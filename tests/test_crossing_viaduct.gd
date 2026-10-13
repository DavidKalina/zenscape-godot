extends SceneTree
## The Broken Viaduct in the crossing yard (studies/crossing_yard.gd,
## studies/crossings/crossing_viaduct.gd), headless, the pilot driven
## through the yard's own step (`tick`: the real motor over the built
## colliders) with the stick and buttons scripted:
##   - the fallen span: a plain running long jump taken at the lip comes
##     down short (no landing, no catch); a chain of three long jumps, each
##     timed on the touch, lands on the far deck (a chain of two: measured);
##   - the piers: a jump onto the first, then a pump on each landing,
##     reaches every pier in turn and the chimney's plinth;
##   - the launch: slid down the slab off the slot's east head, long-jumped
##     off its lip's edge and twirled at the peak, he lands on the far rim
##     (or catches its ledge); not twirled he falls short.
##   godot --headless --path . --script tests/test_crossing_viaduct.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D
var m: PilotMotor
var c: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("crossing viaduct test timed out"); quit(2))
	study = load("res://studies/crossing_yard.tscn").instantiate()
	study.scripted = true
	# Its gust arrows off (tests/test_crossing_viaduct_arrows.gd has them).
	study.hazards_on = false
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	await physics_frame
	m = study.motor
	c = study.crossing
	print("MEASURE numbers %s" % [c.numbers])
	_fallen_span()
	_piers()
	_launch()
	print("crossing viaduct: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## Local (the crossing's frame) to world, and back.
func world(p: Vector3) -> Vector3:
	return c.position+p

func local(p: Vector3) -> Vector3:
	return p-c.position

func _hold(want: Vector2, jump := false, crouch := false, twirl := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.script_twirl = twirl

func _put(at: Vector3, face: Vector2) -> void:
	_hold(Vector2.ZERO)
	study.place(world(at),face)
	for i in range(3): study.tick(DT)

# --- The fallen span -----------------------------------------------------------------

## From `back` m before the lip on the deck, run down it; `jumps` long jumps,
## the first at `first` m before the lip, each after timed on the touch.
## How it ended: {landed (on the far deck), caught, takeoffs (m before the
## lip, local z), paces}.
func _chain(back: float, first: float, jumps: int, twirl := false) -> Dictionary:
	var lip: Vector3 = c.lip
	var rise: float = lip.y/absf(lip.z)
	var from := Vector3(0.0,(absf(lip.z)-back)*rise,lip.z+back)
	_put(from,Vector2(0.0,-1.0))
	var takeoffs := []
	var paces := []
	var longs := 0
	var was_long := false
	var out := {"landed":false,"caught":false}
	var peak_twirled := false
	for i in range(900):
		var z := local(m.feet).z
		var crouch := z < lip.z+first+0.6 or longs > 0
		var jump := false
		if longs == 0: jump = m.grounded and z < lip.z+first and m.move == "slide"
		elif longs < jumps: jump = m.grounded and was_long
		var tw := twirl and longs >= jumps and not m.grounded and m.velocity.y <= 0.0 and not peak_twirled
		_hold(Vector2(0.0,-1.0),jump,crouch,tw)
		if tw: peak_twirled = true
		var long_before := m.move == "long"
		study.tick(DT)
		if m.move == "long" and not long_before:
			longs += 1
			takeoffs.append(snappedf(local(m.feet).z-lip.z,0.01))
			paces.append(snappedf(m.speed(),0.01))
		if m.move == "long": was_long = true
		elif jump: was_long = false
		var l := local(m.feet)
		if m.on_ledge():
			out.caught = true
			break
		if m.grounded and l.z < lip.z-0.5:
			out.landed = absf(l.y-c.far_start.y) < 0.1
			break
		if l.y < c.far_start.y-3.0: break
	out["takeoffs"] = takeoffs
	out["paces"] = paces
	out["longs"] = longs
	return out

func _fallen_span() -> void:
	var plain := _chain(14.0,0.4,1)
	print("MEASURE fallen span, plain long jump at the lip: %s" % [plain])
	check(plain.longs == 1 and not plain.landed and not plain.caught,"A plain running long jump at the lip falls short of the far deck, no catch (%s)" % [plain])
	var plain_twirl := _chain(14.0,0.4,1,true)
	print("MEASURE fallen span, plain long jump twirled at its peak: %s" % [plain_twirl])
	var two := _chain(18.0,5.6,2)
	print("MEASURE fallen span, chain of two: %s" % [two])
	# The chain of three: started where its last takeoff comes near the lip
	# (the first two jumps' reach back), timed on each touch.
	var best := {}
	for first: float in [10.0,10.4,9.6,10.8,9.2]:
		var three := _chain(22.0,first,3)
		print("MEASURE fallen span, chain of three from %.1f m: %s" % [first,three])
		if three.landed and three.longs == 3:
			best = three
			break
	check(not best.is_empty(),"A chain of three long jumps timed on each touch lands on the far deck (%s)" % [best])

# --- The piers ---------------------------------------------------------------------

func _piers() -> void:
	var beat: Dictionary = c.beats()[1]
	var face: Vector2 = beat.face
	_put(beat.at,face)
	var tops: Array = c.pier_tops
	var reached := []
	var pumps := []
	var since := -1.0
	var pad_edge: float = c.TURN_PAD.y*0.5
	var t0: Vector3 = c.turn_mid
	var landed_on := -1
	for i in range(1200):
		var l := local(m.feet)
		var along := Vector2(l.x-t0.x,l.z-t0.z).dot(face)
		var jump := false
		if reached.is_empty() and m.grounded and along > pad_edge-0.4: jump = true
		elif since >= 0.1 and m.grounded: jump = true
		_hold(face,jump)
		study.tick(DT)
		if since >= 0.0: since += DT
		if m.chain == 2 and pumps.size() < reached.size(): pumps.append(true)
		if m.grounded and not jump:
			l = local(m.feet)
			# Which top he stands on.
			var on := -1
			for k in range(tops.size()):
				if absf(l.y-(tops[k] as Vector3).y) < 0.05 and Vector2(l.x-tops[k].x,l.z-tops[k].z).length() < 1.6: on = k
			if absf(l.y-c.slot_foot.y) < 0.05: on = tops.size()
			if on >= 0 and on != landed_on:
				landed_on = on
				reached.append(on)
				since = 0.0
				if on == tops.size(): break
			if l.y < c.turn_mid.y-0.5: break
		if l.y < c.turn_mid.y-2.0: break
	_hold(Vector2.ZERO)
	print("MEASURE piers: reached %s, pumps %d" % [reached,pumps.size()])
	var all := []
	for k in range(tops.size()+1): all.append(k)
	check(reached == all,"A jump then a pump on each landing reaches every pier in turn and the slot's plinth (%s)" % [reached])
	check(pumps.size() >= tops.size(),"Every jump after the first is the pump (%d of %d)" % [pumps.size(),tops.size()])

# --- The launch ----------------------------------------------------------------------

func _launch_run(twirl: bool) -> Dictionary:
	var beat: Dictionary = c.beats()[3]
	var face: Vector2 = beat.face
	_put(beat.at,face)
	var slab_low_y: float = c.lip_end.y
	var jumped := false
	var twirled := false
	var out := {"rim":false,"caught":false,"pace":0.0}
	for i in range(900):
		var l := local(m.feet)
		var crouch: bool = l.y < c.slab_top.y-0.3
		var to_edge := Vector2(c.lip_end.x-l.x,c.lip_end.z-l.z).dot(face)
		var jump := not jumped and m.grounded and absf(l.y-slab_low_y) < 0.05 and m.move == "slide" and to_edge < 0.5
		var tw := twirl and jumped and not twirled and m.velocity.y <= 0.0
		_hold(face,jump,crouch,tw)
		if tw: twirled = true
		study.tick(DT)
		if m.move == "long" and not jumped:
			jumped = true
			out.pace = snappedf(m.speed(),0.01)
		if jumped and m.on_ledge():
			out.caught = true
			break
		if jumped and m.grounded:
			out.rim = c.exit_reached(local(m.feet))
			break
		if local(m.feet).y < c.far_near.y-3.0: break
	out["jumped"] = jumped
	return out

func _launch() -> void:
	var twirled := _launch_run(true)
	print("MEASURE launch twirled: %s" % [twirled])
	check(twirled.jumped and (twirled.rim or twirled.caught),"Slid down the slab, long-jumped off its lip and twirled, he reaches the far rim (%s)" % [twirled])
	var bare := _launch_run(false)
	print("MEASURE launch not twirled: %s" % [bare])
	check(bare.jumped and not bare.rim and not bare.caught,"Not twirled, the launch falls short (%s)" % [bare])
	_hold(Vector2.ZERO)
