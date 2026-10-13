extends SceneTree
## The giants (scripts/traps/trap_tumble.gd, trap_ray.gd) in the trap yard,
## headless, the pilot driven by scripted input:
##   - the Tumbling Block (through the real play loop: input actions, the
##     study's own frames) is a giant over open void; standing still he is
##     slid off into the void within one rhythm; its lurch throws a rider
##     near the leading edge; a station-keeper who never jumps the lurch is
##     thrown at the first face change (it can't be walked); a skilled
##     rider (uphill, hops, jumps each lurch) rides several and takes the
##     prize; the pocket carries him through a lurch to a step he hops up
##     from;
##   - the Sky Ray, flying its real schedule through the yard's own frame
##     (study.tick, the pilot's motor, the trap field): its path runs from
##     the start deck to a far deck; it carries a pilot along it; standing
##     still through its hardest bank he slides off its back within a couple
##     of seconds; a rider who holds the middle, leaning uphill, and catches
##     a handhold for the big roll rides from the start deck to the far deck;
##     in a dive's plunge he leaves its back and lands on it again; slid
##     slowly off its rim, leaning in, he catches the rim and hangs, carried;
##     a careful rider jumps on from the start deck's edge while it waits,
##     rides, and jumps off onto the far deck while it waits there; and,
##     through the real play loop with the stick pressed as input actions,
##     through the big roll a rider holding toward the high wing catches a
##     handhold, hangs from it at vertical carried, shimmies along it and is
##     back on his feet on top as it rolls level, while one who doesn't grab
##     is off before it is vertical.
##   godot --headless --path . --script tests/test_trap_giants.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Trap = preload("res://scripts/traps/trap.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _tick(n: int) -> void:
	for i in range(n):
		study.tick(DT)
		await physics_frame

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("trap giants test timed out"); quit(2))
	study = load("res://studies/trap_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	await physics_frame
	await physics_frame
	# The ray first: the tumble's part runs the yard unscripted (every trap
	# stepped by real frames), the ray's on scripted ticks from a fresh yard.
	await _ray()
	await _tumble()
	print("trap giants: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## The Tumbling Block is played through the real play loop: the study not
## scripted, its own `_process` frames (at the project's frame rate), the
## stick and the jump pressed as input actions, the camera held looking
## along the route (-z) as a player would hold it.
var _jump_left := 0

func _play(way: float, jump: bool) -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"move_back")
	if way < 0.0: Input.action_press(&"move_forward")
	elif way > 0.0: Input.action_press(&"move_back")
	# A fresh press, held a few frames.
	if jump and _jump_left <= -2: _jump_left = 10
	if _jump_left > 0: Input.action_press(&"walk_jump")
	else: Input.action_release(&"walk_jump")
	_jump_left -= 1
	study.set("_yaw",0.0)

func _let_go() -> void:
	for action: StringName in [&"move_forward",&"move_back",&"walk_jump"]: Input.action_release(action)
	_jump_left = 0

## One real frame; its seconds. TRACE=1 prints each.
func _frame() -> float:
	await process_frame
	if OS.get_environment("TRACE") != "":
		var trap: Node3D = study.traps.named("tumble")
		print("  %s %.2f roll %.2f feet %s grounded %s move %s hold %s riding %s pocket %s slide %.2f off %s vel %s stick %s" % [trap.phase,trap.phase_t,trap.roll,(trap.to_local(m.feet)-trap.centre()).snapped(Vector3.ONE*0.01),m.grounded,m.move,m.hold,trap.riding(),trap.in_pocket(m.feet),trap.slide,trap.put_off,m.velocity.snapped(Vector3.ONE*0.01),Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")])
	return study.get_process_delta_time()

## Gone into the void: under the block's middle and not holding it.
func _in_void(trap: Node3D) -> bool:
	return m.feet.y < trap.to_global(trap.centre()).y-0.5 and not trap.riding()

## The block set with the rhythm at `phase`, `phase_t` in, the face at
## roll `base` on top, and him set down at `at` (in the block's own frame;
## the top's middle if INF). The yard's `place` rebuilds the traps, so the
## block is set after it.
func _set_on(trap: Node3D, at := Vector3.INF, phase := "rest", phase_t := 0.0, base := 0.0) -> void:
	_let_go()
	study.place(trap.top_point(),Vector2(0.0,-1.0))
	trap.set("_base",base)
	trap.roll = base
	trap.phase = phase
	trap.phase_t = phase_t
	trap._pose()
	if at != Vector3.INF: m.reset(trap.to_global(trap._transform()*at)+Vector3.UP*0.05,0.0)
	study.set("_yaw",0.0)
	await physics_frame

## A rider for `limit` s: `skill` 0 stands still, 1 keeps station walking
## uphill and hops what blocks him but never jumps the lurch (the face
## change "walked"), 2 also jumps at the end of the shudder (the skilled
## rider) and climbs from a hang. Returns {"t": seconds till the void (or
## limit), "lurches", "worst": the largest frame step past what the stone
## and a fall could make}.
func _ride(trap: Node3D, skill: int, limit: float) -> Dictionary:
	var p := Trap.pilot()
	var size: float = trap.knob("size")
	var rise := sqrt(2.0*float(p.jumps[0])/p.gravity)
	var t := 0.0
	var prev := m.feet
	var worst := 0.0
	var stuck := 0.0
	var last_on := INF
	while t < limit:
		var c: Vector3 = trap.to_global(trap.centre())
		var off := m.feet.z-c.z
		# Up to the middle at rest (the prize is there on face 2), the uphill
		# side as it tips; everything carries him back, so only uphill.
		var target := -size*0.15 if trap.phase == "tip" else 0.0
		var way := 0.0
		var jump := false
		if skill > 0:
			if off > target+0.2: way = -1.0
			# Pressing on and not getting on over the stone: hop it (a bar, a
			# wall, a step).
			var on_stone: float = trap.face_local(trap.top_face(),m.feet).z
			stuck = stuck+1.0/60.0 if way != 0.0 and m.grounded and on_stone > last_on-p.walk*0.3/60.0 else 0.0
			last_on = on_stone
			if stuck > 0.15: jump = true
			if m.hold == "hang": way = signf(-m.lip_out.y)
		if skill > 1 and trap.phase == "tip" and trap.until_lurch() <= rise*0.3 and m.grounded: jump = true
		_play(way,jump)
		var dt := await _frame()
		t += dt
		if not m.recovering():
			worst = maxf(worst,m.feet.distance_to(prev)-(PilotMotor.TERMINAL+absf(trap.lurch_rate())*size)*dt)
		prev = m.feet
		if _in_void(trap): break
	_let_go()
	return {"t":t,"lurches":trap.lurches,"worst":worst}

func _tumble() -> void:
	var trap: Node3D = study.traps.named("tumble")
	var p := Trap.pilot()
	check(trap != null and trap.danger() == 5,"The yard has the Tumbling Block, cost 4 over the void")
	var size: float = trap.knob("size")
	var height: float = preload("res://scripts/pilot_physics_ground.gd").HEAD*preload("res://scripts/world_scale.gd").wanderer
	check(size >= height*6.0,"It reads as a giant: %.1f m a side, %.1f of his heights" % [size,size/height])
	check(trap.open_below(),"...over open void: no floor a layer down in its lane")
	study.scripted = false
	var cycle: float = float(trap.knob("rest"))+float(trap.knob("tip_time"))+float(trap.knob("lurch"))
	var half := size*0.5
	# Standing still at the top's middle, from the start of a rest.
	await _set_on(trap)
	var still := await _ride(trap,0,cycle+6.0)
	check(_in_void(trap) and still.t < cycle+1.5,"Standing still he is slid off and into the void in %.1f s (a rhythm is %.1f s; %s)" % [still.t,cycle,trap.put_off])
	# The lurch throws a rider near the leading edge: on the tipped face a
	# body length in from it as the shudder starts, keeping his place
	# uphill (no jump).
	var shudder: float = float(trap.knob("tip_time"))-float(trap.knob("tell"))
	await _set_on(trap,Vector3(0.0,half,half-height*1.5),"tip",shudder)
	var held := 0.0
	while trap.phase != "rest" and held < 3.0:
		_play(-1.0,false)
		held += await _frame()
	_let_go()
	var thrown_how: String = trap.put_off
	held = 0.0
	while not _in_void(trap) and held < 3.0: held += await _frame()
	check(thrown_how == "thrown" and _in_void(trap),"The lurch throws a rider near the leading edge into the void (%s, %.1f s after)" % [thrown_how,held])
	# Walked, not jumped: a station-keeper who never jumps the lurch.
	await _set_on(trap)
	var walked := await _ride(trap,1,cycle*3.0)
	check(_in_void(trap) and walked.lurches <= 1 and trap.put_off in ["thrown","jolted"],"The face change can't be walked: keeping station without jumping the lurch he is thrown at lurch %d (%.1f s, %s)" % [walked.lurches,walked.t,trap.put_off])
	check(float(trap.knob("bevel")) == 0.0,"...the edges are knife edges at default knobs (bevel %.2f)" % float(trap.knob("bevel")))
	# The skilled rider: station uphill, hops the bar and walls, jumps at
	# the end of each shudder, climbs from a hang.
	await _set_on(trap)
	var rides := 4
	var skilled := await _ride(trap,2,cycle*float(rides)+cycle*0.5)
	check(not _in_void(trap) and skilled.lurches >= rides and trap.on_block(m.feet),"A skilled rider (uphill, hop, jump the lurch) rides %d lurches (%.1f s, %d lurched, thrown %d)" % [rides,skilled.t,skilled.lurches,trap.thrown])
	check(trap.prize_taken,"...and picks up the prize on face 2 as it comes up")
	var ramped: float = trap.pace
	check(ramped > 1.0,"...the pace ramps up as he rides (x%.2f)" % ramped)
	check(skilled.worst < 0.05,"...carried by the stone, never jumped (worst excess step %.3f m)" % skilled.worst)
	var heard: Array = trap.heard.map(func(h: Array) -> String: return String(h[0]))
	check("grind" in heard and "lurch" in heard and "slam" in heard,"...told: a grind in the shudder before each lurch, the lurch, the slam as it stops")
	# The pocket: in it as face 3 tips, he rides the lurch there and is set
	# on the step under the new top's leading lip; a hop and he is up.
	var pl: float = trap.knob("plate")
	var pocket: float = trap.knob("pocket")
	await _set_on(trap,Basis(Vector3.RIGHT,PI*1.5)*Vector3(0.0,half-pl,-half+pocket*0.5),"tip",shudder,PI*0.5)
	held = 0.0
	while trap.phase != "rest" and held < 3.0:
		_play(0.0,false)
		held += await _frame()
	check(trap.riding() and trap.put_off == "" and trap.in_pocket(m.feet),"In the pocket he rides the lurch, not thrown, onto the step it becomes (%s)" % trap.put_off)
	var up := false
	held = 0.0
	while held < 3.0 and not _in_void(trap):
		if m.grounded and trap.face_at(m.feet) == trap.top_face() and not trap.in_pocket(m.feet):
			up = true
			break
		_play(-1.0,m.grounded and absf(m.velocity.z) < p.walk*0.2)
		held += await _frame()
	_let_go()
	check(up,"...and from the step he hops up onto the new top (%.1f s)" % held)
	print("     tumble: still %.1f s; walked %d lurch(es); skilled %d lurches in %.1f s, pace x%.2f" % [still.t,walked.lurches,skilled.lurches,skilled.t,ramped])
	study.scripted = true
	trap.reset()


## On the ray's back at `at` (its frame), the ray at `d` along its loop,
## moving.
func _ray_board(trap: Node3D, d: float, at: Vector3) -> void:
	study.place(trap.to_global(Vector3(trap.line_x(),0.0,0.0)),Vector2(0.0,-1.0))
	trap.set_at(d)
	m.reset(trap.world_of(at),PI)
	study.script_want = Vector2.ZERO
	study.script_jump = false
	await _tick(1)

## The stick (frame x z) that walks `local` (the back's x z) on the ray now.
func _ray_way(trap: Node3D, local: Vector2) -> Vector2:
	var b: Basis = trap.global_transform.basis*trap.body.transform.basis
	var w := b*Vector3(local.x,0.0,local.y)
	return Vector2(w.x,w.z).limit_length(1.0)

## Downhill on the back now (its x z), or zero on the level.
func _ray_down(trap: Node3D) -> Vector2:
	var n: Vector3 = trap.normal()
	var down := Vector3.DOWN-Vector3.DOWN.dot(n)*n
	var b: Basis = trap.global_transform.basis*trap.body.transform.basis
	var dl := b.inverse()*down
	return Vector2(dl.x,dl.z) if Vector2(dl.x,dl.z).length() > 0.05 else Vector2.ZERO

## A rider holding the middle of its back (he is at `l`, its frame): toward
## it (out past a long ridge, along it to the open back between them first),
## leaning uphill on a slope; through a big roll (its tell on), toward the
## high wing, to catch a handhold; holding one, still.
func _ray_keep(trap: Node3D, l: Vector3) -> Vector2:
	if trap.holds_rail(): return Vector2.ZERO
	var big: Dictionary = trap.big_at()
	if not big.is_empty() and big.phase != "out":
		return Vector2(trap._high_side(big.beat),-l.z*0.3).normalized()
	var want := Vector2(-l.x,-l.z)*0.6
	if absf(l.x) > float(trap.knob("width"))*0.3 and absf(l.z) > 0.6: want = Vector2(0.0,-signf(l.z))
	var down := _ray_down(trap)
	if down != Vector2.ZERO: want -= down.normalized()*0.4
	return want

## Still with it: on its back (or over it in a float), or on a handhold.
func _ray_with(trap: Node3D) -> bool:
	if trap.holds_rail(): return true
	var l: Vector3 = trap.local_of(m.feet)
	return absf(l.x) <= float(trap.knob("width"))*0.5+0.3 and absf(l.z) <= float(trap.knob("long"))*0.5+0.3 and l.y >= -0.5

func _ray() -> void:
	var trap: Node3D = study.traps.named("ray")
	check(trap != null and trap.danger() == 5,"The yard has the Sky Ray, cost 4 over the void")
	var v: float = trap.knob("speed")
	var w: float = float(trap.knob("width"))*0.5
	# A ride from A to B: the far stop beside the far deck.
	var far_deck: Vector3 = trap.to_global(Vector3(0.0,0.0,-float(trap.knob("ride"))-4.0))
	var b_point: Vector3 = trap.to_global(trap.path_at(trap.far_stop()))
	check(absf(b_point.z-far_deck.z) < 1.0 and trap.length() > 60.0,"Its path runs from the start deck to a far deck %.0f m off (it stops beside it, %.1f m off its middle)" % [trap.length(),absf(b_point.z-far_deck.z)])
	# Carried along the path, out from the start deck.
	await _ray_board(trap,trap.stop_at(0)+v*3.0,Vector3.ZERO)
	var start: Vector3 = m.feet
	var start_body: Vector3 = trap.body.global_position
	await _tick(180)
	var moved := m.feet.distance_to(start)
	check(trap.on_back(m.feet),"He rides it: still on its back after 3 s (local %s)" % str(trap.local_of(m.feet).snapped(Vector3.ONE*0.01)))
	check(moved > v*3.0*0.8 and trap.body.global_position.distance_to(start_body) > 5.0,"...his world position follows it (moved %.1f m, it moved %.1f)" % [moved,trap.body.global_position.distance_to(start_body)])
	# The moves: the hardest bank, the first dive, the first big roll.
	var hardest := {}
	var dive := {}
	var big := {}
	for beat: Dictionary in trap.beats():
		if (beat.kind == "L" or beat.kind == "R") and (hardest.is_empty() or float(beat.size) > float(hardest.size)): hardest = beat
		if beat.kind == "D" and dive.is_empty(): dive = beat
		if beat.kind == "V" and big.is_empty(): big = beat
	check(not hardest.is_empty() and not dive.is_empty() and not big.is_empty(),"Its path has banks, dives and a big roll (%s, big %d a leg)" % [trap.knob("pattern"),int(trap.knob("big"))])
	# Standing still through the hardest bank: slid off. Clear of the ridges
	# on the low side.
	var low := 1.0 if hardest.kind == "R" else -1.0
	var still_z: float = float(trap.knob("long"))*(-0.2 if low > 0.0 else 0.2)
	var roll_start: float = float(hardest.at)
	await _ray_board(trap,roll_start-v*1.0,Vector3(0.0,0.0,still_z))
	var off_at := -1.0
	var fell := false
	var t := 0.0
	while t < 1.0+float(hardest.long)/v+2.0 and not fell:
		await _tick(1)
		t += DT
		if off_at < 0.0 and not trap.on_back(m.feet) and not trap.holds_rim(): off_at = t-1.0
		fell = off_at >= 0.0 and not m.on_ledge() and trap.local_of(m.feet).y < -1.0
	check(off_at >= 0.0 and off_at < 2.5 and fell,"Standing still through its hardest bank (%.2f rad) he is slid off its back, %.2f s into the roll, and falls (thrown %d)" % [hardest.size,off_at,trap.throws])
	# Holding the middle, leaning uphill, toward the high wing through the big
	# roll: from the start stop to the far one, with it throughout.
	await _ray_board(trap,trap.stop_at(0),Vector3.ZERO)
	var legs: Array = trap.get("_legs")
	var to_far: float = float(trap.knob("dwell"))+float(legs[0].time)
	trap.clock = float(legs[0].start)
	var stayed := true
	var high := 0.0
	var leans := 0
	var held := 0.0
	t = 0.0
	while t < to_far+0.5:
		var l: Vector3 = trap.local_of(m.feet)
		if _ray_down(trap) != Vector2.ZERO: leans += 1
		study.script_want = _ray_way(trap,_ray_keep(trap,l))
		await _tick(1)
		t += DT
		if trap.holds_rail(): held += DT
		if not m.grounded and not trap.holds_rail(): high = maxf(high,trap.local_of(m.feet).y)
		if not _ray_with(trap):
			stayed = false
			break
	study.script_want = Vector2.ZERO
	var at_far: bool = absf(trap.s-trap.far_stop()) < 0.5
	check(stayed and trap.on_back(m.feet) and at_far and leans > 60 and held > 1.0,"Holding the middle, leaning uphill, and catching a handhold for the big roll, he rides from the start deck to the far deck (%.1f s of %.1f, %d floats, %.1f s on a handhold)" % [t,to_far,trap.floats,held])
	# Standing still into a dive: the plunge lifts him off its back, and it
	# pulls up under him.
	await _ray_board(trap,float(dive.at)+float(dive.plunge)-v*0.5,Vector3.ZERO)
	var lifted := 0.0
	var air := 0.0
	t = 0.0
	while t < 2.0:
		await _tick(1)
		t += DT
		if not m.grounded:
			air += DT
			lifted = maxf(lifted,trap.local_of(m.feet).y)
	check(lifted > 0.3 and air > 0.2,"In a dive's plunge he leaves its back: %.2f m clear of it, %.2f s in the air" % [lifted,air])
	check(trap.on_back(m.feet) and m.grounded,"...and it pulls up under him: back on it (local %s)" % str(trap.local_of(m.feet).snapped(Vector3.ONE*0.01)))
	# Slid off the rim slowly, leaning in: the motor's catch takes the rim
	# and he hangs from it, carried with it.
	await _ray_board(trap,roll_start-v*1.0,Vector3(low*(w-1.0),0.0,still_z))
	var hung := 0.0
	var lip_drift := 0.0
	var lip_local := Vector3.INF
	t = 0.0
	# Through the bank, and a while hanging after it.
	while t < 1.0+float(hardest.long)/v+1.5:
		var down := _ray_down(trap)
		study.script_want = _ray_way(trap,-down.normalized()*float(trap.knob("lean_pace"))*0.6/m.run) if down != Vector2.ZERO and m.grounded else Vector2.ZERO
		await _tick(1)
		t += DT
		if m.hold == "hang" and trap.holds_rim():
			hung += DT
			var here: Vector3 = trap.local_of(m.lip)
			if lip_local == Vector3.INF: lip_local = here
			lip_drift = maxf(lip_drift,here.distance_to(lip_local))
	study.script_want = Vector2.ZERO
	check(hung > 0.5 and lip_drift < 0.3,"Slid off its rim leaning in, he catches the rim and hangs, carried (%.2f s hanging, the lip %.2f m off where he took it)" % [hung,lip_drift])
	await _ray_route(trap)
	var rolled := await _ray_big(trap,big)
	print("     ray: hardest bank %.2f rad, still off at %.2f s; to the far deck %.1f s (%.1f on a handhold); dive %.2f m clear for %.2f s; hung %.2f s; %s" % [hardest.size,off_at,to_far,held,lifted,air,hung,rolled])
	study.scripted = true
	_let_go_ray()
	trap.reset()

## The route: on from the start deck's edge while it waits there, ridden
## holding the middle (a handhold through the big roll), off onto the far
## deck while it waits there.
func _ray_route(trap: Node3D) -> void:
	var lane: Vector3 = trap.global_position
	study.place(lane+Vector3(float(trap.knob("edge_x"))-0.4,0.0,float(trap.knob("board_z"))),Vector2(1.0,0.0))
	var legs: Array = trap.get("_legs")
	trap.clock = float(legs[0].start)+0.5
	trap.s = trap.d_at(trap.clock)
	trap._pose()
	await _tick(2)
	var t := 0.0
	var boarded := false
	while t < 3.0 and not boarded:
		study.script_jump = m.grounded and t > 0.2
		study.script_want = Vector2(1.0,0.0)
		await _tick(1)
		t += DT
		boarded = m.grounded and trap.on_back(m.feet)
	study.script_jump = false
	check(boarded,"A careful rider jumps on from the start deck's edge while it waits (local %s)" % str(trap.local_of(m.feet).snapped(Vector3.ONE*0.01)))
	var far: float = -float(trap.knob("ride"))
	var landed := false
	var off := false
	var rim: float = float(trap.knob("width"))*0.5
	var waiting := false
	t = 0.0
	while t < trap.cycle() and boarded:
		var l: Vector3 = trap.local_of(m.feet)
		# Waiting beside the far deck (its -x the deck's side: it flies -z).
		waiting = absf(trap.s-trap.far_stop()) < 0.05
		var want := _ray_keep(trap,l)
		study.script_want = _ray_way(trap,want)
		study.script_jump = false
		if waiting or off:
			study.script_want = Vector2(-1.0,0.0)
			study.script_jump = m.grounded and trap.on_back(m.feet) and l.x < -rim+0.9
		await _tick(1)
		t += DT
		if waiting and not m.grounded and not trap.on_back(m.feet): off = true
		var rel: Vector3 = m.feet-lane
		if off and m.grounded and rel.x < float(trap.knob("edge_x")) and rel.z < far and rel.z > far-8.0:
			landed = true
			break
		if m.feet.y < lane.y-3.0: break
	study.script_want = Vector2.ZERO
	study.script_jump = false
	check(landed,"...rides to the far deck and jumps off onto it while it waits there (%.1f s, at %s)" % [t,str((m.feet-lane).snapped(Vector3.ONE*0.01))])

# ---- the big roll, played through the real play loop: the study not
# scripted, its own frames, the stick pressed as input actions (the camera
# held looking -z, so the stick's x is the frame's x, its y the frame's z) ----

func _stick(way: Vector2) -> void:
	study.set("_yaw",0.0)
	for action: StringName in [&"move_left",&"move_right",&"move_forward",&"move_back"]: Input.action_release(action)
	if way.length() < 0.2: return
	way = way.normalized()
	if way.x > 0.0: Input.action_press(&"move_right",way.x)
	elif way.x < 0.0: Input.action_press(&"move_left",-way.x)
	if way.y > 0.0: Input.action_press(&"move_back",way.y)
	elif way.y < 0.0: Input.action_press(&"move_forward",-way.y)

func _let_go_ray() -> void:
	_stick(Vector2.ZERO)

## The frame way of the back's `local` (x z) now, flattened.
func _flat(trap: Node3D, local: Vector3) -> Vector2:
	var b: Basis = trap.global_transform.basis*trap.body.transform.basis
	var w := b*local
	return Vector2(w.x,w.z)

## Through the big roll from its tell: a rider holding toward the high wing
## catches a handhold, hangs from it at vertical, carried, shimmies along it,
## and is back on his feet on top as it rolls level; one who doesn't grab is
## off before it is vertical. Returns a line for the summary.
func _ray_big(trap: Node3D, big: Dictionary) -> String:
	var v: float = trap.knob("speed")
	var hs: float = trap._high_side(big)
	var roll: float = trap.knob("big_roll")
	var hold: float = trap.knob("big_hold")
	var lead: float = float(trap.knob("big_tell"))+0.5
	# Downhill of the middle rail, a body's width.
	var at := Vector3(-hs*0.6,0.0,0.0)
	await _ray_board(trap,float(big.at)-v*lead,at)
	study.scripted = false
	var t := 0.0
	var vertical := false
	var lip_at := Vector3.INF
	var lip_drift := 0.0
	var tilt_most := 0.0
	var shimmied := 0.0
	var z_was := INF
	var gone := false
	var heard_long := false
	var jump_most := 0.0
	while t < lead+2.0*roll+hold+1.0:
		var phase: String = trap.big_at().get("phase","")
		var into: float = trap.big_at().get("t",-99.0)
		var want := _flat(trap,Vector3(hs,0.0,0.0))
		# Half way through the hold: along the rail a moment (the shimmy).
		if phase == "hold" and into > roll+hold*0.3 and into < roll+hold*0.6:
			want = _flat(trap,Vector3(0.0,0.0,-1.0)).normalized()
			if z_was == INF: z_was = trap.grip_z
			shimmied = absf(trap.grip_z-z_was)
		elif phase == "out" or phase == "": want = Vector2.ZERO
		_stick(want)
		var was_local: Vector3 = trap.local_of(m.feet)
		t += await _frame_ray()
		# Moved with the back, give or take his own shimmy and the ease onto
		# the hang: never jumped.
		jump_most = maxf(jump_most,m.feet.distance_to(trap.world_of(was_local)))
		tilt_most = maxf(tilt_most,trap.tilt())
		if phase == "hold":
			if not vertical and trap.tilt() > float(trap.knob("big_tilt"))-0.1:
				vertical = trap.holds_rail() and m.hold == "hang" and m.rider == trap
			if trap.holds_rail() and m.hold == "hang":
				var here: Vector3 = trap.local_of(m.lip)
				if lip_at == Vector3.INF: lip_at = here
				lip_drift = maxf(lip_drift,Vector2(here.x-lip_at.x,here.y-lip_at.y).length())
		if not _ray_with(trap) and not trap.holds_rim(): gone = true
		if "screech_long" in trap.heard.map(func(h: Array) -> String: return String(h[0])): heard_long = true
	_let_go_ray()
	var top: bool = not gone and m.grounded and trap.on_back(m.feet) and not trap.holds_rail() and trap.local_of(m.feet).y > -0.1
	check(heard_long,"Before the big roll, a long screech (its tell)")
	check(vertical and tilt_most > 1.45,"Holding the stick toward the high wing he catches a handhold and hangs from it at vertical, carried (tilt %.0f deg, grabs %d)" % [rad_to_deg(tilt_most),trap.grabs])
	check(lip_drift < 0.25,"...the hold carried with the ray (his hands %.2f m off the rail across it)" % lip_drift)
	check(jump_most < 0.25,"...no jumps: his feet never more than %.2f m a frame off the back's point under them" % jump_most)
	check(shimmied > 0.15,"...the stick along the rail shimmies him along it (%.2f m)" % shimmied)
	check(top and trap.set_ons >= 1,"...and as it rolls level he is set back on his feet on top (local %s)" % str(trap.local_of(m.feet).snapped(Vector3.ONE*0.01)))
	# Not grabbing: the stick let go, standing in the same place.
	await _ray_board(trap,float(big.at)-v*lead,at)
	t = 0.0
	var off_before := false
	var no_wall := true
	while t < lead+roll+hold*0.5:
		_stick(Vector2.ZERO)
		t += await _frame_ray()
		var phase: String = trap.big_at().get("phase","")
		if phase == "hold" and not off_before and trap.tilt() > float(trap.knob("big_tilt"))-0.1:
			off_before = not trap.on_back(m.feet) and not trap.holds_rail() and not m.on_ledge()
		# Never stood on its back past the shed tilt (no standing on a wall).
		if m.grounded and trap.on_back(m.feet) and trap.tilt() > float(trap.knob("shed_tilt"))+0.1: no_wall = false
	check(off_before and trap.grabs == 0,"Not grabbing, he slides down the back and off before it is vertical (shed %d, lifted %d, thrown %d)" % [trap.sheds,trap.floats,trap.throws])
	check(no_wall,"...never standing on its back past %.0f deg" % rad_to_deg(float(trap.knob("shed_tilt"))))
	study.scripted = true
	return "big roll: %.0f deg, held, shimmied %.2f m" % [rad_to_deg(tilt_most),shimmied]

## One real frame; its seconds.
func _frame_ray() -> float:
	await process_frame
	if OS.get_environment("TRACE") != "":
		var trap: Node3D = study.traps.named("ray")
		print("  %s tilt %.2f local %s grounded %s move %s hold %s rail %d grabs %d stick %s" % [str(trap.big_at().get("phase","")),trap.tilt(),str(trap.local_of(m.feet).snapped(Vector3.ONE*0.01)),m.grounded,m.move,m.hold,trap.grip_rail,trap.grabs,Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")])
	return study.get_process_delta_time()
