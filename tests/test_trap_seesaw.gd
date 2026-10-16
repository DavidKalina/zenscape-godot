extends SceneTree
## suite: slow
## Seesaw Slab (scripts/traps/trap_seesaw.gd) in the trap yard, headless:
##   - stood on the near end, the slab tips toward him (far end rises) and
##     he is carried with it;
##   - empty, it returns level;
##   - a hard landing on the high end flings what stands on the low end:
##     a RigidBody3D load, and the pilot himself.
##   - round 2b: a slam on the high end flings a heavy block off the low end
##     farther than a plain landing; the heavy block holds its end down under
##     the pilot's plain weight; a block dropped on the high end launches a
##     pilot on the low end (to the ledge on the catapult lane, off the span
##     on the timed one).
##   - the blocks on the yard's own loop (the study's _process, physics on its
##     own clock, as in play; 2026-10-12 they fell through the slab there):
##     a block rests on its end for seconds, rides a plain landing without
##     sinking into the slab, flies clear off a slam and lands on the far deck,
##     slides down (and off) a slab tilted past its grip, and a dropped block
##     launches the pilot.
##   godot --headless --path . --script tests/test_trap_seesaw.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Trap = preload("res://scripts/traps/trap.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor
var trap: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _tick(n: int) -> void:
	for i in range(n):
		study.tick(DT)
		await physics_frame

## `n` frames of the yard's own loop: the study ticks in _process, physics
## steps on its own clock (`watch`, if given, is called each frame).
func _play(n: int, watch: Callable = Callable()) -> void:
	study.scripted = false
	for i in range(n):
		await process_frame
		if watch.is_valid(): watch.call()
	study.scripted = true

## How far the block's underside is above the slab's top where it is, and
## whether it is over the slab (local x and z inside its span).
func _clear(t: Node3D, b: RigidBody3D) -> Array:
	var l: Vector3 = (t.body.transform as Transform3D).affine_inverse()*t.to_local(b.global_position)
	var half: float = b.get_meta("half",0.5)
	var over: bool = absf(l.x) <= float(t.knob("width"))*0.5 and l.z <= 0.0 and l.z >= -t.length()
	return [l.y-half,over]

func _put(z: float, up := 0.0, t: Node3D = null) -> void:
	var at: Vector3 = (t if t != null else trap).to_global(Vector3(0.0,up,z))
	study.place(at,Vector2(0.0,-1.0))
	study.script_want = Vector2.ZERO

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("trap seesaw test timed out"); quit(2))
	study = load("res://studies/trap_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	trap = study.traps.named("seesaw")
	check(trap != null and trap.danger() == 3,"The yard has a Seesaw Slab, cost 3")
	var max_tilt: float = trap.knob("max_tilt")
	await physics_frame
	await physics_frame
	# Near end: the far end rises.
	_put(-0.8)
	await _tick(90)
	check(m.grounded and trap.on_slab(m.feet),"Stood on the near end he is on the slab")
	check(trap.tilt > max_tilt*0.4 and trap.high_end() == 1,"...it tips toward him: far end up (tilt %.2f of %.2f)" % [trap.tilt,max_tilt])
	check(absf(m.feet.y-trap.to_global(Vector3(0.0,trap._surface_y(trap.to_local(m.feet).z),0.0)).y) < 0.2,"...and he is carried with it (y %.2f)" % m.feet.y)
	# Empty: level.
	_put(8.0)
	await _tick(300)
	check(absf(trap.tilt) < 0.01,"Empty, it returns level (tilt %.3f)" % trap.tilt)
	# Hard landing on the high end flings the low end.
	var stone := RigidBody3D.new()
	stone.gravity_scale = 0.0
	var cs := CollisionShape3D.new()
	cs.shape = SphereShape3D.new()
	stone.add_child(cs)
	study.add_child(stone)
	trap.loads.append(stone)
	_put(-length_far(),3.0)
	_level_at(max_tilt)
	stone.global_position = trap.to_global(Vector3(0.0,1.5,-0.7))
	stone.linear_velocity = Vector3.ZERO
	await physics_frame
	var launches: int = trap.launches
	await _tick(80)
	check(trap.launches == launches+1,"A hard landing on the high end is a launch (%d)" % trap.launches)
	check(stone.linear_velocity.y > 1.0,"...it flings the load on the low end (vy %.1f)" % stone.linear_velocity.y)
	# The pilot himself on the low end, a blow on the high end.
	_put(-0.8)
	_level_at(max_tilt)
	m.feet = trap.to_global(Vector3(0.0,trap._surface_y(-0.8),-0.8))
	await physics_frame
	await _tick(1)
	_level_at(max_tilt)
	trap.impact(2.5,float(trap.knob("hard"))*1.5)
	await _tick(2)
	check(not m.grounded and m.velocity.y > 1.0,"...and the pilot on the low end (vy %.1f)" % m.velocity.y)
	await _round_2b()
	await _real_loop()
	print("trap seesaw: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## z of a spot on the far end.
func length_far() -> float:
	return trap.length()-0.8

func _level_at(t: float) -> void:
	trap.tilt = t
	trap.spin = 0.0
	trap._pose()

## Block flight from a drop/slam on the near end of the slam lane: [farthest
## z travelled (m, along the route), highest y above its rest].
func _slam_run(t: Node3D, height: float, slam: bool) -> Array:
	var z := -0.8
	_put(z,height,t)
	await physics_frame
	await _tick(2)
	if slam: m.slam(27.0,20.0)
	var b: RigidBody3D = t.block
	var start: Vector3 = b.global_position
	var far := 0.0
	var high := 0.0
	var launches: int = t.launches
	for i in range(240):
		await _tick(1)
		far = maxf(far,start.z-b.global_position.z)
		high = maxf(high,b.global_position.y-start.y)
	return [far,high,t.launches-launches]

func _round_2b() -> void:
	# Heavy load keeps its end down under the pilot's plain weight.
	var sl: Node3D = study.traps.named("seesaw_slam")
	check(sl != null,"The yard has the slam lane")
	_put(8.0,0.0,sl)
	await _tick(120)
	var cap: float = sl.knob("max_tilt")
	check(sl.tilt < -cap*0.8 and sl.high_end() == -1,"The heavy block holds the far end down (tilt %.2f of %.2f)" % [sl.tilt,cap])
	var rest_y: float = sl.block.global_position.y
	_put(-0.8,0.1,sl)
	await _tick(150)
	check(m.grounded and sl.on_slab(m.feet) and sl.tilt < -cap*0.5,"...and the pilot standing on the high end alone cannot lift it (tilt %.2f)" % sl.tilt)
	check(absf(sl.block.global_position.y-rest_y) < 0.4,"...the block stays down (dy %.2f)" % (sl.block.global_position.y-rest_y))
	# A plain landing on the high end, then a slam from height.
	var plain: Array = await _slam_run(sl,1.2,false)
	await _tick(60)
	var hit: Array = await _slam_run(sl,5.0,true)
	print("  plain landing: carried %.2f m, rose %.2f m; slam: carried %.2f m, rose %.2f m" % [plain[0],plain[1],hit[0],hit[1]])
	check(hit[2] >= 1 and hit[1] > 1.0,"A slam on the high end flings the load up (rose %.2f m)" % hit[1])
	check(hit[0] > 2.0*maxf(plain[0],0.5),"...farther than a plain landing does (%.2f m against %.2f m)" % [hit[0],plain[0]])
	# A light load rises more than a heavy one for the same blow.
	# The catapult lane: the plate lets the block fall; the pilot rides to the ledge.
	var dr: Node3D = study.traps.named("seesaw_drop")
	check(dr != null,"The yard has the drop lane")
	_put(dr.launch_z()+1.0,0.5,dr)
	await _tick(60)
	check(m.grounded and dr.on_slab(m.feet) and dr.high_end() == -1,"On the plate the pilot is the low end, the hook end up")
	var top := 0.0
	var vy := 0.0
	var dropped := false
	for i in range(900):
		await _tick(1)
		vy = maxf(vy,m.velocity.y)
		if dr.drops > 0: dropped = true
	check(dropped,"Standing on the plate lets the block go")
	check(vy > 8.0,"A block dropped on the high end launches the pilot on the low end (vy %.1f)" % vy)
	var ledge_y: float = dr.to_global(Vector3(0.0,dr.ledge_top(),0.0)).y
	check(m.grounded and absf(m.feet.y-ledge_y) < 0.3,"...he comes down on the high ledge (feet y %.2f, ledge %.2f, z %.1f)" % [m.feet.y,ledge_y,dr.to_local(m.feet).z])
	# The timed trap: flung off the span.
	var tm: Node3D = study.traps.named("seesaw_dropper")
	check(tm != null,"The yard has the timed dropper")
	# Stood a little past the pivot on the far half: stood farther out, he
	# slides down the tilt and off its end in the 4 s before the first drop.
	_put(-3.6,0.3,tm)
	await _tick(30)
	var x0: float = m.feet.x
	var thrown := 0.0
	var drops := 0
	for i in range(480):
		await _tick(1)
		thrown = maxf(thrown,absf(m.feet.x-tm.to_global(Vector3.ZERO).x))
		drops = maxi(drops,tm.drops)
	check(drops >= 1 and thrown > float(tm.knob("width"))*0.5+1.5,"The timed drop throws the pilot off the span (%.1f m sideways, %d drop(s))" % [thrown,drops])

## The blocks on the yard's own loop, as in play.
func _real_loop() -> void:
	var sl: Node3D = study.traps.named("seesaw_slam")
	var b: RigidBody3D = sl.block
	# At rest, the pilot elsewhere: the block stays on its end.
	_put(8.0,0.0,sl)
	var rest: Vector3 = b.global_position
	var low := [INF]
	await _play(240,func() -> void: low[0] = minf(low[0],_clear(sl,b)[0]))
	check(low[0] > -0.06 and b.global_position.distance_to(rest) < 0.1,"Real loop: the block rests on its end for 4 s (lowest %.2f m over the top, moved %.2f m)" % [low[0],b.global_position.distance_to(rest)])
	# A plain landing on the high end: the block rides the slab, never into it.
	_put(-0.8,1.2,sl)
	low[0] = INF
	await _play(180,func() -> void: low[0] = minf(low[0],_clear(sl,b)[0]))
	var c: Array = _clear(sl,b)
	check(sl.launches >= 1 and low[0] > -0.1 and c[1] and absf(c[0]) < 0.1,"Real loop: after a plain landing the block is still on the slab (lowest %.2f, now %.2f over the top)" % [low[0],c[0]])
	# A slam: flung clear, never below the slab's top while over it, and down on the far deck.
	_put(8.0,0.0,sl)
	await _play(30)
	_put(-0.8,5.0,sl)
	await _play(2)
	m.slam(27.0,20.0)
	var start: Vector3 = b.global_position
	var launches: int = sl.launches
	low[0] = INF
	var top := [0.0]
	await _play(240,func() -> void:
		var cl: Array = _clear(sl,b)
		if cl[1]: low[0] = minf(low[0],cl[0])
		top[0] = maxf(top[0],b.global_position.y-start.y))
	var deck_top: float = sl.to_global(Vector3.ZERO).y
	var far_z: float = sl.to_local(b.global_position).z
	check(sl.launches > launches and top[0] > 1.0 and low[0] > -0.1,"Real loop: a slam flings the block clear (rose %.2f m, lowest %.2f over the slab)" % [top[0],low[0]])
	check(far_z < -sl.length() and absf(b.global_position.y-(deck_top+float(b.get_meta("half")))) < 0.1 and b.linear_velocity.length() < 0.3,"...and it comes to rest on the far deck (z %.2f past the slab's %.2f, y %.2f)" % [far_z,-sl.length(),b.global_position.y])
	# Tilted past its grip, a block slides down the slab and off its low end.
	var slick: Node3D = (load("res://scripts/traps/trap_seesaw_slam.gd") as GDScript).new()
	slick.configure({"grip":0.1,"block_arm":0.2})
	slick.position = Vector3(-60.0,0.0,0.0)
	study.traps.add(slick)
	var sb: RigidBody3D = slick.block
	var z0: float = slick.to_local(sb.global_position).z
	low[0] = INF
	var off := [false]
	await _play(240,func() -> void:
		var cl: Array = _clear(slick,sb)
		if cl[1]: low[0] = minf(low[0],cl[0])
		elif slick.to_local(sb.global_position).z < -slick.length(): off[0] = true)
	check(off[0] and low[0] > -0.1 and sb.global_position.y < slick.to_global(Vector3.ZERO).y-2.0,"Real loop: grip 0.1 under the tilt's %.2f, the block slides down and off the low end (from z %.2f; lowest %.2f over the top)" % [tan(float(slick.knob("max_tilt"))),z0,low[0]])
	# A block dropped on the high end launches the pilot on the plate.
	var dr: Node3D = study.traps.named("seesaw_drop")
	_put(dr.launch_z()+1.0,0.5,dr)
	var vy := [0.0]
	var blow := [INF]
	await _play(900,func() -> void:
		vy[0] = maxf(vy[0],m.velocity.y)
		var cl: Array = _clear(dr,dr.block)
		if dr.released and cl[1]: blow[0] = minf(blow[0],cl[0]))
	var ledge_y: float = dr.to_global(Vector3(0.0,dr.ledge_top(),0.0)).y
	# A 12 m/s landing sinks a few cm for a step (and the slab's pose is read
	# a step ahead of the block's); through the slab would be its own size.
	check(dr.drops >= 1 and vy[0] > 8.0 and blow[0] > -0.15,"Real loop: the dropped block launches the pilot (vy %.1f) and lands on the slab (lowest %.2f over the top)" % [vy[0],blow[0]])
	check(m.grounded and absf(m.feet.y-ledge_y) < 0.3,"...he comes down on the high ledge (feet y %.2f, ledge %.2f)" % [m.feet.y,ledge_y])
