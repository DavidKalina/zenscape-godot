extends SceneTree
## The giants (scripts/traps/trap_tumble.gd, trap_ray.gd) in the trap yard,
## headless, the pilot driven by scripted input:
##   - the Tumbling Block is several pilot-heights a side; a pilot standing
##     still on its top is carried round and slid off as it tips; one who
##     keeps walking uphill against the roll (a station-keeper) stays on
##     longer, over N seconds;
##   - the Sky Ray, flying its real schedule through the yard's own frame
##     (study.tick, the pilot's motor, the trap field): it carries a pilot
##     along its path; standing still through its hardest bank he slides off
##     its back within a couple of seconds; a rider who holds the middle,
##     leaning uphill, stays on through the whole loop; in a dive's plunge he
##     leaves its back and lands on it again; slid slowly off its rim, leaning
##     in, he catches the rim and hangs, carried; and a careful rider jumps
##     on from the start deck's edge, rides the loop and jumps off onto the
##     far deck.
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
	await _tumble()
	await _ray()
	print("trap giants: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## Seconds (up to `limit`) he stays on the block; `keep` the station-keeper.
func _stay_on(trap: Node3D, keep: bool, limit: float) -> float:
	trap.reset()
	study.place(trap.top_point(),Vector2(0.0,-1.0))
	study.script_want = Vector2.ZERO
	await _tick(2)
	var t := 0.0
	var p := Trap.pilot()
	var z0: float = trap.to_global(trap.centre()).z
	var prev_z := m.feet.z
	while t < limit:
		var want := Vector2.ZERO
		if keep:
			# Hold the middle: walk -z (uphill) when behind it, back when ahead.
			var off := m.feet.z-z0
			want = Vector2(0.0,clampf(-off*2.0,-1.0,1.0))
		study.script_want = want
		# Hop what blocks him (a step, a wall): pressing on and not getting on.
		study.script_jump = keep and m.feet.z-z0 > 0.3 and m.feet.z > prev_z-0.004 and m.grounded
		prev_z = m.feet.z
		await _tick(1)
		t += DT
		if OS.get_environment("TRACE") != "" and int(t*60.0)%5 == 0 and t > 6.0 and t < 7.4 and keep:
			print("  t %.2f roll %.2f feet %s grounded %s move %s hold %s" % [t,trap.roll,(trap.to_local(m.feet)-trap.centre()).snapped(Vector3.ONE*0.01),m.grounded,m.move,m.hold])
			print("     want %s vel %s wallish %s" % [study.script_want,m.velocity.snapped(Vector3.ONE*0.01),str(m.slope)])
		if not trap.on_block(m.feet) or m.feet.y < trap.top_point().y-3.0 and not m.on_ledge(): break
	study.script_jump = false
	return t

func _tumble() -> void:
	var trap: Node3D = study.traps.named("tumble")
	var p := Trap.pilot()
	check(trap != null and trap.danger() == 5,"The yard has the Tumbling Block, cost 4 over the void")
	var size: float = trap.knob("size")
	check(size >= 4.0*1.12,"It is many pilot-heights a side (%.1f m)" % size)
	var still := await _stay_on(trap,false,20.0)
	check(still < 15.0,"Standing still on its top he is slid off as it tips (%.1f s)" % still)
	var keeping := await _stay_on(trap,true,40.0)
	check(keeping > still*1.5 and keeping >= 39.9,"Walking against the roll he stays on, the whole run, longer (%.1f s vs %.1f s)" % [keeping,still])
	print("     tumble: still %.1f s, keeping %.1f s of 40, rolled %.2f rad" % [still,keeping,trap.roll])
	# Carried, not teleported: no frame of a keeper moves more than the surface could.
	var worst := 0.0
	trap.reset()
	study.place(trap.top_point(),Vector2(0.0,-1.0))
	study.script_want = Vector2.ZERO
	await _tick(2)
	var last := m.feet
	for i in range(120):
		await _tick(1)
		worst = maxf(worst,m.feet.distance_to(last))
		last = m.feet
	check(worst < p.run*DT*3.0+float(trap.knob("size"))*float(trap.knob("spin"))*DT*2.0,"...carried by the surface, never jumped (worst step %.3f m)" % worst)
	trap.reset()

## On the ray's back at `at` (its frame), the ray at `d` along its loop.
func _ray_board(trap: Node3D, d: float, at: Vector3) -> void:
	study.place(trap.to_global(Vector3(trap.line_x(),0.0,0.0)),Vector2(0.0,-1.0))
	trap.s = d
	trap._pose()
	m.reset(trap.to_global(trap.body.transform*at),PI)
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
## leaning uphill on a slope.
func _ray_keep(trap: Node3D, l: Vector3) -> Vector2:
	var want := Vector2(-l.x,-l.z)*0.6
	if absf(l.x) > float(trap.knob("width"))*0.3 and absf(l.z) > 0.6: want = Vector2(0.0,-signf(l.z))
	var down := _ray_down(trap)
	if down != Vector2.ZERO: want -= down.normalized()*0.4
	return want

func _ray() -> void:
	var trap: Node3D = study.traps.named("ray")
	check(trap != null and trap.danger() == 5,"The yard has the Sky Ray, cost 4 over the void")
	var v: float = trap.knob("speed")
	var w: float = float(trap.knob("width"))*0.5
	# Carried along the path, from the start deck.
	await _ray_board(trap,trap.near_at(0.0),Vector3.ZERO)
	var start: Vector3 = m.feet
	var start_body: Vector3 = trap.body.global_position
	await _tick(180)
	var moved := m.feet.distance_to(start)
	check(trap.on_back(m.feet),"He rides it: still on its back after 3 s (local %s)" % str(trap.local_of(m.feet).snapped(Vector3.ONE*0.01)))
	check(moved > v*3.0*0.8 and trap.body.global_position.distance_to(start_body) > 5.0,"...his world position follows it (moved %.1f m, it moved %.1f)" % [moved,trap.body.global_position.distance_to(start_body)])
	# The beats: the hardest bank, the first dive.
	var hardest := {}
	var dive := {}
	for beat: Dictionary in trap.beats():
		if beat.kind != "D" and (hardest.is_empty() or float(beat.size) > float(hardest.size)): hardest = beat
		if beat.kind == "D" and dive.is_empty(): dive = beat
	check(not hardest.is_empty() and not dive.is_empty(),"Its loop has banks and dives (%s)" % trap.knob("pattern"))
	# Standing still through the hardest bank: slid off. Clear of the ridges
	# on the low side (the right wing low: +x).
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
	# Holding the middle, leaning uphill, through the whole loop from the
	# start deck: on its back (or floating over it in a dive) throughout.
	await _ray_board(trap,trap.near_at(0.0),Vector3.ZERO)
	var lap: float = trap.loop_length()/v
	var stayed := true
	var high := 0.0
	var worst := 0.0
	var leans := 0
	t = 0.0
	while t < lap:
		var l: Vector3 = trap.local_of(m.feet)
		var want := _ray_keep(trap,l)
		if _ray_down(trap) != Vector2.ZERO: leans += 1
		study.script_want = _ray_way(trap,want)
		await _tick(1)
		t += DT
		l = trap.local_of(m.feet)
		worst = maxf(worst,maxf(absf(l.x)-w,0.0))
		if not m.grounded: high = maxf(high,l.y)
		if absf(l.x) > w+0.3 or absf(l.z) > float(trap.knob("long"))*0.5+0.3 or l.y < -0.5:
			stayed = false
			break
	study.script_want = Vector2.ZERO
	check(stayed and trap.on_back(m.feet) and leans > 60,"Holding the middle, leaning uphill, he stays on through the whole loop (%.1f s of %.1f, %d floats)" % [t,lap,trap.floats])
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
	while t < 1.0+float(hardest.long)/v:
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
	print("     ray: hardest bank %.2f rad, still off at %.2f s; keeper lap %.1f s; dive %.2f m clear for %.2f s; hung %.2f s" % [hardest.size,off_at,lap,lifted,air,hung])
	trap.reset()

## The route: on from the start deck's edge as it passes, the loop ridden
## holding the middle, off onto the far deck as it passes that.
func _ray_route(trap: Node3D) -> void:
	var lane: Vector3 = trap.global_position
	var v: float = trap.knob("speed")
	study.place(lane+Vector3(float(trap.knob("edge_x"))-0.4,0.0,1.0),Vector2(1.0,0.0))
	trap.s = trap.near_at(0.0)-v*2.0
	trap._pose()
	await _tick(2)
	var t := 0.0
	var boarded := false
	while t < 6.0 and not boarded:
		var c: Vector3 = trap.body.global_position
		study.script_jump = c.z > m.feet.z-1.5 and c.z < m.feet.z and m.grounded
		study.script_want = Vector2(1.0,0.0) if study.script_jump or not m.grounded else Vector2.ZERO
		await _tick(1)
		t += DT
		boarded = m.grounded and trap.on_back(m.feet)
	study.script_jump = false
	check(boarded,"A careful rider jumps on from the start deck's edge as it passes (local %s)" % str(trap.local_of(m.feet).snapped(Vector3.ONE*0.01)))
	var far: float = -float(trap.knob("ride"))
	var landed := false
	var off := false
	var rim: float = float(trap.knob("width"))*0.5
	t = 0.0
	while t < trap.loop_length()/v+4.0 and boarded:
		var d: float = fposmod(trap.s,trap.loop_length())
		var l: Vector3 = trap.local_of(m.feet)
		var b: Basis = trap.global_transform.basis*trap.body.transform.basis
		# Beside the far deck (it flies +z there, its +x the deck's side).
		var beside: bool = d < trap.straight() and trap.path_at(d).z > far-6.0 and trap.path_at(d).z < far-1.0
		var want := _ray_keep(trap,l)
		if d < v and not beside: want = Vector2(rim-0.6-l.x,-l.z)
		study.script_want = _ray_way(trap,want)
		study.script_jump = false
		if beside or off:
			study.script_want = Vector2(-1.0,0.0)
			study.script_jump = m.grounded and trap.on_back(m.feet) and l.x > rim-0.9
		await _tick(1)
		t += DT
		if beside and not m.grounded and not trap.on_back(m.feet): off = true
		var rel: Vector3 = m.feet-lane
		if off and m.grounded and rel.x < float(trap.knob("edge_x")) and rel.z < far and rel.z > far-8.0:
			landed = true
			break
		if m.feet.y < lane.y-3.0: break
	study.script_want = Vector2.ZERO
	study.script_jump = false
	check(landed,"...rides the loop and jumps off onto the far deck as it passes (%.1f s, at %s)" % [t,str((m.feet-lane).snapped(Vector3.ONE*0.01))])
