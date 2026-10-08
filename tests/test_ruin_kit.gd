extends SceneTree
## The gothic ruin kit (scripts/ruin_kit.gd): every piece, in the kit's
## order, builds intact (weathered 0) and ruined (weathered 1) from a few
## seeds into a node with a "Mesh" (faces, normals, colours) and a "Body" of
## convex hulls with a flat top a walker can stand on; the same seed builds
## the same piece; the glyph stone carries its glyph, its glow surface and
## its halo; the arch and the ruined window stay open for the plane; and the
## scale constants still answer the pilot's and the plane's limits
## (scripts/pilot_motor.gd, scripts/plane_figure.gd).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const SEEDS := [1,77,4242]
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL "+label)

func _run() -> void:
	check(RuinKit.PIECES.size() == 13 and RuinKit.NAMES.size() == 13, "thirteen pieces, each named")
	for id: String in RuinKit.PIECES:
		for seed_value: int in SEEDS:
			for weathered: float in [0.0,1.0]:
				_piece(id,seed_value,weathered)
		# The same seed, the same piece.
		var a := RuinKit.piece(id,9,0.6)
		var b := RuinKit.piece(id,9,0.6)
		check(_mesh(a).mesh.get_faces() == _mesh(b).mesh.get_faces(),id+" is the same from the same seed")
		a.free()
		b.free()
	# The plane's way through: no hull in the arch's opening, nor in the
	# ruined window's (its mullion a stub under the corridor).
	for seed_value: int in SEEDS:
		var arch := RuinKit.arch(seed_value,1.0)
		var half := RuinKit.THREAD*0.5
		check(_clear(arch,AABB(Vector3(-half,0.9,-3.0),Vector3(half*2.0,RuinKit.SPRING-1.6,6.0))),"the ruined arch is open to the plane, seed %d" % seed_value)
		arch.free()
		arch = RuinKit.arch(seed_value,0.0)
		check(_clear(arch,AABB(Vector3(-half,0.9,-3.0),Vector3(half*2.0,RuinKit.SPRING-1.6,6.0))),"the arch is open to the plane, seed %d" % seed_value)
		arch.free()
		var window := RuinKit.lancet_wall(seed_value,1.0)
		check(_clear(window,AABB(Vector3(-half,RuinKit.WINDOW.y+1.0,-0.4),Vector3(half*2.0,RuinKit.WINDOW.z-RuinKit.WINDOW.y-1.1,0.8))),"the ruined window is open to the plane, seed %d" % seed_value)
		window.free()
	# The scale, against the limits it was set by.
	var first_grab: float = PilotMotor.JUMPS[0]+PilotMotor.HANG_DROP+PilotMotor.GRAB_LOW
	var chain_grab: float = PilotMotor.JUMPS[2]+PilotMotor.HANG_DROP+PilotMotor.GRAB_LOW
	check(is_equal_approx(RuinKit.GRAB_TOP,first_grab) and is_equal_approx(RuinKit.CHAIN_TOP,chain_grab),"GRAB_TOP and CHAIN_TOP follow the jumps")
	check(is_equal_approx(RuinKit.STAND,PilotMotor.CLIMB_IN+RuinKit.BODY),"STAND follows the climb")
	check(RuinKit.RISER < PilotMotor.STEP_UP-0.1,"a riser is walked up")
	check(RuinKit.PLINTH_COURSE.x < PilotMotor.STEP_UP and RuinKit.SUB_BASE.x < PilotMotor.STEP_UP and RuinKit.FLOOR.z < PilotMotor.STEP_UP,"plinth courses, pier bases and slabs are stepped onto")
	check(RuinKit.SET_OFF < first_grab-0.2,"each set-off is caught with one jump")
	check(RuinKit.WALL_HEIGHT > first_grab and RuinKit.WALL_HEIGHT < chain_grab-0.1,"a wall is caught from a running chain")
	check(RuinKit.WINDOW.y < first_grab-0.2 and RuinKit.ARCH_DEPTH >= RuinKit.STAND,"a window's sill is caught and stood in")
	check(RuinKit.CHEST.z < first_grab and RuinKit.GLYPH_BLOCK.z < first_grab,"the chest's and the glyph stone's tops are caught")
	check(RuinKit.WALL_THICK >= RuinKit.TOP_ROOM and RuinKit.ABACUS*2.0 >= RuinKit.TOP_ROOM,"wall and capital tops have room to walk")
	var depth: Array = RuinKit.BUTTRESS_DEPTH
	for i in range(depth.size()-1): check(float(depth[i])-float(depth[i+1]) >= RuinKit.STAND,"buttress tread %d is deep enough to stand on" % i)
	var steps: Array = RuinKit.VAULT_STEPS
	check(float(steps[-1]) < first_grab-0.2,"the vault walls' lowest step is caught from the ground")
	for i in range(steps.size()-1): check(float(steps[i])-float(steps[i+1]) <= RuinKit.SET_OFF,"the vault walls step %d is one jump" % i)
	check(RuinKit.THREAD >= PlaneFigure.SPAN*2.5,"THREAD follows the wingspan")
	check(RuinKit.ARCH_SPAN >= RuinKit.THREAD and RuinKit.WINDOW.x >= RuinKit.THREAD and 2.0*(RuinKit.ROSE.y-RuinKit.ROSE.z) >= RuinKit.THREAD,"the arch, the window and the rose clear the plane")
	check(RuinKit.TURRET.y-RuinKit.TURRET.z >= 2.0*RuinKit.BODY+0.4,"the turret's stair is wide enough to climb")
	print("PASS: ruin kit" if failures == 0 else "FAIL: ruin kit (%d)" % failures)
	quit(1 if failures else 0)

func _piece(id: String, seed_value: int, weathered: float) -> void:
	var node := RuinKit.piece(id,seed_value,weathered)
	var label := "%s seed %d weathered %.0f" % [id,seed_value,weathered]
	check(node != null,label+" builds")
	if node == null: return
	var mesh := _mesh(node)
	var ok := mesh != null and mesh.mesh != null and mesh.mesh.get_surface_count() >= 1
	if ok:
		var arrays := mesh.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		ok = verts.size() >= 36 and verts.size()%3 == 0 and (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == verts.size() and (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size() == verts.size()
	check(ok,label+" has a mesh")
	if ok:
		var box := mesh.mesh.get_aabb()
		check(box.position.y > -0.5 and box.size.length() > 0.5 and box.size.length() < 30.0,label+" stands on the ground at a sane size: "+str(box))
	var body := node.get_node_or_null("Body") as StaticBody3D
	var hulls := 0
	var top := false
	if body != null:
		for child in body.get_children():
			var shape := (child as CollisionShape3D).shape as ConvexPolygonShape3D
			if shape == null or shape.points.size() < 4: continue
			hulls += 1
			# A flat top: three or more corners level at the hull's head.
			var high := -INF
			for p in shape.points: high = maxf(high,p.y)
			var level := 0
			for p in shape.points:
				if p.y > high-0.02: level += 1
			if level >= 3 and high > 0.1: top = true
	check(hulls > 0,label+" has collision")
	check(top,label+" has a top to stand on")
	if id == "glyph_stone":
		check(ok and mesh.mesh.get_surface_count() == 2,label+" has its glow surface")
		check(str(node.get_meta("glyph","")) in RuinKit.GLYPHS and node.get_node_or_null("Halo") is MeshInstance3D,label+" carries a glyph and its halo")
	node.free()

## No hull of `node`'s body reaches into `box`.
func _clear(node: Node3D, box: AABB) -> bool:
	for child in node.get_node("Body").get_children():
		var shape := (child as CollisionShape3D).shape as ConvexPolygonShape3D
		var hull := AABB(shape.points[0],Vector3.ZERO)
		for p in shape.points: hull = hull.expand(p)
		if hull.intersects(box):
			print("  in the way: ",hull)
			return false
	return true

func _mesh(node: Node3D) -> MeshInstance3D:
	return node.get_node_or_null("Mesh") as MeshInstance3D
