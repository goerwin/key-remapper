#!/usr/bin/env bash
set -euo pipefail

#
# Smoke test of the installed app: builds and installs the signed app, then drives its menu with
# UI scripting and checks that the daemon keeps running. The terminal app needs Accessibility.
# Usage: Tests/app.sh [--no-build]
#

process='application process "KeyRemapper"'
menu="menu 1 of menu bar item 1 of menu bar 2 of $process"
alerts="every window of $process whose subrole is \"AXDialog\""
config="$HOME/keyRemapperMac/config.json"
configBackup=$(mktemp)
failures=0

ui() { osascript -e "tell application \"System Events\" to $1"; }
menuItems() { ui "get name of every menu item of $menu" | sed 's/, /\n/g'; }
menuHas() { menuItems | grep -qx "$1"; }
# Profiles are the menu items under the "Profiles" header, until the next separator
profileItems() { menuItems | awk '/^Profiles$/ { p = 1; next } /^missing value$/ { p = 0 } p'; }
profilesAre() { [[ "$(profileItems)" == "$1" ]]; }
# The active profile has a checkmark
isChecked() { [[ "$(ui "get value of attribute \"AXMenuItemMarkChar\" of menu item \"$1\" of $menu")" == "✓" ]]; }
clickMenu() {
  ui "click menu item \"$1\" of $menu" >/dev/null || true
  sleep 1
}
daemonPid() { pgrep -f 'MacOS/KeyRemapperDaemon' || true; }
daemonIs() { [[ "$(daemonPid)" == "$1" ]]; }
daemonRuns() { [[ -n "$(daemonPid)" ]]; }
hasWindow() { ui "exists window \"$1\" of $process" | grep -q true; }
hasNoWindow() { ! hasWindow "$1"; }
# Alerts have no title, so they're counted
hasNoAlerts() { [[ "$(ui "count ($alerts)")" == 0 ]]; }
hasAlert() { ! hasNoAlerts; }
dismissAlert() { ui "click button \"OK\" of item 1 of ($alerts)" >/dev/null || true; sleep 1; }
daemonNotInDock() { ! lsappinfo list | grep -A4 '"co.goerwin.KeyRemapperDaemon"' | grep -q Foreground; }

check() {
  local name=$1
  shift
  if "$@"; then
    echo "ok: $name"
  else
    echo "FAIL: $name"
    failures=$((failures + 1))
  fi
}

waitFor() {
  for _ in $(seq 1 20); do
    "$@" && return 0
    sleep 0.5
  done
  return 1
}

frontApp=$(lsappinfo info -only bundleid "$(lsappinfo front)" | cut -d'"' -f4)

"$(dirname "$0")/../Scripts/install.sh" "$@"

check "starts the daemon" waitFor daemonRuns
pid=$(daemonPid)
check "starts remapping" waitFor menuHas Pause
check "shows no alerts" hasNoAlerts
check "keeps the daemon out of the Dock" daemonNotInDock

clickMenu Pause
check "pauses" menuHas Resume
open -a Finder && sleep 0.5 && open -b "$frontApp" && sleep 0.5
check "survives switching apps while paused" daemonIs "$pid"
clickMenu Resume
check "resumes" menuHas Pause

profiles=$(profileItems)
active=$(while read -r name; do isChecked "$name" && echo "$name"; done <<< "$profiles")
while read -r name; do
  clickMenu "$name"
  check "switches to profile \"$name\"" isChecked "$name"
done <<< "$profiles"
clickMenu "$active"
check "survives switching profiles" daemonIs "$pid"

cp -p "$config" "$configBackup"
trap 'cp -p "$configBackup" "$config"' EXIT
{ echo '// A comment'; cat "$configBackup"; } > "$config"
sleep 1.5
check "lists the profiles of a config with comments" waitFor profilesAre "$profiles"
check "keeps remapping with comments in the config" menuHas Pause
check "shows no alerts with comments in the config" hasNoAlerts

echo '{' > "$config"
check "reloads the config when it's saved, reporting errors" waitFor hasAlert
dismissAlert
check "stops remapping with an invalid config" menuHas Resume
cp -p "$configBackup" "$config"
check "resumes when the config is fixed" waitFor menuHas Pause
echo '{ "profiles": {} }' > "$config"
check "reports the errors of the daemon" waitFor hasAlert
dismissAlert
check "stops remapping on errors of the daemon" menuHas Resume
cp -p "$configBackup" "$config"
check "resumes when the config is fixed again" waitFor menuHas Pause
check "shows no alerts after fixing the config" hasNoAlerts
clickMenu Pause
touch "$config" && sleep 1.5
check "stays paused when the config is saved" menuHas Resume
clickMenu Resume

clickMenu Logger
check "opens the Logger" hasWindow Logger
ui "click button 1 of window \"Logger\" of $process" >/dev/null
sleep 1
check "closes the Logger" hasNoWindow Logger
check "shows no alerts at the end" hasNoAlerts
check "keeps the same daemon running" daemonIs "$pid"

echo
if ((failures)); then
  echo "$failures FAILED"
  exit 1
fi
echo "SUCCESS!"
