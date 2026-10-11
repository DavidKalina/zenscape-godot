#!/bin/zsh
# The aqueduct isle (studies/aqueduct_isle.gd). The whole loop: find the
# lodestone on the floating stone east of the heel stone (E / pad A picks it
# up, E keeps it), walk back to the parked plane and Space (pad A) by it to
# take off, fly where the nose arrow points; land by hand on the turf (the
# game's rules: brake or drift to a stop, then F / pad Y gets out). Near
# the shard an arch rises out of the cloud past it; fly through it, wait,
# and the Sundered line starts rising ahead: big pieces of the real
# Sundered hall end to end, a sidestep now and then (docs/design/isle-hall-line.md, isle-hall-chain.md).
#   ./run-aqueduct-isle.command                 the whole loop, from on foot
#   ./run-aqueduct-isle.command --near-ring     in the plane, stone seated, 260 m before the ring
#   ./run-aqueduct-isle.command --carry --fly   in the plane, stone seated, by the isle
#   ./run-aqueduct-isle.command --no-chain      the shard only (the old arrival chime)
#   ./run-aqueduct-isle.command --near-ring --autopilot   sit back: it flies the line for you
#   ./run-aqueduct-isle.command --chain-style=halls       the old hall chain (four chunks, a long S)
#   --line-bays=<a-b> (8-11)  --line-gap=<a-b> (14-26)  --line-run=<a-b> (2-4)  --line-turn=sidestep|bend|mix
#   --line-look=real|greybox (real: each piece the game's own Sundered hall, basalt + overgrowth on its ridge island; greybox: round 1's boxes)
#   --line-jog=<m> (48)  --line-jog-gap=<m> (120)  --line-bend=<deg> (26)  --line-ahead=<m> (260)  --line-keep=<n> (6)  --line-seed=<n>
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
