#!/bin/zsh
# The colonnade spine's look views (rendered, --no-title): ./tools/colonnade_spine_captures.sh OUTDIR [extra flags]
cd "${0:A:h}/.."
G="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
O=$1
shift
mkdir -p "$O"
run() { "$G" --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/colonnade_spine_isle.tscn -- --no-title --capture="$O/$1" "${@:2}" 2>&1 | grep -E "saved|SCRIPT ERROR" }
run 1-establishing.png --at=175,85,70 --look=80,38,-14 "$@"
run 2-along-from-head.png --at=4,60,-48 --look=110,36,-12 "$@"
run 3-south-flank.png --at=104,30,30 --look=92,38,-12 "$@"
run 4-onfoot-start.png "$@"
run 5-head.png --at=78,52,-30 --look=44,47,-14 "$@"
run 6-tail-curl.png --at=182,44,44 --look=148,30,2 "$@"
run 7-onfoot-plaza.png --place=63,43.44,-16.3,270 "$@"
run 8-north-shelf.png --at=118,46,-48 --look=80,38,-20 "$@"
