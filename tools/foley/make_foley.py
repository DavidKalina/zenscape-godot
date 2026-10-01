#!/usr/bin/env python3
"""Cut CC0 recordings into the tools' foley (docs/scenic/sound.md, "Tool sound").

Two steps:

    tools/foley/make_foley.py candidates   # sources -> numbered takes + audition page
    tools/foley/make_foley.py build        # tools/foley/picks.json -> assets/audio/foley/

`candidates` reads every source fetched by fs_search.py (/tmp/zs-foley/fs/<dir>/)
and the Kenney CC0 packs (/tmp/zs-foley/kenney/), cuts one-shot sources into
single hits at their onsets, and cuts loop sources into seamless loops. Each
take is trimmed, faded, high-passed and matched in loudness, then written to
/tmp/zs-foley/cand/<clip>/<n>.wav with an index, and /tmp/zs-foley/cand/index.html
plays them all for auditioning.

`build` copies the picked takes, in order, to assets/audio/foley/<clip>-<k>.wav
(loops to <clip>.wav) and writes the credits to assets/audio/foley/SOURCES.tsv.

No numpy here: audio is decoded by ffmpeg to 16-bit mono PCM and handled with
the array module.
"""
import array
import csv
import glob
import html
import json
import math
import os
import shutil
import subprocess
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
WORK = "/tmp/zs-foley"
CAND = os.path.join(WORK, "cand")
OUT = os.path.join(ROOT, "assets/audio/foley")
PICKS = os.path.join(ROOT, "tools/foley/picks.json")
RATE = 32000

# Clip -> (kind, fetched dirs, Kenney name prefixes, longest take in seconds, loudness dBFS RMS).
# One-shots are cut at onsets; loops are cut to LOOP_SECONDS and crossfaded.
CLIPS = {
	"poke": ("shot", ["poke"], ["impactSoft_medium", "impactPunch_medium"], 0.6, -20),
	"pat": ("shot", ["pat", "poke"], ["impactSoft_heavy", "impactSoft_medium"], 0.6, -20),
	"chisel-tick": ("shot", ["chisel_tick"], ["impactMining"], 0.35, -22),
	"chisel-knock": ("shot", ["chisel_tick", "hammer_rock"], ["impactMining", "impactPlate_light"], 0.6, -19),
	"mesa-break": ("shot", ["mesa", "hammer_rock"], [], 1.6, -19),
	"hammer-rock": ("shot", ["hammer_rock", "mesa", "chisel_tick"], ["impactMining"], 1.0, -18),
	"hammer-soil": ("shot", ["hammer_soil", "pat"], ["impactSoft_heavy", "impactPunch_heavy"], 0.7, -19),
	"scree": ("shot", ["scree", "pebbles"], [], 1.8, -22),
	"crumble": ("shot", ["scree", "pebbles"], [], 1.4, -23),
	"pebbles": ("shot", ["pebbles", "scree"], [], 1.4, -23),
	"trees": ("shot", ["trees"], [], 1.8, -24),
	"wire-start": ("shot", ["wire"], ["pluck"], 0.8, -24),
	"ui-cloth": ("shot", ["ui_cloth"], ["cloth"], 0.6, -26),
	"ui-tick": ("shot", ["ui_tick"], ["click", "tick", "switch"], 0.15, -26),
	"ui-pick": ("shot", ["ui_pick"], ["impactWood_light", "handleSmallLeather", "impactPlank_medium"], 0.5, -22),
	"ui-take": ("shot", ["ui_seeds"], ["handleCoins", "handleSmallLeather"], 0.6, -23),
	"ui-put": ("shot", ["ui_seeds"], ["dropLeather", "bookPlace"], 0.6, -23),
	"ui-refuse": ("shot", ["ui_refuse"], ["impactWood_light", "impactSoft_medium"], 0.4, -24),
	"ui-undo": ("shot", ["ui_undo"], ["bookFlip", "cloth"], 0.6, -24),
	"ui-page": ("shot", ["ui_page"], ["bookFlip", "bookOpen"], 0.9, -23),
	"ui-shutter": ("shot", ["ui_shutter"], [], 0.6, -22),
	"water-gather": ("shot", ["water_gather", "water_pop"], [], 0.7, -22),
	"water-toss": ("shot", ["toss"], [], 0.5, -26),
	"water-pop": ("shot", ["water_pop", "water_gather"], [], 0.5, -20),
	"water-splash": ("shot", ["water_splash"], [], 1.6, -18),
	"sow": ("shot", ["sow", "ui_seeds"], [], 1.0, -23),
	"stone-drop": ("shot", ["stone_drop", "hammer_soil"], ["impactSoft_medium"], 0.5, -20),
	"plant": ("shot", ["plant", "trees"], [], 0.7, -25),
	"water-swirl-loop": ("loop", ["water_swirl"], [], 0, -22),
	"groove-loop": ("loop", ["groove"], [], 0, -22),
	"rub-loop": ("loop", ["rub", "groove"], [], 0, -24),
	"sweep-loop": ("loop", ["paddle", "groove"], [], 0, -22),
	"scrape-loop": ("loop", ["chisel_drag"], [], 1.0, -22),
	"stretch-loop": ("loop", ["pinch"], [], 0.7, -24),
	"cut-loop": ("loop", ["wire", "groove"], [], 0, -22),
}
# Fetched sources whose titles show they are off-topic (a guitar under
# "pluck" is kept for the Wire; a synth under "sweep" is not).
EXCLUDE = set("""
152571 493880 386244 795493 244022 330901 401620
819656 764655 96488 222521 386007 614053 707526 210867 467122
452622 221532 392487 799137 591152 489924
815415 640204
128972 661807 321143
387554 268050 379882 414728 682180 412253
342539 767043 697751 861328 662271
854496 89069 437028 443958
487385 407145 863867 573130 484227 813036
650979 30449 837146 217342 853615 194016 840618 817567 445118 445117
436776 383444 391752 361303 469453
384890 594634 584323
157804 408612 535588
676626 431120 415202 389805
498694 319905 778462 646696 397918 573681
454222 173941
263901 466620 457223 542334
342200 96152 575561 349453
843664 71852
808646 660533
469184 863561 850568 90297 173930 406084 404763 577966 406220 634620 739915 449645 327894
""".split())
LOOP_SECONDS = 1.6
LOOP_FADE = 0.3
# Onsets: 10 ms frames; a hit starts where the level jumps ONSET_RISE dB over
# the last 50 ms and is within ONSET_FLOOR dB of the file's loudest frame.
FRAME = RATE // 100
ONSET_RISE = 9.0
ONSET_FLOOR = 30.0
TAIL_DROP = 36.0
MAX_TAKES_PER_SOURCE = 4


def decode(path):
	pcm = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"],
		capture_output=True, check=True).stdout
	a = array.array("h")
	a.frombytes(pcm)
	return [s / 32768.0 for s in a]


def write(path, x):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	a = array.array("h", [max(-32767, min(32767, int(round(s * 32767)))) for s in x])
	with wave.open(path, "wb") as w:
		w.setnchannels(1)
		w.setsampwidth(2)
		w.setframerate(RATE)
		w.writeframes(a.tobytes())


def db(v):
	return 20 * math.log10(max(v, 1e-9))


def envelope(x):
	return [db(math.sqrt(sum(s * s for s in x[i:i + FRAME]) / FRAME)) for i in range(0, len(x) - FRAME + 1, FRAME)]


def highpass(x, hz=70.0):
	# One-pole high-pass: rumble under the voice only muddies the mix.
	rc = 1.0 / (2 * math.pi * hz)
	k = rc / (rc + 1.0 / RATE)
	y, prev_x, prev_y = [], 0.0, 0.0
	for s in x:
		prev_y = k * (prev_y + s - prev_x)
		prev_x = s
		y.append(prev_y)
	return y


def level(x, target_db):
	# RMS over the frames within 30 dB of the loudest, so silence doesn't count;
	# then the peak is held under -1 dBFS.
	env = envelope(x) if len(x) >= FRAME else [db(max(abs(s) for s in x) or 1e-9)]
	top = max(env)
	live = [e for e in env if e > top - 30] or [top]
	rms = 10 * math.log10(sum(10 ** (e / 10) for e in live) / len(live))
	g = 10 ** ((target_db - rms) / 20)
	peak = max(abs(s) for s in x) * g
	if peak > 0.89:
		g *= 0.89 / peak
	return [s * g for s in x]


def fade(x, fin, fout):
	n_in, n_out = int(fin * RATE), int(fout * RATE)
	y = list(x)
	for i in range(min(n_in, len(y))):
		y[i] *= i / n_in
	for i in range(min(n_out, len(y))):
		y[-1 - i] *= (i / n_out) ** 2
	return y


def onsets(x):
	env = envelope(x)
	if not env:
		return []
	top = max(env)
	hits, last = [], -100
	for i in range(len(env)):
		before = min(env[max(0, i - 5):i] or [-120])
		if env[i] > top - ONSET_FLOOR and env[i] - before >= ONSET_RISE and i - last > 12:
			hits.append(i)
			last = i
	if not hits:
		hits = [max(0, env.index(top) - 2)]
	return hits


def shots(x, longest):
	env = envelope(x)
	out = []
	marks = onsets(x)
	for k, i in enumerate(marks):
		start = max(0, i - 1) * FRAME
		peak = max(env[i:i + 10] or [env[i]])
		end_frame = marks[k + 1] if k + 1 < len(marks) else len(env)
		stop = end_frame
		for j in range(i + 1, end_frame):
			if env[j] < peak - TAIL_DROP:
				stop = j
				break
		stop = min(stop * FRAME, start + int(longest * RATE))
		if stop - start < int(0.03 * RATE):
			continue
		out.append((start / RATE, fade(x[start:stop], 0.002, min(0.08, (stop - start) / RATE * 0.4))))
		if len(out) >= MAX_TAKES_PER_SOURCE:
			break
	return out


def loops(x, seconds=0):
	# The steadiest stretches: windows whose level varies least, crossfaded
	# into their own head so they loop without a seam.
	seconds = seconds or LOOP_SECONDS
	n = int(seconds * RATE)
	f = int(min(LOOP_FADE, seconds * 0.25) * RATE)
	if len(x) < n + f:
		return []
	env = envelope(x)
	# The loud end of the file, not one spike, sets the bar.
	top = sorted(env)[int(len(env) * 0.95)]
	span = (n + f) // FRAME
	scored = []
	for i in range(0, len(env) - span, 5):
		w = env[i:i + span]
		if min(w) < top - 30:
			continue
		mean = sum(w) / len(w)
		scored.append((sum((e - mean) ** 2 for e in w) / len(w), i))
	scored.sort()
	out, used = [], []
	for _, i in scored:
		if any(abs(i - u) < span for u in used):
			continue
		used.append(i)
		s = i * FRAME
		seg = x[s:s + n + f]
		body = seg[:n]
		tail = seg[n:]
		looped = list(body)
		for j in range(f):
			t = j / f
			looped[j] = body[j] * math.sqrt(t) + tail[j] * math.sqrt(1 - t)
		out.append((s / RATE, looped))
		if len(out) >= 2:
			break
	return out


def sources_for(dirs, kenney):
	found = []
	for d in dirs:
		meta = {}
		tsv = os.path.join(WORK, "fs", d, "sources.tsv")
		if os.path.exists(tsv):
			for row in csv.reader(open(tsv), delimiter="\t"):
				meta[row[0]] = {"title": row[2], "author": row[1], "page": row[5], "licence": "CC0"}
		for p in sorted(glob.glob(os.path.join(WORK, "fs", d, "*.mp3"))):
			sid = os.path.basename(p)[:-4]
			if sid in EXCLUDE:
				continue
			found.append((p, "fs:" + sid, meta.get(sid, {"title": sid, "author": "", "page": "", "licence": "CC0"})))
	for prefix in kenney:
		for p in sorted(glob.glob(os.path.join(WORK, "kenney", "*", "**", prefix + "*.ogg"), recursive=True)):
			name = os.path.basename(p)[:-4]
			found.append((p, "kenney:" + name, {"title": name, "author": "Kenney", "page": "https://kenney.nl/assets", "licence": "CC0"}))
	seen, out = set(), []
	for item in found:
		if item[1] not in seen:
			seen.add(item[1])
			out.append(item)
	return out


def candidates(only=None):
	index = {}
	for clip, (kind, dirs, kenney, longest, loud) in CLIPS.items():
		if only and clip not in only:
			continue
		folder = os.path.join(CAND, clip)
		shutil.rmtree(folder, ignore_errors=True)
		takes = []
		for path, sid, meta in sources_for(dirs, kenney):
			try:
				x = highpass(decode(path))
			except subprocess.CalledProcessError:
				continue
			cut = loops(x, longest) if kind == "loop" else shots(x, longest)
			for at, seg in cut:
				n = len(takes) + 1
				write(os.path.join(folder, "%d.wav" % n), level(seg, loud))
				takes.append({"n": n, "source": sid, "at": round(at, 3), "seconds": round(len(seg) / RATE, 3), **meta})
		index[clip] = {"kind": kind, "takes": takes}
		print("%-14s %3d takes" % (clip, len(takes)))
	old = {}
	ipath = os.path.join(CAND, "index.json")
	if only and os.path.exists(ipath):
		old = json.load(open(ipath))
	old.update(index)
	json.dump(old, open(ipath, "w"), indent=1)
	page(old)


def page(index):
	picks = json.load(open(PICKS)) if os.path.exists(PICKS) else {}
	rows = ["<!doctype html><meta charset=utf-8><title>ZenScape foley audition</title>",
		"<style>body{font:14px system-ui;margin:24px;background:#f4efe4;color:#333}h2{margin:28px 0 6px}"
		".t{display:inline-block;margin:4px;padding:6px 8px;border-radius:6px;background:#fffaf0;border:1px solid #ddd;cursor:pointer}"
		".t.on{background:#d8ecc8;border-color:#7a6}.t small{color:#888}</style>",
		"<h1>Foley audition</h1><p>Click a take to hear it; green ones are in tools/foley/picks.json now. "
		"Tell Claude the numbers you like, e.g. <code>poke: 3 7 12</code>.</p>"]
	for clip, entry in index.items():
		chosen = set(picks.get(clip, []))
		rows.append("<h2>%s <small>(%s)</small></h2>" % (clip, entry["kind"]))
		for t in entry["takes"]:
			src = "%s/%d.wav" % (clip, t["n"])
			rows.append("<span class='t%s' onclick=\"new Audio('%s').play()\" title='%s'>%d <small>%s</small></span>" % (
				" on" if t["n"] in chosen else "", src, html.escape(t["title"] + " — " + t["author"], quote=True), t["n"], html.escape(t["title"][:22])))
	open(os.path.join(CAND, "index.html"), "w").write("\n".join(rows))
	print("audition:", os.path.join(CAND, "index.html"))


def build():
	index = json.load(open(os.path.join(CAND, "index.json")))
	picks = json.load(open(PICKS))
	os.makedirs(OUT, exist_ok=True)
	for old in glob.glob(os.path.join(OUT, "*.wav")):
		os.remove(old)
	credits = [["file", "source", "title", "author", "page", "licence", "at_seconds"]]
	for clip, numbers in picks.items():
		entry = index[clip]
		takes = {t["n"]: t for t in entry["takes"]}
		for k, n in enumerate(numbers, 1):
			name = clip + ".wav" if entry["kind"] == "loop" else "%s-%d.wav" % (clip, k)
			shutil.copy(os.path.join(CAND, clip, "%d.wav" % n), os.path.join(OUT, name))
			t = takes[n]
			credits.append([name, t["source"], t["title"], t["author"], t["page"], t["licence"], str(t["at"])])
			if entry["kind"] == "loop":
				break
	with open(os.path.join(OUT, "SOURCES.tsv"), "w") as f:
		csv.writer(f, delimiter="\t", lineterminator="\n").writerows(credits)
	print("built", len(credits) - 1, "files into", OUT)


if __name__ == "__main__":
	if len(sys.argv) > 1 and sys.argv[1] == "build":
		build()
	elif len(sys.argv) > 1 and sys.argv[1] == "candidates":
		candidates(set(sys.argv[2:]) or None)
	else:
		print(__doc__)
