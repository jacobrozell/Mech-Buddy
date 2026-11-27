#!/bin/bash
# Host side of LandscapeScreenshotUITests: takes the screenshot each time the test writes request.txt.
# Usage: scripts/landscape-shots-watch.sh <udid> <dir>
udid="$1"; dir="$2"; mkdir -p "$dir"
while true; do
  if [ -f "$dir/request.txt" ]; then
    name=$(cat "$dir/request.txt")
    xcrun simctl io "$udid" screenshot "$dir/$name.png" >/dev/null 2>&1
    rm -f "$dir/request.txt"
  fi
  sleep 0.2
done
