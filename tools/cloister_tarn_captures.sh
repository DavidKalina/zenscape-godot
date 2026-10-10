#!/bin/zsh
# Rendered captures of the cloister tarn (docs/scenic/cloister-tarn.md):
#   zsh tools/cloister_tarn_captures.sh DIR [name ...]
# Each view: name, the eye, the point looked at. Extra args after `--`
# go to the scene (e.g. -- --look=rosewater_dusk).
set -u
cd "${0:A:h}/.."
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
DIR="${1:-captures/cloister-tarn}"
shift
typeset -A VIEWS
VIEWS=(
  1-establishing "135,62,50 78,30,-2"
  2-southwest "30,55,62 80,31,0"
  3-tarn-west "92,35,6 66,32,0"
  4-crag "72,33,10 62,38,-20"
  5-gate "70,32.2,1.5 100,30.5,0"
  6-north "70,72,-75 80,32,0"
  7-onfoot-alley "88,32.3,15 70,31.5,14"
  8-fall "122,24,22 108,28,0"
)
NAMES=()
EXTRA=()
seen_dash=0
for a in "$@"; do
  if [[ "$a" == "--" ]]; then seen_dash=1; continue; fi
  if (( seen_dash )); then EXTRA+=("$a"); else NAMES+=("$a"); fi
done
(( ${#NAMES} == 0 )) && NAMES=(${(ko)VIEWS})
mkdir -p "$DIR"
for n in $NAMES; do
  v=(${=VIEWS[$n]})
  perl -e 'alarm 220; exec @ARGV' "$GODOT_BIN" --path . --rendering-method forward_plus --windowed --resolution 1440x900 \
    res://studies/cloister_tarn_isle.tscn -- --no-title --capture="$DIR/$n.png" --at="${v[1]}" --look="${v[2]}" $EXTRA < /dev/null 2>&1 \
    | grep -E "saved|SCRIPT ERROR"
done
