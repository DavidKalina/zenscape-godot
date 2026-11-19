#!/usr/bin/env python3
"""Cut CC0 recordings into the flight's foley: trees knocked down, grass skimmed.

The same two steps as make_foley.py, on its cutting code, for the clips
scripts/endless/flight_sound.gd plays:

    tools/foley/fs_search.py "tree falling" --into $ZS_FOLEY_WORK/fs/tree_fall   # fetch
    tools/foley/make_flight_foley.py candidates [clip ...]   # takes + audition page
    tools/foley/make_flight_foley.py build                   # flight_picks.json -> assets/audio/foley/

The work folder is $ZS_FOLEY_WORK, else /tmp/zs-foley. `candidates` writes
<work>/cand-flight/<clip>/<n>.wav and <work>/cand-flight/index.html, which
plays every take; a clip with no picks yet gets a first guess (one take from
each source in turn, the steadiest loop). `build` replaces only its own clips
in assets/audio/foley/ and their rows in SOURCES.tsv.

make_foley.py's own `build` wipes every WAV in that folder: run this one's
`build` again after it.
"""
import csv
import glob
import html
import json
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_foley as mf  # noqa: E402

WORK = os.environ.get("ZS_FOLEY_WORK", mf.WORK)
CAND = os.path.join(WORK, "cand-flight")
PICKS = os.path.join(mf.ROOT, "tools/foley/flight_picks.json")
RATE = mf.RATE

# Clip -> (kind, fetched dirs, longest take in seconds, loudness dBFS RMS,
# high-pass Hz, takes wanted). "shot": single hits at their onsets. "phrase":
# a run of hits up to the next quiet (a branch's crackle, a creak). "peak":
# one take round the source's loudest moment (a whole tree fall's crash).
# "loop": the steadiest stretch, crossfaded.
CLIPS = {
	"wood-crack": ("phrase", ["wood_crack", "tree_creak"], 1.1, -18, 90, 6),
	"tree-creak": ("phrase", ["tree_creak"], 2.4, -22, 90, 4),
	"tree-fall": ("peak", ["tree_fall", "tree_crash"], 3.2, -19, 60, 4),
	"wood-thud": ("shot", ["tree_thud"], 0.9, -18, 50, 4),
	"leaf-burst": ("phrase", ["leaf_burst"], 1.2, -22, 180, 6),
	"grass-skim-loop": ("loop", ["grass"], 4.0, -24, 350, 1),
}
# Fetched sources whose titles show they are off-topic (a pencil under
# "snap", a door under "creak", footsteps and birdsong under "grass").
EXCLUDE = set("""
476831 403647 443328 536777 703421 125956 691637 802582 802595 802574 802600
422963 424474 504437 402465 454222 767043 546787 827435 386228 836422 244989
459999 721505 351609 479778 176252 593817 575320 384399 323457 734230 862894
478389 447810 676988 743678 529396 675785
""".split())
# Sources a clip leaves out of the folders it shares: the creaks are not
# cracks, a fall and a split trunk are not creaks, snapping twigs not leaves.
SKIP = {
	"wood-crack": set("683956 797993 797995 848982 848983 848984 494071 751711".split()),
	"tree-creak": set("494071 751711 608346 354104".split()),
	"leaf-burst": set("354103".split()),
}
PEAK_LEAD = 0.5
# A phrase ends where the level has stayed PHRASE_DROP dB under its loudest
# frame for PHRASE_QUIET s; one shorter than PHRASE_MIN s is dropped.
PHRASE_DROP = 28.0
PHRASE_QUIET = 0.16
PHRASE_MIN = 0.18


def sources_for(dirs):
	found, seen = [], set()
	for d in dirs:
		meta = {}
		tsv = os.path.join(WORK, "fs", d, "sources.tsv")
		if os.path.exists(tsv):
			for row in csv.reader(open(tsv, encoding="utf-8"), delimiter="\t", quoting=csv.QUOTE_NONE):
				meta[row[0]] = {"title": row[2], "author": row[1], "page": row[5], "licence": "CC0"}
		for p in sorted(glob.glob(os.path.join(WORK, "fs", d, "*.mp3"))):
			sid = os.path.basename(p)[:-4]
			# Only a source the log names is CC0 for sure.
			if sid in EXCLUDE or sid in seen or sid not in meta:
				continue
			seen.add(sid)
			found.append((p, "fs:" + sid, meta[sid]))
	return found


def phrases(x, longest):
	env = mf.envelope(x)
	out, done = [], 0
	quiet = int(PHRASE_QUIET * 100)
	for i in mf.onsets(x):
		if i < done:
			continue
		top, low, j = env[i], 0, i
		limit = min(len(env), i + int(longest * 100))
		while j < limit:
			top = max(top, env[j])
			low = low + 1 if env[j] < top - PHRASE_DROP else 0
			if low >= quiet:
				break
			j += 1
		done = j
		start, stop = max(0, i - 1) * mf.FRAME, (j - low + 4) * mf.FRAME
		if stop - start < int(PHRASE_MIN * RATE):
			continue
		out.append((start / RATE, mf.fade(x[start:stop], 0.002, min(0.12, (stop - start) / RATE * 0.4))))
		if len(out) >= mf.MAX_TAKES_PER_SOURCE:
			break
	return out


def peak(x, longest):
	# The loudest 100 ms and what follows it: a fall's crash, not its wait.
	env = mf.envelope(x)
	if len(env) < 20:
		return []
	best, at = -1e9, 0
	for i in range(len(env) - 10):
		v = sum(env[i:i + 10])
		if v > best:
			best, at = v, i
	start = max(0, at * mf.FRAME - int(PEAK_LEAD * RATE))
	stop = min(len(x), start + int(longest * RATE))
	return [(start / RATE, mf.fade(x[start:stop], 0.05, 0.6))]


def steadiness(x):
	env = mf.envelope(x)
	mean = sum(env) / len(env)
	return sum((e - mean) ** 2 for e in env) / len(env)


def brightness(x):
	# Zero crossings a second: a rough "how hissy", to tell a thud from a snap.
	n = sum(1 for i in range(1, len(x)) if (x[i - 1] < 0.0) != (x[i] < 0.0))
	return n * RATE / max(len(x), 1)


def candidates(only=None):
	ipath = os.path.join(CAND, "index.json")
	index = json.load(open(ipath)) if os.path.exists(ipath) else {}
	for clip, (kind, dirs, longest, loud, hz, want) in CLIPS.items():
		if only and clip not in only:
			continue
		folder = os.path.join(CAND, clip)
		shutil.rmtree(folder, ignore_errors=True)
		takes = []
		for path, sid, meta in sources_for(dirs):
			if sid[3:] in SKIP.get(clip, ()):
				continue
			try:
				x = mf.highpass(mf.decode(path), hz)
			except subprocess.CalledProcessError:
				continue
			if kind == "loop":
				cut = mf.loops(x, longest)
			elif kind == "peak":
				cut = peak(x, longest)
			elif kind == "phrase":
				cut = phrases(x, longest)
			else:
				cut = mf.shots(x, longest)
			for at, seg in cut:
				n = len(takes) + 1
				seg = mf.level(seg, loud)
				mf.write(os.path.join(folder, "%d.wav" % n), seg)
				takes.append({"n": n, "source": sid, "at": round(at, 3), "seconds": round(len(seg) / RATE, 3),
					"steady": round(steadiness(seg), 2), "bright": round(brightness(seg)), **meta})
		index[clip] = {"kind": kind, "want": want, "takes": takes}
		print("%-16s %3d takes" % (clip, len(takes)))
	json.dump(index, open(ipath, "w"), indent=1)
	page(index)


def guess(entry):
	"""A first pick: one take from each source in turn; the steadiest loop."""
	takes = entry["takes"]
	if entry["kind"] == "loop":
		return [min(takes, key=lambda t: t["steady"])["n"]] if takes else []
	by = {}
	for t in takes:
		by.setdefault(t["source"], []).append(t["n"])
	out = []
	while len(out) < entry["want"] and any(by.values()):
		for s in list(by):
			if by[s] and len(out) < entry["want"]:
				out.append(by[s].pop(0))
	return out


def picks_now(index):
	picks = json.load(open(PICKS)) if os.path.exists(PICKS) else {}
	return {clip: picks.get(clip) or guess(entry) for clip, entry in index.items()}


def page(index):
	picks = picks_now(index)
	rows = ["<!doctype html><meta charset=utf-8><title>Flight foley audition</title>",
		"<style>body{font:14px system-ui;margin:24px;background:#f4efe4;color:#333}h2{margin:28px 0 6px}"
		".t{display:inline-block;margin:4px;padding:6px 8px;border-radius:6px;background:#fffaf0;border:1px solid #ddd;cursor:pointer}"
		".t.on{background:#d8ecc8;border-color:#7a6}.t small{color:#888}</style>",
		"<h1>Flight foley audition</h1><p>Click a take to hear it; green ones are in the game now. "
		"Tell Claude the numbers you like, e.g. <code>wood-crack: 3 7 12</code>.</p>"]
	for clip, entry in index.items():
		chosen = set(picks.get(clip, []))
		rows.append("<h2>%s <small>(%s, %d wanted)</small></h2>" % (clip, entry["kind"], entry["want"]))
		for t in entry["takes"]:
			rows.append("<span class='t%s' onclick=\"new Audio('%s/%d.wav').play()\" title='%s'>%d <small>%s %.1fs</small></span>" % (
				" on" if t["n"] in chosen else "", clip, t["n"], html.escape(t["title"] + " - " + t["author"], quote=True),
				t["n"], html.escape(t["title"][:22]), t["seconds"]))
	open(os.path.join(CAND, "index.html"), "w", encoding="utf-8").write("\n".join(rows))
	print("audition:", os.path.join(CAND, "index.html"))


def build():
	index = json.load(open(os.path.join(CAND, "index.json")))
	picks = picks_now(index)
	json.dump(picks, open(PICKS, "w"), indent=1)
	tsv = os.path.join(mf.OUT, "SOURCES.tsv")
	rows = list(csv.reader(open(tsv, encoding="utf-8"), delimiter="\t", quoting=csv.QUOTE_NONE))
	mine = tuple(CLIPS)
	rows = [r for r in rows if not r[0].startswith(mine)]
	made = 0
	for clip, numbers in picks.items():
		entry = index[clip]
		takes = {t["n"]: t for t in entry["takes"]}
		for old in glob.glob(os.path.join(mf.OUT, clip + "*.wav")):
			os.remove(old)
		for k, n in enumerate(numbers, 1):
			name = clip + ".wav" if entry["kind"] == "loop" else "%s-%d.wav" % (clip, k)
			shutil.copy(os.path.join(CAND, clip, "%d.wav" % n), os.path.join(mf.OUT, name))
			t = takes[n]
			rows.append([name, t["source"], t["title"], t["author"], t["page"], t["licence"], str(t["at"])])
			made += 1
			if entry["kind"] == "loop":
				break
	with open(tsv, "w", encoding="utf-8", newline="") as f:
		csv.writer(f, delimiter="\t", lineterminator="\n", quoting=csv.QUOTE_NONE, escapechar=None, quotechar=None).writerows(rows)
	page(index)
	print("built", made, "files into", mf.OUT)


if __name__ == "__main__":
	if len(sys.argv) > 1 and sys.argv[1] == "build":
		build()
	elif len(sys.argv) > 1 and sys.argv[1] == "candidates":
		candidates(set(sys.argv[2:]) or None)
	else:
		print(__doc__)
