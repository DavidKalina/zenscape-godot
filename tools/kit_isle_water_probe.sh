#!/bin/zsh
# Every kit isle's water surfaces, headless (tools/kit_isle_water_probe.gd):
#   zsh tools/kit_isle_water_probe.sh [isle ...] [-- extra args, e.g. --old-water]
# Isles: aqueduct bell_spires cloister_tarn sundered_gorge colonnade_spine
# (default all).
set -u
cd "${0:A:h}/.."
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
ISLES=()
EXTRA=()
seen_dash=0
for a in "$@"; do
  if [[ "$a" == "--" ]]; then seen_dash=1; continue; fi
  if (( seen_dash )); then EXTRA+=("$a"); else ISLES+=("$a"); fi
done
(( ${#ISLES} == 0 )) && ISLES=(aqueduct bell_spires cloister_tarn sundered_gorge colonnade_spine)
for isle in $ISLES; do
  "$GODOT_BIN" --headless --path . -s res://tools/kit_isle_water_probe.gd -- "--isle=$isle" $EXTRA < /dev/null 2>&1 \
    | grep -E "^WATER|water probe|SCRIPT ERROR|ERROR"
done
