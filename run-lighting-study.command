#!/bin/zsh
set -e
cd "${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
exec "$GODOT_BIN" --path . --windowed --resolution 1920x1200 --rendering-method forward_plus --script res://tools/prototype_lighting_study.gd -- --clean --balanced --paused --phase=0.48 --cam=43,1.13,1.8893,0,3,0 --fog=0.02 --haze=0.03 --shroud=0 --clouds=0.06 --wind=0.4 "$@"
