#!/bin/zsh
set -euo pipefail

if [[ $# -gt 1 || ( "${1:-}" != "" && "${1:-}" != --no-build ) ]]; then
  echo "Usage: $0 [--no-build]" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
build="$root/build/install"
sourceApp="$build/Build/Products/Release/KeyRemapper.app"

if [[ "${1:-}" != --no-build ]]; then
  buildCommand=(
    xcodebuild -quiet
    -project "$root/KeyRemapper.xcodeproj"
    -scheme KeyRemapper
    -configuration Release
    -destination 'platform=macOS'
    -derivedDataPath "$build"
    -allowProvisioningUpdates
  )
  if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    buildCommand+=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$CODE_SIGN_IDENTITY")
  fi
  "${buildCommand[@]}" build
fi

source "${DOTFILES_DIR:-$HOME/Projects/dotfiles}/scripts/install-mac-lib.zsh"
MAC_APP_NAME="KeyRemapper"
MAC_SOURCE_APP="$sourceApp"
MAC_QUIT_PATTERNS='(^|/)KeyRemapperDaemon$'
mac_install_app
