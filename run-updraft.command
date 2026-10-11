#!/bin/zsh
# The aqueduct isle with the updraft (scripts/updraft.gd, docs/design/updraft.md).
# Flow (slides, long jumps, wall runs, pace over 6 m/s) fills a swirl; Q / pad RB
# spends it as a launch straight up, on the ground, out of a slide or in mid-air.
# --no-updraft turns it off. Other flags pass through to the isle.
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-updraft-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

print -r -- "Opening the aqueduct isle with the updraft. Launch log: $LAUNCH_LOG"
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
