extends RefCounted
## Sandbox replay uses the source conductor's response rate and terrain trauma.
## The original journal's word thresholds are replaced by explicit scene controls.
var terrain := 1.0
var foliage := 1.0
var water := 1.0
var _water_nodes: Array[MeshInstance3D] = []
var _water_details: Array[Node3D] = []
var _pond_cold := 0.0
var _pond_ice := 0.0
var replaying := false
var _stage := 0
var _water_only := false
var _debt := 0.0
var _rise_rate := 0.0
var _geometry: Node3D
var _details: Array[Node3D] = []
var _boulders: Array[Dictionary] = []
var _landmark: Node3D

func setup(geometry: Node3D) -> void:
	_geometry = geometry
	_landmark = geometry.get_node("landmark-arch")
	for node in geometry.get_children():
		if node.get_meta("source_kind", "static") == "birds" or node.get_meta("source_foam",false):
			continue
		if node.name in ["terrain", "landmark-arch", "skirt"]:
			continue
		if node.name in ["mesh-4", "mesh-5", "mesh-6", "mesh-7"]:
			_boulders.append({"node":node,"rest":node.transform,"height":node.get_aabb().size.y*node.basis.y.length()})
			continue
		var mesh: Mesh = node.multimesh.mesh if node is MultiMeshInstance3D else node.mesh if node is MeshInstance3D else null
		var material := mesh.surface_get_material(0) as ShaderMaterial if mesh != null else null
		if material != null and material.shader.resource_path.get_file() in ["reference_water.gdshader", "lake_reference_water.gdshader", "reference_fall.gdshader"]:
			_water_nodes.append(node)
			continue
		# Captured frog contact rings and the frogs themselves share a habitat.
		if node.name in ["mesh-39", "mesh-40"]:
			_water_details.append(node)
			continue
		if material == null or material.get_shader_parameter("plant_growth") != true:
			_details.append(node)
	publish()

func set_terrain(value: float) -> void:
	replaying = false
	terrain = clampf(value, 0.0, 1.0)
	_debt = 0.0
	_rise_rate = 0.0
	publish()

func set_foliage(value: float) -> void:
	replaying = false
	foliage = clampf(value, 0.0, 1.0)
	publish()

func set_water(value: float) -> void:
	replaying = false
	water = clampf(value, 0.0, 1.0)
	publish()

func set_pond_conditions(cold: float, ice: float) -> void:
	_pond_cold = cold
	_pond_ice = ice
	_publish_pond_life()

func _publish_pond_life() -> void:
	var habitable := terrain >= 0.995 and water > 0.92 and _pond_cold < 0.7 and _pond_ice < 0.6
	for node in _water_details:
		node.visible = habitable

func replay_water() -> void:
	water = 0.0
	_water_only = true
	_debt = 0.0
	_rise_rate = 0.0
	_stage = 0 if terrain < 0.995 else 1
	replaying = true
	publish()

func replay() -> void:
	_water_only = false
	terrain = 0.0
	foliage = 0.0
	water = 0.0
	_debt = 0.0
	_rise_rate = 0.0
	_stage = 0
	replaying = true
	publish()

func advance(delta: float, paused: bool, tremor: RefCounted) -> void:
	if paused or not replaying:
		return
	var before := terrain
	var response := 1.0 - exp(-delta * 1.4)
	if _stage == 0:
		terrain = lerpf(terrain, 1.0, response)
		if terrain > 0.995:
			terrain = 1.0
			_stage = 1
	elif _stage == 1:
		water = lerpf(water, 1.0, response)
		if water > 0.995:
			water = 1.0
			_stage = 2
			if _water_only:
				replaying = false
	else:
		foliage = lerpf(foliage, 1.0, response)
		if foliage > 0.9999:
			foliage = 1.0
			replaying = false
	var rise := terrain - before
	var velocity := rise / delta if delta > 0.0 else 0.0
	_rise_rate = lerpf(_rise_rate, smoothstep(0.002, 0.03, velocity), 1.0 - exp(-delta * 2.5))
	_debt += rise
	if rise > 0.0 and _debt >= 0.035:
		_debt -= 0.035
		var magnitude := minf(1.0, (0.3 + 0.5 * _rise_rate) * (0.55 + 0.65 * terrain))
		tremor.add(magnitude * 0.8)
	publish()

func publish() -> void:
	# Keep life and water on solid ground during a backwards terrain scrub.
	RenderingServer.global_shader_parameter_set("zs_growth", Vector2(terrain, foliage if terrain >= 0.995 else 0.0))
	var wet := water if terrain >= 0.995 else 0.0
	RenderingServer.global_shader_parameter_set("zs_water_growth", wet)
	if _geometry == null:
		return
	_landmark.visible = terrain > 0.001
	for i in range(_boulders.size()):
		var boulder := _boulders[i]
		var grown := smoothstep(0.72+i*0.045,0.9+i*0.025,terrain)
		var rest: Transform3D = boulder.rest
		boulder.node.visible = grown > 0.001
		boulder.node.transform = Transform3D(rest.basis.scaled(Vector3.ONE*maxf(grown,0.0001)),rest.origin-Vector3.UP*boulder.height*(1.0-grown))
	for node in _water_nodes:
		var material := node.mesh.surface_get_material(0) as ShaderMaterial
		if node.has_meta("water_bed"):
			var filled := smoothstep(0.2, 0.85, wet)
			node.position.y = lerpf(node.get_meta("water_bed"), node.get_meta("water_level"), filled)
			material.set_shader_parameter("level_drop", float(node.get_meta("water_level")) - node.position.y)
			node.visible = filled > 0.001
		else:
			node.visible = wet > (0.1 if material.shader.resource_path.ends_with("reference_water.gdshader") else 0.001)
	_publish_pond_life()
	for node in _details:
		node.visible = terrain >= 0.995
