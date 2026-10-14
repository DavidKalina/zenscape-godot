#!/bin/bash
# usage: run_load.sh <worktree> <tag> <shape> <seed> <threads|all> [extra args...]
WT=$1; TAG=$2; SHAPE=$3; SEED=$4; TH=$5; shift 5
G=/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot
OUT=/tmp/ni/load/$TAG-$SHAPE-$SEED-t$TH
mkdir -p $OUT
rm -f $WT/override.cfg
if [ "$TH" != "all" ]; then printf '[threading]\n\nworker_pool/max_threads=%s\n' "$TH" > $WT/override.cfg; fi
echo "uptime: $(uptime)" > $OUT/log.txt
perl -e 'alarm 400; exec @ARGV' $G --windowed --path $WT -s res://tools/bench_loading.gd -- --no-title --shape=$SHAPE --seed=$SEED --secs=3 --turn=0 --loading-trace --out=$OUT "$@" >> $OUT/log.txt 2>&1
echo "rc=$?" >> $OUT/log.txt
rm -f $WT/override.cfg
grep -E "playable at|loading trace: isle|motif isles:|SCRIPT ERROR" $OUT/log.txt
