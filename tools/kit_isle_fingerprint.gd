extends SceneTree
## A kit isle's layout fingerprint (headless): what the pilot and the plane
## can stand on and bump, so a refactor of the shared kit isle builder
## (scripts/kit_isle/) can prove it moved nothing. Rays straight down on a
## RAY_STEP grid over the isle, every layer, their hits (height, normal) to
## the millimetre; and every collision shape in the scene, its kind, layer
## and world-space data, sorted (so how the shapes are split into bodies
## doesn't count) and hashed by kind.
##   godot --headless --path . --script tools/kit_isle_fingerprint.gd -- res://studies/bell_spires_isle.tscn [--box=x0,z0,x1,z1] [--dump=PATH]
## Prints one line per part; diff two runs' output.
const RAY_STEP := 0.5

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var path := ""
	var box := Rect2()
	var dump := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("res://"): path = a
		elif a.begins_with("--box="):
			var p := a.trim_prefix("--box=").split(",")
			box = Rect2(float(p[0]),float(p[1]),float(p[2])-float(p[0]),float(p[3])-float(p[1]))
		elif a.begins_with("--dump="): dump = a.trim_prefix("--dump=")
	var study: Node = load(path).instantiate()
	study.set("scripted",true)
	root.add_child(study)
	current_scene = study
	while not study.get("walk_ready"): await process_frame
	for i in range(3): await physics_frame
	print("FP start ",_v(study.get("start")))
	var shapes := {}
	var count := {}
	_collect(study,shapes,count)
	var kinds: Array = shapes.keys()
	kinds.sort()
	var bounds := AABB()
	var first := true
	for kind: String in kinds:
		var list: PackedStringArray = shapes[kind]
		list.sort()
		print("FP shapes %s %d %s" % [kind,list.size(),"\n".join(list).md5_text()])
		if dump != "": FileAccess.open(dump+"."+kind,FileAccess.WRITE).store_string("\n".join(list))
	for k: String in count: print("FP count ",k," ",count[k])
	if box.size == Vector2.ZERO: box = Rect2(-20.0,-120.0,220.0,200.0)
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var rays := PackedStringArray()
	var hits := 0
	var x := box.position.x+0.123
	while x < box.end.x:
		var z := box.position.y+0.0771
		while z < box.end.y:
			var q := PhysicsRayQueryParameters3D.create(Vector3(x,140.0,z),Vector3(x,-60.0,z),0xFFFFFFFF)
			q.hit_back_faces = false
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				hits += 1
				rays.append("%.2f,%.2f:%.3f/%.2f,%.2f,%.2f" % [x,z,hit.position.y,snappedf(hit.normal.x,0.01)+0.0,snappedf(hit.normal.y,0.01)+0.0,snappedf(hit.normal.z,0.01)+0.0])
			z += RAY_STEP
		x += RAY_STEP
	print("FP rays %d %s" % [hits,"\n".join(rays).md5_text()])
	if dump != "":
		var f := FileAccess.open(dump,FileAccess.WRITE)
		f.store_string("\n".join(rays))
	quit(0)

func _v(v: Variant) -> String:
	if v is Vector3: return "%.3f,%.3f,%.3f" % [v.x,v.y,v.z]
	return str(v)

func _collect(node: Node, shapes: Dictionary, count: Dictionary) -> void:
	if node is CollisionShape3D and not (node as CollisionShape3D).disabled and (node as CollisionShape3D).shape != null:
		var owner_body := node.get_parent() as CollisionObject3D
		var layer := owner_body.collision_layer if owner_body != null else 0
		var shape: Shape3D = (node as CollisionShape3D).shape
		var t: Transform3D = (node as Node3D).global_transform
		var kind := shape.get_class()
		var text := "%d|" % layer
		if shape is BoxShape3D: text += "%s|%s" % [_v((shape as BoxShape3D).size),_t(t)]
		elif shape is ConvexPolygonShape3D:
			var pts := PackedStringArray()
			for p: Vector3 in (shape as ConvexPolygonShape3D).points: pts.append(_v(t*p))
			pts.sort()
			text += ";".join(pts)
		elif shape is ConcavePolygonShape3D:
			var faces := (shape as ConcavePolygonShape3D).get_faces()
			var tris := PackedStringArray()
			for i in range(0,faces.size(),3):
				var tri := PackedStringArray([_v(t*faces[i]),_v(t*faces[i+1]),_v(t*faces[i+2])])
				tri.sort()
				tris.append(";".join(tri))
			tris.sort()
			# Each triangle on its own, so a trimesh split in two still matches.
			for tri in tris:
				if not shapes.has("Tri"): shapes["Tri"] = PackedStringArray()
				shapes["Tri"].append("%d|%s" % [layer,tri])
			count[kind] = count.get(kind,0)+1
			return
		else: text += "%s|%s" % [str(shape),_t(t)]
		if not shapes.has(kind): shapes[kind] = PackedStringArray()
		shapes[kind].append(text)
		count[kind] = count.get(kind,0)+1
	for child in node.get_children(): _collect(child,shapes,count)

func _t(t: Transform3D) -> String:
	return "%s %s %s %s" % [_v(t.basis.x),_v(t.basis.y),_v(t.basis.z),_v(t.origin)]
