extends SceneTree
## Checks the fixed cache (scripts/roguelike/fixed_cache.gd) gives back what a
## build makes (docs/design/roguelike/loading-screen-round2b.md): the aqueduct
## isle's base art built here, a copy kept and loaded back, both dumped node by
## node (class, script, groups, every stored and script property, metas, the
## motif's fields; resources by content, arrays hashed) and compared; and the
## plan's piece footprints measured fresh against those loaded from the file.
## Run twice with different seeds to see the cache is the run's-seed-free:
##   Godot --headless --path . -s res://tools/fixed_cache_check.gd
const FixedCache = preload("res://scripts/roguelike/fixed_cache.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const KitMotif = preload("res://scripts/kit_isle/kit_motif.gd")

var _res := {}
var _objs := {}
var _root: Node

func _initialize() -> void:
	var bad := 0
	var base_script: GDScript = load("res://studies/aqueduct_isle_base.gd")
	var a: RefCounted = base_script.new()
	a.warm()
	var root_a := Node3D.new()
	var t := Time.get_ticks_msec()
	a.build(root_a)
	print("CHECK base built here in %d ms" % (Time.get_ticks_msec()-t))
	var dump_a := _dump(root_a,a)
	var path := FixedCache.base_path()
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	FixedCache.save_base(a,root_a)
	var began := Time.get_ticks_msec()
	while not FixedCache.saved(): await process_frame
	FixedCache.finish_save()
	print("CHECK saved in %d ms" % (Time.get_ticks_msec()-began))
	print("CHECK file %s: %d MB" % [path.get_file(),_size(path)/1048576])
	var b: RefCounted = base_script.new()
	t = Time.get_ticks_msec()
	var root_b := FixedCache.load_base(b)
	print("CHECK base loaded in %d ms" % (Time.get_ticks_msec()-t))
	if root_b == null:
		print("CHECK the base didn't load")
		quit(1)
		return
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
			if shown < 8:
				shown += 1
				print("  - %s\n  + %s" % [la.left(600),lb.left(600)])
	print("CHECK base: %d lines, %d differ; triangles %d / %d" % [dump_a.size(),diffs,_tris(root_a),_tris(root_b)])
	if diffs > 0: bad += 1
	root_a.free()
	root_b.free()
	# The footprints: measured fresh, kept, then loaded into an empty table.
	KitMotif._boxes.clear()
	t = Time.get_ticks_msec()
	LayerPlan.warm()
	var fresh: Dictionary = KitMotif.boxes_all().duplicate()
	print("CHECK footprints: %d measured in %d ms" % [fresh.size(),Time.get_ticks_msec()-t])
	FixedCache.boxes_save()
	KitMotif._boxes.clear()
	FixedCache.boxes_load()
	var kept: Dictionary = KitMotif.boxes_all()
	var same := fresh.size() == kept.size()
	for k: String in fresh:
		if not kept.has(k) or not is_equal_approx((fresh[k] as Rect2).position.x,(kept[k] as Rect2).position.x) or (fresh[k] as Rect2) != (kept[k] as Rect2): same = false
	print("CHECK footprints: %d kept, %s" % [kept.size(),"identical" if same else "DIFFER"])
	var keys := fresh.keys()
	keys.sort()
	print("CHECK footprint keys (piece/seed/weathered): %s" % ", ".join(keys))
	if not same: bad += 1
	print("CHECK done: %d problems" % bad)
	quit(0 if bad == 0 else 1)

func _size(path: String) -> int:
	var f := FileAccess.open(path,FileAccess.READ)
	return f.get_length() if f != null else 0

func _tris(root: Node) -> int:
	var n := 0
	for mi: Node in root.find_children("*","MeshInstance3D",true,false):
		var m := (mi as MeshInstance3D).mesh
		if not (m is ArrayMesh): continue
		for s in range(m.get_surface_count()): n += m.surface_get_array_len(s)/3
	return n

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
			if v is Node: return _auto.sub("@"+str(_root.get_path_to(v)) if (v == _root or _root.is_ancestor_of(v)) else "@outside:"+str(v.name),"_$2_#",true)
			if v is Script: return "script:"+_script(v)
			if v is Resource:
				for k: String in FixedCache.shared():
					if is_same(FixedCache.shared()[k],v): return "shared:"+k
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
					if k == FixedCache.SHARED_TAG: continue
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
## before: the same isle gets other numbers in another run. Numbered alike
## (a scene file also writes the `@` as `_`).
var _auto := RegEx.create_from_string("([@_])([A-Z][A-Za-z0-9]+)([@_])[0-9]+")
func _norm(lines: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for l in lines: out.append(_auto.sub(l,"_$2_#",true))
	return out
