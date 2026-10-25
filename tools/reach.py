"""Files reachable from roots by res:// strings, class_name words, uid://
ids and #include lines. Every file is a node; text files (and uncompressed
binary scenes) are parsed for edges, and each file brings its .import and
.uid sidecars. Written for the cut to endless flight (docs/archive.md).
  python tools/reach.py ROOT... [--out FILE]
A root that is a directory adds every file under it. What it can't see:
loads built at run time ("res://shaders/sea_fft_%s.glsl" % name, a folder
listed with DirAccess), and the dependencies of compressed binary scenes:
for those, run `python tools/godot.py -s res://tools/reach_deps.gd` first,
which writes scratch/reach_deps.txt from Godot's own
ResourceLoader.get_dependencies, and reach.py reads it.
`why(starts, file)` gives the shortest chain from the starts to a file."""
import os, re, sys

TEXT = ('.gd', '.tscn', '.tres', '.gdshader', '.gdshaderinc', '.glsl', '.json', '.cfg', '.import', '.gdextension', '.godot', '.py', '.md', '.command')
SKIP = {'.git', 'scratch', '.godot', 'captures', '.claude'}
root = os.getcwd()
files = {}
for d, dirs, fs in os.walk(root):
	dirs[:] = [x for x in dirs if x not in SKIP]
	for f in fs:
		p = os.path.join(d, f)
		files[os.path.relpath(p, root).replace('\\', '/')] = p
texts = {}
cls = {}
for rel, p in files.items():
	if rel.endswith(TEXT):
		try:
			texts[rel] = open(p, encoding='utf-8', errors='replace').read()
		except Exception:
			pass
		if rel.endswith('.gd'):
			for m in re.finditer(r'^\s*class_name\s+(\w+)', texts.get(rel, ''), re.M):
				cls[m.group(1)] = rel
# binary scenes and resources name their dependencies as res:// strings too
BIN = ('.scn', '.res', '.mesh', '.anim')
for rel, p in files.items():
	if rel.endswith(BIN):
		try:
			texts[rel] = open(p, 'rb').read().decode('latin-1')
		except Exception:
			pass
# uid:// ids: from .uid sidecars and the uid= line of .import files
uids = {}
for rel, p in files.items():
	if rel.endswith('.uid'):
		try:
			uids[open(p).read().strip()] = rel[:-4]
		except Exception:
			pass
	elif rel.endswith('.import'):
		m = re.search(r'^uid="(uid://[a-z0-9]+)"', texts.get(rel, ''), re.M)
		if m: uids[m.group(1)] = rel[:-7]
# dependencies only Godot can read (compressed binary scenes): tools/reach_deps.gd
EXTRA = {}
_dp = os.path.join(root, 'scratch', 'reach_deps.txt')
if os.path.exists(_dp):
	for line in open(_dp):
		bits = line.split()
		if len(bits) == 3 and bits[0] == 'DEP':
			a = bits[1].replace('res://', ''); b = bits[2].split('::::')[-1].replace('res://', '')
			EXTRA.setdefault(a, set()).add(b)
UID = re.compile(r'uid://[a-z0-9]+')
cls_re = re.compile(r'\b(' + '|'.join(map(re.escape, cls)) + r')\b')
RES = re.compile(r'res://([^"\'\s\)>]+)')

def edges(rel):
	out = set()
	for side in (rel + '.import', rel + '.uid'):
		if side in files:
			out.add(side)
	t = texts.get(rel)
	if t is None:
		return out
	for line in t.splitlines():
		s = line.strip()
		if rel.endswith('.gd') and s.startswith('#'):
			continue
		for m in RES.finditer(s):
			out.add(m.group(1).rstrip('.,;:'))
		for m in UID.finditer(s):
			if m.group(0) in uids and not rel.endswith(('.uid', '.import')): out.add(uids[m.group(0)])
		if rel.endswith('.gd'):
			for m in cls_re.finditer(s):
				out.add(cls[m.group(1)])
	for dep in EXTRA.get(rel, ()):
		out.add(dep)
	# a file's import sidecar and uid sidecar travel with it
	for side in (rel + '.import', rel + '.uid'):
		if side in files:
			out.add(side)
	return {o for o in out if o in files}

def reach(starts):
	seen = set()
	stack = list(starts)
	while stack:
		f = stack.pop()
		if f in seen or f not in files:
			continue
		seen.add(f)
		stack.extend(e for e in edges(f) if e not in seen)
	return seen

if __name__ == '__main__':
	args = sys.argv[1:]
	out = None
	if '--out' in args:
		i = args.index('--out'); out = args[i + 1]; del args[i:i + 2]
	starts = []
	for a in args:
		a = a.rstrip('/')
		if os.path.isdir(a):
			starts += [r for r in files if r.startswith(a + '/')]
		else:
			starts.append(a)
	got = sorted(reach(starts))
	txt = '\n'.join(got) + '\n'
	if out:
		open(out, 'w').write(txt)
	else:
		sys.stdout.write(txt)
	print('COUNT', len(got), file=sys.stderr)

def why(starts, target):
	"""The shortest chain of files from the starts to target."""
	from collections import deque
	prev = {s: None for s in starts if s in files}
	q = deque(prev)
	while q:
		f = q.popleft()
		if f == target:
			chain = []
			while f is not None:
				chain.append(f); f = prev[f]
			return chain[::-1]
		for e in edges(f):
			if e not in prev:
				prev[e] = f; q.append(e)
	return None
