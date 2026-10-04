extends SceneTree
## A material cursor's spring (scripts/cursor_motion.gd) stays finite and
## settles under the pointer through long frames: a hitch of 1/20 s (a shader
## compiling) once sent it to infinity, and it never came back.
##   godot --headless --path . --script tests/test_cursor_motion_hitch.gd
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("OK   " if ok else "FAIL ")+label)
	if not ok: failures += 1

func run() -> void:
	var motion = preload("res://scripts/cursor_motion.gd").new()
	var ground := func(_p: Vector2) -> Variant: return 0.0
	var finite := true
	for i in range(400):
		# The pointer jumps about while every frame is a long one.
		var target := Vector3(sin(i*0.7)*6.0,0.0,cos(i*0.3)*6.0)
		motion.advance(0.05,target,false,ground,Vector2.RIGHT)
		finite = finite and motion.tip.is_finite() and motion.tip_velocity.is_finite()
	check(finite,"through 400 frames of 1/20 s the cursor stays finite")
	for i in range(60): motion.advance(0.05,Vector3(2.0,0.0,-3.0),false,ground,Vector2.RIGHT)
	check(Vector2(motion.tip.x,motion.tip.z).distance_to(Vector2(2.0,-3.0)) < 0.01,"and settles under the pointer")
	motion.tip_velocity = Vector2(INF,0.0)
	motion.advance(1.0/60.0,Vector3(1.0,0.0,1.0),false,ground,Vector2.RIGHT)
	check(motion.tip.is_finite(),"a cursor already lost comes back")
	print("RESULT ","PASS" if failures == 0 else "FAIL")
	quit(1 if failures > 0 else 0)
