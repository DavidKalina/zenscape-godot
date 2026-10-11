extends SceneTree
## The Hollow Keel (studies/hollow_keel_isle.tscn), headless: the undercroft
## the plane flies through is clear of stone along its line (a plane-sized
## slab swept down the lane, the tokens' spheres, the breach line), the
## hall's mouths are open, the stairs lead from the chapel's turf to the
## hall's floor and are walked, the porch and its rope bridge to the islet
## are walked, the foot tokens stand in open air, and the isle draws within
## its triangle budget.
##   godot --headless --path . --script tests/test_hollow_keel_isle.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const Keel = preload("res://studies/hollow_keel_isle_art.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const DT := 1.0/60.0
const BUDGET := 700000
var failures := 0
var study: Node3D
var m: PilotMotor

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(400.0).timeout.connect(func() -> void: push_error("hollow keel test timed out"); quit(2))
	study = load("res://studies/hollow_keel_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	for i in range(3): await physics_frame
	var tris: int = study.triangles(study.art)
	check(tris > 0 and tris < BUDGET,"The isle draws %d triangles (budget %d)" % [tris,BUDGET])
	_plane_line()
	_stairs()
	_porch_and_islet()
	_tokens()
	print("PASS: hollow keel" if failures == 0 else "FAIL: hollow keel (%d)" % failures)
	quit(1 if failures else 0)

# --- Driving (the aqueduct isle test's) ----------------------------------------------

func tick(want: Vector2, jump := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = false
	study.script_twirl = false
	study.tick(DT)

func flat(v: Vector3) -> Vector2:
	return Vector2(v.x,v.z)

## Walked through `points` (world x, z), the stick only, never a jump.
func walk(from: Vector3, points: Array, frames := 9000, slow_from := 1000, jump_at := -1) -> Dictionary:
	study.place(from,(points[0]-flat(from)).normalized())
	for i in range(20): tick(Vector2.ZERO)
	var i := 0
	var lowest := INF
	for f in range(frames):
		var off: Vector2 = points[i]-flat(m.feet)
		var slow := i >= slow_from
		if off.length() < (0.5 if i == points.size()-1 else (0.35 if slow else 0.9)):
			i += 1
			if i >= points.size(): return {"ok":m.grounded,"lowest":lowest}
			continue
		tick(off.normalized()*(0.3 if slow else 1.0),i == jump_at and f%20 < 3)
		lowest = minf(lowest,m.feet.y)
		if OS.has_environment("HK_TRACE") and f%6 == 0: print("   f%d i%d feet %s grounded %s" % [f,i,m.feet,m.grounded])
		if m.feet.y < Keel.YF-20.0: break
	return {"ok":false,"lowest":lowest,"at":i,"feet":m.feet}

func _ray(a: Vector3, b: Vector3) -> PhysicsRayQueryParameters3D:
	var r := PhysicsRayQueryParameters3D.new()
	r.from = a
	r.to = b
	return r

# --- The plane's line -----------------------------------------------------------------------

## A plane-sized slab (the bump probe's size, a margin on) swept down the lane
## from well outside one mouth to well outside the other, and the tokens'
## spheres.
func _plane_line() -> void:
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(PlaneFigure.SPAN+0.6,0.5,1.4)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = box
	var blocked := 0
	var first := ""
	var x := Keel.HALL_X-8.0
	while x < Keel.HALL_X+Keel.LENGTH+8.0:
		q.transform = Transform3D(Basis.IDENTITY,Vector3(x,Keel.YF+Keel.LANE_Y,Keel.MID.y+Keel.LANE_Z))
		if not space.intersect_shape(q,1).is_empty():
			blocked += 1
			if first == "": first = " first at x %.1f" % x
		x += 0.5
	check(blocked == 0,"Plane: the undercroft's lane is clear of stone for its whole %.0f m, mouth to mouth, a plane's span and a margin wide (%d slabs blocked)%s" % [Keel.LENGTH+16.0,blocked,first])
	# Its generous width: 0.9 m to spare either side.
	var narrow := 0
	x = Keel.HALL_X+2.0
	while x < Keel.HALL_X+Keel.LENGTH-2.0:
		for dz in [-0.9,0.9]:
			q.transform = Transform3D(Basis.IDENTITY,Vector3(x,Keel.YF+Keel.LANE_Y,Keel.MID.y+Keel.LANE_Z+dz))
			if not space.intersect_shape(q,1).is_empty():
				narrow += 1
				break
		x += 0.5
	check(narrow == 0,"Plane: the lane has 0.9 m to spare each side the whole way (%d places narrower)" % narrow)
	var ball := SphereShape3D.new()
	ball.radius = 0.9
	q.shape = ball
	var lines: Array = Keel.plane_tokens()
	var tokens := 0
	var shut := 0
	for l: Array in lines:
		for p: Vector3 in l[3]:
			tokens += 1
			q.transform = Transform3D(Basis.IDENTITY,p)
			if not space.intersect_shape(q,1).is_empty(): shut += 1
	check(lines.size() == 3 and tokens >= 12 and shut == 0,"Plane: %d tokens on %d lines, every one in open air, 0.9 m clear (%d not)" % [tokens,lines.size(),shut])
	# The tight line: out through a breach in the south wall and clear.
	var bx := Keel.right_breach()
	check(bx > 0.0,"Plane: the south wall has a flyable breach (x %.1f)" % bx)
	var out := 0
	var z := Keel.MID.y+Keel.LANE_Z
	q.shape = box
	while bx > 0.0 and z < Keel.MID.y+Hall.WALL_Z+4.0:
		q.transform = Transform3D(Basis.IDENTITY,Vector3(Keel.HALL_X+bx,Keel.YF+3.1,z))
		if not space.intersect_shape(q,1).is_empty(): out += 1
		z += 0.5
	check(out == 0,"Plane: the breach line leaves the hall clear of stone (%d slabs blocked)" % out)
	var hit := space.intersect_ray(_ray(Vector3(Keel.HALL_X-8.0,Keel.YF+Keel.LANE_Y,Keel.MID.y+Keel.LANE_Z),Vector3(Keel.HALL_X+Keel.LENGTH+8.0,Keel.YF+Keel.LANE_Y,Keel.MID.y+Keel.LANE_Z)))
	check(hit.is_empty(),"Plane: a ray down the lane from outside one mouth to outside the other meets nothing")
	var wall := space.intersect_ray(_ray(Vector3(Keel.HALL_X+10.0,Keel.YF+8.0,Keel.MID.y-4.0),Vector3(Keel.HALL_X+10.0,Keel.YF+30.0,Keel.MID.y-4.0)))
	check(not wall.is_empty(),"Plane: the plate stands over the hall (a ray up from the nave meets stone)")

# --- On foot -------------------------------------------------------------------------------------

## From before the chapel's arch, in at the arch to the shaft's head and down
## the three grand stairs to the hall's floor: the stick only.
func _stairs() -> void:
	var x0: float = Keel.stair_x(0)
	var x1: float = Keel.stair_x(1)
	var x2: float = Keel.stair_x(2)
	var head: Vector3 = Keel.stair_head(0)
	var foot: Vector3 = Keel.stair_foot(0)
	var r := walk(Vector3(x0,Keel.TOP,Keel.MID.y-24.0),[Vector2(x0,head.z-1.0),Vector2(x0,head.z+2.0),Vector2(x0,foot.z-1.0),Vector2(x1,foot.z-0.4),Vector2(x1,Keel.stair_foot(1).z),Vector2(x2,Keel.stair_foot(1).z),Vector2(x2,Keel.stair_foot(2).z+0.3)],9000,4,5)
	check(bool(r.ok) and absf(m.feet.y-Keel.YF) < 0.6,"Stairs: from the chapel's turf down the three grand stairs to the hall's floor, walked (feet %s, floor %.2f; %s)" % [m.feet,Keel.YF,str(r)])

## From the foot of the stairs along the hall's open floor to the east mouth,
## out on the porch, over the rope bridge to the islet.
func _porch_and_islet() -> void:
	var b: Vector3 = (Keel.bridge_ends()[0] as Array)[0]
	var e: Vector3 = (Keel.bridge_ends()[0] as Array)[1]
	var r := walk(Vector3(Keel.stair_x(2)+3.0,Keel.YF,Keel.MID.y+Keel.LANE_Z),[Vector2(Keel.HALL_X+Keel.LENGTH-4.0,Keel.MID.y+Keel.LANE_Z),Vector2(Keel.HALL_X+Keel.LENGTH+2.0,Keel.MID.y+Keel.LANE_Z),Vector2(b.x-1.0,b.z),Vector2(b.x+1.0,b.z),Vector2(e.x,e.z),Vector2(Keel.ISLET.x,Keel.ISLET.y)])
	check(bool(r.ok) and absf(m.feet.y-Keel.ISLET.w) < 0.6,"Porch: from the stairs' foot along the hall, out on the porch, over the rope bridge to the islet (feet %s; %s)" % [m.feet,str(r)])

func _tokens() -> void:
	var life: Node = study.get("life")
	check(life != null and life.tokens != null and life.tokens.tokens.size() >= 4,"Tokens: %d on-foot tokens" % (life.tokens.tokens.size() if life != null and life.tokens != null else 0))
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	var ball := SphereShape3D.new()
	ball.radius = 0.4
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	var shut := 0
	var low := 0
	for t: Dictionary in Keel.foot_spots():
		q.transform = Transform3D(Basis.IDENTITY,t.at)
		if not space.intersect_shape(q,1).is_empty():
			shut += 1
			print("     token %s inside stone at %s" % [t.name,t.at])
		if (t.at as Vector3).y < Keel.YF+3.0: low += 1
	check(shut == 0,"Tokens: every foot token stands in open air (%d not)" % shut)
	check(low >= 3,"Tokens: %d of them down in the undercroft and on the porch and islet" % low)
	var flocks: Array = life.birds.flocks if life != null and life.birds != null else []
	check(flocks.size() >= 1,"Life: songbird flocks perched (%d)" % flocks.size())
