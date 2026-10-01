extends Node3D
## Draws the live water (scripts/water_flow.gd, docs/scenic/water-flow.md)
## with copies of the ponds' and streams' own materials, so it keeps today's
## look.
##
## Every SURFACE_SECONDS the depth field becomes two meshes: all the water
## through the pond material (the lake shader: shore fetch in CUSTOM0/1 for its
## chop, depth in UV2, the depth palette in COLOR), and over it the moving
## water through the stream material (UV along and across the flow, so its
## streaks run downstream, with foam blended into COLOR where it is fast),
## fading out towards the slow water round it so the two meet without a seam.
## The ponds reflect through one planar view that follows the largest pond
## (`reflection`, scripts/live_water_reflection.gd). Where fast water crosses
## a big drop, a waterfall stands, traced from the flow and sized by its flux
## (`falls`, scripts/flow_falls.gd; --no-live-falls leaves them out). Where
## water leaves the plate over its rim, a fall pours down the block's side
## into the void (`edge_falls`, scripts/edge_falls.gd; --no-edge-falls leaves
## them out).
## Seconds between surface rebuilds (native).
const SURFACE_SECONDS := 1.0/30.0
## The GDScript mirror's coarser grid rebuilds less often (about 4 ms a build).
const FALLBACK_SURFACE_SECONDS := 0.1
## Surface parameters (ZenScapeWaterFlow::surface). Water shallower than
## `wet` is not drawn; the sheet sits `lift` above the water.
## With `under`, still water is drawn everywhere wet, moving water over it.
const SURFACE := {"wet":0.012,"lift":0.012,"flow_on":0.22,"flow_off":0.12,"foam_from":0.8,"foam_to":2.2,"depth_scale":0.45,"under":true}
## Moving water from THIN.x (the drawn `wet` depth) to THIN.y m deep fades
## from a wet darkening of the ground to the stream's full look (shader
## `live_thin`). A sheet a centimetre or two deep running down a steep face
## took the sky's sheen at the face's grazing angle, and its speed's foam,
## and read as a pale glassy shell.
const THIN := Vector2(0.012,0.05)
## How much faster than a planned pond's the live still water hides its bed
## with depth under the planar view (shader `bed_absorb`). The planned ponds'
## basins are a metre or more deep; a spring's pool is 0.4-1 m, and at 1 its
## floor showed through as the grass it was cut from.
const BED_ABSORB := 2.0
## Live still water's depth ramp (shader `tint_*`), and the moving water's
## vertex palette ends, so a stream over a pond takes the pond's colour.
const TINT := {"shallow":Color("6aad9e"),"mid":Color("3f9196"),"deep":Color("2f6478")}
const FORMAT :=(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

var flow: RefCounted
var data: NativeTerrainData
var still := MeshInstance3D.new()
var moving := MeshInstance3D.new()
var falls: Node3D
var edge_falls: Node3D
## The ponds' planar view, or null without a scene or under --no-live-reflection.
var reflection: Node3D
var scene_node: Node3D
## Indices of the still mesh's calm triangles (the rest lie under moving water).
var _calm := 0
var _since := 0.0
var _drawn := -1
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
	# Copies, so the planar view and the moving water's fade are live water's
	# own; they follow their sources' parameters (`reflection`, `_follow`).
	var still_material: ShaderMaterial = pond_material.duplicate()
	still_material.set_shader_parameter("hide_pool_surface",false)
	still_material.set_shader_parameter("planar_levels",Vector2(-1000000.0,-1000000.0))
	# The shore foam keeps to the bank (distance from dry ground in UV.x).
	still_material.set_shader_parameter("shore_distance",true)
	# Still water lies level; where the sheet under moving water tilts down a
	# face it fades, and the moving water's look shows alone.
	still_material.set_shader_parameter("live_level",true)
	# A live pond is shallower than a planned one: its water hides the bed
	# sooner under the planar view, so it reads as a pond, not grass.
	still_material.set_shader_parameter("bed_absorb",BED_ABSORB)
	# Its colour deepens with depth, from teal shallows to deep blue-teal, and
	# its bed fades out within a hand's depth (shader `depth_tint`).
	still_material.set_shader_parameter("depth_tint",true)
	still_material.set_shader_parameter("tint_shallow",TINT.shallow)
	still_material.set_shader_parameter("tint_mid",TINT.mid)
	still_material.set_shader_parameter("tint_deep",TINT.deep)
	still.material_override = still_material
	moving.name = "FlowMoving"
	var moving_material: ShaderMaterial = stream_material.duplicate()
	moving_material.set_shader_parameter("flow_edge_fade",true)
	# A film thinner than THIN reads as wet ground, not glassy water.
	moving_material.set_shader_parameter("live_thin",THIN)
	# Drawn after the still water it lies over, whatever the sort says.
	moving_material.render_priority = 1
	moving.material_override = moving_material
	for node: MeshInstance3D in [still,moving]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.mesh = ArrayMesh.new()
		# A pond's reflection does not show the water itself.
		node.set_meta("skip_reflection",true)
		add_child(node)
	var colors := {"shallow":TINT.shallow.srgb_to_linear(),"deep":TINT.deep.srgb_to_linear(),"foam":Color(0.65,0.8,0.79)}
	_params = SURFACE.merged(colors)
	scene_node = scene
	if scene != null and not "--no-live-falls" in OS.get_cmdline_user_args():
		falls = preload("res://scripts/flow_falls.gd").new()
		falls.name = "FlowFalls"
		scene.add_child(falls)
		falls.setup(flow,[still_material,moving_material])
	if scene != null and not "--no-edge-falls" in OS.get_cmdline_user_args():
		edge_falls = preload("res://scripts/edge_falls.gd").new()
		edge_falls.name = "EdgeFalls"
		scene.add_child(edge_falls)
		edge_falls.setup(flow,scene.get("_chunk_editor"))
	if scene != null and not "--no-live-reflection" in OS.get_cmdline_user_args():
		reflection = preload("res://scripts/live_water_reflection.gd").new()
		reflection.name = "LiveReflection"
		add_child(reflection)
		reflection.setup_live(still_material,pond_material,moving_material,stream_material,float(SURFACE.lift))

var _params := {}

func _exit_tree() -> void:
	if is_instance_valid(falls): falls.queue_free()
	if is_instance_valid(edge_falls): edge_falls.queue_free()

## The standing water the reflection follows (WaterFlow.pools), set by the
## editor as it reads them.
var pools: Array = []

## Rebuilds what changed since the last call.
func update(delta: float) -> void:
	if reflection != null: reflection.sync_live(scene_node,get_tree(),pools)
	_since += delta
	if _since >= (SURFACE_SECONDS if flow.native else FALLBACK_SURFACE_SECONDS) and flow.revision != _drawn:
		_since = 0.0
		_drawn = flow.revision
		publish()

## The still surface last published, as built (see `still_triangles`).
var _still_vertices := PackedVector3Array()
var _still_indices := PackedInt32Array()

## Builds both meshes from the depth field now.
func publish() -> void:
	var began := Time.get_ticks_usec()
	var arrays: Dictionary = flow.surface(_params)
	last_build_usec = Time.get_ticks_usec()-began
	began = Time.get_ticks_usec()
	_fill(still.mesh,arrays.still)
	_fill(moving.mesh,arrays.flow)
	# Kept for `still_triangles`: reading the mesh back would wait on the GPU.
	_still_vertices = arrays.still.vertices
	_still_indices = arrays.still.indices
	# A library without `under` draws still and moving apart, all calm.
	_calm = int(arrays.still.get("calm",(arrays.still.indices as PackedInt32Array).size()))
	var under: bool = arrays.still.has("calm")
	if moving.material_override.get_shader_parameter("flow_edge_fade") != under: moving.material_override.set_shader_parameter("flow_edge_fade",under)
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
	var vertices := _still_vertices
	var indices := _still_indices
	var lift: float = SURFACE.lift
	for k in range(mini(_calm,indices.size())): soup.append(vertices[indices[k]]-Vector3(0,lift,0))
	return soup

## The number of waterfalls standing.
func fall_count() -> int:
	return falls.shown_count() if falls != null else 0
