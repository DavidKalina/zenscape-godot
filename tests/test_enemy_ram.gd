extends SceneTree
## The Plinth Ram (scripts/enemies/plinth_ram.gd) in the enemy yard
## (studies/enemy_yard.tscn), headless, the pilot driven by scripted input:
##   - the pilot stood on its line within its notice, it telegraphs (the tell
##     called, the colour changed) for about its tell time, then charges;
##   - the charge winds up (under its top speed early on) and, missing (he
##     steps off its line once it is committed), runs only a little past
##     where he stood, then SKIDS: it keeps sliding along its line while its
##     front swings round to him, digs in and charges again, never steered
##     off the isle;
##   - a charge that finds him shoves him: a pilot standing on its line, or
##     near the isle's lip, is hit; a late sharp juke is missed;
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
	await _late_juke_misses()
	await _skid_swings_round()
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
	var start := ram.position
	var aimed: float = Vector2(m.feet.x-start.x,m.feet.z-start.z).length()
	_tick(int(float(ram.knobs.wind_up)*0.3/DT))
	check(Vector2(ram.vel.x,ram.vel.z).length() < float(ram.knobs.charge_speed)*0.6,"It winds up: early in the charge it is well under its top speed (%.2f)" % Vector2(ram.vel.x,ram.vel.z).length())
	# Committed: he steps off the line (stood aside on the isle).
	m.reset(Vector3(8.0,0.0,9.0),PilotMotor.facing_of(Vector2(0.0,-1.0)))
	_until(func() -> bool: return Vector2(ram.vel.x,ram.vel.z).length() >= ram.knobs.charge_speed-0.1,1.0)
	check(Vector2(ram.vel.x,ram.vel.z).length() > m.run,"It charges above his run (%.2f over %.2f m/s)" % [Vector2(ram.vel.x,ram.vel.z).length(),m.run])
	_until(func() -> bool: return ram.state == "skid" or ram.gone,8.0)
	var skid_at := ram.position
	_until(func() -> bool: return ram.state == "dig" or ram.gone,3.0)
	var ran: float = Vector2(ram.position.x-start.x,ram.position.z-start.z).length()
	check(absf(ram.position.x-start.x) < 0.5 and m.feet.x > 5.0,"It did not steer after him")
	check(not ram.gone and ram.state == "dig","Missing, it slid to a stop on the isle and dug in, not over the edge")
	check(ran <= aimed+float(ram.knobs.overrun)+0.5 and ran > aimed,"It ran only a little past where he stood (%.1f m, he was %.1f m off)" % [ran,aimed])
	check(skid_at.distance_to(ram.position) > 1.0,"It slid on after the skid began (%.1f m)" % skid_at.distance_to(ram.position))
	# Short of an edge: set it charging at the near rim from close by.
	ram = await _fresh()
	_until(func() -> bool: return ram.state == "charge",3.0)
	ram.set("_reach",100.0)
	m.reset(Vector3(8.0,0.0,9.0),PilotMotor.facing_of(Vector2(0.0,-1.0)))
	var fell := false
	for i in range(int(12.0/DT)):
		study.tick(DT)
		if ram.gone or not ram.grounded: fell = true
	check(not fell and ram.position.z < 13.0,"Charging at an edge with reach to spare, it stops at the lip and never goes over (z %.1f)" % ram.position.z)

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

func _late_juke_misses() -> void:
	var ram: Node3D = await _fresh()
	var hit := [false]
	ram.hit_pilot.connect(func(_e: Node3D) -> void: hit[0] = true)
	_until(func() -> bool: return ram.state == "charge",3.0)
	# Stands until it is nearly on him, then runs sideways.
	_until(func() -> bool: return ram.position.distance_to(m.feet) < 4.5,3.0)
	study.script_want = Vector2(1.0,0.0)
	_until(func() -> bool: return hit[0] or ram.state == "skid",2.0)
	_tick(30)
	study.script_want = Vector2.ZERO
	check(not hit[0],"A late sharp juke is missed (he is %.1f m off its line)" % absf(m.feet.x-ram.position.x))
	check(m.feet.x > 1.5,"He is clear of it (x %.1f)" % m.feet.x)

func _skid_swings_round() -> void:
	var ram: Node3D = await _fresh()
	_until(func() -> bool: return ram.state == "charge",3.0)
	m.reset(Vector3(8.0,0.0,9.0),PilotMotor.facing_of(Vector2(0.0,-1.0)))
	var way: Vector2 = ram.get("_dir")
	_until(func() -> bool: return ram.state == "skid",4.0)
	check(ram.state == "skid" and not study.enemies.sounds.filter(func(s: Array) -> bool: return s[0] == &"ram_scrape").is_empty(),"It skids, with its scrape sound")
	var dust: CPUParticles3D = ram.get("_dust")
	_tick(5)
	check(dust.emitting,"Dust puffs off its feet in the skid")
	var slid := Vector2(ram.vel.x,ram.vel.z)
	var along := slid.normalized().dot(way)
	var worst := 0.0
	var seen_charge := 0
	var pace_at_swing := 0.0
	for i in range(int(5.0/DT)):
		study.tick(DT)
		if ram.state == "skid":
			var off := absf(angle_difference(ram.facing,PilotMotor.facing_of(way)))
			var pace := Vector2(ram.vel.x,ram.vel.z).length()
			if pace > 1.5 and off > worst:
				worst = off
				pace_at_swing = pace
		if ram.state == "charge": seen_charge += 1
		if seen_charge > 3: break
	check(along > 0.99,"It carries its momentum on along the old line while skidding")
	check(worst > 0.5 and pace_at_swing > 1.5,"Its front swings round while it still slides (%.2f rad at %.1f m/s)" % [worst,pace_at_swing])
	check(seen_charge > 3 and ram.told_count >= 2,"It digs in, tells again and charges again (%d tells)" % ram.told_count)
	var to: Vector2 = Vector2(m.feet.x-ram.position.x,m.feet.z-ram.position.z)
	check(absf(angle_difference(ram.facing,PilotMotor.facing_of(to))) < 0.4,"The second charge is aimed at him")
	check(not ram.gone and ram.grounded,"It stays on the isle")

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
