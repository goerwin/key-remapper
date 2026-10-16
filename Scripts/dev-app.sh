#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
build="$root/build/dev-app"
app="$build/Build/Products/Debug/KeyRemapper.app"

pkill -x KeyRemapper || true
for _ in {1..40}; do
  if ! pgrep -f '(^|/)KeyRemapperDaemon$' >/dev/null; then break; fi
  sleep 0.25
done
if pgrep -f '(^|/)KeyRemapperDaemon$' >/dev/null; then
  echo "Error: the daemon didn't quit with the app" >&2
  exit 1
fi

xcodebuild -quiet -project "$root/KeyRemapper.xcodeproj" -scheme KeyRemapper \
  -configuration Debug -derivedDataPath "$build" build
echo "Launching $app"
open -n "$app"
