extends SceneTree
## The Broken Viaduct's perches through the real play loop: the crossing yard's
## own
## `_process` frames (not scripted), the pilot driven by Input actions (the
## stick, Space, Shift/C), the gust arrows firing on their own.
##   - The far perch fires at a pilot on the later piers (and the stair
##     beside them).
##   - Off pier LEFT_FROM, a running jump opened into the sail carries him
##     to the left perch's first stone; he hops onto the sinking stone, which
##     sinks under him (and he with it), then onto the last stone; walked off
##     it, Shift/C in the air slams the perch's top: it is down (its horn
##     tipped over), no tell and no shot at him on the piers for
##     DISABLE_TIME, then it comes back and fires again.
##   - A low perch fires at him gliding under the sail; the hit throws him
##     out of the sail into a tumble, and after the beat Space opens the
##     sail again.
##   godot --headless --path . --script tests/test_crossing_viaduct_perches.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const GustArrows = preload("res://studies/crossings/gust_arrows.gd")
var failures := 0
var study: Node3D
var m: PilotMotor
var c: Node3D
var arrows: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("viaduct perches test timed out"); quit(2))
	Engine.max_fps = 60
	study = load("res://studies/crossing_yard.tscn").instantiate()
	root.add_child(study)
	current_scene = study
	while not study.walk_ready or not study.isle_up: await process_frame
	await physics_frame
	m = study.motor
	c = study.crossing
	arrows = c.arrows
	print("MEASURE routes %s" % [c.routes])
	print("MEASURE sail gap %.2f (plain long jump %.2f, sail reach about %.2f), slam over %.2f" % [c.sail_gap,c.long_reach(m.long_speed,c.ROUTE_DROP),c.sail_reach(c.ROUTE_DROP),c.slam_over])
	await _far_perch()
	await _route_and_slam()
	await _low_perch()
	_release()
	print("viaduct perches: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func world(p: Vector3) -> Vector3:
	return c.position+p

func local(p: Vector3) -> Vector3:
	return p-c.position

func _release() -> void:
	for a: StringName in [&"move_forward",&"move_back",&"move_left",&"move_right",&"walk_jump",&"walk_crouch",&"walk_twirl"]:
		Input.action_release(a)

## The perches' clocks reset (no ball in flight, none cooling down).
func _quiet() -> void:
	for l in arrows.launchers:
		l.air_blast.phase = "idle"
		l.air_blast.cooldown_left = 0.0
		l.air_blast.since_shot = INF
		l.air_blast.balls.clear()
		l.air_blast.shocks.clear()
	arrows.hits.clear()

func _face(dir: Vector2) -> void:
	if dir.length() > 0.01: study.set("_yaw",PilotMotor.facing_of(dir.normalized()))

## The stick held toward `to` (world, flat).
func _steer_to(to: Vector3) -> void:
	_face(Vector2(to.x-m.feet.x,to.z-m.feet.z))
	Input.action_press(&"move_forward")

func _tap(action: StringName, frames := 3) -> void:
	for i in range(frames):
		Input.action_press(action)
		await process_frame
	Input.action_release(action)

# --- The far perch -----------------------------------------------------------------

func _far_perch() -> void:
	for k: int in [7,9]:
		_release()
		var top: Vector3 = c.pier_tops[k]
		study.place(world(top),c.beats()[1].face)
		_quiet()
		var shots0: int = arrows.launchers[1].air_blast.shots
		var first := -1.0
		for i in range(60*4):
			await process_frame
			if first < 0.0 and arrows.launchers[1].air_blast.shots > shots0: first = i/60.0
			if not arrows.hits.is_empty(): break
		var by_far: Array = arrows.hits.filter(func(h: Dictionary) -> bool: return h.launcher == 1)
		print("MEASURE pier %d: the far perch fired after %.2f s, hits %s" % [k,first,arrows.hits])
		check(first >= 0.0 and not by_far.is_empty(),"Standing on pier %d, the far perch winds up, fires and its ball reaches him (%d hit(s) from it)" % [k+1,by_far.size()])
	# On the stair beside the upper piers.
	_release()
	var stair := _stair_top_near(c.pier_tops[8])
	study.place(world(stair),c.beats()[1].face)
	_quiet()
	var shots1: int = arrows.launchers[1].air_blast.shots
	for i in range(60*3): await process_frame
	check(arrows.launchers[1].air_blast.shots > shots1,"On the safe stair beside pier 9, the far perch fires at him too (%d shot(s))" % (arrows.launchers[1].air_blast.shots-shots1))

## The stair's tread top beside `pier` (local), found by a ray.
func _stair_top_near(pier: Vector3) -> Vector3:
	var p: Vector3 = c.at(pier,c.TURN_B,0.0,c.SAFE_ASIDE)
	var hit := study.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(world(p+Vector3.UP*8.0),world(p-Vector3.UP*8.0),1))
	return local(hit.position) if not hit.is_empty() else p

# --- The route out and the slam ----------------------------------------------------

## The foot piece under `st` (a route stone), by where it hung.
func _slab_of(st: Dictionary) -> Node3D:
	for s: Node3D in study.stones.slabs:
		if s.rest.origin.distance_to(world(st.at)) < 0.1: return s
	return null

func _on(slab: Node3D) -> bool:
	return m.grounded and study.stones.on == slab

func _route_and_slam() -> void:
	var r: Dictionary = c.routes.left
	var stones: Array = r.stones
	var a := _slab_of(stones[0])
	var b := _slab_of(stones[1])
	var cc := _slab_of(stones[2])
	check(a != null and b != null and cc != null and b.get_script().resource_path.ends_with("sink_slab.gd"),"The left perch's route: a plain stone, a sinking stone, a plain stone")
	if a == null or b == null or cc == null: return
	# The traverse with the arrows off (the perch fires on its route; the
	# test wants the route itself).
	study.set_hazards(false)
	var from: Vector3 = r.from
	var w: Vector2 = c.way(float(r.deg))
	# On the pier, back from its edge, facing out along the route.
	_release()
	study.place(world(c.at(from,float(r.deg),-0.6)),w)
	for i in range(10): await process_frame
	# Run at the edge, jump on it, the sail at the jump's top, steered at the
	# first stone; folded over it.
	var jumped := false
	var sailed := false
	var landed_a := false
	var press := 0
	for i in range(60*6):
		_steer_to(a.global_position)
		var out_d := Vector2(local(m.feet).x-from.x,local(m.feet).z-from.z).dot(w)
		if not jumped and m.grounded and out_d > float(r.edge)-0.35:
			press = 3
			jumped = true
		elif jumped and not sailed and not m.grounded and m.velocity.y < 0.5 and press == 0:
			press = 3
			sailed = true
		elif sailed and m.move == "sail" and Vector2(m.feet.x-a.global_position.x,m.feet.z-a.global_position.z).length() < 0.6 and press == 0:
			press = 3
		if press > 0:
			Input.action_press(&"walk_jump")
			press -= 1
		else: Input.action_release(&"walk_jump")
		await process_frame
		if _on(a):
			landed_a = true
			break
		if m.feet.y < world(from).y-10.0: break
	_release()
	print("MEASURE route: jumped %s, sailed %s, landed on the first stone %s (feet %s local, stone %s)" % [jumped,sailed,landed_a,local(m.feet),local(a.global_position)])
	check(landed_a and sailed,"A running jump off pier %d opened into the sail carries him over the %.1f m gap onto the first stone" % [c.LEFT_FROM+1,c.sail_gap])
	if not landed_a: return
	for i in range(20): await process_frame
	# Hop onto the sinking stone.
	var on_b := await _hop(a,b)
	check(on_b,"A running hop takes him onto the sinking stone")
	if not on_b: return
	var y0: float = m.feet.y
	var sunk0: float = b.sunk
	for i in range(45): await process_frame
	print("MEASURE sinking: stood 0.75 s, the stone sank %.2f m, his feet %.2f m" % [b.sunk-sunk0,y0-m.feet.y])
	check(b.sunk > 0.25 and y0-m.feet.y > 0.25 and _on(b),"Stood on, the sinking stone sinks (%.2f m in 0.75 s) and takes him down with it (%.2f m)" % [b.sunk-sunk0,y0-m.feet.y])
	var on_c := await _hop(b,cc)
	check(on_c,"From the sunk stone, a hop still makes the last stone")
	if not on_c: return
	for i in range(40): await process_frame
	check(b.sunk < 0.05,"Left, the sinking stone rises back to where it hung (%.2f m sunk)" % b.sunk)
	# Arrows on; a running hop off the last stone toward the perch's top,
	# Shift/C in the air once over it.
	study.set_hazards(true)
	_quiet()
	var l: GustArrows.Launcher = arrows.launchers[0]
	var top := world(r.top)
	var slams0: int = study.slam.lands
	var pressed := false
	var hopped := false
	var dir := Vector2(top.x-cc.global_position.x,top.z-cc.global_position.z).normalized()
	var air_at := 0.0
	for i in range(60*3):
		_steer_to(top)
		var d := Vector2(m.feet.x-cc.global_position.x,m.feet.z-cc.global_position.z).dot(dir)
		if not hopped and m.grounded and d > cc.size.z*0.5-0.35:
			hopped = true
			Input.action_press(&"walk_jump")
		elif hopped and not m.grounded: Input.action_release(&"walk_jump")
		var over: bool = Vector2(m.feet.x-top.x,m.feet.z-top.z).length() < c.PERCH_TOP*0.5
		if not pressed and hopped and not m.grounded and over and m.feet.y-top.y > study.slam.LOW*m.size+0.1:
			pressed = true
			air_at = m.feet.y-top.y
			Input.action_press(&"walk_crouch")
		await process_frame
		if pressed and m.grounded: break
	_release()
	for i in range(3): await process_frame
	print("MEASURE slam: pressed %s at %.2f m over the top, slam lands %d -> %d, last %s, perch down %s (%.1f s left), horn disabled %s, feet %s local" % [pressed,air_at,slams0,study.slam.lands,study.slam.last,l.is_down(),l.down_left,l.horn.is_disabled(),local(m.feet)])
	check(study.slam.lands > slams0 and absf(local(m.feet).y-r.top.y) < 0.2,"A hop off the last stone and Shift/C over the perch's top: he slams onto it")
	check(l.is_down() and l.horn.is_disabled() and l.slams == 1,"The slam disables the left perch (down %.1f s, its horn tipped over)" % l.down_left)
	check(arrows.silenced.size() > 0 and arrows.silenced[arrows.silenced.size()-1].launcher == 0,"The yard hears it silenced (%s)" % [arrows.silenced])
	# On the piers in its zone: nothing from it until it's back.
	var down_at := l.down_left
	_release()
	study.place(world(c.pier_tops[1]),c.beats()[1].face)
	var shots0: int = l.air_blast.shots
	var tells := 0
	var t := 0.0
	while l.is_down() and t < GustArrows.DISABLE_TIME+1.0:
		await process_frame
		t += 1.0/60.0
		if l.is_down() and l.air_blast.phase == "windup": tells += 1
		if m.feet.y < world(c.turn_mid).y-3.0:
			study.place(world(c.pier_tops[1]),c.beats()[1].face)
	print("MEASURE down: %.2f s (from %.2f left), tells %d, shots %d" % [t,down_at,tells,l.air_blast.shots-shots0])
	check(tells == 0 and l.air_blast.shots == shots0 and absf(t-down_at) < 0.2,"Down %.1f s: no tell, no shot from it at him on pier 2" % t)
	var back := -1.0
	for i in range(60*5):
		await process_frame
		if l.air_blast.shots > shots0:
			back = i/60.0
			break
		if m.feet.y < world(c.turn_mid).y-3.0: study.place(world(c.pier_tops[1]),c.beats()[1].face)
	check(back >= 0.0 and not l.horn.is_disabled(),"Then it's back: it fires at him again %.2f s later" % back)
	_release()

## A running hop from the stone `from` to the stone `to`: back to the far
## edge, run, Space at the near edge. True stood on `to`.
func _hop(from: Node3D, to: Node3D) -> bool:
	var dir := Vector2(to.global_position.x-from.global_position.x,to.global_position.z-from.global_position.z).normalized()
	var half: float = from.size.z*0.5
	var pressed := 0
	var jumped := false
	for i in range(60*3):
		_steer_to(to.global_position)
		var d := Vector2(m.feet.x-from.global_position.x,m.feet.z-from.global_position.z).dot(dir)
		if not jumped and m.grounded and d > half-0.35:
			jumped = true
			pressed = 3
		if pressed > 0:
			Input.action_press(&"walk_jump")
			pressed -= 1
		else: Input.action_release(&"walk_jump")
		await process_frame
		if jumped and _on(to):
			_release()
			for k in range(4): await process_frame
			return true
		if m.feet.y < from.global_position.y-6.0: break
	_release()
	return false

# --- A low perch at a sailing pilot ------------------------------------------------

func _low_perch() -> void:
	_release()
	var k := 0
	var l: GustArrows.Launcher = arrows.launchers[3+k]
	var top: Vector3 = c.low_perch_at(k)
	# In the air off the left of the piers, high over the low perch's band,
	# heading for the left turn updraft past it.
	var draft: Dictionary = c.updrafts()[1]
	var goal: Vector3 = world(draft.base)
	var start: Vector3 = c.at(top,c.TURN_B,6.0,10.0,14.0)
	study.place(world(start),Vector2(goal.x-world(start).x,goal.z-world(start).z).normalized())
	_quiet()
	for i in range(8): await process_frame
	await _tap(&"walk_jump")
	for i in range(4): await process_frame
	check(m.move == "sail","Off the route in the air, Space opens the sail (move %s)" % m.move)
	var hit := {}
	var shots0: int = l.air_blast.shots
	for i in range(60*8):
		_steer_to(goal)
		await process_frame
		for h: Dictionary in arrows.hits:
			if h.launcher == 3+k: hit = h
		if not hit.is_empty(): break
		if m.move != "sail": break
	_release()
	print("MEASURE low perch %d at %s: shots %d (pops %d, bursts %d), hit %s, move %s, feet %s local" % [k,top,l.air_blast.shots-shots0,l.air_blast.breaks,l.air_blast.lands,hit,m.move,local(m.feet)])
	check(l.air_blast.shots > shots0,"The low perch fires at him gliding by under the sail")
	check(not hit.is_empty() and hit.kind == "thrown" and hit.how == "under the sail" and m.move == "tumble","Its ball throws him out of the sail into a tumble (%s)" % [hit])
	if m.move != "tumble": return
	var waited := 0
	while waited < 60 and waited/60.0 < study.KNOCK_SAIL+0.1:
		waited += 1
		await process_frame
	await _tap(&"walk_jump")
	for i in range(3): await process_frame
	check(m.move == "sail" and m.stunned == "","After the beat (%.2f s), Space opens the sail again (move %s)" % [waited/60.0,m.move])
	# Fair: none of them fires at a pilot standing on the route.
	_release()
	study.place(world(c.turn_mid),c.beats()[1].face)
	_quiet()
	var low_shots := 0
	for j in range(3,arrows.launchers.size()): low_shots -= arrows.launchers[j].air_blast.shots
	for i in range(60*3): await process_frame
	for j in range(3,arrows.launchers.size()): low_shots += arrows.launchers[j].air_blast.shots
	check(low_shots == 0,"Standing on the turn platform, no low perch fires (%d shot(s))" % low_shots)
