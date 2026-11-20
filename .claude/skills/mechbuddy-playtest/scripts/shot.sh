#!/bin/zsh
# Save a simulator screenshot into the playtest session folder and a small preview to Read.
# Usage: shot.sh 07-initiative        (no extension)
# Copy this file to your scratchpad and set the three variables below first.

SIM_UDID="C3CA7CF6-9F36-42CC-B331-6A1BBCBE4B6B"          # iPhone 17 simulator
SESSION_DIR="$HOME/Desktop/personal/apps/MechBuddy/ongoing/play-YYYY-MM-DD"
PREVIEW="${TMPDIR:-/tmp}/mechbuddy-view.png"              # the file you Read to see the screen

name="$1"
[[ -z "$name" ]] && { echo "usage: shot.sh <NN-name>"; exit 1; }
mkdir -p "$SESSION_DIR"
xcrun simctl io "$SIM_UDID" screenshot "$SESSION_DIR/$name.png" >/dev/null 2>&1 \
  && sips -Z 900 "$SESSION_DIR/$name.png" --out "$PREVIEW" >/dev/null \
  && echo "saved $name -> preview at $PREVIEW"
