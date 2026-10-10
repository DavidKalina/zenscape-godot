extends SceneTree
## The ruin kit (scripts/ruin_kit.gd, scripts/ruin_kit_aqueduct.gd,
## scripts/ruin_kit_hall.gd): every piece of every family builds intact
## (weathered 0) and ruined (weathered 1) from a few seeds into a node with
## a "Mesh" (faces, normals, colours) and a "Body" of convex hulls, each
## with a real volume (Jolt cannot build a flat one), and a flat top a
## walker can stand on; the same seed builds the same piece; nothing glows
## (one stone surface, no halo); the plane's way stays clear through the
## gothic arch and window, every aqueduct arch and the hall (and the hall's
## knife-edge slit lets a plane on its wingtip through, not a level one);
## the stairs walk on clean boxes (every tread's top true; the grand
## stair's finer steps reach the flight's head; no joint between
## treads or slabs left as a gap: the drawn treads, worn, settled and laid
## in slabs, have no hulls); and the scale constants still answer the pilot's and the plane's limits
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
	check(RuinKit.PIECES.size() == 14,"fourteen gothic pieces")
	check(RuinKit.AQUEDUCT_PIECES.size() == 5 and RuinKit.HALL_PIECES.size() == 4,"five aqueduct pieces and four hall pieces")
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
	# A run: the head, spans SPAN apart, one broken; dry past the break.
	var run := Aqueduct.run(5,0.5,4,2)
	var parts := _pieces(run)
	check(parts.size() == 5,"a run is its head and its four spans")
	var wet := 0
	for child in parts:
		if child.get_node_or_null("Water") != null: wet += 1
	check(wet == 4 and parts[3].get_node_or_null("Spill") != null,"the run carries water to the break and spills there, dry past it")
	check(is_equal_approx((parts[2] as Node3D).position.x-(parts[1] as Node3D).position.x,Aqueduct.SPAN),"spans stand SPAN apart")
	check(run.get_node_or_null("Mesh") is MeshInstance3D and run.get_node_or_null("Body") is StaticBody3D,"a run is merged into one mesh and one body")
	run.free()
	_long_hall()
	_curved_hall()
	_budget()
	_terrain()
	_connections()
	_stairs_walk()
	check(is_equal_approx(RuinKit.GRAND_STEPS*RuinKit.GRAND_RISER,RuinKit.STEPS*RuinKit.RISER) and RuinKit.GRAND_RISER < PilotMotor.STEP_UP,"the grand stair's flight rises as the kit's, on finer, walkable steps")
	_scale()
	print("PASS: ruin kit" if failures == 0 else "FAIL: ruin kit (%d)" % failures)
	quit(1 if failures else 0)

## The scale, against the limits it was set by.
func _scale() -> void:
	var first_grab: float = PilotMotor.JUMPS[0]+PilotMotor.HANG_DROP+PilotMotor.GRAB_LOW
	var chain_grab: float = PilotMotor.JUMPS[1]+PilotMotor.HANG_DROP+PilotMotor.GRAB_LOW
	check(is_equal_approx(RuinKit.GRAB_TOP,first_grab) and is_equal_approx(RuinKit.CHAIN_TOP,chain_grab),"GRAB_TOP and CHAIN_TOP follow the jumps")
	check(is_equal_approx(RuinKit.STAND,PilotMotor.CLIMB_IN+RuinKit.BODY),"STAND follows the climb")
	check(RuinKit.RISER < PilotMotor.STEP_UP-0.1,"a riser is walked up")
	check(RuinKit.PLINTH_COURSE.x < PilotMotor.STEP_UP and RuinKit.SUB_BASE.x < PilotMotor.STEP_UP and RuinKit.FLOOR.z < PilotMotor.STEP_UP,"plinth courses, pier bases and slabs are stepped onto")
	check(RuinKit.SET_OFF < first_grab-0.2,"each set-off is caught with one jump")
	check(RuinKit.WALL_HEIGHT > first_grab and RuinKit.WALL_HEIGHT < chain_grab-0.1,"a wall is caught from the pump")
	check(RuinKit.WINDOW.y < first_grab-0.2 and RuinKit.ARCH_DEPTH >= RuinKit.STAND,"a window's sill is caught and stood in")
	check(RuinKit.CHEST.z < first_grab,"the chest's top is caught")
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
	check(Hall.LANE.y-Hall.LANE.x >= RuinKit.THREAD and Hall.LANE.x >= Hall.INNER_Z+Hall.COLUMN_R and Hall.LANE.y <= Hall.ROW_Z-Hall.COLUMN_R,"the lane is THREAD wide and more, between the inner columns and the outer row")
	check(Hall.LANE_Y.y < Hall.TIE_LOW-0.2 and Hall.LANE_Y.y-Hall.LANE_Y.x >= 2.0,"the lane runs under every tie, and is tall enough")
	check(Hall.COLUMN_H-Hall.CAPITAL_H-(Hall.TIE_HIGH+Hall.TIE_DEPTH) >= 2.0 and Hall.COLUMN_H-Hall.CAPITAL_H-(Hall.TIE_LOW+Hall.TIE_DEPTH) >= 3.5,"over a tie there is room to hop it, under the capitals")
	check(Hall.ROW_Z*2.0-2.0*Hall.COLUMN_R > RuinKit.THREAD*3.0,"the nave is wide enough to weave")
	check(Hall.COLUMN_R > RuinKit.PIER_CORE+RuinKit.SHAFT_MAIN.y*1.5,"a colossus column is far heavier than a clustered pier")
	check(Hall.PLINTH.x < PilotMotor.STEP_UP and Hall.PAVING.x < PilotMotor.STEP_UP,"the column plinths and paving are stepped onto")
	check(Hall.BEAM.y*2.0 >= RuinKit.TOP_ROOM and Hall.ABACUS*2.0 >= RuinKit.TOP_ROOM,"beam, tie and abacus tops are walked")
	check(Hall.RAMP < deg_to_rad(35.0),"a fallen beam is walked up onto its tie")
	check(Hall.TREAD >= RuinKit.STAND,"the buttress's treads are stood on, each a jump over the last")
	check(Hall.KNIFE.x < PlaneFigure.SPAN and Hall.KNIFE.x >= 1.0 and Hall.KNIFE.z >= PlaneFigure.SPAN+1.2,"a slit is narrower than the wings, wider than the plane on its wingtip, and tall enough for it")
	check(Aqueduct.FOOTING > 0.0 and Hall.FOUNDATION > 0.0,"feet reach below the ground")

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
		check(box.position.y > -0.5 and box.size.length() > 0.5 and box.size.length() < (45.0 if id in ["hall_bay","stone_circle"] else 30.0),label+" stands on the ground at a sane size: "+str(box))
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
	check(top,label+" has a top to stand on")
	# No ornament glows: one stone surface, no halo.
	check(ok and mesh.mesh.get_surface_count() == 1 and node.get_node_or_null("Halo") == null,label+" is stone and growth only, nothing glowing")
	if id == "hall_bay": check(node.has_meta("slit"),label+" has its slit")
	for key: String in ["bounds","feet","corridors","walk"]:
		if id.begins_with("aqueduct") or id == "hall_bay": check(node.has_meta(key),label+" gives its "+key)
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

## A run's or a hall's built pieces (its children with their metadata).
func _pieces(root: Node) -> Array:
	return root.get_children().filter(func(c: Node) -> bool: return c.has_meta("feet"))

## The long hall: a lane clear end to end, THREAD wide and more; the weave
## it promises (low ties dived under and flown over, high ones hopped,
## beams fallen across, roof gaps flown out of, slits a knife-edged plane
## threads and a level one does not, the middle narrowed), each where it
## says; merged into one mesh and body; its ends at its mouths.
func _long_hall() -> void:
	var half := PlaneFigure.SPAN*0.5
	for seed_value: int in [1,77]:
		for weathered: float in [0.25,0.85]:
			var tag := "seed %d weathered %.2f" % [seed_value,weathered]
			var hall := Hall.hall(seed_value,weathered,12)
			var length: float = hall.get_meta("length")
			check(is_equal_approx(length,Hall.BAY*12.0),"a 12-bay hall is 12 bays long, "+tag)
			check(hall.get_node_or_null("Mesh") is MeshInstance3D and hall.get_node_or_null("Body") is StaticBody3D,"the hall is merged into one mesh and one body, "+tag)
			var lane: AABB = (hall.get_meta("corridors") as Array)[0].box
			check(lane.position.x <= 0.01 and lane.end.x >= length-0.01 and lane.size.z >= RuinKit.THREAD and lane.size.y >= 2.0,"the lane runs end to end, THREAD wide, "+tag)
			check(_clear(hall,lane.grow(-0.02)),"nothing stands in the lane, end to end, "+tag)
			var weave: Dictionary = hall.get_meta("weave")
			check((weave.low_ties as Array).size() >= 2 and (weave.high_ties as Array).size() >= 2,"low and high ties, at least two of each, "+tag)
			for tie: Vector3 in weave.low_ties:
				var over := AABB(Vector3(tie.x-1.0,Hall.TIE_LOW+Hall.TIE_DEPTH+0.3,Hall.LANE.x),Vector3(2.0,Hall.COLUMN_H-Hall.CAPITAL_H-0.1-(Hall.TIE_LOW+Hall.TIE_DEPTH+0.3),Hall.LANE.y-Hall.LANE.x))
				check(_clear(hall,over),"over a low tie there is room to fly, "+tag)
			for tie: Vector3 in weave.high_ties:
				var hop := AABB(Vector3(tie.x-1.0,Hall.TIE_HIGH+Hall.TIE_DEPTH+0.2,Hall.LANE.x),Vector3(2.0,Hall.COLUMN_H-Hall.CAPITAL_H-0.1-(Hall.TIE_HIGH+Hall.TIE_DEPTH+0.2),Hall.LANE.y-Hall.LANE.x))
				check(_clear(hall,hop),"a high tie is hopped under the roof, "+tag)
			if weathered > 0.3:
				check(not (weave.fallen as Array).is_empty(),"a beam lies fallen across the nave, "+tag)
			for f: Array in weave.fallen:
				var head: Vector3 = f[0]
				var foot: Vector3 = f[1]
				check(atan2(head.y-foot.y,Vector2(head.x-foot.x,head.z-foot.z).length()) < deg_to_rad(35.0),"a fallen beam is a walkable ramp, "+tag)
				check(maxf(head.z,foot.z) < Hall.LANE.x,"a fallen beam stays out of the lane, "+tag)
			check(not (weave.gaps as Array).is_empty(),"the roof has a gap to fly out of, "+tag)
			for gap: AABB in weave.gaps:
				check(gap.size.x >= RuinKit.THREAD and gap.size.z >= RuinKit.THREAD and _clear(hall,gap),"a roof gap is open and wide enough, "+tag)
			check(not (weave.slits as Array).is_empty() and not (weave.narrows as Array).is_empty(),"slits and narrows to pick a line through, "+tag)
			for slit: Vector3 in weave.slits:
				var edge := AABB(slit+Vector3(-1.5,-half-0.3,-0.48),Vector3(3.0,PlaneFigure.SPAN+0.6,0.96))
				check(_clear(hall,edge),"a knife-edged plane slips through a slit, "+tag)
				check(not _clear(hall,AABB(slit+Vector3(-0.3,-0.15,-half),Vector3(0.6,0.3,PlaneFigure.SPAN)),false),"a level plane cannot pass a slit, "+tag)
			_breaks(hall,tag)
			var ends: Array = hall.get_meta("ends")
			check(ends.size() == 2 and is_equal_approx((ends[0].at as Vector3).x,0.0) and is_equal_approx((ends[1].at as Vector3).x,length) and bool(ends[0].open) and bool(ends[1].open),"the hall's ends are its two open mouths, "+tag)
			hall.free()

## What the roof and walls have lost: stretches of whole roof, broken roof
## and open sky (open bays open to the sky over the nave); breaches in the
## side walls, each flyable one a corridor from the lane inside to the
## open air outside (clear of stone), on both sides; a door. `path`-space
## boxes, checked through the hall's path (so on curves too).
func _breaks(hall: Node3D, tag: String) -> void:
	var path = hall.get_meta("path")
	var plans: Array = hall.get_meta("plans")
	var roofs := {}
	for p: Dictionary in plans: roofs[p.roof] = true
	check(roofs.has("whole") and roofs.has("broken") and roofs.has("open"),"the roof is whole, broken and open in stretches, "+tag)
	var weave: Dictionary = hall.get_meta("weave")
	check((weave.open as Array).size() == plans.filter(func(p: Dictionary) -> bool: return p.roof == "open").size(),"each open bay gives its sky, "+tag)
	for box: AABB in weave.open:
		check(_clear_along(hall,path,box),"an open bay is open to the sky over the nave, "+tag)
	var sides := {-1:0,1:0}
	for item: Dictionary in weave.breaches:
		var box: AABB = item.box
		sides[int(item.side)] += 1
		check(box.size.x >= RuinKit.THREAD and box.size.y >= 2.0,"a breach is wide and tall enough to fly, "+tag)
		# From the lane (inside) to beyond the wall (outside).
		var reaches := box.position.z <= Hall.LANE.y and box.end.z >= Hall.LANE.x and (box.end.z > Hall.WALL_Z+Hall.WALL_THICK if int(item.side) > 0 else box.position.z < -Hall.WALL_Z-Hall.WALL_THICK)
		check(reaches,"a breach's corridor runs from the lane out past the wall, "+tag)
		check(_clear_along(hall,path,box),"a %s breach is open from the lane to the outside, %s" % [item.kind,tag])
	check(sides[1] >= 2 and sides[-1] >= 1,"flyable breaches on both sides, "+tag)
	check(not (weave.doors as Array).is_empty(),"a door to walk out of, "+tag)
	var corridors: Array = hall.get_meta("corridors")
	check(corridors.size() == 1+(weave.breaches as Array).size(),"the lane and each breach are corridors, "+tag)

## A curved hall: a plan of straight and curved stretches. Its lane runs
## clear through the curve (path space), its breaches and open bays as on
## a straight one; the metadata sits on the geometry: the ends at the
## path's ends, heading along it, an outer column there; the lane's
## corridor line along the lane's middle, over its floor.
func _curved_hall() -> void:
	for seed_value: int in [3,41]:
		for turn: float in [0.9,-0.7]:
			var tag := "curved seed %d turn %.1f" % [seed_value,turn]
			var hall := Hall.hall(seed_value,0.6,12,Callable(),true,[{"bays":3,"turn":0.0},{"bays":5,"turn":turn},{"bays":4,"turn":0.0}])
			var path = hall.get_meta("path")
			check(path.curved() and is_equal_approx(float(path.length),Hall.BAY*12.0),"a curved hall's path, "+tag)
			var lane: AABB = (hall.get_meta("corridors") as Array)[0].box
			check(lane.position.x <= 0.01 and lane.end.x >= Hall.BAY*12.0-0.01 and lane.size.z >= RuinKit.THREAD,"the curved lane runs end to end, "+tag)
			check(_clear_along(hall,path,lane.grow(-0.02)),"nothing stands in the lane through the curve, "+tag)
			_breaks(hall,tag)
			# The bend is real: the far end turned by the turn.
			var ends: Array = hall.get_meta("ends")
			var far: Vector3 = ends[1].heading
			check(absf(wrapf(atan2(-far.z,far.x)-turn,-PI,PI)) < 0.01,"the far end heads round the curve, "+tag)
			for k in range(2):
				var e: Dictionary = ends[k]
				var s := 0.0 if k == 0 else Hall.BAY*12.0
				check((e.at as Vector3).distance_to(path.point(Vector3(s,0.0,0.0))) < 0.01,"an end sits at its path's end, "+tag)
				for side: float in [-1.0,1.0]:
					var column: Vector3 = path.point(Vector3(s,2.0,side*Hall.ROW_Z))
					check(not _clear(hall,AABB(column-Vector3(0.3,0.3,0.3),Vector3(0.6,0.6,0.6)),false),"an outer column stands at the mouth, "+tag)
			var line: Dictionary = (hall.get_meta("corridors") as Array)[0]
			var ok := true
			for p: Vector3 in line.points:
				var back: Vector3 = path.locate(p)
				if absf(back.z-lane.get_center().z) > 0.05 or absf(p.y-lane.position.y) > 0.05: ok = false
			check(ok and is_equal_approx(float(line.width),lane.size.z),"the lane's line follows the curve along its middle, "+tag)
			hall.free()

## The cost: a 12-bay hall, as the world builds it (IN_WORLD detail), under
## BUDGET triangles.
func _budget() -> void:
	RuinKit.set_detail(Hall.IN_WORLD)
	for weathered: float in [0.0,0.6]:
		var hall := Hall.hall(12,weathered,12)
		var count := RuinKit.triangles(hall)
		check(count < Hall.BUDGET,"a 12-bay hall at weathered %.1f is under budget: %d < %d" % [weathered,count,Hall.BUDGET])
		hall.free()
	RuinKit.set_detail(1.0)

## No hull of `node` reaches into `box` (in `path`'s space): each hull's
## points carried back into path space.
func _clear_along(node: Node, path, box: AABB, say := true) -> bool:
	var body := node.get_node_or_null("Body")
	if body == null: return true
	var grown := box.grow(3.0)
	for child in body.get_children():
		var shape := (child as CollisionShape3D).shape as ConvexPolygonShape3D
		var first: Vector3 = path.locate(shape.points[0])
		if not grown.has_point(first) and not path.curved():
			# A quick reject on a straight hall (path space is the frame).
			var raw := AABB(shape.points[0],Vector3.ZERO)
			for p in shape.points: raw = raw.expand(p)
			if not raw.intersects(box): continue
		var hull := AABB(first,Vector3.ZERO)
		for p in shape.points: hull = hull.expand(path.locate(p))
		if hull.intersects(box):
			if say: print("  in the way of %s: %s (path space)" % [node.name,hull])
			return false
	return true

## On uneven ground: piers grow down to a slope and a valley (tall in its
## middle), a hall's columns and walls reach below a slope (nothing floats),
## and a hall run into a hillside is buried at its far end, its lane cut
## short there and that mouth shut.
func _terrain() -> void:
	var slope := func(x: float, z: float) -> float: return 0.45*x+0.1*z+1.0
	var span := Aqueduct.span(3,0.6,3,true,slope)
	_grounded(span,slope,"the span's piers")
	span.free()
	var stump := Aqueduct.stump(3,0.6,slope)
	_grounded(stump,slope,"the stump")
	stump.free()
	var length := Aqueduct.SPAN*5
	var valley := func(x: float, z: float) -> float: return 8.0*absf(x/length-0.5)*2.0
	var run := Aqueduct.run(4,0.4,5,-1,false,valley)
	var feet: Array = run.get_meta("feet")
	feet.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	var middle: Vector3 = feet[feet.size()/2]
	check(middle.y < (feet[0] as Vector3).y-4.0 and middle.y < (feet[-1] as Vector3).y-4.0,"across a valley the piers are tall in its middle, short at its ends")
	_grounded(run,valley,"the valley run's piers")
	run.free()
	var hill := func(x: float, z: float) -> float: return 0.12*x+0.08*z
	var bay := Hall.bay(5,0.5,{},hill)
	_grounded(bay,hill,"the bay's columns and walls")
	bay.free()
	var bays := 5
	var buried := func(x: float, z: float) -> float: return clampf((x-Hall.BAY*bays*0.5)*0.6,0.0,14.0)
	var hall := Hall.hall(6,0.5,bays,buried)
	var lane: AABB = (hall.get_meta("corridors") as Array)[0].box
	var ends: Array = hall.get_meta("ends")
	check(lane.end.x < Hall.BAY*bays-4.0 and bool(ends[0].open) and not bool(ends[1].open),"a hall run into a hillside: its lane stops at the slope, its far mouth is buried")
	check(_clear(hall,lane.grow(-0.02)),"the buried hall's lane is clear as far as it goes")
	_grounded(hall,buried,"the buried hall's columns and walls")
	hall.free()

## Each foot `node` gives lies below the ground there, and stone reaches
## down to it: the lowest hull point within a pace of each foot is under
## the ground (nothing floats).
func _grounded(node: Node3D, ground: Callable, label: String) -> void:
	var feet: Array = node.get_meta("feet")
	check(not feet.is_empty(),label+": feet given")
	var hulls: Array = []
	for body in [node.get_node_or_null("Body")]+_pieces(node).map(func(c: Node) -> Node: return c.get_node_or_null("Body")):
		if body == null: continue
		var at: Vector3 = (body.get_parent() as Node3D).position if body.get_parent() != node else Vector3.ZERO
		for holder in body.get_children():
			var pts := PackedVector3Array()
			for p in ((holder as CollisionShape3D).shape as ConvexPolygonShape3D).points: pts.append(p+at)
			hulls.append(pts)
	var floating := 0
	for foot: Vector3 in feet:
		var g := float(ground.call(foot.x,foot.z))
		# The lowest stone standing over the foot: hulls whose plan covers it.
		var low := INF
		for pts: PackedVector3Array in hulls:
			var box := AABB(pts[0],Vector3.ZERO)
			for p in pts: box = box.expand(p)
			if foot.x > box.position.x-0.1 and foot.x < box.end.x+0.1 and foot.z > box.position.z-0.1 and foot.z < box.end.z+0.1:
				low = minf(low,box.position.y)
		if foot.y > g-0.05 or low > g:
			floating += 1
			print("  afloat: foot %s ground %.2f lowest stone %.2f" % [foot,g,low])
	check(floating == 0,label+" reach below the ground (%d not)" % floating)

## The connection points sit where the geometry is: a run's far end on its
## deck (a hull's top at DECK there), its head's at its abutment; a hall's
## mouths at its floor between its first and last outer columns.
func _connections() -> void:
	var run := Aqueduct.run(8,0.3,3)
	var ends: Array = run.get_meta("ends")
	check(ends.size() == 2 and ends[0].kind == "abutment" and ends[1].kind == "channel","a run's ends: its head's abutment, its channel's far end")
	check(_top_near(run,(ends[1].at as Vector3)+Vector3(-0.4,0.0,0.0),Aqueduct.DECK),"the run's far end sits on its deck")
	check(_top_near(run,(ends[0].at as Vector3)+Vector3(0.6,0.0,0.0),Aqueduct.DECK),"the run's head end sits on the cistern's floor")
	run.free()
	var hall := Hall.hall(9,0.4,4)
	var mouths: Array = hall.get_meta("ends")
	for m: Dictionary in mouths:
		var at: Vector3 = m.at
		check(is_equal_approx(at.y,float(m.height)) and not _clear(hall,AABB(Vector3(at.x-0.5,1.0,Hall.ROW_Z-0.5),Vector3(1.0,1.0,1.0)),false),"a hall's mouth sits at its floor by its end columns")
	hall.free()

## Whether a hull of `node` has a top within 0.2 m of `height` over `at`.
func _top_near(node: Node3D, at: Vector3, height: float) -> bool:
	for body in [node.get_node_or_null("Body")]:
		if body == null: continue
		for holder in body.get_children():
			var pts := ((holder as CollisionShape3D).shape as ConvexPolygonShape3D).points
			var box := AABB(pts[0],Vector3.ZERO)
			for p in pts: box = box.expand(p)
			if box.has_point(Vector3(at.x,box.position.y+0.01,at.z)) and absf(box.end.y-height) < 0.2: return true
	return false

func _mesh(node: Node3D) -> MeshInstance3D:
	return node.get_node_or_null("Mesh") as MeshInstance3D

## The flight and the grand stair, intact and ruined: over every tread,
## away from its edges, the body's top is the tread's own (RISER a step),
## its hulls meeting with no gap between treads, slabs or flights.
func _stairs_walk() -> void:
	for id: String in ["stairs","grand_stair"]:
		for seed_value: int in SEEDS:
			for weathered: float in [0.0,1.0]:
				var node := RuinKit.piece(id,seed_value,weathered)
				var boxes: Array[AABB] = []
				for holder in node.get_node("Body").get_children():
					var pts: PackedVector3Array = ((holder as CollisionShape3D).shape as ConvexPolygonShape3D).points
					var box := AABB(pts[0],Vector3.ZERO)
					for q in pts: box = box.expand(q)
					boxes.append(box)
				var grand := id == "grand_stair"
				var width := RuinKit.GRAND_WIDTH if grand else RuinKit.STAIR_WIDTH
				var n := RuinKit.GRAND_STEPS if grand else RuinKit.STEPS
				var tread := RuinKit.GRAND_TREAD if grand else RuinKit.TREAD
				var riser := RuinKit.GRAND_RISER if grand else RuinKit.RISER
				var run1 := (n-1)*tread+(RuinKit.GRAND_LANDING if grand else RuinKit.LANDING)
				var run2 := (n-1)*tread+RuinKit.LANDING if grand else 0.0
				var front := (run1+run2)*0.5
				var bad := 0
				var x := -width*0.5+0.15
				while x <= width*0.5-0.15:
					var d := 0.03
					while d < run1+run2-0.03:
						var step := mini(int(d/tread),n-1)+1 if d < run1 else n+mini(int((d-run1)/tread),n-1)+1
						var near := fmod(d if d < run1 else d-run1,tread)
						if near > 0.02 and near < tread-0.02:
							var top := -INF
							for box in boxes:
								if x > box.position.x and x < box.end.x and front-d > box.position.z and front-d < box.end.z: top = maxf(top,box.end.y)
							if absf(top-step*riser) > 0.005: bad += 1
						d += 0.037
					x += 0.11
				check(bad == 0,"%s seed %d weathered %.0f: every tread walks at its true top (%d off)" % [id,seed_value,weathered,bad])
				node.free()
