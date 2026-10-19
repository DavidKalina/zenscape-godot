#!/bin/zsh
# How much a patch of water changes frame to frame in a film (Godot
# --write-movie), as a flicker figure: the mean and worst absolute
# difference of grey levels (0-255) between consecutive frames over a crop,
# from frame FROM on.
#   zsh tools/water_flicker.sh FILM.avi W:H:X:Y [FROM]
set -u
film="$1"
crop="$2"
from="${3:-200}"
out="${film%.*}-flicker.txt"
ffmpeg -v error -i "$film" -vf "select='gte(n\\,$from)',crop=$crop,format=gray,tblend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=$out" -f null -
awk -F= -v name="${film:t}" '/YAVG/{s+=$2;n++; if($2>m)m=$2} END{printf "%s: mean frame-to-frame difference %.3f, worst %.3f, over %d frames\n",name,s/n,m,n}' "$out"
