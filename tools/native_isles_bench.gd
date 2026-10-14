extends SceneTree
## Motif isle builds measured, profiled and dumped (docs/design/roguelike/
## native-isles-round1.md). Builds each motif isle of the given layers as a
## motif isle's worker does (scripts/kit_isle/motif_isle.gd `start_build`:
## build, levels, held shapes), headless:
##   Godot --headless --path . -s res://tools/native_isles_bench.gd -- --layers=sprawl:2,ring:1 [--mode=time|profile|dump|par]
## --mode=time     each isle built on the main thread, timed per step.
## --mode=profile  run with `-d --profiling` before --path: each isle built in
##                 a frame of its own, so the local debugger prints that frame's
##                 GDScript functions (tools/native_isles_profile.py sums them).
## --mode=dump     each isle dumped node by node (round 2's isle_store_check
##                 dump: classes, properties, metas, meshes' and shapes' arrays
##                 hashed) into --out=<dir>/<n>_<motif>_<seed>.txt, to compare a
##                 run with the native kernels against one with --gdscript-kernels.
## --mode=par      the layer's isles built on the worker pool, --par=N at once
##                 (0 = all at once), wall time and each build's.
## --motifs=a,b    only these motif ids. --repeat=N times each (time mode).
const RuinLod = preload("res://scripts/ruin_lod.gd")
const LateShapes = preload("res://scripts/late_shapes.gd")
const LayerShapes = preload("res://scripts/roguelike/layer_shapes.gd")
const RoostMotif = preload("res://scripts/kit_isle/motif_dragon_roost.gd")
const RunLayer = preload("res://studies/run_layer.gd")

var mode := "time"
var out_dir := "/tmp/ni/dump"
var par := 0
var repeat := 1
var only: Array = []
var _isles: Array = []
var _frame := 0
var _at := 0

func _initialize() -> void:
	var layers := ["sprawl:2","ring:1"]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--layers="): layers = Array(a.get_slice("=",1).split(","))
		elif a.begins_with("--mode="): mode = a.get_slice("=",1)
		elif a.begins_with("--out="): out_dir = a.get_slice("=",1)
		elif a.begins_with("--par="): par = int(a.get_slice("=",1))
		elif a.begins_with("--repeat="): repeat = int(a.get_slice("=",1))
		elif a.begins_with("--motifs="): only = Array(a.get_slice("=",1).split(","))
	var began := Time.get_ticks_msec()
	for l: String in layers:
		var laid: Dictionary = RunLayer._plan_for(int(l.get_slice(":",1)),{},l.get_slice(":",0))
		var plan: Dictionary = laid.plan
		var n := 0
		for isle: Dictionary in plan.isles:
			if isle.role == "base": continue
			_isles.append([l,n,isle.motif])
			n += 1
		if not (plan.get("roost",{}) as Dictionary).is_empty():
			_isles.append([l,n,RoostMotif.new()])
	# --all: every other motif at its authored seed, and the families at more seeds.
	if OS.get_cmdline_user_args().has("--all"):
		var n := 0
		for path: String in ["res://scripts/kit_isle/motif_cloister_tarn.gd","res://scripts/kit_isle/motif_drowned_nave.gd","res://scripts/kit_isle/motif_hollow_keel.gd","res://scripts/kit_isle/motif_broken_ring.gd"]:
			var m: RefCounted = load(path).new()
			if m.family(): m.configure(m.default_seed())
			_isles.append(["all",n,m])
			n += 1
		for path: String in ["res://scripts/kit_isle/motif_broken_ring.gd","res://scripts/kit_isle/motif_colonnade_spine.gd"]:
			for at_seed: int in [11,222,3333]:
				var m: RefCounted = load(path).new()
				m.configure(at_seed)
				_isles.append(["all",n,m])
				n += 1
	if not only.is_empty(): _isles = _isles.filter(func(e: Array) -> bool: return only.has(e[2].id()))
	for e: Array in _isles: e[2].warm()
	print("BENCH plans %d ms, %d isles, kernels %s" % [Time.get_ticks_msec()-began,_isles.size(),"native" if preload("res://scripts/native_isle_kernels.gd").get_kernel() != null else "gdscript"])
	DirAccess.make_dir_recursive_absolute(out_dir)
	if mode == "par":
		# The main thread at a frame rate, as in play (not a busy loop of script).
		Engine.max_fps = 60
		_par.call_deferred()

static func label(e: Array) -> String:
	return "%s#%d %s seed %d" % [e[0],e[1],e[2].id(),int(e[2].isle_seed)]

## As a motif isle's worker: build, levels, held shapes. [root, ms each].
static func build(m: RefCounted) -> Array:
	var root := Node3D.new()
	root.name = "Staging"
	var t0 := Time.get_ticks_usec()
	m.build(root)
	var t1 := Time.get_ticks_usec()
	RuinLod.add(root)
	var t2 := Time.get_ticks_usec()
	LateShapes.defer(root)
	var t3 := Time.get_ticks_usec()
	return [root,(t1-t0)/1000.0,(t2-t1)/1000.0,(t3-t2)/1000.0]

func _process(_delta: float) -> bool:
	if mode == "par":
		if not _par_state.is_empty(): _par_poll()
		return false
	_frame += 1
	if _at >= _isles.size():
		print("BENCH done")
		return true
	var frame_began := Time.get_ticks_msec()
	if mode == "profile":
		# A quiet frame first (so the next prints); then each build's frame
		# held to over a second, so the local debugger prints it.
		if _frame == 1:
			OS.delay_msec(1100)
			return false
		print("PROFILE BUILD %s" % label(_isles[_at]))
	var e: Array = _isles[_at]
	_at += 1
	for r in range(repeat if mode == "time" else 1):
		var m: RefCounted = e[2]
		if r > 0: m = _fresh(m)
		var got := build(m)
		var root: Node3D = got[0]
		print("BENCH %s: build %.0f ms, lod %.0f ms, held %.0f ms, total %.0f ms" % [label(e),got[1],got[2],got[3],got[1]+got[2]+got[3]])
		if mode == "dump":
			var lines := Dump.new().dump(root,m)
			var f := FileAccess.open("%s/%s_%d_%s_%d.txt" % [out_dir,str(e[0]).replace(":","-"),int(e[1]),m.id(),int(m.isle_seed)],FileAccess.WRITE)
			f.store_string("\n".join(lines))
			f.close()
			print("DUMP %s: %d lines" % [label(e),lines.size()])
		root.free()
	if mode == "profile": OS.delay_msec(maxi(0,1100-(Time.get_ticks_msec()-frame_began)))
	return false

## A motif like `m` (its seed and knobs), not yet built.
static func _fresh(m: RefCounted) -> RefCounted:
	var n: RefCounted = (m.get_script() as Script).new()
	if m.family(): n.configure(int(m.isle_seed),m.knobs)
	n.warm()
	return n

var _par_state := {}

## The layer's isles built on the worker pool, `par` builders at once, each
## taking the next isle until none is left; the main thread keeps ticking
## (polled in `_process`), as in the game.
func _par() -> void:
	var motifs: Array = []
	for e: Array in _isles: motifs.append(_fresh(e[2]))
	var times := PackedFloat64Array()
	times.resize(motifs.size())
	var roots: Array = []
	roots.resize(motifs.size())
	var at := [0]
	var lock := Mutex.new()
	var width := motifs.size() if par <= 0 else mini(par,motifs.size())
	var tasks: Array = []
	var began := Time.get_ticks_usec()
	for w in range(width):
		tasks.append(WorkerThreadPool.add_task(func() -> void:
			while true:
				lock.lock()
				var i: int = at[0]
				at[0] += 1
				lock.unlock()
				if i >= motifs.size(): return
				var t := Time.get_ticks_usec()
				roots[i] = build(motifs[i])[0]
				times[i] = (Time.get_ticks_usec()-t)/1000.0
			,false,"bench builder"))
	_par_state = {"tasks":tasks,"began":began,"times":times,"roots":roots,"width":width,"count":motifs.size()}

func _par_poll() -> void:
	for t: int in _par_state.tasks:
		if not WorkerThreadPool.is_task_completed(t): return
	for t: int in _par_state.tasks: WorkerThreadPool.wait_for_task_completion(t)
	var wall := (Time.get_ticks_usec()-int(_par_state.began))/1000.0
	var total := 0.0
	var times: PackedFloat64Array = _par_state.times
	for i in range(int(_par_state.count)):
		total += times[i]
		print("PAR %s: %.0f ms" % [label(_isles[i]),times[i]])
		(_par_state.roots[i] as Node).free()
	print("PAR width %d of %d isles: wall %.0f ms, sum of builds %.0f ms" % [int(_par_state.width),int(_par_state.count),wall,total])
	_par_state = {}
	quit(0)

## Round 2's node-by-node dump (tools/isle_store_check.gd on perf/fast-load),
## without the store.
class Dump:
	var _res := {}
	var _objs := {}
	var _root: Node
	var _auto := RegEx.create_from_string("([@_])([A-Z][A-Za-z0-9]+)([@_])[0-9]+")

	func dump(root: Node, motif: RefCounted) -> PackedStringArray:
		_root = root
		var lines := PackedStringArray()
		for node: Node in [root]+root.find_children("*","",true,false):
			var groups: Array = node.get_groups()
			groups.sort()
			lines.append("%s %s script=%s groups=%s" % [root.get_path_to(node),node.get_class(),_script(node.get_script()),groups])
			for p: Dictionary in node.get_property_list():
				if not (int(p.usage) & (PROPERTY_USAGE_STORAGE|PROPERTY_USAGE_SCRIPT_VARIABLE)): continue
				if p.name in ["script","scene_file_path","owner"] or str(p.name).begins_with("metadata/"): continue
				lines.append("  .%s = %s" % [p.name,_canon(node.get(p.name))])
			var metas: Array = node.get_meta_list()
			metas.sort()
			for k: StringName in metas: lines.append("  :%s = %s" % [k,_canon(node.get_meta(k))])
		for p: Dictionary in motif.get_property_list():
			if not (int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
			if p.name == "built_ms" or p.name.ends_with("_ms"): continue
			lines.append("motif.%s = %s" % [p.name,_canon(motif.get(p.name))])
		var out := PackedStringArray()
		for l in lines: out.append(_auto.sub(l,"$1$2$3#",true))
		return out

	func _script(s: Variant) -> String:
		if s == null: return "-"
		var sc := s as Script
		return sc.resource_path if sc.resource_path != "" else "inner:"+str(sc.get_instance_base_type())+":"+str(sc.get_script_property_list().size())

	func _canon(v: Variant) -> String:
		match typeof(v):
			TYPE_OBJECT:
				if v == null: return "null"
				if v is Node: return _auto.sub("@"+str(_root.get_path_to(v)) if (v == _root or _root.is_ancestor_of(v)) else "@outside:"+str(v.name),"$1$2$3#",true)
				if v is Script: return "script:"+_script(v)
				if v is Resource:
					var id: int = v.get_instance_id()
					if _res.has(id): return "res#%d" % int(_res[id])
					var idx := _res.size()
					_res[id] = idx
					if (v as Resource).resource_path != "" and not (v as Resource).resource_path.contains("::"): return "file:"+(v as Resource).resource_path
					var parts := PackedStringArray()
					for p: Dictionary in (v as Object).get_property_list():
						if not (int(p.usage) & PROPERTY_USAGE_STORAGE): continue
						if p.name in ["resource_path","resource_local_to_scene","resource_name","script"]: continue
						parts.append("%s=%s" % [p.name,_canon((v as Object).get(p.name))])
					var metas: Array = (v as Object).get_meta_list()
					metas.sort()
					for k: StringName in metas: parts.append(":%s=%s" % [k,_canon((v as Object).get_meta(k))])
					var text := "%s{%s}" % [v.get_class(),",".join(parts)]
					return "res#%d:%s" % [idx,text if text.length() < 300 else text.md5_text()]
				var oid: int = v.get_instance_id()
				if _objs.has(oid): return "obj#%d" % int(_objs[oid])
				_objs[oid] = _objs.size()
				var parts := PackedStringArray()
				var s: Script = (v as Object).get_script()
				if v is WeakRef: return "weak"
				if s != null:
					for p: Dictionary in s.get_script_property_list():
						if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: parts.append("%s=%s" % [p.name,_canon((v as Object).get(p.name))])
				return "obj#%d:%s/%s{%s}" % [_objs[oid],v.get_class(),_script(s),",".join(parts)]
			TYPE_ARRAY:
				var parts := PackedStringArray()
				for e: Variant in v: parts.append(_canon(e))
				var text := "[%s]" % ",".join(parts)
				return text if text.length() < 400 else "[n=%d:%s]" % [(v as Array).size(),text.md5_text()]
			TYPE_DICTIONARY:
				var parts := PackedStringArray()
				for k: Variant in v: parts.append("%s:%s" % [_canon(k),_canon(v[k])])
				var text := "{%s}" % ",".join(parts)
				return text if text.length() < 400 else "{n=%d:%s}" % [(v as Dictionary).size(),text.md5_text()]
			TYPE_CALLABLE:
				var c: Callable = v
				var on: Object = c.get_object()
				if not (on is Script) and not c.is_standard(): return "lambda"
				return "callable(%s.%s%s)" % [_script(on) if on is Script else str(on.get_class() if on != null else null),c.get_method(),_canon(c.get_bound_arguments())]
			TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
				var c := HashingContext.new()
				c.start(HashingContext.HASH_MD5)
				c.update(var_to_bytes(v))
				return "packed(n=%d:%s)" % [v.size(),c.finish().hex_encode()]
		return var_to_str(v)
