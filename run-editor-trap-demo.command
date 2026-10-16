#!/bin/zsh
# The traps demo in the motif editor (studies/motif_editor.tscn, spec
# docs/design/motif-editor/spec-editor-traps.md): motifs/authored/
# editor_trap_demo.json, Editor Hill's terraced dome with three traps on the
# way from the spawn (east) to the far rim (west): a wind blaster deck on the
# pilot grid (step on its plate and keep moving), a seesaw off the crown's
# west lip, and loose voussoirs (count 6) off the next lip down: run them.
# P plays from the spawn (Shift+P under the camera), P again back to
# editing with every trap as built. H the pilot grid, G the full look,
# click a trap for its knobs, Ctrl+S saves.
#   ./run-editor-trap-demo.command
# The same by hand:
#   Godot --path . --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/motif_editor.tscn -- --no-title --load=editor_trap_demo
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-editor-trap-demo-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

print -r -- "Opening the traps demo in the motif editor. Launch log: $LAUNCH_LOG"
"$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/motif_editor.tscn -- --no-title --load=editor_trap_demo "$@" 2>&1 | tee "$LAUNCH_LOG"
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
