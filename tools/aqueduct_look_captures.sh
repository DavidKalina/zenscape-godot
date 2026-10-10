#!/bin/zsh
# The aqueduct isle in the game's look presets (rendered, --no-title):
#   zsh tools/aqueduct_look_captures.sh OUTDIR [preset ...]
# Each preset gets the south-west establishing view and an on-foot view.
cd "${0:A:h}/.."
G="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
O=$1
shift
mkdir -p "$O"
presets=("$@")
(( ${#presets} )) || presets=(alpine_morning rosewater_dusk first_snow nordic_night)
run() { "$G" --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/aqueduct_isle.tscn -- --no-title --capture="$O/$1" "${@:2}" 2>&1 | grep -E "saved|SCRIPT ERROR" }
for p in $presets; do
  run "southwest-$p.png" --preset=$p --at=30,44,52 --look=75,34,-2
  run "onfoot-$p.png" --preset=$p --place=57.3,38.7,16.1,13
done
