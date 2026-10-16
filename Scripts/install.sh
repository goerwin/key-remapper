#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 || ( "${1:-}" != "" && "${1:-}" != --no-build ) ]]; then
  echo "Usage: $0 [--no-build]" >&2
  exit 1
fi

root=$(cd "$(dirname "$0")/.." && pwd)
build="$root/build/install"
sourceApp="$build/Build/Products/Release/KeyRemapper.app"
app=/Applications/KeyRemapper.app
temporaryApp="/Applications/.KeyRemapper.installing.$$.app"
backupApp="/Applications/.KeyRemapper.backup.$$.app"
needsSudo=false

installCommand() {
  if [[ "$needsSudo" == true ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

cleanup() {
  if [[ -e "$temporaryApp" ]]; then
    installCommand rm -rf "$temporaryApp"
  fi
  if [[ -e "$backupApp" && ! -e "$app" ]]; then
    installCommand mv "$backupApp" "$app"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [[ "${1:-}" != --no-build ]]; then
  set --
  if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    set -- CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY"
  fi
  xcodebuild -quiet -project "$root/KeyRemapper.xcodeproj" -scheme KeyRemapper \
    -configuration Release -destination 'platform=macOS' -derivedDataPath "$build" \
    -allowProvisioningUpdates "$@" build
fi
if [[ ! -d "$sourceApp" ]]; then
  echo "Error: no built app at $sourceApp. Run make install first." >&2
  exit 1
fi
codesign --verify --deep --strict "$sourceApp"

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$sourceApp/Contents/Info.plist")
echo "Installing KeyRemapper $version to $app"

if [[ ! -w /Applications || ( -e "$app" && ! -w "$app" ) ]]; then
  sudo -v
  needsSudo=true
fi

installCommand ditto "$sourceApp" "$temporaryApp"

pkill -x KeyRemapper || true
for _ in {1..40}; do
  if ! pgrep -x KeyRemapper >/dev/null && ! pgrep -f '(^|/)KeyRemapperDaemon$' >/dev/null; then
    break
  fi
  sleep 0.25
done
if pgrep -x KeyRemapper >/dev/null || pgrep -f '(^|/)KeyRemapperDaemon$' >/dev/null; then
  echo "Error: the app or daemon didn't quit. The installed app was kept." >&2
  exit 1
fi

# Keep the previous copy until the replacement is in place.
if [[ -e "$app" ]]; then
  installCommand mv "$app" "$backupApp"
fi
installCommand mv "$temporaryApp" "$app"
if [[ -e "$backupApp" ]]; then
  installCommand rm -rf "$backupApp"
fi
trap - EXIT INT TERM

echo "Installed KeyRemapper $version to $app"
open "$app"
