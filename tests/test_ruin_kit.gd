extends SceneTree
## The ruin kit (scripts/ruin_kit.gd, scripts/ruin_kit_aqueduct.gd,
## scripts/ruin_kit_hall.gd): every piece of every family builds intact
## (weathered 0) and ruined (weathered 1) from a few seeds into a node with
## a "Mesh" (faces, normals, colours) and a "Body" of convex hulls, each
## with a real volume (Jolt cannot build a flat one), and a flat top a
## walker can stand on; the same seed builds the same piece; the glyph
## stone, the floor medallion and the colossus mask carry their glyph, its
## glow surface and its halo; the plane's way stays clear through the
## gothic arch and window, every aqueduct arch and the hall (and the hall's
## knife-edge slit lets a plane on its wingtip through, not a level one);
## and the scale constants still answer the pilot's and the plane's limits
## (scripts/pilot_motor.gd, scripts/plane_figure.gd).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
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
	check(RuinKit.PIECES.size() == 13,"thirteen gothic pieces")
	check(RuinKit.AQUEDUCT_PIECES.size() == 5 and RuinKit.HALL_PIECES.size() == 6,"five aqueduct pieces and six hall pieces")
	for id: String in RuinKit.ALL_PIECES: check(RuinKit.NAMES.has(id),id+" is named")
	for id: String in RuinKit.ALL_PIECES:
		for seed_value: int in SEEDS:
			for weathered: float in [0.0,1.0]:
				_piece(id,seed_value,weathered)
		# The same seed, the same piece.
		var a := RuinKit.piece(id,9,0.6)
		var b := RuinKit.piece(id,9,0.6)
		check(_mesh(a).mesh.get_faces() == _mesh(b).mesh.get_faces(),id+" is the same from the same seed")
		a.free()
		b.free()
	var half := RuinKit.THREAD*0.5
	for seed_value: int in SEEDS:
		for weathered: float in [0.0,1.0]:
			var tag := "seed %d weathered %.0f" % [seed_value,weathered]
			# The plane's way through the gothic arch and the ruined window.
			if weathered > 0.5:
				var window := RuinKit.lancet_wall(seed_value,1.0)
				check(_clear(window,AABB(Vector3(-half,RuinKit.WINDOW.y+1.0,-0.4),Vector3(half*2.0,RuinKit.WINDOW.z-RuinKit.WINDOW.y-1.1,0.8))),"the ruined window is open to the plane, "+tag)
				window.free()
			var arch := RuinKit.arch(seed_value,weathered)
			check(_clear(arch,AABB(Vector3(-half,0.9,-3.0),Vector3(half*2.0,RuinKit.SPRING-1.6,6.0))),"the arch is open to the plane, "+tag)
			arch.free()
			# Under every aqueduct arch: the span's, both tiers of the two-tier.
			var span := Aqueduct.span(seed_value,weathered)
			check(_clear(span,AABB(Vector3(-half,1.2,-3.5),Vector3(half*2.0,Aqueduct.SPRING+1.5-1.2,7.0))),"the plane threads the aqueduct span's arch, "+tag)
			span.free()
			var tiers := Aqueduct.two_tier(seed_value,weathered)
			check(_clear(tiers,AABB(Vector3(-half,1.2,-3.5),Vector3(half*2.0,Aqueduct.LOWER_SPRING+1.2-1.2,7.0))),"the plane threads the two-tier's lower arch, "+tag)
			check(_clear(tiers,AABB(Vector3(-half,Aqueduct.MID+0.6,-3.5),Vector3(half*2.0,Aqueduct.UPPER_RISE+1.2-0.6,7.0))),"the plane threads the two-tier's upper arch, "+tag)
			tiers.free()
			# Through the hall bay under its roof, along X (its ruined corner
			# included), and through the assembled hall's gate.
			var corridor := AABB(Vector3(-Hall.BAY*0.5-3.0,1.2,-2.3),Vector3(Hall.BAY+6.0,2.2,3.5))
			var bay := Hall.bay(seed_value,weathered)
			check(_clear(bay,corridor),"the plane flies through the hall bay, "+tag)
			check(weathered < 0.5 or bool(bay.get_meta("snapped")),"the ruined bay's corner has come down, "+tag)
			# The knife-edge slit: a plane on its wingtip (as tall as its span,
			# as wide as its body) passes; a level one (its span across) does not.
			var slit: Vector3 = bay.get_meta("slit")
			var edge := AABB(slit+Vector3(-0.48,-PlaneFigure.SPAN*0.5-0.3,-1.5),Vector3(0.96,PlaneFigure.SPAN+0.6,3.0))
			check(_clear(bay,edge),"a knife-edged plane slips through the slit, "+tag)
			check(not _clear(bay,AABB(slit+Vector3(-PlaneFigure.SPAN*0.5,-0.15,-0.3),Vector3(PlaneFigure.SPAN,0.3,0.6)),false),"a level plane cannot pass the slit, "+tag)
			bay.free()
			if weathered > 0.5:
				var hall := Hall.hall(seed_value,weathered)
				var through := AABB(Vector3(-Hall.BAY-3.0,1.2,-2.3),Vector3(Hall.BAY*2.0+6.0,2.2,3.5))
				var ok := true
				for child in hall.get_children(): ok = ok and _clear(child,through,true,child.position)
				check(ok,"the plane flies through the assembled hall, its gate to its fallen end, "+tag)
				hall.free()
	# A run: the head, spans SPAN apart, one broken; dry past the break.
	var run := Aqueduct.run(5,0.5,4,2)
	check(run.get_child_count() == 5,"a run is its head and its four spans")
	var wet := 0
	for child in run.get_children():
		if child.get_node_or_null("Water") != null: wet += 1
	check(wet == 4 and run.get_child(3).get_node_or_null("Spill") != null,"the run carries water to the break and spills there, dry past it")
	check(is_equal_approx((run.get_child(2) as Node3D).position.x-(run.get_child(1) as Node3D).position.x,Aqueduct.SPAN),"spans stand SPAN apart")
	run.free()
	_scale()
	print("PASS: ruin kit" if failures == 0 else "FAIL: ruin kit (%d)" % failures)
	quit(1 if failures else 0)

## The scale, against the limits it was set by.
func _scale() -> void:
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
	check(RuinKit.HULL_THIN < 0.1,"only slivers go without a hull")
	# The aqueduct.
	var crown := Aqueduct.SPRING+RuinKit._rise(Aqueduct.CLEAR*0.5,Aqueduct.CLEAR)+RuinKit.ORDER*2.0
	check(Aqueduct.CLEAR >= RuinKit.THREAD+0.8 and is_equal_approx(Aqueduct.CLEAR,Aqueduct.SPAN-Aqueduct.PIER.x),"an aqueduct arch clears the plane with room to spare")
	check(crown < Aqueduct.DECK-Aqueduct.FLOOR,"the span's arch stands under its deck")
	check(Aqueduct.CHANNEL >= RuinKit.TOP_ROOM,"the channel is walked along")
	check(Aqueduct.PARAPET.y < PilotMotor.STEP_UP and Aqueduct.WATER < Aqueduct.PARAPET.y,"the parapets are stepped over, the water within them")
	check(is_equal_approx(Aqueduct.CHANNEL+2.0*Aqueduct.PARAPET.x,Aqueduct.DECK_WIDTH),"the deck is the channel and its parapets")
	var lower := Aqueduct.LOWER_SPRING+RuinKit._rise(Aqueduct.CLEAR*0.5,Aqueduct.CLEAR)+RuinKit.ORDER*2.0
	var upper_half := (Aqueduct.SPAN-Aqueduct.UPPER_PIER.x)*0.5
	var upper := Aqueduct.MID+Aqueduct.UPPER_RISE+RuinKit._rise(upper_half,upper_half*2.0*Aqueduct.UPPER_PITCH)+RuinKit.ORDER*2.0
	check(lower < Aqueduct.MID-Aqueduct.FLOOR and upper < Aqueduct.DECK_HIGH-Aqueduct.FLOOR,"the two-tier's arches stand under their courses")
	check(upper_half*2.0 >= RuinKit.THREAD,"the upper arcade clears the plane")
	check(Aqueduct.ABUTMENT_TREAD >= RuinKit.STAND and RuinKit.SET_OFF < first_grab-0.2,"the head's treads are stood on, each a jump over the last")
	check(Aqueduct.STUMP.y < chain_grab and Aqueduct.STUMP.x < first_grab,"a stump is climbed from the water")
	# The hall.
	check(Hall.BAY-2.0*Hall.PLINTH.y >= RuinKit.THREAD and Hall.BAY-2.0*Hall.ABACUS >= RuinKit.THREAD,"the plane flies between the hall's columns, at their bases and capitals")
	check(Hall.COLUMN_H-Hall.CAPITAL_H > RuinKit.THREAD,"and under the capitals")
	check(Hall.COLUMN_R > RuinKit.PIER_CORE+RuinKit.SHAFT_MAIN.y*1.5,"a colossus column is far heavier than a clustered pier")
	check(Hall.PLINTH.x < PilotMotor.STEP_UP and Hall.PAVING.x < PilotMotor.STEP_UP and Hall.MEDALLION_TOP < PilotMotor.STEP_UP,"the column plinths, paving and medallion are stepped onto")
	check(Hall.BEAM.y*2.0 >= RuinKit.TOP_ROOM and Hall.ABACUS*2.0 >= RuinKit.TOP_ROOM,"beam and abacus tops are walked")
	check(Hall.RAMP < deg_to_rad(35.0) and atan2(Hall.COLUMN_H-Hall.SNAP,Hall.BAY) < deg_to_rad(30.0),"the fallen slab and the sagging beams are walked up")
	check(Hall.KNIFE.x < PlaneFigure.SPAN and Hall.KNIFE.x >= 1.0 and Hall.KNIFE.z >= PlaneFigure.SPAN+1.2,"the slit is narrower than the wings, wider than the plane on its wingtip, and tall enough for it")
	check(Hall.GATE.x >= RuinKit.THREAD,"the hall's gate clears the plane")
	check(Hall.BROW >= RuinKit.STAND,"the mask's brow is stood on")

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
	var thin := 0
	var top := false
	if body != null:
		for child in body.get_children():
			var shape := (child as CollisionShape3D).shape as ConvexPolygonShape3D
			if shape == null or shape.points.size() < 4:
				thin += 1
				continue
			hulls += 1
			# A real volume: no hull flat or a sliver (Jolt's "Too few faces").
			var box := AABB(shape.points[0],Vector3.ZERO)
			for p in shape.points: box = box.expand(p)
			if RuinKit.hull_thickness(shape.points) < RuinKit.HULL_THIN or minf(box.size.x,minf(box.size.y,box.size.z)) < 0.03: thin += 1
			# A flat top: three or more corners level at the hull's head.
			var high := -INF
			for p in shape.points: high = maxf(high,p.y)
			var level := 0
			for p in shape.points:
				if p.y > high-0.02: level += 1
			if level >= 3 and high > 0.1: top = true
	check(hulls > 0,label+" has collision")
	check(thin == 0,label+" has no flat or degenerate hull (%d)" % thin)
	# The mask lies back: its ledge is the brow, near level but not quite.
	if id == "hall_mask": check(float(node.get_meta("brow_slope",PI)) < deg_to_rad(30.0),label+" has a brow ledge to stand on")
	else: check(top,label+" has a top to stand on")
	if id in ["glyph_stone","hall_medallion","hall_mask"]:
		check(ok and mesh.mesh.get_surface_count() == 2,label+" has its glow surface")
		check(str(node.get_meta("glyph","")) in RuinKit.GLYPHS and node.get_node_or_null("Halo") is MeshInstance3D,label+" carries a glyph and its halo")
	if id == "hall_mask": check(node.get_node_or_null("Halo2") is MeshInstance3D,label+" has a halo in each eye")
	if id == "hall_bay": check(node.get_node_or_null("Medallion") != null and node.has_meta("slit"),label+" has its medallion and its slit")
	if id in ["aqueduct_span","aqueduct_two_tier","aqueduct_broken","aqueduct_end"]: check(node.get_node_or_null("Water") is MeshInstance3D,label+" carries water")
	if id == "aqueduct_broken": check(node.get_node_or_null("Spill") is MeshInstance3D and node.get_node_or_null("Pool") is MeshInstance3D,label+" spills into a pool")
	node.free()

## No hull of `node`'s body reaches into `box` (`node` at `offset` in the
## box's frame); `say` prints what is in the way.
func _clear(node: Node, box: AABB, say := true, offset := Vector3.ZERO) -> bool:
	var body := node.get_node_or_null("Body")
	if body == null: return true
	for child in body.get_children():
		var shape := (child as CollisionShape3D).shape as ConvexPolygonShape3D
		var hull := AABB(shape.points[0]+offset,Vector3.ZERO)
		for p in shape.points: hull = hull.expand(p+offset)
		if hull.intersects(box):
			if say: print("  in the way of %s: %s" % [node.name,hull])
			return false
	return true

func _mesh(node: Node3D) -> MeshInstance3D:
	return node.get_node_or_null("Mesh") as MeshInstance3D
