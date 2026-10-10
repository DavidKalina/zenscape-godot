#!/usr/bin/env python3
"""Compare two kit isle ray dumps (tools/kit_isle_fingerprint.gd --dump=PATH).

  python3 tools/kit_isle_fp_compare.py OLD NEW [--tol=0.002]

Every ray's hit must be there in both, its height within TOL m (a
ray on an edge where two shapes meet may answer with either's normal: those
are counted, not failed); prints the mismatches (at most 20) and a summary line,
exit 1 on any.
"""
import sys


def load(path):
    out = {}
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        key, rest = line.split(":", 1)
        y, n = rest.split("/")
        out[key] = (float(y), tuple(float(v) for v in n.split(",")))
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    tol = 0.002
    for a in sys.argv[1:]:
        if a.startswith("--tol="):
            tol = float(a.split("=", 1)[1])
    old, new = load(args[0]), load(args[1])
    bad = []
    worst = 0.0
    edges = 0
    for key in sorted(set(old) | set(new)):
        if key not in old or key not in new:
            bad.append(f"{key}: only in {'old' if key in old else 'new'}")
            continue
        (ya, na), (yb, nb) = old[key], new[key]
        dy = abs(ya - yb)
        worst = max(worst, dy)
        if dy > tol:
            bad.append(f"{key}: {ya:.3f} {na} -> {yb:.3f} {nb}")
        elif max(abs(p - q) for p, q in zip(na, nb)) > 0.03:
            # The same height, another face: a ray on an edge where two
            # shapes meet (which one answers depends on the bodies' order).
            edges += 1
    for b in bad[:20]:
        print(b)
    print(f"{len(old)} rays old, {len(new)} new, {len(bad)} differ, {edges} on an edge, worst height change {worst:.4f} m")
    sys.exit(1 if bad else 0)


main()
