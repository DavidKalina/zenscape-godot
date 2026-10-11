#!/bin/zsh
# Close-ups to judge the kit isles' ground and rock against what they match
# (rendered, --no-title): a far sky islet (grove_east, the rock look's
# source), the aqueduct isle's crags, keel and meadow, a bell spire, the
# gorge's wall.  ./tools/kit_isle_compare_captures.sh OUTDIR
# The plate's own ground (the edit chunks') for the same comparison:
#   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_ground.gd -- --no-title --seed 7 --diorama --only=mood --mood=alpine_morning --out=OUTDIR/plate
cd "${0:A:h}/.."
G="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
O=${1:-captures/kit-isle-shared/compare}
mkdir -p "$O"
cap() { "$G" --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/$1.tscn -- --no-title --capture="$O/$2" "${@:3}" 2>&1 | grep -E "saved|SCRIPT ERROR" }
cap aqueduct_isle islet-close.png --at=178,44,-6 --look=215,34,-35
cap aqueduct_isle crag-close.png --at=36,37,24 --look=56,38,4
cap aqueduct_isle keel-close.png --at=104,16,44 --look=90,14,4
cap aqueduct_isle meadow-close.png --at=112,32.2,10 --look=100,30,-6
cap bell_spires_isle spire-close.png --at=108,40,-2 --look=98,40,-12
cap sundered_gorge_isle gorge-wall.png --at=84,23,12 --look=88,27,-15
