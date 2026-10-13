#!/bin/zsh
# The tower shell study (studies/tower_shell_study.tscn,
# docs/design/roguelike/tower-shell-round1.md): the ruin kit's broken tower
# with a wall-kick chimney inside, on flat ground. Walk in at the door, jump
# at a side wall, Space at each wall to kick up to the rim. R the doorway,
# 1 door, 2 shaft, 3 rim. Extra args pass through, e.g.
#   ./run-tower-shell.command --tower-height=16        # a taller shell
#   ./run-tower-shell.command --tower-weathered=1      # more and bigger breaches
#   ./run-tower-shell.command --tower-open             # the back wall torn away
#   ./run-tower-shell.command --tower-seed=3
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-tower-shell-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

print -r -- "Opening the tower shell study (R doorway, 1-3 stations). Launch log: $LAUNCH_LOG"
"$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/tower_shell_study.tscn -- --no-title "$@" 2>&1 | tee "$LAUNCH_LOG"
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
