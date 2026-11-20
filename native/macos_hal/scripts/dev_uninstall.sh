#!/bin/bash
# Removes the Mute Around virtual microphone (macOS) and restarts coreaudiod.
# Needs sudo.
set -euo pipefail

DEST="/Library/Audio/Plug-Ins/HAL/MuteAround.driver"
if [[ -d "$DEST" ]]; then
  sudo rm -rf "$DEST"
  sudo killall -9 coreaudiod
  echo "Removed $DEST."
else
  echo "Not installed."
fi
