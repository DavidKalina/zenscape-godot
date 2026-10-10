#!/bin/zsh
# The hall chain study (studies/hall_chain.tscn, docs/design/hall-chain.md):
# fly through the Sundered hall and the next one rises out of the clouds
# ahead, then the next, for as long as you fly. Starts in the plane.
# R the chain again, N the next hall now, P autopilot, C camera, F plane.
# Extra args pass through, e.g.
#   ./run-hall-chain.command --autopilot           # sit back and watch it
#   ./run-hall-chain.command --chain-at=0.5 --chain-gap=50   # later, tighter
#   ./run-hall-chain.command --chain-mirror=off             # every hall the same way round
#   ./run-hall-chain.command --chain-keep=3        # the oldest sinks sooner
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-hall-chain-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

print -r -- "Opening the hall chain study (R again, N next hall, P autopilot, C camera, F plane). Launch log: $LAUNCH_LOG"
"$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/hall_chain.tscn -- --no-title "$@" 2>&1 | tee "$LAUNCH_LOG"
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
