#!/usr/bin/env python3
"""Search Freesound for CC0 sounds and fetch their HQ previews.

Freesound's public search page lists CC0 results with preview links, so no
API key is needed. Only CC0 results are taken (the search filter enforces it),
and every fetched file is logged with its id, author and page so
assets/audio/ATTRIBUTION.md can credit it, even though CC0 asks for nothing.

    tools/foley/fs_search.py "stone scrape" --max-dur 3 --take 6 --into /tmp/zs-foley/fs/stone-scrape

Writes <into>/<id>.mp3 and appends to <into>/sources.tsv.
"""
import argparse
import html
import os
import re
import sys
import urllib.parse
import urllib.request

UA = {"User-Agent": "Mozilla/5.0 (zenscape foley search)"}
RESULT = re.compile(r'<div\s+class="bw-player"(.*?)tabindex', re.S)


def attr(block, name):
	m = re.search(r'data-%s="([^"]*)"' % name, block)
	return html.unescape(m.group(1)) if m else ""


def search(query, pages=2, sort="downloads_desc"):
	out = []
	for page in range(1, pages + 1):
		q = urllib.parse.urlencode({"q": query, "f": 'license:"Creative Commons 0"', "s": sort, "page": page})
		req = urllib.request.Request("https://freesound.org/search/?" + q, headers=UA)
		body = urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")
		for block in RESULT.findall(body):
			out.append({
				"id": attr(block, "sound-id"),
				"user": attr(block, "username"),
				"title": attr(block, "title"),
				"dur": float(attr(block, "duration") or 0),
				"downloads": int(attr(block, "num-downloads") or 0),
				"mp3": attr(block, "mp3").replace("-lq.mp3", "-hq.mp3"),
			})
	return out


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("query")
	ap.add_argument("--min-dur", type=float, default=0.05)
	ap.add_argument("--max-dur", type=float, default=6.0)
	ap.add_argument("--take", type=int, default=6)
	ap.add_argument("--pages", type=int, default=2)
	ap.add_argument("--into", required=True)
	a = ap.parse_args()
	os.makedirs(a.into, exist_ok=True)
	seen = set()
	log = os.path.join(a.into, "sources.tsv")
	if os.path.exists(log):
		seen = {line.split("\t")[0] for line in open(log)}
	taken = 0
	for r in search(a.query, a.pages):
		if taken >= a.take:
			break
		if r["id"] in seen or not (a.min_dur <= r["dur"] <= a.max_dur):
			continue
		dest = os.path.join(a.into, r["id"] + ".mp3")
		try:
			data = urllib.request.urlopen(urllib.request.Request(r["mp3"], headers=UA), timeout=30).read()
		except Exception as e:  # a missing preview is not worth stopping for
			print("skip", r["id"], e, file=sys.stderr)
			continue
		open(dest, "wb").write(data)
		page = "https://freesound.org/people/%s/sounds/%s/" % (r["user"], r["id"])
		with open(log, "a") as f:
			f.write("\t".join([r["id"], r["user"], r["title"], "%.2f" % r["dur"], str(r["downloads"]), page, a.query]) + "\n")
		seen.add(r["id"])
		taken += 1
		print("%s  %5.2fs  %6d dl  %s — %s" % (r["id"], r["dur"], r["downloads"], r["title"], r["user"]))


if __name__ == "__main__":
	main()
