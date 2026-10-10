#!/usr/bin/env python3
"""Check every kit isle's layout fingerprint against a base
(tools/kit_isle_fingerprints.sh writes both):

  python3 tools/kit_isle_fp_check.py BASE_DIR NEW_DIR

Per isle: the start and every collision shape must match exactly (the
`FP start` and `FP shapes` lines), and every ray's hit within 2 mm
(tools/kit_isle_fp_compare.py). Exit 1 on any difference.
"""
import subprocess
import sys
from pathlib import Path

base, new = Path(sys.argv[1]), Path(sys.argv[2])
ok = True
for isle in ["aqueduct", "bell", "cloister", "gorge", "colonnade"]:
    a = [l for l in (base / f"{isle}.txt").read_text().splitlines() if l.startswith(("FP start", "FP shapes"))]
    b_path = new / f"{isle}.txt"
    if not b_path.exists():
        print(f"{isle}: no new fingerprint")
        ok = False
        continue
    b = [l for l in b_path.read_text().splitlines() if l.startswith(("FP start", "FP shapes"))]
    shapes = "shapes same" if a == b else "SHAPES DIFFER:\n  " + "\n  ".join(sorted(set(a) ^ set(b)))
    r = subprocess.run([sys.executable, str(Path(__file__).with_name("kit_isle_fp_compare.py")), str(base / f"{isle}.rays"), str(new / f"{isle}.rays")],
                       capture_output=True, text=True)
    last = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.stderr
    print(f"{isle}: {shapes}; {last}")
    if a != b or r.returncode != 0:
        ok = False
        for line in r.stdout.strip().splitlines()[:-1][:5]:
            print("   ", line)
sys.exit(0 if ok else 1)
