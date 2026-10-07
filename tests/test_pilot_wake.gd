extends SceneTree
## The pilot's wake through low foliage (scripts/pilot_wake.gd, read by
## shaders/foliage_tread.gdshaderinc), on its CPU mirror `push_at`: running
## through, plants beside his path lean out from it and those ahead lean on
## ahead; the stretch behind him is still parted well back (a
## trailing wake, not a ring at his feet: 1.5 m back at a run); a plant he passed leans out, then
## springs back past upright and settles; a run parts wider and harder than a
## walk; standing he parts a little ring; in the air he parts nothing, and a
## hard landing parts wider a moment; hidden, his wake settles and the shaders
## stop reading it. The surface and meadow shaders compile with it (headless
## parses them), and the mushrooms take the wobble.
##   godot --headless --path . --script tests/test_pilot_wake.gd
const PilotWake = preload("res://scripts/pilot_wake.gd")
const Mushroom = preload("res://scripts/mushroom_mesh.gd")
const DT := 1.0/60.0
var failures := 0

## What the wake reads of the motor.
class Motor:
	extends RefCounted
	var feet := Vector3.ZERO
	var ground_y := 0.0
	var grounded := true
	var velocity := Vector3.ZERO

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, what: String) -> void:
	if ok: print("ok   ",what)
	else:
		failures += 1
		print("FAIL ",what)

func run() -> void:
	_spring()
	_run_through()
	_walk_and_run()
	_stand_jump_land()
	_hidden()
	_shaders()
	print("PASS: pilot wake" if failures == 0 else "FAIL: pilot wake (%d)" % failures)
	quit(1 if failures else 0)

func _wake(motor: Motor = null) -> Node:
	var wake: Node = PilotWake.new()
	wake.motor = motor
	root.add_child(wake)
	wake.set_process(false)
	return wake

## Runs the wake `seconds` along x at `speed` from `from`, calling `each`
## (with the time) every frame.
func _go(wake: Node, from: Vector3, speed: float, seconds: float, each := Callable()) -> Vector3:
	var at := from
	var t := 0.0
	while t < seconds:
		at.x += speed*DT
		wake.advance(DT,at,true)
		t += DT
		if each.is_valid(): each.call(t,at)
	return at

func _spring() -> void:
	check(is_equal_approx(PilotWake.spring(0.0),1.0) and is_equal_approx(PilotWake.spring(PilotWake.HOLD),1.0),"Held while he passes")
	var low := 1.0
	var low_at := 0.0
	for i in range(200):
		var t := PilotWake.HOLD+i*0.01
		if PilotWake.spring(t) < low:
			low = PilotWake.spring(t)
			low_at = t
	check(low < -0.2 and low > -0.45,"Springs back past upright by %.0f %%" % (-low*100.0))
	check(absf(low_at-(PilotWake.HOLD+PI/PilotWake.RING)) < 0.05 and low_at < 0.8,"Overshooting at %.2f s" % low_at)
	check(absf(PilotWake.spring(1.5)) < 0.03 and PilotWake.spring(PilotWake.HOLD+PilotWake.LIFE+0.1) == 0.0,"Settled by 1.5 s")

func _run_through() -> void:
	var wake := _wake()
	var plant := Vector2(6.0,0.35)
	# Lambdas copy locals: what they find goes in here.
	var seen := {"out":-INF,"back":INF,"after":0.0}
	var head := _go(wake,Vector3.ZERO,PilotWake.RUN,3.5,func(_t: float, at: Vector3) -> void:
		var push: Vector3 = wake.push_at(plant)
		seen.out = maxf(seen.out,push.y)
		if at.x > plant.x: seen.back = minf(seen.back,push.y)
		if at.x > plant.x+PilotWake.RUN*1.8: seen.after = maxf(seen.after,absf(push.y)))
	check(seen.out > 0.5,"A plant beside his path leans out from it (%.2f)" % seen.out)
	check(seen.back < -0.08,"Then springs back past upright (%.2f)" % seen.back)
	check(seen.after < 0.02,"And settles once he is well past (%.3f)" % seen.after)
	var h := Vector2(head.x,head.z)
	var left: Vector3 = wake.push_at(h+Vector2(-0.4,0.35))
	var right: Vector3 = wake.push_at(h+Vector2(-0.4,-0.35))
	check(left.y > 0.3 and right.y < -0.3,"Both sides part, away from him (%.2f, %.2f)" % [left.y,right.y])
	check(wake.push_at(h+Vector2(0.4,0.05)).x > 0.3,"The plants ahead lean on ahead of him")
	check(wake.push_at(h).z > 0.5,"What is under him is pressed down")
	# The wake trails: still parted this far back.
	var back := 0.0
	for i in range(1,60):
		var d := i*0.05
		if wake.push_at(h+Vector2(-d,0.3)).y > 0.2: back = d
	check(back > 1.5,"The wake trails %.1f m behind him, not just a ring at his feet" % back)
	check(wake.push_at(h+Vector2(-1.0,1.5)) == Vector3.ZERO,"Off to the side nothing moves")
	var box: Vector4 = wake.published[PilotWake.POINTS]
	check(box.x < h.x-2.0 and box.z > h.x and box.y < -0.5 and box.w > 0.5,"The box holds his path")
	wake.free()

func _walk_and_run() -> void:
	var walk := _wake()
	var run_wake := _wake()
	var near := Vector2(0.0,0.3)
	var far := Vector2(0.0,0.75)
	var seen := {"walk_near":0.0,"walk_far":0.0,"run_near":0.0,"run_far":0.0}
	_go(walk,Vector3(-4.0,0,0),PilotWake.WALK,4.0,func(_t: float, _at: Vector3) -> void:
		seen.walk_near = maxf(seen.walk_near,walk.push_at(near).y)
		seen.walk_far = maxf(seen.walk_far,walk.push_at(far).y))
	_go(run_wake,Vector3(-4.0,0,0),PilotWake.RUN,2.0,func(_t: float, _at: Vector3) -> void:
		seen.run_near = maxf(seen.run_near,run_wake.push_at(near).y)
		seen.run_far = maxf(seen.run_far,run_wake.push_at(far).y))
	var walk_near: float = seen.walk_near
	var walk_far: float = seen.walk_far
	var run_near: float = seen.run_near
	var run_far: float = seen.run_far
	check(run_near > walk_near,"A run leans them harder than a walk (%.2f, %.2f)" % [run_near,walk_near])
	check(run_far > 0.15 and run_far > walk_far*1.5,"And reaches wider (%.2f, %.2f at 0.75 m)" % [run_far,walk_far])
	walk.free()
	run_wake.free()

func _stand_jump_land() -> void:
	var motor := Motor.new()
	var wake := _wake(motor)
	for i in range(180): wake.advance(DT,Vector3.ZERO,true,0.0)
	check(wake.push_at(Vector2(0.25,0.0)).x > 0.2,"Standing, he parts a little ring")
	check(wake.push_at(Vector2(0.65,0.0)) == Vector3.ZERO,"Only a little one")
	var stand_lean: float = wake.lean
	# Up in a jump: nothing parted under him.
	motor.grounded = false
	motor.velocity.y = -9.0
	for i in range(30): wake.advance(DT,Vector3.ZERO,true,1.0)
	check(wake.push_at(Vector2(0.25,0.0)).length() < 0.02,"In the air he parts nothing")
	# Down hard.
	motor.grounded = true
	motor.velocity.y = 0.0
	wake.advance(DT,Vector3.ZERO,true,0.0)
	check(wake.kick > 0.3,"A hard landing kicks the ring wider (%.2f)" % wake.kick)
	var peak := 0.0
	var wide := 0.0
	for i in range(12):
		wake.advance(DT,Vector3.ZERO,true,0.0)
		peak = maxf(peak,wake.lean)
		wide = maxf(wide,wake.radius)
	check(peak > stand_lean*1.1 and wide > PilotWake.RADIUS_STAND*1.1,"For a moment (lean %.2f, reach %.2f m)" % [peak,wide])
	wake.free()

func _hidden() -> void:
	var wake := _wake()
	var head := _go(wake,Vector3.ZERO,PilotWake.RUN,1.0)
	var plant := Vector2(head.x-0.3,0.3)
	var before: float = wake.push_at(plant).y
	var back := INF
	for i in range(30):
		wake.advance(DT,head,false)
		back = minf(back,wake.push_at(plant).y)
	check(before > 0.3 and back < 0.0,"Stepped out, where he was springs back (%.2f to %.2f)" % [before,back])
	for i in range(120): wake.advance(DT,head,false)
	var zero := true
	for v: Vector4 in wake.published: zero = zero and v == Vector4.ZERO
	check(zero,"Then the wake is off: the shaders read nothing")
	# Back on somewhere else: a fresh path there, nothing joining the old.
	wake.advance(DT,Vector3(20,0,0),true)
	wake.advance(DT,Vector3(20.05,0,0),true)
	check(wake.push_at(Vector2(10.0,0.0)) == Vector3.ZERO and wake.path.size() <= 1,"Set down elsewhere, the path starts there")
	wake.free()

func _shaders() -> void:
	var surface: Shader = load("res://shaders/reference_surface.gdshader")
	var names: Array = surface.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u.name)
	check(names.has("tread_wobble") and names.has("sway_shape"),"The surface shader compiles with the wake")
	var grass: Shader = load("res://shaders/dense_grass.gdshader")
	check(grass.get_shader_uniform_list().size() > 0,"The meadow's dense grass compiles with it")
	for global in PilotWake.GLOBALS:
		check(global in RenderingServer.global_shader_parameter_get_list(),"%s is a global" % global)
	var material := ShaderMaterial.new()
	material.shader = surface
	Mushroom.dress(material,"fungus-caps",{},"mushroom:fungus-caps")
	check(float(material.get_shader_parameter("tread_wobble")) > 0.0,"Mushrooms wobble in it")
