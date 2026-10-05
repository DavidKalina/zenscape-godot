extends RefCounted
## The sky's disk cache: what is slow to work out and the same every time
## for a world (the layout, scripts/sky_world.gd; each range's far skyline,
## scripts/sky_ring.gd), kept under DIR so a world started again stands at
## once.
##
## Every entry is keyed by what made it: `code(kind)` (a hash of the
## source of every script that shapes that kind, followed through their
## preloads from its roots in KINDS, the native erosion kernel's source and
## FORMAT) and the entry's own inputs (its seed, stature, scale, stride, the
## palette's colours baked in its vertices, ...: `key`). A change to any of
## them makes a new key, so stale rock is never read back: it just isn't
## found, and is made again. A new kind of entry (a new skyline kind) needs
## only its own `kind` name, its inputs and, to be narrower than every sky
## script, its roots in KINDS.
##
## A file holds MAGIC, its key, the payload's size and md5, and the payload
## zstd-compressed; one that is short, corrupt, of another key or another
## FORMAT is deleted and made again (`load_value` returns null). Written to
## a temporary name first and moved into place, so a half-written file is
## never read. Files from other code are pruned once a session, and the
## whole kept under MOST bytes, oldest first (`prune`).
##
## Safe on workers: reading and writing touch only their own file.
## `--no-sky-cache` turns it off.

const MAGIC := "ZSC1"
## Bump by hand for a change to the file layout or the codec here.
const FORMAT := 1
const DIR := "user://sky_cache"
const MOST := 160*1024*1024
## The scripts whose code shapes each kind cached: "follow", read with
## every script they preload or load (`_closure`); "only", read alone. A
## kind not here reads ROOTS, followed. A skyline is its range's shape made
## from its inputs (scripts/sky_peak.gd, its erosion and strata) by the
## ring (scripts/sky_ring.gd `_shape`); the layout, the world's whole plan.
const ROOTS := ["res://scripts/sky_cache.gd","res://scripts/sky_world.gd","res://scripts/sky_peak.gd","res://scripts/sky_peaks.gd","res://scripts/sky_ring.gd"]
const KINDS := {
	"skyline":{"follow":["res://scripts/sky_peak.gd"],"only":["res://scripts/sky_ring.gd","res://scripts/sky_cache.gd"]},
	"layout":{"follow":["res://scripts/sky_world.gd"],"only":["res://scripts/sky_cache.gd"]},
}
## Other sources (not scripts) the shapes read: the native erosion kernel.
const SOURCES := ["res://native/terrain_kernels/kernels.cpp","res://native/terrain_kernels/water_flow.h"]

## Where the cache lies (tests point it elsewhere) and whether it is on.
static var dir := DIR
static var enabled := true
static var _flags_read := false
static var _codes := {}
static var _pruned := false
static var _mutex := Mutex.new()
## For the record: entries read back, made and written, and those found
## broken (tests, the loading screen's timing).
static var hits := 0
static var misses := 0
static var broken := 0

static func on() -> bool:
	if not _flags_read:
		_flags_read = true
		if "--no-sky-cache" in OS.get_cmdline_user_args(): enabled = false
	return enabled

## The hash of everything in the code that shapes a kind (main thread
## first: workers read it once made).
static func code(kind := "") -> String:
	_mutex.lock()
	var found: String = _codes.get(kind,"")
	_mutex.unlock()
	if found != "": return found
	found = code_from(_source,kind)
	_mutex.lock()
	_codes[kind] = found
	_mutex.unlock()
	return found

## The code's hash with every script's source read by `read` (path ->
## PackedByteArray): tests read one changed.
static func code_from(read: Callable, kind := "") -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(("%s|%d|%s|%s" % [MAGIC,FORMAT,str(Engine.get_version_info().hex),kind]).to_utf8_buffer())
	for path in scripts_of(kind,read):
		ctx.update(path.to_utf8_buffer())
		var text: PackedByteArray = read.call(path)
		if not text.is_empty(): ctx.update(text)
	for path: String in SOURCES:
		if FileAccess.file_exists(path): ctx.update(FileAccess.get_file_as_bytes(path))
	# Whether the native kernel erodes, or the GDScript one: their results
	# may differ in the last bits.
	var kernel: RefCounted = preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	ctx.update(("native" if kernel != null else "gdscript").to_utf8_buffer())
	ctx.update(("version %s" % str(ProjectSettings.get_setting("application/config/version",""))).to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0,16)

## Every script whose code shapes a kind, sorted.
static func scripts_of(kind: String, read: Callable) -> PackedStringArray:
	var roots: Dictionary = KINDS.get(kind,{"follow":ROOTS,"only":[]})
	var out := _closure(read,roots.follow)
	for path: String in roots.only:
		if not path in out: out.append(path)
	out.sort()
	return out

## Every script reached from `roots` through `preload`/`load` of a script
## path, sorted.
static func _closure(read: Callable, roots: Array = ROOTS) -> PackedStringArray:
	var seen := {}
	var queue: Array[String] = []
	for root: String in roots: queue.append(root)
	var pattern := RegEx.create_from_string("res://[A-Za-z0-9_/\\-.]+\\.gd\\b")
	while not queue.is_empty():
		var path: String = queue.pop_back()
		if seen.has(path): continue
		seen[path] = true
		var text: String = (read.call(path) as PackedByteArray).get_string_from_utf8()
		for m in pattern.search_all(text):
			var found := m.get_string()
			if not seen.has(found): queue.append(found)
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out

## A script's source, or its compiled form in an export (text not kept).
static func _source(path: String) -> PackedByteArray:
	if ResourceLoader.exists(path):
		var script := load(path) as Script
		if script != null and script.has_source_code() and script.source_code != "": return script.source_code.to_utf8_buffer()
	for p in [path,path.get_basename()+".gdc"]:
		if FileAccess.file_exists(p): return FileAccess.get_file_as_bytes(p)
	return path.to_utf8_buffer()

## An entry's key: its kind, the code's hash and a hash of its inputs.
static func key(kind: String, inputs: Array) -> String:
	return "%s_%s_%s" % [kind,code(kind),var_to_str(inputs).md5_text().substr(0,20)]

static func _path(entry_key: String) -> String:
	return "%s/%s.zsc" % [dir,entry_key]

## The value kept under `entry_key`, or null if none (or a broken one,
## which is deleted).
static func load_value(entry_key: String) -> Variant:
	if not on(): return null
	var path := _path(entry_key)
	if not FileAccess.file_exists(path):
		_count("misses")
		return null
	var value: Variant = _read(path,entry_key)
	if value == null:
		_count("broken")
		_count("misses")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return null
	_count("hits")
	return value

static func _read(path: String, entry_key: String) -> Variant:
	var f := FileAccess.open(path,FileAccess.READ)
	if f == null: return null
	if f.get_length() < 4+4+8+16+8: return null
	if f.get_buffer(4).get_string_from_ascii() != MAGIC: return null
	if f.get_pascal_string() != entry_key: return null
	var raw_size := f.get_64()
	var sum := f.get_buffer(16)
	var packed_size := f.get_64()
	if raw_size <= 0 or raw_size > 1<<31 or packed_size <= 0 or f.get_position()+packed_size != f.get_length(): return null
	var packed := f.get_buffer(packed_size)
	if packed.size() != packed_size: return null
	var raw := packed.decompress(raw_size,FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size: return null
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(raw)
	if ctx.finish() != sum: return null
	return bytes_to_var(raw)

## Keeps `value` (no objects) under `entry_key`.
static func save_value(entry_key: String, value: Variant) -> void:
	if not on(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var raw := var_to_bytes(value)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(raw)
	var path := _path(entry_key)
	var temp := "%s.%d.tmp" % [path,OS.get_thread_caller_id()]
	var f := FileAccess.open(temp,FileAccess.WRITE)
	if f == null: return
	f.store_buffer(MAGIC.to_ascii_buffer())
	f.store_pascal_string(entry_key)
	f.store_64(raw.size())
	f.store_buffer(ctx.finish())
	f.store_64(packed.size())
	f.store_buffer(packed)
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(path))

## Surface arrays (Mesh.ARRAY_*) kept under `entry_key`, or [] if none.
static func load_arrays(entry_key: String) -> Array:
	var value: Variant = load_value(entry_key)
	if not value is Dictionary: return []
	var arrays: Variant = decode(value)
	return arrays if arrays is Array else []

static func save_arrays(entry_key: String, arrays: Array) -> void:
	save_value(entry_key,encode(arrays))

## The arrays under the key, or made by `make` (on the calling thread) and
## kept.
static func arrays(entry_key: String, make: Callable) -> Array:
	var found := load_arrays(entry_key)
	if not found.is_empty(): return found
	var made: Array = make.call()
	save_arrays(entry_key,made)
	return made

# --- The codec --------------------------------------------------------------------
# Exact: what is read back is what was kept. A vertex attribute the same
# for every vertex is kept once ("all"); one the same for each triangle's
# three, once a triangle ("face", the faceted ranges' colours); a UV of a
# fixed x and the vertex's height, by that x ("height").

static func encode(arrays: Array) -> Dictionary:
	var vertices: Variant = arrays[Mesh.ARRAY_VERTEX] if arrays.size() > Mesh.ARRAY_VERTEX else null
	var n: int = (vertices as PackedVector3Array).size() if vertices is PackedVector3Array else -1
	var slots := {}
	for slot in range(arrays.size()):
		var a: Variant = arrays[slot]
		if a == null: continue
		slots[slot] = _encode_slot(a,n,vertices if slot != Mesh.ARRAY_VERTEX else null)
	return {"size":arrays.size(),"n":n,"slots":slots}

static func _encode_slot(a: Variant, n: int, vertices: Variant) -> Dictionary:
	var count := -1
	if a is PackedVector3Array or a is PackedVector2Array or a is PackedColorArray or a is PackedFloat32Array: count = a.size()
	if count != n or n <= 0: return {"raw":a}
	var first: Variant = a[0]
	var same := true
	for k in range(1,n):
		if a[k] != first:
			same = false
			break
	if same: return {"all":first,"type":typeof(a)}
	if a is PackedVector2Array and vertices is PackedVector3Array:
		var height := true
		for k in range(n):
			if a[k].x != first.x or a[k].y != vertices[k].y:
				height = false
				break
		if height: return {"height":first.x}
	if n%3 == 0:
		var face := true
		for k in range(0,n,3):
			if a[k+1] != a[k] or a[k+2] != a[k]:
				face = false
				break
		if face:
			var out: Variant = a.duplicate()
			out.resize(0)
			out.resize(n/3)
			for k in range(n/3): out[k] = a[k*3]
			return {"face":out}
	return {"raw":a}

static func decode(value: Dictionary) -> Variant:
	if not (value.get("size") is int and value.get("n") is int and value.get("slots") is Dictionary): return null
	var arrays := []
	arrays.resize(int(value.size))
	var n := int(value.n)
	var slots: Dictionary = value.slots
	# The vertices first: a "height" UV reads them.
	var order: Array = slots.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return a == Mesh.ARRAY_VERTEX or (b != Mesh.ARRAY_VERTEX and a < b))
	for slot: int in order:
		if slot < 0 or slot >= arrays.size(): return null
		var e: Variant = slots[slot]
		if not e is Dictionary: return null
		if e.has("raw"): arrays[slot] = e.raw
		elif e.has("all"):
			var out: Variant = type_convert([],int(e.type))
			out.resize(n)
			out.fill(e.all)
			arrays[slot] = out
		elif e.has("height"):
			var v: Variant = arrays[Mesh.ARRAY_VERTEX]
			if not v is PackedVector3Array or v.size() != n: return null
			var out := PackedVector2Array()
			out.resize(n)
			var x := float(e.height)
			for k in range(n): out[k] = Vector2(x,v[k].y)
			arrays[slot] = out
		elif e.has("face"):
			var f: Variant = e.face
			if f.size()*3 != n: return null
			var out: Variant = f.duplicate()
			out.resize(n)
			for k in range(f.size()-1,-1,-1):
				var c: Variant = f[k]
				out[k*3] = c
				out[k*3+1] = c
				out[k*3+2] = c
			arrays[slot] = out
		else: return null
	return arrays

# --- Keeping it small -----------------------------------------------------------------

## Deletes every entry made by other code, and the oldest past MOST bytes
## (once a session, from the main thread as a world starts).
static func prune(force := false) -> void:
	if not on() or (_pruned and not force): return
	_pruned = true
	var d := DirAccess.open(dir)
	if d == null: return
	var kept := []
	for file in d.get_files():
		var path := "%s/%s" % [dir,file]
		# The kind is the name up to its code's hash.
		var parts := file.get_basename().rsplit("_",true,2)
		if not file.ends_with(".zsc") or parts.size() != 3 or parts[1] != code(parts[0]):
			d.remove(file)
			continue
		kept.append([FileAccess.get_modified_time(path),FileAccess.get_size(path),file])
	kept.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var total := 0
	for k: Array in kept:
		total += int(k[1])
		if total > MOST: d.remove(k[2])

## The bytes the cache holds now.
static func size() -> int:
	var d := DirAccess.open(dir)
	if d == null: return 0
	var total := 0
	for file in d.get_files(): total += FileAccess.get_size("%s/%s" % [dir,file])
	return total

## Every entry gone (tests).
static func wipe() -> void:
	var d := DirAccess.open(dir)
	if d == null: return
	for file in d.get_files(): d.remove(file)

static func _count(which: String) -> void:
	_mutex.lock()
	match which:
		"hits": hits += 1
		"misses": misses += 1
		"broken": broken += 1
	_mutex.unlock()
