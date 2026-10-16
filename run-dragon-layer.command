#!/bin/zsh
# The roost's dragon live over a generated layer: he wakes ~3 s after the layer
# stands, swoops
# low over an isle, watches from a high circuit, grips a roomy isle's rim.
#   ./run-dragon-layer.command                        sprawl seed 11
#   ./run-dragon-layer.command --shape=ring --seed=2  the ring
#   keys: U wake him, J swoop next, K grip next, H back to his circuit,
#         V his camera (chase, orbit, look from here, off), G he lets go
#   --dragon-first=grip|swoop|monitor  --dragon-monitor=<s> (25)
#   --dragon-grip-hold=<s> (22)  --dragon-swoop-over=<m> (30)
#   --dragon-wake-at=<s> (3)  --dragon-no-blast  --dragon-log
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-dragon-layer-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

print -r -- "Opening the dragon over a generated layer. Launch log: $LAUNCH_LOG"
"$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --world=sky --dragon-live "$@" 2>&1 | tee "$LAUNCH_LOG"
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
