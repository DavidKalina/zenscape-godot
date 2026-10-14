import re, sys, collections
txt = open(sys.argv[1]).read().splitlines()
topn = int(sys.argv[2]) if len(sys.argv) > 2 else 30
per = collections.OrderedDict()
cur = None; state = 0; fn = None
for line in txt:
    if line.startswith("PROFILE BUILD"):
        cur = line.split("PROFILE BUILD ")[1]; per[cur] = {}; state = 1; continue
    if state == 1 and line.startswith("FRAME:"):
        state = 2; per[cur]["__frame"] = line; continue
    if state == 2:
        m = re.match(r"^\d+:(.*)$", line)
        if m: fn = m.group(1); continue
        m = re.match(r"^\s+total: ([\d.e-]+)/.*self: ([\d.e-]+)/.*tcalls: (\d+)", line)
        if m and fn:
            per[cur][fn] = (float(m.group(1)), float(m.group(2)), int(m.group(3))); continue
        if line.startswith("FRAME:") or line.startswith("BENCH") or line.startswith("PROFILE"): state = 0
agg = collections.defaultdict(lambda: [0.0, 0.0, 0])
for isle, fns in per.items():
    print("==", isle, fns.get("__frame"))
    items = sorted(((k, v) for k, v in fns.items() if k != "__frame"), key=lambda kv: -kv[1][1])
    tot = sum(v[1] for k, v in items)
    print("   self sum %.3f s" % tot)
    for k, v in items[:12]:
        print("   self %.3f total %.3f calls %8d  %s" % (v[1], v[0], v[2], k))
    for k, v in items:
        agg[k][0] += v[0]; agg[k][1] += v[1]; agg[k][2] += v[2]
print("== ALL ISLES, by self")
tot = sum(v[1] for v in agg.values())
print("   self sum %.3f s" % tot)
for k, v in sorted(agg.items(), key=lambda kv: -kv[1][1])[:topn]:
    print("   self %6.3f (%4.1f%%) total %6.3f calls %8d  %s" % (v[1], 100*v[1]/tot, v[0], v[2], k))
