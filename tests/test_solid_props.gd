extends SceneTree
## Solid props for the pilot on foot (scripts/solid_props.gd, scripts/
## wanderer_eye.gd), headless, on the walk-test island (studies/
## walk_island.tscn, the real game's scene): its own props cleared and a few
## set on its open ground, read by the walker as in play, and the motor
## (scripts/pilot_motor.gd) stepped with the walker's own ground, walk, wall
## and ledge answers at 60 frames a second:
##  - a wall kick off a spruce's trunk and off a broadleaf's (its trunk as
##    wide as it is at the body's height, foliage never the wall), and off a
##    cabin's gable wall;
##  - jumped onto a boulder, he stands on its top;
##  - a low log is walked over, a taller one stops a walk and is hopped over;
##  - walked into a trunk he still slides round it, never into it;
##  - walked into a cabin he slides along its wall, never into it; jumped at
##    its long wall he catches the eave and climbs onto the roof; dropped onto
##    it he stands on its roof.
##   godot --headless --path . --script tests/test_solid_props.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var failures := 0
var eye: Node
var data: NativeTerrainData
var motor: RefCounted

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("solid props test timed out"); quit(2))
	var scene: Node3D = load("res://studies/walk_island.tscn").instantiate()
	scene.places_path = OS.get_temp_dir().path_join("solid-props-test-%d" % Time.get_ticks_usec()).path_join("places.json")
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not scene.walk_ready: await process_frame
	for i in range(10): await process_frame
	eye = scene.wanderer
	motor = eye.motor
	var editor: NativeChunkEditor = scene._chunk_editor
	data = editor.data
	# The island's own props cleared, ours set on flat open ground.
	data.objects.clear()
	data.objects_revision += 1
	var start: Vector2 = scene.island.start
	var props := {}
	var taken: Array[Vector2] = []
	for spec: Array in [["cabin",1.0,4.0],["tree",1.0,2.5],["broadleaf",1.4,2.5],["boulder_1",1.1,2.0],["log",1.8,2.2],["log",3.6,2.5]]:
		var name: String = spec[0]+("_tall" if spec[0] == "log" and spec[1] > 2.0 else "")
		var spot := _flat_spot(start,taken,spec[2])
		var id := data.place(spec[0],spot,0.6,spec[1]) if spot != Vector2.INF else -1
		check(id >= 0,"Set a %s down at %s" % [name,str(spot)])
		if id < 0: continue
		taken.append(spot)
		props[name] = {"at":spot,"id":id,"room":spec[2]}
	await editor.refresh(self)
	for i in range(5): await process_frame
	eye._read_obstacles(true)
	check(eye.solids.parts.size() >= 7,"The walker reads them with their heights (%d parts)" % eye.solids.parts.size())
	if failures:
		_end(scene)
		return
	_kick(props.tree,"spruce")
	_kick(props.broadleaf,"broadleaf")
	_boulder(props.boulder_1)
	_low_log(props.log)
	_tall_log(props.log_tall)
	_slide_round(props.tree,"spruce")
	_slide_round(props.broadleaf,"broadleaf")
	_cabin(props.cabin)
	_end(scene)

func _end(scene: Node) -> void:
	print("PASS: solid props" if failures == 0 else "FAIL: solid props (%d)" % failures)
	scene.queue_free()
	for i in range(10): await process_frame
	quit(1 if failures else 0)

# --- Setting up ---------------------------------------------------------------------

## A flat spot of land near `near`, `room` m clear of the shore and of every
## spot already `taken` (each with its own room).
func _flat_spot(near: Vector2, taken: Array[Vector2], room: float) -> Vector2:
	var best := Vector2.INF
	for ring in range(0,60):
		var r := ring*0.5
		for k in range(maxi(1,ring*4)):
			var p := near+Vector2.from_angle(TAU*k/maxi(1,ring*4))*r
			if not _flat(p,room): continue
			var clear := true
			for other in taken:
				if p.distance_to(other) < room+3.0: clear = false
			if clear: return p
	return best

func _flat(p: Vector2, room: float) -> bool:
	var inland: Variant = data.sample(p,data.shore_distance)
	if not data.has_land(p) or inland == null or float(inland) < room+2.0: return false
	var h: Variant = data.ground_height(p)
	if h == null: return false
	for k in range(12):
		var q: Variant = data.ground_height(p+Vector2.from_angle(TAU*k/12.0)*(room+1.5))
		if q == null or absf(float(q)-float(h)) > 0.4: return false
	return true

## The pilot stood on the ground at plate point `at`, facing `way`.
func _stand(at: Vector2, way: Vector2) -> void:
	motor.reset(Vector3(at.x,eye._motor_ground(at),at.y),PilotMotor.facing_of(way))

## One motor step with the walker's own answers.
func _step(want: Vector2, jump := false) -> Dictionary:
	return motor.step(DT,want,PilotMotor.RUN,jump,eye._motor_ground,eye._walk,eye._lip)

func _flat_feet() -> Vector2:
	return Vector2(motor.feet.x,motor.feet.z)

func _ground(p: Vector2) -> float:
	return float(data.ground_height(p))

# --- Walls --------------------------------------------------------------------------

## Run at the prop, jump, take hold of it and kick off: off its trunk (as
## wide as it is at the body's height, the figure's radius and the motor's
## reach for a wall added), inside its foliage if that is wider.
func _kick(prop: Dictionary, what: String) -> void:
	var c: Vector2 = prop.at
	var out := Vector2(1.0,0.3).normalized()
	_stand(c+out*3.2,-out)
	var held := false
	var jumped := false
	for i in range(120):
		var near := _flat_feet().distance_to(c)
		var jump: bool = near < 2.2 and i < 60
		_step(-out,jump)
		if motor.move == "wall":
			held = true
			break
		if jumped and motor.grounded: break
		jumped = jumped or not motor.grounded
	var gap := _flat_feet().distance_to(c)
	check(held,"A %s: jumped at, he takes hold of it (%.2f m from its middle)" % [what,gap])
	if not held: return
	var trunk := 0.0
	var leaves := 0.0
	var y: float = motor.feet.y
	for p: Dictionary in eye.solids.parts:
		if p.key != prop.id: continue
		var wide: float = eye.solids._round_span(p,y+eye.STEP,y+eye.HEAD)
		if p.soft: leaves = maxf(leaves,wide)
		else: trunk = maxf(trunk,wide)
	check(gap <= trunk+eye.RADIUS+PilotMotor.WALL_PROBE+0.01,"On the trunk (%.2f m from its middle; trunk %.2f there)" % [gap,trunk])
	if leaves > trunk+PilotMotor.WALL_PROBE: check(gap < leaves+eye.RADIUS,"Inside its foliage (%.2f m wide there)" % leaves)
	check(motor.wall_out.dot(out) > 0.8,"Its way off points back out (%.2f)" % motor.wall_out.dot(out))
	for i in range(6): _step(-out)
	y = motor.feet.y
	var events := _step(-out,true)
	check(events.has("wall_jump"),"Jump on it kicks off")
	var away := Vector2(motor.velocity.x,motor.velocity.z)
	check(away.dot(motor.wall_out if motor.wall_out != Vector2.ZERO else out) > 3.0 and motor.velocity.y > 3.0,"Up and out, away from it (%.1f m/s out, %.1f up)" % [away.dot(out),motor.velocity.y])
	var top := y
	for i in range(40):
		_step(Vector2.ZERO)
		top = maxf(top,motor.feet.y)
	check(top > y+1.0 and _flat_feet().distance_to(c) > gap+1.0,"Kicked up %.2f m and %.2f m away" % [top-y,_flat_feet().distance_to(c)-gap])
	for i in range(90): _step(Vector2.ZERO)

## Walked into a trunk on the ground, he slides round it to the far side,
## never in it.
func _slide_round(prop: Dictionary, what: String) -> void:
	var c: Vector2 = prop.at
	var way := Vector2(-0.3,1.0).normalized()
	_stand(c-way*3.0+Vector2(-way.y,way.x)*0.1,way)
	var g := _ground(c)
	var nearest := INF
	var wide := 0.0
	for p: Dictionary in eye.solids.parts:
		if p.key == prop.id and p.has("round"): wide = maxf(wide,eye.solids._round_span(p,g+eye.STEP+0.15,g+eye.HEAD-0.15))
	for i in range(150):
		_step(way)
		nearest = minf(nearest,_flat_feet().distance_to(c))
	var past := (_flat_feet()-c).dot(way)
	check(past > 1.5,"Walked into a %s, he slides round it on (%.2f m past it)" % [what,past])
	check(nearest >= wide+eye.RADIUS-0.02,"Never into it (%.2f m from its middle, kept %.2f)" % [nearest,wide+eye.RADIUS])

# --- Tops ---------------------------------------------------------------------------

## Run at the boulder and jump: he lands on its top and stands there.
func _boulder(prop: Dictionary) -> void:
	var c: Vector2 = prop.at
	var g := _ground(c)
	var top: float = eye.solids.top(c)
	check(top > g+0.8,"The boulder has a top %.2f m up" % (top-g))
	var way := Vector2(0.4,-1.0).normalized()
	_stand(c-way*3.6,way)
	# Walked into, it stops him: its top is out of a step's reach.
	var blocked := INF
	for i in range(60):
		_step(way*0.5)
		blocked = minf(blocked,_flat_feet().distance_to(c))
	check(motor.grounded and motor.feet.y < g+0.3 and blocked > 0.9,"Walked into, it stops him (kept %.2f m off its middle)" % blocked)
	_stand(c-way*3.6,way)
	var jumped := false
	var landed := false
	var held := 0
	for i in range(160):
		var near := _flat_feet().distance_to(c)
		var want := way*0.6 if not jumped or motor.feet.y < top-0.2 else Vector2.ZERO
		var jump: bool = (near < 1.75 and not jumped) or (jumped and not motor.grounded and held < 20)
		if jumped: held += 1
		var events := _step(want,jump)
		if not motor.grounded: jumped = true
		if jumped and events.has("landed"):
			landed = true
			break
	for i in range(40): _step(Vector2.ZERO)
	var at := _flat_feet()
	check(landed and motor.grounded,"Jumped at, he lands")
	check(motor.feet.y > g+0.7 and absf(motor.feet.y-float(eye.solids.top(at))) < 0.05,"On the boulder's top (%.2f m up, its top there %.2f)" % [motor.feet.y-g,float(eye.solids.top(at))-g])
	for i in range(60): _step(-way*0.5)
	check(motor.grounded and motor.feet.y < g+0.3 and _flat_feet().distance_to(c) > 1.0,"And walks off it again (%.2f m up)" % (motor.feet.y-g))

## The long way across a log part (its middle's long axis, plate x, z).
func _log_across(prop: Dictionary) -> Vector2:
	for p: Dictionary in eye.solids.parts:
		if p.key != prop.id or not p.has("rects"): continue
		var widest := Rect2()
		for r: Variant in p.rects:
			if r != null and (r as Rect2).get_area() > widest.get_area(): widest = r
		var basis: Basis = (p.from_local as Transform3D).basis
		var long := basis.x if widest.size.x*basis.x.length() > widest.size.y*basis.z.length() else basis.z
		var flat := Vector2(long.x,long.z).normalized()
		return Vector2(-flat.y,flat.x)
	return Vector2.RIGHT

## A low log: walked straight over.
func _low_log(prop: Dictionary) -> void:
	var c: Vector2 = prop.at
	var g := _ground(c)
	var top: float = eye.solids.top(c)
	check(top > g+0.2 and top < g+PilotMotor.STEP_UP,"The low log stands %.2f m, within a step" % (top-g))
	var way := _log_across(prop)
	_stand(c-way*2.0,way)
	var high := -INF
	for i in range(90):
		_step(way*0.5)
		high = maxf(high,motor.feet.y-_ground(_flat_feet()))
	var past := (_flat_feet()-c).dot(way)
	var aside := absf((_flat_feet()-c).dot(Vector2(-way.y,way.x)))
	check(past > 1.0 and aside < 0.3,"Walked straight over it (%.2f m past, %.2f aside)" % [past,aside])
	check(high > 0.15,"Stepping up onto it on the way (%.2f m)" % high)

## A taller log: it stops a walk, and a jump hops it.
func _tall_log(prop: Dictionary) -> void:
	var c: Vector2 = prop.at
	var g := _ground(c)
	var top: float = eye.solids.top(c)
	check(top > g+PilotMotor.STEP_UP,"The tall log stands %.2f m, over a step" % (top-g))
	var way := _log_across(prop)
	_stand(c-way*2.5,way)
	for i in range(90): _step(way*0.5)
	check((_flat_feet()-c).dot(way) < 0.0 and motor.feet.y < g+0.3,"Walked into, it stops him short (%.2f m before it)" % -(_flat_feet()-c).dot(way))
	_stand(c-way*2.5,way)
	var jumped := false
	for i in range(120):
		var near := (c-_flat_feet()).dot(way)
		var events := _step(way,near < 1.4 and (not jumped or not motor.grounded))
		if not motor.grounded: jumped = true
	var past := (_flat_feet()-c).dot(way)
	check(jumped and past > 1.0,"Jumped, he hops over it (%.2f m past)" % past)

# --- The cabin ----------------------------------------------------------------------

func _cabin(prop: Dictionary) -> void:
	var c: Vector2 = prop.at
	var g := _ground(c)
	var roof: float = eye.solids.top(c)
	check(roof > g+2.0,"The cabin's roof stands %.2f m" % (roof-g))
	# Its walls: the part's own frame.
	var part := {}
	for p: Dictionary in eye.solids.parts:
		if p.key == prop.id: part = p
	var basis: Basis = (part.from_local as Transform3D).basis
	var side := Vector2(basis.x.x,basis.x.z).normalized()
	var along := Vector2(basis.z.x,basis.z.z).normalized()
	# Walked at a wall aslant: along it, never in it.
	var way := (-side+along*0.5).normalized()
	_stand(c+side*4.0,way)
	var inside := 0
	for i in range(90):
		_step(way*0.5)
		if eye.solids.inside(motor.feet,true): inside += 1
	var moved := (_flat_feet()-c).dot(along)
	var off := (_flat_feet()-c).dot(side)
	check(inside == 0 and off > 1.0,"Walked into the cabin, never in it (%.2f m off its middle)" % off)
	check(moved > 1.0,"Sliding along its wall (%.2f m along)" % moved)
	# Its gable end is a wall to kick off (its long sides' eaves are low
	# enough that a hold there catches the eave, below).
	_stand(c+along*3.6,-along)
	var held := false
	for i in range(90):
		var near := (_flat_feet()-c).dot(along)
		_step(-along,near < 3.0 and i < 40)
		if motor.move == "wall":
			held = true
			break
	check(held and motor.wall_out.dot(along) > 0.9,"Jumped at its gable wall, he takes hold (%.2f)" % motor.wall_out.dot(along))
	if held:
		_step(-along)
		var events := _step(-along,true)
		check(events.has("wall_jump") and Vector2(motor.velocity.x,motor.velocity.z).dot(along) > 3.0,"And kicks off it")
	for i in range(90): _step(Vector2.ZERO)
	# Its eave is a ledge: jumped at the wall and held into it, he catches the
	# roof's edge and climbs up onto it.
	_stand(c+side*3.2,-side)
	var caught := false
	var climbed := false
	for i in range(240):
		var near := (_flat_feet()-c).dot(side)
		_step(-side,near < 2.6 and i < 40)
		if motor.on_ledge(): caught = true
		if caught and motor.grounded and not motor.on_ledge():
			climbed = true
			break
	check(caught,"Jumped at its wall, he catches the eave")
	check(climbed and motor.feet.y > g+1.4 and absf(motor.feet.y-float(eye.solids.top(_flat_feet()))) < 0.05,"And climbs up onto the roof (%.2f m up)" % (motor.feet.y-g))
	for i in range(30): _step(Vector2.ZERO)
	# Dropped onto it, he stands on its roof.
	motor.reset(Vector3(c.x,roof+1.5,c.y),0.0)
	motor.grounded = false
	var landed := false
	for i in range(120):
		if _step(Vector2.ZERO).has("landed"): landed = true
		if landed and i > 60: break
	var at := _flat_feet()
	check(landed and motor.grounded and absf(motor.feet.y-float(eye.solids.top(at))) < 0.05 and motor.feet.y > g+2.0,
		"Dropped onto it, he stands on its roof (%.2f m up)" % (motor.feet.y-g))
