extends Node3D
## The mountain ring's far skyline (scripts/sky_world.gd): every ring range
## and every inner range laid out with it stood whole, at once, as coarse
## faces (every STRIDE-th grid point of its heightfield, scripts/sky_peak.gd;
## the low foothills and the far row every STRIDE_LOW-th), so the ring
## stands round the world as
## a skyline from anywhere in it and never streams in or out. Near, a range
## is made in full by SkyPeaks (within its RING_BUILD), and its skyline
## steps aside for it (`advance`); let go again, the skyline comes back.
##
## The skyline is worked out on workers from the wanderer's first steps
## (`warm`, from SkyIslands `warm_ring`), before the first glide opens, and
## kept across glides; only a new seed or a new set of saved islands (a new
## layout) makes it again. No trees, no cloud wrapped round its foot and no
## solid: those come with the full range near. Drawn with the ranges' own
## ground material (SkyPeaks `_ground`), laid OFF_MAP off as theirs are.
##
## A child of SkyPeaks, so it stands at the cells' origin and the swaps that
## move the world carry it along.

const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
## The skyline's grid: every STRIDE-th point (SkyPeak STEP apart, so 16 m).
const STRIDE := 4
## The low foothills and the far row, coarser still (32 m).
const STRIDE_LOW := 8

## The ranges (SkyPeaks), whose palette, material and built ranges this reads.
var peaks: Node3D
## Each ring range's skyline, by its SkyPeaks key: {node (Node3D, or null
## until stood up), arrays (until stood up), cell}.
var lines := {}
## Skylines being made on workers, by key: {task, out, cell}.
var _making := {}
## The layout the skyline was made for (SkyWorld `layout`).
var _for := ""

func _init() -> void:
	name = "SkyRing"

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	_wait()

func _wait() -> void:
	for key in _making: WorkerThreadPool.wait_for_task_completion(_making[key].task)
	_making.clear()

## Every skyline gone.
func drop() -> void:
	_wait()
	for key in lines:
		if lines[key].node != null: (lines[key].node as Node3D).queue_free()
	lines.clear()
	_for = ""

func line_count() -> int:
	var n := 0
	for key in lines:
		if lines[key].node != null: n += 1
	return n

## Sets workers making every ring range's skyline not yet made, for the
## world's layout now; a skyline made for another layout goes first.
func warm(owner: Node3D) -> void:
	peaks = owner
	if not SkyWorld.ring_on():
		drop()
		return
	var cells: Array[Vector2i] = peaks.ring_cells()
	if SkyWorld._layout_key != _for: drop()
	_for = SkyWorld._layout_key
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	for cell in cells:
		var key: String = peaks._key(cell)
		if lines.has(key) or _making.has(key): continue
		var out := {}
		var task := WorkerThreadPool.add_task(_make.bind(peaks.seed_of(cell),peaks.stature_of(cell),peaks._palette("grass"),peaks._palette("rock"),peaks._gravel(),peaks._snow(),_off_map(),STRIDE_LOW if peaks.kind_of(cell) in ["foot","far"] else STRIDE,peaks.gorge_of(cell),out),false,"Sky ring skyline")
		_making[key] = {"task":task,"out":out,"cell":cell}

static func _make(seed_value: int, stature: float, grass: Array, rock: Array, gravel: Color, snow: Color, off_map: Vector3, stride: int, gorge: bool, out: Dictionary) -> void:
	var shape: RefCounted = SkyPeak.make(seed_value,stature,gorge)
	out.arrays = shape.body_arrays(grass,rock,gravel,off_map,stride,snow)

func _off_map() -> Vector3:
	return (peaks.get_script() as GDScript).get_script_constant_map().OFF_MAP

## A new glide's ranges (SkyPeaks `reset`): the skyline warmed if it is not
## already, and every finished one drawn with the ranges' material now.
func reset(owner: Node3D) -> void:
	warm(owner)
	for key in lines:
		var line: Dictionary = lines[key]
		if line.node != null: ((line.node as Node3D).get_child(0) as MeshInstance3D).mesh.surface_set_material(0,peaks._ground())

## Each frame of the glide (SkyPeaks `advance`): stands up one finished
## skyline, and hides each whose range stands in full.
func advance() -> void:
	for key in _making.keys():
		var m: Dictionary = _making[key]
		if not WorkerThreadPool.is_task_completed(m.task): continue
		WorkerThreadPool.wait_for_task_completion(m.task)
		_making.erase(key)
		lines[key] = {"node":null,"arrays":m.out.arrays,"cell":m.cell}
		break
	for key in lines:
		var line: Dictionary = lines[key]
		if line.node == null and peaks.cells != null:
			_stand(key)
			break
	_show()

## Waits for every skyline and stands them all up (tests, captures).
func flush() -> void:
	for key in _making.keys():
		var m: Dictionary = _making[key]
		WorkerThreadPool.wait_for_task_completion(m.task)
		lines[key] = {"node":null,"arrays":m.out.arrays,"cell":m.cell}
	_making.clear()
	if peaks == null or peaks.cells == null: return
	for key in lines:
		if lines[key].node == null: _stand(key)
	_show()

func _stand(key: String) -> void:
	var line: Dictionary = lines[key]
	var s: Variant = peaks.spot(line.cell)
	if s == null: return
	var node := Node3D.new()
	node.name = "Skyline_%d" % line.cell.y
	var scale: Vector3 = peaks.scale_of(line.cell)
	node.position = Vector3(s.x,s.y+peaks.lift(scale.y),s.z)
	node.rotation.y = s.w
	node.scale = scale
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = SkyPeak.mesh_from(line.arrays,peaks._ground())
	body.position = -_off_map()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(body)
	add_child(node)
	line.node = node
	line.erase("arrays")

## Each skyline shows unless its range stands in full.
func _show() -> void:
	for key in lines:
		var node: Node3D = lines[key].node
		if node != null: node.visible = not peaks.built.has(key)

## True if a ring range's skyline stands and shows.
func showing(key: String) -> bool:
	return lines.has(key) and lines[key].node != null and (lines[key].node as Node3D).visible
