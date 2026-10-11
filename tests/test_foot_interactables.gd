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
##   - run and jumped into the first rope he takes hold (his hands meeting
##     it; a jump passing 0.5 m from it doesn't), pumps it up and lets go
##     on the upswing: plainly, he falls short of the second rope; with the
##     twirl at the top of the arc he reaches it; from the second, with the
##     sail, the third; from the third, the far deck;
##   - hopped onto a balustrade's coping from the high deck he stands on
##     it; crouched there he surfs down the stair on it (only the motor's
##     slope surf, carving to hold the coping), gaining pace, off its foot
##     faster than he runs; and carved hard across, he drops off its side.
## Then the aqueduct isle's route (scripts/interactables/
## aqueduct_foot_route.gd): from its --foot-at=ropes spot (facing the
## first rope, the gap beyond) he runs and jumps to the first rope, swings,
## let go plainly falls short of the second; again, lets go with a twirl
## to the second, and from it onto the far island;
## from its rim he boards the ferry and rides it back across.
##   godot --headless --path . --script tests/test_foot_interactables.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Yard = preload("res://studies/interactables_yard.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const Route = preload("res://scripts/interactables/aqueduct_foot_route.gd")
const DT := 1.0/60.0
const TOP_Y := 30.0
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
	check(pieces != null and pieces.slabs.size() == 8 and pieces.ropes.size() == 3 and pieces.rails.size() == 2,"The yard has its pieces: 4 bobbing and 4 drifting slabs, 3 ropes, 2 balustrades")
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
	var ropes: Array = pieces.ropes
	# A jump that passes beside the first rope (0.5 m off it) doesn't take it.
	study.place(Vector3(6.55,0.0,3.0),Vector2(0.0,-1.0))
	var missed := not _run_at(ropes[0],90)
	check(missed,"A jump passing 0.5 m beside the first rope doesn't take hold (no magnet)")
	_tick(30)
	var caught := _catch_first()
	check(caught,"Run and jumped off the deck, he takes hold of the first rope (%s)" % m.hold)
	if not caught: return
	check(m.hold == "swing" and m.on_ledge(),"...hanging from it (hold %s)" % m.hold)
	var gap := absf(ropes[1].anchor.z-ropes[0].anchor.z)
	var release := _pump_and_go(ropes[0],6.0,0.75)
	var plain := _fly_to(ropes[1],"")
	check(not plain,"Let go plainly at the best angle, he falls short of the second rope %.1f m on" % gap)
	check(release.length() > 6.0,"...let go at %.1f m/s" % release.length())
	caught = _catch_first()
	_pump_and_go(ropes[0],6.0,0.75)
	var twirled := _fly_to(ropes[1],"twirl")
	check(twirled,"Let go with a twirl at the top of the arc, he reaches the second rope")
	if not twirled: return
	var gap2 := absf(ropes[2].anchor.z-ropes[1].anchor.z)
	_pump_and_go(ropes[1],4.0,0.75)
	var sailed := _fly_to(ropes[2],"sail")
	check(sailed,"From the second, let go and the sail popped, he glides %.1f m to the third and takes it" % gap2)
	if not sailed: return
	var from := _pump_and_go(ropes[2],6.0,0.75,true)
	var landed := Vector3.INF
	for i in range(240):
		_input(Vector2(0.0,-1.0))
		_tick(1)
		if m.grounded:
			landed = m.feet
			break
	var throw := Vector2(landed.x-from.x,landed.z-from.z).length() if landed != Vector3.INF else 0.0
	check(landed != Vector3.INF and landed.z < -47.0 and landed.y > -0.5,"...pumped and let go again, he lands on the far deck (z %.1f)" % landed.z)
	check(throw > run_reach*1.5,"...the throw (%.2f m from letting go) goes well past a running jump (%.2f m)" % [throw,run_reach])

## Run along -z and jumped at the deck's edge: whether `r` took him.
func _run_at(r: Node3D, frames: int) -> bool:
	for t in range(frames):
		_input(Vector2(0.0,-1.0),_jumping(-1.6))
		_tick(1)
		if r.held(): return true
		if m.feet.y < -3.0: break
	return false

func _catch_first() -> bool:
	study.place(Vector3(6.0,0.0,3.0),Vector2(0.0,-1.0))
	_input(Vector2.ZERO)
	_tick(2)
	# The rope let go of swings on a while: waited for till it hangs still.
	var r: Node3D = pieces.ropes[0]
	for i in range(1800):
		if (r.velocity as Vector3).length() < 0.3 and (r.hands-r.anchor).angle_to(Vector3.DOWN) < 0.06: break
		_tick(1)
	var ok := _run_at(pieces.ropes[0],180)
	if not ok: print("  (no catch: feet %s, rope end %s, cool %.2f)" % [m.feet,pieces.ropes[0].hands,pieces.ropes[0]._cool])
	return ok

## Flown on from a release (`how`: "" plain, "twirl" or "sail" at the top
## of the arc), the stick on along -z: whether `r` took him.
func _fly_to(r: Node3D, how: String) -> bool:
	var done := false
	for i in range(420):
		var top := not done and m.velocity.y <= 0.0
		if top: done = true
		study.script_twirl = how == "twirl" and top
		_input(Vector2(0.0,-1.0),how == "sail" and top)
		_tick(1)
		study.script_twirl = false
		if r.held(): return true
		if m.grounded or m.feet.y < float(r.anchor.y)-float(r.length)-3.0: return false
	return false

## Pumped (the stick along the swing, in time) for up to `seconds`, then let
## go on a forward upswing past `angle_at` from the plumb: its pace (or,
## `where`, where he let go from).
func _pump_and_go(r: Node3D, seconds: float, angle_at: float, where := false) -> Vector3:
	var frames := int(seconds*60.0)
	for i in range(frames):
		var v: Vector3 = r.velocity
		_input(Vector2(0.0,-1.0) if v.z <= 0.0 else Vector2(0.0,1.0))
		_tick(1)
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
	return at if where else pace

## A balustrade is stone: hopped onto, surfed down by the motor's own
## slope surf, carved off.
func _rail() -> void:
	var rail: Node3D = pieces.rails[1]
	var head: Vector3 = rail.rail[0]
	var down3: Vector3 = rail.way(0.5)
	var down := Vector2(down3.x,down3.z).normalized()
	var side := Vector2(-down.y,down.x)
	# Walked up its head from the high deck: a step onto the newel's
	# pedestal, on up the eased coping.
	study.place(Vector3(head.x,4.48,head.z-1.5),down)
	_tick(2)
	var walked := false
	for i in range(90):
		_input(down*0.5)
		_tick(1)
		if m.grounded and pieces.on_rail == rail:
			walked = true
			break
	_input(Vector2.ZERO)
	_tick(10)
	check(walked and pieces.on_rail == rail and m.grounded,"Walked up its head from the high deck, he steps onto the coping and stands on it")
	# Beside its eased head on the high deck, a step and a hop sideways onto it.
	var inward := Vector2(signf(24.0-head.x),0.0)
	study.place(Vector3(head.x,4.48,head.z+0.5)+Vector3(inward.x,0.0,0.0)*0.6,down)
	_tick(2)
	var on := false
	for i in range(80):
		# The jump with the stick toward it, let go over it (as he'd land).
		_input(-inward if i < 14 else Vector2.ZERO,i < 14)
		_tick(1)
		if m.grounded and pieces.on_rail == rail:
			on = true
			break
	_input(Vector2.ZERO)
	_tick(20)
	on = on and pieces.on_rail == rail and m.grounded
	check(on,"Hopped sideways from the high deck onto its eased head, he lands and stands on its coping (no catch)")
	if not on: return
	# Walked on over the top of the flight, then crouched, the stick down
	# it: the motor's surf takes him down.
	var crest: float = rail.rail[0].distance_to(rail.rail[1])+0.3
	var surfed_down := false
	var start := -1.0
	var most := 0.0
	var off_side := false
	var off_end := false
	var flew := Vector3.ZERO
	for i in range(600):
		var near: Array = rail.nearest(m.feet)
		var t: Vector3 = rail.way(float(near[0]))
		var f := Vector2(t.x,t.z).normalized()
		var right := Vector2(-f.y,f.x)
		# Hold the line: the stick on down it, carved back toward the middle.
		var p := Vector2(m.feet.x,m.feet.z)-Vector2(rail.point(float(near[0])).x,rail.point(float(near[0])).z)
		var v := Vector2(m.velocity.x,m.velocity.z)
		var steer := clampf(-p.dot(right)*4.0-(v.dot(right)/maxf(v.length(),1.0))*3.0,-1.0,1.0)
		# Up over its eased head on foot, then crouched down the flight.
		var tuck := float(near[0]) > crest
		if tuck and start < 0.0: start = m.speed()
		_input((f+right*steer).normalized(),false,tuck)
		_tick(1)
		if tuck: most = maxf(most,m.speed())
		if tuck and m.move == "slide": surfed_down = true
		if not m.grounded:
			var where: Array = rail.nearest(m.feet)
			off_end = float(where[0]) >= rail.length-0.3
			off_side = not off_end
			flew = m.velocity
			break
	check(surfed_down,"...run on over the top of the flight and crouched, he surfs it (the motor's slope surf)")
	check(off_end and not off_side,"...the length of it, holding the coping, off its foot (left it %.1f m along of %.1f)" % [float(rail.nearest(m.feet)[0]),rail.length])
	check(most > start+4.0 and most > PilotMotor.RUN*1.8,"...gaining pace down it (from %.2f m/s to %.2f m/s)" % [start,most])
	check(Vector2(flew.x,flew.z).length() > PilotMotor.RUN,"...and flies off its foot at %.2f m/s, its shape's launch" % Vector2(flew.x,flew.z).length())
	var landed_pace := 0.0
	var landed_move := ""
	for i in range(120):
		_tick(1)
		if m.grounded:
			_tick(6)
			landed_pace = m.speed()
			landed_move = m.move
			break
	check(landed_pace > PilotMotor.RUN and landed_move == "slide","...landed crouched he slides on faster than he runs (%.2f m/s, %s)" % [landed_pace,landed_move])
	# Carved hard across on the upper flight: off its side.
	var mid: Vector3 = rail.point(rail.length*0.3)
	study.place(mid,down)
	_tick(2)
	var surfed := false
	var dropped := false
	var gone := 0.0
	for i in range(240):
		var lean := 1.0 if i > 25 else 0.0
		_input((down+side*lean).normalized() if lean > 0.0 else down,false,true)
		_tick(1)
		surfed = surfed or m.move == "slide"
		if not m.grounded or pieces.on_rail != rail:
			var where: Array = rail.nearest(m.feet)
			dropped = float(where[0]) < rail.length-0.3
			gone = float(where[1])
			break
	_tick(30)
	check(surfed and dropped,"Surfing it, a hard carve across drops him off its side (%.2f m off its line, %.1f m down)" % [gone,mid.y-m.feet.y])
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
	check(pieces != null and pieces.ropes.size() == 2 and pieces.slabs.size() >= 4 and pieces.rails.size() >= 2,"The aqueduct isle has its route: ropes, slabs, balustrades")
	if pieces == null: return
	var spot: Array = Route.SPOTS.ropes
	study.place(spot[0],spot[1])
	_tick(2)
	var first: Node3D = pieces.ropes[0]
	var second: Node3D = pieces.ropes[1]
	var to_first: Vector3 = first.hands-m.feet
	var facing := PilotMotor.forward(m.facing)
	check(Vector2(to_first.x,to_first.z).length() < 12.0 and facing.dot(Vector2(to_first.x,to_first.z).normalized()) > 0.95,"--foot-at=ropes starts him %.1f m from the first rope, facing it" % Vector2(to_first.x,to_first.z).length())
	var took := _isle_first(first)
	check(took,"Run from there and jumped, he takes hold of the first rope")
	if not took: return
	_pump_and_go(first,5.0,0.75)
	check(not _fly_to(second,""),"...let go plainly, he falls short of the second (%.1f m on)" % absf(second.anchor.z-first.anchor.z))
	study.place(spot[0],spot[1])
	_input(Vector2.ZERO)
	for i in range(1800):
		if (first.velocity as Vector3).length() < 0.3 and (first.hands-first.anchor).angle_to(Vector3.DOWN) < 0.06: break
		_tick(1)
	took = _isle_first(first)
	if not took: return
	_pump_and_go(first,5.0,0.75)
	var twirled := _fly_to(second,"twirl")
	check(twirled,"...let go with a twirl at the top of the arc, he takes the second (%.1f m on)" % absf(second.anchor.z-first.anchor.z))
	if not twirled: return
	_pump_and_go(second,3.0,0.6)
	var far := Vector3.INF
	for t in range(240):
		_input(Vector2(0.0,-1.0))
		_tick(1)
		if m.grounded:
			far = m.feet
			break
	check(far != Vector3.INF and far.z < -40.0 and far.y > TOP_Y-0.5,"...and lets go onto the far island (%s)" % far)
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

## Run from where he stands to the isle's first rope and jumped at it:
## whether he took hold.
func _isle_first(first: Node3D) -> bool:
	for t in range(240):
		var to: Vector2 = Vector2(first.anchor.x-m.feet.x,first.anchor.z-m.feet.z)
		_input(to.normalized(),_jumping_if(to.length() < 1.6))
		_tick(1)
		if first.held(): return true
	return false

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
