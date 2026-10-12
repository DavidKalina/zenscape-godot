extends SceneTree
## The Plinth Ram (scripts/enemies/plinth_ram.gd) in the enemy yard
## (studies/enemy_yard.tscn), headless, the pilot driven by scripted input:
##   - the pilot stood on its line within its notice, it telegraphs (the tell
##     called, the colour changed) for about its tell time, then charges;
##   - the charge winds up (under its top speed early on) and, missing (he
##     steps off its line once it is committed), runs only a little past
##     where he stood, brakes short of the isle's edge and stays on the isle;
##   - a charge that finds him shoves him: knocked, tumbling away along its
##     line, at a pace over his run.
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
	var start := ram.position
	var aimed: float = Vector2(m.feet.x-start.x,m.feet.z-start.z).length()
	_tick(int(float(ram.knobs.wind_up)*0.3/DT))
	check(Vector2(ram.vel.x,ram.vel.z).length() < float(ram.knobs.charge_speed)*0.6,"It winds up: early in the charge it is well under its top speed (%.2f)" % Vector2(ram.vel.x,ram.vel.z).length())
	# Committed: he steps off the line (stood aside on the isle).
	m.reset(Vector3(8.0,0.0,9.0),PilotMotor.facing_of(Vector2(0.0,-1.0)))
	_until(func() -> bool: return Vector2(ram.vel.x,ram.vel.z).length() >= ram.knobs.charge_speed-0.1,1.0)
	check(Vector2(ram.vel.x,ram.vel.z).length() > m.run,"It charges above his run (%.2f over %.2f m/s)" % [Vector2(ram.vel.x,ram.vel.z).length(),m.run])
	_until(func() -> bool: return ram.state == "stun" or ram.gone,8.0)
	var ran: float = Vector2(ram.position.x-start.x,ram.position.z-start.z).length()
	check(absf(ram.position.x-start.x) < 0.5 and m.feet.x > 5.0,"It did not steer after him")
	check(not ram.gone and ram.state == "stun","Missing, it braked to a stop on the isle and stands winded, not over the edge")
	check(ran <= aimed+float(ram.knobs.overrun)+0.5,"It ran only a little past where he stood (%.1f m, he was %.1f m off)" % [ran,aimed])
	# Short of an edge: set it charging at the near rim from close by.
	ram = await _fresh()
	_until(func() -> bool: return ram.state == "charge",3.0)
	ram.set("_reach",100.0)
	m.reset(Vector3(8.0,0.0,9.0),PilotMotor.facing_of(Vector2(0.0,-1.0)))
	_until(func() -> bool: return ram.state == "stun" or ram.gone,8.0)
	check(not ram.gone and ram.grounded,"Charging at an edge with reach to spare, it stops at the lip")

func _hit_shoves() -> void:
	var ram: Node3D = await _fresh()
	var hit := [false]
	ram.hit_pilot.connect(func(_e: Node3D) -> void: hit[0] = true)
	_until(func() -> bool: return hit[0],6.0)
	check(hit[0],"A charge that finds him hits him")
	check(m.move == "tumble" and not m.grounded,"He is knocked (tumbling), not damaged")
	check(m.velocity.z > m.run,"Shoved along its line, faster than he runs (%.2f m/s)" % m.velocity.z)
