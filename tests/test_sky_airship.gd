extends SceneTree
## The airship towing an islet (scripts/sky_airship.gd): only a lone islet
## is taken; the event runs start to finish (come, lower, bite, taut, tear,
## tow, settle, release, leave, done); the islet stays a solid in the
## islets' `built` the whole time, never let go while towed, and moves with
## the ship, hanging under it within its lines' reach; a walker standing on
## it (feet kept in its frame, as scripts/wanderer_eye.gd perches) is
## carried along: the islet under the feet is always it, the ground under
## them always where the feet are; it rides a swap of the world's origin
## mid-tow; the moored islet stays where it was left for the session (let go
## and grown again, it comes back there); and nothing is left behind.
## Headless: nodes and numbers only, nothing drawn.
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyAirship = preload("res://scripts/sky_airship.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	var orphans_before := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var cells := SkyCells.new([Vector3.ZERO,Vector3(380.0,-20.0,-160.0)])
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var eye := Vector3(150.0,0.0,150.0)
	for i in range(240):
		islets.advance(1.0/60.0,eye)
		islets.flush()
	var ship: Node3D = SkyAirship.new()
	ship.islets = islets
	ship.enabled = false
	ship.now = false
	ship.set_process(false)
	ship.away_odds = 0.0
	root.add_child(ship)
	ship.eye_override = eye
	# Only lone islets: a cluster's member (fixed, grouped) never.
	var any_key: String = islets.built.keys()[0]
	var member: Dictionary = (islets.built[any_key] as Dictionary).duplicate()
	member.fixed = true
	member.group = "c"
	check(not SkyAirship.lone(member),"A cluster's member is never taken")
	var key: String = ship.pick(eye,true)
	check(key != "","A lone islet near the eye is picked (%s)" % key)
	if key == "":
		_finish(islets,ship,orphans_before)
		return
	check(ship.start_on(key,eye,SkyAirship.SPAWN_NOW),"The event starts on it")
	var b: Dictionary = ship.towed()
	var start_home: Vector3 = b.home
	var shape: RefCounted = b.shape
	# The walker: stood on the islet's ground near its middle, in its frame.
	var at := Vector2.ZERO
	if shape.blocked(at): at = shape.rim_point(0.3)*0.4
	var feet := Vector3(at.x,float(shape.ground_at(at)),at.y)
	var kept := true
	var carried := true
	var hung := true
	var most_off := 0.0
	var shifted := false
	var steps := 0
	while ship.busy() and steps < 40000:
		steps += 1
		ship.advance(1.0/30.0)
		islets.advance(1.0/30.0,eye)
		if not ship.busy(): break
		if islets.built.get(key) != b: kept = false
		var place: Vector3 = islets.place(b)
		var global_feet := place+feet
		var under: Dictionary = islets.islet_at(global_feet)
		var body: Variant = islets.body(global_feet+Vector3.UP*0.5)
		if under != b or body == null or (body as Vector2).x < global_feet.y-0.05: carried = false
		var phase: String = ship.event.phase
		if phase in ["tow","settle"]:
			var off: Vector3 = (ship.event.pos as Vector3)-(b.home as Vector3)
			most_off = maxf(most_off,Vector2(off.x,off.z).length())
			if off.y < 3.0 or off.y > 30.0: hung = false
		# A swap of the world's origin, mid-tow: the islet and the ship ride it.
		if phase == "tow" and not shifted and ship.event.t > 10.0:
			shifted = true
			var before := place-islets.position
			cells.origin += Vector3(-200.0,0.0,50.0)
			islets.advance(0.0,eye)
			ship.advance(0.0)
			check(ship.position.is_equal_approx(islets.position) and (islets.place(b)-islets.position).is_equal_approx(before),"A swap of the origin carries the towed islet and the ship alike")
	var phases: Array = ship.phases
	check(phases == ["come","lower","bite","taut","tear","tow","settle","release","leave","done"],"The event runs start to finish: %s" % str(phases))
	check(kept,"The towed islet stays in the islets' built the whole time, never let go")
	check(carried,"A walker on it is carried along: always over it, the ground at the feet")
	check(hung and most_off < 15.0,"It hangs under the ship on its lines (at most %.1f m off level)" % most_off)
	var moved: float = Vector2(b.home.x-start_home.x,b.home.z-start_home.z).length()
	check(moved > SkyAirship.TOW_DISTANCE.x*0.8,"It is towed away to a new mooring (%.0f m)" % moved)
	check(islets.moved.get(key) is Vector3,"The mooring is kept for the session")
	check(not b.get("fixed",false) and not b.has("towed"),"Moored, it is an ordinary islet again")
	# Let go far off and grown again, it comes back at its mooring.
	var mooring: Vector3 = b.home
	var cell: Vector2i = b.cell
	islets.pinned = null
	for i in range(30): islets.advance(1.0/30.0,eye+Vector3(5000.0,0.0,5000.0)+cells.origin)
	check(not islets.built.has(key),"Far off, it is let go")
	for i in range(240):
		islets.advance(1.0/60.0,mooring+Vector3(20.0,0.0,0.0))
		islets.flush()
	var again: Dictionary = islets.built.get(key,{})
	check(not again.is_empty() and (again.home as Vector3).is_equal_approx(mooring) and again.cell == cell,"Flown back to, it stands at its mooring")
	# The ship's parts are hidden and its lines empty between events.
	check(not ship._ship.visible and (ship._lines.mesh as ArrayMesh).get_surface_count() == 0,"Between events the ship is hidden and its lines gone")
	_carried_off(islets,ship,eye)
	_finish(islets,ship,orphans_before)

## Carried off: another lone islet taken out of view is gone, and gone for
## the session.
func _carried_off(islets: Node3D, ship: Node3D, eye: Vector3) -> void:
	for i in range(240):
		islets.advance(1.0/60.0,eye)
		islets.flush()
	ship.eye_override = eye
	ship.away_odds = 1.0
	var key: String = ship.pick(eye,true)
	if key == "" or not ship.start_on(key,eye,SkyAirship.SPAWN_NOW):
		print("SKIP carried off: no lone islet with a way out of view")
		return
	var away: bool = ship.event.away
	var steps := 0
	while ship.busy() and steps < 60000:
		steps += 1
		ship.advance(1.0/30.0)
		islets.advance(1.0/30.0,eye)
	if not away:
		print("SKIP carried off: no way out of view, moored instead")
		return
	check(not islets.built.has(key) and islets.moved.has(key) and islets.moved[key] == null,"Carried off, it is gone for the session")
	for i in range(60): islets.advance(1.0/60.0,eye)
	check(not islets.built.has(key),"And never grows again in its cell")

func _finish(islets: Node3D, ship: Node3D, orphans_before: float) -> void:
	ship.queue_free()
	islets.queue_free()
	await process_frame
	await process_frame
	var orphans := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)-orphans_before
	check(orphans <= 0,"Nothing is left behind (%d orphan nodes)" % orphans)
	print("PASS: sky airship" if failures == 0 else "FAIL: sky airship (%d)" % failures)
	quit(1 if failures else 0)
