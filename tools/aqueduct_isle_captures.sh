#!/bin/zsh
# The aqueduct isle's look views (rendered, --no-title): ./tools/aqueduct_isle_captures.sh OUTDIR
cd "${0:A:h}/.."
G="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
O=$1
mkdir -p "$O"
run() { "$G" --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/aqueduct_isle.tscn -- --no-title --capture="$O/$1" "${@:2}" 2>&1 | grep -E "saved|SCRIPT ERROR" }
run 1-establishing.png --at=140,62,60 --look=82,34,-4
run 2-southwest.png --at=30,44,52 --look=75,34,-2
run 3-path-from-below.png --at=90,33,-28 --look=58,37,-10
run 4-path-partway.png --at=42,41.5,-10 --look=64,40,6
run 5-floating-south.png --at=86,32,30 --look=64,39,8
run 6-summit-view.png --at=54.7,48.3,0.5 --look=100,34,-8
run 7-onfoot-ledge.png --place=57.3,38.7,16.1,13
run 8-onfoot-ramp.png --place=49.6,36.6,-13.6,230
