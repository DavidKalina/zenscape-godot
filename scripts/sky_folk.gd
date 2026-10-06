extends Node3D
## The sky folk living on the islands (scripts/islander_figure.gd): a few
## on every island but the plate's first home, the same people on the same
## island every time (from its seed). They stand together on dry, gentle
## ground in from the shore, and ride with their island as it rises, waits
## off in the sky or becomes the plate (scripts/sky_islands.gd).
##
## Left alone they potter: stand a while, then toddle a few steps off
## round their spot and stand again. A plane flying over within CALL
## metres and they turn to it and hail, jumping and waving both arms; the
## wanderer walking up within GREET and they turn and wave. Only those
## within LIVE metres of the eye move; past SHOW they are not drawn.
##
## Islands are copies, parented to SkyIslands, each in its own frame; the
## plate's folk stand in SkyIslands' own frame (`plate_holder`) and keep
## to the ground as it is shaped under them. Each person keeps to their
## land's own frame (plate metres, as NativeTerrainData reads them), set
## in their holder's by `frame`, the land's place in it (only ever moved,
## never turned).
##
## Settling is part of the sky streaming in, so it shares the sky's frame
## budget (scripts/sky_commits.gd): islands are queued (`settle_later`) and
## one settles in a frame that still has room, never in the frame its
## island stood up in.

const IslanderFigure = preload("res://scripts/islander_figure.gd")
const Plate = preload("res://scripts/plate.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
## The figure's scale to the world: its eyes at the wanderer's height.
const SCALE := 1.9
## People an island, fewest and most, and how far apart they stand (m).
const PER_ISLAND := Vector2i(1,3)
const APART := Vector2(1.3,2.6)
## Ground to stand on: at least INSET m in from the shore, no water within
## DRY m, and no more than STEEP m of rise across FLAT m.
const INSET := 3.0
const DRY := 1.5
const FLAT := 0.8
const STEEP := 0.3
## How far clear of anything standing on the land (a tree, a stone) they
## keep, past its own size (m).
const CLEAR := 0.9
## How far from their spot they wander (m), and seconds stood between walks.
const WANDER := 3.5
const REST := Vector2(2.0,6.0)
## Turning, radians a second; and how far off the way it is still walking.
const TURN := 4.0
const WALK_OFF := 1.0
## Ranges (m): drawn, moving, hailing a plane over them, greeting the
## wanderer; and how far over them a plane must be to be hailed.
const SHOW := 260.0
const LIVE := 120.0
const CALL := 90.0
const GREET := 7.0
const OVER := 8.0
const SCARVES := [Color("d9573a"),Color("e2b84a"),Color("6f8fa8"),Color("7fa08a"),Color("cf6b4a"),Color("b85c7a")]

## The islands (scripts/sky_islands.gd), for the plate's folk; unset in a
## test.
var islands: Node3D
## Each person: {figure, land, frame, at and home (Vector2s on the land),
## target (one, or null), rest (seconds left standing), rng}.
var people := []
var plate_holder: Node3D
var _plate_key := ""
var _plate_wait := 0.0
## Islands waiting to be settled: [holder, seed, land, frame].
var _queue := []

func _init() -> void:
	name = "SkyFolk"
	plate_holder = Node3D.new()
	plate_holder.name = "PlateFolk"
	add_child(plate_holder)

## Puts an island's folk on `holder` (the island's node), from `chunk_seed`,
## on `land` (a NativeTerrainData: its ground, shore and water), the land
## standing at `frame` in the holder's frame. Returns how many.
func settle(holder: Node3D, chunk_seed: int, land: Object, frame: Transform3D) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed*7919+17
	var count := rng.randi_range(PER_ISLAND.x,PER_ISLAND.y)
	var half := Plate.HALF-INSET
	var spots: Array[Vector2] = []
	for attempt in range(80):
		if spots.size() >= count: break
		var p: Vector2
		if spots.is_empty(): p = Vector2(rng.randf_range(-half,half),rng.randf_range(-half,half))
		else: p = spots[0]+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(APART.x,APART.y)*(1.0+spots.size()*0.3)
		if not good(p,land): continue
		if spots.any(func(q: Vector2) -> bool: return q.distance_to(p) < APART.x): continue
		spots.append(p)
	for p in spots:
		var figure := IslanderFigure.new(SCARVES[rng.randi()%SCARVES.size()])
		figure.scale = Vector3.ONE*SCALE
		figure.rotation.y = rng.randf()*TAU
		figure.set_process(false)
		holder.add_child(figure)
		var person := {"figure":figure,"land":land,"frame":frame,"at":p,"home":p,"target":null,"rest":rng.randf_range(REST.x,REST.y),"rng":rng}
		people.append(person)
		_ground(person)
	return spots.size()

## Queues an island's folk (`settle`) for a frame with room in the sky's
## budget.
func settle_later(holder: Node3D, chunk_seed: int, land: Object, frame: Transform3D) -> void:
	_queue.append([holder,chunk_seed,land,frame])

## Settles the next queued island, if this frame has room; true if one was.
func _settle_next() -> bool:
	while not _queue.is_empty():
		var next: Array = _queue[0]
		if not is_instance_valid(next[0]) or (next[0] as Node).is_queued_for_deletion():
			_queue.pop_front()
			continue
		if not SkyCommits.open(): return false
		_queue.pop_front()
		var began := Time.get_ticks_usec()
		settle(next[0],next[1],next[2],next[3])
		SkyCommits.spend("folk",Time.get_ticks_usec()-began)
		return true
	return false

## Whether someone can stand at `p`: on the land in from its shore, dry,
## gentle, and clear of what stands on it (its `objects`).
static func good(p: Vector2, land: Object) -> bool:
	if land.nearest_land(p,INSET,0.0) != p: return false
	var h: Variant = _height(land,p)
	if h == null: return false
	if land.water_reaches(Rect2(p-Vector2.ONE*DRY,Vector2.ONE*DRY*2.0)): return false
	for d in [Vector2(FLAT,0.0),Vector2(-FLAT,0.0),Vector2(0.0,FLAT),Vector2(0.0,-FLAT)]:
		var e: Variant = _height(land,p+d)
		if e == null or absf(float(e)-float(h)) > STEEP: return false
	var things: Variant = land.get("objects")
	if things is Array:
		for item: Dictionary in things:
			if Vector2(float(item.get("x",INF)),float(item.get("z",INF))).distance_to(p) < CLEAR+0.5*float(item.get("scale",1.0)): return false
	return true

## The land's ground at `p`, or null off it; read on a 0.1 m grid, as the
## islands read it (SkyIslands `_height`), so walking does not fill the
## terrain's lookup.
static func _height(land: Object, p: Vector2) -> Variant:
	return land.ground_height(p.snapped(Vector2.ONE*0.1))

## Lets go of the plate's folk.
func clear_plate() -> void:
	for person: Dictionary in people.duplicate():
		if is_instance_valid(person.figure) and person.figure.get_parent() == plate_holder:
			person.figure.free()
	_prune()
	_plate_key = ""

func _process(delta: float) -> void:
	_settle_next()
	if islands != null: _keep_plate(delta)
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	step(delta,camera.global_position,islands != null and bool(islands.get("_air")))

## The plate's folk: whenever the plate is somewhere new (claimed or
## loaded), the folk of that spot, once its ground is formed. None on the
## first home.
func _keep_plate(delta: float) -> void:
	if islands.claiming: return
	var home: Vector3 = -islands.origin
	var key: String = islands._key(home)
	if key == _plate_key: return
	_plate_wait -= delta
	if _plate_wait > 0.0: return
	_plate_wait = 1.0
	clear_plate()
	if home.length() < 1.0:
		_plate_key = key
		return
	var land: Object = islands.editor.data
	if not land._shore_ready or not SkyCommits.open(): return
	var began := Time.get_ticks_usec()
	settle(plate_holder,islands.seed_of(home),land,plate_holder.global_transform.affine_inverse()*islands.editor.terrain.global_transform)
	SkyCommits.spend("folk",Time.get_ticks_usec()-began)
	_plate_key = key

func _prune() -> void:
	people = people.filter(func(person: Dictionary) -> bool: return is_instance_valid(person.figure) and not person.figure.is_queued_for_deletion())

## One frame for everyone: drawn and moving by their distance from `eye`;
## those moving hail a plane over them (`flying`), greet the wanderer near,
## or potter about.
func step(delta: float, eye: Vector3, flying: bool) -> void:
	_prune()
	for person: Dictionary in people:
		var figure: Node3D = person.figure
		var at := figure.global_position if figure.is_inside_tree() else figure.position
		var far := at.distance_to(eye)
		figure.visible = far < SHOW
		var live := far < LIVE and figure.is_visible_in_tree()
		figure.set_process(live)
		if not live: continue
		var level := Vector2(eye.x-at.x,eye.z-at.z).length()
		if flying and level < CALL and eye.y-at.y > OVER:
			figure.play("hail")
			person.target = null
			_face(figure,_toward(figure,eye),delta)
		elif not flying and far < GREET:
			figure.play("wave")
			person.target = null
			_face(figure,_toward(figure,eye),delta)
		else:
			_potter(person,delta)
		_ground(person)

## Stands a while, then walks to a spot near home, turning on the way.
func _potter(person: Dictionary, delta: float) -> void:
	var figure: Node3D = person.figure
	var rng: RandomNumberGenerator = person.rng
	if person.target == null:
		figure.play("idle")
		person.rest -= delta
		if person.rest > 0.0: return
		person.rest = rng.randf_range(REST.x,REST.y)
		for attempt in range(6):
			var p: Vector2 = person.home+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.8,WANDER)
			if good(p,person.land):
				person.target = p
				break
		return
	var here: Vector2 = person.at
	var to: Vector2 = person.target-here
	if to.length() < 0.15:
		person.target = null
		return
	var off := _face(figure,atan2(-to.x,-to.y),delta)
	if absf(off) > WALK_OFF:
		figure.play("idle")
		return
	figure.play("walk")
	var stride := minf(IslanderFigure.WALK_SPEED*SCALE*delta,to.length())
	var ahead := Vector2(-sin(figure.rotation.y),-cos(figure.rotation.y))
	var next := here+ahead*stride
	if _height(person.land,next) == null:
		person.target = null
		return
	person.at = next

## Keeps them on the ground as it is (the plate's may be shaped under
## them); off the land, back home.
func _ground(person: Dictionary) -> void:
	var figure: Node3D = person.figure
	var at: Vector2 = person.at
	var h: Variant = _height(person.land,at)
	if h == null:
		at = person.home
		h = _height(person.land,at)
		if h == null: return
		person.at = at
		person.target = null
	figure.position = (person.frame as Transform3D)*Vector3(at.x,float(h),at.y)

## The turn (about y, in its holder's frame) that faces `point` (global).
func _toward(figure: Node3D, point: Vector3) -> float:
	var local: Vector3 = (figure.get_parent() as Node3D).to_local(point) if figure.is_inside_tree() else point
	var d: Vector3 = local-figure.position
	return atan2(-d.x,-d.z)

## Turns towards `yaw` at TURN; returns how far off it still is.
func _face(figure: Node3D, yaw: float, delta: float) -> float:
	var off := wrapf(yaw-figure.rotation.y,-PI,PI)
	figure.rotation.y += clampf(off,-TURN*delta,TURN*delta)
	return wrapf(yaw-figure.rotation.y,-PI,PI)
