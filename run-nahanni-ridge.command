#!/bin/zsh
# The Nahanni map, started in the air short of the fin ridge's south end,
# pointed down its length (the ridge: scripts/endless/world/profiles/nahanni.gd
# `pieces`). Double-click, or from a terminal
#   ./run-nahanni-ridge.command
#   ./run-nahanni-ridge.command --weight=heavy
# Extra arguments are the game's launch flags (a later --at= / --alt= /
# --heading= wins). Runs tools/play.py like run-endless-flight.command.
set -u
cd "${0:A:h}"
if [[ -n "${GODOT_BIN:-}" ]]; then export GODOT="$GODOT_BIN"; fi
python3 tools/play.py -- --world=nahanni --at=-170,1000 --alt=60 --heading=0 "$@"
launch_status=$?
if (( launch_status != 0 )) && [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
exit "$launch_status"
