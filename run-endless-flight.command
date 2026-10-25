#!/bin/zsh
# Endless flight on the Mac: double-click, or from a terminal
#   ./run-endless-flight.command
#   ./run-endless-flight.command --weight=heavy
# Extra arguments are the game's launch flags. tools/play.py finds Godot
# (GODOT_BIN or GODOT picks another), imports first and keeps a launch log.
set -u
cd "${0:A:h}"
if [[ -n "${GODOT_BIN:-}" ]]; then export GODOT="$GODOT_BIN"; fi
python3 tools/play.py -- "$@"
launch_status=$?
if (( launch_status != 0 )) && [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
exit "$launch_status"
