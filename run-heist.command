#!/bin/zsh
set -u
PROJECT_DIR="${0:A:h}"
GODOT_BIN="${GODOT_BIN:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LAUNCH_LOG="${TMPDIR:-/tmp}/zenscape-heist-launch.log"

if [[ ! -x "$GODOT_BIN" ]]; then
  print -r -- "Godot could not be found at: $GODOT_BIN" | tee "$LAUNCH_LOG"
  print -r -- "Set GODOT_BIN to your Godot executable and try again."
  if [[ -t 0 ]]; then read -r "launch_reply?Press Return to close this window."; fi
  exit 1
fi

# The run's ledger is a throwaway file in /tmp, never the player's save;
# pass --ledger=<path> to use another.
LEDGER_ARG=("--ledger=${TMPDIR:-/tmp}/zenscape-heist-ledger.json")
for a in "$@"; do [[ "$a" == --ledger=* ]] && LEDGER_ARG=(); done

print -r -- "Opening the heist level. Launch log: $LAUNCH_LOG"
"$GODOT_BIN" --path "$PROJECT_DIR" --rendering-method forward_plus --windowed --resolution 1440x900 res://studies/heist_level.tscn -- --no-title "${LEDGER_ARG[@]}" "$@" 2>&1 | tee "$LAUNCH_LOG"
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
