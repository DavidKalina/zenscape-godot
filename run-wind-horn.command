#!/bin/zsh
# The wind-horn study (studies/wind_horn_study.tscn,
# docs/design/roguelike/wind-horn-round1.md): the ruin kit's stone wind-horn
# on flat ground; its head tracks you, draws breath and blows on a loop.
# P knocks it out for a few seconds. 1 front, 2 30 m out, 3 on the pedestal.
# Extra args pass through, e.g.
#   ./run-wind-horn.command --horn-weathered=1 --horn-seed=3
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-wind-horn-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

print -r -- "Opening the wind-horn study (P knock out, 1-3 stations). Launch log: $LAUNCH_LOG"
"$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/wind_horn_study.tscn -- --no-title "$@" 2>&1 | tee "$LAUNCH_LOG"
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
