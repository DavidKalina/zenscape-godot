extends SceneTree
## Checks the isle store (scripts/roguelike/isle_store.gd) gives back the very
## isle a build makes (docs/design/roguelike/loading-screen-round2.md): each
## motif of the given layers built here (as a motif isle's worker does: build,
## levels, held shapes), then built by a helper process (scripts/roguelike/
## isle_forge.gd), kept and loaded back; both dumped node by node (class,
## script, groups, every stored and script property, metas, the motif's
## fields; resources by their content, meshes' and shapes' arrays hashed) and
## compared. Headless:
##   Godot --headless --path . -s res://tools/isle_store_check.gd -- [--layers=sprawl:2,ring:1] [--all] [--keep]
const IsleStore = preload("res://scripts/roguelike/isle_store.gd")
const RuinLod = preload("res://scripts/ruin_lod.gd")
const LateShapes = preload("res://scripts/late_shapes.gd")
const LayerShapes = preload("res://scripts/roguelike/layer_shapes.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const RoostMotif = preload("res://scripts/kit_isle/motif_dragon_roost.gd")

var _res := {}
var _objs := {}
var _root: Node

func _initialize() -> void:
	var layers := ["sprawl:2","ring:1"]
	var all := false
	var keep := false
	var only := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--layers="): layers = Array(a.get_slice("=",1).split(","))
		elif a == "--all": all = true
		elif a == "--keep": keep = true
		elif a.begins_with("--only="): only = a.get_slice("=",1)
	var recipes: Array = []
	var seen := {}
	for l: String in layers:
		var plan: Dictionary = LayerShapes.make(l.get_slice(":",0),int(l.get_slice(":",1)),{})
		var ms: Array = []
		for isle: Dictionary in plan.isles:
			if isle.role != "base": ms.append(isle.motif)
		if not (plan.get("roost",{}) as Dictionary).is_empty(): ms.append(RoostMotif.new())
		for m: RefCounted in ms:
			var r := IsleStore.recipe(m)
			var k := var_to_str(r)
			if not seen.has(k):
				seen[k] = true
				recipes.append(r)
	if all:
		for path: String in ["res://scripts/kit_isle/motif_cloister_tarn.gd","res://scripts/kit_isle/motif_drowned_nave.gd","res://scripts/kit_isle/motif_hollow_keel.gd","res://scripts/kit_isle/motif_broken_ring.gd"]:
			var m: RefCounted = load(path).new()
			if m.family(): m.configure(m.default_seed())
			var r := IsleStore.recipe(m)
			if not seen.has(var_to_str(r)):
				seen[var_to_str(r)] = true
				recipes.append(r)
	if OS.get_cmdline_user_args().has("--base"): recipes.append(IsleStore.recipe(load("res://studies/aqueduct_isle_base.gd").new()))
	var bad := 0
	if only != "": recipes = recipes.filter(func(r: Dictionary) -> bool: return only in str(r.script))
	for r: Dictionary in recipes:
		var a := _make(r)
		a.warm()
		var root_a := Node3D.new()
		root_a.name = "Staging"
		var t := Time.get_ticks_msec()
		a.build(root_a)
		RuinLod.add(root_a)
		LateShapes.defer(root_a)
		var built := Time.get_ticks_msec()-t
		var dump_a := _dump(root_a,a)
		var out := ProjectSettings.globalize_path("user://isle_check/%s_%d.scn" % [r.script.get_file().get_basename(),int(r.seed)])
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var args := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"-s","res://scripts/roguelike/isle_forge.gd","--",
			"--forge-motif="+str(r.script),"--forge-seed="+str(r.seed),"--forge-bells="+("1" if r.bells else "0"),"--forge-style="+preload("res://scripts/ruin_stone_style.gd").current,"--forge-out="+out])
		t = Time.get_ticks_msec()
		var said: Array = []
		var code := OS.execute(OS.get_executable_path(),args,said,true)
		var forged := Time.get_ticks_msec()-t
		var b := _make(r)
		t = Time.get_ticks_msec()
		var root_b := IsleStore.load_art(b,out)
		var loaded := Time.get_ticks_msec()-t
		if root_b == null:
			print("CHECK %s seed %d: helper exit %d, no isle loaded\n%s" % [r.script.get_file(),int(r.seed),code,"".join(said).right(2000)])
			bad += 1
			continue
		LateShapes.defer(root_b)
		var dump_b := _dump(root_b,b)
		dump_a = _norm(dump_a)
		dump_b = _norm(dump_b)
		var diffs := 0
		var shown := 0
		for i in range(maxi(dump_a.size(),dump_b.size())):
			var la: String = dump_a[i] if i < dump_a.size() else "<none>"
			var lb: String = dump_b[i] if i < dump_b.size() else "<none>"
			if la != lb:
				diffs += 1
				if shown < 6:
					shown += 1
					print("  - %s\n  + %s" % [la.left(600),lb.left(600)])
		print("CHECK %s seed %d: %d lines, %d differ; built here %d ms, helper %d ms, loaded %d ms, file %d MB, triangles %d / %d" % [r.script.get_file(),int(r.seed),
			dump_a.size(),diffs,built,forged,loaded,FileAccess.get_file_as_bytes(out).size()/1048576 if false else _size(out)/1048576,RuinKit_tris(root_a),RuinKit_tris(root_b)])
		if diffs > 0: bad += 1
		root_a.free()
		root_b.free()
		if not keep: DirAccess.remove_absolute(out)
	print("CHECK done: %d of %d differ" % [bad,recipes.size()])
	quit(0 if bad == 0 else 1)

func _size(path: String) -> int:
	var f := FileAccess.open(path,FileAccess.READ)
	return f.get_length() if f != null else 0

func RuinKit_tris(root: Node) -> int:
	var n := 0
	for mi: Node in root.find_children("*","MeshInstance3D",true,false):
		var m := (mi as MeshInstance3D).mesh
		if not (m is ArrayMesh): continue
		for s in range(m.get_surface_count()): n += m.surface_get_array_len(s)/3
	return n

func _make(r: Dictionary) -> RefCounted:
	var m: RefCounted = load(r.script).new()
	if int(r.seed) >= 0: m.configure(int(r.seed))
	if m.get("still_bells") != null: m.set("still_bells",r.bells)
	# As the plan reads it (scripts/roguelike/layer_plan.gd `_motif_isle`).
	m.sockets()
	return m

# --- The dump --------------------------------------------------------------------------------

func _dump(root: Node, motif: RefCounted) -> PackedStringArray:
	_res = {}
	_objs = {}
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
	return lines

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
				for k: String in IsleStore.shared():
					if is_same(IsleStore.shared()[k],v): return "shared:"+k
				var id: int = v.get_instance_id()
				if _res.has(id): return "res#%d" % int(_res[id][0])
				var idx := _res.size()
				_res[id] = [idx,""]
				var parts := PackedStringArray()
				if (v as Resource).resource_path != "" and not (v as Resource).resource_path.contains("::"): return "file:"+(v as Resource).resource_path
				for p: Dictionary in (v as Object).get_property_list():
					if not (int(p.usage) & PROPERTY_USAGE_STORAGE): continue
					if p.name in ["resource_path","resource_local_to_scene","resource_name","script"]: continue
					parts.append("%s=%s" % [p.name,_canon((v as Object).get(p.name))])
				var metas: Array = (v as Object).get_meta_list()
				metas.sort()
				for k: StringName in metas:
					if k == IsleStore.SHARED_TAG: continue
					parts.append(":%s=%s" % [k,_canon((v as Object).get_meta(k))])
				var text := "%s{%s}" % [v.get_class(),",".join(parts)]
				return "res#%d:%s" % [idx,text if text.length() < 300 else text.md5_text()]
			var oid: int = v.get_instance_id()
			if _objs.has(oid): return "obj#%d" % int(_objs[oid])
			_objs[oid] = _objs.size()
			var parts := PackedStringArray()
			var s: Script = (v as Object).get_script()
			if v is WeakRef: return "weak(%s)" % _canon((v as WeakRef).get_ref()) if not ((v as WeakRef).get_ref() is RefCounted and not ((v as WeakRef).get_ref() is Resource)) else "weak(object)"
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
			return "packed(n=%d:%s)" % [v.size(),_md5(var_to_bytes(v))]
	return var_to_str(v)

func _md5(b: PackedByteArray) -> String:
	var c := HashingContext.new()
	c.start(HashingContext.HASH_MD5)
	c.update(b)
	return c.finish().hex_encode()

## Auto names (`@CollisionShape3D@2755`) count every node the process made
## before: the same isle gets other numbers in another run. Numbered alike.
var _auto := RegEx.create_from_string("([@_])([A-Z][A-Za-z0-9]+)([@_])[0-9]+")
func _norm(lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for l in lines: out.append(_auto.sub(l,"$1$2$3#",true))
	return out
