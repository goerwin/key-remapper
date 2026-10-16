#!/usr/bin/env zsh

#Script to format all clang - supported files
files=($(ls **/*.(c|cpp|h|hpp|m|mm) | egrep -v "(^|/)(build|vendors)/"))
for file in $files; do clang-format -i "$file"; done

# Format .swift files
./swift-format format -i **/*.swift

# Format.json files
files=($(ls **/*.json | egrep -v "(^|/)(build|vendors)/|xcassets/"));
for file in $files; do prettier --write "$file"; done
