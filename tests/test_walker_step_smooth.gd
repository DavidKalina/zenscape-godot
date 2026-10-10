extends SceneTree
## The game's walker (scripts/wanderer_eye.gd) up and down a stair, headless:
## on the walk-test island (studies/walk_island.tscn) a flight of steps is cut
## into the land (each tread level, each riser one facet row, as the chisel
## leaves them), and the pilot runs and walks up and down it, the camera at
## rest and low behind him. The feet stand each tread in turn and climb each
## riser fast; the figure and the camera are drawn smoothly over it
## (scripts/pilot_step_smooth.gd, the camera's reach eased out): the most a
## frame's rise changes frame to frame stays under 0.02 m for the figure,
## 0.015 m for the camera's height and 0.02 m for its distance, and the
## figure is never drawn more than 0.12 m off the feet.
##   godot --headless --path . --script tests/test_walker_step_smooth.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const MOVES := [&"move_left",&"move_right",&"move_forward",&"move_back"]
const DT := 1.0/60.0
## The flight: STEPS risers of RISER m, TREAD m apart, cut WIDE m either side
## of its line, from the line's foot (t = 0) on up; level land FOOT m before
## it and TOP m past its head.
const STEPS := 6
const RISER := 0.3
const TREAD := 1.0
const WIDE := 2.5
const FOOT := 2.5
const TOP := 2.5
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("walker step smooth test timed out"); quit(2))
	var scene: Node3D = load("res://studies/walk_island.tscn").instantiate()
	scene.places_path = OS.get_temp_dir().path_join("walker-step-test-%d" % Time.get_ticks_usec()).path_join("places.json")
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not scene.walk_ready: await process_frame
	for i in range(30): await process_frame
	var eye: Node = scene.wanderer
	var data: NativeTerrainData = scene._chunk_editor.data
	check(eye.active and not eye.flying,"Walking")
	# The eye is ticked here at a steady DT, so a frame's change is the walk's
	# own, not the headless frame time's.
	eye.set_process(false)
	var line := _stair_line(eye,data,scene.island.start as Vector2)
	check(not line.is_empty(),"Room for a stair near the start")
	if line.is_empty():
		_finish(scene)
		return
	var cut := _cut_stair(data,line)
	print("     stair: %d risers of %.2f m, %.2f m treads, %d land points cut" % [STEPS,RISER,TREAD,cut])
	var from: Vector2 = line.at
	var way: Vector2 = line.way
	var head_y := float(data.ground_height(from+way*(STEPS*TREAD+1.0)))
	var foot_y := float(data.ground_height(from-way))
	check(absf(head_y-foot_y-STEPS*RISER) < 0.02,"The stair rises %.2f m" % (head_y-foot_y))
	var smooth: Variant = eye.get("step_smooth")
	# At rest the camera stands well over the stair; low (looked up past
	# him) the stair behind draws it in, at once (it must never stand in the
	# ground), and lets it out again smoothly.
	var worst := {"feet":0.0,"figure":0.0,"camera":0.0,"distance":0.0,"off":0.0,"low_camera":0.0,"low_distance":0.0,"low_out":0.0,"drawn_in":0.0}
	for pace: float in [0.5,1.0]:
		for up: bool in [true,false]:
			for low: bool in [false,true]:
				var polar: float = 1.45 if low else eye.CAM_POLAR
				var dir := way if up else -way
				var start := from-way*2.0 if up else from+way*(STEPS*TREAD+2.0)
				eye.place(Vector3(start.x,0.0,start.y))
				eye._yaw = atan2(-dir.x,-dir.y)+eye._turn()
				eye._polar = polar
				eye._stand_camera()
				for i in range(40): await _tick(eye,Vector2.ZERO,0.0)
				var series := {"feet":[],"figure":[],"camera":[],"distance":[]}
				var climbed := false
				for f in range(600):
					eye._polar = polar
					await _tick(eye,dir,pace)
					var feet: Vector3 = eye.motor.feet
					var t := (Vector2(feet.x,feet.z)-from).dot(way)
					if (up and t > STEPS*TREAD+1.5) or (not up and t < -1.5):
						climbed = true
						break
					if t < -1.0 or t > STEPS*TREAD+1.0: continue
					series.feet.append(feet.y)
					series.figure.append(eye.figure.position.y)
					var out: Vector3 = eye._offset(eye._yaw,eye._polar)
					series.camera.append(float(eye._cam_y)+out.y*float(eye._cam_distance))
					series.distance.append(float(eye._cam_distance))
					worst.off = maxf(worst.off,absf(eye.figure.position.y-feet.y))
					worst.drawn_in = maxf(worst.drawn_in,eye.CAM_DISTANCE-float(eye._cam_distance))
				check(climbed and eye.active and not eye.flying,"%s the stair at %s, camera %s" % ["Up" if up else "Down","a run" if pace > 0.75 else "a walk","low" if low else "at rest"])
				for key: String in series:
					var a: Array = series[key]
					var into: String = ("low_"+key) if low and key in ["camera","distance"] else key
					for k in range(2,a.size()):
						var jerk := absf((a[k]-a[k-1])-(a[k-1]-a[k-2]))
						worst[into] = maxf(worst[into],jerk)
						# Let out: the reach growing (or still) both frames.
						if key == "distance" and a[k]-a[k-1] >= 0.0 and a[k-1]-a[k-2] >= 0.0: worst.low_out = maxf(worst.low_out,jerk)
	_push(eye,Vector2.ZERO,0.0)
	print("     stair, the most a frame's rise changes frame to frame (m): feet %.3f, figure %.4f, camera %.4f, camera's distance %.4f; figure off the feet at most %.3f m%s" % [worst.feet,worst.figure,worst.camera,worst.distance,worst.off,"" if smooth != null else " (no smoothing)"])
	print("     camera low: height %.4f, distance %.4f, letting out %.4f; drawn in at most %.2f m" % [worst.low_camera,worst.low_distance,worst.low_out,worst.drawn_in])
	check(worst.feet > 0.03,"The feet climb each riser fast (%.3f m a frame squared)" % worst.feet)
	check(worst.figure < 0.02,"The figure climbs smoothly (%.4f m a frame squared)" % worst.figure)
	check(worst.camera < 0.015,"The camera rises smoothly (%.4f m a frame squared)" % worst.camera)
	check(worst.distance < 0.02,"The camera's reach changes smoothly (%.4f m a frame squared)" % worst.distance)
	check(worst.drawn_in > 1.0,"Low, the stair behind draws the camera in (%.2f m)" % worst.drawn_in)
	check(worst.low_out < 0.02,"And it lets out again smoothly (%.4f m a frame squared)" % worst.low_out)
	check(worst.off < 0.12,"The figure drawn near the feet (at most %.3f m off)" % worst.off)
	await _resets(eye,data,line)
	_finish(scene)

## Set down, landed or stepped in, the figure is drawn at the feet at once:
## the smoothing never lags a teleport.
func _resets(eye: Node, data: NativeTerrainData, line: Dictionary) -> void:
	var from: Vector2 = line.at
	var way: Vector2 = line.way
	# Running up the stair, then set down at its foot mid-stride.
	var start := from-way*2.0
	eye.place(Vector3(start.x,0.0,start.y))
	for i in range(60): await _tick(eye,way,1.0)
	var foot := from-way*1.5
	eye.place(Vector3(foot.x,0.0,foot.y))
	check(absf(eye.figure.position.y-eye.motor.feet.y) < 0.001,"Set down, drawn at the feet at once (%.3f m off)" % (eye.figure.position.y-eye.motor.feet.y))
	await _tick(eye,Vector2.ZERO,0.0)
	check(absf(eye.figure.position.y-eye.motor.feet.y) < 0.01,"And the next frame (%.3f m off)" % (eye.figure.position.y-eye.motor.feet.y))
	for i in range(60): await _tick(eye,way,1.0)
	eye.leave()
	eye.enter()
	eye.set_process(false)
	check(absf(eye.figure.position.y-eye.motor.feet.y) < 0.001,"Stepped out and in, drawn at the feet (%.3f m off)" % (eye.figure.position.y-eye.motor.feet.y))
	await _tick(eye,Vector2.ZERO,0.0)
	check(absf(eye.figure.position.y-eye.motor.feet.y) < 0.01,"And the next frame (%.3f m off)" % (eye.figure.position.y-eye.motor.feet.y))

func _finish(scene: Node) -> void:
	print("PASS: walker step smooth" if failures == 0 else "FAIL: walker step smooth (%d)" % failures)
	scene.queue_free()
	for i in range(10): await process_frame
	quit(1 if failures else 0)

func _tick(eye: Node, way: Vector2, strength: float) -> void:
	_push(eye,way,strength)
	await process_frame
	eye._advance_eye(DT)

## A line from near `near` with room for the stair: on the land all along,
## nothing standing within WIDE of it, away from the shore.
## {"at" (its foot), "way"}, or {}.
func _stair_line(eye: Node, data: NativeTerrainData, near: Vector2) -> Dictionary:
	for ring in range(0,14):
		for k in range(16):
			var at := near+Vector2.from_angle(TAU*k/16.0)*ring*1.5
			for j in range(16):
				var way := Vector2.from_angle(TAU*j/16.0)
				if _clear(eye,data,at,way): return {"at":at,"way":way}
	return {}

func _clear(eye: Node, data: NativeTerrainData, at: Vector2, way: Vector2) -> bool:
	var side := Vector2(-way.y,way.x)
	var t := -FOOT-1.0
	while t <= STEPS*TREAD+TOP+1.0:
		for s in [-1.0,0.0,1.0]:
			var p: Vector2 = at+way*t+side*s
			if not data.has_land(p) or eye._blocked(p) or data.ground_height(p) == null: return false
			if eye._depth(p) > 0.0: return false
		t += 0.5
	# Not by the rim.
	for s in [-WIDE-1.0,WIDE+1.0]:
		if not data.has_land(at+side*s): return false
	return true

## Each land point along the line is set to its tread's level: the level of
## the ground at the line's foot, plus a riser for each step passed.
func _cut_stair(data: NativeTerrainData, line: Dictionary) -> int:
	var at: Vector2 = line.at
	var way: Vector2 = line.way
	var side := Vector2(-way.y,way.x)
	var base := float(data.ground_height(at))
	var cut := 0
	for i in range(data.points.size()):
		var d: Vector2 = data.points[i]-at
		var t := d.dot(way)
		if absf(d.dot(side)) > WIDE or t < -FOOT or t > STEPS*TREAD+TOP: continue
		data.heights[i] = base+RISER*clampf(floorf(t/TREAD)+1.0,0.0,STEPS) if t >= 0.0 else base
		cut += 1
	return cut

## The stick pushed `strength` the world way `way` (x, z), through the
## walker's own reading of it against the camera.
func _push(eye: Node, way: Vector2, strength: float) -> void:
	for move in MOVES: Input.action_release(move)
	if strength <= 0.0: return
	var forward := PilotMotor.forward(eye._yaw-eye._turn())
	var right := Vector2(-forward.y,forward.x)
	var x := way.normalized().dot(right)*strength
	var y := way.normalized().dot(forward)*strength
	if absf(x) > 0.01: Input.action_press(&"move_right" if x > 0.0 else &"move_left",absf(x))
	if absf(y) > 0.01: Input.action_press(&"move_forward" if y > 0.0 else &"move_back",absf(y))
