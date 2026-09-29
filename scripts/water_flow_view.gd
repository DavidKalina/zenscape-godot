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
## (`falls`, scripts/flow_falls.gd; --no-live-falls leaves them out).
## Seconds between surface rebuilds (native).
const SURFACE_SECONDS := 1.0/30.0
## The GDScript mirror's coarser grid rebuilds less often (about 4 ms a build).
const FALLBACK_SURFACE_SECONDS := 0.1
## Surface parameters (ZenScapeWaterFlow::surface). Water shallower than
## `wet` is not drawn; the sheet sits `lift` above the water.
## With `under`, still water is drawn everywhere wet, moving water over it.
const SURFACE := {"wet":0.012,"lift":0.012,"flow_on":0.22,"flow_off":0.12,"foam_from":0.8,"foam_to":2.2,"depth_scale":0.45,"under":true}
const FORMAT := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

var flow: RefCounted
var data: NativeTerrainData
var still := MeshInstance3D.new()
var moving := MeshInstance3D.new()
var falls: Node3D
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
	still.material_override = still_material
	moving.name = "FlowMoving"
	var moving_material: ShaderMaterial = stream_material.duplicate()
	moving_material.set_shader_parameter("flow_edge_fade",true)
	# Drawn after the still water it lies over, whatever the sort says.
	moving_material.render_priority = 1
	moving.material_override = moving_material
	for node: MeshInstance3D in [still,moving]:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.mesh = ArrayMesh.new()
		# A pond's reflection does not show the water itself.
		node.set_meta("skip_reflection",true)
		add_child(node)
	var colors := {"shallow":Color("79ae9b").srgb_to_linear(),"deep":Color("245a5c").srgb_to_linear(),"foam":Color(0.65,0.8,0.79)}
	_params = SURFACE.merged(colors)
	scene_node = scene
	if scene != null and not "--no-live-falls" in OS.get_cmdline_user_args():
		falls = preload("res://scripts/flow_falls.gd").new()
		falls.name = "FlowFalls"
		scene.add_child(falls)
		falls.setup(flow,[still_material,moving_material])
	if scene != null and not "--no-live-reflection" in OS.get_cmdline_user_args():
		reflection = preload("res://scripts/live_water_reflection.gd").new()
		reflection.name = "LiveReflection"
		add_child(reflection)
		reflection.setup_live(still_material,pond_material,moving_material,stream_material,float(SURFACE.lift))

var _params := {}

func _exit_tree() -> void:
	if is_instance_valid(falls): falls.queue_free()

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

## Builds both meshes from the depth field now.
func publish() -> void:
	var began := Time.get_ticks_usec()
	var arrays: Dictionary = flow.surface(_params)
	last_build_usec = Time.get_ticks_usec()-began
	began = Time.get_ticks_usec()
	_fill(still.mesh,arrays.still)
	_fill(moving.mesh,arrays.flow)
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
	if still.mesh.get_surface_count() == 0: return soup
	var arrays: Array = still.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var lift: float = SURFACE.lift
	for k in range(mini(_calm,indices.size())): soup.append(vertices[indices[k]]-Vector3(0,lift,0))
	return soup

## The number of waterfalls standing.
func fall_count() -> int:
	return falls.shown_count() if falls != null else 0
