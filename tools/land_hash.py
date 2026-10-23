#!/usr/bin/env python3
"""The endless land's fingerprint for a seed, to check two machines grow the
same land (co-op sends only the seed; docs/design/endless-flight/native-land-handoff.md).

  python tools/land_hash.py                      # seed 1, the native field if built
  python tools/land_hash.py --seed 7 -- --land-native=0
  python tools/land_hash.py --compare a.txt b.txt

Runs tools/land_hash.gd headless: heights, meadows and the river at about
78,000 fixed spots and six whole chunks, hashed over the raw float bits
(`exact`) and over the heights rounded to the millimetre (`mm`), and dumped
one line a spot to scratch/land_hash/seed<N>_<os>_<arch>_<field>.txt
(--dump FILE elsewhere). Args after `--` are the land's flags.

Run it on each machine and compare the `exact` lines. If they differ, copy
one dump to the other machine and run --compare on the two: it prints how
many spots differ and by how much (the first few, with where).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot  # noqa: E402


def compare(a: str, b: str) -> int:
    def read(path: str) -> tuple[dict, dict]:
        head, rows = {}, {}
        for line in Path(path).read_text().splitlines():
            if line.startswith("# land_hash "):
                head = json.loads(line[len("# land_hash "):])
                continue
            parts = line.split()
            if not parts:
                continue
            if parts[0] == "chunk":
                rows[("chunk", *parts[1:4])] = parts[4]
            else:
                rows[(parts[0], parts[1])] = (parts[2], float(parts[3]), float(parts[4]))
        return head, rows
    ha, ra = read(a)
    hb, rb = read(b)
    print(f"A: {ha.get('machine')} {ha.get('field')} exact {ha.get('exact', '')[:16]}...")
    print(f"B: {hb.get('machine')} {hb.get('field')} exact {hb.get('exact', '')[:16]}...")
    differ, worst, shown = 0, 0.0, 0
    for key, va in ra.items():
        vb = rb.get(key)
        if vb is None or va == vb:
            continue
        differ += 1
        if key[0] == "chunk":
            print(f"  chunk {' '.join(key[1:])} differs")
            continue
        d = abs(va[1] - vb[1])
        worst = max(worst, d)
        if shown < 10:
            print(f"  at x={key[0]} z={key[1]}: height {va[1]:.6f} vs {vb[1]:.6f} (bits {va[0]} vs {vb[0]}), meadow {va[2]:.6f} vs {vb[2]:.6f}")
            shown += 1
    missing = len(set(ra) ^ set(rb))
    print(f"{differ} of {len(ra)} spots differ, worst height {worst:.6g} m" + (f", {missing} spots in only one file" if missing else ""))
    return 0 if differ == 0 and not missing else 1


def main(argv: list[str]) -> int:
    land_args: list[str] = []
    if "--" in argv:
        i = argv.index("--")
        argv, land_args = argv[:i], argv[i + 1:]
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--dump", help="dump file (default scratch/land_hash/seed<N>_<os>_<arch>_<field>.txt)")
    p.add_argument("--compare", nargs=2, metavar=("A", "B"), help="compare two dumps")
    args = p.parse_args(argv)
    if args.compare:
        return compare(*args.compare)
    tmp = godot.ROOT / "scratch" / "land_hash" / f"seed{args.seed}_run.txt"
    tmp.parent.mkdir(parents=True, exist_ok=True)
    dump = Path(args.dump) if args.dump else tmp
    r = godot.run(["--script", "res://tools/land_hash.gd", "--", f"--seed={args.seed}", f"--dump={dump.resolve()}", *land_args], timeout=600)
    found = None
    for line in r["output"].splitlines():
        if line.startswith("LAND_HASH "):
            found = json.loads(line[len("LAND_HASH "):])
    if found is None or godot.status(r) != 0:
        print("\n".join(godot.filtered(r["output"])[0]))
        print(godot.summary(r))
        return 1
    if not args.dump:
        machine = found["machine"].replace(" ", "_").lower()
        named = tmp.with_name(f"seed{args.seed}_{machine}_{found['field']}.txt")
        tmp.replace(named)
        found["dump"] = str(named)
    print(f"seed {found['seed']}  field {found['field']}  {found['machine']}  Godot {found['godot']}")
    print(f"exact {found['exact']}")
    print(f"mm    {found['mm']}")
    print(f"{found['spots']} spots, {found['chunks']} chunks in {found['seconds']:.1f} s; dump {found['dump']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
