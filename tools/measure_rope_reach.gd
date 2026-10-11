extends SceneTree
## How far a swing rope's release reaches (docs/design/foot-interactables.md,
## round 2), headless, in the interactables yard: on its first rope, pumped
## to full swing, let go on the forward upswing at a sweep of angles, then
## in the air nothing (plain), the twirl (X at the top of the arc) or the
## sail (Space again at the top). For each, the furthest a second rope of
## the same length, hung plumb from the same height, could stand and still
## be caught (SwingRope `try_catch`'s test on his flight), in metres from
## the first rope's anchor along the swing. Each is given for the best
## release angle (a well-timed release, the boost's whole) and for badly
## timed ones, let go early (17° past the plumb) or late (69°): little of
## the boost. --set=t_boost=4,...
## overrides SwingRope's live `t_*` first; --curve prints every angle.
## "lands" is where he comes down to ground KNOT m under the rope's end
## (its knot at a standing walker's hands), in metres from the anchor.
##   godot --headless --path . --script tools/measure_rope_reach.gd [-- --lengths=6.6,4.2] [--set=t_boost=6] [--curve]
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const DT := 1.0/60.0
## The ground under a rope's knot (m): the knot at a standing walker's hands.
const KNOT := 0.9
var study: Node3D
var m: PilotMotor
var curve := false
## The last flight's landing (m from the anchor), `fly`.
var _landed := 0.0

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
	# Only the first rope catches, moved out into open sky east of the
	# yard, so no frame or deck is in his way.
	pieces.ropes = [rope]
	rope.anchor = Vector3(80.0,rope.anchor.y,-3.8)
	var lengths := [float(rope.length)]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lengths="):
			lengths = Array(a.get_slice("=",1).split(",")).map(func(t: String) -> float: return float(t))
		if a == "--curve": curve = true
		if a.begins_with("--set="):
			for kv: String in a.trim_prefix("--set=").split(","):
				var script: Script = SwingRope
				script.set(kv.get_slice("=",0),float(kv.get_slice("=",1)))
	for length: float in lengths:
		rope.length = length
		for mode: String in ["plain","twirl","sail"]:
			report(rope,mode)
	quit()

func report(rope: Node3D, mode: String) -> void:
		var best := 0.0
		var best_angle := 0.0
		var best_land := 0.0
		var line := PackedStringArray()
		var early := []
		var late := []
		for angle: float in [0.3,0.45,0.6,0.75,0.9,1.05,1.2]:
			var reach := fly(rope,angle,mode)
			line.append("%.0f°:%.1f/%.1f" % [rad_to_deg(angle),reach,_landed])
			if angle == 0.3: early = [reach,_landed]
			if angle == 1.2: late = [reach,_landed]
			best_land = maxf(best_land,_landed)
			if reach > best:
				best = reach
				best_angle = angle
		print("REACH %-6s best %.1f m, lands %.1f (let go %.0f° past plumb, timing %.2f); early %.1f, lands %.1f; late %.1f, lands %.1f; rope %.1f m long" % [mode,best,best_land,rad_to_deg(best_angle),_timing_at(best_angle),early[0],early[1],late[0],late[1],rope.length])
		if curve: print("      "+" ".join(line))

## The timing SwingRope gives a rising release `a` rad past the plumb.
func _timing_at(a: float) -> float:
	var x := (a-SwingRope.t_best)/maxf(SwingRope.t_window,0.01)
	return clampf(1.0-x*x,0.0,1.0)

## Taken hold of, pumped 6 s, let go past `angle` on the forward upswing,
## flown with `mode`: the furthest rope caught.
func fly(rope: Node3D, angle: float, mode: String) -> float:
	study.place(Vector3(rope.anchor.x,0.0,1.0),Vector2(0.0,-1.0))
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
		if m.grounded or m.feet.y < rope.anchor.y-rope.length-KNOT-0.5: break
	_landed = 0.0
	var ground: float = rope.anchor.y-rope.length-KNOT
	for f: Array in flight:
		var p: Vector3 = f[0]
		if p.y <= ground:
			_landed = rope.anchor.z-p.z
			break
	var far := 0.0
	var d := 1.0
	while d < 60.0:
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
