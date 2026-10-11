#!/bin/zsh
# The dragon experiment on the aqueduct isle (docs/design/rim-dragon.md).
# Round 3: a wyvern after Smaug (scripts/sky_dragon.gd) rises out of the
# cloud sea and roams the archipelago, now and then low over the isle, its
# shadow sweeping the turf.
#   ./run-rim-dragon.command                     the flying dragon, look c
#   ./run-rim-dragon.command --dragon-pass       starts on a low pass (shadow over the isle ~12 s in)
#   ./run-rim-dragon.command --dragon-attack     round 4: starts on its way in to grab a far isle (~10 s)
#   ./run-rim-dragon.command --dragon-ride       round 5: on foot on the isle it grips; sag, snap, launch (~20 s a cycle); G lets go
#   round 7: it attacks the four ruin motif isles; --dragon-target=bell_spires|cloister_tarn|sundered_gorge|colonnade_spine
#   round 8: --dragon-ride grips your isle, flies off to grip another, comes back; --dragon-ride-repeat = the old instant loop
#   ./run-rim-dragon.command --dragon-look=a     a angular, b carved, c stone and glow (default)
#   V in game cycles the dragon camera: chase, orbit, look from here, off
#   --dragon-watch[=chase|orbit|look] starts on it  --dragon-delay=<s> (3)
#   --dragon-skip=<s> runs it on  --dragon-log prints where it is every 2 s
#   ./run-rim-dragon.command --dragon-rim         round 1's rim grip and gales
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

print -r -- "Opening the dragon on the aqueduct isle. Launch log: $LAUNCH_LOG"
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
