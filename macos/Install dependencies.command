#!/bin/zsh
set -e
BREW=/opt/homebrew/bin/brew
if [[ ! -x "$BREW" ]]; then
  echo "Install Homebrew first from https://brew.sh, then run this file again."
  exit 1
fi
"$BREW" install scrcpy python@3.13 ffmpeg
"$BREW" install --cask android-platform-tools
echo "Done. You can now open ARIZONA Quest Live.app."
