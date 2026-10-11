#!/bin/zsh
# The bell spires isle's look views (rendered, --no-title): ./tools/bell_spires_captures.sh OUTDIR [extra flags]
cd "${0:A:h}/.."
G="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
O=$1
shift
mkdir -p "$O"
run() { "$G" --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/bell_spires_isle.tscn -- --no-title --capture="$O/$1" "${@:2}" 2>&1 | grep -E "saved|SCRIPT ERROR" }
run 1-establishing.png --at=150,72,40 --look=86,42,-24 "$@"
run 2-from-the-meadow.png --at=110,33,0 --look=86,46,-24 "$@"
run 3-thread.png --at=112,50,-38 --look=80,48,-22 "$@"
run 4-belfry.png --at=104,64,-8 --look=86,61,-24 "$@"
run 5-fin-west.png --at=40,50,-52 --look=78,40,-28 "$@"
run 6-start-on-foot.png "$@"
