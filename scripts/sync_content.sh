#!/usr/bin/env sh
# Copies the canonical reference articles in content/ into the iOS app resources.
# Run after editing anything in content/. The Android app will consume the same files.
set -e
cd "$(dirname "$0")/.."
mkdir -p ios/EarthFromAbove/Resources/Content
cp content/*.md ios/EarthFromAbove/Resources/Content/
echo "synced $(ls content/*.md | wc -l | tr -d ' ') articles"
