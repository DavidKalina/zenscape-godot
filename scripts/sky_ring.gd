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
##
## The sea's summits (SkyWorld `_summits`) stand with it: each a range of
## its own made on a worker as the skyline is, sunk so only its top
## (`show` m) stands over the sea, its faces only where they stand over it
## (SUMMIT_STRIDE apart), snow down SUMMIT_SNOW of the way to the sea; and
## its rock over the sea kept as a small heightfield (`summit_body`), so
## the glide meets it as giant stone (SkyPeaks `body`). Never made in full:
## they stand under the glide's ceiling, so nothing about them needs more.
##
## Each skyline is kept on disk (scripts/sky_cache.gd), keyed by all it is
## made from (`inputs`), so a world started again stands at once; its mesh
## is made on the worker too, so standing it up is only adding a node. A
## new layout keeps every skyline whose inputs it still has.
##
## The swap with the full range is a cross-fade, never a cut (`_show`): the
## full range comes in solid under its skyline, which fades out over SWAP
## seconds; let go, the skyline fades back in over it before it goes
## (SkyPeaks `leaving`).

const SkyPeak = preload("res://scripts/sky_peak.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyCache = preload("res://scripts/sky_cache.gd")
## Seconds a skyline takes to fade out over its full range made near, or
## back in over it as it is let go.
const SWAP := 1.6
## The skyline's grid: every STRIDE-th point (SkyPeak STEP apart, so 16 m).
const STRIDE := 4
## The low foothills, the far row and the ridges' low stretches and spurs,
## coarser still (32 m: SkyPeaks `coarse_of`).
const STRIDE_LOW := 8
## The range in sight of the plate, nearer than any (8 m).
const HOME_STRIDE := 2
## The sea's summits' faces (4 m: they stand small), how far down from their tops toward the
## sea their snow lies (a share), and how far (m) under the sea their faces
## and solid still reach, for the sea's line wandering up and down
## (SkyPeaks SEA_FRAY).
const SUMMIT_STRIDE := 1
const SUMMIT_SNOW := 0.4
const SUMMIT_UNDER := 24.0

## The ranges (SkyPeaks), whose palette, material and built ranges this reads.
var peaks: Node3D
## Each ring range's skyline, by its SkyPeaks key: {node (Node3D, or null
## until stood up), mesh (until stood up), cell, key (its cache key)}.
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
## The sea's summits, by their index in the layout: {node (or null until
## stood up), arrays (until then), sink (its frame's height), solid ({i0,
## j0, w, h: the shape's grid's box over the sea; heights; sea: its own
## height at the sea}), over (how many of its summits stand over the sea),
## top}; and those being made on workers: {task, out}.
var summits := {}
var _summit_making := {}

func _init() -> void:
	name = "SkyRing"

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	_wait()

func _wait() -> void:
	for key in _making: WorkerThreadPool.wait_for_task_completion(_making[key].task)
	_making.clear()
	for key in _summit_making: WorkerThreadPool.wait_for_task_completion(_summit_making[key].task)
	_summit_making.clear()

## Every skyline gone.
func drop() -> void:
	_wait()
	for key in lines:
		if lines[key].node != null: (lines[key].node as Node3D).queue_free()
	lines.clear()
	for key in summits:
		if summits[key].node != null: (summits[key].node as Node3D).queue_free()
	summits.clear()
	_for = ""
	whole = false

## Every skyline set aside for a new layout, by its cache key, its mesh kept
## for a range the new layout still has.
func _set_aside() -> Dictionary:
	_wait()
	var aside := {}
	for key in lines:
		var line: Dictionary = lines[key]
		if line.node != null:
			aside[line.key] = ((line.node as Node3D).get_child(0) as MeshInstance3D).mesh
			(line.node as Node3D).queue_free()
		elif line.has("mesh"): aside[line.key] = line.mesh
	lines.clear()
	# The sea's summits are laid by the layout's index: made again (read
	# back from disk) for the new one.
	for i in summits:
		if summits[i].node != null: (summits[i].node as Node3D).queue_free()
	summits.clear()
	_for = ""
	whole = false
	return aside

## Every skyline's progress, 0 to 1: made (on workers, or read back) and
## stood up (the loading screen's glow).
func progress() -> float:
	var total := lines.size()+_making.size()+summits.size()+_summit_making.size()
	if total == 0: return 1.0 if whole else 0.0
	return float(line_count()+summit_count())/float(total)

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
	var aside := {}
	if SkyWorld._layout_key != _for: aside = _set_aside()
	_for = SkyWorld._layout_key
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	for cell in cells:
		var key: String = peaks._key(cell)
		if lines.has(key) or _making.has(key): continue
		var made := inputs(cell)
		var cache_key := SkyCache.key("skyline",made)
		whole = false
		if aside.has(cache_key):
			lines[key] = {"node":null,"mesh":aside[cache_key],"cell":cell,"key":cache_key}
			continue
		var out := {}
		var task := WorkerThreadPool.add_task(_make.bind(made,cache_key,out),false,"Sky ring skyline")
		_making[key] = {"task":task,"out":out,"cell":cell,"key":cache_key}

	var laid: Array = SkyWorld.layout().get("summits",[])
	for i in range(laid.size()):
		if summits.has(i) or _summit_making.has(i): continue
		var summit: Dictionary = laid[i]
		var made := summit_inputs(summit)
		var out := {}
		var task := WorkerThreadPool.add_task(_make_summit_cached.bind(made,SkyCache.key("summit",made),out),false,"Sea summit")
		_summit_making[i] = {"task":task,"out":out}
		whole = false

## All a range's skyline is made from (SkyCache `key`): its range's seed,
## stature, gorge, height (the snow line's floor), its grid's stride, the
## world's palette baked into its colours and where it is laid off the map.
func inputs(cell: Vector2i) -> Array:
	return [peaks.seed_of(cell),peaks.stature_of(cell),peaks.gorge_of(cell),peaks.scale_of(cell).y,stride_of(cell),peaks._palette("grass"),peaks._palette("rock"),peaks._gravel(),peaks._snow(),_off_map()]

## All a sea's summit is made from (SkyCache `key`, kind "summit"): its
## seed, how much of it shows, the palette and where it is laid.
func summit_inputs(summit: Dictionary) -> Array:
	return [int(summit.seed),float(summit.show),peaks._palette("grass"),peaks._palette("rock"),peaks._gravel(),peaks._snow(),_off_map()]

## Every how many grid points a range's skyline is drawn.
func stride_of(cell: Vector2i) -> int:
	if cell == Vector2i.ZERO: return HOME_STRIDE
	return STRIDE_LOW if peaks.coarse_of(cell) else STRIDE

## On a worker: the skyline read back from disk, or made and kept; then
## its mesh (no material yet: `_stand` gives it the ranges').
static func _make(made: Array, cache_key: String, out: Dictionary) -> void:
	var arrays := SkyCache.arrays(cache_key,_shape.bind(made))
	out.mesh = SkyPeak.mesh_from(arrays,null)

static func _shape(made: Array) -> Array:
	var shape: RefCounted = SkyPeak.make(int(made[0]),float(made[1]),bool(made[2]))
	shape.snowline = maxf(shape.snowline,SkyPeak.snow_floor(float(made[3])))
	return shape.body_arrays(made[5],made[6],made[7],made[9],int(made[4]),made[8])

## A sea's summit (SkyWorld `_summits`): its range made (its gorge uncut),
## sunk `show` m under its top; its faces over the sea, its snow, how far
## it is sunk (`sink`: its frame's height) and its rock over the sea as a
## small heightfield (`solid`).
static func _make_summit(seed_value: int, show: float, grass: Array, rock: Array, gravel: Color, snow: Color, off_map: Vector3, out: Dictionary) -> void:
	var shape: RefCounted = SkyPeak.make(seed_value,1.0,false)
	var sea: float = shape.top-show
	shape.snowline = shape.top-show*SUMMIT_SNOW
	out.arrays = shape.body_arrays(grass,rock,gravel,off_map,SUMMIT_STRIDE,snow,sea-SUMMIT_UNDER)
	# Seasons: its cap thins in summer and spreads in winter, by its own height.
	SkyPeak.season_share(out.arrays,show*SkyPeak.SUMMIT_SEASON)
	out.sink = SkyPeak.SEA-sea
	# The grid's box over the sea, and its heights.
	var nx: int = shape.nx
	var all: PackedFloat32Array = shape.heights
	var lo := Vector2i(nx,shape.nz)
	var hi := Vector2i(-1,-1)
	for j in range(shape.nz):
		for i in range(nx):
			if all[j*nx+i] < sea-SUMMIT_UNDER: continue
			lo = Vector2i(mini(lo.x,i),mini(lo.y,j))
			hi = Vector2i(maxi(hi.x,i),maxi(hi.y,j))
	var heights := PackedFloat32Array()
	if hi.x >= lo.x:
		lo = Vector2i(maxi(lo.x-1,0),maxi(lo.y-1,0))
		hi = Vector2i(mini(hi.x+1,nx-1),mini(hi.y+1,shape.nz-1))
		for j in range(lo.y,hi.y+1): heights.append_array(all.slice(j*nx+lo.x,j*nx+hi.x+1))
	out.solid = {"i0":lo.x,"j0":lo.y,"w":hi.x-lo.x+1,"h":hi.y-lo.y+1,"heights":heights,"sea":sea}
	var over := 0
	for q: Vector3 in shape.summits:
		if q.y > sea: over += 1
	out.over = over
	out.top = shape.top

## On a worker: a sea's summit read back from disk (its faces through the
## cache's codec, its solid as it was), or made and kept; then its mesh.
static func _make_summit_cached(made: Array, cache_key: String, out: Dictionary) -> void:
	var kept: Variant = SkyCache.load_value(cache_key)
	var arrays: Variant = SkyCache.decode(kept.faces) if kept is Dictionary and kept.get("faces") is Dictionary else null
	if arrays is Array and kept.get("solid") is Dictionary:
		for part in ["sink","solid","over","top"]: out[part] = kept[part]
	else:
		_make_summit(int(made[0]),float(made[1]),made[2],made[3],made[4],made[5],made[6],out)
		arrays = out.arrays
		SkyCache.save_value(cache_key,{"faces":SkyCache.encode(arrays),"sink":out.sink,"solid":out.solid,"over":out.over,"top":out.top})
	out.erase("arrays")
	out.mesh = SkyPeak.mesh_from(arrays,null)

func _off_map() -> Vector3:
	return (peaks.get_script() as GDScript).get_script_constant_map().OFF_MAP

## A new glide's ranges (SkyPeaks `reset`): the skyline warmed if it is not
## already, and every finished one drawn with the ranges' material now.
func reset(owner: Node3D) -> void:
	warm(owner)
	for key in lines:
		var line: Dictionary = lines[key]
		if line.node != null: ((line.node as Node3D).get_child(0) as MeshInstance3D).mesh.surface_set_material(0,peaks._ground())
	for key in summits:
		if summits[key].node != null: ((summits[key].node as Node3D).get_child(0) as MeshInstance3D).mesh.surface_set_material(0,peaks._ground())

## Each frame of the glide (SkyPeaks `advance`): stands up one finished
## skyline, and hides each whose range stands in full.
func advance() -> void:
	if _pending and SkyWorld.ready(): warm(peaks)
	for key in _making.keys():
		var m: Dictionary = _making[key]
		if not WorkerThreadPool.is_task_completed(m.task): continue
		WorkerThreadPool.wait_for_task_completion(m.task)
		_making.erase(key)
		lines[key] = {"node":null,"mesh":m.out.mesh,"cell":m.cell,"key":m.key}
		break
	for i in _summit_making.keys():
		var m: Dictionary = _summit_making[i]
		if not WorkerThreadPool.is_task_completed(m.task): continue
		WorkerThreadPool.wait_for_task_completion(m.task)
		_summit_making.erase(i)
		summits[i] = m.out
		summits[i].node = null
		break
	var standing := true
	for key in lines:
		var line: Dictionary = lines[key]
		if line.node == null:
			_stand(key)
			standing = false
			break
	if standing:
		for i in summits:
			if summits[i].node == null:
				_stand_summit(i)
				standing = false
				break
	if not whole and standing and _making.is_empty() and _summit_making.is_empty() and not _pending and not lines.is_empty():
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
		lines[key] = {"node":null,"mesh":m.out.mesh,"cell":m.cell,"key":m.key}
	_making.clear()
	for i in _summit_making.keys():
		WorkerThreadPool.wait_for_task_completion(_summit_making[i].task)
		summits[i] = _summit_making[i].out
		summits[i].node = null
	_summit_making.clear()
	if peaks == null: return
	for key in lines:
		if lines[key].node == null: _stand(key)
	for i in summits:
		if summits[i].node == null: _stand_summit(i)
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
	var mesh: ArrayMesh = line.mesh
	mesh.surface_set_material(0,peaks._ground())
	body.mesh = mesh
	body.position = -_off_map()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Kilometres off: never in the plate's water's mirror (scripts/
	# planar_water.gd).
	body.set_meta("skip_reflection",true)
	node.add_child(body)
	add_child(node)
	line.node = node
	line.erase("mesh")

## A sea's summit stood up: sunk in its spot, turned, its faces in the
## ranges' material; no shadow, and out of the plate's water's mirror.
func _stand_summit(i: int) -> void:
	var laid: Array = SkyWorld.layout().get("summits",[])
	if i >= laid.size(): return
	var summit: Dictionary = summits[i]
	var node := Node3D.new()
	node.name = "Summit_%d" % i
	node.position = Vector3(laid[i].at.x,float(summit.sink),laid[i].at.z)
	node.rotation.y = float(laid[i].turn)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var mesh: ArrayMesh = summit.mesh
	mesh.surface_set_material(0,peaks._ground())
	body.mesh = mesh
	body.position = -_off_map()
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Kilometres off: never in the plate's water's mirror.
	body.set_meta("skip_reflection",true)
	node.add_child(body)
	add_child(node)
	summit.node = node
	summit.erase("mesh")

## The sea's summit under a global point as a solid, Vector2(its rock's
## height, its underside far under the cloud) in global metres, or null:
## off its rock, or where its rock is under the sea.
func summit_body(point: Vector3) -> Variant:
	if peaks == null: return null
	for i in summits:
		var summit: Dictionary = summits[i]
		var node: Node3D = summit.node
		if node == null: continue
		var local := node.transform.affine_inverse()*(point-peaks.position)
		var solid: Dictionary = summit.solid
		var fx := (local.x+SkyPeak.HALF.x)/SkyPeak.STEP-int(solid.i0)
		var fz := (local.z+SkyPeak.HALF.y)/SkyPeak.STEP-int(solid.j0)
		if fx < 0.0 or fz < 0.0 or fx >= int(solid.w)-1 or fz >= int(solid.h)-1: continue
		var ix := int(fx)
		var iz := int(fz)
		var w := int(solid.w)
		var heights: PackedFloat32Array = solid.heights
		var u := fx-ix
		var v := fz-iz
		var h := lerpf(lerpf(heights[iz*w+ix],heights[iz*w+ix+1],u),lerpf(heights[(iz+1)*w+ix],heights[(iz+1)*w+ix+1],u),v)
		if h < float(solid.sea): continue
		var y := peaks.position.y+node.position.y
		return Vector2(h+y,SkyPeak.BOTTOM+y)
	return null

## How many of the sea's summits stand.
func summit_count() -> int:
	var n := 0
	for i in summits:
		if summits[i].node != null: n += 1
	return n

## Each skyline shows, once the skyline is whole, fading in at first; and
## where its range stands in full, fading out over it as it comes, back in
## over it as it goes (SkyPeaks `swap_of`).
func _show() -> void:
	var fade := 0.0
	if _whole_at >= 0:
		fade = 1.0-clampf((Time.get_ticks_msec()-_whole_at)/(FADE*1000.0),0.0,1.0)
		if fade <= 0.0: _whole_at = -1
	for key in lines:
		var node: Node3D = lines[key].node
		if node == null: continue
		var swap: float = peaks.swap_of(key)
		node.visible = whole and swap < 1.0
		(node.get_child(0) as GeometryInstance3D).transparency = maxf(fade,swap)
	for i in summits:
		var node: Node3D = summits[i].node
		if node == null: continue
		node.visible = whole
		(node.get_child(0) as GeometryInstance3D).transparency = fade

## The skyline stands whole at once, without its own fade (the loading
## screen fades the world in instead).
func settle_fade() -> void:
	_whole_at = -1
	if peaks != null: _show()

## True if a ring range's skyline stands and shows.
func showing(key: String) -> bool:
	return lines.has(key) and lines[key].node != null and (lines[key].node as Node3D).visible
