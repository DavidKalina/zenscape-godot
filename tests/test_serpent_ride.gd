extends SceneTree
## The serpent ride (studies/serpent_ride.tscn), headless, the pilot driven
## by scripted input: stood still mid-back, he stays on it a whole lap of
## its way, drifting next to nothing on the body (no skating, no sinking);
## run from its neck to its tail and back, he stays on; jumped straight up
## at places round its way (straights, curves, the slalom, the dive), he
## comes back down on it; walked off its side he falls, the view fades, and
## he is set back on its back, the fall counted; crouched on its back in
## the dive, he surfs down it, gaining speed; from the start tower, a
## jump timed as it passes lands him on it. F1 shows the ride's numbers.
##   godot --headless --path . --script tests/test_serpent_ride.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const Ride = preload("res://studies/serpent_ride.gd")
const DT := 1.0/60.0
## Stood still a lap: the most he may drift on the body (m), and the most
## his place on it may move in one frame (m).
const DRIFT := 0.05
const SKATE := 0.002
## The camera, a frame, while he stands: the most it may turn (rad) and its
## place round his feet may move (m).
const CAM_TURN_MOST := 0.02
const CAM_SHIFT_MOST := 0.15
## Down its back in the dive, crouched: the least gain in 1.5 s (m/s).
const SURF_GAIN := 5.0
var failures := 0
var study: Node3D
var m: PilotMotor
var serpent: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("serpent ride test timed out"); quit(2))
	study = load("res://studies/serpent_ride.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	serpent = study.serpent
	check(serpent != null and serpent.route == Ride.RIDE_ROUTE,"The real serpent flies the ride's own way (%.0f m round)" % serpent.route_length)
	check(study.riding_on == "still" and m.feet.distance_to(study.tower_top) < 0.1,"He starts on the start tower, the serpent coming")
	_stands_a_lap()
	_runs_its_length()
	_jumps()
	_off_the_side()
	_surfs_the_dive()
	_boards_from_the_tower()
	_hud()
	print("serpent ride: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## The serpent set down with its head at route arc `at`, him on its back
## at arc `a`.
func _set_on(at: float, a: float) -> void:
	serpent.place(fposmod(at,serpent.route_length))
	study.back.reset()
	study.set_on_back(a)
	_input(Vector2.ZERO,false,false)

func _input(want: Vector2, jump: bool, crouch: bool) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch

## The stick along its back toward its tail (or its head), and back toward
## its spine when he is off it.
func _along(to_tail: bool) -> Vector2:
	var a: float = study.anchor.x
	var way: Vector2 = study.back.ahead(a)*(-1.0 if to_tail else 1.0)
	var x: Vector3 = study.back.frame(a).basis.x
	var across := Vector2(x.x,x.z).normalized()
	return (way-across*clampf(float(study.anchor.y)*0.8,-0.6,0.6)).normalized()

func _stands_a_lap() -> void:
	_set_on(serpent.marks()["tower"],Ride.MID_AT)
	var from: Vector3 = study.anchor
	var flown := 0.0
	var last: float = serpent.travelled
	var off := 0
	var skate := 0.0
	var sink := 0.0
	var was: Vector3 = study.anchor
	var ticks := 0
	var t0 := Time.get_ticks_msec()
	# The camera: its turn and its place round him a frame, and whether it
	# is ever inside the body.
	var cam: Camera3D = study.camera
	var look := _flat_angle(-cam.global_basis.z)
	var offset := cam.global_position-m.feet
	var cam_turn := 0.0
	var cam_shift := 0.0
	var inside := 0
	var probe := PhysicsPointQueryParameters3D.new()
	while flown < serpent.route_length and ticks < 20000:
		study.tick(DT)
		ticks += 1
		flown += serpent.travelled-last
		last = serpent.travelled
		if study.riding_on != "serpent": off += 1
		skate = maxf(skate,Vector2(study.anchor.x-was.x,study.anchor.y-was.y).length())
		was = study.anchor
		var under: float = study.ground.height_from(Vector2(m.feet.x,m.feet.z),m.feet.y)
		sink = maxf(sink,absf(m.feet.y-under))
		var now_look := _flat_angle(-cam.global_basis.z)
		cam_turn = maxf(cam_turn,absf(wrapf(now_look-look,-PI,PI)))
		look = now_look
		cam_shift = maxf(cam_shift,(cam.global_position-m.feet).distance_to(offset))
		offset = cam.global_position-m.feet
		probe.position = cam.global_position
		for hit: Dictionary in study.ground.space.intersect_point(probe,4):
			if hit.rid == study.back.rid(): inside += 1
	var drift: Vector3 = study.anchor-from
	print("MEASURE stood still a lap: %.0f m flown in %d frames (%.2f ms a frame), off it %d frames, drift %.4f m along, %.4f across, %.4f up; most a frame moved on it %.5f m; feet off its skin at most %.4f m; falls %d" % [flown,ticks,float(Time.get_ticks_msec()-t0)/ticks,off,drift.x,drift.y,drift.z,skate,sink,study.falls])
	check(off == 0 and study.falls == 0,"Stood still mid-back, he stays on it the whole lap (%.0f m, %d frames off)" % [flown,off])
	check(Vector2(drift.x,drift.y).length() < DRIFT and absf(drift.z) < DRIFT,"He drifts next to nothing on the body over the lap (%.4f m along, %.4f across)" % [drift.x,drift.y])
	check(skate < SKATE and sink < 0.01,"No skating or sinking: at most %.5f m on the body in a frame, feet within %.4f m of its skin" % [skate,sink])
	print("MEASURE the camera standing a lap: most it turned in a frame %.4f rad, most its place round him moved in a frame %.3f m, frames inside the body %d" % [cam_turn,cam_shift,inside])
	check(cam_turn < CAM_TURN_MOST and cam_shift < CAM_SHIFT_MOST,"The camera sways with the body, never snapping (at most %.4f rad and %.3f m a frame)" % [cam_turn,cam_shift])
	check(inside == 0,"The camera is never inside its body")

## The flat angle of `way`.
func _flat_angle(way: Vector3) -> float:
	return atan2(way.x,way.z)

## From the neck to near the tail and back, running along its back.
func _runs_its_length() -> void:
	_set_on(float(serpent.marks()["north"])-60.0,Ride.NECK_AT)
	var falls: int = study.falls
	var reached_tail := false
	var back_at_neck := false
	var widest := 0.0
	var air := 0
	var t := 0.0
	for i in range(3600):
		_input(_along(not reached_tail),false,false)
		study.tick(DT)
		t += DT
		if study.riding_on == "serpent": widest = maxf(widest,absf(study.anchor.y))
		else: air += 1
		if not reached_tail and study.anchor.x >= Ride.TAIL_AT-1.0: reached_tail = true
		if reached_tail and study.anchor.x <= Ride.NECK_AT+1.0:
			back_at_neck = true
			break
	_input(Vector2.ZERO,false,false)
	print("MEASURE run neck to tail and back: %.1f s, %d frames off it, widest off the spine %.2f m (back's half width %.2f), falls %d" % [t,air,widest,study.back.half_width(Ride.MID_AT),study.falls-falls])
	check(reached_tail and back_at_neck and study.falls == falls,"Run from its neck to its tail and back, he stays on (%.1f s)" % t)

## Straight up, no stick, at places round its way: down on it again each
## time, about where he left.
func _jumps() -> void:
	var places := ["tower","dive","bottom","climb","north","pillars","arch","south"]
	var landed := 0
	var worst := 0.0
	var notes := PackedStringArray()
	for place: String in places:
		_set_on(float(serpent.marks()[place])+30.0,Ride.MID_AT)
		for i in range(30): study.tick(DT)
		var from: Vector3 = study.anchor
		var falls: int = study.falls
		var up := false
		var air := 0.0
		for i in range(240):
			_input(Vector2.ZERO,i < 15,false)
			study.tick(DT)
			if study.riding_on == "air":
				up = true
				air += DT
			elif up: break
		_input(Vector2.ZERO,false,false)
		var on: bool = up and study.riding_on == "serpent" and study.falls == falls
		var miss := Vector2(study.anchor.x-from.x,study.anchor.y-from.y)
		if on:
			landed += 1
			worst = maxf(worst,miss.length())
		notes.append("%s %s %.2fs (%+.2f along, %+.2f across)" % [place,"on" if on else "OFF",air,miss.x,miss.y])
	print("MEASURE straight-up jumps: %s" % ", ".join(notes))
	check(landed == places.size(),"Jumped straight up at %d places round its way, he comes down on it every time (%d), at most %.2f m from where he left" % [places.size(),landed,worst])

## Walked off its side: falls, fades, is set back on its back.
func _off_the_side() -> void:
	_set_on(float(serpent.marks()["south"])+20.0,Ride.MID_AT)
	var falls: int = study.falls
	var fell := false
	var faded := false
	var t := 0.0
	for i in range(600):
		var x: Vector3 = study.back.frame(study.anchor.x).basis.x
		_input(Vector2(x.x,x.z).normalized() if not fell else Vector2.ZERO,false,false)
		study.tick(DT)
		t += DT
		if study.riding_on == "air": fell = true
		if study.fading(): faded = true
		if faded and not study.fading(): break
	_input(Vector2.ZERO,false,false)
	print("MEASURE off the side: fell %s, faded %s, set back after %.2f s, on %s at %.1f m, falls %d" % [fell,faded,t,study.riding_on,study.anchor.x,study.falls-falls])
	check(fell and faded and study.falls == falls+1,"Walked off its side he falls, and the fall is counted")
	check(study.riding_on == "serpent" and absf(study.anchor.y) < 0.3,"He is set back on its back after a short beat (%.2f s)" % t)

## Crouched on its back in the dive: surfing down it, faster and faster.
func _surfs_the_dive() -> void:
	# Its middle on the dive's straight: its head 95 m on from the mark.
	var dive: float = serpent.marks()["dive"]
	_set_on(dive+95.0,Ride.MID_AT)
	for i in range(10): study.tick(DT)
	var slope: float = m.steepness()
	var paces := []
	var surfed := 0
	for i in range(120):
		_input(Vector2.ZERO,false,true)
		study.tick(DT)
		if m.move == "slide": surfed += 1
		if i%30 == 29: paces.append(snappedf(m.speed(),0.01))
	_input(Vector2.ZERO,false,false)
	print("MEASURE surf the dive: slope %.1f°, paces on its back %s (each 0.5 s), %d frames surfing, at %.1f m from the snout, on %s" % [slope,paces,surfed,study.anchor.x,study.riding_on])
	check(slope > PilotMotor.SLIDE_FROM and paces.size() == 4 and float(paces[2]) > SURF_GAIN and float(paces[2]) > float(paces[0]),"Crouched on its back in the dive (%.0f°), he surfs down it gaining speed (%s m/s)" % [slope,paces])

## From the tower, run and jump as its back goes by: on.
func _boards_from_the_tower() -> void:
	study.go_to(4)
	var tower: Vector3 = study.tower_top
	var went := false
	var held := 0.0
	for i in range(900):
		# Its middle alongside: go.
		var near: Vector3 = study.back.locate(tower)
		if not went and near.x > 30.0 and near.x < 50.0: went = true
		var to: Vector2 = study.tower_out if went else Vector2.ZERO
		var edge := Vector2(m.feet.x-tower.x,m.feet.z-tower.z).dot(study.tower_out) > Ride.TOWER_HALF-0.4
		# Jump at the edge, held 0.3 s (let go at once, the jump is cut low).
		if went and edge and m.grounded and held == 0.0: held = 0.3
		_input(to,held > 0.0,false)
		held = maxf(held-DT,0.0) if held > 0.0 and not m.grounded else held
		study.tick(DT)
		if study.riding_on == "serpent": break
	_input(Vector2.ZERO,false,false)
	for i in range(30): study.tick(DT)
	print("MEASURE boarding from the tower: on %s at %.1f m from the snout, %+.2f across" % [study.riding_on,study.anchor.x,study.anchor.y])
	check(study.riding_on == "serpent","From the tower, a running jump as its back goes by lands him on it")

func _hud() -> void:
	study._hud.visible = true
	study._show_hud()
	var text: String = study._hud.text
	check(text.contains("over the ground") and text.contains("on its back") and text.contains("serpent") and text.contains("falls") and text.contains("slope"),"F1 shows his speed over the ground and on its back, its speed, what he's on, falls and the slope")
