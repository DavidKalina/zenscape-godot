extends Node3D
## The glide prototype's other islands (scripts/sky_glide.gd): copies of the
## live plate set out in the sky, so there is somewhere to fly to.
##
## Only the plate itself is ever live. Each copy is a snapshot: new instances
## that share the plate's meshes, multimeshes and materials, so they cost
## draws but no simulation, and plants that grow on the plate grow on the
## copies too. Flying over a copy's footprint swaps the two (`arrive`). The
## whole world is shifted so the copy's spot becomes the plate's own, and
## every island, the one just left included, moves by the same amount. The
## copies are exact, so the swap can't be seen, and the ~300 places that
## assume the plate sits at the origin never notice.
##
## Wandering off from the copies, more turn up (scripts/sky_cells.gd): far
## from every island for a while, one rises out of the haze ahead; fallen
## into the parted cloud sea, one surfaces from it just ahead. Each brings a
## thermal. No more than CAP copies stand at once; beyond that the farthest
## are let go, never the nearest or the newest, and come back in the same
## spot when flown back to.
##
## Copies are only translated, never turned. A turned copy would light
## differently from the plate under the same sun, and the swap would show.

const HALF := 14.0
## Where the copies stand from the plate, in metres: far apart (400 to
## 950 m, over a minute's slow glide, half a minute down a jet stream) and
## at different heights, so each is a destination.
const OFFSETS := [Vector3(380.0,-20.0,-160.0),Vector3(-260.0,25.0,-520.0),Vector3(-640.0,-35.0,120.0),Vector3(180.0,-50.0,700.0),Vector3(820.0,15.0,420.0)]
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyClouds = preload("res://scripts/sky_clouds.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const IslandKeel = preload("res://scripts/island_keel.gd")
## The most copies standing at once. Each is ~140 draws.
const CAP := 9
## A copy that turns up rises this far (metres) over this long (seconds):
## gently out of the haze, or steeply up out of the cloud sea.
const WANDER_RISE := Vector2(60.0,10.0)
const FALL_RISE := Vector2(140.0,7.0)
## Its thermal stands this far off its middle, its base this far down, so
## it reaches the cushion under the band.
const THERMAL_SIDE := 24.0
const THERMAL_DOWN := 25.0
## Only parts this near the plate's middle, and smaller than this, are
## copied. That leaves out the sky, the fog and anything else world-sized.
const NEAR := 22.0
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
## The jet streams and thermals between the islands (scripts/sky_currents.gd).
var currents: Node3D
## The clouds between them (scripts/sky_clouds.gd).
var clouds: Node3D

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
	show_air(false)

## Copies the plate as it stands now to every offset, replacing any earlier
## copies.
func build() -> void:
	clear()
	currents.position = Vector3.ZERO
	clouds.reset()
	var slots := [Vector3.ZERO]
	slots.append_array(OFFSETS)
	cells = SkyCells.new(slots)
	var sources := _sources()
	for offset: Vector3 in OFFSETS: _add(offset,offset,Vector3.ZERO,sources)

func clear() -> void:
	for island in _copies: island.queue_free()
	_copies.clear()
	offsets.clear()
	homes.clear()
	_rise.clear()
	_newest = Vector3.INF
	if currents != null: currents.drop_added()

func _add(home: Vector3, at: Vector3, rise: Vector3, sources: Array) -> void:
	var island := Node3D.new()
	island.name = "Island%d" % get_child_count()
	island.position = at+Vector3.DOWN*rise.x
	add_child(island)
	for source: GeometryInstance3D in sources: island.add_child(_copy(source))
	_copies.append(island)
	offsets.append(at)
	homes.append(home)
	_rise.append(rise)

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
	clouds.follow(eye)

## Puts a copy at a home spot, rising from below, with a thermal beside it
## unless it is one of the fixed slots (those have theirs).
func realise(home: Vector3, kind: String) -> void:
	var at := home+cells.origin
	_add(home,at,_rise_for(kind),_sources())
	_newest = home
	if _fixed(home): return
	var a := fposmod(home.x*0.37+home.z*0.71,TAU)
	currents.add_thermal(at+Vector3(cos(a),0.0,sin(a))*THERMAL_SIDE+Vector3.DOWN*THERMAL_DOWN,_key(home))

func _rise_for(kind: String) -> Vector3:
	var r := FALL_RISE if kind == "fall" else WANDER_RISE
	return Vector3(r.x,0.0,r.y)

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

## The plate's drawn parts worth copying.
func _sources() -> Array:
	var found := []
	var stack: Array[Node] = [scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == self or node in skip or node is Camera3D: continue
		if node is Node3D and not (node as Node3D).visible: continue
		for child in node.get_children(): stack.append(child)
		if not (node is MeshInstance3D or node is MultiMeshInstance3D): continue
		var part := node as GeometryInstance3D
		if node is MeshInstance3D and (node as MeshInstance3D).mesh == null: continue
		if node is MultiMeshInstance3D and ((node as MultiMeshInstance3D).multimesh == null or (node as MultiMeshInstance3D).multimesh.visible_instance_count == 0): continue
		var box := part.global_transform*part.get_aabb()
		var middle := box.get_center()
		if absf(middle.x) > NEAR or absf(middle.z) > NEAR: continue
		if box.size.x > LARGEST or box.size.z > LARGEST: continue
		found.append(part)
	return found

## A new instance of `source` that shares its mesh and materials.
func _copy(source: GeometryInstance3D) -> GeometryInstance3D:
	var copy: GeometryInstance3D
	if source is MultiMeshInstance3D:
		copy = MultiMeshInstance3D.new()
		(copy as MultiMeshInstance3D).multimesh = (source as MultiMeshInstance3D).multimesh
	else:
		var mesh := MeshInstance3D.new()
		var from := source as MeshInstance3D
		mesh.mesh = from.mesh
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
		var h: Variant = _height(point-offset)
		if h != null: return float(h)+offset.y
	return null

## The island whose footprint holds a global point, as a solid: Vector2(its
## ground's height there, the underside of the rock it hangs from
## (scripts/island_keel.gd)), in global metres, or null over open air.
func body(point: Vector3) -> Variant:
	var plate: Variant = _body(point)
	if plate != null: return plate
	for i in range(offsets.size()):
		var offset := offsets[i]+Vector3.DOWN*sunk(i)
		var b: Variant = _body(point-offset)
		if b != null: return (b as Vector2)+Vector2(offset.y,offset.y)
	return null

func _body(point: Vector3) -> Variant:
	var top: Variant = _height(point)
	if top == null: return null
	var local := editor.terrain.to_local(point)
	var under := editor.terrain.to_global(Vector3(local.x,IslandKeel.underside(Vector2(local.x,local.z)),local.z)).y
	return Vector2(float(top),under)

## The plate's height under a global point, in global metres, or null off it.
func _height(point: Vector3) -> Variant:
	var local := editor.terrain.to_local(point)
	if absf(local.x) > HALF or absf(local.z) > HALF: return null
	var at := Vector2(snappedf(local.x,SNAP),snappedf(local.z,SNAP))
	var h: Variant = editor.data.ground_height(at)
	if h == null: return null
	return editor.terrain.to_global(Vector3(at.x,float(h),at.y)).y

## The copy whose footprint holds a global point, or -1. A copy still
## rising can't be arrived at yet.
func copy_under(point: Vector3) -> int:
	for i in range(offsets.size()):
		if _rise[i] != Vector3.ZERO: continue
		var local := editor.terrain.to_local(point-offsets[i])
		if absf(local.x) <= HALF and absf(local.z) <= HALF: return i
	return -1

## Makes copy `index` the plate: every copy moves by the shift, and the one
## arrived at takes the spot the plate is leaving. Returns the shift to add
## to anything that flies (the eye). The copy then stands for the island
## left, so it takes that one's home, and the cells' origin moves too.
func arrive(index: int) -> Vector3:
	var shift := -offsets[index]
	homes[index] = -cells.origin
	for i in range(offsets.size()):
		offsets[i] = shift if i == index else offsets[i]+shift
		_copies[i].position = offsets[i]+Vector3.DOWN*sunk(i)
	cells.origin += shift
	currents.position += shift
	clouds.move(shift)
	return shift
