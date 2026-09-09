#!/bin/zsh
set -e
cd "${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
exec "$GODOT_BIN" --path . --windowed --resolution 1600x1000 --rendering-method forward_plus res://studies/prototype_living_fog.tscn -- --clean --balanced "$@"
