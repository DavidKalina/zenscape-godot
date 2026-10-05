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
## Between them stand the islets (scripts/sky_islets.gd), small scenery, and
## now and then a mountain range of the land far below risen up through the
## cloud sea (scripts/sky_peaks.gd), giant stone with a gorge through it.
## Both are solids to the glide (`body`); no island stands on a range.

const HALF := 14.0
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
## The most chunks standing at once. Each is three draws.
const CAP := 9
## A copy that turns up rises this far (metres) over this long (seconds):
## gently out of the haze, or steeply up out of the cloud sea.
const WANDER_RISE := Vector2(60.0,10.0)
const FALL_RISE := Vector2(140.0,7.0)
## Its thermal stands this far off its middle, its base this far down, so
## it reaches the cushion under the band.
const THERMAL_SIDE := 24.0
const THERMAL_DOWN := 25.0
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

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	name = "SkyIslands"
	currents = SkyCurrents.new()
	add_child(currents)
	var slots := [Vector3.ZERO]
	slots.append_array(OFFSETS)
	currents.build(slots)
	clouds = SkyClouds.new()
	add_child(clouds)
	clouds.build(slots)
	islets = SkyIslets.new()
	islets.palette_source = editor.data._palette
	add_child(islets)
	skip.append(islets)
	peaks = SkyPeaks.new()
	peaks.palette_source = editor.data._palette
	peaks.tree_parts = Callable(SkyIslets,"_tree_parts")
	add_child(peaks)
	skip.append(peaks)
	show_air(false)

## Sets a flat chunk at every offset, replacing any earlier ones.
func build() -> void:
	clear()
	currents.position = Vector3.ZERO
	clouds.reset()
	var slots := [Vector3.ZERO]
	slots.append_array(OFFSETS)
	cells = SkyCells.new(slots)
	for offset: Vector3 in OFFSETS: _add(offset,offset,Vector3.ZERO)
	_islet_materials()
	islets.reset(cells)
	peaks.ground_source = islets.ground_source
	peaks.canopy_tint = SkyIslets._canopy_tint
	peaks.reset(cells,currents)

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

func _add(home: Vector3, at: Vector3, rise: Vector3) -> void:
	var island := Node3D.new()
	island.name = "Island%d" % get_child_count()
	island.position = at+Vector3.DOWN*rise.x
	add_child(island)
	_copies.append(island)
	offsets.append(at)
	homes.append(home)
	_rise.append(rise)
	lands.append(null)
	seeds.append(seed_of(home))
	_bake(island,seeds[-1])

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
	clouds.keep_off(peaks.keep_spots(eye))
	clouds.follow(eye)

## Puts a copy at a home spot, rising from below, with a thermal beside it
## unless it is one of the fixed slots (those have theirs).
func realise(home: Vector3, kind: String) -> void:
	var at := home+cells.origin
	_add(home,at,_rise_for(kind))
	_newest = home
	if _fixed(home): return
	var a := fposmod(home.x*0.37+home.z*0.71,TAU)
	currents.add_thermal(at+Vector3(cos(a),0.0,sin(a))*THERMAL_SIDE+Vector3.DOWN*THERMAL_DOWN,_key(home))

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

## Lets go of the farthest copies past CAP, never the nearest to the eye or
## the newest.
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
		if homes[i].distance_to(_newest) < 1.0: keep.append(i)
	keep.append(near_i)
	var freed := SkyCells.trim(eye,offsets,CAP,keep)
	freed.sort()
	freed.reverse()
	for i in freed: _free(i)

func _free(index: int) -> void:
	if not _fixed(homes[index]): currents.drop_thermals(_key(homes[index]))
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
## `chunk_seed` and its mesh built, as the flip bakes its underside
## (scripts/diorama_flip.gd `_bake_underside`); its earth sides are fitted
## here on the main thread. Drawn with the plate's own ground and earth-side
## materials, only the plate's palette carries over, never what stands on it.
func _bake(island: Node3D, chunk_seed: int) -> void:
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
		Genesis.shape(plain,chunk_seed)
		baked.append(plain)
		baked.append(plain.build_mesh()))
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
## as it was.
func show_air(on: bool) -> void:
	currents.visible = on
	clouds.visible = on
	islets.visible = on
	peaks.visible = on

## The air at a global point (SkyCurrents `air_at`).
func air(point: Vector3) -> Dictionary:
	return currents.air_at(point)

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
	return peaks.ground(point)

## The island whose footprint holds a global point, as a solid: Vector2(its
## ground's height there, the slab's flat underside (NativeTerrainData
## .SLAB_BASE)), in global metres, or null over open air.
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
	return peaks.body(point)

func _body(point: Vector3, land: NativeTerrainData = null) -> Variant:
	var top: Variant = _height(point,land)
	if top == null: return null
	var local := editor.terrain.to_local(point)
	var under := editor.terrain.to_global(Vector3(local.x,NativeTerrainData.SLAB_BASE,local.z)).y
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
