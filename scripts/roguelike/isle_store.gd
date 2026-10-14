extends RefCounted
## A built motif isle kept on disk (docs/design/roguelike/loading-screen-round2.md):
## its art as the worker built it (scripts/kit_isle/motif_isle.gd: the motif's
## `build` into its staging node, then its levels of detail, scripts/ruin_lod.gd)
## saved as a binary scene, with what the build left on the motif and in the
## art that a scene file can't hold (node references, live scripts' state,
## groups), so loading it gives back the same isle: the same nodes, meshes,
## shapes, metas and motif fields. Loading is engine work (no GDScript
## building), so it runs on a worker beside other loads; and a file is built
## by a helper process (scripts/roguelike/isle_forge.gd), each with its own
## GDScript, since this engine runs one process's GDScript one thread at a
## time (round 2's diagnosis).
##
## Kept under `DIR`, named by `key`: the motif's script, its seed and knobs,
## the look and the launch flags a build reads, the engine, and a hash of
## every script (`code_hash`), so any change of code builds afresh. The four
## materials every isle shares (`shared`) are saved tagged and put back as
## the live ones on load, so a look or weather change still reaches them.
const RuinLod = preload("res://scripts/ruin_lod.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Style = preload("res://scripts/ruin_stone_style.gd")

const DIR := "user://isle_cache"
## Bumped when the file's layout changes.
const VERSION := 1
## The store keeps about this much (bytes); the least recently used go first.
const KEEP_BYTES := 6_000_000_000
## The root's meta holding what the scene can't.
const STATE := &"isle_store"
## A shared material's tag (its key in `shared`).
const SHARED_TAG := &"isle_store_shared"
## Launch flags that change nothing an isle's build reads (left out of the key).
const LOOSE_FLAGS := ["--seed=","--shape=","--knob=","--no-title","--loading-trace","--no-shader-warmup","--shader-warmup","--no-loading-screen",
	"--no-isle-store","--forge-","--secs=","--out=","--cap=","--caps=","--stills","--parts=","--turn=","--window=","--no-next","--procs","--census",
	"--motifs-now","--no-flora","--no-life","--no-bell","--quit-after","--plan-away"]

static var _hash := ""
static var _hash_lock := Mutex.new()

## Whether the store is in use: not with --no-isle-store.
static func enabled() -> bool:
	return not "--no-isle-store" in preload("res://scripts/launch_args.gd").user_args()

## The four materials the isles share, live: {key: material}.
static func shared() -> Dictionary:
	return {"ground":KitLook.ground_material(),"rock":KitLook.rock_material(),"stone":RuinKit.materials().stone,"growth":RuinKit.materials().growth}

# --- The key ----------------------------------------------------------------------------

## A hash of every script and data file the game runs (once; a millisecond
## or so per hundred files). Any change and every isle is built afresh.
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
		_hash = ctx.finish().hex_encode()
	var out := _hash
	_hash_lock.unlock()
	return out

static func _gather(dir: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir)
	if d == null: return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".json") or f.ends_with(".cfg") or f.ends_with(".gdshader"): out.append(dir.path_join(f))
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

## What picks the isle: [script path, seed (-1 not a family), knobs,
## still bells].
static func recipe(motif: RefCounted) -> Dictionary:
	var knobs: Dictionary = motif.get("knobs") if motif.get("knobs") is Dictionary else {}
	var keys := knobs.keys()
	keys.sort()
	var ordered := []
	for k: Variant in keys: ordered.append([str(k),var_to_str(knobs[k])])
	return {"script":(motif.get_script() as Script).resource_path,"seed":int(motif.get("isle_seed")) if motif.get("isle_seed") != null else -1,
		"knobs":ordered,"bells":bool(motif.get("still_bells")) if motif.get("still_bells") != null else false}

## The file a motif's build is kept in.
static func key(motif: RefCounted) -> String:
	var r := recipe(motif)
	var text := var_to_str([VERSION,code_hash(),r.script,r.seed,r.knobs,r.bells,Style.current,
		build_flags(preload("res://scripts/launch_args.gd").user_args())])
	return "%s_%d_%s" % [str(motif.id()),int(r.seed),text.md5_text().left(20)]

static func path_of(motif: RefCounted) -> String:
	var id := motif.get_instance_id()
	_books.lock()
	var known: Variant = _paths.get(id)
	_books.unlock()
	if known != null: return known
	var path := ProjectSettings.globalize_path(DIR.path_join(key(motif)+".scn"))
	_books.lock()
	if _paths.size() > 512: _paths.clear()
	_paths[id] = path
	_books.unlock()
	return path

## A motif's file, worked out once (its recipe doesn't change once placed).
static var _paths := {}

## A file that couldn't be read: not tried again this session.
static func failed(motif: RefCounted) -> void:
	var path := path_of(motif)
	_books.lock()
	_failed[path] = true
	_books.unlock()

static func has(motif: RefCounted) -> bool:
	return FileAccess.file_exists(path_of(motif))

# --- Saving (the helper's, or anyone's: the tree is spent) ------------------------------------

## Saves `root` (the motif's build, its levels added) and what the build left
## on `motif` to `path`. `root` is changed (owners, scripts and some metas taken
## off) and should be freed after. Answers "" or what went wrong.
static func save(motif: RefCounted, root: Node, path: String) -> String:
	var why := _save(motif,root,path)
	if why != "":
		# Not kept (and not tried again): built in the game as before.
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var f := FileAccess.open(path+".nokeep",FileAccess.WRITE)
		if f != null: f.store_string(why)
	return why

static func _save(motif: RefCounted, root: Node, path: String) -> String:
	var enc := Enc.new()
	enc.root = root
	enc.motif = motif
	enc.shared = shared()
	var state := {"version":VERSION,"motif":{},"scripts":[],"metas":[],"groups":[]}
	for p: Dictionary in motif.get_property_list():
		if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var kept: Variant = enc.value(motif.get(p.name),"motif."+str(p.name))
		# A field that can't be kept (a callable in a family's cached plan)
		# is left as the game's own motif has it (made from the same seed);
		# tools/isle_store_check.gd compares the fields after.
		if enc.fail != "":
			enc.fail = ""
			continue
		state.motif[p.name] = kept
	var nodes: Array = [root]+root.find_children("*","",true,false)
	for node: Node in nodes:
		var where := str(root.get_path_to(node))
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
	if enc.fail != "": return enc.fail
	state.objs = enc.objs
	# Off the nodes what the scene can't hold, put back on load.
	for m: Array in state.metas: root.get_node(NodePath(m[0])).remove_meta(m[1])
	for s: Array in state.scripts: root.get_node(NodePath(s[0])).set_script(null)
	for key_name: String in enc.shared:
		(enc.shared[key_name] as Material).set_meta(SHARED_TAG,key_name)
	for node: Node in nodes:
		if node != root: node.owner = root
	root.set_meta(STATE,state)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK: return "pack failed (%d)" % err
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	# (The saver goes by the extension: the part file ends in .scn too.)
	var tmp := path.get_basename()+".part%d.scn" % OS.get_process_id()
	err = ResourceSaver.save(packed,tmp)
	for key_name: String in enc.shared: (enc.shared[key_name] as Material).remove_meta(SHARED_TAG)
	if err != OK: return "save failed (%d)" % err
	if DirAccess.rename_absolute(tmp,path) != OK: return "rename failed"
	return ""

# --- Loading (on a worker) ----------------------------------------------------------------

## The art kept for `motif` (as its build would have left it in `into`'s
## place, levels added), its fields set as the build set them; null if none
## or it can't be read.
static func load_art(motif: RefCounted, path: String, times := {}) -> Node3D:
	if not FileAccess.file_exists(path):
		push_warning("isle store: no %s" % path.get_file())
		return null
	# (Deep: nothing shared with another load of the same file, so a repeated
	# motif's copies are their own, as two builds are.)
	var t := Time.get_ticks_usec()
	var packed := ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	times.read_us = Time.get_ticks_usec()-t
	t = Time.get_ticks_usec()
	if packed == null:
		push_warning("isle store: %s didn't load" % path.get_file())
		return null
	var root := packed.instantiate() as Node3D
	times.instance_us = Time.get_ticks_usec()-t
	t = Time.get_ticks_usec()
	if root == null:
		push_warning("isle store: %s didn't instantiate" % path.get_file())
		return null
	var state: Dictionary = root.get_meta(STATE,{})
	root.remove_meta(STATE)
	# As built in code: no owners (`find_children` reads them), no scene file.
	root.scene_file_path = ""
	for node: Node in root.find_children("*","",true,false): node.owner = null
	if int(state.get("version",-1)) != VERSION:
		push_warning("isle store: %s is of another version" % path.get_file())
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
	times.decode_us = Time.get_ticks_usec()-t
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

# --- Small things kept: the plan's piece footprints ---------------------------------------

## The kit pieces' footprints the plan measures (KitMotif `piece_block`,
## 2-4 s of building pieces at launch) kept between launches, for this code.
static func boxes_path() -> String:
	var text := var_to_str([VERSION,code_hash(),Style.current,build_flags(preload("res://scripts/launch_args.gd").user_args())])
	return ProjectSettings.globalize_path(DIR.path_join("boxes_%s.txt" % text.md5_text().left(20)))

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

# --- The helpers --------------------------------------------------------------------------------

## Helper processes building now (file -> pid), waiting to start ([file,
## args]), and files a helper failed to make.
static var _forging := {}
static var _queue: Array = []
## Asked for ahead (the next layer's isles): started only while `_queue` is
## empty and `background` (no loading screen up).
static var _later: Array = []
static var background := true
## Helpers at once building ahead (the next layer's isles, during play).
const AHEAD_PROCS := 2
static var _failed := {}
## When each file was asked for and made (ms), for the log.
static var asked := {}
static var made := {}
## The helpers' books, kept by the main thread and the plan's worker.
static var _books := Mutex.new()

## Whether helpers can run: the store in use, an editor build of the engine
## (an exported game has no project to point a helper at), not headless, and
## not --forge-procs=0.
static func can_forge() -> bool:
	return enabled() and OS.has_feature("editor") and DisplayServer.get_name() != "headless" and forge_procs() > 0

## How many helpers at once: --forge-procs=N, else half the logical cores,
## 2 to 8.
static func forge_procs() -> int:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--forge-procs="): return maxi(int(a.get_slice("=",1)),0)
	return clampi(OS.get_processor_count()/2,2,8)

## Where `motif`'s file stands: "ready" (kept), "forging" (a helper on it),
## "queued", "failed" (a helper ran and made none), "none".
static func state(motif: RefCounted) -> String:
	var path := path_of(motif)
	_books.lock()
	var busy := _forging.has(path)
	for q: Array in _queue:
		if q[0] == path: busy = true
	var ahead := -1
	for i in range(_later.size()):
		if _later[i][0] == path: ahead = i
	_books.unlock()
	if busy: return "forging"
	if ahead >= 0: return "later"
	if _failed.has(path) or FileAccess.file_exists(path+".nokeep"): return "failed"
	if FileAccess.file_exists(path): return "ready"
	return "none"

## A helper asked to build `motif` into the store (once; started by `pump`).
static func forge(motif: RefCounted, later := false) -> void:
	if not can_forge(): return
	var path := path_of(motif)
	if state(motif) != "none": return
	var r := recipe(motif)
	var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"-s","res://scripts/roguelike/isle_forge.gd","--"])
	args.append_array(build_flags(preload("res://scripts/launch_args.gd").user_args()))
	args.append_array(["--forge-motif="+str(r.script),"--forge-seed="+str(r.seed),"--forge-bells="+("1" if r.bells else "0"),"--forge-style="+Style.current,"--forge-out="+path])
	_books.lock()
	(_later if later else _queue).append([path,args])
	if not later: asked[path] = Time.get_ticks_msec()
	_books.unlock()

## Starts queued helpers up to `forge_procs`, and notes those that ended.
static func pump() -> void:
	_books.lock()
	for path: String in _forging.keys():
		if OS.is_process_running(int(_forging[path])): continue
		_forging.erase(path)
		if FileAccess.file_exists(path): made[path] = Time.get_ticks_msec()
		else:
			_failed[path] = true
			push_warning("isle store: a helper made no %s; it is built here instead" % path.get_file())
	while not _queue.is_empty() or (background and not _later.is_empty()):
		if _forging.size() >= forge_procs(): break
		var ahead := _queue.is_empty()
		# Built ahead while the game is played: AHEAD_PROCS at most, and on
		# macOS in the background QoS class (the efficiency cores, I/O held
		# back), so the frames being played keep the performance cores.
		if ahead and _forging.size() >= AHEAD_PROCS: break
		var q: Array = _queue.pop_front() if not ahead else _later.pop_front()
		var exe := OS.get_executable_path()
		var args: PackedStringArray = q[1]
		if ahead and OS.get_name() == "macOS" and FileAccess.file_exists("/usr/sbin/taskpolicy"):
			args = PackedStringArray(["-b",exe])+args
			exe = "/usr/sbin/taskpolicy"
		var pid := OS.create_process(exe,args)
		if pid <= 0:
			_failed[q[0]] = true
			continue
		_forging[q[0]] = pid
	_books.unlock()

## Whether any helper runs or waits.
static func forging() -> bool:
	_books.lock()
	var busy := not _forging.is_empty() or not _queue.is_empty()
	_books.unlock()
	return busy

## Every helper stopped (the game is going).
static func stop_all() -> void:
	_books.lock()
	_queue.clear()
	for path: String in _forging: OS.kill(int(_forging[path]))
	_forging.clear()
	_books.unlock()

## Every motif isle of a layer's plan (and its roost) asked of the helpers
## (safe on the plan's worker).
static func forge_plan(plan: Dictionary, later := false) -> void:
	if not can_forge(): return
	if later and not "--forge-ahead" in preload("res://scripts/launch_args.gd").user_args(): return
	for isle: Dictionary in plan.get("isles",[]):
		if isle.get("role") == "base" or not isle.has("motif"): continue
		forge(isle.motif,later)
	if not (plan.get("roost",{}) as Dictionary).is_empty(): forge(load("res://scripts/kit_isle/motif_dragon_roost.gd").new(),later)
	pump()

## An isle asked for ahead, wanted now: to the front.
static func hurry(motif: RefCounted) -> void:
	var path := path_of(motif)
	_books.lock()
	for i in range(_later.size()):
		if _later[i][0] == path:
			_queue.append(_later[i])
			asked[path] = Time.get_ticks_msec()
			_later.remove_at(i)
			break
	_books.unlock()

## The motifs any layer may place that build the same whatever the seed
## (not a family), and the roost, asked of the helpers at launch, before
## the plan is laid.
static func forge_fixed() -> void:
	if not can_forge(): return
	var LayerPlan = load("res://scripts/roguelike/layer_plan.gd")
	for p: Array in LayerPlan.POOL:
		var m: RefCounted = (p[1] as Script).new()
		if m.family(): continue
		if m.get("still_bells") != null: m.set("still_bells","--no-bell" in preload("res://scripts/launch_args.gd").user_args())
		forge(m)
	forge(load("res://scripts/kit_isle/motif_dragon_roost.gd").new())
	pump()

## The store's folder, made, and kept out of Spotlight's index on macOS
## (gigabytes of scene files it would otherwise read while the game loads).
static func make_dir() -> void:
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	if OS.get_name() == "macOS" and not FileAccess.file_exists(dir.path_join(".metadata_never_index")):
		var f := FileAccess.open(dir.path_join(".metadata_never_index"),FileAccess.WRITE)
		if f != null: f.close()

# --- Keeping the store in bounds ----------------------------------------------------------

## The least recently used files removed past KEEP_BYTES (and any half
## written ones left by a helper that died).
static func prune() -> void:
	make_dir()
	var dir := ProjectSettings.globalize_path(DIR)
	var d := DirAccess.open(dir)
	if d == null: return
	var files: Array = []
	var total := 0
	for f in d.get_files():
		var full := dir.path_join(f)
		if ".part" in f:
			if Time.get_unix_time_from_system()-FileAccess.get_modified_time(full) > 600: DirAccess.remove_absolute(full)
			continue
		var size := FileAccess.get_size(full)
		files.append([FileAccess.get_modified_time(full),full,size])
		total += size
	files.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for f: Array in files:
		if total <= KEEP_BYTES: break
		DirAccess.remove_absolute(f[1])
		total -= int(f[2])

## Marks `path` as just used (its time is the store's order).
static func touch(path: String) -> void:
	var f := FileAccess.open(path,FileAccess.READ_WRITE)
	if f != null:
		f.seek(0)
		var b := f.get_8()
		f.seek(0)
		f.store_8(b)
		f.close()

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
