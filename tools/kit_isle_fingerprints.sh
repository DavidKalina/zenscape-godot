#!/bin/zsh
# Every kit isle's layout fingerprint (tools/kit_isle_fingerprint.gd), headless, into OUTDIR/<isle>.txt.
cd "${0:A:h}/.."
G="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
O=${1:-captures/kit-isle-shared/fp}
mkdir -p "$O"
typeset -A SCENES
SCENES=(aqueduct aqueduct_isle bell bell_spires_isle cloister cloister_tarn_isle gorge sundered_gorge_isle colonnade colonnade_spine_isle stair stair_clouds_isle)
for k in ${(k)SCENES}; do
  ( "$G" --headless --path . --script tools/kit_isle_fingerprint.gd -- res://studies/${SCENES[$k]}.tscn --no-sky --no-life --no-flora --dump=$O/$k.rays 2>&1 | grep '^FP' > "$O/$k.txt" ) &
done
wait
