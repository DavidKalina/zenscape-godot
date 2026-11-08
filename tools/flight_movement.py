#!/usr/bin/env python3
"""How continuously a run moves (flow), per station and pilot, with a
timeline of where the straights are. Reads flight-study run JSONs and
measures the flown direction (heading and pitch, not the stick), so stick
noise the plane doesn't follow doesn't count.

The numbers are FlightMetrics `flow` (scripts/flight_metrics.gd), which
every run saved since round 3 carries in its metrics; this recomputes them
the same way from the ticks so older runs and the timeline work too:

  swing       how fast the flight direction swings: the heading's and the
              pitch's change over the last SMOOTH s, sqrt(yaw^2 + pitch^2),
              deg/s
  still       share of the ticks swinging under STILL deg/s: flying straight
  straights   still spells of at least LONG s; longest, the longest one
  yaw share   the sideways share of the swing
  rev/s       sign changes of the yaw rate and the pitch rate past REVERSE
              deg/s, per s: the jerkiness guard (a wobble reverses often)

  python3 tools/flight_movement.py --station sundered
  python3 tools/flight_movement.py --station all --timeline
  python3 tools/flight_movement.py --dir /path/to/flight_runs --station sundered_flow --timeline
"""
import argparse
import glob
import json
import math
import os
import statistics as st
from collections import defaultdict

RUNS = os.path.expanduser("~/Library/Application Support/Godot/app_userdata/"
	"ZenScape/flight_runs")
# FlightMetrics FLOW_SMOOTH, FLOW_STILL, FLOW_STRAIGHT, FLOW_REVERSE.
SMOOTH = 0.25
STILL = 6.0
LONG = 0.5
REVERSE = 10.0


def wrap(a):
	return (a + math.pi) % (2 * math.pi) - math.pi


def movement(run):
	tk = run["ticks"]
	t, head, pitch = tk["t"], tk["heading"], tk["pitch"]
	n = len(t)
	yaw, pit = [], []
	j = 0
	for i in range(n):
		while j < i and t[j + 1] <= t[i] - SMOOTH + 1e-5:
			j += 1
		span = t[i] - t[j]
		if span <= 0:
			yaw.append(0.0); pit.append(0.0)
			continue
		yaw.append(wrap(head[i] - head[j]) / span)
		pit.append((pitch[i] - pitch[j]) / span)
	rate = [math.degrees(math.hypot(y, p)) for y, p in zip(yaw, pit)]
	spells, start = [], None
	for i, r in enumerate(rate + [math.inf]):
		calm = r < STILL
		if calm and start is None:
			start = t[i]
		elif not calm and start is not None:
			spells.append((t[i] if i < n else t[-1]) - start)
			start = None
	signs, rev = [0, 0], 0
	for y, p in zip(yaw, pit):
		for k, v in enumerate((y, p)):
			if abs(math.degrees(v)) < REVERSE:
				continue
			s = 1 if v > 0 else -1
			if signs[k] and s != signs[k]:
				rev += 1
			signs[k] = s
	dur = run.get("result", {}).get("duration") or (t[-1] - t[0])
	ya, pa = sum(abs(v) for v in yaw), sum(abs(v) for v in pit)
	return {
		"dur": dur,
		"swing": st.mean(rate),
		"still": sum(1 for r in rate if r < STILL) / n,
		"straights": sum(1 for s in spells if s >= LONG - 1e-5),
		"longest": max(spells, default=0.0),
		"yaw_share": ya / (ya + pa) if ya + pa else 0.0,
		"rev": rev / dur if dur else 0.0,
		"rate": rate, "t": t,
	}


def strip(m, step=0.25):
	"""One char per `step` s: ' ' straight, then . : - = + * # swinging harder."""
	marks = " .:-=+*#"
	out, t, rate = "", m["t"], m["rate"]
	i = 0
	edge = t[0]
	while i < len(rate):
		edge += step
		k = i
		while k < len(rate) and t[k] < edge:
			k += 1
		r = max(rate[i:max(k, i + 1)])
		out += " " if r < STILL else marks[min(len(marks) - 1, 1 + int(r / 15))]
		i = max(k, i + 1)
	return out


def pilot(run, name):
	who = str(run.get("pilot", "?"))
	return who.split(":", 1)[-1] if who.startswith("bot:") else who


def main():
	ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	ap.add_argument("--station", default="sundered", help="a station id, or all")
	ap.add_argument("--dir", default=RUNS)
	ap.add_argument("--timeline", action="store_true")
	a = ap.parse_args()
	groups = defaultdict(list)
	for f in sorted(glob.glob(os.path.join(a.dir, "*.json"))):
		try:
			d = json.load(open(f, encoding="utf-8"))
		except Exception:
			continue
		if "ticks" not in d or not d["ticks"].get("heading"):
			continue
		if a.station != "all" and d.get("station") != a.station:
			continue
		groups[(d["station"], d.get("station_hash", ""), pilot(d, f))].append((os.path.basename(f), movement(d)))
	order = {"human": 0, "perfect": 1, "sharp": 2, "decent": 3, "sloppy": 4}
	key = lambda kv: (kv[0][0], kv[0][1], order.get(kv[0][2], 9))
	print(f"still = flown direction swinging < {STILL} deg/s; straights = still >= {LONG} s; rev/s = yaw/pitch rate sign changes past {REVERSE} deg/s\n")
	print(f"{'station':14} {'hash':12} {'pilot':8} {'n':>3} {'dur s':>6} {'swing°/s':>9} {'still':>6} {'straights':>9} {'longest s':>9} {'yaw share':>9} {'rev/s':>6}")
	for (stn, digest, who), rs in sorted(groups.items(), key=key):
		m = [r[1] for r in rs]
		f = lambda k: st.mean(x[k] for x in m)
		print(f"{stn:14} {digest:12} {who:8} {len(m):>3} {f('dur'):6.1f} {f('swing'):9.1f} {f('still'):6.0%} {f('straights'):9.1f} {f('longest'):9.2f} {f('yaw_share'):9.0%} {f('rev'):6.2f}")
	if a.timeline:
		print("\ntimeline, one char per 0.25 s:  ' ' straight  . : - = + * # swinging harder")
		for (stn, digest, who), rs in sorted(groups.items(), key=key):
			if who not in ("human", "perfect", "sharp"):
				continue
			for name, m in rs[:2]:
				print(f"{stn:14} {who:8} |{strip(m)}|")


if __name__ == "__main__":
	main()
