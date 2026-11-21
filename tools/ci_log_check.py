#!/usr/bin/env python3
"""Fail a CI step on SCRIPT ERROR / ERROR lines in a Godot log, bar exit noise.

The exit-time leak reports ("N resources still in use at exit", "Pages in use
exist at exit", ...) are the same noise tools/godot.py drops (NOISE); they are
not failures of the import, test or export.

  python tools/ci_log_check.py import.log
"""
from pathlib import Path
import sys

from godot import NOISE

errors = []
for name in sys.argv[1:]:
    for line in Path(name).read_text(errors='replace').splitlines():
        if ('SCRIPT ERROR' in line or 'ERROR:' in line) and not NOISE.match(line):
            errors.append(f'{name}: {line}')
for line in errors[:40]:
    print(line)
if errors:
    sys.exit(f'{len(errors)} error line(s)')
print(f'OK {", ".join(sys.argv[1:])}: no errors (exit noise dropped)')
