#!/bin/zsh
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-game-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

# The game, v1 (docs/design/roguelike/game-v1-launcher.md). It opens on the
# title (studies/game_title.tscn); Space / A there opens the run with these
# same flags. Flags after the `--`:
#   --shape=sprawl     the run's first region; the run alternates sprawl and
#                      ring by depth on its own (layer_shapes.gd RUN)
#   --world=under      every region underground: v1 is the Olmec city only
#                      (game-v1-brief.md); drop it to open into the sky
#                      after the first two regions (layer-round13-worlds.md)
#   --under-look=torch   the underground regions in the torch look
#   (no --seed=)       the run draws a new seed each launch; the card's R
#                      keeps the same one, Space draws another
#   (no --dragon-live) no dragon; the plane is not in this scene
#   the Olmec's headless body is on by default (--knob=bodies=1, the hunt
#   --body-chase on), so nothing is passed for it
# Extra flags win, e.g. ./run-game.command --seed=7 --shape=ring.
print -r -- "Opening ZenScape. Launch log: $LAUNCH_LOG"
"$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/game_title.tscn -- --no-title --shape=sprawl --world=under --under-look=torch "$@" 2>&1 | tee "$LAUNCH_LOG"
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
