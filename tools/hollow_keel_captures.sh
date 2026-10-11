#!/bin/zsh
# Rendered captures of the Hollow Keel isle (docs/scenic/hollow-keel.md):
#   zsh tools/hollow_keel_captures.sh DIR [view ...] [-- extra args]
# Each view opens a window (--no-title), settles, saves DIR/<view>.png and
# quits. Views: above below west_mouth inside shaft stairs porch east_mouth.
set -u
PROJECT_DIR="${0:A:h:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="${1:-captures/hollow-keel}"
shift || true
mkdir -p "$OUT"
typeset -A AT LOOK PLACE
AT[above]="150,66,40";            LOOK[above]="80,26,-15"
AT[below]="30,0,-70";             LOOK[below]="82,14,-15"
AT[west_mouth]="14,19,-4";        LOOK[west_mouth]="50,18,-10"
AT[inside]="50,19,-8.7";          LOOK[inside]="90,18,-8.7"
AT[shaft]="68,40,-30";            LOOK[shaft]="73,25,-14"
AT[stairs]="72,24.5,-17";            LOOK[stairs]="76.5,21,-23.5"
AT[porch]="134,26,-30";           LOOK[porch]="128,17,-10"
AT[east_mouth]="150,18,-6";       LOOK[east_mouth]="110,18,-12"
VIEWS=(above below west_mouth inside shaft stairs porch east_mouth)
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
  "$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/hollow_keel_isle.tscn -- "${args[@]}" "${EXTRA[@]}" 2>&1 | grep -E "saved|ERROR|SCRIPT" | head -5
done
