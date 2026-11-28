#!/bin/zsh
# The Nahanni map, started in the air on the low side of the scarp in the west
# valley, 600 m short of its face and pointed up the valley at it (the scarp:
# scripts/endless/world/profiles/nahanni.gd `pieces`). Double-click, or from a
# terminal
#   ./run-nahanni-scarp.command
#   ./run-nahanni-scarp.command --weight=heavy
# Extra arguments are the game's launch flags (a later --at= / --alt= /
# --heading= wins). Runs tools/play.py like run-endless-flight.command.
set -u
cd "${0:A:h}"
if [[ -n "${GODOT_BIN:-}" ]]; then export GODOT="$GODOT_BIN"; fi
python3 tools/play.py -- --world=nahanni --at=-2068,-2848 --alt=50 --heading=125 "$@"
launch_status=$?
if (( launch_status != 0 )) && [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
exit "$launch_status"
