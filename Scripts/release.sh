#!/usr/bin/env bash
set -euo pipefail

#
# Previews and creates a release: bumps the latest version tag on origin, shows the commits that
# will go in it and, after confirmation, pushes an annotated tag whose message is the release notes.
# Pushing the tag triggers .github/workflows/release.yml, which builds the app and publishes it.
#
# Usage: Scripts/release.sh patch|minor|major
#

bump=${1:-}
if [[ ! "$bump" =~ ^(patch|minor|major)$ ]]; then
  echo "Usage: $0 patch|minor|major" >&2
  exit 1
fi

if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "Error: releases are made from main" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: there are uncommitted changes" >&2
  exit 1
fi

git fetch --quiet --tags origin main

if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/main)" ]]; then
  echo "Error: main and origin/main differ, push or pull first" >&2
  exit 1
fi

lastTag=$(git ls-remote --tags --refs origin 'v*' | sed 's|.*refs/tags/||' |
  grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
lastTag=${lastTag:-v0.0.0}

IFS=. read -r major minor patch <<<"${lastTag#v}"
case "$bump" in
major) newTag="v$((major + 1)).0.0" ;;
minor) newTag="v$major.$((minor + 1)).0" ;;
patch) newTag="v$major.$minor.$((patch + 1))" ;;
esac

range="$lastTag..HEAD"
[[ "$lastTag" == "v0.0.0" ]] && range="HEAD"

notes=$(git log --no-merges --format='- %s (%h)' "$range")
if [[ -z "$notes" ]]; then
  echo "Error: no commits since $lastTag" >&2
  exit 1
fi

echo "Release $lastTag -> $newTag"
echo
echo "$notes"
echo
git diff --stat "$lastTag" HEAD 2>/dev/null | tail -1 || true
echo

read -r -p "Push tag $newTag and release it? [y/N] " answer
if [[ ! "$answer" =~ ^[yY]$ ]]; then
  echo "Cancelled"
  exit 0
fi

git tag -a "$newTag" -F - <<<"$newTag

$notes"
git push --quiet origin "$newTag"

repo=$(git remote get-url origin | sed -E 's#(git@|https://)github.com[:/]##; s#\.git$##')
echo "Pushed $newTag, follow the build at https://github.com/$repo/actions"
