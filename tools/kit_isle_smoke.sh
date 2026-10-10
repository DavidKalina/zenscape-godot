#!/bin/zsh
# Every kit isle opened headless with its life, flora and sky, its build lines
# and any script error printed (tools/kit_isle_fingerprint.gd does the opening).
#   zsh tools/kit_isle_smoke.sh [isle_scene ...]
cd "${0:A:h}/.."
G="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
SCENES=(aqueduct_isle bell_spires_isle cloister_tarn_isle sundered_gorge_isle colonnade_spine_isle)
(( $# > 0 )) && SCENES=("$@")
for s in $SCENES; do
  echo "== $s"
  "$G" --headless --path . --script tools/kit_isle_fingerprint.gd -- res://studies/$s.tscn 2>&1 \
    | grep -E 'SCRIPT ERROR|Parse Error|ERROR: [^0-9]|triangles|flora|life|walking|   at: ' | grep -v 'RID allocations|resources still' | head -12
done
