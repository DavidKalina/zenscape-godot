extends SceneTree
## The on-foot pieces (docs/design/foot-interactables.md) in the
## interactables yard (studies/interactables_yard.tscn), headless, the pilot
## driven by scripted input through the character study's frame:
##   - set on a bobbing slab he stays on it standing, carried as it bobs and
##     sags, and it sinks under him; jumped onto from the deck he lands and
##     stays; left, it springs back up;
##   - set on a drifting slab (sliding across the way, then the turning
##     one) he rides it, staying put on it while it carries him metres, and
##     turns with the turning one;
##   - run and jumped into the first rope he takes hold, pumps it up, lets
##     go on the upswing and flies further than his running jump goes, out
##     to the far deck (catching the second rope on the way and pumping it
##     too);
##   - jumped onto a balustrade from the high deck he slides it down the
##     stair, balancing, gaining pace, flung off its foot faster than he
##     runs, and landed crouched he slides on.
## Then the aqueduct isle's route (scripts/interactables/
## aqueduct_foot_route.gd): run off the near rim beside the aqueduct, he
## takes the first rope and swings rope to rope across the gap onto the far
## island; from its rim he boards the ferry and rides it back across.
##   godot --headless --path . --script tests/test_foot_interactables.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Yard = preload("res://studies/interactables_yard.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const Balustrade = preload("res://scripts/interactables/balustrade.gd")
const Route = preload("res://scripts/interactables/aqueduct_foot_route.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor
var pieces: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(180.0).timeout.connect(func() -> void: push_error("foot interactables test timed out"); quit(2))
	study = load("res://studies/interactables_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	pieces = study.pieces
	check(pieces != null and pieces.slabs.size() == 8 and pieces.ropes.size() == 2 and pieces.rails.size() == 2,"The yard has its pieces: 4 bobbing and 4 drifting slabs, 2 ropes, 2 balustrades")
	_bob()
	_drift()
	var run_reach := _running_jump()
	_rope(run_reach)
	_rail()
	study.queue_free()
	await process_frame
	await _isle_route()
	print("foot interactables: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _input(want: Vector2, jump := false, crouch := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch

func _tick(n: int) -> void:
	for i in range(n): study.tick(DT)

## Jump held from the deck's edge (z under `edge`) to the top of the arc,
## as a player holds it.
var _held_for := 0
func _jumping(edge: float) -> bool:
	if m.grounded and m.feet.z < edge:
		_held_for = 1
		return true
	if _held_for > 0 and not m.grounded and m.velocity.y > 0.0:
		_held_for += 1
		return true
	_held_for = 0
	return false

## Set down on `slab`'s top, standing still.
func _set_on(slab: Node3D, off := Vector3.ZERO) -> void:
	study.place(slab.transform*off,Vector2(0.0,-1.0))
	_input(Vector2.ZERO)
	_tick(2)

func _bob() -> void:
	var slab: Node3D = pieces.slabs[1]
	_set_on(slab,Vector3(0.4,0.0,0.2))
	var local: Vector3 = slab.transform.affine_inverse()*m.feet
	var off := 0
	var drift := 0.0
	var lowest := 0.0
	var top := -INF
	var bottom := INF
	for i in range(240):
		_tick(1)
		if pieces.on != slab or not m.grounded: off += 1
		drift = maxf(drift,(slab.transform.affine_inverse()*m.feet).distance_to(local))
		lowest = minf(lowest,slab.sag)
		top = maxf(top,m.feet.y)
		bottom = minf(bottom,m.feet.y)
	check(off == 0,"Stood on a bobbing slab 4 s he stays on it (off %d frames)" % off)
	check(drift < 0.05,"...not skating on it (%.3f m from where he stood, on it)" % drift)
	check(lowest < -0.15,"...it sinks under him (%.2f m)" % lowest)
	check(top-bottom > 0.1,"...and he goes up and down with it (%.2f m)" % (top-bottom))
	# Jumped onto from the deck: lands, stays.
	study.place(Vector3(-30.5,0.0,3.0),Vector2(0.0,-1.0))
	_tick(2)
	var first: Node3D = pieces.slabs[0]
	var landed := false
	for i in range(180):
		_input(Vector2(0.0,-1.0),_jumping(-1.6))
		_tick(1)
		if m.grounded and pieces.on == first:
			landed = true
			break
	_input(Vector2.ZERO)
	var stayed := 0
	for i in range(120):
		_tick(1)
		if pieces.on == first and m.grounded: stayed += 1
	check(landed and stayed == 120,"Jumped onto a bobbing slab from the deck he lands on it and stays (%s, %d of 120 frames)" % [landed,stayed])
	# Left (set back on the deck), it springs back up past its rest.
	var sag_on: float = first.sag
	study.place(Vector3(-30.0,0.0,2.0),Vector2(0.0,-1.0))
	var highest := -INF
	for i in range(120):
		_tick(1)
		highest = maxf(highest,first.sag)
	check(sag_on < -0.1 and highest > 0.0,"Left, it springs back up past its rest (from %.2f m to %+.2f m)" % [sag_on,highest])

func _drift() -> void:
	var slab: Node3D = pieces.slabs[4]
	_set_on(slab,Vector3(0.3,0.0,0.0))
	var local: Vector3 = slab.transform.affine_inverse()*m.feet
	var from := m.feet
	var off := 0
	var drift := 0.0
	var travelled := 0.0
	for i in range(240):
		_tick(1)
		if pieces.on != slab or not m.grounded: off += 1
		drift = maxf(drift,(slab.transform.affine_inverse()*m.feet).distance_to(local))
		travelled = maxf(travelled,Vector2(m.feet.x-from.x,m.feet.z-from.z).length())
	check(off == 0 and drift < 0.08,"Riding a drifting slab 4 s he stays put on it (off %d frames, %.3f m on it)" % [off,drift])
	check(travelled > 3.0,"...while it carries him %.1f m" % travelled)
	var spinner: Node3D = pieces.slabs[6]
	_set_on(spinner,Vector3(2.2,0.0,0.0))
	var facing := m.facing
	var turned := 0.0
	var spin_off := 0
	var spun_drift := 0.0
	local = spinner.transform.affine_inverse()*m.feet
	for i in range(180):
		var was := m.facing
		_tick(1)
		turned += wrapf(m.facing-was,-PI,PI)
		if pieces.on != spinner: spin_off += 1
		spun_drift = maxf(spun_drift,(spinner.transform.affine_inverse()*m.feet).distance_to(local))
	check(spin_off == 0 and spun_drift < 0.08 and absf(turned) > 1.0,"On the turning slab's arm he stays (%.3f m on it) and turns with it (%.2f rad)" % [spun_drift,turned])

## A full running jump off the rope deck's edge onto the floor beyond the
## start deck: its reach.
func _running_jump() -> float:
	study.place(Vector3(-20.0,0.0,6.0),Vector2(1.0,0.0))
	_input(Vector2(1.0,0.0))
	_tick(60)
	_input(Vector2(1.0,0.0),true)
	var from := m.feet
	_tick(1)
	var reach := 0.0
	for i in range(120):
		_tick(1)
		if m.grounded:
			reach = Vector2(m.feet.x-from.x,m.feet.z-from.z).length()
			break
	_input(Vector2.ZERO)
	check(reach > 2.0,"A running jump reaches %.2f m" % reach)
	return reach

func _rope(run_reach: float) -> void:
	var first: Node3D = pieces.ropes[0]
	var second: Node3D = pieces.ropes[1]
	study.place(Vector3(6.0,0.0,3.0),Vector2(0.0,-1.0))
	_input(Vector2(0.0,-1.0))
	var caught := false
	var t := 0
	while t < 180 and not caught:
		# Jump at the deck's edge.
		_input(Vector2(0.0,-1.0),_jumping(-1.6))
		_tick(1)
		t += 1
		caught = first.held()
	check(caught,"Run and jumped off the deck, he takes hold of the first rope (%s)" % m.hold)
	if not caught: return
	check(m.hold == "swing" and m.on_ledge(),"...hanging from it (hold %s)" % m.hold)
	var release := _pump_and_go(first,1.5,0.4)
	var reached_second := false
	for i in range(120):
		_input(Vector2(0.0,-1.0))
		_tick(1)
		if second.held():
			reached_second = true
			break
	check(reached_second,"Let go on the upswing, he flies on and takes hold of the second rope")
	if not reached_second: return
	var from := _pump_and_go(second,1.5,0.5)
	var landed := Vector3.INF
	for i in range(180):
		_input(Vector2(0.0,-1.0))
		_tick(1)
		if m.grounded:
			landed = m.feet
			break
	var throw := Vector2(landed.x-from.x,landed.z-from.z).length() if landed != Vector3.INF else 0.0
	check(landed != Vector3.INF and landed.z < -16.0,"...pumped and let go again, he lands on the far deck (z %.1f)" % landed.z)
	check(throw > run_reach*1.5,"...the throw (%.2f m from letting go) goes well past a running jump (%.2f m)" % [throw,run_reach])
	check(release.length() > 6.0,"...let go at %.1f m/s" % release.length())

## Pumped (the stick along the swing, in time) for up to `seconds`, then let
## go on a forward upswing: where he let go from (the first) and its pace
## (from the second rope the place is given back instead).
func _pump_and_go(r: Node3D, seconds: float, angle_at: float) -> Vector3:
	var frames := int(seconds*60.0)
	for i in range(frames):
		var v: Vector3 = r.velocity
		_input(Vector2(0.0,-1.0) if v.z <= 0.0 else Vector2(0.0,1.0))
		_tick(1)
	# On to a forward upswing past `angle_at` from the plumb, then Space.
	for i in range(240):
		var v: Vector3 = r.velocity
		var angle: float = (r.hands-r.anchor).angle_to(Vector3.DOWN)
		var ahead: bool = r.hands.z < r.anchor.z
		if ahead and v.z < 0.0 and angle > angle_at: break
		_input(Vector2(0.0,-1.0) if v.z <= 0.0 else Vector2(0.0,1.0))
		_tick(1)
	var at := m.feet
	var pace: Vector3 = r.velocity
	_input(Vector2(0.0,-1.0),true)
	_tick(1)
	_input(Vector2(0.0,-1.0),false)
	check(not r.held() and not m.on_ledge(),"...let go (%.1f m/s, %.0f° up)" % [pace.length(),rad_to_deg(atan2(pace.y,Vector2(pace.x,pace.z).length()))])
	if r == pieces.ropes[0]: return pace
	return at

func _rail() -> void:
	var rail: Node3D = pieces.rails[1]
	var head: Vector3 = rail.rail[0]
	# Beside it on the high deck, the stick toward it, a jump.
	var inward := Vector3(-signf(head.x-24.0),0.0,0.0)
	study.place(Vector3(head.x,4.48,head.z)+inward*0.7+Vector3(0.0,0.0,0.3),Vector2(0.0,1.0))
	_tick(2)
	var toward := Vector2(-inward.x,0.0)
	_input(toward,true)
	var on := false
	for i in range(60):
		_tick(1)
		if i == 6: _input(toward,false)
		if rail.held():
			on = true
			break
	check(on,"Jumped from the high deck onto the balustrade, he slides it")
	if not on: return
	var start := absf(float(rail.pace))
	var fell := false
	var flung := false
	var most := 0.0
	var min_balance := 0.0
	for i in range(600):
		# Balanced: the stick across against his lean, a little tucked.
		var t: Vector3 = rail.way(rail.s)*signf(rail.pace)
		var flat := Vector2(t.x,t.z).normalized()
		var right := Vector2(-flat.y,flat.x)
		_input(flat*0.4-right*clampf(float(rail.balance)*2.5,-1.0,1.0),false,true)
		var was_held: bool = rail.held()
		_tick(1)
		most = maxf(most,absf(float(rail.pace)))
		min_balance = maxf(min_balance,absf(float(rail.balance)))
		if was_held and not rail.held():
			flung = rail.s >= rail.length-0.01
			fell = not flung
			break
	check(not fell and flung,"...balanced the length of it, flung off its foot (balance at most %.2f)" % min_balance)
	check(most > start+4.0,"...gaining pace down it (from %.2f m/s to %.2f m/s)" % [start,most])
	var landed_pace := 0.0
	for i in range(120):
		_tick(1)
		if m.grounded:
			landed_pace = m.speed()
			break
	check(landed_pace > PilotMotor.RUN,"...landed crouched he slides on faster than he runs (%.2f m/s, %s)" % [landed_pace,m.move])
	_input(Vector2.ZERO)

## The aqueduct isle's route: the rope chain over the gap, the ferry back.
func _isle_route() -> void:
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.get("isle_up"): await process_frame
	m = study.motor
	pieces = study.foot_pieces
	check(pieces != null and pieces.ropes.size() == 3 and pieces.slabs.size() >= 4 and pieces.rails.size() >= 2,"The aqueduct isle has its route: ropes, slabs, balustrades")
	if pieces == null: return
	var spot: Array = Route.SPOTS.ropes
	study.place(spot[0],spot[1])
	var caught := [false,false,false]
	var on := -1
	var far := Vector3.INF
	for t in range(900):
		var want := Vector2(0.0,-1.0)
		var edge: bool = study.ground.height_from(Vector2(m.feet.x,m.feet.z-0.6),m.feet.y) < m.feet.y-1.0
		var jump := _jumping_if(edge)
		on = -1
		for i in range(3):
			if pieces.ropes[i].held(): on = i
		if on >= 0:
			var r: Node3D = pieces.ropes[on]
			want = Vector2(0.0,-1.0) if r.velocity.z <= 0.0 else Vector2(0.0,1.0)
			jump = r.hands.z < r.anchor.z and r.velocity.z < 0.0 and (r.hands-r.anchor).angle_to(Vector3.DOWN) > 0.45 and r.velocity.length() > 7.0
		_input(want,jump)
		_tick(1)
		for i in range(3):
			if pieces.ropes[i].held(): caught[i] = true
		if m.grounded and m.feet.z < -40.0:
			far = m.feet
			break
		if m.feet.y < 20.0: break
	check(caught[0] and caught[1] and caught[2],"Run off the near rim he takes the first rope and swings rope to rope (%s)" % [caught])
	check(far != Vector3.INF,"...and lets go onto the far island (%s)" % far)
	# The ferry, from the far rim when it comes in.
	spot = Route.SPOTS.ferry
	study.place(spot[0],spot[1])
	var ferry: Node3D = pieces.slabs[0]
	var boarded := false
	for t in range(1200):
		var near: bool = ferry.transform.origin.z < -40.3
		_input(Vector2(0.0,1.0) if near or not m.grounded else Vector2.ZERO,_jumping_if(near and m.feet.z > -42.3))
		_tick(1)
		if pieces.on == ferry:
			boarded = true
			break
		if m.feet.y < 20.0: break
	_input(Vector2.ZERO)
	var stayed := true
	for k in range(600):
		_tick(1)
		if pieces.on != ferry: stayed = false
		if ferry.transform.origin.z > -27.5: break
	check(boarded and stayed and m.feet.z > -29.5,"From the far rim he boards the ferry and rides it back across (z %.1f)" % m.feet.z)

## As `_jumping`, from the ground when `go`.
func _jumping_if(go: bool) -> bool:
	if m.grounded and go:
		_held_for = 1
		return true
	if _held_for > 0 and not m.grounded and m.velocity.y > 0.0:
		_held_for += 1
		return true
	_held_for = 0
	return false
