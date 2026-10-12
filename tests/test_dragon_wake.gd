extends SceneTree
## The roost dragon's wake (scripts/dragon_wake.gd, docs/design/dragon-wake/
## round1.md), headless, with --dragon-wake: he stirs (the eyes open, the
## head lifts off its shelf), takes off, flies his circuit (well out from
## the roost, once over the aqueduct isle, high over its ground, clear of
## the motif isles), never grips, blows or holds anything, and lands back
## in his coil, its frame and pose as before, the eyes shut. No bone jumps
## between frames as the coil turns to flight and back. And the schedule on
## its own: once a world day at WAKE_HOUR, not in the opening minutes.
##   godot --headless --path . --script tests/test_dragon_wake.gd
const LaunchArgs = preload("res://scripts/launch_args.gd")
const MotifSky = preload("res://scripts/kit_isle/motif_sky.gd")
const DragonWake = preload("res://scripts/dragon_wake.gd")
const DT := 1.0/60.0
## Longest the whole wake may take (s), and the clearances asked: over the
## aqueduct isle's ground (m, any bone), and off a motif isle's circle (m)
## below its top plus ISLE_OVER.
const LONGEST := 300.0
const HOME_CLEAR := 15.0
const ISLE_OVER := 40.0
## The fastest any bone may move in a frame (m/s): past a wing tip's
## downstroke in flight (some 170 m/s), so a pose snapping between coil and
## flight shows.
const POP := 200.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(600.0).timeout.connect(func() -> void: push_error("dragon wake test timed out"); quit(2))
	LaunchArgs.set_override(["--no-title","--dragon-wake"])
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready or study.roost_dragon == null: await process_frame
	await physics_frame
	await physics_frame
	_schedule()
	var dragon: Node3D = study.roost_dragon
	var wake: RefCounted = dragon.wake
	check(wake != null and not wake.out(),"The roost dragon has a wake and sleeps at load")
	var coil: Transform3D = wake.coil_xf
	var sk: Skeleton3D = dragon.skeleton
	var head_i: int = dragon._bone["head"]
	var asleep_pose := _pose_of(sk)
	var head_asleep := (sk.global_transform*sk.get_bone_global_pose(head_i)).origin
	var head_lifted := head_asleep
	var seen: Array = []
	var states: Dictionary = {}
	var far := 0.0
	var home_near := INF
	var home_clear := INF
	var isle_clear := INF
	var isle_worst := ""
	var haze_out := false
	var shown_out := true
	var pop := 0.0
	var fastest := {}
	var pop_at := ""
	var was := _points(sk)
	var home: Vector3 = wake.home
	var places := MotifSky.places()
	var t := 0.0
	while t < LONGEST:
		study._roost_frame(DT)
		t += DT
		var phase: String = wake.phase
		if seen.is_empty() or seen.back() != phase: seen.append(phase)
		states[str(dragon.state)] = true
		var now := _points(sk)
		for i in range(now.size()):
			var v := now[i].distance_to(was[i])/DT
			fastest[phase] = maxf(float(fastest.get(phase,0.0)),v)
			if v > pop:
				pop = v
				pop_at = "%s, %s at %.1f s" % [phase,sk.get_bone_name(i),t]
		was = now
		if phase == "stirring":
			var h := (sk.global_transform*sk.get_bone_global_pose(head_i)).origin
			if h.y > head_lifted.y: head_lifted = h
		if phase == "flying":
			var at := dragon.global_position
			far = maxf(far,at.distance_to(coil.origin))
			var haze: CPUParticles3D = dragon.roost._haze
			if haze.emitting: haze_out = true
			if not dragon.is_visible_in_tree(): shown_out = false
			home_near = minf(home_near,Vector2(at.x-home.x,at.z-home.z).length())
			# Every bone over the aqueduct isle's ground, where it has ground.
			if Vector2(at.x-home.x,at.z-home.z).length() < 260.0:
				for p in now:
					var ground: Variant = study.sky.ground(Vector3(p.x,400.0,p.z))
					if ground != null: home_clear = minf(home_clear,p.y-float(ground))
			# Off the motif isles: every bone out of an isle's circle or over its top.
			if int(t/DT)%4 == 0:
				for place: Array in places:
					var mid: Vector3 = place[1]
					var reach := float(place[2])
					for p in now:
						if p.y > mid.y+ISLE_OVER: continue
						var off := Vector2(p.x-mid.x,p.z-mid.z).length()-reach
						if off < isle_clear:
							isle_clear = off
							isle_worst = str(place[0])
		if phase == "asleep" and seen.size() > 1: break
	print("dragon wake: phases %s; states %s; %.0f s; out to %.0f m from the roost; %.0f m from the aqueduct isle's middle at the nearest; %.1f m over its ground at the least; %.1f m off a motif isle's circle at the least (%s); the head lifted %.1f m; fastest bone %.0f m/s (%s; by phase %s)" % [str(seen),str(states.keys()),t,far,home_near,home_clear,isle_clear,isle_worst,head_lifted.y-head_asleep.y,pop,pop_at,str(fastest)])
	check(seen == ["asleep","stirring","rising","flying","settling","asleep"],"He stirs, takes off, flies, lands and sleeps, in that order")
	check(head_lifted.y-head_asleep.y > 2.0,"Stirring, his head lifts off its shelf (%.1f m)" % (head_lifted.y-head_asleep.y))
	check(far > 500.0,"He flies well out from the roost (%.0f m)" % far)
	check(not haze_out and shown_out,"Out, the roost's breath haze is off and he is shown wherever he is")
	check(home_near < 80.0,"His circuit passes over the aqueduct isle (%.0f m from its middle)" % home_near)
	check(home_clear > HOME_CLEAR,"Every bone stays over %.0f m above the aqueduct isle's ground (%.1f m)" % [HOME_CLEAR,home_clear])
	check(isle_clear > 0.0,"No bone comes within a motif isle's circle below its top + %.0f m (%.1f m, %s)" % [ISLE_OVER,isle_clear,isle_worst])
	check(not (states.has("grabbing") or states.has("clinging") or states.has("leaving")) and (dragon.grip as Dictionary).is_empty() and dragon.gale == null,"He never grips anything (no grab, cling or grip, and no gale)")
	check(pop < POP,"No bone jumps between frames through the wake (fastest %.0f m/s)" % pop)
	check(wake.phase == "asleep" and str(dragon.state) == "roosting" and not dragon.awake(),"He is back asleep on his roost")
	check(dragon.global_transform.origin.distance_to(coil.origin) < 0.01 and dragon.global_transform.basis.is_equal_approx(coil.basis),"Back in his coil's frame")
	var back := _pose_of(sk)
	var worst := 0.0
	for i in range(back.size()): worst = maxf(worst,(back[i] as Quaternion).angle_to(asleep_pose[i] as Quaternion))
	# The breath and the tail's twitch move on; the coil's line is the same.
	check(worst < 0.6,"His pose is the coil again (the most a bone differs from before: %.2f rad, the breath's and the twitch's)" % worst)
	check((dragon._eye_points as Array).is_empty(),"His eyes are shut again")
	print("PASS: dragon wake" if failures == 0 else "FAIL: dragon wake (%d)" % failures)
	LaunchArgs.set_override(null)
	quit(1 if failures > 0 else 0)

## The schedule on its own (a wake with no dragon, a clock of our own): once
## a world day as WAKE_HOUR passes, never before FIRST_AFTER s, never while
## the day is held.
func _schedule() -> void:
	var w: RefCounted = DragonWake.new()
	var now := [11.0]
	w.hours = func() -> float: return float(now[0])
	var got: Array = []
	for step: Array in [[60.0,11.0],[90.0,15.4],[100.0,15.6],[300.0,20.0],[400.0,39.4],[401.0,39.6],[402.0,40.0],[500.0,-1.0],[501.0,63.6]]:
		w._since = float(step[0])
		now[0] = float(step[1])
		got.append(w._due())
	check(got == [false,false,false,false,false,true,false,false,false],"He wakes once a day as %.1f h passes, not in the first %.0f s, not while the day is held (%s)" % [DragonWake.WAKE_HOUR,DragonWake.FIRST_AFTER,str(got)])

## Every bone's place in the world.
func _points(sk: Skeleton3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var xf := sk.global_transform
	for i in range(sk.get_bone_count()): out.append(xf*sk.get_bone_global_pose(i).origin)
	return out

func _pose_of(sk: Skeleton3D) -> Array:
	var out: Array = []
	for i in range(sk.get_bone_count()): out.append(sk.get_bone_pose_rotation(i))
	return out
