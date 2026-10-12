extends SceneTree
## The Plinth Ram (scripts/enemies/plinth_ram.gd) in the enemy yard
## (studies/enemy_yard.tscn), headless, the pilot driven by scripted input:
##   - it telegraphs (tell called, colour), then charges, winding up;
##   - the charge HOMES: a pilot who moves early is followed and hit; a
##     standing pilot, also near the lip, is hit and shoved;
##   - a LATE dodge near an edge sends it over: a jump over it, a slide
##     sideways, a drop into a ledge hang (he is still hanging, not hit);
##   - a late dodge in the open: it skids on, swings round, comes again, and
##     does not fall;
##   - it never charges off an edge with no pilot to chase (soak);
##   - slid into from the side near an edge, it goes over.
##   godot --headless --path . --script tests/test_enemy_ram.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(60.0).timeout.connect(func() -> void: push_error("enemy ram test timed out"); quit(2))
	study = load("res://studies/enemy_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	check(study.enemies.enemies.size() == 1,"The yard has its one ram")
	await _telegraph_then_charge_and_stop()
	await _hit_shoves()
	await _hit_near_the_lip()
	await _homes_on_an_early_sidestep()
	await _late_jump_near_edge()
	await _late_slide_near_edge()
	await _late_dodge_in_the_open()
	await _ledge_hang_drops_it()
	await _never_off_an_edge_unchased()
	await _push_over_the_edge()
	study.queue_free()
	await process_frame
	print("enemy ram: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _tick(n: int) -> void:
	for i in range(n): study.tick(DT)

## Until `done` holds, at most `seconds`; the frames it took.
func _until(done: Callable, seconds: float) -> int:
	var n := 0
	while n < int(seconds/DT) and not done.call():
		study.tick(DT)
		n += 1
	return n

func _fresh() -> Node3D:
	study.respawn()
	await physics_frame
	await physics_frame
	return study.enemies.enemies[0]

func _telegraph_then_charge_and_stop() -> void:
	var ram: Node3D = await _fresh()
	var tell_time: float = ram.knobs.tell
	check(ram.state == "idle" and ram.told_count == 0,"Idle at first, no tell given")
	var frames := _until(func() -> bool: return ram.state == "tell",3.0)
	check(ram.state == "tell" and ram.told_count == 1,"On its line within its notice it telegraphs (%.2f s)" % (frames*DT))
	check(not study.enemies.sounds.is_empty() and study.enemies.sounds[0][0] == &"ram_paw","The tell called the placeholder sound")
	check(ram.get("_mat").albedo_color.is_equal_approx(ram.tell_colour),"The tell changed its colour")
	var held := _until(func() -> bool: return ram.state != "tell",3.0)
	check(ram.state == "charge" and absf(held*DT-tell_time) < 0.1,"It charges after the tell, %.2f s" % (held*DT))
	_tick(int(float(ram.knobs.wind_up)*0.3/DT))
	check(Vector2(ram.vel.x,ram.vel.z).length() < float(ram.knobs.charge_speed)*0.6,"It winds up: early in the charge it is well under its top speed (%.2f)" % Vector2(ram.vel.x,ram.vel.z).length())
	_until(func() -> bool: return Vector2(ram.vel.x,ram.vel.z).length() >= ram.knobs.charge_speed-0.1,1.0)
	check(Vector2(ram.vel.x,ram.vel.z).length() > m.run,"It charges above his run (%.2f over %.2f m/s)" % [Vector2(ram.vel.x,ram.vel.z).length(),m.run])

func _hit_shoves() -> void:
	var ram: Node3D = await _fresh()
	var hit := [false]
	ram.hit_pilot.connect(func(_e: Node3D) -> void: hit[0] = true)
	_until(func() -> bool: return hit[0],6.0)
	check(hit[0],"A charge that finds him hits him")
	check(m.move == "tumble" and not m.grounded,"He is knocked (tumbling), not damaged")
	check(m.velocity.z > m.run,"Shoved along its line, faster than he runs (%.2f m/s)" % m.velocity.z)

## Stood at `at` (x, z) on the isle, the ram `d` m away along its line, until
## it has hit or `seconds` pass; whether it hit.
func _stand_and_wait(at: Vector2, seconds: float) -> bool:
	var ram: Node3D = await _fresh()
	# Close enough to notice him wherever he stands.
	ram.position = Vector3(0.0,0.0,at.y-9.0)
	m.reset(Vector3(at.x,0.0,at.y),PilotMotor.facing_of(Vector2(0.0,-1.0)))
	var hit := [false]
	ram.hit_pilot.connect(func(_e: Node3D) -> void: hit[0] = true)
	_until(func() -> bool: return hit[0],seconds)
	return hit[0]

func _hit_near_the_lip() -> void:
	# 1 m from the south edge (z 13): the ram brakes harder there, but it
	# still reaches him.
	var hit: bool = await _stand_and_wait(Vector2(0.0,12.0),6.0)
	check(hit,"A pilot standing near the isle's lip, within its reach, is hit")
	for z in [4.0,7.0]:
		hit = await _stand_and_wait(Vector2(0.0,z),6.0)
		check(hit,"A pilot standing on its line %.0f m on is hit" % (z+2.0))

## A ram at `r` (x, z) and the pilot at `p`, facing each other, the ram
## charging at him; `run` has him already running along it (a vector, x, z).
func _charging(r: Vector2, p: Vector2, run := Vector2.ZERO) -> Node3D:
	var ram: Node3D = await _fresh()
	ram.position = Vector3(r.x,0.0,r.y)
	ram.facing = PilotMotor.facing_of(p-r)
	ram.rotation.y = ram.facing
	var speed := run.length()
	m.reset(Vector3(p.x,0.0,p.y),PilotMotor.facing_of(run if speed > 0.0 else r-p),speed)
	study.script_want = run.normalized() if speed > 0.0 else Vector2.ZERO
	_until(func() -> bool: return ram.state == "charge",3.0)
	return ram

## The flat distance between ram and pilot at which a dodge `tau` s before
## contact (at its top speed) is made.
func _contact_at(ram: Node3D, tau: float) -> float:
	return float(ram.knobs.charge_speed)*tau+ram.length*0.5+float(ram.knobs.radius)

## Plays a charge at a pilot who dodges `tau` s before contact: "jump" (held
## 12 ticks), "slide" (crouch while running), "side" (run sideways), "hang"
## (walks off the rim), "step" (a sidestep of 0.35 s, then he stands). Returns {hit, over (the ram fell or is falling),
## hung (still hanging at the end), ram}.
func _play(r: Vector2, p: Vector2, kind: String, tau: float, run := Vector2.ZERO, after := 4.0) -> Dictionary:
	var ram: Node3D = await _charging(r,p,run)
	var hit := [false]
	var where := [0.0]
	ram.hit_pilot.connect(func(_e: Node3D) -> void:
		# The first charge and its skid decide it; a second go is another test.
		if ram.told_count <= 1 and not hit[0]:
			hit[0] = true
			where[0] = ram.position.x)
	var at := _contact_at(ram,tau)
	var dist := func() -> float: return Vector2(m.feet.x-ram.position.x,m.feet.z-ram.position.z).length()
	_until(func() -> bool: return hit[0] or ram.state != "charge" or dist.call() <= at,3.0)
	match kind:
		"jump": study.script_jump = true
		"slide":
			# He has the run of a power slide across its line already: the
			# pace he would have, crouched sideways, at this moment.
			m.velocity = Vector3(m.run,0.0,0.0)
			m.facing = PilotMotor.facing_of(Vector2(1.0,0.0))
			study.script_want = Vector2(1.0,0.0)
			study.script_crouch = true
		"side": study.script_want = Vector2(1.0,0.0)
		"hang": study.script_want = Vector2(0.0,0.4)
		"step": study.script_want = Vector2(1.0,0.0)
	var over := false
	for i in range(int(after/DT)):
		if kind == "jump" and i == 12: study.script_jump = false
		if kind == "step" and i == 22: study.script_want = Vector2.ZERO
		study.tick(DT)
		if ram.gone or not ram.grounded: over = true
		if kind == "hang" and m.hold != "" and study.script_want != Vector2.ZERO: study.script_want = Vector2.ZERO
	var out := {"hit":hit[0],"over":over,"hung":m.hold == "hang","ram":ram,"hit_x":where[0]}
	study.script_want = Vector2.ZERO
	study.script_jump = false
	study.script_crouch = false
	return out

func _push_over_the_edge() -> void:
	var ram: Node3D = await _fresh()
	# Idle near the south edge (z 13), its side to him; he slides into it
	# from the north at over push speed.
	ram.position = Vector3(0.0,0.0,12.2)
	ram.facing = PilotMotor.facing_of(Vector2(1.0,0.0))
	ram.rotation.y = ram.facing
	ram.set("_wander_t",100.0)
	ram.set("_walking",false)
	m.reset(Vector3(0.0,0.0,9.5),PilotMotor.facing_of(Vector2(0.0,1.0)),m.run*1.5)
	study.script_want = Vector2(0.0,1.0)
	var knocked := [false]
	ram.knocked.connect(func(_e: Node3D) -> void: knocked[0] = true)
	_until(func() -> bool: return knocked[0] or ram.gone,3.0)
	study.script_want = Vector2.ZERO
	check(knocked[0],"Slid into from the side, it is knocked")
	_until(func() -> bool: return ram.gone or not ram.grounded,3.0)
	check(ram.gone or not ram.grounded,"Pushed toward the edge, it goes over")

## The pilot sidesteps early (a second before contact) and stands: the ram
## has followed him and hits him; it homed, it did not run the old line.
func _homes_on_an_early_sidestep() -> void:
	var res: Dictionary = await _play(Vector2(0.0,-1.0),Vector2(0.0,8.0),"step",0.9)
	var ram: Node3D = res.ram
	check(res.hit,"An early sidestep is followed: the ram turns after him and hits him")
	check(res.hit_x > 0.5,"It left its first line to do it (it hit him at x %.1f)" % res.hit_x)

## Late jump 0.18 s before contact, 2 m from the south rim (z 13): it loses
## him over the rim's stopping distance and goes over.
func _late_jump_near_edge() -> void:
	var res: Dictionary = await _play(Vector2(0.0,0.0),Vector2(0.0,11.0),"jump",0.18)
	check(not res.hit,"A late jump over the charge is not hit")
	check(res.over,"...and the ram, fixated, cannot stop short of the rim and goes over")
	# Too early, he lands in front of it; too late he is run down.
	res = await _play(Vector2(0.0,0.0),Vector2(0.0,11.0),"jump",0.6)
	check(res.hit and not res.over,"A jump made too early lands in front of it and is hit")
	res = await _play(Vector2(0.0,0.0),Vector2(0.0,11.0),"jump",0.03)
	check(res.hit,"A jump made too late is run down")

## A power slide sideways 0.4 s before contact (he has the run of it), near the rim.
func _late_slide_near_edge() -> void:
	var res: Dictionary = await _play(Vector2(0.0,0.0),Vector2(0.0,11.0),"slide",0.4)
	check(not res.hit,"A late slide sideways is not hit")
	check(res.over,"...and the ram goes over the rim")
	res = await _play(Vector2(0.0,0.0),Vector2(0.0,11.0),"slide",0.1)
	check(res.hit,"A slide begun too late is hit")

## The same late jump in the open: it brakes, skids round, comes again, and
## does not fall.
func _late_dodge_in_the_open() -> void:
	var ram: Node3D = await _charging(Vector2(0.0,-9.0),Vector2(0.0,0.0))
	var hit := [false]
	ram.hit_pilot.connect(func(_e: Node3D) -> void:
		if ram.told_count <= 1: hit[0] = true)
	var at := _contact_at(ram,0.18)
	_until(func() -> bool: return hit[0] or Vector2(m.feet.x-ram.position.x,m.feet.z-ram.position.z).length() <= at,3.0)
	study.script_jump = true
	var skidded := false
	var swung := 0.0
	var fell := false
	var again := false
	for i in range(int(6.0/DT)):
		if i == 12: study.script_jump = false
		study.tick(DT)
		if ram.state == "skid": skidded = true
		if ram.gone or not ram.grounded: fell = true
		if skidded and ram.state == "skid" and Vector2(ram.vel.x,ram.vel.z).length() > 1.5: swung = maxf(swung,absf(angle_difference(ram.facing,PilotMotor.facing_of(Vector2(0.0,1.0)))))
		if ram.told_count >= 2 and ram.state == "charge": again = true
	check(not hit[0],"Dodged in the open: not hit")
	check(skidded and swung > 0.5,"It lost him and skidded, its front swinging round (%.2f rad)" % swung)
	check(not fell and ram.position.z < 6.0,"A miss in the open costs it nothing: it did not fall (z %.1f)" % ram.position.z)
	check(again and ram.told_count >= 2,"It tells again and comes again (%d tells)" % ram.told_count)

## He steps off the south rim into a hang as it comes: it runs over the lip
## above him, and he is still hanging (not knocked off).
func _ledge_hang_drops_it() -> void:
	var res: Dictionary = await _play(Vector2(0.0,2.0),Vector2(0.0,12.7),"hang",0.8)
	check(m.hold == "hang" or res.hung,"He hangs from the rim")
	check(res.over,"It runs over the lip above him and falls")
	check(not res.hit and res.hung,"...and does not knock the hanging pilot off (still %s)" % m.hold)

## No pilot to chase: it never takes itself off an edge.
func _never_off_an_edge_unchased() -> void:
	# He vanishes (out of range) as it charges toward the south rim.
	var ram: Node3D = await _charging(Vector2(0.0,4.0),Vector2(0.0,12.0))
	_until(func() -> bool: return ram.position.z > 7.5,3.0)
	m.reset(Vector3(-10.0,0.0,-12.0),0.0)
	var fell := false
	for i in range(int(8.0/DT)):
		study.tick(DT)
		if ram.gone or not ram.grounded: fell = true
	check(not fell,"A charge that loses its pilot out of range stops at the rim (z %.1f)" % ram.position.z)
	# Idle, far from him, at each rim, for a long time.
	for at: Vector2 in [Vector2(0.0,11.5),Vector2(11.0,0.0),Vector2(-11.0,-8.0)]:
		ram = await _fresh()
		ram.position = Vector3(at.x,0.0,at.y)
		m.reset(Vector3(-at.x*0.5,0.0,-at.y-6.0 if at.y > 0.0 else 9.0),0.0)
		fell = false
		for i in range(int(40.0/DT)):
			study.tick(DT)
			if ram.gone or not ram.grounded: fell = true
		check(not fell,"Wandering at the rim by %s for 40 s, it never goes over" % at)
	# He is on the high ledge, out of reach: it charges the wall, no more.
	ram = await _fresh()
	m.reset(Vector3(0.0,1.2,-14.5),0.0)
	fell = false
	for i in range(int(12.0/DT)):
		study.tick(DT)
		if ram.gone or not ram.grounded: fell = true
	check(not fell,"Chasing a pilot it cannot reach (the ledge), it hits the wall and does not fall")
