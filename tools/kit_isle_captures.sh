#!/bin/zsh
# Every kit isle's look views, one folder an isle (rendered, --no-title; each
# view opens a window, settles, saves and quits):
#   zsh tools/kit_isle_captures.sh OUTDIR [isle ...]
# Isles: aqueduct bell cloister gorge colonnade (default all).
cd "${0:A:h}/.."
O=${1:-captures/kit-isle-shared/now}
shift
ISLES=(aqueduct bell cloister gorge colonnade)
(( $# > 0 )) && ISLES=("$@")
for isle in $ISLES; do
  case $isle in
    aqueduct) zsh tools/aqueduct_isle_captures.sh "$O/aqueduct" ;;
    bell) zsh tools/bell_spires_captures.sh "$O/bell" ;;
    cloister) zsh tools/cloister_tarn_captures.sh "$O/cloister" ;;
    gorge) zsh tools/sundered_gorge_captures.sh "$O/gorge" establishing gorge_north bridge_south west_from_chapel lower_crossing fall southwest onfoot_start ;;
    colonnade) zsh tools/colonnade_spine_captures.sh "$O/colonnade" ;;
  esac
done
