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
## Copies are only translated, never turned. A turned copy would light
## differently from the plate under the same sun, and the swap would show.

const HALF := 14.0
## Where the copies stand from the plate, in metres: far apart (400 to
## 950 m, over a minute's slow glide, half a minute down a jet stream) and
## at different heights, so each is a destination.
const OFFSETS := [Vector3(380.0,-20.0,-160.0),Vector3(-260.0,25.0,-520.0),Vector3(-640.0,-35.0,120.0),Vector3(180.0,-50.0,700.0),Vector3(820.0,15.0,420.0)]
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyClouds = preload("res://scripts/sky_clouds.gd")
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
var _copies: Array[Node3D] = []
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
	var sources := _sources()
	for offset: Vector3 in OFFSETS:
		var island := Node3D.new()
		island.name = "Island%d" % _copies.size()
		island.position = offset
		add_child(island)
		for source: GeometryInstance3D in sources: island.add_child(_copy(source))
		_copies.append(island)
		offsets.append(offset)

func clear() -> void:
	for island in _copies: island.queue_free()
	_copies.clear()
	offsets.clear()

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
		for s in range(from.get_surface_override_material_count()):
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
	for offset in offsets:
		var h: Variant = _height(point-offset)
		if h != null: return float(h)+offset.y
	return null

## The plate's height under a global point, in global metres, or null off it.
func _height(point: Vector3) -> Variant:
	var local := editor.terrain.to_local(point)
	if absf(local.x) > HALF or absf(local.z) > HALF: return null
	var at := Vector2(snappedf(local.x,SNAP),snappedf(local.z,SNAP))
	var h: Variant = editor.data.ground_height(at)
	if h == null: return null
	return editor.terrain.to_global(Vector3(at.x,float(h),at.y)).y

## The copy whose footprint holds a global point, or -1.
func copy_under(point: Vector3) -> int:
	for i in range(offsets.size()):
		var local := editor.terrain.to_local(point-offsets[i])
		if absf(local.x) <= HALF and absf(local.z) <= HALF: return i
	return -1

## Makes copy `index` the plate: every copy moves by the shift, and the one
## arrived at takes the spot the plate is leaving. Returns the shift to add
## to anything that flies (the eye).
func arrive(index: int) -> Vector3:
	var shift := -offsets[index]
	for i in range(offsets.size()):
		offsets[i] = shift if i == index else offsets[i]+shift
		_copies[i].position = offsets[i]
	currents.position += shift
	clouds.move(shift)
	return shift
