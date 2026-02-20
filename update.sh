#!/bin/bash

set -e

SOURCE_XCFRAMEWORK="${1:-/Users/rogerio/git/llama.cpp/build-apple/llama.xcframework}"
DEST_XCFRAMEWORK="llama.cpp/llama.xcframework"

if [ ! -d "$SOURCE_XCFRAMEWORK" ]; then
  echo "Error: Source XCFramework not found at '$SOURCE_XCFRAMEWORK'."
  exit 1
fi

echo "Syncing XCFramework from '$SOURCE_XCFRAMEWORK' to '$DEST_XCFRAMEWORK'..."
mkdir -p "$DEST_XCFRAMEWORK"
rsync -a --delete "$SOURCE_XCFRAMEWORK/" "$DEST_XCFRAMEWORK/"

echo "Running Swift tests..."
swift test
