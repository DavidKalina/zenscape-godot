extends SceneTree
## The plane's arc, round 1 (scripts/plane_arc/plane_arc.gd, part_spots.gd,
## plane_cough.gd; docs/design/plane-arc/round1.md), headless, on the
## aqueduct isle with its motif isles stood up and --plane-arc (a script run
## otherwise starts repaired):
##   - on a fresh save the parked plane is broken (all six missing, dusty)
##     and Space by it plays the won't-start beat and doesn't take off;
##   - each part is laid by name from its isle's geometry: the wheel on the
##     stone circle's east lintel, high, near the plane; the wingtip under
##     the cloister tarn's deep water; the fin on the serpent's back; the
##     windscreen in the drowned nave's water; the propeller on the
##     salvager's rope, its pass by the gate tower's crown never within
##     reach of anyone standing on it; the cowl under the belfry's bell;
##     each --part-at start on solid ground;
##   - the ledger lists the six as "part" objectives (needs_plane false)
##     and the region counts by it;
##   - a pickup on foot stamps the ledger at once and rides at his side;
##     the propeller is snatched off the rope; the fin off the serpent;
##   - a carried part survives a fall off the isle and a respawn;
##   - Space by the plane fits what he carries, one after another, the paint
##     cleaning, saved; the save reads back carried and fitted;
##   - with all six fitted the plane is whole, new, and takes off.
##   godot --headless --path . --script tests/test_plane_arc.gd
const DT := 1.0/60.0
const LaunchArgs = preload("res://scripts/launch_args.gd")
const LedgerScript = preload("res://scripts/ledger/ledger.gd")
const PartSpots = preload("res://scripts/plane_arc/part_spots.gd")
const PlaneArc = preload("res://scripts/plane_arc/plane_arc.gd")
const SnagPlane = preload("res://scripts/snag_plane.gd")
const TarnArt = preload("res://studies/cloister_tarn_isle_art.gd")
const NaveArt = preload("res://studies/drowned_nave_isle_art.gd")
const Belfry = preload("res://scripts/ruin_kit_belfry.gd")
const Telescope = preload("res://scripts/telescope.gd")
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
	create_timer(240.0).timeout.connect(func() -> void: push_error("plane arc test timed out"); quit(2))
	book = LedgerScript.shared()
	book.reset()
	_file = "user://plane_arc_test_%d.json" % OS.get_process_id()
	book.path = _file
	_registry()
	LaunchArgs.set_override(["--no-title","--plane-arc"])
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
	check(arc != null and not arc.fixed,"The aqueduct isle has the plane's arc, not fixed with --plane-arc")
	if arc == null:
		quit(1)
		return
	_broken()
	_refused()
	_laid()
	_starts()
	_pickup()
	_fall()
	_fit_one()
	_snatch()
	_fin()
	_round_trip()
	_all_six()
	LaunchArgs.set_override(null)
	book.path = ""
	for path in [_file,_file+".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	print("PASS: plane arc" if failures == 0 else "FAIL: plane arc (%d)" % failures)
	quit(1 if failures > 0 else 0)

## Frames of the scene: the serpent, the arc, the pilot and the figure.
func _frames(seconds: float) -> void:
	for i in range(int(round(seconds/DT))):
		study.sky.serpent.advance(DT)
		arc.snag.advance(DT)
		arc.advance(DT)
		arc.cough.advance(DT)
		study.tick(DT)
		if study.plane_figure != null: study.plane_figure._process(DT)

## Stood by the parked plane, where a hop out of it lands.
func _by_plane() -> void:
	var spot: Vector3 = study._hop_spot(study.parked_at,study.parked_heading)
	study.place(spot,Vector2(study.parked_at.x-spot.x,study.parked_at.z-spot.z).normalized())
	study._last_stood = spot
	_frames(0.1)

# --- The ledger ---------------------------------------------------------------------------

func _registry() -> void:
	var r: RefCounted = book.registry
	var parts: Array[String] = r.region_objectives("ruins","part")
	var want: Array = PartSpots.IDS.map(func(id: String) -> String: return PartSpots.objective(id))
	check(parts.size() == 6 and want.all(func(id: String) -> bool: return parts.has(id)),"The six parts are 'part' objectives on their isles: %s" % [parts])
	check(parts.all(func(id: String) -> bool: return r.objective(id).row == "plane" and r.objective(id).needs_plane == false),"Each counts under the Plane row, needs_plane false")
	check(r.region_objectives("ruins").all(func(id: String) -> bool: return r.objective(id).needs_plane is bool),"Every objective has a needs_plane flag")
	var foot: Dictionary = book.region_progress("ruins",false)
	var plane: Dictionary = book.region_progress("ruins",true)
	check(foot.total == 63 and plane.total == 0 and foot.types.part.total == 6,"The region counts by it: 63 on foot (6 parts), 0 needing the plane (%d, %d)" % [foot.total,plane.total])
	check(book.card("bell_spires",{}).finds.has(["part","Plane",0,1]),"The bell spires' card has a Plane row: %s" % [book.card("bell_spires",{}).finds])

# --- Broken -------------------------------------------------------------------------------

func _broken() -> void:
	var figure: Node3D = study.plane_figure
	check(study.parked and figure != null,"The plane stands parked")
	check(not arc.flies() and arc.missing().size() == 6,"A fresh save: the plane is broken, all six missing")
	check(figure.missing().size() == 6 and figure.get_wear() > 0.95,"The figure shows it: %d parts missing, wear %.2f" % [figure.missing().size(),figure.get_wear()])

func _refused() -> void:
	_by_plane()
	check(study.by_plane(),"Stood by the plane")
	var at: Vector3 = study.parked_at
	var rest: Transform3D = study.plane_figure.transform
	study.board_parked()
	check(not study.flying and study.parked and arc.cough.playing(),"Space by the broken plane: it won't start (no takeoff, the cough plays)")
	var shook := 0.0
	for i in range(int(0.6/DT)):
		_frames(DT)
		shook = maxf(shook,study.plane_figure.transform.origin.distance_to(rest.origin)+(study.plane_figure.transform.basis.get_euler()-rest.basis.get_euler()).length())
	check(shook > 0.001 and arc.cough.coughs >= 1,"It coughs and shudders (%d coughs, %.3f)" % [arc.cough.coughs,shook])
	_frames(PlaneCough_TIME())
	check(not arc.cough.playing() and arc.cough.coughs == 3 and study.plane_figure.transform.is_equal_approx(rest),"Three coughs, then still where it stood")
	check(not study.flying and study.parked_at == at,"Still parked, not flying")

static func PlaneCough_TIME() -> float:
	return preload("res://scripts/plane_arc/plane_cough.gd").TIME

# --- Laid by name -------------------------------------------------------------------------

func _laid() -> void:
	# The wheel: on a standing lintel of the stone circle, the east one, high
	# over the turf, near the parked plane.
	var circle: Node3D = study.circle
	var ring: Dictionary = circle.get_meta("ring")
	var wheel: Vector3 = arc.holders.wheel.global_position
	var east := Vector3(-INF,0.0,0.0)
	for lintel: Array in ring.lintels:
		if not bool(lintel[1]): continue
		var top: Vector3 = circle.transform*(lintel[0] as Vector3)
		if top.x > east.x: east = top
	var on := wheel.distance_to(east+Vector3.UP*PartSpots.HOVER) < 0.05
	check(on,"The wheel hovers on the ring's east standing lintel (%s)" % wheel)
	var plane_d := Vector2(wheel.x-study.parked_at.x,wheel.z-study.parked_at.z).length()
	check(wheel.y > study.isle_top()+12.0 and plane_d < 80.0,"High (%.1f m over the turf), near the plane (%.0f m)" % [wheel.y-study.isle_top(),plane_d])
	# The wingtip: under the tarn's surface where it's deep.
	var tarn := PartSpots.offset("cloister_tarn")
	var tip: Vector3 = arc.holders.wingtip.global_position
	var local := tip-tarn
	var bed := TarnArt.ground(local.x,local.z)
	check(local.y < TarnArt.W and local.y > bed and bed <= TarnArt.W-PartSpots.SWIM_DEEP,"The wingtip lies under the cloister tarn (%.2f under, %.1f m deep)" % [TarnArt.W-local.y,TarnArt.W-bed])
	check(arc._glints.has("wingtip") and (arc._glints.wingtip as Node3D).global_position.y > TarnArt.W+tarn.y and (arc._glints.wingtip as Node3D).is_in_group(Telescope.GROUP),"Its glint is over the water")
	check(_in_pool(study.motifs.isles,"cloister_tarn",tip),"In the tarn's water the pilot swims")
	# The windscreen: in the drowned nave's water.
	var nave := PartSpots.offset("drowned_nave")
	var glass: Vector3 = arc.holders.windscreen.global_position-nave
	check(glass.y < NaveArt.W and glass.y > NaveArt.ground(glass.x,glass.z),"The windscreen lies in the drowned nave's water (%.2f under)" % (NaveArt.W-glass.y))
	check(_in_pool(study.motifs.isles,"drowned_nave",glass+nave),"In the nave's water")
	# The cowl: under the belfry's bell as built.
	var bell_isle: Node3D = _motif(study.motifs.isles,"bell_spires")
	var bell: Node3D = bell_isle.motif.belfry.get_node("Bell") if bell_isle != null and bell_isle.motif.belfry != null else null
	var cowl: Vector3 = arc.holders.cowl.global_position
	if bell != null:
		var pivot := bell.global_position
		check(Vector2(cowl.x-pivot.x,cowl.z-pivot.z).length() < 0.05 and pivot.y-cowl.y > Belfry.BELL.y and pivot.y-cowl.y < Belfry.BELL.y+0.6,"The cowl is jammed under the bell (%.2f under its pivot)" % (pivot.y-cowl.y))
	else: check(false,"The bell spires' belfry stands")
	# The fin: on the serpent's back.
	var serpent: Node3D = study.sky.serpent
	arc.place_fin()
	var fin: Vector3 = arc.holders.fin.global_position
	var frame: Transform3D = serpent.ring_frame(arc.fin_ring)
	check(fin.distance_to(frame.origin) < 4.0 and (fin-frame.origin).dot(frame.basis.y.normalized()) > 0.5,"The tail fin rides the serpent's back (%.1f m off its ring's middle)" % fin.distance_to(frame.origin))
	check(arc.holders.fin.is_in_group(Telescope.GROUP) and arc.holders.wheel.is_in_group(Telescope.GROUP),"The parts glint through the telescope")
	# The propeller: on the salvager's rope; over a lap its pass comes by the
	# gate tower's crown but never in reach of anyone standing on it.
	var snag: Node3D = arc.snag
	check(snag.load_token == arc.holders.propeller and snag.load_token.get("id") == "propeller","The propeller hangs on the salvager's rope")
	var s: Dictionary = arc.snag_spot
	var crown: Vector3 = s.crown
	var edge: Vector3 = s.edge
	var near := INF
	var stand_near := INF
	var lowest := INF
	snag.set_process(false)
	for i in range(int(snag.lap/DT)):
		snag.advance(DT)
		var p: Vector3 = snag.load_point()
		near = minf(near,p.distance_to(edge))
		lowest = minf(lowest,p.y-crown.y)
		# Anyone on the crown's top (its 5 x 1.6 m) at his middle's height.
		for dx: float in [-2.4,-1.2,0.0,1.2,2.4]:
			var spot: Vector3 = Gorge_frame()*Vector3(dx,9.6+0.55,-1.7)+PartSpots.offset("sundered_gorge")
			stand_near = minf(stand_near,p.distance_to(spot))
	snag.set_process(true)
	var reach: float = 0.6+PlaneArc.SIZE*0.5
	check(near < 3.5,"Its pass comes by the gate tower's crown edge (%.1f m at closest; lowest %.1f m off the crown)" % [near,lowest])
	check(stand_near > maxf(reach,PlaneArc.SNAG_REACH)+0.2,"Never within reach of anyone standing on the crown: a leap, not wait-and-grab (%.1f m at closest)" % stand_near)

static func Gorge_frame() -> Transform3D:
	return preload("res://studies/sundered_gorge_isle_art.gd").tower_frame()

func _motif(isles: Array, id: String) -> Node3D:
	for isle: Node3D in isles:
		if str(isle.motif.id()) == id: return isle
	return null

## Whether `p` (world) is in motif `id`'s water (its pools, placed).
func _in_pool(isles: Array, id: String, p: Vector3) -> bool:
	var isle := _motif(isles,id)
	if isle == null: return false
	for pool: Dictionary in isle.motif.pools():
		var rect: Rect2 = pool.rect
		var off: Vector3 = isle.offset
		if rect.has_point(Vector2(p.x-off.x,p.z-off.z)) and p.y < float(pool.top)+off.y: return true
	return false

## Each --part-at start stands on something solid.
func _starts() -> void:
	var space := study.get_world_3d().direct_space_state
	for id: String in ["wheel","wingtip","windscreen","cowl"]:
		var s: Dictionary = arc.spots[id]
		_solid(space,id,s.stand)
	_solid(space,"propeller",arc.snag_spot.stand)

func _solid(space: PhysicsDirectSpaceState3D, id: String, at: Vector3) -> void:
	var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*0.8,at+Vector3.DOWN*1.5,1|(1 << 11))
	var hit := space.intersect_ray(ray)
	var gap: float = at.y-(hit.position as Vector3).y if not hit.is_empty() else INF
	check(absf(gap) < 0.6,"--part-at=%s starts on solid ground (%.2f m over it)" % [id,gap])

# --- Taking, carrying, falling ------------------------------------------------------------

func _pickup() -> void:
	var wheel: Vector3 = arc.holders.wheel.global_position
	check(not book.is_done("aqueduct_isle/wheel"),"The wheel's objective isn't done yet")
	study.place(wheel+Vector3.DOWN*0.85,Vector2(0.0,-1.0))
	_frames(DT*2.0)
	check(arc.state.wheel == "carried" and book.is_done("aqueduct_isle/wheel") and book.is_carried("wheel"),"On foot at the wheel it's taken: stamped in the ledger at once, carried")
	check(not arc.holders.wheel.is_in_group(Telescope.GROUP),"Taken, it no longer glints")
	_frames(0.8)
	var d: float = arc.holders.wheel.global_position.distance_to(study.figure.global_position)
	check(d < 1.4 and is_equal_approx(arc.holders.wheel.scale.x,PlaneArc.CARRY),"It rides at his side, small (%.2f m off, %.2fx)" % [d,arc.holders.wheel.scale.x])
	check(study.isle_card().finds.has(["part","Plane",1,2]),"The aqueduct isle's card counts it: %s" % [study.isle_card().finds])
	# He moves as ever.
	var was: Vector3 = study.motor.feet
	study.script_want = Vector2(0.0,-1.0)
	_frames(0.4)
	study.script_want = Vector2.ZERO
	check(study.motor.feet.distance_to(was) > 0.3,"Carrying it, he still runs (%.2f m)" % study.motor.feet.distance_to(was))

func _fall() -> void:
	# Off the isle's south rim into open sky: stranded, back by the plane.
	study.place(Vector3(100.0,32.0,70.0),Vector2(0.0,1.0))
	study._last_stood = Vector3(100.0,30.0,40.0)
	var back := false
	for i in range(int(12.0/DT)):
		_frames(DT)
		if not study.off_edge and study._stranded_left < 0.0 and study.motor.feet.distance_to(study.parked_at) < 6.0:
			back = true
			break
	_frames(0.5)
	check(back,"Off the edge he falls, is stranded and comes back by the plane")
	check(arc.state.wheel == "carried" and arc.carried.has("wheel"),"The wheel is still carried")
	check(arc.holders.wheel.global_position.distance_to(study.figure.global_position) < 1.4,"And at his side again")
	study.respawn()
	_frames(0.5)
	check(arc.state.wheel == "carried" and arc.holders.wheel.global_position.distance_to(study.figure.global_position) < 1.4,"A respawn keeps it too")

# --- Fitting ------------------------------------------------------------------------------

func _fit_one() -> void:
	_by_plane()
	var wear: float = study.plane_figure.get_wear()
	study.board_parked()
	check(not study.flying and arc.state.wheel == "fitted" and book.is_fitted("wheel") and not book.is_carried("wheel"),"Space by the plane fits the wheel (saved at once), no takeoff")
	_frames(2.5)
	check(not study.plane_figure.is_missing("wheel") and study.plane_figure.missing().size() == 5,"It seats on the plane (%d missing)" % study.plane_figure.missing().size())
	check(study.plane_figure.get_wear() < wear-0.05,"The paint a step cleaner (%.2f to %.2f)" % [wear,study.plane_figure.get_wear()])
	check(not arc.holders.has("wheel"),"Nothing carried left of it")
	study.board_parked()
	_frames(0.2)
	check(not study.flying and arc.cough.playing(),"Five still missing: it won't start")
	_frames(2.0)

func _snatch() -> void:
	var snag: Node3D = arc.snag
	snag.set_process(false)
	var took := false
	for i in range(int(snag.lap/DT)):
		snag.advance(DT)
		study.motor.reset(snag.load_point()+Vector3.DOWN*1.0,0.0)
		study.tick(DT)
		arc.advance(DT)
		if arc.state.propeller != "laid":
			took = true
			break
	snag.set_process(true)
	study._end_fall()
	check(took and not snag.attached and snag.get("_jolt") >= 0.0,"At the load he snatches the propeller off the rope; the salvager lurches")
	check(book.is_carried("propeller") and arc.holders.propeller.get_parent() == arc,"It's his: stamped, carried")
	for i in range(int((SnagPlane.RESPAWN+1.0)/DT)): snag.advance(DT)
	check(not snag.attached and snag.load_token == null,"No new load hangs: there is one propeller")

func _fin() -> void:
	var fin: Node3D = arc.holders.fin
	study.place(fin.global_position+Vector3.DOWN*0.55,Vector2(0.0,-1.0))
	arc.touch(study.motor.feet+Vector3.UP*0.55)
	check(arc.state.fin == "carried" and book.is_done("aqueduct_isle/fin") and arc.fin_holder() == null,"On the serpent's back he takes the tail fin")

func _round_trip() -> void:
	var b: Node = LedgerScript.new()
	b.path = _file
	b.load_saved()
	check(b.is_fitted("wheel") and b.is_carried("propeller") and b.is_carried("fin") and not b.is_carried("wheel"),"The save reads back: wheel fitted, propeller and fin carried (%s)" % [b.plane])
	check(b.is_done("aqueduct_isle/wheel") and b.is_done("sundered_gorge/propeller") and b.is_done("aqueduct_isle/fin"),"And their objectives done")
	var raw := FileAccess.get_file_as_string(_file)
	check(raw.contains("\"plane\"") and raw.contains("\"fitted\""),"In the same progress file")
	b.free()

func _all_six() -> void:
	for id: String in ["wingtip","windscreen","cowl"]: arc.take(id)
	check(arc.carried.size() == 5,"Carrying the other five (%s)" % [arc.carried])
	_frames(0.3)
	_by_plane()
	study.board_parked()
	check(not study.flying and arc.fitting.size() >= 4,"Space fits them, one after another")
	var steps := 0
	var was: int = study.plane_figure.missing().size()
	for i in range(int(7.0/DT)):
		_frames(DT)
		var now: int = study.plane_figure.missing().size()
		if now < was: steps += 1
		was = now
	check(steps == 5 and study.plane_figure.missing().is_empty() and arc.flies(),"Each seats in turn (%d steps): the plane is whole" % steps)
	_frames(1.5)
	check(study.plane_figure.get_wear() < 0.05,"Mended, the paint is new (%.2f)" % study.plane_figure.get_wear())
	var c: Node = LedgerScript.new()
	c.path = _file
	c.load_saved()
	check((c.plane.fitted as Array).size() == 6 and (c.plane.carried as Array).is_empty(),"All six fitted in the save")
	c.free()
	study.board_parked()
	check(study.flying and study.takeoff != null,"With all six, Space climbs in and takes off")
	for i in range(20): arc.advance(DT)
	check(arc.carried.is_empty(),"Nothing left carried")
	study.leave_plane()
