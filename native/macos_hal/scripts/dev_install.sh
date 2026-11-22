#!/bin/bash
# Developer install of the Mute Around virtual microphone (macOS).
#
# Builds MuteAround.driver (unless a path is given), copies it to
# /Library/Audio/Plug-Ins/HAL and restarts coreaudiod. Needs sudo.
# Audio in every app stops for a second while coreaudiod restarts.
#
#   native/macos_hal/scripts/dev_install.sh [path/to/MuteAround.driver]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DRIVER="${1:-}"
if [[ -z "$DRIVER" ]]; then
  cmake -S "$ROOT/native/macos_hal" -B "$ROOT/build/macos_hal" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$ROOT/build/macos_hal"
  DRIVER="$ROOT/build/macos_hal/MuteAround.driver"
fi
[[ -d "$DRIVER" ]] || { echo "No driver bundle at $DRIVER" >&2; exit 1; }

DEST="/Library/Audio/Plug-Ins/HAL/MuteAround.driver"
echo "Installing $DRIVER → $DEST"
sudo rm -rf "$DEST"
sudo cp -R "$DRIVER" "$DEST"
sudo chown -R root:wheel "$DEST"
sudo killall -9 coreaudiod
echo "Done. \"Mute Around\" should now appear in Audio MIDI Setup."
