extends RefCounted
## What a launch builds the same every time, kept on disk
## (docs/design/roguelike/loading-screen-round2b.md): the aqueduct isle's art
## (studies/aqueduct_isle_base.gd: one isle, constant seeds, no run seed) and the
## plan's kit-piece footprints (KitMotif `piece_block`, keyed by piece, its
## constant seed and weathering). Neither depends on a run's seed or shape, so
## the first launch since a code change makes them and every later launch,
## whatever the seed, loads them. A trimmed form of round 2's isle store:
## no per-seed isle files, no helper processes; the base is saved from a copy of
## the one the game builds, on a worker, once.
##
## Kept under `DIR`, named by `key_text`: the scripts (a hash of every script and
## data file), the stone look, the launch flags a build reads, the engine. Only
## the newest of each is kept (older ones are removed when a new one is saved), so
## the folder is the base's one scene file and one small text file.
## The four materials every isle shares (`shared`) are saved tagged and put back
## as the live ones on load, so a look or weather change still reaches them.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")

const DIR := "user://fixed_cache"
## Bumped when the file's layout changes.
const VERSION := 1
## The root's meta holding what the scene can't.
const STATE := &"fixed_cache"
## A shared material's tag (its key in `shared`).
const SHARED_TAG := &"fixed_cache_shared"
## Launch flags that change nothing a build reads (left out of the key).
const LOOSE_FLAGS := ["--seed=","--shape=","--knob=","--no-title","--loading-trace","--no-shader-warmup","--shader-warmup","--no-loading-screen",
	"--no-fixed-cache","--secs=","--out=","--cap=","--caps=","--stills","--parts=","--turn=","--window=","--no-next","--procs","--census",
	"--motifs-now","--no-flora","--no-life","--no-bell","--quit-after","--plan-away","--raygrid","--change-after=","--no-stills","--frames","--isle-builds=","--flora-records"]

static var _hash := ""
static var _hash_lock := Mutex.new()
## Set once the base's save has been asked (one a launch).
static var _asked := false
## The save's worker task till it is waited (-1: none), and what it leaves
## for the main thread: the copy to free, the live materials to untag.
static var _task := -1
static var _dst: Node
static var _live := {}
static var _began := 0

## Whether the cache is in use: not with --no-fixed-cache.
static func enabled() -> bool:
	return not "--no-fixed-cache" in preload("res://scripts/launch_args.gd").user_args()

## The four materials the isles share, live: {key: material}.
static func shared() -> Dictionary:
	return {"ground":KitLook.ground_material(),"rock":KitLook.rock_material(),"stone":RuinKit.materials().stone,"growth":RuinKit.materials().growth}

# --- The key ----------------------------------------------------------------------------

## A hash of every script and data file the game runs (once). Any change and
## everything is made afresh. (An exported game has its scripts compiled behind
## .remap files: its executable's size and time stand in for them.)
static func code_hash() -> String:
	_hash_lock.lock()
	if _hash == "":
		var files := PackedStringArray()
		for top: String in ["res://scripts","res://studies","res://data"]: _gather(top,files)
		files.sort()
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_MD5)
		for f in files:
			ctx.update(f.to_utf8_buffer())
			ctx.update(FileAccess.get_md5(f).to_utf8_buffer())
		ctx.update(Engine.get_version_info().string.to_utf8_buffer())
		if not OS.has_feature("editor"):
			var exe := OS.get_executable_path()
			ctx.update(("%d/%d" % [FileAccess.get_modified_time(exe),FileAccess.get_size(exe)]).to_utf8_buffer())
		_hash = ctx.finish().hex_encode()
	var out := _hash
	_hash_lock.unlock()
	return out

static func _gather(dir: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir)
	if d == null: return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".gdc") or f.ends_with(".remap") or f.ends_with(".json") or f.ends_with(".cfg") or f.ends_with(".gdshader"): out.append(dir.path_join(f))
	for sub in d.get_directories(): _gather(dir.path_join(sub),out)

## The launch flags a build may read (all but LOOSE_FLAGS), in order.
static func build_flags(args: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for a in args:
		var loose := false
		for f: String in LOOSE_FLAGS:
			if a.begins_with(f): loose = true
		if not loose: out.append(a)
	return out

static func key_text() -> String:
	return var_to_str([VERSION,code_hash(),Style.current,build_flags(preload("res://scripts/launch_args.gd").user_args())]).md5_text().left(20)

static func _dir() -> String:
	return ProjectSettings.globalize_path(DIR)

## The base's file for this code and these flags.
static func base_path() -> String:
	return _dir().path_join("base_%s.scn" % key_text())

static func has_base() -> bool:
	return enabled() and FileAccess.file_exists(base_path())

## The folder, made, and kept out of Spotlight's index on macOS.
static func make_dir() -> void:
	var dir := _dir()
	DirAccess.make_dir_recursive_absolute(dir)
	if OS.get_name() == "macOS" and not FileAccess.file_exists(dir.path_join(".metadata_never_index")):
		var f := FileAccess.open(dir.path_join(".metadata_never_index"),FileAccess.WRITE)
		if f != null: f.close()

## Removes files of `prefix` but `keep` (those of older code).
static func _drop_others(prefix: String, keep: String) -> void:
	var d := DirAccess.open(_dir())
	if d == null: return
	for f in d.get_files():
		if f.begins_with(prefix) and f != keep: DirAccess.remove_absolute(_dir().path_join(f))

# --- Saving the base ---------------------------------------------------------------------

## Keeps a copy of `src` (the base's art just built into it, nothing yet added
## to it or changed) and what the build left on `motif`. What is read off `src`
## and `motif` is read here, now; the copy is packed and written on a worker
## (engine work: it does not slow the GDScript the game runs). Once.
static func save_base(motif: RefCounted, src: Node3D) -> void:
	if not enabled() or _asked: return
	_asked = true
	make_dir()
	var dst := src.duplicate() as Node3D
	var enc := Enc.new()
	enc.root = src
	enc.motif = motif
	enc.shared = shared()
	var state := {"version":VERSION,"motif":{},"scripts":[],"metas":[],"groups":[]}
	for p: Dictionary in motif.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var kept: Variant = enc.value(motif.get(p.name),"motif."+str(p.name))
		# A field that can't be kept is left as the game's own motif has it.
		if enc.fail != "":
			enc.fail = ""
			continue
		state.motif[p.name] = kept
	var nodes: Array = [src]+src.find_children("*","",true,false)
	for node: Node in nodes:
		var where := str(src.get_path_to(node))
		var groups := []
		for g: StringName in node.get_groups(): groups.append(g)
		if not groups.is_empty(): state.groups.append([where,groups])
		for k: StringName in node.get_meta_list():
			var v: Variant = node.get_meta(k)
			if Enc.plain(v,enc.shared): continue
			state.metas.append([where,k,enc.value(v,where+":"+str(k))])
		var script: Script = node.get_script()
		if script != null:
			var vars := {}
			for p: Dictionary in script.get_script_property_list():
				if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
				vars[p.name] = enc.value(node.get(p.name),where+"."+str(p.name))
			state.scripts.append([where,enc.script_ref(script,where),vars])
	if enc.fail != "":
		push_warning("fixed cache: the base art can't be kept (%s)" % enc.fail)
		dst.free()
		return
	state.objs = enc.objs
	# Off the copy what the scene can't hold, put back on load.
	for m: Array in state.metas: dst.get_node(NodePath(m[0])).remove_meta(m[1])
	for s: Array in state.scripts: dst.get_node(NodePath(s[0])).set_script(null)
	var all: Array = [dst]+dst.find_children("*","",true,false)
	for node: Node in all:
		if node != dst: node.owner = dst
	dst.set_meta(STATE,state)
	# The four shared materials tagged here, on the main thread, and untagged
	# when the save is reaped (`_reap`), as the copy is freed there: the
	# worker touches nothing live and frees nothing.
	var live := enc.shared
	for key_name: String in live: (live[key_name] as Material).set_meta(SHARED_TAG,key_name)
	var path := base_path()
	_dst = dst
	_live = live
	_began = Time.get_ticks_msec()
	_task = WorkerThreadPool.add_task(func() -> void:
		var packed := PackedScene.new()
		var err := packed.pack(dst)
		var tmp := path.get_basename()+".part%d.scn" % OS.get_process_id()
		if err == OK: err = ResourceSaver.save(packed,tmp)
		packed = null
		if err != OK:
			push_warning("fixed cache: the base art wasn't kept (%d)" % err)
			DirAccess.remove_absolute(tmp)
			return
		DirAccess.rename_absolute(tmp,path)
		_drop_others("base_",path.get_file()),false,"Fixed cache: keep the base")
	(Engine.get_main_loop() as SceneTree).process_frame.connect(_poll)

## Whether the base's save is done (or none was asked). A worker's read of a
## mesh's arrays waits on the main thread's next frame, so tools run frames.
static func saved() -> bool:
	return _task < 0 or WorkerThreadPool.is_task_completed(_task)

## The save, if one is under way, finished now (a quit: the scene that asked
## it leaving the tree, `aqueduct_isle.gd` `_exit_tree`), so the file is whole
## and renamed, not left as a .part, and the task waited before the engine's
## teardown.
static func finish_save() -> void:
	if _task < 0: return
	if not WorkerThreadPool.is_task_completed(_task): print("fixed cache: quit mid-save, finishing it")
	_flush_till_done(_task)
	_reap()

## The save's task waited (on the main thread, once it is done), its copy
## freed and the materials untagged. A task never waited keeps its Callable,
## and with it the four live shared materials it captured, till the engine's
## last teardown, after the RenderingServer is gone: their free there crashed
## the quit of every session that saved (signal 11 in a mutex lock).
static func _reap() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.process_frame.is_connected(_poll): tree.process_frame.disconnect(_poll)
	if _task < 0: return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	for key_name: String in _live: (_live[key_name] as Material).remove_meta(SHARED_TAG)
	_live = {}
	if is_instance_valid(_dst): _dst.free()
	_dst = null
	print("fixed cache: the base kept in %d ms" % (Time.get_ticks_msec()-_began))

## Waits out a worker's `task` on the main thread when the frames have
## stopped (a quit: the tree torn down), flushing the RenderingServer's queue
## meanwhile: a worker's read of a mesh waits on the main thread to flush it,
## so a plain wait there would never end. Then the task is waited (freed).
static func drain(task: int) -> void:
	if task < 0: return
	_flush_till_done(task)
	WorkerThreadPool.wait_for_task_completion(task)

static func _flush_till_done(task: int) -> void:
	while not WorkerThreadPool.is_task_completed(task):
		RenderingServer.force_sync()
		OS.delay_msec(1)

## Each frame while the save runs: reaped once done (`_reap`).
static func _poll() -> void:
	if saved(): _reap()

# --- Loading ----------------------------------------------------------------------------------

## The base art kept (as its build would leave it), its fields set on `motif`
## as the build set them; null if none or it can't be read.
static func load_base(motif: RefCounted, times := {}) -> Node3D:
	var path := base_path()
	if not FileAccess.file_exists(path): return null
	var t := Time.get_ticks_usec()
	var packed := ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	times.read_us = Time.get_ticks_usec()-t
	if packed == null:
		push_warning("fixed cache: %s didn't load" % path.get_file())
		return null
	var root := packed.instantiate() as Node3D
	if root == null:
		push_warning("fixed cache: %s didn't instantiate" % path.get_file())
		return null
	var state: Dictionary = root.get_meta(STATE,{})
	root.remove_meta(STATE)
	# As built in code: no owners (`find_children` reads them), no scene file.
	root.scene_file_path = ""
	for node: Node in root.find_children("*","",true,false): node.owner = null
	if int(state.get("version",-1)) != VERSION:
		push_warning("fixed cache: %s is of another version" % path.get_file())
		root.free()
		return null
	var dec := Dec.new()
	dec.root = root
	dec.motif = motif
	dec.objs = state.get("objs",[])
	dec.shared = shared()
	# The live shared materials in place of the saved copies.
	_reshare(root,dec.shared)
	for s: Array in state.scripts:
		var node := root.get_node(NodePath(s[0]))
		node.set_script(dec.script_of(s[1]))
	for s: Array in state.scripts:
		var node := root.get_node(NodePath(s[0]))
		var vars: Dictionary = s[2]
		for k: String in vars: node.set(k,dec.value(vars[k]))
	for m: Array in state.metas: root.get_node(NodePath(m[0])).set_meta(m[1],dec.value(m[2]))
	for g: Array in state.groups:
		var node := root.get_node(NodePath(g[0]))
		for name: StringName in g[1]:
			if not node.is_in_group(name): node.add_to_group(name)
	for k: String in state.motif: motif.set(k,dec.value(state.motif[k]))
	times.total_us = Time.get_ticks_usec()-t
	return root

## Every material tagged as shared under `root` (its meshes, their levels,
## overrides) swapped for the live one.
static func _reshare(root: Node, live: Dictionary) -> void:
	var seen := {}
	for node: Node in [root]+root.find_children("*","",true,false):
		if node is GeometryInstance3D:
			var g := node as GeometryInstance3D
			if g.material_override != null and g.material_override.has_meta(SHARED_TAG): g.material_override = live[g.material_override.get_meta(SHARED_TAG)]
			if g.material_overlay != null and g.material_overlay.has_meta(SHARED_TAG): g.material_overlay = live[g.material_overlay.get_meta(SHARED_TAG)]
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			for s in range(mi.get_surface_override_material_count()):
				var m := mi.get_surface_override_material(s)
				if m != null and m.has_meta(SHARED_TAG): mi.set_surface_override_material(s,live[m.get_meta(SHARED_TAG)])
			_reshare_mesh(mi.mesh,live,seen)
		if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
			_reshare_mesh((node as MultiMeshInstance3D).multimesh.mesh,live,seen)

static func _reshare_mesh(mesh: Mesh, live: Dictionary, seen: Dictionary) -> void:
	if mesh == null or seen.has(mesh.get_instance_id()): return
	seen[mesh.get_instance_id()] = true
	for s in range(mesh.get_surface_count()):
		var m := mesh.surface_get_material(s)
		if m != null and m.has_meta(SHARED_TAG): mesh.surface_set_material(s,live[m.get_meta(SHARED_TAG)])
	for k: StringName in mesh.get_meta_list():
		var v: Variant = mesh.get_meta(k)
		if v is Mesh: _reshare_mesh(v,live,seen)
		elif v is Array:
			for e: Variant in v:
				if e is Mesh: _reshare_mesh(e,live,seen)


# --- The plan's piece footprints ---------------------------------------------------------

## The kit pieces' footprints the plan measures (KitMotif `piece_block`, 2-4 s
## of building pieces at launch), kept between launches for this code. Keyed
## by piece, seed and weathering, all constants of the kit and the motifs.
static func boxes_path() -> String:
	return _dir().path_join("boxes_%s.txt" % key_text())

static func boxes_load() -> void:
	if not enabled(): return
	var path := boxes_path()
	if not FileAccess.file_exists(path): return
	var kept: Variant = str_to_var(FileAccess.get_file_as_string(path))
	if kept is Dictionary: load("res://scripts/kit_isle/kit_motif.gd").boxes_take(kept)

static func boxes_save() -> void:
	var KitMotif = load("res://scripts/kit_isle/kit_motif.gd")
	if not enabled() or not KitMotif.boxes_new: return
	make_dir()
	var f := FileAccess.open(boxes_path(),FileAccess.WRITE)
	if f == null: return
	f.store_string(var_to_str(KitMotif.boxes_all()))
	f.close()
	KitMotif.boxes_new = false
	_drop_others("boxes_",boxes_path().get_file())

# --- What the scene file can't hold, as data -------------------------------------------------

## Encodes values: a node in the tree as its path; an object (not a
## resource) once, by index into `objs`, with its script and fields; arrays
## and dictionaries holding either, once each, so what shared one shares it
## again; a shared material by its key. Anything else as it is (resources
## are saved in the same file, so their sharing holds).
class Enc:
	var root: Node
	var motif: RefCounted
	var shared: Dictionary
	var objs: Array = []
	var fail := ""
	var _seen: Array = []

	## Whether `v` holds nothing that needs encoding (a node, an object, a
	## weak reference, a callable or a shared material, at any depth).
	static func plain(v: Variant, live: Dictionary) -> bool:
		match typeof(v):
			TYPE_OBJECT:
				if v == null: return true
				if v is Resource:
					for k: String in live:
						if is_same(live[k],v): return false
					return true
				return false
			TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID: return false
			TYPE_ARRAY:
				for e: Variant in v:
					if not plain(e,live): return false
				return true
			TYPE_DICTIONARY:
				for k: Variant in v:
					if not plain(k,live) or not plain(v[k],live): return false
				return true
		return true

	func value(v: Variant, where: String) -> Variant:
		if plain(v,shared): return v
		match typeof(v):
			TYPE_OBJECT:
				if v is Resource:
					for k: String in shared:
						if is_same(shared[k],v): return {"@shared":k}
					return v
				if v is Node:
					var n := v as Node
					if n == root or root.is_ancestor_of(n): return {"@node":str(root.get_path_to(n))}
					fail = "%s: a node outside the isle (%s)" % [where,n]
					return null
				if v is WeakRef:
					var to: Variant = (v as WeakRef).get_ref()
					if to == null: return {"@weak":null}
					return {"@weak":value(to,where+"(weak)")}
				if is_same(v,motif): return {"@motif":true}
				return {"@obj":_object(v as Object,where)}
			TYPE_CALLABLE:
				# A script's static function, bound (not a lambda: those can't be kept).
				var c: Callable = v
				var on: Object = c.get_object()
				if on is Script and (on as Script).resource_path != "" and c.get_method() != &"" and (on as Script).has_method(c.get_method()):
					var binds: Array = []
					for b: Variant in c.get_bound_arguments(): binds.append(value(b,where+"(bound)"))
					return {"@call":[(on as Script).resource_path,str(c.get_method()),binds]}
				fail = "%s: a Callable can't be kept" % where
				return null
			TYPE_ARRAY:
				var i := _find(v)
				if i >= 0: return {"@ref":i}
				var a: Array = v
				var entry := {"kind":"array","type":[a.get_typed_builtin(),a.get_typed_class_name(),_typed_script(a.get_typed_script(),where)],"items":[]}
				i = _add(v,entry)
				var items: Array = []
				for e: Variant in a: items.append(value(e,where+"[]"))
				entry.items = items
				return {"@ref":i}
			TYPE_DICTIONARY:
				var i := _find(v)
				if i >= 0: return {"@ref":i}
				var entry := {"kind":"dict","pairs":[]}
				i = _add(v,entry)
				var pairs: Array = []
				for k: Variant in v: pairs.append([value(k,where+"{}"),value(v[k],where+"."+str(k))])
				entry.pairs = pairs
				return {"@ref":i}
			_:
				fail = "%s: a %s can't be kept" % [where,type_string(typeof(v))]
				return null

	func _typed_script(s: Variant, where: String) -> Variant:
		if s == null or not (s is Script): return null
		return script_ref(s,where)

	func _object(o: Object, where: String) -> int:
		var i := _find(o)
		if i >= 0: return i
		var entry := {"kind":"obj","class":o.get_class(),"script":null,"vars":{},"props":{}}
		i = _add(o,entry)
		var script: Script = o.get_script()
		if script != null:
			entry.script = script_ref(script,where)
			for p: Dictionary in script.get_script_property_list():
				if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
				entry.vars[p.name] = value(o.get(p.name),where+"."+str(p.name))
		for p: Dictionary in o.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE or not (int(p.usage) & PROPERTY_USAGE_STORAGE): continue
			if p.name == "script": continue
			entry.props[p.name] = value(o.get(p.name),where+"."+str(p.name))
		return i

	func _find(v: Variant) -> int:
		for e: Array in _seen:
			if is_same(e[0],v): return int(e[1])
		return -1

	func _add(v: Variant, entry: Dictionary) -> int:
		objs.append(entry)
		_seen.append([v,objs.size()-1])
		return objs.size()-1

	## A script by its path, or an inner class as [its outer's path, the
	## names down to it] (looked for in the motif's and the node's scripts
	## and what they preload).
	func script_ref(s: Script, where: String) -> Variant:
		if s.resource_path != "" and not s.resource_path.contains("::"): return s.resource_path
		var outers: Array = []
		var m: Script = motif.get_script()
		while m != null:
			outers.append(m)
			m = m.get_base_script()
		var found: Variant = null
		for outer: Script in outers:
			found = _inner_path(outer,s,2)
			if found != null: return [outer.resource_path,found]
		fail = "%s: an inner script not found (%s)" % [where,s]
		return null

	static func _inner_path(outer: Script, s: Script, depth: int) -> Variant:
		var consts := outer.get_script_constant_map()
		for k: StringName in consts:
			var c: Variant = consts[k]
			if c is Script and is_same(c,s): return [str(k)]
		if depth <= 0: return null
		for k: StringName in consts:
			var c: Variant = consts[k]
			if c is Script and (c as Script).resource_path != "" and c != outer:
				var deeper: Variant = _inner_path(c,s,depth-1)
				if deeper != null: return [str(k)]+(deeper as Array)
		return null

## Decodes what Enc encoded, against the loaded `root` and the `motif`.
class Dec:
	var root: Node
	var motif: RefCounted
	var objs: Array = []
	var shared: Dictionary
	var _made := {}

	func script_of(ref: Variant) -> Script:
		if ref is String: return load(ref)
		var outer: Script = load(str(ref[0]))
		var s: Variant = outer
		for name: String in ref[1]: s = (s as Script).get_script_constant_map()[name]
		return s

	func value(v: Variant) -> Variant:
		if not (v is Dictionary) or (v as Dictionary).size() != 1: return v
		var d: Dictionary = v
		if d.has("@node"): return root.get_node(NodePath(d["@node"]))
		if d.has("@shared"): return shared[d["@shared"]]
		if d.has("@motif"): return motif
		if d.has("@weak"): return weakref(value(d["@weak"])) if d["@weak"] != null else WeakRef.new()
		if d.has("@obj"): return _make(int(d["@obj"]))
		if d.has("@call"):
			var c: Array = d["@call"]
			var binds: Array = []
			for b: Variant in c[2]: binds.append(value(b))
			return Callable(load(str(c[0])),StringName(c[1])).bindv(binds)
		if d.has("@ref"): return _make(int(d["@ref"]))
		return v

	func _make(i: int) -> Variant:
		if _made.has(i): return _made[i]
		var e: Dictionary = objs[i]
		match str(e.kind):
			"array":
				var t: Array = e.type
				var a: Array = []
				if int(t[0]) != TYPE_NIL: a = Array([],int(t[0]),StringName(t[1]),script_of(t[2]) if t[2] != null else null)
				_made[i] = a
				for item: Variant in e.items: a.append(value(item))
				return a
			"dict":
				var d := {}
				_made[i] = d
				for pair: Array in e.pairs: d[value(pair[0])] = value(pair[1])
				return d
			_:
				var o: Object
				# (A script's own `new`: its `_init` runs with its defaults, then
				# every field is set as it was.)
				if e.script != null: o = script_of(e.script).new()
				else: o = ClassDB.instantiate(StringName(e["class"]))
				_made[i] = o
				for k: String in e.props: o.set(k,value(e.props[k]))
				for k: String in e.vars: o.set(k,value(e.vars[k]))
				return o
