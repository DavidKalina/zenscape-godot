extends SceneTree
## Headless probe for the God Hand glb: node tree, bones, clips, attachment heights,
## vertex colour alpha, material and glTF extras.
## Run: Godot --headless --path . --script res://tools/probe_god_hand.gd

const PATH := "res://assets/models/zenscape-god-hand.glb"
const ATTACH := ["Pinch", "Palm", "Orb", "Pollen"]
const CONTACTS := {"PinchIn": 0.4, "PressIn": 0.433, "CupIn": 0.7, "CupOut": 0.3}


func _initialize() -> void:
	var packed := load(PATH) as PackedScene
	if packed == null:
		print("FAIL: could not load ", PATH)
		quit(1)
		return
	var root := packed.instantiate() as Node3D
	get_root().add_child(root)
	await process_frame  # AnimationPlayer resolves tracks only once inside the tree
	print("== node tree")
	_tree(root, 0)
	var skel := _find(root, "Skeleton3D") as Skeleton3D
	var mi := _find(root, "MeshInstance3D") as MeshInstance3D
	var player := _find(root, "AnimationPlayer") as AnimationPlayer
	print("== extras / metadata")
	_meta(root)
	if skel:
		_bones(root, skel)
	if mi:
		_mesh(root, mi)
	if player and skel:
		_clips(root, skel, player)
	quit(0)


func _tree(n: Node, depth: int) -> void:
	if depth > 5:
		return
	var extra := ""
	if n is Node3D:
		var t := (n as Node3D).transform
		extra = " origin=%s basis_x=%s basis_z=%s" % [t.origin, t.basis.x, t.basis.z]
	print("  ".repeat(depth), n.name, " <", n.get_class(), ">", extra)
	for c in n.get_children():
		_tree(c, depth + 1)


func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var f := _find(c, cls)
		if f:
			return f
	return null


func _meta(n: Node) -> void:
	for k in n.get_meta_list():
		print("  meta on ", n.name, " <", n.get_class(), ">", " [", k, "] = ", n.get_meta(k))
	for c in n.get_children():
		_meta(c)


func _skel_to_root(root: Node3D, skel: Skeleton3D) -> Transform3D:
	# walk local transforms (the instance is not inside the tree during _initialize)
	var xf := Transform3D.IDENTITY
	var n: Node = skel
	while n != root and n != null:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _bones(root: Node3D, skel: Skeleton3D) -> void:
	print("== skeleton: ", skel.get_bone_count(), " bones; skel->root xform ", _skel_to_root(root, skel))
	var xf := _skel_to_root(root, skel)
	for i in skel.get_bone_count():
		var p := skel.get_bone_parent(i)
		var pos := xf * skel.get_bone_global_rest(i).origin
		print("  %2d %-14s parent=%-12s rest_pos=(%.3f, %.3f, %.3f)" % [i, skel.get_bone_name(i),
			skel.get_bone_name(p) if p >= 0 else "-", pos.x, pos.y, pos.z])


func _mesh(root: Node3D, mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	print("== mesh ", mi.name, " surfaces=", mesh.get_surface_count(), " aabb=", mesh.get_aabb())
	print("  skin=", mi.skin, " skeleton path=", mi.skeleton)
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		print("  surface ", s, " verts=", verts.size(), " tris=", (idx.size() / 3 if idx != null else verts.size() / 3),
			" format=", mesh.surface_get_format(s))
		var cols = arrays[Mesh.ARRAY_COLOR]
		if cols == null or (cols as PackedColorArray).size() == 0:
			print("  NO ARRAY_COLOR")
		else:
			var c: PackedColorArray = cols
			var mn := Color(9, 9, 9, 9)
			var mx := Color(-9, -9, -9, -9)
			var lo := 0
			var hi := 0
			for col in c:
				mn = Color(minf(mn.r, col.r), minf(mn.g, col.g), minf(mn.b, col.b), minf(mn.a, col.a))
				mx = Color(maxf(mx.r, col.r), maxf(mx.g, col.g), maxf(mx.b, col.b), maxf(mx.a, col.a))
				if col.a < 0.05:
					lo += 1
				if col.a > 0.95:
					hi += 1
			print("  COLOR n=%d min=%s max=%s alpha<0.05: %d alpha>0.95: %d" % [c.size(), mn, mx, lo, hi])
			# alpha vs position along the reach (z) for a sense of the fade
			var bins := {}
			for i in c.size():
				var b := int(floor(verts[i].z * 10.0))
				if not bins.has(b):
					bins[b] = [0.0, 0]
				bins[b][0] += c[i].a
				bins[b][1] += 1
			var keys := bins.keys()
			keys.sort()
			for b in keys:
				print("    z in [%.1f,%.1f): mean alpha %.3f (n=%d)" % [b / 10.0, (b + 1) / 10.0, bins[b][0] / bins[b][1], bins[b][1]])
		var mat := mesh.surface_get_material(s)
		print("  material=", mat)
		if mat is BaseMaterial3D:
			var m := mat as BaseMaterial3D
			print("    vertex_color_use_as_albedo=", m.vertex_color_use_as_albedo, " is_srgb=", m.vertex_color_is_srgb,
				" transparency=", m.transparency, " albedo=", m.albedo_color, " shading=", m.shading_mode,
				" cull=", m.cull_mode, " roughness=", m.roughness, " metallic=", m.metallic, " emission_enabled=", m.emission_enabled)
		if mi.get_surface_override_material(s):
			print("    override=", mi.get_surface_override_material(s))


func _pose_pos(root: Node3D, skel: Skeleton3D, name: String) -> Vector3:
	return _skel_to_root(root, skel) * skel.get_bone_global_pose(skel.find_bone(name)).origin


func _sample(root: Node3D, skel: Skeleton3D, player: AnimationPlayer, clip: String, t: float) -> String:
	player.seek(t, true)
	player.advance(0)
	skel.force_update_all_bone_transforms()
	var out := "    t=%.3f" % t
	for b in ATTACH:
		var p := _pose_pos(root, skel, b)
		out += "  %s=(%.3f,%.3f,%.3f)" % [b, p.x, p.y, p.z]
	return out


func _all_pos(root: Node3D, skel: Skeleton3D, player: AnimationPlayer, t: float) -> PackedVector3Array:
	player.seek(t, true)
	player.advance(0)
	skel.force_update_all_bone_transforms()
	var out := PackedVector3Array()
	for i in skel.get_bone_count():
		out.append(_skel_to_root(root, skel) * skel.get_bone_global_pose(i).origin)
	return out


func _clips(root: Node3D, skel: Skeleton3D, player: AnimationPlayer) -> void:
	print("== animations (libraries=", player.get_animation_library_list(), ")")
	for n in player.get_animation_list():
		var a := player.get_animation(n)
		print("  %-14s length=%.4f loop_mode=%d tracks=%d step=%.4f" % [n, a.length, a.loop_mode, a.get_track_count(), a.step])
		if n == "Idle":
			for ti in a.get_track_count():
				print("      track ", a.track_get_path(ti), " type=", a.track_get_type(ti), " keys=", a.track_get_key_count(ti))
	print("== attachment bone positions (root space)")
	for n in player.get_animation_list():
		if n == "RESET":
			continue
		var a := player.get_animation(n)
		player.play(n)
		print("  ", n)
		print(_sample(root, skel, player, n, 0.0))
		if CONTACTS.has(n):
			print(_sample(root, skel, player, n, CONTACTS[n]), "  <- contact")
		print(_sample(root, skel, player, n, a.length / 2.0))
		print(_sample(root, skel, player, n, a.length))
		# loop seam: pose at 0 vs at length (sampled just before, to avoid wrap)
		var p0 := _all_pos(root, skel, player, 0.0)
		var p1 := _all_pos(root, skel, player, a.length - 0.00001)
		var worst := 0.0
		var wb := ""
		for i in p0.size():
			var d := p0[i].distance_to(p1[i])
			if d > worst:
				worst = d
				wb = skel.get_bone_name(i)
		print("    seam max bone delta t0 vs t_end = %.5f (%s)" % [worst, wb])
		player.stop()
