#!/bin/zsh
# The Godot editor on this project, with main pulled first: double-click, or
# from a terminal  ./open-godot.command
# tools/play.py --editor pulls origin's main (fast-forward only; it says why
# when it can't), warns when the native terrain kernels are out of date, then
# opens the editor on this checkout and leaves it running (GODOT_BIN or
# GODOT picks another Godot).
set -u
cd "${0:A:h}"
if [[ -n "${GODOT_BIN:-}" ]]; then export GODOT="$GODOT_BIN"; fi
python3 tools/play.py --editor "$@"
launch_status=$?
if (( launch_status != 0 )) && [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
exit "$launch_status"
