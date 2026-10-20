#!/bin/zsh
# The islet yard (studies/islet_yard.gd): the islet unit, the smallest piece
# an isle is composed of (scripts/kit_isle/islet_unit.gd), in the game's
# sky. One hero unit in the middle (you start on its turf), a ring of
# siblings drawn from the same family knobs round it
# (docs/design/isle-look/islet-unit-handoff.md).
#   ./run-islet-yard.command                       the hero and eight siblings
#   ./run-islet-yard.command --family=3            another family of siblings
#   ./run-islet-yard.command --hero=seed=12,shape=0.9,drip=1
#   ./run-islet-yard.command --base=growth=1,weather=0.2 --ring=12
#   ./run-islet-yard.command --solo                the hero alone
#   knobs: seed size shape lean drip lopsided growth weather (0..1; size 1.5..18 m)
#   --hide=Turf,Rock,Drape,Tufts,Roots,Growth      leave parts hidden (looking at one)
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-islet-yard-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

print -r -- "Opening the islet yard. Launch log: $LAUNCH_LOG"
"$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/islet_yard.tscn -- --no-title "$@" 2>&1 | tee "$LAUNCH_LOG"
launch_status=${pipestatus[1]}
# Godot can report script-load failures while returning a zero exit status.
if (( launch_status == 0 )) && /usr/bin/grep -Eq 'SCRIPT ERROR:|ERROR: Failed to load' "$LAUNCH_LOG"; then
  launch_status=1
fi
if (( launch_status != 0 )); then
  print -r -- "ZenScape stopped with an error (exit $launch_status)."
  print -r -- "Launch log: $LAUNCH_LOG"
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
fi
exit "$launch_status"
