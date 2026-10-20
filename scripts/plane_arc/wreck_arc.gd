extends "res://scripts/plane_arc/plane_arc.gd"
## The plane's arc on the wreck cluster (studies/wreck_cluster.gd): the six
## parts of scripts/plane_arc/plane_arc.gd (found on foot, carried, fitted
## at the broken plane; with all six fitted it flies), laid at the points
## the cluster's deal gives (`lay_out`, id -> world point) instead of the
## aqueduct region's fixed spots. All still parts: no ferry, no salvager's
## rope, no bell. Nothing is saved: what's taken and fitted lives in memory
## only, and `lay_out` again takes every part off the plane and lays them
## afresh (the cluster's re-deal).
##
## Flags: --plane-fixed (or --fly) starts it repaired, as does the cluster
## unless --wreck-start (its `parts_on`); --parts-carried
## starts carrying all six; --part-at=<id> starts the pilot by that part.

## The parts' pop as each is taken.
const TAKEN_HERE := {"wheel":"The wheel","cowl":"The cowl","fin":"The tail fin","wingtip":"The wingtip","propeller":"The propeller","windscreen":"The windscreen"}

func setup(scene: Node3D) -> void:
	host = scene
	var args := LaunchArgs.user_args()
	fixed = args.has("--plane-fixed") or args.has("--fly") or host.get("parts_on") == false
	for arg: String in args:
		if arg.begins_with("--fly-at="): fixed = true
		elif arg.begins_with("--part-at="): _part_at = arg.get_slice("=",1)
	keep = false
	_moments = host.get("_moments")
	if _moments == null:
		_moments = MomentsHud.new()
		add_child(_moments)
	cough = PlaneCough.new()
	add_child(cough)
	# The parts' sounds (the base's `_seat` and `take` play them).
	sounds = PartSounds.new()
	add_child(sounds)

## Every part off the plane and laid at `points` (id -> world middle), or
## all carried with `all_carried`; the plane dressed broken again. The ids
## in `hidden` are inside a cache (studies/wreck_cluster_caches.gd): their
## holders made but unseen and untakeable ("hidden") until `unhide`.
func lay_out(points: Dictionary, all_carried := false, hidden: Array = []) -> void:
	_clear()
	for id: String in IDS:
		if all_carried:
			state[id] = "carried"
			carried.append(id)
			holders[id] = _make(id,true)
		elif id in hidden:
			state[id] = "hidden"
			var held := _make(id,false)
			held.visible = false
			holders[id] = held
		elif points.has(id):
			state[id] = "laid"
			var at: Vector3 = points[id]
			spots[id] = {"at":at,"glint":at,"stand":at+Vector3(0.0,-PartSpots.HOVER,1.6),"face":Vector2(0.0,-1.0)}
			var holder := _make(id,false)
			holder.position = at
			holders[id] = holder
			spot(holder,"")
		else:
			# No spot for it: fitted, so the plane can still fly.
			state[id] = "fitted"
	_follow(0.0,true)
	var figure: Node3D = host.get("plane_figure")
	if figure != null: dress(figure)

## Part `id`'s holder while it is hidden (the cache's find), or null.
func hidden_holder(id: String) -> Node3D:
	return holders.get(id) if state.get(id,"") == "hidden" else null

## Hidden part `id` out of its cache and settled where its holder hovers:
## laid there, glinting, taken as any laid part.
func unhide(id: String) -> void:
	if state.get(id,"") != "hidden": return
	var holder: Node3D = holders.get(id)
	if holder == null or not is_instance_valid(holder): return
	var at := holder.global_position
	state[id] = "laid"
	holder.visible = true
	spots[id] = {"at":at,"glint":at,"stand":at+Vector3(0.0,-PartSpots.HOVER,1.6),"face":Vector2(0.0,-1.0)}
	spot(holder,"")

func _clear() -> void:
	for h: Variant in holders.values():
		if is_instance_valid(h): (h as Node).queue_free()
	for g: Variant in _glints.values():
		if is_instance_valid(g): (g as Node).queue_free()
	for f: Dictionary in _flying:
		if is_instance_valid(f.holder): (f.holder as Node).queue_free()
	holders = {}
	_glints = {}
	spots = {}
	state = {}
	carried.clear()
	fitting.clear()
	_flying.clear()
	_fit_left = 0.0
	_last = Vector3.INF
	cowl = ""
	torn = {}

## Every part here lies still where it was dealt.
func kind(_id: String) -> String:
	return "still"

func place_fin() -> void:
	pass

## His middle at `point` this frame: every laid part within his reach of the
## way he moved since the last is taken (the base's, with no rope's load).
func touch(point: Vector3, scale := 1.0) -> void:
	var from := _last if _last != Vector3.INF and _last.distance_to(point) <= JUMP else point
	_last = point
	for id: String in IDS:
		if state.get(id,"") != "laid": continue
		var holder: Variant = holders.get(id)
		if holder == null or not is_instance_valid(holder): continue
		var at: Vector3 = (holder as Node3D).global_position
		var reach := Lines.WALKER_REACH*scale+SIZE*0.5
		if Geometry3D.get_closest_point_to_segment(at,from,point).distance_to(at) < reach: take(id)

func take(id: String) -> void:
	if state.get(id,"") != "laid": return
	state[id] = "carried"
	carried.append(id)
	var holder: Node3D = holders.get(id)
	if holder == null or not is_instance_valid(holder): holder = _make(id,false)
	holders[id] = holder
	holder.remove_from_group(Telescope.GROUP)
	holder.set("turning",true)
	holder.global_basis = Basis.IDENTITY
	_shrink(holder)
	if _moments != null:
		_moments.pop("%s: it rides with you to the plane" % TAKEN_HERE[id],2.6)
		_moments.blip(2)

## The parts laid now: id -> world middle.
func laid_points() -> Dictionary:
	var out := {}
	for id: String in IDS:
		if state.get(id,"") == "laid" and is_instance_valid(holders.get(id)): out[id] = (holders[id] as Node3D).global_position
	return out

## Starts the pilot by part `id`'s spot.
func _start_by(id: String) -> void:
	if not spots.has(id):
		push_warning("wreck arc: --part-at=%s: no such part laid (%s)" % [id,", ".join(PackedStringArray(IDS))])
		return
	var s: Dictionary = spots[id]
	var at: Vector3 = s.stand
	if host.has_method("safe_ground"): at = host.safe_ground(at)
	host.set("_place",Vector4(at.x,at.y,at.z,0.0))

## --part-at once the deal is laid (the host calls it).
func start_by_flag() -> void:
	if _part_at != "": _start_by(_part_at)

# --- Torn off in flight (scripts/carry/plane_strain.gd) ------------------------------

## The parts strain tore off the plane in flight (id -> true) till fitted
## again; with --plane-fixed too, so a fixed plane can still break.
var torn := {}

## Whether the plane flies: none torn off, and (unless fixed) all six fitted.
func flies() -> bool:
	return missing().is_empty()

## The parts not fitted (with the plane fixed, only those torn off).
func missing() -> Array:
	return IDS.filter(func(id: String) -> bool: return state.get(id,"") != "fitted" and (not fixed or torn.has(id)))

func dress(figure: Node3D) -> void:
	if figure == null or not figure.has_method("set_missing"): return
	figure.set_missing(missing())

## Part `id` torn off the plane: off the figure, falling (not yet laid).
func tear(id: String) -> void:
	torn[id] = true
	state[id] = "falling"
	var figure: Node3D = host.get("plane_figure")
	if figure != null: figure.set_missing(missing())

## Part `id` laid at `at` (world middle), glinting, taken as any laid part.
func lay_at(id: String, at: Vector3) -> void:
	if is_instance_valid(holders.get(id)): (holders[id] as Node).queue_free()
	state[id] = "laid"
	spots[id] = {"at":at,"glint":at,"stand":at+Vector3(0.0,-PartSpots.HOVER,1.6),"face":Vector2(0.0,-1.0)}
	var holder := _make(id,false)
	holder.position = at
	holders[id] = holder
	spot(holder,"")

func fit_all() -> void:
	for id: String in carried: torn.erase(id)
	super.fit_all()
