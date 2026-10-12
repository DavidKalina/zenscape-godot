extends SceneTree
## suite: slow
## The airship ferry (scripts/kit_isle/airship_ferry.gd, docs/design/
## airship-ferry/round1.md), headless, on the aqueduct isle with its motif
## isles stood up:
##   - it flies by default, its loop resting at home (the aqueduct isle's
##     south edge) and at the bell spires, its deck level with the turf
##     there and a hand off the edge;
##   - its body moves with it at once (a ray this frame finds the deck where
##     it is now);
##   - round its whole lap its hull, cabin and envelope never meet an
##     isle's ground or rock or the parked plane, and its loop keeps clear
##     of the serpent's way and the other ships' loops;
##   - a walker on its foredeck is carried home to the bell spires: aboard
##     and on the deck every frame, never sliding on it (his place in the
##     ship's frame stays put) or jittering, a jump on the moving deck lands
##     back on it; and at the bell spires he walks off onto their turf;
##   - on foot at the home stop he walks aboard as it rests there;
##   - --ferry-aboard starts him on its foredeck at home, about to leave;
##     --ferry-aboard=bell coming in to the bell spires, their isle stood.
##   godot --headless --path . --script tests/test_airship_ferry.gd
const IsleSky = preload("res://studies/aqueduct_isle_sky.gd")
const Ferry = preload("res://scripts/kit_isle/airship_ferry.gd")
const AirshipBuild = preload("res://scripts/airship_build.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const DT := 1.0/60.0
## What the ship must keep off: the isles' solids and turf, the parked plane.
const WORLD := 1 | (1 << 11) | (1 << 13)
## The most his place on the deck may drift over the whole crossing (m),
## and in any one frame (m).
const DRIFT := 0.05
const JITTER := 0.004
var failures := 0
var study: Node3D
var sky: Node3D
var ferry: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(400.0).timeout.connect(func() -> void: push_error("airship ferry test timed out"); quit(2))
	LaunchArgs.set_override(["--no-title"])
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	sky = study.sky
	sky.flush()
	await physics_frame
	await physics_frame
	ferry = sky.ferry
	check(ferry != null,"The ferry flies by default")
	if ferry == null:
		_end()
		return
	ferry.manual = true
	_loop()
	_body_follows()
	_clear_of_isles()
	_clear_of_ways()
	_ride()
	_walk_aboard()
	for n: String in ["home","bell"]: await _flag(n)
	_end()

func _end() -> void:
	LaunchArgs.set_override(null)
	print("PASS: airship ferry" if failures == 0 else "FAIL: airship ferry (%d)" % failures)
	quit(1 if failures > 0 else 0)

## Frames of the scene: the serpent, the ferry, then the pilot.
func _frames(seconds: float, each := Callable()) -> void:
	for i in range(int(round(seconds/DT))):
		sky.serpent.advance(DT)
		ferry.step(DT)
		study.tick(DT)
		if each.is_valid(): each.call()

# --- The loop --------------------------------------------------------------------

func _loop() -> void:
	var names: Array = ferry.stops.map(func(s: Dictionary) -> String: return str(s.name))
	print("ferry: loop %.0f m, lap %.0f s, stops %s" % [ferry._length,ferry.lap,str(names)])
	check(names == ["home","bell"],"It rests at home and at the bell spires (%s)" % str(names))
	check(ferry.lap > 90.0 and ferry.lap < 240.0,"A lap takes a few minutes (%.0f s)" % ferry.lap)
	var space := study.get_world_3d().direct_space_state
	# Each stop: the deck level with the turf beside it, a hand off its edge.
	for n: String in ["home","bell"]:
		ferry.set_clock(ferry.clock_before(n,-1.0))
		check(ferry.resting() == n and ferry.pace == 0.0,"%s: it rests there" % n)
		var w: Dictionary = ferry.wait_spot(n)
		var deck: Vector3 = ferry.deck_point()
		var turf: Variant = _ground(space,Vector3(w.stand.x,deck.y+3.0,w.stand.z))
		check(turf != null and absf(float(turf)-deck.y) < 0.2,"%s: the deck (%.2f) is level with the turf beside it (%s)" % [n,deck.y,str(turf)])
		# Across from the deck's edge toward the turf: how far to ground.
		var out: Vector3 = (Vector3(w.stand.x,deck.y,w.stand.z)-deck)
		out.y = 0.0
		out = out.normalized()
		var gap := INF
		for k in range(40):
			var p: Vector3 = deck+out*(AirshipBuild.HULL.x*Ferry.SCALE*0.9+k*0.05)
			var hit: Dictionary = _hit(space,p+Vector3.UP*1.0,p-Vector3.UP*1.0,WORLD)
			if not hit.is_empty() and hit.rid != ferry.body.get_rid():
				gap = k*0.05
				break
		check(gap < 0.9,"%s: the turf is a hand off the deck's edge (%.2f m)" % [n,gap])

## The body moves with it at once: a ray this frame finds the deck.
func _body_follows() -> void:
	var space := study.get_world_3d().direct_space_state
	var worst := 0.0
	for t: float in [3.0,47.0,71.0,120.0]:
		ferry.set_clock(t)
		var deck: Vector3 = ferry.deck_point()
		var hit := _hit(space,deck+Vector3.UP*0.5,deck-Vector3.UP*0.5,1)
		if hit.is_empty() or hit.rid != ferry.body.get_rid(): worst = INF
		else: worst = maxf(worst,absf((hit.position as Vector3).y-deck.y))
	check(worst < 0.02,"Its body moves with it at once (the deck found within %.3f m)" % worst)

## Its hull, cabin and envelope never meet the isles or the parked plane.
func _clear_of_isles() -> void:
	var space := study.get_world_3d().direct_space_state
	var shapes: Array = []
	for c: Node in ferry.body.get_children():
		if c is CollisionShape3D: shapes.append(c)
	var q := PhysicsShapeQueryParameters3D.new()
	q.collision_mask = WORLD
	var exclude: Array[RID] = [ferry.body.get_rid()]
	for a: Dictionary in sky.airships:
		for b: Node in (a.ship as Node).find_children("*","CollisionObject3D",true,false): exclude.append((b as CollisionObject3D).get_rid())
	for b: Node in sky.serpent.find_children("*","CollisionObject3D",true,false): exclude.append((b as CollisionObject3D).get_rid())
	q.exclude = exclude
	var hits: Array = []
	var t := 0.0
	while t < ferry.lap:
		var pose: Transform3D = ferry.pose_at(t)
		for c: CollisionShape3D in shapes:
			q.shape = c.shape
			q.transform = pose*c.transform
			var found := space.intersect_shape(q,4)
			for f: Dictionary in found:
				var who: Node = f.collider
				hits.append("t %.1f %s at %s meets %s" % [t,c.shape.get_class(),str(pose.origin),who.get_path() if who != null else "?"])
		t += 0.5
	for h: String in hits.slice(0,12): print("  ",h)
	check(hits.is_empty(),"Round its lap it meets no isle or the parked plane (%d touches)" % hits.size())

## Its loop keeps clear of the serpent's way and the other ships' loops.
func _clear_of_ways() -> void:
	var serpent: Node3D = sky.serpent
	var worst := INF
	var worst_at := Vector3.ZERO
	var s := 0.0
	while s < ferry._length:
		var p: Vector3 = ferry.point(s)
		var t := 0.0
		while t < serpent.route_length:
			var d: float = p.distance_to(serpent.route_point(t))-serpent.reach_at(t)
			if d < worst:
				worst = d
				worst_at = p
			t += 2.0
		s += 4.0
	# The ferry's farthest from its loop's point: down its hull's keel, out
	# along its envelope's side (the ship's own SCALE).
	print("ferry: nearest the serpent's way %.1f m past its reach, at %s" % [worst,str(worst_at)])
	check(worst > 6.0,"Its loop keeps clear of the serpent's way (%.1f m past the serpent's reach)" % worst)
	var ships := INF
	for a: Dictionary in sky.airships:
		if a.has("ferry"): continue
		for i in range(200):
			var ap: Vector3 = IsleSky._loop(a.points,i/200.0)
			var f := 0.0
			while f < ferry._length:
				ships = minf(ships,ap.distance_to(ferry.point(f)))
				f += 6.0
	check(ships > 80.0,"Its loop keeps well off the other ships' loops (%.0f m)" % ships)

# --- Riding ----------------------------------------------------------------------

## Aboard at home a few seconds before it leaves, carried to the bell
## spires; a jump on the way; off onto their turf.
func _ride() -> void:
	ferry.set_clock(ferry.clock_before("home",-(Ferry.HOLD-Ferry.LEAVE_LEAD)))
	ferry.board_now()
	_frames(0.3)
	var motor: RefCounted = study.motor
	var local: Vector3 = ferry.pose.affine_inverse()*motor.feet
	var start_local := local
	var aboard := true
	var drift := 0.0
	var jitter := 0.0
	var moved := 0.0
	var was: Vector3 = motor.feet
	var face0: float = angle_difference(ferry.heading,motor.facing)
	var turn := 0.0
	var frames := 0
	var jumped := false
	var jump_drift := 0.0
	var landed_local := Vector3.ZERO
	var resting := ""
	var left_home := false
	while frames < int(ferry.lap/DT):
		# A jump on the moving deck once it's under way.
		study.script_jump = not jumped and ferry.pace > 6.0
		if study.script_jump:
			jumped = true
			landed_local = local
		sky.serpent.advance(DT)
		ferry.step(DT)
		study.tick(DT)
		study.script_jump = false
		frames += 1
		moved += motor.feet.distance_to(was)
		was = motor.feet
		var now: Vector3 = ferry.pose.affine_inverse()*motor.feet
		if ferry.riding_on == "deck" and motor.grounded:
			if jumped and jump_drift == 0.0 and landed_local != Vector3.ZERO:
				jump_drift = Vector2(now.x-landed_local.x,now.z-landed_local.z).length()
				landed_local = Vector3.ZERO
				start_local = now
				# In the air he keeps his facing while it turns; from the
				# landing on he turns with it again.
				face0 = angle_difference(ferry.heading,motor.facing)
			jitter = maxf(jitter,now.distance_to(local))
			drift = maxf(drift,now.distance_to(start_local))
		elif landed_local == Vector3.ZERO:
			if aboard: print("  off the deck at %.2f s: on %s, grounded %s, feet %s, deck %s" % [frames*DT,ferry.riding_on,motor.grounded,str(motor.feet),str(ferry.deck_point())])
			aboard = false
		local = now
		if ferry.riding_on == "deck" and landed_local == Vector3.ZERO:
			turn = maxf(turn,absf(angle_difference(angle_difference(ferry.heading,motor.facing),face0)))
		resting = ferry.resting()
		if resting == "": left_home = true
		if left_home and resting == "bell": break
	print("ferry: rode %.0f m in %.0f s, drift %.3f m, worst frame %.4f m, jump came down %.2f m off, facing off the ship's by %.3f rad" % [moved,frames*DT,drift,jitter,jump_drift,turn])
	check(resting == "bell","Carried from home to rest at the bell spires (%s after %.0f s)" % [resting,frames*DT])
	check(aboard,"He stays aboard, on the deck, the whole way")
	check(drift < DRIFT and jitter < JITTER,"He doesn't slide or jitter on the deck as it moves and turns (drift %.3f m, worst frame %.4f m)" % [drift,jitter])
	check(turn < 0.02,"He turns with it (facing off the ship's by %.3f rad)" % turn)
	check(jumped and jump_drift < 0.3,"A jump on the moving deck comes down where it went up (%.2f m off)" % jump_drift)
	check(moved > 250.0,"He went the whole way with it (%.0f m)" % moved)
	# Off: the isle is to port (the ship's -X); walk across onto the turf.
	_frames(0.5)
	var port: Vector3 = -ferry.pose.basis.x
	study.script_want = Vector2(port.x,port.z).normalized()
	_frames(2.0)
	study.script_want = Vector2.ZERO
	_frames(0.5)
	var under: Variant = _ground(study.get_world_3d().direct_space_state,motor.feet+Vector3.UP*0.5)
	var bell: Node3D = _isle("bell_spires")
	var c: Vector3 = bell.circle()
	var off := Vector2(motor.feet.x-c.x,motor.feet.z-c.y).length()
	check(motor.grounded and ferry.riding_on == "still" and off < c.z and under != null and absf(float(under)-41.8) < 0.5,"Off at the bell spires he walks onto their turf (%s, %.0f m from its middle)" % [str(motor.feet),off])

## On foot by the home stop as it comes in: he walks aboard as it rests.
func _walk_aboard() -> void:
	ferry.set_clock(ferry.clock_before("home",Ferry.WAIT_LEAD))
	var w: Dictionary = ferry.wait_spot("home")
	study.place(w.stand,w.face)
	study._last_stood = w.stand
	_frames(0.3)
	check(study.motor.grounded and ferry.riding_on == "still","Waiting on the turf at home (%s)" % str(study.motor.feet))
	var waited := 0
	while ferry.resting() != "home" and waited < 60*60:
		_frames(DT)
		waited += 1
	_frames(1.0)
	var had: int = ferry.boardings
	study.script_want = w.face
	# Across onto the deck, and stop on it.
	var walked := 0
	while ferry.riding_on != "deck" and walked < 120:
		_frames(DT)
		walked += 1
	_frames(0.15)
	study.script_want = Vector2.ZERO
	_frames(0.5)
	check(ferry.riding_on == "deck" and ferry.boardings > had,"He walks aboard as it rests at home (%s, on %s)" % [str(study.motor.feet),ferry.riding_on])
	var before: Vector3 = ferry.pose.affine_inverse()*study.motor.feet
	_frames(Ferry.HOLD+10.0)
	var after: Vector3 = ferry.pose.affine_inverse()*study.motor.feet
	check(ferry.resting() == "" and ferry.riding_on == "deck" and before.distance_to(after) < DRIFT,"It leaves with him aboard (%.3f m drift)" % before.distance_to(after))

# --- The flags ---------------------------------------------------------------

## A fresh isle with --ferry-aboard (=bell): he starts on the foredeck.
func _flag(n: String) -> void:
	study.queue_free()
	await process_frame
	await process_frame
	LaunchArgs.set_override(["--no-title","--ferry-aboard" if n == "home" else "--ferry-aboard=bell"])
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	sky = study.sky
	ferry = sky.ferry
	ferry.manual = true
	var on: float = study.motor.feet.distance_to(ferry.deck_point())
	var until: float = fposmod(float(ferry.stop(n).at)-ferry.clock,ferry.lap)
	var bell: Node3D = _isle("bell_spires")
	if n == "home":
		var leaves: float = fposmod(float(ferry.stop(n).at)+Ferry.HOLD-ferry.clock,ferry.lap)
		check(ferry.resting() == "home" and on < 0.1 and absf(leaves-Ferry.LEAVE_LEAD) < 0.5,"--ferry-aboard: on its foredeck (%.2f m off) at home, %.1f s before it leaves" % [on,leaves])
	else:
		check(ferry.resting() == "" and on < 0.1 and absf(until-Ferry.BELL_LEAD) < 0.5 and bell != null and bell.is_up(),"--ferry-aboard=bell: on its foredeck (%.2f m off), %.0f s out from the bell spires, their isle up" % [on,until])
	_frames(1.0)
	check(ferry.riding_on == "deck" and study.motor.grounded,"--ferry-aboard%s: he stands on the deck (%s)" % ["" if n == "home" else "=bell",ferry.riding_on])

# --- Helpers ---------------------------------------------------------------------

func _hit(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, mask: int) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,mask))

## The ground under `p` (its top, y), not the ferry's deck.
func _ground(space: PhysicsDirectSpaceState3D, p: Vector3) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(p,p-Vector3.UP*20.0,WORLD)
	q.exclude = [ferry.body.get_rid()]
	var hit := space.intersect_ray(q)
	return (hit.position as Vector3).y if not hit.is_empty() else null

func _isle(id: String) -> Node3D:
	for isle: Node3D in sky.motifs.isles:
		if str(isle.motif.id()) == id: return isle
	return null
