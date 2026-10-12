extends SceneTree
## The dragon's cyclone blast (scripts/dragon_cyclone.gd, docs/design/
## dragon-cyclone/round1.md), headless: fired over open turf it travels to
## its aim and lands there; a wall in the way breaks it; a pilot inside it
## is knocked outward and up (once a funnel) and the plane gets air out and
## up; the wind-up and the cooldown hold the cadence, and losing the pilot
## stops it.
##   godot --headless --path . --script tests/test_dragon_cyclone.gd
const DragonCyclone = preload("res://scripts/dragon_cyclone.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

var failures := 0
var made: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var space := root.get_world_3d().direct_space_state
	# Turf: a big flat floor, its top at y 0, on the turf layer.
	_box(Vector3(400.0,2.0,400.0),Vector3(0.0,-1.0,0.0),DragonCyclone.TURF)
	await physics_frame
	await physics_frame
	var mouth := Vector3(0.0,60.0,40.0)
	var aim := Vector3(0.0,0.0,-40.0)
	# Open turf: it lands at the aim.
	var c := _cyclone()
	c.fire(mouth,aim)
	var t := 0.0
	while c.lands == 0 and c.breaks == 0 and t < 20.0:
		c.advance(0.05,space,false,mouth,aim)
		t += 0.05
	check(c.lands == 1 and c.breaks == 0 and c.last_at.distance_to(aim) < 1.5,"over open turf it lands at its aim (%.1f m off, %.1f s)" % [c.last_at.distance_to(aim),t])
	var trip := mouth.distance_to(aim)/DragonCyclone.SPEED
	check(absf(t-trip) < 0.2,"aimed and straight: there in %.1f s at %.0f m/s (%.1f s)" % [trip,DragonCyclone.SPEED,t])
	# A pilot just inside it: knocked out and up, with its turn; once.
	var f: Dictionary = c.funnels[0]
	var at: Vector3 = f.pos
	var pilot := PilotMotor.new()
	var feet := at+Vector3(c.radius()*0.4,0.0,0.0)
	var v := c.pilot_knock(feet,pilot)
	check(v.x > 0.0 and v.y > 0.0 and absf(v.z) > 1.0,"a pilot inside is thrown outward (%.1f) and up (%.1f) with a spin (%.1f)" % [v.x,v.y,v.z])
	check(c.pilot_knock(feet,pilot) == Vector3.ZERO,"once a funnel")
	var c2 := _cyclone()
	c2.fire(mouth,aim)
	c2.funnels[0].state = "spin"
	c2.funnels[0].pos = at
	check(c2.pilot_knock(at+Vector3(c2.radius()*3.0,0.0,0.0),pilot) == Vector3.ZERO,"a pilot well outside it is untouched")
	var air: Dictionary = c.plane_air(at+Vector3(-c.radius()*0.5,c.tall()*0.4,0.0),Vector3.FORWARD)
	var wind: Vector3 = air.get("wind",Vector3.ZERO)
	check(wind.y > 5.0 and wind.x < 0.0 and absf((air.get("shove",Vector3.ZERO) as Vector3).z) > 1.0,"the plane in it is thrown out and up and rolled (wind %s)" % str(wind))
	# A wall in the way: broken there, never landed.
	_box(Vector3(30.0,30.0,1.0),Vector3(0.0,15.0,0.0),DragonCyclone.SOLID)
	await physics_frame
	await physics_frame
	var w := _cyclone()
	w.fire(mouth,aim)
	t = 0.0
	while w.lands == 0 and w.breaks == 0 and t < 20.0:
		w.advance(0.05,space,false,mouth,aim)
		t += 0.05
	check(w.breaks == 1 and w.lands == 0 and absf(w.last_at.z) < 1.0 and w.funnels.is_empty(),"a wall in the way breaks it there (z %.1f)" % w.last_at.z)
	# Cadence: spotted, a wind-up then a shot, then the cooldown and the
	# wind-up again before the next; not spotted, nothing.
	var k := _cyclone()
	var times: Array = []
	t = 0.0
	while t < 15.0:
		var was := k.shots
		t += 0.05
		k.advance(0.05,null,true,mouth,aim)
		if k.shots > was: times.append(snappedf(t,0.01))
	var gap := DragonCyclone.COOLDOWN+DragonCyclone.WINDUP
	var ok := times.size() == int((15.0-DragonCyclone.WINDUP-0.1)/gap)+1 and absf(float(times[0])-DragonCyclone.WINDUP) < 0.1
	for i in range(1,times.size()): ok = ok and absf(float(times[i])-float(times[i-1])-gap) < 0.1
	check(ok,"spotted, he fires after the wind-up, then every %.1f s (%s)" % [gap,str(times)])
	var n := times.size()
	for i in range(int((DragonCyclone.WINDUP*0.5)/0.05)): k.advance(0.05,null,true,mouth,aim)
	check(k.phase == "windup","winding up again")
	for i in range(int(gap*2.0/0.05)): k.advance(0.05,null,false,mouth,aim)
	check(times.size() == n and k.phase == "idle","lost, the wind-up stops and he holds fire")
	for one: Node in made: one.free()
	print("PASS: dragon cyclone" if failures == 0 else "FAIL: dragon cyclone (%d)" % failures)
	quit(1 if failures else 0)

func _cyclone() -> DragonCyclone:
	var c := DragonCyclone.new()
	c.look = false
	c.publish = false
	made.append(c)
	return c

func _box(size: Vector3, at: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	root.add_child(body)
	return body

func check(ok: bool, what: String) -> void:
	if ok: print("  ok: "+what)
	else:
		print("  FAILED: "+what)
		failures += 1
