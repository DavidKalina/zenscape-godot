extends SceneTree
## The downdraft (scripts/downdraft.gd, scripts/buried_find.gd; docs/design/
## downdraft/round1.md), headless, on the aqueduct isle with its motif isles:
##   - in the air, Q alone is still the updraft; crouch + Q is the
##     downdraft: the whole charge spent and charging locked, a short hang,
##     then driven down past the fall's pace, his flat pace kept, a ring at
##     the touch (and the key does nothing again till the lock lifts);
##   - the touch pushes a floating slab (sagged and shoved) and swings the
##     belfry's bell, and knocks the jammed cowl down onto the belfry floor
##     where it's taken (it can't be taken jammed);
##   - the buried rune off the north path stays buried (a shimmer glinting
##     for the telescope, the token hidden and not taken by walking over it,
##     not opened by a downdraft too far off) until a downdraft over it
##     blows it open; it comes up, is taken and stamped in the ledger.
##   godot --headless --path . --script tests/test_downdraft.gd
const DT := 1.0/60.0
const LaunchArgs = preload("res://scripts/launch_args.gd")
const LedgerScript = preload("res://scripts/ledger/ledger.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Downdraft = preload("res://scripts/downdraft.gd")
const Updraft = preload("res://scripts/updraft.gd")
const BuriedFind = preload("res://scripts/buried_find.gd")
const Telescope = preload("res://scripts/telescope.gd")
const PartSpots = preload("res://scripts/plane_arc/part_spots.gd")
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
	create_timer(240.0).timeout.connect(func() -> void: push_error("downdraft test timed out"); quit(2))
	book = LedgerScript.shared()
	book.reset()
	_file = "user://downdraft_test_%d.json" % OS.get_process_id()
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
	check(study.updraft != null and study.downdraft != null and study.updraft.downdraft == study.downdraft,"The pilot has the updraft and the downdraft, sharing its key")
	_choice()
	_slam()
	_lock()
	_slab()
	await _bell_and_cowl()
	_buried()
	LaunchArgs.set_override(null)
	book.path = ""
	for path in [_file,_file+".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("PASS: downdraft" if failures == 0 else "FAIL: downdraft (%d)" % failures)
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

## In the air `up` m over `at`, falling from rest (flat pace `flat`).
func _airborne(at: Vector3, up: float, flat := Vector3.ZERO) -> void:
	_stand(at)
	var m: PilotMotor = study.motor
	m.reset(at+Vector3.UP*up,0.0)
	m.grounded = false
	m.ground_y = at.y
	m.velocity = flat
	study.updraft.reset()
	study.downdraft.reset()

## One tick with the key pressed (crouch `crouch`), `charge` in hand.
func _press(charge: float, crouch: bool) -> void:
	study.updraft.charge = charge
	study.script_crouch = crouch
	study.script_wind = true
	_frame()

## Ticks until he's down (or `most` s), the lowest vertical pace seen.
func _until_down(most := 3.0) -> float:
	var low := 0.0
	for i in range(int(most/DT)):
		_frame()
		low = minf(low,study.motor.velocity.y)
		if study.motor.grounded and i > 2: break
	return low

# --- Which it is -----------------------------------------------------------------------

func _choice() -> void:
	var u: Node3D = study.updraft
	var d: Node3D = study.downdraft
	_airborne(OPEN,3.0)
	_frames(0.05)
	var ups: int = u.updrafts
	_press(1.0,false)
	check(u.updrafts == ups+1 and d.phase == "" and study.motor.velocity.y > 5.0,"In the air, Q alone is still the updraft (up at %.1f m/s)" % study.motor.velocity.y)
	_until_down()
	_airborne(OPEN,3.0)
	_frames(0.05)
	ups = u.updrafts
	_press(0.8,true)
	check(u.updrafts == ups and u.downdrafts == 1 and d.phase == "gather","In the air with crouch held, Q is the downdraft (%s)" % d.phase)
	check(u.charge == 0.0 and u.spent,"The whole charge is spent and charging locked (%.2f, spent %s)" % [u.charge,u.spent])
	_until_down()
	# On the ground, crouch + Q is still the updraft (the downdraft is the air's).
	_stand(OPEN)
	ups = u.updrafts
	u.spent = false
	_press(1.0,true)
	check(u.updrafts == ups+1 and d.phase == "","On the ground crouch + Q stays the updraft")
	study.script_crouch = false
	_until_down()

# --- The slam ---------------------------------------------------------------------------

func _slam() -> void:
	var d: Node3D = study.downdraft
	var m: PilotMotor = study.motor
	_airborne(OPEN,6.0,Vector3(5.0,0.0,0.0))
	_frames(0.03)
	var lands: int = d.lands
	_press(1.0,true)
	study.script_wind = false
	# The hang as the wind gathers.
	var hang := 0.0
	for i in range(int(Downdraft.GATHER/DT)-1):
		_frame()
		hang = maxf(hang,absf(m.velocity.y))
	check(d.phase == "gather" or d.phase == "slam","It gathers a moment first (%s)" % d.phase)
	check(hang < 1.0,"The hang: his fall stopped while it gathers (%.2f m/s)" % hang)
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
	check(moved > 5.0*Downdraft.SLAM_KEEP*0.95,"His flat pace kept on the way down (%.2f of 5)" % moved)
	check(d.lands == lands+1 and not d.last.is_empty() and is_equal_approx(float(d.last.radius),Downdraft.radius_for(1.0,m.size)),"The touch: a ring %.1f m round, strength %.2f, heard by %d" % [float(d.last.get("radius",0.0)),float(d.last.get("strength",0.0)),int(d.last.get("hit",0))])
	_frame()
	check(m.grounded and (m.move == "slide" or m.move == "crouch") and m.speed() > 2.5,"Crouch still held, he slides out of it (%s at %.1f m/s)" % [m.move,m.speed()])
	study.script_crouch = false
	_frames(0.6)

func _lock() -> void:
	var u: Node3D = study.updraft
	# Straight after a downdraft the lock holds: no charge comes, so the
	# key does nothing in the air, up or down.
	_airborne(OPEN,3.0,Vector3(9.0,0.0,0.0))
	u.spent = true
	u._spent_t = 0.0
	u._spent_pace = 0.0
	var ups: int = u.updrafts
	var downs: int = u.downdrafts
	for i in range(20): _frame()
	check(u.charge == 0.0,"Locked: fast airtime builds no charge (%.2f)" % u.charge)
	study.script_crouch = true
	study.script_wind = true
	_frame()
	study.script_wind = false
	_frame()
	study.script_wind = true
	study.script_crouch = false
	_frame()
	check(u.updrafts == ups and u.downdrafts == downs,"Locked and empty: neither fires")
	_until_down()

# --- The push -----------------------------------------------------------------------------

func _slab() -> void:
	var slab: Node3D = null
	for node: Node in get_nodes_in_group(Downdraft.GROUP):
		if node.has_method("weigh") and node.get("bob") != null and float(node.get("bob")) > 0.0:
			slab = node
			break
	check(slab != null,"A bobbing slab answers the downdraft")
	if slab == null: return
	var top: Vector3 = slab.global_position
	var winded: int = slab.winded
	# Down onto it, off its middle.
	_airborne(top+Vector3(0.6,0.0,0.3),5.0)
	_press(1.0,true)
	study.script_wind = false
	_until_down()
	var sag: float = slab.sag
	var shove: float = slab.shove.length()
	_frames(0.15)
	check(slab.winded == winded+1,"The touch on the slab reached it")
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
	# A downdraft onto the belfry floor.
	var spot := PartSpots.cowl()
	var floor: Vector3 = spot.stand
	_airborne(floor,1.3)
	bell.speed = 0.0
	bell.angle = 0.0
	_press(1.0,true)
	study.script_wind = false
	_until_down()
	check(study.motor.grounded and absf(study.motor.feet.y-floor.y) < 0.3,"Down on the belfry floor (%.2f m off it)" % (study.motor.feet.y-floor.y))
	check(absf(float(bell.speed)) > 0.6,"The bell is swung hard (%.2f rad/s)" % float(bell.speed))
	var swing := 0.0
	for i in range(int(1.2/DT)):
		isle.motif.frame(DT,isle)
		swing = maxf(swing,absf(float(bell.angle)))
	check(swing > 0.3,"It swings wide (%.2f rad)" % swing)
	check(arc.cowl == "falling" or arc.cowl == "down","The swing knocks the cowl loose (%s)" % arc.cowl)
	study.script_crouch = false
	_frames(PlaneArc_FALL())
	var at: Vector3 = PartSpots.cowl_floor()
	check(arc.cowl == "down" and cowl.global_position.distance_to(at) < 0.05,"It drops onto the belfry floor (%.2f m off its spot)" % cowl.global_position.distance_to(at))
	# Taken there as ever.
	study.place(at+Vector3.DOWN*PartSpots.HOVER,Vector2(0.0,-1.0))
	_frames(DT*3.0)
	check(arc.state.cowl == "carried" and book.is_done("bell_spires/cowl"),"Taken off the floor: stamped in the ledger, carried")

static func PlaneArc_FALL() -> float:
	return preload("res://scripts/plane_arc/plane_arc.gd").COWL_DELAY+preload("res://scripts/plane_arc/plane_arc.gd").COWL_FALL+0.2

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
	# A downdraft too far off leaves it.
	var away := ground+Vector3(-BuriedFind.REACH-3.0,0.0,0.0)
	_airborne(Vector3(away.x,study.ground.ground_callable().call(Vector2(away.x,away.z)),away.z),3.0)
	var lands: int = study.downdraft.lands
	_press(0.3,true)
	study.script_wind = false
	_until_down()
	check(study.downdraft.lands == lands+1 and dig.covered(),"A downdraft %.1f m off leaves it buried" % (BuriedFind.REACH+3.0))
	study.script_crouch = false
	_frames(0.3)
	# One over it blows it open.
	_airborne(ground+Vector3(0.4,0.0,0.0),3.0)
	_press(0.4,true)
	study.script_wind = false
	_until_down()
	check(dig.state == "rising" and holder.visible,"A downdraft over it blows the turf off: it comes up (%s)" % dig.state)
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
