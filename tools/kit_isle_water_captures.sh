#!/bin/zsh
# Rendered captures of the kit isles' water (docs/scenic/kit-isle-water.md):
# the views a walker has at the shore and the plane has skimming over, and
# where the water meets a fall's lip.
#   zsh tools/kit_isle_water_captures.sh DIR [view ...] [-- extra args, e.g. --old-water]
# Views are <isle>-<name>: tarn-shore tarn-skim tarn-gate tarn-lip
# tarn-high gorge-shore gorge-skim gorge-lip gorge-fall
# aqueduct-deck aqueduct-above aqueduct-snap (default all). Each opens a
# window (--no-title), settles, saves DIR/<view>.png and quits; the log line
# carries the frame's cost and draw calls.
set -u
cd "${0:A:h}/.."
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
DIR="${1:-captures/kit-isle-water/now}"
shift
typeset -A SCENE AT LOOK
SCENE[tarn]=cloister_tarn; SCENE[gorge]=sundered_gorge; SCENE[aqueduct]=aqueduct
AT[tarn-shore]="82,32,11.4";         LOOK[tarn-shore]="76,29.7,0"
AT[tarn-skim]="74,36,8";             LOOK[tarn-skim]="92,30,-4"
AT[tarn-gate]="70,32.2,1.5";         LOOK[tarn-gate]="100,30.5,0"
AT[tarn-lip]="104,34.2,-5";          LOOK[tarn-lip]="110.5,29.6,0.5"
AT[tarn-high]="80,50,30";           LOOK[tarn-high]="80,30,-2"
AT[gorge-shore]="66.5,33.2,-53";     LOOK[gorge-shore]="76,29.3,-57"
AT[gorge-skim]="60,36.5,-44";        LOOK[gorge-skim]="77,29.5,-57"
AT[gorge-lip]="76,32,-49.5";         LOOK[gorge-lip]="81.5,28.5,-56"
AT[gorge-fall]="96,30,-70";          LOOK[gorge-fall]="80,22,-55"
AT[aqueduct-deck]="100,37.7,-3";     LOOK[aqueduct-deck]="100,35.9,-16"
AT[aqueduct-above]="104.5,40.5,-9";  LOOK[aqueduct-above]="100,36,-22"
AT[aqueduct-snap]="103,38.5,-27";    LOOK[aqueduct-snap]="100,36,-33"
ALL=(tarn-shore tarn-skim tarn-gate tarn-lip tarn-high gorge-shore gorge-skim gorge-lip gorge-fall aqueduct-deck aqueduct-above aqueduct-snap)
NAMES=()
EXTRA=()
seen_dash=0
for a in "$@"; do
  if [[ "$a" == "--" ]]; then seen_dash=1; continue; fi
  if (( seen_dash )); then EXTRA+=("$a"); else NAMES+=("$a"); fi
done
(( ${#NAMES} == 0 )) && NAMES=($ALL)
mkdir -p "$DIR"
for n in $NAMES; do
  isle=${n%%-*}
  perl -e 'alarm 220; exec @ARGV' "$GODOT_BIN" --path . --rendering-method forward_plus --windowed --resolution 1440x900 \
    "res://studies/${SCENE[$isle]}_isle.tscn" -- --no-title --capture="$DIR/$n.png" --at="${AT[$n]}" --look="${LOOK[$n]}" $EXTRA < /dev/null 2>&1 \
    | grep -E "saved|SCRIPT ERROR"
done
