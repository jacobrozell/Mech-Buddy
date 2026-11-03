#!/bin/sh
# Xcode Cloud clone hook for XcodeGen apps.
# Xcode Cloud only runs ci_scripts at the repository root.
# Mech Buddy does not use Firebase. Do not add a GoogleService-Info secret.
set -e
cd "$CI_PRIMARY_REPOSITORY_PATH"

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

yml=""
yml=$(find . -name project.yml -not -path '*/.*' -maxdepth 4 | head -n 1)
if [ -z "$yml" ]; then
  echo "No project.yml; assuming the Xcode project is already in git"
  exit 0
fi

brew install xcodegen
(cd "$(dirname "$yml")" && xcodegen generate)
echo "Generated Xcode project from $yml"
