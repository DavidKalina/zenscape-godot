#!/bin/bash
A=/Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/native-isles
B=/Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/native-isles-base
for th in all 8 6 1; do
  for sp in "sprawl 2" "ring 1"; do
    nb=$th; [ "$th" = "all" ] && nb=0
    /tmp/ni/run_load.sh $A after $sp $th --isle-builds=$nb > /dev/null
    /tmp/ni/run_load.sh $B before $sp $th > /dev/null
  done
done
echo MATRIX DONE
