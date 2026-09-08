#!/bin/zsh
set -e
PROJECT_DIR="${0:A:h}"
exec "$PROJECT_DIR/run-garden.command" --garden-file="$PROJECT_DIR/selection-garden.json" "$@"
