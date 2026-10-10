#!/bin/zsh
# The real game (studies/cozy_worlds.tscn) with the moments set pieces in the
# sky (--moments), no title, starting in the plane high over home (--skydive).
# In the plane, N hops to the next set piece (Shift+N back); every set piece
# is listed with its distance in the log. Extra args pass through, e.g.
#   ./run-moments-world.command --moments-at=3          # start on set piece 3's way in
#   ./run-moments-world.command --challenge-time=12     # every challenge timed
#   ./run-moments-world.command --challenge-mode=chain  # challenge collectibles one at a time
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-moments-world-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

print -r -- "Opening ZenScape with the moments set pieces (in the plane: N hops to the next one). Launch log: $LAUNCH_LOG"
"$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/cozy_worlds.tscn -- --moments --no-title --skydive "$@" 2>&1 | tee "$LAUNCH_LOG"
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
