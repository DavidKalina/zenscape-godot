#!/bin/zsh
# Rendered captures of the Sundered gorge isle (docs/scenic/sundered-gorge.md):
#   zsh tools/sundered_gorge_captures.sh DIR [view ...] [-- extra args]
# Each view opens a window (--no-title), settles, saves DIR/<view>.png and
# quits. Views: establishing gorge_north bridge_south west_from_chapel
# lower_crossing onfoot_start onfoot_bridge fall.
set -u
PROJECT_DIR="${0:A:h:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="${1:-captures/sundered-gorge}"
shift || true
mkdir -p "$OUT"
typeset -A AT LOOK PLACE
AT[establishing]="152,72,46";       LOOK[establishing]="86,22,-22"
AT[gorge_north]="87.5,36,-86";      LOOK[gorge_north]="88,22,-15"
AT[bridge_south]="84,23,12";        LOOK[bridge_south]="88,27,-15"
AT[west_from_chapel]="114,42,-2";   LOOK[west_from_chapel]="72,31,-24"
AT[lower_crossing]="104,34,-66";    LOOK[lower_crossing]="86,25,-45"
AT[fall]="96,30,-70";               LOOK[fall]="80,22,-55"
AT[southwest]="30,62,40";           LOOK[southwest]="86,24,-22"
PLACE[onfoot_start]=""
PLACE[onfoot_bridge]="81,30,-15,90"
VIEWS=(establishing gorge_north bridge_south west_from_chapel lower_crossing fall southwest onfoot_start onfoot_bridge)
EXTRA=()
if (( $# > 0 )); then
  picked=()
  while (( $# > 0 )); do
    if [[ "$1" == "--" ]]; then shift; EXTRA=("$@"); break; fi
    picked+=("$1"); shift
  done
  (( ${#picked} > 0 )) && VIEWS=("${picked[@]}")
fi
for v in "${VIEWS[@]}"; do
  args=(--no-title "--capture=$OUT/$v.png")
  if [[ -n "${AT[$v]:-}" ]]; then args+=("--at=${AT[$v]}" "--look=${LOOK[$v]}"); fi
  if [[ -n "${PLACE[$v]:-}" ]]; then args+=("--place=${PLACE[$v]}"); fi
  "$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/sundered_gorge_isle.tscn -- "${args[@]}" "${EXTRA[@]}" 2>&1 | grep -E "saved|ERROR|SCRIPT" | head -5
done
