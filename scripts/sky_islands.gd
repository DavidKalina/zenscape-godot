extends Node3D
## The glide prototype's other islands (scripts/sky_glide.gd): fresh chunks
## set out in the sky, so there is somewhere to fly to.
##
## Only the plate itself is ever live. Every other island is a fresh,
## unbuilt chunk: the Quiet plain a new world starts as (scripts/
## genesis_canvas.gd `shape`), from a seed of its own spot, so the same spot
## always gives the same plain. Each is its ground and its earth sides,
## baked on a worker as it turns up (`_bake`), and
## stands exactly as the plate would if that plain were formed on it. They
## are never copies of the plate: its water, grass, creatures and wind read
## world-space maps and moving rigs that only make sense at the origin, and
## copied out they showed as a hovering brown slab and frozen birds.
##
## Wandering off from the chunks, more turn up (scripts/sky_cells.gd): far
## from every island for a while, one rises out of the haze ahead; fallen
## into the parted cloud sea, one surfaces from it just ahead. Each brings a
## thermal. No more than CAP chunks stand at once; beyond that the farthest
## are let go, never the nearest or the newest, and come back in the same
## spot when flown back to.
##
## Chunks are only translated, never turned, so they light like the plate.
##
## The world is bounded (scripts/sky_world.gd): one seed for every placement
## in the sky, saved with the world; islands, islets and clouds only within
## the bounds round the plate's first home; and round them a ring of
## mountain ranges with a few notches through it, past which an edge wind
## turns the glide home (`air`). --no-ring opens the sky again, endless.
##
## Between them stand the islets (scripts/sky_islets.gd), small scenery, a
## few big forested isles (scripts/sky_forest_isles.gd) to glide in under
## the trees of, and now and then a mountain range of the land far below
## risen up through the cloud sea (scripts/sky_peaks.gd), giant stone with a
## gorge through it. All are solids to the glide (`body`); no island stands
## on a range or an isle.
##
## Flying into a chunk claims it (`claim`): the island left behind is kept
## (its land document, in `built_islands`, saved with the world) and its look baked
## where it stands; the plate is formed as the chunk's plain (or, for an
## island built before, its land is loaded back); then the whole world is
## shifted so the chunk's spot becomes the plate's own, and every island
## moves by the same amount. The chunk showed exactly the plain the plate
## now holds, so the swap can't be seen, and the ~300 places that assume
## the plate sits at the origin never notice. An island left as the fresh
## plain it was claimed as goes back to being a chunk.
##
## Only the land travels with an island. The sky, the day and the weather
## are the world's, and stay as they are.

const Plate = preload("res://scripts/plate.gd")
const HALF := Plate.HALF
## How far past an outlined island's shore a glider is still over it (m).
const CLAIM_MARGIN := 1.0
## Where the copies stand from the plate, in metres: far apart (400 to
## 950 m, over a minute's slow glide, half a minute down a jet stream) and
## at different heights, so each is a destination.
const OFFSETS := [Vector3(380.0,-20.0,-160.0),Vector3(-260.0,25.0,-520.0),Vector3(-640.0,-35.0,120.0),Vector3(180.0,-50.0,700.0),Vector3(820.0,15.0,420.0)]
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyClouds = preload("res://scripts/sky_clouds.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const SkyHomes = preload("res://scripts/sky_homes.gd")
## The world's seed, bounds, ring and edge (scripts/sky_world.gd).
const SkyWorld = preload("res://scripts/sky_world.gd")
## The most chunks standing at once. Each is three draws.
const CAP := 9
## A copy that turns up rises this far (metres) over this long (seconds):
## gently out of the haze, or steeply up out of the cloud sea.
const WANDER_RISE := Vector2(60.0,10.0)
const FALL_RISE := Vector2(140.0,7.0)
## Its thermal stands this far off its middle (10 m clear of the plate's
## side), its base this far down, so it reaches the cushion under the band.
const THERMAL_SIDE := Plate.HALF+10.0
const THERMAL_DOWN := 25.0
## Only parts this near the plate's middle, and smaller than this, are
## hidden while the plate is formed again (`_hide_plate`). That leaves out
## the sky, the fog and anything else world-sized. NEAR keeps 8 m past the
## plate's rim.
const NEAR := Plate.HALF+8.0
const LARGEST := 80.0
## Height lookups snap to this grid. The terrain data memoises every point
## it is asked about, and a glide asks about a great many.
const SNAP := 0.1

var scene: Node3D
var editor: NativeChunkEditor
## Each copy's offset from the plate, the same order as its node.
var offsets: Array[Vector3] = []
## Each copy's spot in home coordinates (SkyCells), and how it rises:
## Vector3(depth, seconds risen, seconds to rise), zero once up.
var homes: Array[Vector3] = []
var _rise: Array[Vector3] = []
var _copies: Array[Node3D] = []
## Where islands turn up (scripts/sky_cells.gd), and the newest one's home.
var cells: SkyCells
var _newest := Vector3.INF
## Nodes never copied (the figure, the glide's own air).
var skip: Array[Node] = []
## Each chunk's plain, the same order as its node; null while it bakes.
var lands: Array = []
## Each chunk's seed (`seed_of`).
var seeds: Array[int] = []
## The jet streams and thermals between the islands (scripts/sky_currents.gd).
var currents: Node3D
## The clouds between them (scripts/sky_clouds.gd).
var clouds: Node3D
## The small islets scattered between them (scripts/sky_islets.gd).
var islets: Node3D
## The mountain ranges risen through the cloud sea (scripts/sky_peaks.gd).
var peaks: Node3D
## The towering cumulus risen out of the cloud sea (scripts/sky_towers.gd).
var towers: Node3D
## The forested isles (scripts/sky_forest_isles.gd).
var isles: Node3D
## The islands built and left, by home key (`_key`): {home, label, document}.
var built_islands := {}
## The swaps' shifts added up: the plate's own home is -origin.
var origin := Vector3.ZERO
## The seed the plate's plain was formed from when it was claimed, or -1
## for a world's first island.
var plate_seed := -1
## True while a claim is under way.
var claiming := false
## True once a glide has shown the islands: made ahead as the world starts
## (`make_ahead`), they stay out of the build view till then, as before.
var _flown := false

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	name = "SkyIslands"
	# The wonders (SkyHomes): the ranges stand, the ring round the world with
	# them (scripts/sky_world.gd); --wonders brings back every other one,
	# --no-peaks takes the ranges away, --no-ring the ring and the bounds.
	var args := OS.get_cmdline_user_args()
	if "--wonders" in args:
		SkyHomes.stone = true
		SkyHomes.isles = true
	if "--no-peaks" in args: SkyHomes.peaks = false
	SkyWorld.read_flags()
	currents = SkyCurrents.new()
	add_child(currents)
	var slots := [Vector3.ZERO]
	slots.append_array(OFFSETS)
	currents.build(slots)
	# The clouds are laid out with the islands (`build`), once the world's
	# seed and its mountains are known: never here, where it would wait on
	# the layout on the main thread.
	clouds = SkyClouds.new()
	add_child(clouds)
	islets = SkyIslets.new()
	islets.palette_source = editor.data._palette
	islets.flora_source = editor.content
	add_child(islets)
	skip.append(islets)
	peaks = SkyPeaks.new()
	peaks.palette_source = editor.data._palette
	peaks.tree_parts = Callable(SkyIslets,"_tree_parts")
	add_child(peaks)
	skip.append(peaks)
	towers = SkyTowers.new()
	add_child(towers)
	skip.append(towers)
	isles = SkyForestIsles.new()
	isles.palette_source = editor.data._palette
	isles.tree_parts = Callable(SkyIslets,"_tree_parts")
	isles.islets = islets
	add_child(isles)
	skip.append(isles)
	show_air(false)

## Sets an island at every fixed slot and every island built, except the
## plate's own, replacing any earlier ones.
func build() -> void:
	clear()
	_keep()
	var slots := [Vector3.ZERO]
	slots.append_array(OFFSETS)
	clouds.build(slots)
	clouds.reset()
	cells = SkyCells.new(slots)
	cells.origin = origin
	currents.position = origin
	clouds.move(origin)
	var spots: Array = slots.duplicate()
	for entry: Dictionary in built_islands.values():
		if not _fixed(entry.home): spots.append(entry.home)
	for home: Vector3 in spots:
		if SkyCells._flat(home,-origin) < 1.0: continue
		_add(home,home+origin,Vector3.ZERO)
		if not _fixed(home): _thermal(home)
	_islet_materials()
	islets.side_source = editor._skirt_mesh.surface_get_material(0) if editor._skirt_mesh != null else null
	islets.reset(cells)
	peaks.ground_source = islets.ground_source
	peaks.canopy_tint = SkyIslets._canopy_tint
	peaks.reset(cells,currents)
	towers.reset(cells,currents)
	isles.ground_source = islets.ground_source
	isles.side_source = editor._skirt_mesh.surface_get_material(0) if editor._skirt_mesh != null else null
	isles.canopy_tint = SkyIslets._canopy_tint
	isles.reset(cells)

func clear() -> void:
	for island in _copies: island.queue_free()
	_copies.clear()
	offsets.clear()
	homes.clear()
	_rise.clear()
	lands.clear()
	seeds.clear()
	_newest = Vector3.INF
	if currents != null: currents.drop_added()
	if islets != null: islets.clear()
	if peaks != null: peaks.clear()
	if towers != null: towers.clear()
	if isles != null: isles.clear()

func _add(home: Vector3, at: Vector3, rise: Vector3) -> Node3D:
	var island := Node3D.new()
	island.name = "Island%d" % get_child_count()
	island.position = at+Vector3.DOWN*rise.x
	island.visible = _air or _flown
	add_child(island)
	_copies.append(island)
	offsets.append(at)
	homes.append(home)
	_rise.append(rise)
	lands.append(null)
	seeds.append(seed_of(home))
	_bake(island,seeds[-1],built_islands.get(_key(home),{}).get("document",{}))
	return island

## Each frame of the glide: copies rise, a new one turns up if the glide has
## wandered off or fallen into the sea (SkyCells `advance`), the farthest
## are let go past CAP, and the clouds follow.
func advance(delta: float, eye: Vector3, heading: float, parted: float) -> void:
	for i in range(_rise.size()):
		if _rise[i] == Vector3.ZERO: continue
		_rise[i].y += delta
		if _rise[i].y >= _rise[i].z: _rise[i] = Vector3.ZERO
		_copies[i].position = offsets[i]+Vector3.DOWN*sunk(i)
	var live := [Vector3.ZERO]
	live.append_array(offsets)
	var found: Variant = cells.advance(delta,eye,heading,live,parted)
	if found != null: realise(found.home,found.kind)
	trim(eye)
	islets.advance(delta,eye)
	peaks.advance(delta,eye)
	towers.advance(delta,eye)
	isles.advance(delta,eye)
	clouds.screen(towers.screens(eye),towers.fade(eye)*0.9)
	var keep: Array = peaks.keep_spots(eye)+isles.keep_spots(eye)
	keep.sort_custom(func(a: Vector4, b: Vector4) -> bool: return Vector2(a.x-eye.x,a.y-eye.z).length() < Vector2(b.x-eye.x,b.y-eye.z).length())
	clouds.keep_off(keep)
	clouds.follow(eye)

## Puts a copy at a home spot, rising from below, with a thermal beside it
## unless it is one of the fixed slots (those have theirs).
func realise(home: Vector3, kind: String) -> void:
	var at := home+cells.origin
	_add(home,at,_rise_for(kind))
	_newest = home
	if not _fixed(home): _thermal(home)

func _thermal(home: Vector3) -> void:
	var a := fposmod(home.x*0.37+home.z*0.71,TAU)
	currents.add_thermal(home+cells.origin+Vector3(cos(a),0.0,sin(a))*THERMAL_SIDE+Vector3.DOWN*THERMAL_DOWN,_key(home))

func _rise_for(kind: String) -> Vector3:
	var r := FALL_RISE if kind == "fall" else WANDER_RISE
	return Vector3(r.x,0.0,r.y)

## The plate's own terrain and still-water materials for the islets, so
## their grass and ponds are drawn as the plate's are.
func _islet_materials() -> void:
	islets.ground_source = editor.terrain.get_active_material(0)
	var water: Material = null
	var view: Node = editor.get("flow_view")
	if view != null and view.get("still") != null: water = (view.still as MeshInstance3D).material_override
	if water == null and editor.content != null: water = editor.content.get("_water_material")
	islets.water_source = water

## How far under its spot copy `index` still is.
func sunk(index: int) -> float:
	var r := _rise[index]
	if r == Vector3.ZERO: return 0.0
	return r.x*(1.0-smoothstep(0.0,r.z,r.y))

## Lets go of the farthest copies past CAP, never the nearest to the eye,
## the newest or one you built.
func trim(eye: Vector3) -> void:
	if _copies.size() <= CAP: return
	var keep := []
	var nearest := INF
	var near_i := -1
	for i in range(offsets.size()):
		var d := Vector2(offsets[i].x-eye.x,offsets[i].z-eye.z).length()
		if d < nearest:
			nearest = d
			near_i = i
		if homes[i].distance_to(_newest) < 1.0 or built_islands.has(_key(homes[i])): keep.append(i)
	keep.append(near_i)
	var freed := SkyCells.trim(eye,offsets,CAP,keep)
	freed.sort()
	freed.reverse()
	for i in freed: _free(i)

func _free(index: int, thermal := true) -> void:
	if thermal and not _fixed(homes[index]): currents.drop_thermals(_key(homes[index]))
	_copies[index].queue_free()
	_copies.remove_at(index)
	offsets.remove_at(index)
	homes.remove_at(index)
	_rise.remove_at(index)
	lands.remove_at(index)
	seeds.remove_at(index)

func _fixed(home: Vector3) -> bool:
	for s in cells.reserved:
		if Vector2(s.x-home.x,s.z-home.z).length() < 1.0: return true
	return false

func _key(home: Vector3) -> String:
	return "%d,%d" % [roundi(home.x),roundi(home.z)]

func built() -> bool:
	return not _copies.is_empty()

func copy_count() -> int:
	return _copies.size()

## The plain a spot gives: one seed per spot, so flown back to, it is the
## same land.
static func seed_of(home: Vector3) -> int:
	return int(SkyCells.noise(Vector2i(roundi(home.x),roundi(home.z)),11)*1000000.0)

## On a worker, a detached copy of the land is shaped as the Quiet plain from
## `chunk_seed`, or given a built island's `document`, and its mesh built,
## as the flip bakes its underside (scripts/diorama_flip.gd `_bake_underside`); its earth sides are fitted
## here on the main thread. Drawn with the plate's own ground and earth-side
## materials, only the plate's palette carries over, never what stands on it.
## A fresh plain is its seed's island (Genesis `shape`), so the far islands
## show their outlines and shore walls as the plate does.
func _bake(island: Node3D, chunk_seed: int, document: Dictionary = {}) -> void:
	var land := editor.data
	var mesh := land.source_mesh
	var arrays := land._arrays.duplicate()
	var palette := {}
	for key in ["sand","gravel","snowline","rock_slope"]: palette[key] = land._palette.get(key)
	var tint: Variant = land._ground_tint
	var offset := land.world_offset
	var baked: Array = []
	var task := WorkerThreadPool.add_task(func() -> void:
		var plain := NativeTerrainData.new()
		for key in palette: plain._palette.set(key,palette[key])
		plain._ground_tint = tint
		plain.world_offset = offset
		plain.setup(mesh,arrays)
		if document.is_empty() or not plain.load_document(document): Genesis.shape(plain,chunk_seed)
		baked.append(plain)
		# Only the island's faces (scripts/island_outline.gd); its shore wall
		# comes with the earth sides below.
		baked.append(plain.play_mesh(plain.build_mesh())))
	while not WorkerThreadPool.is_task_completed(task): await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	if baked.size() < 2 or baked[1] == null or not is_instance_valid(island) or island.is_queued_for_deletion(): return
	var index := _copies.find(island)
	if index < 0: return
	lands[index] = baked[0]
	var ground := _copy(editor.terrain,baked[1])
	var sides := _copy(editor._skirt,editor.skirt_mesh_for(baked[0]))
	island.add_child(ground)
	island.add_child(sides)

## The copy whose footprint holds a global point, or -1. A copy still
## rising or baking can't be claimed yet.
func copy_under(point: Vector3) -> int:
	for i in range(offsets.size()):
		if _rise[i] != Vector3.ZERO or lands[i] == null: continue
		var local := editor.terrain.to_local(point-offsets[i])
		if absf(local.x) > HALF or absf(local.z) > HALF: continue
		if _over_land(lands[i],Vector2(local.x,local.z)): return i
	return -1

## Whether plate point `p` is over `land`'s ground, or within CLAIM_MARGIN of
## it (a full square is all ground). Snapped, as `_height` is, so the glide's
## flight does not fill the terrain's lookup.
func _over_land(land: NativeTerrainData, p: Vector2) -> bool:
	if land.outline.is_empty(): return true
	var at := Vector2(snappedf(p.x,SNAP),snappedf(p.y,SNAP))
	return land.nearest_land(at,0.0,CLAIM_MARGIN) != Vector2.INF

## Makes copy `index` the plate. The island left is kept, and its look baked
## at the plate's spot; the plate's own parts hide while it is formed again
## as the copy's land; then every copy moves by the shift, which is returned
## to add to anything that flies. The world is saved after.
func claim(index: int) -> Vector3:
	claiming = true
	var target := homes[index]
	var places: Node = scene.get("places")
	if places != null: places.busy = true
	var left := -origin
	editor.finish_stroke()
	var fresh := plate_seed >= 0 and editor.data._undo.is_empty()
	if not fresh: built_islands[_key(left)] = {"home":left,"label":_label(),"document":editor.data.to_document()}
	var behind := _add(left,Vector3.ZERO,Vector3.ZERO)
	while _copies.has(behind) and lands[_copies.find(behind)] == null: await get_tree().process_frame
	var hidden := _hide_plate()
	var entry: Dictionary = built_islands.get(_key(target),{})
	if entry.is_empty() or not editor.data.load_document(entry.document):
		await Genesis.form(editor,Genesis.world(seed_of(target)),true)
		plate_seed = seed_of(target)
	else:
		await editor.refresh(get_tree())
		plate_seed = -1
	built_islands.erase(_key(target))
	editor.data._undo.clear()
	editor.data._redo.clear()
	if scene.has_method("_refresh_habitat"): scene._refresh_habitat()
	# The copy may have moved in the list while the plate formed.
	var shift := Vector3.ZERO
	index = homes.find(target)
	if index >= 0:
		shift = -offsets[index]
		_free(index,false)
	for i in range(offsets.size()):
		offsets[i] += shift
		_copies[i].position = offsets[i]+Vector3.DOWN*sunk(i)
	origin += shift
	cells.origin = origin
	currents.position += shift
	clouds.move(shift)
	_show_plate(hidden)
	if places != null:
		places.busy = false
		places.save_places()
	claiming = false
	return shift

func _label() -> String:
	var places: Node = scene.get("places")
	return places._label(scene) if places != null else "Island"

## The plate's drawn parts, put on no render layer, each with the layers it
## had (`_show_plate` gives them back).
func _hide_plate() -> Dictionary:
	var hidden := {}
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == self or node in skip or node is Camera3D: continue
		for child in node.get_children(): stack.append(child)
		if not node is GeometryInstance3D: continue
		var part := node as GeometryInstance3D
		var box := part.global_transform*part.get_aabb()
		var middle := box.get_center()
		if absf(middle.x) > NEAR or absf(middle.z) > NEAR: continue
		if box.size.x > LARGEST or box.size.z > LARGEST: continue
		hidden[part] = part.layers
		part.layers = 0
	return hidden

func _show_plate(hidden: Dictionary) -> void:
	for part: Variant in hidden:
		if is_instance_valid(part): (part as GeometryInstance3D).layers = hidden[part]

## What the world's save keeps of the sky: where the plate stands, what it
## was claimed as, and the islands built and left.
func save_state() -> Dictionary:
	var kept := []
	for entry: Dictionary in built_islands.values():
		kept.append({"home":[entry.home.x,entry.home.y,entry.home.z],"label":entry.label,"document":entry.document})
	return {"origin":[origin.x,origin.y,origin.z],"plate_seed":plate_seed,"built":kept,"seed":SkyWorld.seed}

## Takes a world's saved sky (`save_state`), or none for a new world. The
## islands stand again at the next glide.
func load_state(state: Dictionary) -> void:
	clear()
	built_islands = {}
	origin = Vector3.ZERO
	plate_seed = -1
	var at: Variant = state.get("origin")
	if at is Array and at.size() == 3: origin = Vector3(float(at[0]),float(at[1]),float(at[2]))
	plate_seed = int(state.get("plate_seed",-1))
	for entry: Variant in state.get("built",[]):
		if not entry is Dictionary or not entry.get("home") is Array or entry.home.size() != 3 or not entry.get("document") is Dictionary: continue
		var home := Vector3(float(entry.home[0]),float(entry.home[1]),float(entry.home[2]))
		built_islands[_key(home)] = {"home":home,"label":str(entry.get("label","Island")),"document":entry.document}
	# The world's seed: a world saved before it had one keeps the sky it had
	# (SkyWorld LEGACY_SEED); --sky-seed=N tries another. Never changed
	# under a worker working out the layout.
	SkyWorld.settle()
	SkyWorld.seed = int(state.get("seed",SkyWorld.LEGACY_SEED))
	if SkyWorld.seed_flag() >= 0: SkyWorld.seed = SkyWorld.seed_flag()
	_keep()
	# The world's layout worked out on a worker from here, as the world
	# starts (SkyWorld `prepare`); the build view stands its ranges once it
	# is (`_process`). A skyline made for another world's seed is let go.
	SkyWorld.prepare()
	if peaks != null and peaks.ring.line_count() > 0: peaks.ring.warm(peaks)
	_flown = false

## Sets the mountain ring's skyline (scripts/sky_ring.gd) to be worked out
## on workers, if it isn't yet (it is from the world's start: `_process`);
## nothing waits on it.
func warm_ring() -> void:
	if peaks == null: return
	_keep()
	peaks.ring.warm(peaks)

## Whether the glide's sky is out (`show_air`).
var _air := false

## The build view: the mountains stand round the plate as they do round the
## glide (SkyPeaks `overview`), on their skylines, warmed on workers as the
## world starts; the rest of the glide's sky stays away.
func _process(_delta: float) -> void:
	if _air or peaks == null or not SkyWorld.ring_on(): return
	if peaks.ground_source == null:
		# The plate's own ground material, once it has one.
		var ground: Material = editor.terrain.get_active_material(0) if editor != null and editor.terrain != null else null
		if ground == null: return
		peaks.ground_source = ground
		peaks.canopy_tint = SkyIslets._canopy_tint
		peaks._material = null
	peaks.overview(origin)
	# The ranges within reach of the plate made ahead and kept fresh (a new
	# layout, a claim, a new palette), so a glide starts among them whole.
	_ahead_since += _delta
	if _ahead_since >= 1.0 and SkyWorld.ready():
		_ahead_since = 0.0
		peaks.premake(-origin)

var _ahead_since := 1.0

# --- Made ahead, as a world starts ----------------------------------------------------
# Under the loading screen (scripts/sky_reveal.gd) the sky the world will
# show is made before it is seen: the layout, every range's skyline (the
# build view's mountains), the ranges within reach of the plate in full
# and the islands, islets and cumulus round it (the glide's first sight),
# all hidden till they are wanted.

## Where the glide starts from: over the plate (global).
const AHEAD_EYE := Vector3(0.0,50.0,0.0)

## A frame's making ahead: everything above set going, and what workers
## have finished stood up (hidden: islets, cumulus and isles show only in
## the glide, the islands only once one has been flown).
func make_ahead(delta: float) -> void:
	if not SkyWorld.ring_on() or peaks == null: return
	SkyWorld.prepare()
	_note_ahead()
	if peaks.ground_source == null or not SkyWorld.ready(): return
	peaks.premake(-origin)
	if not built(): build()
	islets.advance(delta,AHEAD_EYE)
	towers.advance(delta,AHEAD_EYE)
	isles.advance(delta,AHEAD_EYE)

## True once the sky the world will show is made (`make_ahead`): with the
## ring off, at once (nothing is laid out ahead then).
func sky_ready() -> bool:
	if not SkyWorld.ring_on() or peaks == null: return true
	if not SkyWorld.ready() or not peaks.ring.whole: return false
	if not peaks.premade_whole(-origin): return false
	if not built() or lands.has(null): return false
	return islets._making.is_empty() and towers._making.is_empty() and isles._making.is_empty() and islets._wanted.is_empty()

## When each part of it was made (msec, from the first ask), for the
## record (scripts/sky_reveal.gd).
var ahead_times := {}

func _note_ahead() -> void:
	var now := Time.get_ticks_msec()
	if not ahead_times.has("asked"): ahead_times.asked = now
	var parts := {"layout":SkyWorld.ready(),"skylines":SkyWorld.ready() and peaks.ring.whole,"ranges":SkyWorld.ready() and peaks.premade_whole(-origin),"islands":built() and not lands.has(null),"islets":built() and islets._making.is_empty() and islets._wanted.is_empty() and towers._making.is_empty()}
	for part: String in parts:
		if parts[part] and not ahead_times.has(part): ahead_times[part] = now-int(ahead_times.asked)

## How much of it is made, 0 to 1, by rough share of the time each takes:
## the layout, the skylines, the ranges near in full, the islands.
func sky_progress() -> float:
	if not SkyWorld.ring_on() or peaks == null: return 1.0
	var done := 0.1 if SkyWorld.ready() else 0.0
	if SkyWorld.ready():
		done += 0.55*peaks.ring.progress()
		done += 0.2*peaks.premade_progress(-origin)
		if built(): done += 0.15*float(lands.size()-lands.count(null))/float(maxi(lands.size(),1))
	return clampf(done,0.0,1.0)

## Stand-ins for everything the sky will draw, each mesh and material once
## (scripts/pipeline_warmup.gd: drawn tiny before the camera for a few
## frames, so their pipelines are built under the loading screen): the
## skylines, solid and fading; a range made in full, the cloud at its foot
## and its spruces; and whatever stands under the sky now (islands, islets,
## cumulus, clouds), hidden or not.
func standins() -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	var seen := {}
	_standins_of(self,out,seen)
	if peaks != null and not peaks.premade.is_empty():
		var made: Dictionary = peaks.premade.values()[0]
		var holder := Node3D.new()
		for mesh: ArrayMesh in [made.body,made.far]:
			mesh.surface_set_material(0,peaks._ground())
			var body := MeshInstance3D.new()
			body.mesh = mesh
			holder.add_child(body)
		if not made.shape.wraps.is_empty(): holder.add_child(peaks._wrap(made.shape))
		if peaks.tree_parts.is_valid(): peaks._plant(holder,made.shape)
		_standins_of(holder,out,seen)
		holder.free()
	# Fading (the skylines' reveal and swaps, the far faces' visibility
	# fade): the same meshes through the transparent pass.
	for node in out.duplicate():
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh:
			var faded := node.duplicate() as MeshInstance3D
			faded.transparency = 0.5
			out.append(faded)
			break
	return out

func _standins_of(node: Node, out: Array[GeometryInstance3D], seen: Dictionary) -> void:
	for child in node.get_children():
		_standins_of(child,out,seen)
		var g := child as GeometryInstance3D
		if g == null: continue
		var drawn: Resource = (g as MeshInstance3D).mesh if g is MeshInstance3D else ((g as MultiMeshInstance3D).multimesh if g is MultiMeshInstance3D else null)
		if drawn == null: continue
		var key := [drawn.get_rid(),g.material_override.get_rid() if g.material_override != null else RID()]
		if seen.has(key): continue
		seen[key] = true
		var copy: GeometryInstance3D
		if g is MeshInstance3D:
			var m := MeshInstance3D.new()
			m.mesh = (g as MeshInstance3D).mesh
			for k in range(mini(m.get_surface_override_material_count(),(g as MeshInstance3D).get_surface_override_material_count())):
				m.set_surface_override_material(k,(g as MeshInstance3D).get_surface_override_material(k))
			copy = m
		else:
			var mm := MultiMeshInstance3D.new()
			mm.multimesh = (g as MultiMeshInstance3D).multimesh
			copy = mm
		copy.material_override = g.material_override
		copy.material_overlay = g.material_overlay
		copy.cast_shadow = g.cast_shadow
		copy.layers = g.layers
		copy.extra_cull_margin = 16384.0
		out.append(copy)

## Tells the ring which islands it must keep clear of and hold inside its
## edge (SkyWorld `keep`): every one built and left, and the plate's own.
func _keep() -> void:
	var homes: Array[Vector3] = [-origin]
	for entry: Dictionary in built_islands.values(): homes.append(entry.home)
	SkyWorld.keep(homes)

## A new instance of `source` that shares its materials, and its mesh unless
## given `drawn`.
func _copy(source: GeometryInstance3D, drawn: Mesh = null) -> GeometryInstance3D:
	var copy: GeometryInstance3D
	if source is MultiMeshInstance3D:
		copy = MultiMeshInstance3D.new()
		(copy as MultiMeshInstance3D).multimesh = (source as MultiMeshInstance3D).multimesh
	else:
		var mesh := MeshInstance3D.new()
		var from := source as MeshInstance3D
		mesh.mesh = drawn if drawn != null else from.mesh
		# The two counts can differ if the plate's mesh is mid-rebuild.
		for s in range(mini(from.get_surface_override_material_count(),mesh.get_surface_override_material_count())):
			mesh.set_surface_override_material(s,from.get_surface_override_material(s))
		copy = mesh
	copy.material_override = source.material_override
	copy.material_overlay = source.material_overlay
	copy.transparency = source.transparency
	copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	copy.custom_aabb = source.custom_aabb
	copy.extra_cull_margin = source.extra_cull_margin
	copy.layers = source.layers
	copy.transform = source.global_transform
	return copy

## The currents and clouds show only while gliding; the build view stays
## as it was, but for the mountains: they stand round the plate in both
## (`_process`). Back from a glide, the ranges made in full near it are let
## go, so the build view stands on their skylines.
func show_air(on: bool) -> void:
	_air = on
	if on and not _flown:
		_flown = true
		for island in _copies: island.visible = true
	currents.visible = on
	clouds.visible = on
	islets.visible = on
	peaks.visible = on or SkyWorld.ring_on()
	if not on: peaks.let_go()
	towers.visible = on
	isles.visible = on

## How deep a global point is in cloud, for the vapour: a drifting one's
## heap (SkyClouds `inside`) or a tower's (SkyTowers `fade`, by its VEIL:
## a tower draws its own fog round the eye), 0 to 1.
func in_cloud(point: Vector3, time: float) -> float:
	return maxf(clouds.inside(point,time),towers.fade(point)*SkyTowers.VEIL)

## The air at a global point (SkyCurrents `air_at`), and past the mountain
## ring the edge wind blowing home (SkyWorld `edge_air`).
func air(point: Vector3) -> Dictionary:
	var here: Dictionary = currents.air_at(point)
	var edge := SkyWorld.edge_air(point-origin)
	if edge.is_empty(): return here
	here.wind = (here.get("wind",Vector3.ZERO) as Vector3)+(edge.wind as Vector3)
	here.along = (here.get("along",Vector3.ZERO) as Vector3)+(edge.along as Vector3)
	return here

## The height of whatever island stands under a global point, or null over
## open air.
func ground(point: Vector3) -> Variant:
	var plate: Variant = _height(point)
	if plate != null: return plate
	for i in range(offsets.size()):
		var offset := offsets[i]+Vector3.DOWN*sunk(i)
		if lands[i] == null: continue
		var h: Variant = _height(point-offset,lands[i])
		if h != null: return float(h)+offset.y
	var islet: Variant = islets.body(point)
	if islet != null: return (islet as Vector2).x
	var isle: Variant = isles.ground(point)
	if isle != null: return isle
	return peaks.ground(point)

## The island whose footprint holds a global point, as a solid: Vector2(its
## ground's height there, the underside there: the hanging rock under an
## island with an outline (NativeTerrainData `underside`), or the square
## slab's flat base, SLAB_BASE), in global metres, or null over open air.
func body(point: Vector3) -> Variant:
	var plate: Variant = _body(point)
	if plate != null: return plate
	for i in range(offsets.size()):
		var offset := offsets[i]+Vector3.DOWN*sunk(i)
		if lands[i] == null: continue
		var b: Variant = _body(point-offset,lands[i])
		if b != null: return (b as Vector2)+Vector2(offset.y,offset.y)
	var islet: Variant = islets.body(point)
	if islet != null: return islet
	var isle: Variant = isles.body(point)
	if isle != null: return isle
	return peaks.body(point)

## True where the solid at a global point is one the glide only rides where
## it is gentle and is turned aside by at its sides (SkyGlide `stone`): a
## range's rock, or a forested isle's trunks and crowns.
func stone(point: Vector3) -> bool:
	return isles.stone(point) or peaks.solid(point)

func _body(point: Vector3, land: NativeTerrainData = null) -> Variant:
	var top: Variant = _height(point,land)
	if top == null: return null
	var local := editor.terrain.to_local(point)
	# The rock under an island with an outline (NativeTerrainData `underside`),
	# at the spot `_height` reads, or the slab's flat base.
	var at := Vector2(snappedf(local.x,SNAP),snappedf(local.z,SNAP))
	var base := (land if land != null else editor.data).underside(at)
	var under := editor.terrain.to_global(Vector3(local.x,base,local.z)).y
	return Vector2(float(top),under)

## The plate's height under a global point, in global metres, or null off it;
## or, given the flat chunk's `land`, a chunk's at the plate's spot.
func _height(point: Vector3, land: NativeTerrainData = null) -> Variant:
	var local := editor.terrain.to_local(point)
	if absf(local.x) > HALF or absf(local.z) > HALF: return null
	var at := Vector2(snappedf(local.x,SNAP),snappedf(local.z,SNAP))
	var h: Variant = (land if land != null else editor.data).ground_height(at)
	if h == null: return null
	return editor.terrain.to_global(Vector3(at.x,float(h),at.y)).y
