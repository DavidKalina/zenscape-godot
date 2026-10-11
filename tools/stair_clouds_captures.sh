#!/bin/zsh
# The Stair to the Clouds' look views (rendered, --no-title): ./tools/stair_clouds_captures.sh OUTDIR [extra flags]
cd "${0:A:h}/.."
G="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
O=$1
shift
mkdir -p "$O"
run() { "$G" --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/stair_clouds_isle.tscn -- --no-title --capture="$O/$1" "${@:2}" 2>&1 | grep -E "saved|SCRIPT ERROR" }
run 1-establishing.png --at=150,70,60 --look=80,50,-8 "$@"
run 2-from-south.png --at=80,40,60 --look=80,52,-10 "$@"
run 3-onfoot-start.png "$@"
run 4-summit.png --at=100,90,14 --look=80,76,-14 "$@"
