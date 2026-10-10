#!/usr/bin/env python3
"""Reads character study recordings (studies/character_runs/*.json, made with
F5 in studies/character_study.tscn) and prints what they show: how much of the
run was moving, hop chains (reach by takeoff speed, room used, how much they
weave), re-hop timing against the chain window, when twirls come, wall runs,
wall kick spacing, ledges taken and the heights reached.

  python3 tools/character_run_report.py               # the newest recording
  python3 tools/character_run_report.py --all         # every recording
  python3 tools/character_run_report.py PATH [PATH..] # these
"""
import argparse
import glob
import json
import math
import os

RUNS = os.path.join(os.path.dirname(__file__), "..", "studies", "character_runs")
CHAIN_WINDOW = 0.2
TAKEOFFS = ("long", "slide_jump", "jump", "pump", "side_flip", "wall_jump", "wallrun_jump")


def flat(a, b):
    return math.dist((a[0], a[2]), (b[0], b[2]))


def report(path):
    d = json.load(open(path))
    t = d["ticks"]
    n = len(t["dt"])
    times = []
    clock = 0.0
    for dt in t["dt"]:
        clock += dt
        times.append(clock)
    beats = d["beats"]
    s = d.get("summary", {})
    print(f"== {os.path.basename(path)}: \"{d.get('label', '')}\" (station {d.get('station')})")
    still = sum(t["dt"][i] for i in range(n) if t["speed"][i] < 0.3)
    plain = sum(t["dt"][i] for i in range(n) if t["state"][i] in ("ground", "skid"))
    print(f"{clock:.1f} s: standing still {still:.1f} s, plain running {plain:.1f} s, moves/air {clock - plain:.1f} s; "
          f"{s.get('across', 0):.0f} m start to end, {s.get('path', 0):.0f} m travelled, fastest {s.get('fastest', 0):.1f} m/s")
    moves = {k: v for k, v in s.get("moves", {}).items() if not k.endswith(" off") and k != "landed"}
    print("moves: " + ", ".join(f"{k} {v}" for k, v in sorted(moves.items(), key=lambda kv: -kv[1])))

    lands = [b for b in beats if b["what"] == "landed"]
    hops = [b for b in beats if b["what"] in ("long", "slide_jump")]
    reach = {}
    for b in hops:
        after = [l for l in lands if l["t"] > b["t"]]
        if after:
            reach.setdefault(round(b["speed"]), []).append(flat(b["at"], after[0]["at"]))
    if reach:
        print("hop reach by takeoff speed: " + "; ".join(
            f"~{k} m/s {min(v):.1f}-{max(v):.1f} m ({len(v)})" for k, v in sorted(reach.items())))

    rehops = []
    for l in lands:
        nxt = [b for b in beats if b["t"] > l["t"] and b["what"] in TAKEOFFS]
        if nxt and nxt[0]["t"] - l["t"] < 0.5:
            rehops.append(nxt[0]["t"] - l["t"])
    if rehops:
        rehops.sort()
        late = sum(1 for r in rehops if r > CHAIN_WINDOW)
        print(f"re-hop after landing: median {rehops[len(rehops) // 2] * 1000:.0f} ms, "
              f"{late}/{len(rehops)} past the {CHAIN_WINDOW * 1000:.0f} ms chain window")

    chains, cur = [], []
    for b in hops:
        if cur and b["t"] - cur[-1]["t"] < 1.2:
            cur.append(b)
        else:
            if len(cur) > 1:
                chains.append(cur)
            cur = [b]
    if len(cur) > 1:
        chains.append(cur)
    for ch in chains:
        pts = [c["at"] for c in ch]
        run = sum(flat(pts[i], pts[i + 1]) for i in range(len(pts) - 1))
        heads = [math.atan2(pts[i + 1][2] - pts[i][2], pts[i + 1][0] - pts[i][0]) for i in range(len(pts) - 1)]
        turn = sum(abs((heads[i + 1] - heads[i] + math.pi) % (2 * math.pi) - math.pi) for i in range(len(heads) - 1))
        print(f"  chain at {ch[0]['t']:.1f} s: {len(ch)} hops, {run:.0f} m, turned {math.degrees(turn):.0f}°, "
              f"top {max(c['speed'] for c in ch):.1f} m/s, height {pts[-1][1] - pts[0][1]:+.1f} m")

    twirls = []
    for b in beats:
        if b["what"] != "twirl":
            continue
        before = [x for x in beats if x["t"] <= b["t"] and x["what"] in TAKEOFFS + ("wallrun on",)]
        if before:
            twirls.append(f"{before[-1]['what']} +{b['t'] - before[-1]['t']:.2f}s")
    if twirls:
        print("twirls, after what: " + ", ".join(twirls))

    for b in beats:
        if b["what"] == "wallrun on":
            off = next((x for x in beats if x["t"] > b["t"] and x["what"] in ("wallrun off", "wallrun_jump")), None)
            if off:
                print(f"  wall run at {b['t']:.1f} s from {b['speed']:.1f} m/s: {flat(b['at'], off['at']):.1f} m along, "
                      f"ended by {off['what']}, height {off['at'][1] - b['at'][1]:+.2f} m")

    kicks = [b for b in beats if b["what"] in ("wall_jump", "wallrun_jump")]
    for a, b in zip(kicks, kicks[1:]):
        if b["t"] - a["t"] < 1.5:
            print(f"  kick to kick {a['t']:.1f} -> {b['t']:.1f} s: walls {flat(a['at'], b['at']):.2f} m apart, "
                  f"{b['at'][1] - a['at'][1]:+.2f} m")
    for b in beats:
        if b["what"].startswith("grabbed") or b["what"] == "climbed":
            print(f"  {b['what']} at {b['t']:.1f} s, height {b['at'][1]:.2f} m")
    ys = t["y"]
    top = max(range(n), key=lambda i: ys[i])
    print(f"highest {ys[top]:.2f} m at {times[top]:.1f} s ({t['x'][top]:.1f}, {t['z'][top]:.1f})")
    print()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*")
    ap.add_argument("--all", action="store_true")
    args = ap.parse_args()
    paths = args.paths or sorted(glob.glob(os.path.join(RUNS, "*.json")))
    if not args.paths and not args.all:
        paths = paths[-1:]
    if not paths:
        print("no recordings under studies/character_runs/ yet (F5 in the character study)")
    for p in paths:
        report(p)


if __name__ == "__main__":
    main()
