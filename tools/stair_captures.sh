#!/bin/zsh
# The grand stair from five angles (rendered, --no-title): ./tools/stair_captures.sh OUTDIR
cd "${0:A:h}/.."
G="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
O=$1
mkdir -p "$O"
run() { "$G" --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/aqueduct_isle.tscn -- --no-title --capture="$O/$1" "${@:2}" 2>&1 | grep -E "saved|SCRIPT ERROR" }
run a-from-foot.png --at=95,31.6,4 --look=80,33.2,0
run b-side.png --at=84,32.6,13 --look=83.5,32.2,0
run c-top-down.png --at=74.5,39,1.5 --look=86.5,30.5,0
run d-onfoot-climb.png --place=86.6,31.0,0.4,270
run e-far.png --at=104,36,16 --look=78,32,0
