#!/bin/zsh
set -e
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
exec "$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus res://scenes/sandbox.tscn "$@"
