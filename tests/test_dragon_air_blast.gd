extends SceneTree
## The dragon's air blast (scripts/dragon_air_blast.gd, docs/design/
## dragon-air-blast/round1.md), headless: the shot leads a pilot running
## straight and meets him, a juke at the shot saves him; stone cover in the
## way pops it harmlessly; its burst knocks the pilot out and up from it,
## far harder than the cyclone, once a burst, and throws the plane out and
## down; the cadence holds and losing the pilot stops it.
##   godot --headless --path . --script tests/test_dragon_air_blast.gd
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const DragonCyclone = preload("res://scripts/dragon_cyclone.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

const STEP := 1.0/60.0

var failures := 0
var made: Array = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var space := root.get_world_3d().direct_space_state
	_box(Vector3(600.0,2.0,600.0),Vector3(0.0,-1.0,0.0),DragonAirBlast.TURF)
	await physics_frame
	await physics_frame
	var mouth := Vector3(0.0,60.0,90.0)
	var run := Vector3(7.0,0.0,0.0)
	# The lead, alone: aimed where he will be when it gets there.
	var aim := Vector3(-10.0,1.0,0.0)
	var led := DragonAirBlast.lead(mouth,aim,run)
	var trip := mouth.distance_to(led)/DragonAirBlast.SPEED
	check(led.distance_to(aim+run*trip*DragonAirBlast.LEAD) < 0.05 and led.x > aim.x,"the shot leads his run (%.1f m ahead, %.2f s out)" % [led.x-aim.x,trip])
	# Running straight in the open: it meets him and throws him.
	var straight := await _duel(space,mouth,run,false)
	check(straight.shots >= 1 and straight.knocked,"running straight he is hit (%s)" % str(straight))
	# Juking (turning back the moment it fires): it misses.
	var juke := await _duel(space,mouth,run,true)
	check(juke.shots >= 1 and not juke.knocked,"juking at the shot he is missed (%s)" % str(juke))
	# Stone cover in the way: popped, harmless.
	var wall := _box(Vector3(30.0,30.0,1.0),Vector3(0.0,15.0,20.0),DragonAirBlast.SOLID)
	await physics_frame
	await physics_frame
	var c := _blast()
	var pilot := PilotMotor.new()
	var feet := Vector3(0.0,0.0,0.0)
	c.fire(mouth,feet+Vector3.UP)
	var t := 0.0
	var v := Vector3.ZERO
	while c.lands == 0 and c.breaks == 0 and t < 5.0:
		c.advance(STEP,space,false,mouth,feet+Vector3.UP)
		v = c.pilot_knock(feet,pilot)
		t += STEP
	check(c.breaks == 1 and c.lands == 0 and absf(c.last_at.z-20.5) < 1.0 and v == Vector3.ZERO,"a wall in the way pops it, harmless (z %.1f)" % c.last_at.z)
	wall.free()
	await physics_frame
	await physics_frame
	# The burst: out and up from it, harder than the cyclone's throw, once.
	var b := _blast()
	b.fire(Vector3(0.0,40.0,0.0),Vector3.ZERO)
	t = 0.0
	while b.lands == 0 and t < 3.0:
		b.advance(STEP,space,false,mouth,Vector3.INF)
		t += STEP
	check(b.lands == 1 and b.last_at.length() < 1.5,"over open turf it bursts at its aim (%.1f m off)" % b.last_at.length())
	var east := b.last_at+Vector3(2.0,-b.last_at.y,0.0)
	var k := b.pilot_knock(east,pilot)
	var tall := DragonAirBlast.walker_tall()
	var cyclone: Vector3 = pilot.knock_velocity(Vector2.RIGHT,DragonCyclone.KNOCK_OUT*tall,DragonCyclone.KNOCK_UP*tall)
	check(k.x > 0.0 and k.y > 0.0 and absf(k.z) < k.x*0.5,"the pilot is thrown outward (%.1f) and up (%.1f)" % [k.x,k.y])
	check(Vector2(k.x,k.z).length() > Vector2(cyclone.x,cyclone.z).length()*1.8,"far harder than the cyclone (%.1f vs %.1f m/s out)" % [Vector2(k.x,k.z).length(),Vector2(cyclone.x,cyclone.z).length()])
	check(b.pilot_knock(east,pilot) == Vector3.ZERO,"once a burst")
	# Its knock is a hit stun: the ragdoll's tumble, poise held off a while,
	# and no second blast while he is down.
	var hit := PilotMotor.new()
	hit.knock(k,b)
	check(hit.stunned == "knock" and hit.move == "tumble" and hit.recovering(),"the blast stuns him (%s, %s)" % [hit.stunned,hit.move])
	check(hit.poise_left() >= hit.poise,"his poise is held off at least %.2f s (%.2f)" % [hit.poise,hit.poise_left()])
	check(not hit.stunnable(b),"the same blast can't stun him again at once")
	var far := _blast()
	far.fire(Vector3(0.0,40.0,0.0),Vector3.ZERO)
	for i in range(int(1.0/STEP)): far.advance(STEP,space,false,mouth,Vector3.INF)
	check(far.pilot_knock(Vector3(DragonAirBlast.shock_radius()*2.0,0.0,0.0),pilot) == Vector3.ZERO,"a pilot well outside the shock is untouched")
	var air: Dictionary = b.plane_air(b.last_at+Vector3(-4.0,3.0,0.0),Vector3.FORWARD)
	var wind: Vector3 = air.get("wind",Vector3.ZERO)
	var shove: Vector3 = air.get("shove",Vector3.ZERO)
	check(wind.x < -10.0 and wind.y < -10.0 and absf(shove.z) > 5.0 and shove.x < 0.0,"the plane is thrown out and down, nose down, rolled (wind %s, shove %s)" % [str(wind),str(shove)])
	# Cadence: spotted, a shot every WINDUP+COOLDOWN; lost, none.
	var q := _blast()
	var times: Array = []
	t = 0.0
	while t < 10.0:
		var was := q.shots
		t += 0.05
		q.advance(0.05,null,true,mouth,aim)
		if q.shots > was: times.append(snappedf(t,0.01))
	var gap := DragonAirBlast.COOLDOWN+DragonAirBlast.WINDUP
	var ok := times.size() >= 3 and absf(float(times[0])-DragonAirBlast.WINDUP) < 0.11
	for i in range(1,times.size()): ok = ok and absf(float(times[i])-float(times[i-1])-gap) < 0.11
	check(ok and gap >= 2.5 and gap <= 3.0,"spotted, he fires after a %.2f s tell, then every %.2f s (%s)" % [DragonAirBlast.WINDUP,gap,str(times)])
	var n := times.size()
	for i in range(int(gap*2.0/0.05)): q.advance(0.05,null,false,mouth,aim)
	check(q.shots == n and q.phase == "idle","lost, he holds fire")
	for one: Node in made: one.free()
	print("PASS: dragon air blast" if failures == 0 else "FAIL: dragon air blast (%d)" % failures)
	quit(1 if failures else 0)

## A pilot running `run` m/s across open turf under his mouth, spotted:
## one shot, led; `juke` turns him back the moment it is fired. Whether
## its burst knocked him.
func _duel(space: PhysicsDirectSpaceState3D, mouth: Vector3, run: Vector3, juke: bool) -> Dictionary:
	var c := _blast()
	var pilot := PilotMotor.new()
	var feet := Vector3(-20.0,0.0,0.0)
	var vel := run
	var knocked := false
	var t := 0.0
	while t < 3.0 and not knocked:
		var was := c.shots
		c.advance(STEP,space,c.shots == 0,mouth,feet+Vector3.UP*0.9)
		if juke and c.shots > was: vel = -run
		if c.pilot_knock(feet,pilot) != Vector3.ZERO: knocked = true
		feet += vel*STEP
		t += STEP
	return {"shots":c.shots,"bursts":c.lands,"knocked":knocked,"at":"%.1f" % feet.x,"burst":"%.1f" % c.last_at.x}

func _blast() -> DragonAirBlast:
	var c := DragonAirBlast.new()
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
