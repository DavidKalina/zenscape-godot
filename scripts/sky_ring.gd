extends Node3D
## The mountain ring's far skyline (scripts/sky_world.gd): every ring range
## and every dividing ridge laid out with it stood whole, at once, as coarse
## faces (every STRIDE-th grid point of its heightfield, scripts/sky_peak.gd;
## the low ones every STRIDE_LOW-th), so the ring stands round the world as
## a skyline from anywhere in it and never streams in or out. Near, a range
## is made in full by SkyPeaks (within its `build_reach`), and its skyline
## steps aside for it (`advance`); let go again, the skyline comes back.
##
## The range in sight of the plate stands so too, finer (HOME_STRIDE): it
## is the one the plate looks at.
##
## The skyline is worked out on workers as the world starts (`warm`, from
## SkyIslands `_overview` once the layout is worked out: scripts/
## sky_world.gd `prepare`), so the ranges stand round the plate in the build
## view as well as the glide's, and kept across glides; only a new seed or a
## new set of saved islands (a new layout) makes it again. No trees, no cloud wrapped round its foot and no
## solid: those come with the full range near. Drawn with the ranges' own
## ground material (SkyPeaks `_ground`), laid OFF_MAP off as theirs are.
##
## A child of SkyPeaks, so it stands at the cells' origin and the swaps that
## move the world carry it along.

const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
## The skyline's grid: every STRIDE-th point (SkyPeak STEP apart, so 16 m).
const STRIDE := 4
## The low foothills, the far row and the ridges' low stretches and spurs,
## coarser still (32 m: SkyPeaks `coarse_of`).
const STRIDE_LOW := 8
## The range in sight of the plate, nearer than any (8 m).
const HOME_STRIDE := 2

## The ranges (SkyPeaks), whose palette, material and built ranges this reads.
var peaks: Node3D
## Each ring range's skyline, by its SkyPeaks key: {node (Node3D, or null
## until stood up), arrays (until stood up), cell}.
var lines := {}
## Skylines being made on workers, by key: {task, out, cell}.
var _making := {}
## The layout the skyline was made for (SkyWorld `layout`).
var _for := ""
## Asked to warm before the layout was worked out.
var _pending := false
## The skyline shows only once every range's stands (`whole`), so the
## mountains come into the world together rather than one by one, fading
## in over FADE seconds from when it was (`_whole_at`, msec).
const FADE := 2.5
var whole := false
var _whole_at := -1

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
	whole = false

func line_count() -> int:
	var n := 0
	for key in lines:
		if lines[key].node != null: n += 1
	return n

## Sets workers making every ring range's skyline not yet made, for the
## world's layout now; a skyline made for another layout goes first. With
## the layout still being worked out on its worker (SkyWorld `prepare`),
## nothing waits on it: the skyline is warmed once it is (`advance`).
func warm(owner: Node3D) -> void:
	peaks = owner
	if not SkyWorld.ring_on():
		drop()
		return
	if not SkyWorld.ready():
		SkyWorld.prepare()
		_pending = true
		return
	_pending = false
	var cells: Array[Vector2i] = peaks.ring_cells()
	if peaks.spot(Vector2i.ZERO) != null: cells.append(Vector2i.ZERO)
	if SkyWorld._layout_key != _for: drop()
	_for = SkyWorld._layout_key
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	for cell in cells:
		var key: String = peaks._key(cell)
		if lines.has(key) or _making.has(key): continue
		var out := {}
		var task := WorkerThreadPool.add_task(_make.bind(peaks.seed_of(cell),peaks.stature_of(cell),peaks._palette("grass"),peaks._palette("rock"),peaks._gravel(),peaks._snow(),_off_map(),stride_of(cell),peaks.gorge_of(cell),out,peaks.scale_of(cell).y),false,"Sky ring skyline")
		_making[key] = {"task":task,"out":out,"cell":cell}
		whole = false

## Every how many grid points a range's skyline is drawn.
func stride_of(cell: Vector2i) -> int:
	if cell == Vector2i.ZERO: return HOME_STRIDE
	return STRIDE_LOW if peaks.coarse_of(cell) else STRIDE

static func _make(seed_value: int, stature: float, grass: Array, rock: Array, gravel: Color, snow: Color, off_map: Vector3, stride: int, gorge: bool, out: Dictionary, height := 1.0) -> void:
	var shape: RefCounted = SkyPeak.make(seed_value,stature,gorge)
	shape.snowline = maxf(shape.snowline,SkyPeak.snow_floor(height))
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
	if _pending and SkyWorld.ready(): warm(peaks)
	for key in _making.keys():
		var m: Dictionary = _making[key]
		if not WorkerThreadPool.is_task_completed(m.task): continue
		WorkerThreadPool.wait_for_task_completion(m.task)
		_making.erase(key)
		lines[key] = {"node":null,"arrays":m.out.arrays,"cell":m.cell}
		break
	var standing := true
	for key in lines:
		var line: Dictionary = lines[key]
		if line.node == null:
			_stand(key)
			standing = false
			break
	if not whole and standing and _making.is_empty() and not _pending and not lines.is_empty():
		whole = true
		_whole_at = Time.get_ticks_msec()
	_show()

## Waits for every skyline and stands them all up (tests, captures).
func flush() -> void:
	if _pending:
		SkyWorld.layout()
		warm(peaks)
	for key in _making.keys():
		var m: Dictionary = _making[key]
		WorkerThreadPool.wait_for_task_completion(m.task)
		lines[key] = {"node":null,"arrays":m.out.arrays,"cell":m.cell}
	_making.clear()
	if peaks == null: return
	for key in lines:
		if lines[key].node == null: _stand(key)
	if not lines.is_empty():
		whole = true
		_whole_at = -1
	_show()

func _stand(key: String) -> void:
	var line: Dictionary = lines[key]
	var s: Variant = peaks.spot(line.cell)
	if s == null: return
	var node := Node3D.new()
	node.name = "Skyline_home" if line.cell == Vector2i.ZERO else "Skyline_%d" % line.cell.y
	var scale: Vector3 = peaks.scale_of(line.cell)
	node.position = Vector3(s.x,s.y+peaks.lift(scale.y),s.z)
	node.rotation.y = s.w
	node.scale = scale
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = SkyPeak.mesh_from(line.arrays,peaks._ground())
	body.position = -_off_map()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Kilometres off: never in the plate's water's mirror (scripts/
	# planar_water.gd).
	body.set_meta("skip_reflection",true)
	node.add_child(body)
	add_child(node)
	line.node = node
	line.erase("arrays")

## Each skyline shows, once the skyline is whole, unless its range stands
## in full; fading in at first.
func _show() -> void:
	var fade := 0.0
	if _whole_at >= 0:
		fade = 1.0-clampf((Time.get_ticks_msec()-_whole_at)/(FADE*1000.0),0.0,1.0)
		if fade <= 0.0: _whole_at = -1
	for key in lines:
		var node: Node3D = lines[key].node
		if node == null: continue
		node.visible = whole and not peaks.built.has(key)
		(node.get_child(0) as GeometryInstance3D).transparency = fade

## True if a ring range's skyline stands and shows.
func showing(key: String) -> bool:
	return lines.has(key) and lines[key].node != null and (lines[key].node as Node3D).visible
