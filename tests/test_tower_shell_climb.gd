extends SceneTree
## The tower shell's chimney (scripts/ruin_kit_tower.gd) climbed by the real
## motor through the study's input path (studies/tower_shell_study.tscn,
## scripted: the stick and Jump as a player gives them, `tick` stepping
## the motor over the tower's own collision): set down outside the door,
## he walks in, turns to a side wall and jumps at it, then presses Jump
## each time he touches a wall (the stick let go), kicking across the
## shaft and up until he stands on the rim (landed on it, or caught its
## lip and climbed). Each kick gains height; none falls back to the floor.
## Intact and weathered, the back torn open, and a taller shell. Also: the
## shaft's spacing is the kick's arc (it reaches the far wall rising,
## inside WALL_LOCK), and the footprint and door keep the agreed interface.
##   godot --headless --path . --script tests/test_tower_shell_climb.gd
const Tower = preload("res://scripts/ruin_kit_tower.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
## [height, weathered, open side, seed, frames late]: each press on the
## touch, or that many frames after it (a late player's: 0.1 s).
const CASES := [[12.0,0.0,false,1,0],[12.0,0.5,false,2,0],[12.0,1.0,true,3,0],[16.0,0.8,false,4,0],[12.0,0.5,false,5,6]]
## The longest a climb may take (s), from the first wall jump.
const CLIMB_MOST := 8.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("tower shell climb test timed out"); quit(2))
	_interface()
	for c: Array in CASES: await _climb(float(c[0]),float(c[1]),bool(c[2]),int(c[3]),int(c[4]))
	print("tower shell climb: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## The spacing from the kick's arc, and the agreed interface.
func _interface() -> void:
	var t: float = Tower.KICK_TIME
	check(t < PilotMotor.WALL_LOCK and Tower.KICK_ARRIVE_RISE > 0.0,"a kick reaches the far wall inside the lock (%.3f s of %.2f), rising (%.2f m/s)" % [t,PilotMotor.WALL_LOCK,Tower.KICK_ARRIVE_RISE])
	check(Tower.KICK_GAIN > 1.0,"a kick gains %.2f m by the far wall" % Tower.KICK_GAIN)
	var node := Tower.tower_shell(1,0.6)
	var foot: Vector2 = node.get_meta("footprint")
	check(foot.x <= 8.0 and foot.y <= 8.0,"the footprint is within 8 x 8 m (%.2f x %.2f)" % [foot.x,foot.y])
	var mesh := (node.get_node("Mesh") as MeshInstance3D).mesh.get_aabb()
	check(mesh.position.y > -0.5 and mesh.position.x > -4.0 and mesh.end.x < 4.0 and mesh.position.z > -4.0 and mesh.end.z < 4.0,"the stone stands round the origin on its foot: %s" % str(mesh))
	check(is_equal_approx(float(node.get_meta("rim")),Tower.HEIGHT),"the kick walls stand to the height (rim %.2f)" % float(node.get_meta("rim")))
	check((node.get_meta("door") as Vector3).z > 0.0,"the door is on the +Z front")
	node.free()

func _climb(height: float, weathered: float, open: bool, seed_value: int, late: int) -> void:
	var tag := "height %.0f, weathered %.1f%s, seed %d%s" % [height,weathered,", open side" if open else "",seed_value,", pressed %d frames late" % late if late > 0 else ""]
	var study: Node3D = load("res://studies/tower_shell_study.tscn").instantiate()
	study.scripted = true
	study.tower_height = height
	study.tower_weathered = weathered
	study.tower_open = open
	study.tower_seed = seed_value
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	var m: PilotMotor = study.motor
	var tower: Node3D = study.tower
	var shaft: AABB = tower.get_meta("shaft")
	var w := shaft.size.x*0.5
	var rim: float = tower.get_meta("rim")
	# In at the door: walked straight back (-Z) to the shaft's middle.
	var frames := 0
	while m.feet.z > shaft.end.z*0.5 and frames < 300:
		_drive(study,Vector2(0.0,-1.0),false)
		frames += 1
	for i in range(25): _drive(study,Vector2.ZERO,false)
	check(m.grounded and absf(m.feet.y) < 0.05 and absf(m.feet.z) < shaft.end.z*0.6 and absf(m.feet.x) < 0.3,"walked in at the door to the shaft's foot, "+tag+" (feet %s)" % str(m.feet))
	# At the east wall: a few running steps toward it, a jump, the stick
	# held into it.
	var want := Vector2(1.0,0.0)
	for i in range(9): _drive(study,want,false)
	_drive(study,want,true)
	var pressed := true
	var kicks := 0
	var lowest_kick := INF
	var last_kick_y := -INF
	var fell_back := false
	var hung := false
	var on_rim := false
	var vx_was := 0.0
	var clock := 0.0
	var touching := 0
	while clock < CLIMB_MOST:
		var press := false
		if m.hold == "hang":
			hung = true
			press = not pressed
		elif not m.grounded:
			# Touching a wall (heading into it, his feet within its feel) that
			# still stands WALL_TALL over them: Jump. Else the button let go.
			var into := signf(m.velocity.x) == signf(m.feet.x) and absf(m.velocity.x) > 0.5
			var near := w-absf(m.feet.x) <= PilotMotor.WALL_PROBE
			var touch := (m.move == "wall" or (into and near)) and m.feet.y+PilotMotor.WALL_TALL < rim
			touching = touching+1 if touch else 0
			press = touch and touching > late and not pressed
		_drive(study,want,press)
		pressed = press
		clock += DT
		# A kick: his way across turned round in the air.
		if not m.grounded and m.hold == "" and absf(m.velocity.x) > 3.0 and signf(m.velocity.x) != signf(vx_was) and vx_was != 0.0:
			kicks += 1
			if kicks > 1: lowest_kick = minf(lowest_kick,m.feet.y-last_kick_y)
			last_kick_y = m.feet.y
			want = Vector2.ZERO
		if absf(m.velocity.x) > 3.0: vx_was = m.velocity.x
		if kicks > 0 and m.grounded and m.feet.y < 1.0:
			fell_back = true
			break
		if m.grounded and m.hold == "" and m.feet.y > rim-0.7:
			on_rim = true
			break
	check(on_rim and not fell_back,"kicked up the shaft to the rim, "+tag+" (%d kicks, %.2f s, %s, feet %s%s)" % [kicks,clock,"stood on the rim" if on_rim else ("fell back to the floor" if fell_back else "not there"),str(m.feet.snapped(Vector3.ONE*0.01)),", caught the lip" if hung else ""])
	check(kicks >= int(floor((rim-PilotMotor.WALL_TALL-1.0)/Tower.KICK_GAIN*0.9)) and lowest_kick > 0.8,"every kick gained height, "+tag+" (least %.2f m over %d kicks)" % [lowest_kick,kicks])
	study.queue_free()
	await process_frame

func _drive(study: Node3D, want: Vector2, jump: bool) -> void:
	study.script_want = want
	study.script_jump = jump
	study.tick(DT)
