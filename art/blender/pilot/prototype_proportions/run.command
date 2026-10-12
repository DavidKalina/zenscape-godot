#!/bin/zsh
# PROTOTYPE: serves the repo root (so the page can load assets/models/pilot.glb)
# and opens the pilot proportions page. Ctrl-C to stop.
cd "$(dirname "$0")/../../../.."
PORT=8765
( sleep 1; open "http://localhost:$PORT/art/blender/pilot/prototype_proportions/index.html" ) &
python3 -m http.server $PORT
