extends Node3D
## Draws the live water (scripts/water_flow.gd, docs/scenic/water-flow.md)
## with the ponds' and streams' own materials, so it keeps today's look.
##
## Every SURFACE_SECONDS the depth field becomes two meshes: still water
## through the pond material (the lake shader: shore fetch in CUSTOM0/1 for its
## chop, depth in UV2, the depth palette in COLOR) and moving water through the
## stream material (UV along and across the flow, so its streaks run
## downstream, with foam blended into COLOR where it is fast). Where moving
## water drops steeply, a waterfall stands (`FlowFalls`, the authored falls'
## ring shader, plunge and spray).
## Seconds between surface rebuilds (native), and between waterfall reads.
const SURFACE_SECONDS := 1.0/30.0
## The GDScript mirror's coarser grid rebuilds less often (about 4 ms a build).
const FALLBACK_SURFACE_SECONDS := 0.1
const FALL_SECONDS := 0.5
## Surface parameters (ZenScapeWaterFlow::surface). Water shallower than
## `wet` is not drawn; the sheet sits `lift` above the water.
const SURFACE := {"wet":0.012,"lift":0.012,"flow_on":0.22,"flow_off":0.12,"foam_from":0.8,"foam_to":2.2,"depth_scale":0.45}
## A waterfall: moving water of at least FALL_FLUX m³/s whose surface drops
## FALL_DROP m within FALL_REACH m, at FALL_SLOPE or steeper. It shows after
## FALL_HOLD s of being found and goes FALL_LINGER s after it is not.
const FALL_FLUX := 0.02
const FALL_DROP := 0.8
const FALL_SLOPE := 0.8
const FALL_REACH := 1.8
const FALL_HOLD := 1.0
const FALL_LINGER := 2.0
const FALL_MAX := 3
const FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

var flow: RefCounted
var data: NativeTerrainData
var still := MeshInstance3D.new()
var moving := MeshInstance3D.new()
var falls: Node3D
var _since := 0.0
var _since_falls := 0.0
var _drawn := -1
## Candidate and shown falls by key: {"item", "found", "lost", "shown"}.
var _falls := {}
var _serial := 0
## Microseconds of the last surface build and mesh publish, for probes.
var last_build_usec := 0
var last_publish_usec := 0
var worst_publish_usec := 0

## `materials`: the ponds' and streams' materials (GardenView). `scene` hosts
## the falls, as it hosts the authored ones.
func setup(water_flow: RefCounted, pond_material: Material, stream_material: Material, scene: Node) -> void:
	flow = water_flow
	data = flow.data
	still.name = "FlowStill"
	still.material_override = pond_material
	moving.name = "FlowMoving"
	moving.material_override = stream_material
	for node: MeshInstance3D in [still,moving]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.mesh = ArrayMesh.new()
		add_child(node)
	var colors := {"shallow":Color("79ae9b").srgb_to_linear(),"deep":Color("245a5c").srgb_to_linear(),"foam":Color(0.65,0.8,0.79)}
	_params = SURFACE.merged(colors)
	if scene != null:
		falls = FlowFalls.new()
		falls.name = "FlowFalls"
		scene.add_child(falls)

var _params := {}

func _exit_tree() -> void:
	if is_instance_valid(falls): falls.queue_free()

## Rebuilds what changed since the last call.
func update(delta: float) -> void:
	_since += delta
	_since_falls += delta
	if _since >= (SURFACE_SECONDS if flow.native else FALLBACK_SURFACE_SECONDS) and flow.revision != _drawn:
		_since = 0.0
		_drawn = flow.revision
		publish()
	if falls != null and _since_falls >= FALL_SECONDS:
		_read_falls(_since_falls)
		_since_falls = 0.0

## Builds both meshes from the depth field now.
func publish() -> void:
	var began := Time.get_ticks_usec()
	var arrays: Dictionary = flow.surface(_params)
	last_build_usec = Time.get_ticks_usec()-began
	began = Time.get_ticks_usec()
	_fill(still.mesh,arrays.still)
	_fill(moving.mesh,arrays.flow)
	last_publish_usec = Time.get_ticks_usec()-began
	worst_publish_usec = maxi(worst_publish_usec,last_publish_usec)

static func _fill(mesh: ArrayMesh, part: Dictionary) -> void:
	mesh.clear_surfaces()
	var indices: PackedInt32Array = part.indices
	if indices.is_empty(): return
	var vertices: PackedVector3Array = part.vertices
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = part.colors
	arrays[Mesh.ARRAY_TEX_UV] = part.uv
	arrays[Mesh.ARRAY_TEX_UV2] = part.uv2
	arrays[Mesh.ARRAY_CUSTOM0] = part.custom0
	arrays[Mesh.ARRAY_CUSTOM1] = part.custom1
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},FORMAT)

## Still water's triangles as a flat soup (three points each), for the life
## survey (scripts/life_survey.gd), which reads pond surfaces that way.
func still_triangles() -> PackedVector3Array:
	var soup := PackedVector3Array()
	if still.mesh.get_surface_count() == 0: return soup
	var arrays: Array = still.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var lift: float = SURFACE.lift
	for i in indices: soup.append(vertices[i]-Vector3(0,lift,0))
	return soup

## Waterfalls come and go with the flow: found for FALL_HOLD s to stand,
## missing for FALL_LINGER s to go. Keys are the drop's top, to half a metre.
func _read_falls(elapsed: float) -> void:
	var found: PackedFloat32Array = flow.falls(FALL_FLUX,FALL_DROP,FALL_SLOPE,FALL_REACH)
	var seen := {}
	for f in range(0,found.size(),7):
		var top := Vector2(found[f],found[f+2])
		var key := Vector2i((top/0.5).round())
		# A fall found again within a metre keeps its key.
		for known: Vector2i in _falls:
			if Vector2(known).distance_to(Vector2(key)) <= 2.0:
				key = known
				break
		if seen.has(key): continue
		seen[key] = true
		var entry: Dictionary = _falls.get(key,{})
		if entry.is_empty():
			_serial += 1
			entry = {"found":0.0,"lost":0.0,"shown":false,"id":1000000+_serial}
			_falls[key] = entry
		entry.found = float(entry.found)+elapsed
		entry.lost = 0.0
		if not entry.shown:
			entry.item = {"id":entry.id,"asset":"waterfall","x":top.x,"z":top.y,"end_x":found[f+3],"end_z":found[f+5],"angle":0.0,"scale":clampf(0.6+found[f+6]*4.0,0.6,1.6)}
	for key: Vector2i in _falls.keys():
		if seen.has(key): continue
		var entry: Dictionary = _falls[key]
		entry.lost = float(entry.lost)+elapsed
		entry.found = 0.0 if not entry.shown else entry.found
		if (entry.shown and entry.lost >= FALL_LINGER) or (not entry.shown and entry.lost > 0.0): _falls.erase(key)
	var shown := []
	for key: Vector2i in _falls:
		var entry: Dictionary = _falls[key]
		if not entry.shown and float(entry.found) >= FALL_HOLD and shown.size() < FALL_MAX: entry.shown = true
		if entry.shown: shown.append(entry.item)
	falls.show_falls(data,shown)

## The number of waterfalls standing.
func fall_count() -> int:
	return falls.shown_count() if falls != null else 0

## The authored falls' look (scripts/native_garden_falls.gd) for falls the
## flow finds, from records that live only here.
class FlowFalls extends NativeGardenFalls:
	func show_falls(terrain: NativeTerrainData, items: Array) -> void:
		var current := {}
		_sprays.clear()
		for item: Dictionary in items:
			var description := _describe(terrain,item)
			if description.is_empty(): continue
			var signature := var_to_bytes([description])
			var entry: Dictionary = _entries.get(item.id,{})
			if entry.is_empty() or entry.signature != signature:
				if not entry.is_empty():
					entry.mesh.free()
					entry.spray.free()
				entry = _create(item,description)
				entry.signature = signature
			current[item.id] = entry
			_sprays.append(entry.spray)
		for id in _entries:
			if not current.has(id):
				_entries[id].mesh.free()
				_entries[id].spray.free()
		_entries = current

	func shown_count() -> int:
		return _entries.size()
