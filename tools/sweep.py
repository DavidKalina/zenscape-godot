#!/usr/bin/env python3
"""Runs a driver or a scene over every combination of seeds, knob values
and flags, a few at a time, and prints one table: a row per combination, a
column per axis and per value it reported.

  python tools/sweep.py scratch/gap_check.gd --seed 1..6 --knob gulf=40,60,80 -j 3
  python tools/sweep.py studies/stun_yard.tscn --seed 1..4                  # smoke each
  python tools/sweep.py scratch/jump.gd --set wanderer-scale=0.8,1.0 -- --tries=5

Axes become the scene's launch flags (after --scene-args): `--seed 1..5`
is --seed=1 ... --seed=5, `--knob gulf=40,60`
--knob=gulf=40, `--set name=a,b` --name=a. Ranges: 1..5, 0..20..5 (by 5).
Args after `--` go to the driver as they are. A .tscn target runs the smoke
driver (tools/harness/smoke.gd) on it.

The columns: the driver's RESULT values (scalars; dicts flattened a level),
or each ROW line as its own row if it printed ROWs; `ok` (exit 0, no
errors) and `s` (seconds). Errors are shown under the table. --csv / --json
FILE save it. Nothing is edited: a knob is a flag, never a sed of the source.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import csv
import itertools
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import godot  # noqa: E402
from drive import res_path  # noqa: E402


def values(spec: str) -> list[str]:
    out: list[str] = []
    for part in spec.split(","):
        if ".." in part:
            bits = [int(b) for b in part.split("..")]
            step = bits[2] if len(bits) == 3 else 1
            out += [str(v) for v in range(bits[0], bits[1] + 1, max(1, step))]
        elif part:
            out.append(part)
    return out


def flatten(d: dict) -> dict:
    out = {}
    for k, v in d.items():
        if isinstance(v, dict) and len(v) <= 12:
            for k2, v2 in v.items():
                out[f"{k}.{k2}"] = v2
        elif isinstance(v, (list, dict)):
            out[k] = json.dumps(v, separators=(",", ":"))
        else:
            out[k] = v
    return out


def run_combo(target: str, combo: dict, args: argparse.Namespace, driver_args: list[str]) -> list[dict]:
    flags = []
    for name, value in combo.items():
        flags.append(f"--knob={name[5:]}={value}" if name.startswith("knob:") else f"--{name}={value}")
    if target.endswith(".tscn"):
        scene = target[6:] if target.startswith("res://") else target
        run_args = ["-s", "res://tools/harness/smoke.gd", "--fixed-fps", "60", "--",
                    f"--scene={scene}", f"--frames={args.frames}"]
    else:
        run_args = ["-s", res_path(target), "--fixed-fps", "60", "--"]
    run_args += [f"--timeout={args.timeout}", *driver_args, "--scene-args", *flags]
    r = godot.run(run_args, timeout=args.timeout + 30, check_import=False)
    result, rows = {}, []
    for line in r["output"].splitlines():
        try:
            if line.startswith("RESULT "):
                result = json.loads(line[7:])
            elif line.startswith("ROW "):
                rows.append(json.loads(line[4:]))
        except ValueError:
            pass
    ok = godot.status(r) == 0
    base = {k.replace("knob:", ""): v for k, v in combo.items()}
    tail = {"ok": "yes" if ok else ("TIMEOUT" if r["timed_out"] else "NO"), "s": round(r["seconds"], 1)}
    errors = r["diag"]["errors"] + [l for l in r["output"].splitlines() if l.startswith("FAIL")]
    if rows:
        return [{**base, **flatten(row), **tail, "_errors": errors if i == 0 else []} for i, row in enumerate(rows)]
    skip = {"frames", "seconds"}
    return [{**base, **flatten({k: v for k, v in result.items() if k not in skip}), **tail, "_errors": errors}]


def table(rows: list[dict]) -> str:
    cols: list[str] = []
    for row in rows:
        for k in row:
            if k != "_errors" and k not in cols:
                cols.append(k)
    cols = [c for c in cols if c not in ("ok", "s")] + ["ok", "s"]

    def cell(v):
        if isinstance(v, float):
            return f"{v:.3g}" if abs(v) < 1000 else f"{v:.0f}"
        return "" if v is None else str(v)
    grid = [[cell(r.get(c)) for c in cols] for r in rows]
    width = [min(40, max(len(c), *(len(g[i]) for g in grid))) for i, c in enumerate(cols)]
    lines = ["  ".join(c.ljust(w)[:w] for c, w in zip(cols, width))]
    lines.append("  ".join("-" * w for w in width))
    lines += ["  ".join(v.ljust(w)[:w] for v, w in zip(g, width)) for g in grid]
    return "\n".join(lines)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    argv = sys.argv[1:]
    driver_args: list[str] = []
    if "--" in argv:
        i = argv.index("--")
        argv, driver_args = argv[:i], argv[i + 1:]
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("target", help="a driver .gd or a scene .tscn")
    p.add_argument("--seed", help="e.g. 1..10 or 1,4,9")
    p.add_argument("--knob", action="append", default=[], help="name=v1,v2 (repeatable)")
    p.add_argument("--set", action="append", default=[], help="flag=v1,v2: --flag=v (repeatable)")
    p.add_argument("-j", "--jobs", type=int, default=4)
    p.add_argument("--timeout", type=int, default=300, help="seconds per combination")
    p.add_argument("--frames", type=int, default=400, help="for a .tscn target")
    p.add_argument("--csv")
    p.add_argument("--json")
    args = p.parse_args(argv)
    axes: dict[str, list[str]] = {}
    if args.seed:
        axes["seed"] = values(args.seed)
    for k in args.knob:
        name, _, spec = k.partition("=")
        axes["knob:" + name] = values(spec)
    for k in args.set:
        name, _, spec = k.partition("=")
        axes[name.lstrip("-")] = values(spec)
    combos = [dict(zip(axes, vs)) for vs in itertools.product(*axes.values())] or [{}]
    why = godot.import_needed()
    if why:
        print(f"== import needed: {why}", flush=True)
        godot.run_import(godot.find_godot())
    print(f"== {len(combos)} runs of {args.target}, {args.jobs} at a time", flush=True)
    rows: list[dict] = []
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as pool:
        for i, got in enumerate(pool.map(lambda c: run_combo(args.target, c, args, driver_args), combos)):
            rows += got
            print(f"   {i + 1}/{len(combos)} {' '.join(f'{k}={v}' for k, v in combos[i].items())}: {got[0]['ok']}", flush=True)
    print(table(rows))
    bad = [r for r in rows if r["_errors"]]
    for r in bad:
        axes_text = " ".join(f"{k.replace('knob:', '')}={r.get(k.replace('knob:', ''))}" for k in axes)
        print(f"\n-- {axes_text}:")
        for e in r["_errors"][:4]:
            print("   " + e.replace("\n", "\n   "))
    clean = [{k: v for k, v in r.items() if k != "_errors"} for r in rows]
    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as f:
            cols = list(dict.fromkeys(k for r in clean for k in r))
            w = csv.DictWriter(f, fieldnames=cols)
            w.writeheader()
            w.writerows(clean)
    if args.json:
        Path(args.json).write_text(json.dumps(clean, indent=1), encoding="utf-8")
    passed = sum(r["ok"] == "yes" for r in rows)
    print(f"== sweep: {passed}/{len(rows)} ok")
    return 0 if passed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
