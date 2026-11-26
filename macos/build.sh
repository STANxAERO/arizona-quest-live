#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
out=../dist/macos
if [ "$#" -gt 0 ]; then out="$1"; fi
app="$out/ARIZONA Quest Live.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
swiftc -swift-version 5 -target arm64-apple-macos14.0 -parse-as-library -O QuestLive.swift -o "$app/Contents/MacOS/QuestLive"
cp Info.plist "$app/Contents/Info.plist"
cp discovery.py "$app/Contents/Resources/discovery.py"
cp lens_viewer.py "$app/Contents/Resources/lens_viewer.py"
cp maintenance.py "$app/Contents/Resources/maintenance.py"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
