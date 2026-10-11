extends SceneTree
## How far a swing rope's release reaches (docs/design/foot-interactables.md,
## round 2), headless, in the interactables yard: on its first rope, pumped
## to full swing, let go on the forward upswing at a sweep of angles, then
## in the air nothing (plain), the twirl (X at the top of the arc) or the
## sail (Space again at the top). For each, the furthest a second rope of
## the same length, hung plumb from the same height, could stand and still
## be caught (SwingRope `try_catch`'s test on his flight), in metres from
## the first rope's anchor along the swing.
##   godot --headless --path . --script tools/measure_rope_reach.gd [-- --lengths=6.6,4.2]
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const DT := 1.0/60.0
var study: Node3D
var m: PilotMotor

func _initialize() -> void:
	run.call_deferred()

func tick(want: Vector2, jump := false, twirl := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_twirl = twirl
	study.tick(DT)

func run() -> void:
	study = load("res://studies/interactables_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	var pieces: Node3D = study.pieces
	var rope: Node3D = pieces.ropes[0]
	# Only the first rope catches.
	pieces.ropes = [rope]
	var lengths := [float(rope.length)]
	for a in OS.get_cmdline_user_args(): if a.begins_with("--lengths="):
		lengths = Array(a.get_slice("=",1).split(",")).map(func(t: String) -> float: return float(t))
	for length: float in lengths:
		rope.length = length
		for mode: String in ["plain","twirl","sail"]:
			report(rope,mode)
	quit()

func report(rope: Node3D, mode: String) -> void:
		var best := 0.0
		var best_angle := 0.0
		for angle: float in [0.3,0.45,0.6,0.75,0.9,1.05,1.2]:
			var reach := fly(rope,angle,mode)
			if reach > best:
				best = reach
				best_angle = angle
		print("REACH %-10s %.1f m (let go %.0f° past plumb), rope %.1f m long" % [mode,best,rad_to_deg(best_angle),rope.length])

## Taken hold of, pumped 6 s, let go past `angle` on the forward upswing,
## flown with `mode`: the furthest rope caught.
func fly(rope: Node3D, angle: float, mode: String) -> float:
	study.place(Vector3(6.0,0.0,1.0),Vector2(0.0,-1.0))
	tick(Vector2.ZERO)
	rope._cool = 0.0
	rope.hands = rope.anchor+Vector3.DOWN*rope.length
	rope.velocity = Vector3.ZERO
	m.grounded = false
	m.velocity = Vector3(0.0,0.0,-4.8)
	rope._take(m,rope.anchor+Vector3.DOWN*rope.length)
	for i in range(360): tick(Vector2(0.0,-1.0) if rope.velocity.z <= 0.0 else Vector2(0.0,1.0))
	for i in range(240):
		var a: float = (rope.hands-rope.anchor).angle_to(Vector3.DOWN)
		if rope.hands.z < rope.anchor.z and rope.velocity.z < 0.0 and a > angle: break
		tick(Vector2(0.0,-1.0) if rope.velocity.z <= 0.0 else Vector2(0.0,1.0))
	tick(Vector2(0.0,-1.0),true)
	var flight: Array = []
	var done := false
	for i in range(600):
		var at_top := m.velocity.y <= 0.0 and not done
		var jump := mode == "sail" and at_top
		var twirl := mode == "twirl" and at_top
		if at_top: done = true
		tick(Vector2(0.0,-1.0),jump,twirl)
		flight.append([m.feet,m.facing])
		if m.grounded or m.feet.y < rope.anchor.y-rope.length-4.0: break
	var far := 0.0
	var d := 1.0
	while d < 40.0:
		if caught(rope,flight,d): far = d
		d += 0.1
	return far

## Whether a rope like `rope`, `d` m on along -z, catches him on `flight`.
func caught(rope: Node3D, flight: Array, d: float) -> bool:
	var a: Vector3 = rope.anchor+Vector3(0.0,0.0,-d)
	var low: Vector3 = a+Vector3.DOWN*float(rope.length)*SwingRope.GRIP_HIGH
	var end: Vector3 = a+Vector3.DOWN*float(rope.length)
	for f: Array in flight:
		var feet: Vector3 = f[0]
		var fw := PilotMotor.forward(float(f[1]))
		var hand := feet+Vector3.UP*PilotMotor.HANG_DROP+Vector3(fw.x,0.0,fw.y)*(PilotMotor.HANG_OUT+0.03)
		if hand.distance_to(Geometry3D.get_closest_point_to_segment(hand,low,end)) <= SwingRope.CATCH: return true
		var chest := feet+Vector3.UP*SwingRope.CHEST
		if chest.distance_to(Geometry3D.get_closest_point_to_segment(chest,low,end)) <= SwingRope.CATCH_BODY: return true
	return false
