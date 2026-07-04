#!/usr/bin/env bash
# Example Cursor launcher for multi-colab-ide
#
# Cursor has no built-in CLI. Copy this to ~/.local/bin/cursor and edit the path:
#
#   cp config/cursor-launcher.example.sh ~/.local/bin/cursor
#   chmod +x ~/.local/bin/cursor
#
# Linux (AppImage):
CURSOR_BIN="${CURSOR_BIN:-$HOME/Apps/cursor.AppImage}"

# macOS (uncomment and adjust):
# CURSOR_BIN="/Applications/Cursor.app/Contents/MacOS/Cursor"

# WSL: often the Windows install or an AppImage inside WSL — set CURSOR_BIN accordingly.

if [[ ! -x "$CURSOR_BIN" && ! -f "$CURSOR_BIN" ]]; then
  echo "Cursor binary not found: $CURSOR_BIN" >&2
  echo "Edit $0 and set CURSOR_BIN to your Cursor install." >&2
  exit 1
fi

exec "$CURSOR_BIN" --no-sandbox "$@"
