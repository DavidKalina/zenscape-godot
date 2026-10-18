extends RefCounted
## Chunks (docs/design/world-editor/spec-world-handles.md goal 2): a
## selection of the world view's pieces kept as a named recipe file, to
## stamp again elsewhere. A chunk keeps each piece's kind, pose (relative
## to the chunk's anchor: its middle, turned as the view faced when it was
## saved), a slab's pumps and a size off the coded one; a stamp rebuilds
## each piece from the current code (scripts/layout_overrides.gd `spawn`).
## Only the kinds the layout file can add (Layout.ADDABLE: rings, slabs) go
## in a chunk.
##
## The files: <the layout file's folder>/chunks/<name>.json (so
## res://layouts/chunks/ for the isle, and beside a `--layout=` file).
##   {"version": 1, "name": "ring_run",
##    "pieces": [{"kind": "air_ring", "pos": [x, y, z], "rot": [x, y, z], "size": 2.5}, ...]}

const Layout = preload("res://scripts/layout_overrides.gd")
const VERSION := 1

static func dir() -> String:
	return Layout.path.get_base_dir().path_join("chunks")

static func file_of(name: String) -> String:
	return dir().path_join(name+".json")

## A name made safe for a file (letters, digits, _ and -).
static func clean(name: String) -> String:
	var out := ""
	for ch in name.strip_edges().to_lower().replace(" ","_"):
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-": out += ch
	return out

## The chunks saved, by name, sorted.
static func names() -> Array:
	var out: Array = []
	var d := DirAccess.open(dir())
	if d == null: return out
	for f: String in d.get_files():
		if f.ends_with(".json"): out.append(f.get_basename())
	out.sort()
	return out

## A name `chunk_<n>` not yet saved.
static func fresh() -> String:
	var have := names()
	var i := 1
	while "chunk_%d" % i in have: i += 1
	return "chunk_%d" % i

## The pieces `names` (tracked) saved as chunk `name` about `anchor`.
## Returns [error, pieces kept, pieces skipped (not addable)].
static func save(name: String, names_in: Array, anchor: Transform3D) -> Array:
	var pieces: Array = []
	var skipped := 0
	var inv := anchor.affine_inverse()
	for n: String in names_in:
		if not Layout.entries.has(n): continue
		var e: Dictionary = Layout.entries[n]
		if not str(e.kind) in Layout.ADDABLE:
			skipped += 1
			continue
		var p := Layout.to_json(inv*Layout.current(n))
		p["kind"] = str(e.kind)
		if e.has("pumps") and float(e.pumps) != float(preload("res://scripts/interactables/bob_slab.gd").SPRING_PUMPS): p["pumps"] = e.pumps
		var sz: Variant = Layout.size_of(n)
		if sz != null and e.has("size0") and not Layout._same_size(sz,e.size0): p["size"] = Layout.size_to_json(sz)
		var off := Layout.tunes_off(n,["pumps"])
		if not off.is_empty(): p["tunes"] = off
		pieces.append(p)
	if pieces.is_empty(): return [ERR_INVALID_DATA,0,skipped]
	var at := dir()
	if at.begins_with("res://"): DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(at))
	else: DirAccess.make_dir_recursive_absolute(at)
	var f := FileAccess.open(file_of(name),FileAccess.WRITE)
	if f == null: return [FileAccess.get_open_error(),0,skipped]
	var rows := PackedStringArray()
	for p: Dictionary in pieces: rows.append("\t\t"+JSON.stringify(p))
	f.store_string("{\n\t\"version\": %d,\n\t\"name\": %s,\n\t\"pieces\": [\n%s\n\t]\n}\n" % [VERSION,JSON.stringify(name),",\n".join(rows)])
	f.close()
	return [OK,pieces.size(),skipped]

## Chunk `name`'s pieces ([] if it can't be read): each {kind, t (relative
## to the anchor), pumps, size}.
static func read(name: String) -> Array:
	var out: Array = []
	var path := file_of(name)
	if not FileAccess.file_exists(path): return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("chunk %s: not a JSON object, ignored" % path)
		return out
	for p: Variant in (parsed as Dictionary).get("pieces",[]):
		if not p is Dictionary or not str(p.get("kind","")) in Layout.ADDABLE: continue
		out.append({"kind":str(p.kind),"t":Layout.from_json(p),"pumps":float(p.get("pumps",0.0)),"size":p.get("size",null),"tunes":p.get("tunes",{}) if p.get("tunes") is Dictionary else {}})
	return out

## A name for stamp piece `i` of chunk `chunk` (`chunk/<chunk>_<n>/<kind>_<i>`),
## `n` the first stamp number not yet in use.
static func stamp_prefix(chunk: String) -> String:
	var n := 1
	while true:
		var p := "chunk/%s_%d/" % [chunk,n]
		var used := false
		for k: String in Layout.entries:
			if k.begins_with(p):
				used = true
				break
		if not used: return p
		n += 1
	return ""
