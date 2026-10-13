extends SceneTree
## The slam (scripts/slam.gd, scripts/buried_find.gd; docs/design/slam/
## round2.md), headless, on the aqueduct isle with its motif isles:
##   - a fresh crouch press high in the air slams, spending no charge; a
##     press low over the ground is still the slide on landing; crouch held
##     from a long jump never slams; updraft then slam in one airtime;
##   - the drive: a short catch, then down past the fall's pace, his flat
##     pace kept, the slide out of it with crouch held, the jump out of it
##     with Jump buffered;
##   - the hit grows with the height: strength, radius, the drop measured;
##   - the touch pushes a floating slab and swings the belfry's bell; a
##     small slam leaves the jammed cowl, a big one knocks it onto the
##     belfry floor where it's taken;
##   - the buried rune off the north path stays buried (walked over, a slam
##     too far off, a small hop's slam over it) until a slam from a height
##     over it breaks it open; it comes up, is taken and stamped.
##   godot --headless --path . --script tests/test_slam.gd
const DT := 1.0/60.0
const LaunchArgs = preload("res://scripts/launch_args.gd")
const LedgerScript = preload("res://scripts/ledger/ledger.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Slam = preload("res://scripts/slam.gd")
const Updraft = preload("res://scripts/updraft.gd")
const BuriedFind = preload("res://scripts/buried_find.gd")
const Telescope = preload("res://scripts/telescope.gd")
const PartSpots = preload("res://scripts/plane_arc/part_spots.gd")
const PlaneArc = preload("res://scripts/plane_arc/plane_arc.gd")
const Tokens = preload("res://studies/aqueduct_isle_tokens.gd")
## Open turf on the near island, north of the castellum.
const OPEN := Vector3(74.2,30.0,-18.4)

var failures := 0
var study: Node3D
var arc: Node3D
var book: Node
var _file := ""

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("slam test timed out"); quit(2))
	book = LedgerScript.shared()
	book.reset()
	_file = "user://slam_test_%d.json" % OS.get_process_id()
	book.path = _file
	LaunchArgs.set_override(["--no-title"])
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	study.chain_on = false
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	study.sky.flush()
	await physics_frame
	await physics_frame
	arc = study.plane_arc
	check(study.slam != null and study.updraft != null and study.updraft.get("downdraft") == null,"The pilot has the slam beside the updraft, no longer on its key")
	_fresh()
	_low()
	_held()
	_sail()
	_combo()
	_drive()
	_energy()
	_slab()
	await _bell_and_cowl()
	_buried()
	LaunchArgs.set_override(null)
	book.path = ""
	for path in [_file,_file+".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("PASS: slam" if failures == 0 else "FAIL: slam (%d)" % failures)
	quit(1 if failures > 0 else 0)

## Frames of the scene: the pilot, the arc, the buried finds.
func _frames(seconds: float) -> void:
	for i in range(int(round(seconds/DT))): _frame()

func _frame() -> void:
	if arc != null: arc.advance(DT)
	study.tick(DT)
	var tokens: Node3D = study.life.tokens if study.life != null else null
	if tokens != null:
		for dig: Node in tokens.buried.values(): dig.advance(DT)

## Stood at `at`, still, nothing held, the charge empty and unlocked.
func _stand(at: Vector3) -> void:
	study.script_want = Vector2.ZERO
	study.script_jump = false
	study.script_crouch = false
	study.script_wind = false
	study.place(at,Vector2(0.0,-1.0))
	study._last_stood = at
	# Set down by hand: no fall off an edge carries over (the isle's net).
	study._end_fall()
	_frames(0.2)

## In the air `up` m over `at`, falling from rest (flat pace `flat`),
## crouch let go.
func _airborne(at: Vector3, up: float, flat := Vector3.ZERO) -> void:
	_stand(at)
	var m: PilotMotor = study.motor
	m.reset(at+Vector3.UP*up,0.0)
	m.grounded = false
	m.ground_y = at.y
	m.velocity = flat
	study.updraft.reset()
	study.slam.reset()

## Ticks until he's down (or `most` s), the lowest vertical pace seen.
func _until_down(most := 3.0) -> float:
	var low := 0.0
	for i in range(int(most/DT)):
		_frame()
		low = minf(low,study.motor.velocity.y)
		if study.motor.grounded and i > 2: break
	return low

## A slam from `up` m over `at` (crouch pressed fresh there), down: the
## touch ({} if it didn't slam). Crouch is let go after.
func _slam_from(at: Vector3, up: float, flat := Vector3.ZERO) -> Dictionary:
	_airborne(at,up,flat)
	var lands: int = study.slam.lands
	study.script_crouch = true
	_until_down()
	study.script_crouch = false
	_frames(0.3)
	return study.slam.last if study.slam.lands == lands+1 else {}

# --- When it slams ---------------------------------------------------------------------

func _fresh() -> void:
	var u: Node3D = study.updraft
	var s: Node3D = study.slam
	_airborne(OPEN,5.0)
	u.charge = 0.7
	var ups: int = u.updrafts
	study.script_crouch = true
	_frame()
	check(s.phase == "hang" or s.phase == "drive","A fresh crouch press 5 m up slams (%s)" % s.phase)
	check(u.charge > 0.6 and u.updrafts == ups and not u.spent,"No charge spent, nothing locked (%.2f left, locked %s)" % [u.charge,u.spent])
	var lands: int = s.lands
	_until_down()
	check(s.lands == lands+1,"It lands as a slam")
	study.script_crouch = false
	_frames(0.3)
	# Q in the air with crouch held is just the updraft now.
	_airborne(OPEN,1.0)
	study.script_crouch = true
	_frame()
	u.charge = 1.0
	ups = u.updrafts
	study.script_wind = true
	_frame()
	study.script_wind = false
	check(u.updrafts == ups+1 and s.phase == "","Q with crouch held in the air is the updraft (up at %.1f m/s)" % study.motor.velocity.y)
	_until_down()
	study.script_crouch = false
	_frames(0.2)

func _low() -> void:
	var s: Node3D = study.slam
	var m: PilotMotor = study.motor
	_airborne(OPEN,Slam.LOW*m.size*0.6,Vector3(7.0,0.0,0.0))
	var lands: int = s.lands
	study.script_crouch = true
	_frame()
	check(s.phase == "","Pressed %.1f m up (under %.1f) it doesn't slam" % [Slam.LOW*m.size*0.6,Slam.LOW*m.size])
	_until_down()
	_frame()
	check(s.lands == lands and m.grounded and m.move == "slide","It keeps its old meaning: the slide on landing (%s at %.1f m/s)" % [m.move,m.speed()])
	study.script_crouch = false
	_frames(0.5)

func _held() -> void:
	var s: Node3D = study.slam
	var m: PilotMotor = study.motor
	_stand(OPEN)
	m.velocity = Vector3(0.0,0.0,-m.run)
	study.script_want = Vector2(0.0,-1.0)
	_frames(0.1)
	study.script_crouch = true
	_frames(0.05)
	study.script_jump = true
	_frame()
	study.script_jump = false
	var long := m.move == "long" or not m.grounded
	# Lifted well up mid-jump, crouch still held from the ground.
	m.feet.y += 4.0
	var lands: int = s.lands
	var slammed := false
	for i in range(int(2.0/DT)):
		_frame()
		if s.phase != "" or m.move == "slam": slammed = true
		if m.grounded: break
	check(long and not slammed and s.lands == lands,"Crouch held from a long jump (%s), 4 m up: no slam" % m.move)
	study.script_crouch = false
	study.script_want = Vector2.ZERO
	_frames(0.5)

## Under the sail: a tap of crouch folds it and slams; a hold brakes, the
## sail kept, no slam.
func _sail() -> void:
	var s: Node3D = study.slam
	var m: PilotMotor = study.motor
	for tap: bool in [true,false]:
		_airborne(OPEN,14.0)
		_frames(0.15)
		study.script_jump = true
		_frame()
		study.script_jump = false
		_frames(0.3)
		var sailing := m.move == "sail"
		var lands: int = s.lands
		study.script_crouch = true
		_frames(0.1 if tap else 0.6)
		var kept := m.move == "sail"
		if tap: study.script_crouch = false
		_until_down(6.0)
		study.script_crouch = false
		_frames(0.3)
		if tap: check(sailing and s.lands == lands+1,"Under the sail (%s), a tap of crouch folds it and slams" % sailing)
		else: check(sailing and kept and s.lands == lands,"Under the sail (%s), crouch held brakes: still sailing (%s), no slam" % [sailing,kept])

func _combo() -> void:
	var u: Node3D = study.updraft
	var s: Node3D = study.slam
	var m: PilotMotor = study.motor
	_stand(OPEN)
	u.charge = 1.0
	var ups: int = u.updrafts
	study.script_wind = true
	_frame()
	study.script_wind = false
	var top := m.feet.y
	for i in range(int(2.0/DT)):
		_frame()
		top = maxf(top,m.feet.y)
		if m.velocity.y < 2.0: break
	check(u.updrafts == ups+1 and u.charge == 0.0,"The updraft spends the charge (up %.1f m)" % (top-OPEN.y))
	var lands: int = s.lands
	study.script_crouch = true
	_frame()
	check(s.busy(),"Near its top, a fresh crouch press slams (%s)" % s.phase)
	_until_down()
	check(s.lands == lands+1 and float(s.last.drop) > 5.0 and float(s.last.strength) >= Slam.decent(),"Updraft then slam in one airtime: a %.1f m drop, strength %.2f" % [float(s.last.get("drop",0.0)),float(s.last.get("strength",0.0))])
	check(not u.spent,"The slam locks nothing: the updraft's charge builds again from flow")
	study.script_crouch = false
	_frames(0.5)

# --- The drive --------------------------------------------------------------------------

func _drive() -> void:
	var s: Node3D = study.slam
	var m: PilotMotor = study.motor
	_airborne(OPEN,9.0,Vector3(5.0,0.0,0.0))
	_frames(0.03)
	study.script_crouch = true
	_frame()
	var hang := 0.0
	for i in range(maxi(int(Slam.HANG/DT)-1,0)):
		_frame()
		hang = maxf(hang,absf(m.velocity.y))
	check(hang < 1.0,"The catch: his fall stopped a moment (%.2f m/s)" % hang)
	var low := 0.0
	var moved := 0.0
	var was_move := ""
	for i in range(int(2.0/DT)):
		_frame()
		low = minf(low,m.velocity.y)
		if m.move == "slam": was_move = "slam"
		if not m.grounded: moved = m.speed()
		if m.grounded: break
	check(was_move == "slam" and low < -PilotMotor.TERMINAL,"Driven down past his fall's pace (%.1f m/s, terminal %.0f)" % [-low,PilotMotor.TERMINAL])
	check(moved > 5.0*Slam.SLAM_KEEP*0.95,"His flat pace kept on the way down (%.2f of 5)" % moved)
	_frame()
	check(m.grounded and (m.move == "slide" or m.move == "crouch") and m.speed() > 2.5,"Crouch still held, he slides out of it (%s at %.1f m/s)" % [m.move,m.speed()])
	study.script_crouch = false
	_frames(0.6)
	# Jump pressed just before the touch: out of it.
	_airborne(OPEN,6.0)
	study.script_crouch = true
	_frame()
	study.script_crouch = false
	var up := false
	for i in range(int(2.0/DT)):
		study.script_jump = s.busy() and m.feet.y-m.ground_y < 1.2
		_frame()
		if m.grounded or m.velocity.y > 3.0:
			for j in range(4):
				_frame()
				up = up or m.velocity.y > 3.0
			break
	study.script_jump = false
	check(up,"Jump buffered for the touch jumps out of it")
	_until_down()
	_frames(0.3)

func _energy() -> void:
	var hits: Array[Dictionary] = []
	for up: float in [2.4,5.0,9.0]: hits.append(_slam_from(OPEN,up))
	var ok := hits.size() == 3 and not hits[0].is_empty() and not hits[1].is_empty() and not hits[2].is_empty()
	check(ok,"Slams from 2.4, 5 and 9 m all land")
	if not ok: return
	var line := ""
	for h: Dictionary in hits: line += " %.1f m: %.2f, %.1f m round;" % [float(h.drop),float(h.strength),float(h.radius)]
	check(float(hits[0].strength) < float(hits[1].strength) and float(hits[1].strength) < float(hits[2].strength) \
		and float(hits[0].radius) < float(hits[1].radius) and float(hits[1].radius) < float(hits[2].radius),"The hit grows with the height:"+line)
	check(absf(float(hits[2].drop)-9.0) < 0.6,"The drop is measured, press to touch (%.2f of 9)" % float(hits[2].drop))
	check(float(hits[0].strength) < Slam.decent() and float(hits[1].strength) >= Slam.decent(),"A hop's slam is under a decent hit (%.2f), 5 m's is over (%.2f, decent %.2f)" % [float(hits[0].strength),float(hits[1].strength),Slam.decent()])

# --- The push -----------------------------------------------------------------------------

func _slab() -> void:
	var slab: Node3D = null
	for node: Node in get_nodes_in_group(Slam.GROUP):
		if node.has_method("weigh") and node.get("bob") != null and float(node.get("bob")) > 0.0:
			slab = node
			break
	check(slab != null,"A bobbing slab answers the slam")
	if slab == null: return
	var top: Vector3 = slab.global_position
	var slammed: int = slab.slammed
	# Down onto it, off its middle.
	_airborne(top+Vector3(0.6,0.0,0.3),5.0)
	study.script_crouch = true
	_until_down()
	var sag: float = slab.sag
	var shove: float = slab.shove.length()
	_frames(0.15)
	check(slab.slammed == slammed+1,"The touch on the slab reached it")
	check(minf(sag,slab.sag) < -0.05 and maxf(shove,slab.shove.length()) > 0.02,"It sags and is shoved aside (sag %.2f, shove %.2f m)" % [minf(sag,slab.sag),maxf(shove,slab.shove.length())])
	study.script_crouch = false
	_frames(0.5)

func _bell_and_cowl() -> void:
	arc._stand_up("bell_spires")
	for i in range(3): await process_frame
	var isle: Node3D = null
	for each: Node3D in study.motifs.isles:
		if str(each.motif.id()) == "bell_spires": isle = each
	check(isle != null and isle.is_up(),"The bell spires stand")
	if isle == null: return
	var bell: Dictionary = isle.motif.bells[0]
	check(arc.cowl == "jammed","The cowl is jammed under the bell")
	var cowl: Node3D = arc.holders.cowl
	# Jammed, it can't be taken: his middle right at it.
	arc._last = Vector3.INF
	arc.touch(cowl.global_position)
	arc.touch(cowl.global_position)
	check(arc.state.cowl == "laid" and not book.is_done("bell_spires/cowl"),"Jammed, reaching it takes nothing")
	var spot := PartSpots.cowl()
	var floor: Vector3 = spot.stand
	# A small slam on the belfry floor: the bell swings, the cowl holds.
	bell.speed = 0.0
	bell.angle = 0.0
	var small := _slam_from(floor,2.2)
	var small_swing := absf(float(bell.speed))
	check(not small.is_empty() and float(small.strength) < Slam.decent() and arc.cowl == "jammed","A small slam (%.1f m) on the floor leaves the cowl jammed (strength %.2f)" % [float(small.get("drop",0.0)),float(small.get("strength",0.0))])
	# A big one: from up by the wall head, down onto the belfry floor.
	_airborne(floor,6.0)
	bell.speed = 0.0
	bell.angle = 0.0
	study.script_crouch = true
	_until_down()
	check(study.motor.grounded and absf(study.motor.feet.y-floor.y) < 0.3,"Down on the belfry floor (%.2f m off it)" % (study.motor.feet.y-floor.y))
	var big_swing := absf(float(bell.speed))
	check(big_swing > 0.3 and big_swing > small_swing,"The bell is swung hard, harder than by the small one (%.2f against %.2f rad/s)" % [big_swing,small_swing])
	var swing := 0.0
	for i in range(int(1.2/DT)):
		isle.motif.frame(DT,isle)
		swing = maxf(swing,absf(float(bell.angle)))
	check(swing > 0.15,"It swings wide (%.2f rad)" % swing)
	check(arc.cowl == "falling" or arc.cowl == "down","The big slam knocks the cowl loose (%s)" % arc.cowl)
	study.script_crouch = false
	_frames(PlaneArc.COWL_DELAY+PlaneArc.COWL_FALL+0.2)
	var at: Vector3 = PartSpots.cowl_floor()
	check(arc.cowl == "down" and cowl.global_position.distance_to(at) < 0.05,"It drops onto the belfry floor (%.2f m off its spot)" % cowl.global_position.distance_to(at))
	# Taken there as ever.
	study.place(at+Vector3.DOWN*PartSpots.HOVER,Vector2(0.0,-1.0))
	_frames(DT*3.0)
	check(arc.state.cowl == "carried" and book.is_done("bell_spires/cowl"),"Taken off the floor: stamped in the ledger, carried")

# --- The buried find ---------------------------------------------------------------------

func _buried() -> void:
	var tokens: Node3D = study.life.tokens
	check(tokens != null and tokens.buried.has("buried"),"The aqueduct isle lays a buried rune")
	if tokens == null or not tokens.buried.has("buried"): return
	var dig: Node3D = tokens.buried.buried
	var holder: Node3D = tokens._holders.get("buried")
	var ground := Tokens.buried_ground()
	var id: String = tokens.objective("buried")
	check(id == "aqueduct_isle/buried" and book.registry.objective(id).type == "token","It's a ledger objective, a rune token: %s" % id)
	check(dig.covered() and holder != null and not holder.visible,"Buried: the token hidden under the turf")
	check(dig.shimmer != null and dig.shimmer.is_in_group(Telescope.GROUP) and Telescope.unfound(dig.shimmer) and not holder.is_in_group(Telescope.GROUP),"Its shimmer glints for the telescope, not the token")
	var g: float = study.ground.ground_callable().call(Vector2(ground.x,ground.z))
	check(absf(g-ground.y) < 0.1,"It lies on the turf (%.2f m off the ground)" % (g-ground.y))
	# Walked over, it stays buried.
	_stand(ground)
	study.script_want = Vector2(1.0,0.0)
	_frames(0.6)
	study.script_want = Vector2.ZERO
	check(dig.covered() and not book.is_done(id) and not tokens.taken.has("buried"),"Walked over, nothing: still buried, not taken")
	# A big slam too far off leaves it.
	var away := ground+Vector3(-BuriedFind.REACH-3.0,0.0,0.0)
	var far := _slam_from(Vector3(away.x,study.ground.ground_callable().call(Vector2(away.x,away.z)),away.z),6.0)
	check(not far.is_empty() and dig.covered(),"A big slam %.1f m off leaves it buried" % (BuriedFind.REACH+3.0))
	# A small hop's slam right over it leaves it.
	var hop := _slam_from(ground+Vector3(0.3,0.0,0.0),2.4)
	check(not hop.is_empty() and dig.covered(),"A small hop's slam over it (%.1f m, strength %.2f) leaves it buried" % [float(hop.get("drop",0.0)),float(hop.get("strength",0.0))])
	# A slam from a height over it breaks it open.
	_airborne(ground+Vector3(0.4,0.0,0.0),6.0)
	study.script_crouch = true
	_until_down()
	check(dig.state == "rising" and holder.visible,"A slam from 6 m over it breaks the turf open: it comes up (%s)" % dig.state)
	check(dig.shimmer == null and dig.mound == null,"The shimmer and the hump are gone")
	study.script_crouch = false
	_stand(ground+Vector3(-4.0,0.0,0.0))
	_frames(BuriedFind.RISE+0.1)
	check(dig.takeable() and holder.position.distance_to(ground+Vector3.UP*Tokens.BURIED_HOVER) < 0.05,"Up, it hovers to be taken (%.2f m off)" % holder.position.distance_to(ground+Vector3.UP*Tokens.BURIED_HOVER))
	check(holder.is_in_group(Telescope.GROUP),"Up, the token glints in its own right")
	# Taken as ever.
	_stand(ground)
	_frames(0.1)
	check(tokens.taken.has("buried") and book.is_done(id),"Taken: stamped in the ledger")
