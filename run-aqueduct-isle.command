#!/bin/zsh
# The aqueduct isle (studies/aqueduct_isle.gd). The whole loop: find the
# lodestone on the floating stone east of the heel stone (E / pad A picks it
# up, E keeps it), board (F / pad Y), fly where the nose arrow points. Near
# the shard an arch rises out of the cloud past it; fly through it, wait,
# and the Sundered halls start rising ahead (docs/design/isle-hall-chain.md).
#   ./run-aqueduct-isle.command                 the whole loop, from on foot
#   ./run-aqueduct-isle.command --near-ring     in the plane, stone seated, 260 m before the ring
#   ./run-aqueduct-isle.command --carry --fly   in the plane, stone seated, by the isle
#   ./run-aqueduct-isle.command --no-chain      the shard only (the old arrival chime)
#   --ring=x,y,z  --ring-near=<m> (420)  --ring-pause=<s> (1.5)  --chain-lead=<m> (180)  --target=x,y,z
#   --arrive-spare=<s> (2)  --catch-up=<x> (1.6)  --first-at=thread|pulse (thread)
#   --stone-plane, and the hall chain's flags (--chain-at=, --chain-gap=, ...)
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-aqueduct-isle-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

print -r -- "Opening the aqueduct isle. Launch log: $LAUNCH_LOG"
"$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/aqueduct_isle.tscn -- --no-title "$@" 2>&1 | tee "$LAUNCH_LOG"
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
