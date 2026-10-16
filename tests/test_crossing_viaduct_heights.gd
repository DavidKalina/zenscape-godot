extends SceneTree
## The Broken Viaduct high over the void through the real play loop: the
## crossing
## yard's own `_process` frames (not scripted), the pilot driven by Input
## actions (the stick and Space), the gust arrows firing on their own.
##   - Thrown off the piers by a gust arrow, Space after the yard's
##     KNOCK_SAIL opens the sail out of the tumble: he glides, no longer
##     tumbling.
##   - Steered into the nearest updraft, the sail climbs; steered on to the
##     turn platform, he lands on it.
##   - Thrown again and Space never pressed, he falls past the void's floor
##     and is back at the start rim, the fall counted.
##   godot --headless --path . --script tests/test_crossing_viaduct_heights.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
var failures := 0
var study: Node3D
var m: PilotMotor
var c: Node3D
var arrows: Node3D
## How far he falls tumbling before the test opens the sail (m).
const LATE := 15.0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(200.0).timeout.connect(func() -> void: push_error("viaduct heights test timed out"); quit(2))
	Engine.max_fps = 60
	study = load("res://studies/crossing_yard.tscn").instantiate()
	root.add_child(study)
	current_scene = study
	while not study.walk_ready or not study.isle_up: await process_frame
	await physics_frame
	m = study.motor
	c = study.crossing
	arrows = c.arrows
	print("MEASURE void floor %.1f m under the walk top (kill y %.1f), crossing at y %.1f, updrafts %s" % [-c.floor_y(),study.kill_y,c.position.y,c.updrafts()])
	check(m.knock_sail == study.KNOCK_SAIL and PilotMotor.new().knock_sail < 0.0,"The yard turns the sail out of a knock on (%.2f s); the motor's default is off" % m.knock_sail)
	await _sail_out()
	await _no_sail()
	_release()
	print("viaduct heights: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func world(p: Vector3) -> Vector3:
	return c.position+p

func local(p: Vector3) -> Vector3:
	return p-c.position

func _release() -> void:
	for a: StringName in [&"move_forward",&"move_back",&"move_left",&"move_right",&"walk_jump",&"walk_crouch",&"walk_twirl"]:
		Input.action_release(a)

## Placed at the turn platform facing up the piers, the perches' clocks
## reset.
func _put_at_piers() -> Vector2:
	_release()
	var beat: Dictionary = c.beats()[1]
	study.place(world(beat.at),beat.face)
	study.set("_yaw",PilotMotor.facing_of(beat.face))
	for l in arrows.launchers:
		l.air_blast.phase = "idle"
		l.air_blast.cooldown_left = 0.0
		l.air_blast.balls.clear()
		l.air_blast.shocks.clear()
	arrows.hits.clear()
	return beat.face

## Which top his feet stand on, -1 none.
func _top_under(feet: Vector3) -> int:
	var l := local(feet)
	for k in range(c.pier_tops.size()):
		var t: Vector3 = c.pier_tops[k]
		if absf(l.y-t.y) < 0.05 and Vector2(l.x-t.x,l.z-t.z).length() < 1.6: return k
	return -1

## Pumping up the piers (the stick held up them, Space on the platform's
## edge and each landing) till a gust arrow throws him. True thrown.
func _pump_till_thrown() -> bool:
	var face := _put_at_piers()
	var press_left := 0
	var since_press := 99
	var started := false
	for i in range(900):
		study.set("_yaw",PilotMotor.facing_of(face))
		Input.action_press(&"move_forward")
		var on := _top_under(m.feet) if m.grounded else -1
		since_press += 1
		var d := Vector2(local(m.feet).x-c.turn_mid.x,local(m.feet).z-c.turn_mid.z).dot(face)
		if m.grounded and not started and d > c.TURN_PAD.y*0.5-0.4 and press_left == 0:
			press_left = 4
			started = true
		if on >= 0 and press_left == 0 and since_press > 8:
			press_left = 4
			since_press = 0
		if press_left > 0:
			Input.action_press(&"walk_jump")
			press_left -= 1
		else: Input.action_release(&"walk_jump")
		var before: int = arrows.hits.size()
		await process_frame
		if arrows.hits.size() > before and arrows.hits[arrows.hits.size()-1].kind == "thrown":
			_release()
			return true
		if on == c.pier_tops.size()-1: break
	_release()
	return false

## The stick held toward `to` (world, flat): the camera turned that way,
## forward held.
func _steer_to(to: Vector3) -> void:
	var d := Vector2(to.x-m.feet.x,to.z-m.feet.z)
	if d.length() < 0.01: return
	study.set("_yaw",PilotMotor.facing_of(d.normalized()))
	Input.action_press(&"move_forward")

func _sail_out() -> void:
	var thrown := await _pump_till_thrown()
	check(thrown and m.move == "tumble","A gust arrow throws him off the piers, tumbling (%s, move %s)" % [arrows.hits,m.move])
	if not thrown: return
	var hit_at := m.feet
	# Space mashed straight away: no sail before the beat.
	Input.action_press(&"walk_jump")
	await process_frame
	Input.action_release(&"walk_jump")
	await process_frame
	check(m.move == "tumble","Space at once (inside KNOCK_SAIL) opens nothing: still tumbling")
	# A late sail (the beat long past, LATE m fallen): the updraft must
	# win the height back.
	var waited := 0
	while m.move == "tumble" and waited < 600:
		waited += 1
		await process_frame
		if waited*(1.0/60.0) > study.KNOCK_SAIL+0.05 and hit_at.y-m.feet.y > LATE: break
	var drop_before := hit_at.y-m.feet.y
	for k in range(3):
		Input.action_press(&"walk_jump")
		await process_frame
	Input.action_release(&"walk_jump")
	await process_frame
	print("MEASURE sail out: pressed %.2f s after the hit, %.2f m under it; move %s, stunned '%s', velocity %s" % [waited/60.0,drop_before,m.move,m.stunned,m.velocity])
	check(m.move == "sail" and m.stunned == "","Space after the beat (here %.1f m fallen) opens the sail out of the tumble (move %s)" % [drop_before,m.move])
	# Gliding: steered for the nearest updraft, then on to the turn
	# platform once he is over it.
	var drafts: Array = c.updrafts()
	var best: Dictionary = {}
	for d: Dictionary in drafts:
		if d.name.begins_with("turn") and (best.is_empty() or Vector2(world(d.base).x-m.feet.x,world(d.base).z-m.feet.z).length() < Vector2(world(best.base).x-m.feet.x,world(best.base).z-m.feet.z).length()): best = d
	var column: Vector3 = world(best.base)
	var pad: Vector3 = world(c.turn_mid)
	var lowest := m.feet.y
	var rode_from := INF
	var highest_riding := -INF
	var riding_frames := 0
	var tumbled := false
	var landed_on_pad := false
	var going_home := false
	for i in range(60*40):
		if m.move == "tumble": tumbled = true
		if not going_home and m.feet.y > pad.y+3.0 and riding_frames > 30: going_home = true
		_steer_to(pad if going_home else column)
		await process_frame
		if m.sail.riding:
			riding_frames += 1
			if rode_from == INF: rode_from = m.feet.y
			highest_riding = maxf(highest_riding,m.feet.y)
		if rode_from == INF: lowest = minf(lowest,m.feet.y)
		if m.grounded or m.on_ledge():
			# On the platform or the stone at its edge (the far deck's end).
			landed_on_pad = absf((m.feet.y if m.grounded else m.feet.y+m.hang_drop)-pad.y) < 1.0 and Vector2(m.feet.x-pad.x,m.feet.z-pad.z).length() < c.TURN_PAD_RIGHT+1.0
			break
		if m.feet.y < study.kill_y+5.0: break
	_release()
	print("MEASURE updraft %s at %s: glided down to %.1f (local %.1f), rode from %.1f to %.1f (%d frames riding), ended %s (local), grounded %s" % [best.name,local(column),lowest,local(Vector3(0,lowest,0)).y,local(Vector3(0,rode_from,0)).y if rode_from != INF else INF,local(Vector3(0,highest_riding,0)).y,riding_frames,local(m.feet),m.grounded])
	check(not tumbled,"Under the sail he glides, never tumbling again")
	check(riding_frames > 30 and highest_riding-rode_from > LATE,"Sailed into the updraft, it lifts him (%.1f m up while riding)" % (highest_riding-rode_from))
	check(landed_on_pad,"Ridden up and steered on, he lands back at the turn platform (or catches its edge) (%s local, the platform at %s)" % [local(m.feet),c.turn_mid])

func _no_sail() -> void:
	var falls0: int = study.falls
	var thrown := await _pump_till_thrown()
	check(thrown,"Thrown again off the piers (%s)" % [arrows.hits])
	if not thrown: return
	var reset := false
	var lowest := INF
	for i in range(60*15):
		await process_frame
		lowest = minf(lowest,local(m.feet).y)
		if study.falls > falls0:
			reset = true
			break
	var entry: Vector3 = world(c.entry().at)
	print("MEASURE no sail: lowest local %.1f, falls %d -> %d, feet %s (start rim %s), move '%s'" % [lowest,falls0,study.falls,m.feet,entry,m.move])
	check(reset and lowest < c.floor_y()+2.0,"Not sailing, he falls past the void's floor (lowest %.1f, floor %.1f) and the fall is counted (%d)" % [lowest,c.floor_y(),study.falls])
	check(m.feet.distance_to(entry) < 0.5 and m.move != "tumble","He is back at the start rim, on his feet (%s)" % [local(m.feet)])
