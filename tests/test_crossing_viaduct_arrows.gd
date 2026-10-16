extends SceneTree
## The Broken Viaduct's gust arrows (studies/crossings/gust_arrows.gd) through
## the real play
## loop: the crossing yard's own `_process` frames (not scripted), the
## pilot driven by Input actions (the stick and Space), the perch firing
## on its own cadence.
##   - Pumping across the piers, a shot reaches him and knocks him off the
##     pier line (thrown: down off the piers or out to the side).
##   - Standing on the safe stair, the piers between him and the perch,
##     its shots pop on the stone and never touch him.
##   - Standing on a pier, a shot only shoves him: he keeps his feet.
##   - Arrows off (K, --arrows=0): no tells, no shots.
##   godot --headless --path . --script tests/test_crossing_viaduct_arrows.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
var failures := 0
var study: Node3D
var m: PilotMotor
var c: Node3D
var arrows: Node3D
var blast: DragonAirBlast

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(170.0).timeout.connect(func() -> void: push_error("viaduct arrows test timed out"); quit(2))
	# Game-like frames: the loop's own delta, near 60 a second.
	Engine.max_fps = 60
	study = load("res://studies/crossing_yard.tscn").instantiate()
	root.add_child(study)
	current_scene = study
	while not study.walk_ready or not study.isle_up: await process_frame
	await physics_frame
	m = study.motor
	c = study.crossing
	arrows = c.arrows
	blast = arrows.launchers[0].air_blast
	check(arrows != null and study.hazards_on and blast.on,"The viaduct's gust arrows are built and on by default")
	_cover_map()
	await _pumping()
	await _cover()
	await _off()
	_release()
	print("viaduct arrows: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func world(p: Vector3) -> Vector3:
	return c.position+p

func local(p: Vector3) -> Vector3:
	return p-c.position

func _release() -> void:
	for a: StringName in [&"move_forward",&"move_back",&"move_left",&"move_right",&"walk_jump",&"walk_crouch",&"walk_twirl"]:
		Input.action_release(a)

## Placed, the camera behind him along `face`, the perch's clock reset
## (no tell under way, no balls).
func _put(at: Vector3, face: Vector2) -> void:
	_release()
	study.place(world(at),face)
	study.set("_yaw",PilotMotor.facing_of(face))
	blast.phase = "idle"
	blast.cooldown_left = 0.0
	blast.balls.clear()
	blast.shocks.clear()
	arrows.hits.clear()

## Which standing spots (each pier top, the safe stair beside each) stone
## hides from the perch: a ray from its mouth to his middle.
func _cover_map() -> void:
	var space := study.get_world_3d().direct_space_state
	var mouth: Vector3 = arrows.launchers[0].mouth_at()
	var piers := []
	var stair := []
	for k in range(c.pier_tops.size()):
		var chest: Vector3 = world(c.pier_tops[k])+Vector3.UP*0.55*DragonAirBlast.walker_tall()
		piers.append(not space.intersect_ray(PhysicsRayQueryParameters3D.create(mouth,chest,1)).is_empty())
		var feet := _stair_at(k)
		stair.append(feet != Vector3.INF and not space.intersect_ray(PhysicsRayQueryParameters3D.create(mouth,world(feet)+Vector3.UP*0.55*DragonAirBlast.walker_tall(),1)).is_empty())
	print("MEASURE perch at %s (local); hidden from it standing on the pier tops %s, on the safe stair beside them %s" % [c.archer_at(),piers,stair])

## The safe stair's top beside pier `k` (local; INF none).
func _stair_at(k: int) -> Vector3:
	var t: Vector3 = c.pier_tops[k]
	var s := Vector2(t.x-c.turn_mid.x,t.z-c.turn_mid.z).length()
	var over: Vector3 = world(c.at(c.turn_mid,c.TURN_B,s,c.SAFE_ASIDE,20.0))
	var hit := study.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(over,over+Vector3.DOWN*40.0,1))
	return local(hit.position) if not hit.is_empty() else Vector3.INF

## The pier field's heading, his place along it and across it (local).
func _along_aside(feet: Vector3) -> Vector2:
	var face: Vector2 = c.way(c.TURN_B)
	var l := local(feet)
	var d := Vector2(l.x-c.turn_mid.x,l.z-c.turn_mid.z)
	return Vector2(d.dot(face),d.dot(c.right_of(face)))

## Which top (or the plinth: its count) his feet stand on, -1 none.
func _top_under(feet: Vector3) -> int:
	var l := local(feet)
	if absf(l.y-c.slot_foot.y) < 0.05: return c.pier_tops.size()
	for k in range(c.pier_tops.size()):
		var t: Vector3 = c.pier_tops[k]
		if absf(l.y-t.y) < 0.05 and Vector2(l.x-t.x,l.z-t.z).length() < 1.6: return k
	return -1

## From the turn platform, the stick held up the piers, Space pressed on
## the platform's edge and on each landing (the pump), till the arrows
## throw him or he reaches the plinth.
func _pumping() -> void:
	var beat: Dictionary = c.beats()[1]
	var face: Vector2 = beat.face
	_put(beat.at,face)
	var shots0: int = blast.shots
	var landed_on := -1
	var press_left := 0
	var since_press := 99
	var thrown_at := -1.0
	var thrown_feet := Vector3.INF
	var lowest := INF
	var max_aside := 0.0
	var reached := []
	var mid_air_at_hit := false
	for i in range(900):
		study.set("_yaw",PilotMotor.facing_of(face))
		var aa := _along_aside(m.feet)
		if thrown_at < 0.0:
			Input.action_press(&"move_forward")
			var on := _top_under(m.feet) if m.grounded else -1
			since_press += 1
			if m.grounded and reached.is_empty() and aa.x > c.TURN_PAD.y*0.5-0.4 and press_left == 0: press_left = 4
			if on >= 0 and on != landed_on:
				landed_on = on
				reached.append(on)
				if on == c.pier_tops.size(): break
			# Space on every landing (the pump), on a new top or the same.
			if on >= 0 and press_left == 0 and since_press > 8:
				press_left = 4
				since_press = 0
		else: _release()
		if press_left > 0:
			Input.action_press(&"walk_jump")
			press_left -= 1
		else: Input.action_release(&"walk_jump")
		var hits_before: int = arrows.hits.size()
		await process_frame
		if arrows.hits.size() > hits_before and thrown_at < 0.0:
			var hit: Dictionary = arrows.hits[arrows.hits.size()-1]
			if hit.kind == "thrown":
				thrown_at = float(i)
				thrown_feet = m.feet
				mid_air_at_hit = true
		if thrown_at >= 0.0:
			lowest = minf(lowest,local(m.feet).y)
			max_aside = maxf(max_aside,absf(_along_aside(m.feet).y))
			if m.grounded and float(i)-thrown_at > 30.0 and not m.downed(): break
			if float(i)-thrown_at > 300.0: break
	_release()
	var shots: int = blast.shots-shots0
	print("MEASURE pumping: reached %s, shots %d, hits %s, thrown at %s, lowest after %.2f (floor %.2f, turn platform %.2f), most aside %.2f, ended %s" % [reached,shots,arrows.hits,thrown_feet,lowest,c.floor_y(),c.turn_mid.y,max_aside,local(m.feet)])
	check(shots >= 1,"Pumping up the piers, the perch winds up and fires at him (%d shot(s))" % shots)
	check(mid_air_at_hit and thrown_at >= 0.0,"A shot reaches him mid-pump and throws him (%s)" % [arrows.hits])
	var off: bool = lowest < c.turn_mid.y-2.0 or max_aside > c.PIER_TOP.x
	check(off and _top_under(m.feet) < 0,"Thrown, he is knocked off the pier line (lowest %.2f, most aside %.2f, ends on no pier: %s)" % [lowest,max_aside,local(m.feet)])

## Standing still on the safe stair (the piers between him and the
## perch): the perch fires, its balls pop on the stone, nothing touches
## him. Then standing on a pier: shoved, he keeps his feet.
func _cover() -> void:
	var face: Vector2 = c.way(c.TURN_B)
	_put(_stair_at(2)+Vector3.UP*0.05,face)
	for i in range(10): await process_frame
	var stood := local(m.feet)
	var shots0: int = blast.shots
	var breaks0: int = blast.breaks
	var knocks0: int = m.knocks
	for i in range(300):
		study.set("_yaw",PilotMotor.facing_of(face))
		await process_frame
		if blast.shots-shots0 >= 2 and blast.balls.is_empty(): break
	var shots: int = blast.shots-shots0
	var breaks: int = blast.breaks-breaks0
	print("MEASURE cover on the safe stair: shots %d, pops %d, hits %s, knocks %d, stood %s, at %s" % [shots,breaks,arrows.hits,m.knocks-knocks0,stood,local(m.feet)])
	check(shots >= 1 and breaks >= shots,"Standing on the safe stair behind the piers, every shot pops on the stone (%d shots, %d pops)" % [shots,breaks])
	check(arrows.hits.is_empty() and m.knocks == knocks0 and local(m.feet).distance_to(stood) < 0.2,"Nothing reaches him: still standing where he was (%s)" % [arrows.hits])
	# On a pier, standing: shoved, not thrown.
	_put(c.pier_tops[5],face)
	for i in range(240):
		study.set("_yaw",PilotMotor.facing_of(face))
		await process_frame
		if not arrows.hits.is_empty() and m.grounded and i > 60: break
	for i in range(60): await process_frame
	print("MEASURE standing on pier 5: hits %s, ends %s, on top %d" % [arrows.hits,local(m.feet),_top_under(m.feet)])
	check(not arrows.hits.is_empty() and arrows.hits[0].kind == "pushed","Standing on a pier, a shot shoves him (%s)" % [arrows.hits])
	check(_top_under(m.feet) == 5 and not m.recovering(),"Shoved, he keeps his feet on his pier (%s)" % [local(m.feet)])

## Off (as K or --arrows=0): pumping up the field, no tell, no shot.
func _off() -> void:
	study.set_hazards(false)
	var beat: Dictionary = c.beats()[1]
	var face: Vector2 = beat.face
	_put(beat.at,face)
	var shots0: int = blast.shots
	var tells := 0
	for i in range(240):
		study.set("_yaw",PilotMotor.facing_of(face))
		Input.action_press(&"move_forward")
		if blast.phase == "windup": tells += 1
		await process_frame
	_release()
	check(blast.shots == shots0 and tells == 0,"Arrows off: no tell, no shot (%d shots, %d tell frames)" % [blast.shots-shots0,tells])
	study.set_hazards(true)
