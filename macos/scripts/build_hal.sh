#!/bin/bash
# Xcode "Build HAL plug-in" Run Script phase: builds MuteAround.driver with
# CMake and copies it into the app bundle's Contents/Resources, where the
# setup flow installs it from.
set -euo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}/.."
BUILD_DIR="$ROOT/build/macos_hal"

# Xcode runs scripts with a minimal PATH; find Homebrew's CMake too.
export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
command -v cmake >/dev/null || { echo "error: CMake ≥ 3.24 is required (brew install cmake)"; exit 1; }

cmake -S "$ROOT/native/macos_hal" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR"

RESOURCES="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "$RESOURCES"
rm -rf "$RESOURCES/MuteAround.driver"
cp -R "$BUILD_DIR/MuteAround.driver" "$RESOURCES/MuteAround.driver"
