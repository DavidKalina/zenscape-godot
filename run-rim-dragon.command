#!/bin/zsh
# The rim dragon (scripts/rim_dragon.gd, docs/design/rim-dragon.md), an
# experiment on the aqueduct isle: it rises out of the cloud sea, swoops over
# the isle, grips the east rim and blows gales across it. Get the treasure
# off its tongue between gusts; get behind stone when it breathes in.
#   ./run-rim-dragon.command                     the whole cycle, from the flight
#   ./run-rim-dragon.command --dragon-perched    already on the rim
#   --dragon-delay=<s> (5)  --dragon-fly=<s> (24)  --dragon-calm (gusts harmless)
#   --dragon-skip=<s> (run it on at the start)
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-rim-dragon-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

print -r -- "Opening the rim dragon on the aqueduct isle. Launch log: $LAUNCH_LOG"
"$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/aqueduct_isle.tscn -- --no-title --dragon "$@" 2>&1 | tee "$LAUNCH_LOG"
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
