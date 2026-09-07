extends SceneTree
## Turn source geometry into a native Godot scene. Source winding is reversed;
## all positions, triangle colors, and instance transforms are retained.

func _initialize() -> void:
	_import.call_deferred()

func _import() -> void:
	if RenderingServer.get_rendering_device() == null:
		push_error("Import requires native rendering: the headless dummy renderer cannot save MultiMesh instance buffers.")
		quit(1)
		return
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	var root_node := Node3D.new()
	root_node.name = "ZenScapeReference"
	# Runtime needs the camera and light recipe, not the 5 MB geometry export.
	var settings := source.duplicate()
	settings.erase("meshes")
	root_node.set_meta("source_settings", settings)
	var hemi: Dictionary = {}
	for light: Dictionary in source.lights:
		if light.type == "HemisphereLight":
			hemi = light
	var growth: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/growth.json"))
	var water_growth: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/water-growth.json"))
	var lake_wind: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/lake-wind.json"))
	var triangles := 0
	var instances := 0
	for entry: Dictionary in source.meshes:
		if lake_wind.has(entry.name):
			for key in ["aFetchA", "aFetchB"]:
				entry.attrs[key] = lake_wind[entry.name][key]
			entry["lake_wind"] = lake_wind[entry.name]
		if growth.has(entry.name):
			entry.attrs.merge(growth[entry.name], true)
		for stream: Dictionary in water_growth.streams:
			if stream.name == entry.name:
				for key in ["aT", "aCenter", "aS", "aU", "aRun"]:
					entry.attrs[key] = stream[key]
		if entry.name == "strand":
			entry["fall_data"] = water_growth.strands[0]
		var mesh := make_mesh(entry)
		triangles += mesh.surface_get_array_len(0) / 3
		var material := make_material(entry, hemi, source.sky)
		mesh.surface_set_material(0, material)
		var node: GeometryInstance3D
		if entry.count > 0:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			multimesh.instance_count = int(entry.count)
			multimesh.mesh = mesh
			for i in range(int(entry.count)):
				multimesh.set_instance_transform(i, matrix_transform(entry.instances, i * 16))
				if entry.instanceColors != null:
					multimesh.set_instance_color(i, color_at(entry.instanceColors, i * 3))
				else:
					multimesh.set_instance_color(i, Color.WHITE)
			var multi_node := MultiMeshInstance3D.new()
			multi_node.multimesh = multimesh
			node = multi_node
			instances += int(entry.count)
		else:
			var mesh_node := MeshInstance3D.new()
			mesh_node.mesh = mesh
			node = mesh_node
		for lake: Dictionary in water_growth.lakes:
			if lake.name == entry.name:
				node.set_meta("water_bed", lake.bed)
				node.set_meta("water_level", lake.level)
		node.name = String(entry.name).validate_node_name()
		node.transform = matrix_transform(entry.matrix)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if entry.castShadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.extra_cull_margin = 0.8
		node.set_meta("source_mesh", entry.name)
		node.set_meta("source_kind", entry.get("role", "static"))
		root_node.add_child(node, true)
		node.owner = root_node
	# MultiMesh buffers live in the renderer: import with a real graphics driver.
	# Give pending buffer uploads a frame before serializing their resources.
	await process_frame
	await process_frame
	var packed := PackedScene.new()
	packed.pack(root_node)
	var result := ResourceSaver.save(packed, "res://assets/zen_reference/geometry.scn", ResourceSaver.FLAG_COMPRESS)
	print("Imported %d mesh groups, %d instances, %d base triangles; save=%s" % [source.meshes.size(), instances, triangles, result])
	root_node.free()
	quit(result)

func make_mesh(entry: Dictionary) -> ArrayMesh:
	var attrs: Dictionary = entry.attrs
	var positions: Array = attrs.position.array
	var count: int = entry.index.size() if entry.index != null else positions.size() / 3
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var water_data := PackedVector2Array()
	vertices.resize(count)
	normals.resize(count)
	colors.resize(count)
	uvs.resize(count)
	water_data.resize(count)
	var fetch_a := PackedFloat32Array()
	var fetch_b := PackedFloat32Array()
	if attrs.has("aFetchA"):
		fetch_a.resize(count * 4)
		fetch_b.resize(count * 4)
	var meadow := PackedFloat32Array()
	if attrs.has("aDelay"):
		meadow.resize(count * 3)
	if attrs.has("aCenter"):
		meadow.resize(count * 4)
	var stream_uvs := _stream_coordinates(entry)
	for i in range(0, count, 3):
		var ids: Array[int] = [i, i + 2, i + 1]
		for j in range(3):
			var index: int = int(entry.index[ids[j]]) if entry.index != null else ids[j]
			vertices[i + j] = vector_at(positions, index * 3)
			colors[i + j] = color_at(attrs.color.array, index * int(attrs.color.size)) if entry.material.vertexColors and attrs.has("color") else Color.WHITE
			if attrs.has("uv"):
				uvs[i + j] = Vector2(attrs.uv.array[index * 2], attrs.uv.array[index * 2 + 1])
			elif not stream_uvs.is_empty():
				uvs[i + j] = stream_uvs[index]
			if attrs.has("aFetchA"):
				for axis in range(4):
					fetch_a[(i + j) * 4 + axis] = attrs.aFetchA.array[index * 4 + axis]
					fetch_b[(i + j) * 4 + axis] = attrs.aFetchB.array[index * 4 + axis]
			if attrs.has("aDepth"):
				water_data[i + j] = Vector2(attrs.aDepth.array[index], attrs.aCut.array[index] if attrs.has("aCut") else 0.0)
			if attrs.has("aDelay"):
				uvs[i + j] = Vector2(attrs.aDelay.array[index], attrs.aHold.array[index])
				water_data[i + j] = Vector2(attrs.aDirt.array[index], attrs.aTo.array[index])
				for axis in range(3):
					meadow[(i + j) * 3 + axis] = attrs.aBaseColor.array[index * 3 + axis]
			if attrs.has("aCenter"):
				for axis in range(3):
					meadow[(i + j) * 4 + axis] = attrs.aCenter.array[index * 3 + axis]
				meadow[(i + j) * 4 + 3] = attrs.aT.array[index]
			if entry.has("fall_data"):
				uvs[i + j] = Vector2(entry.fall_data.vertRing[index], entry.fall_data.vertAng[index])
				water_data[i + j] = Vector2(index / 72, (index % 72) / 6)
			if attrs.has("normal"):
				normals[i + j] = vector_at(attrs.normal.array, index * 3)
		if entry.material.get("flat", false) or not attrs.has("normal"):
			var normal := (vertices[i + 2] - vertices[i]).cross(vertices[i + 1] - vertices[i]).normalized()
			for j in range(3):
				normals[i + j] = normal
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = water_data
	var mesh := ArrayMesh.new()
	var flags := 0
	if not meadow.is_empty():
		arrays[Mesh.ARRAY_CUSTOM0] = meadow
		flags = (Mesh.ARRAY_CUSTOM_RGBA_FLOAT if attrs.has("aCenter") else Mesh.ARRAY_CUSTOM_RGB_FLOAT) << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	if not fetch_a.is_empty():
		arrays[Mesh.ARRAY_CUSTOM0] = fetch_a
		arrays[Mesh.ARRAY_CUSTOM1] = fetch_b
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	return mesh

func make_material(entry: Dictionary, hemi: Dictionary, sky: Dictionary) -> ShaderMaterial:
	var recipe: Dictionary = entry.material
	var material := ShaderMaterial.new()
	var is_stream: bool = entry.attrs.has("aDepth") and not recipe.water
	var is_water: bool = recipe.water or is_stream
	var is_fall: bool = entry.name == "strand"
	material.shader = load("res://shaders/reference_water.gdshader" if is_water else "res://shaders/reference_fall.gdshader" if is_fall else "res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("base_color", color_at(recipe.color).linear_to_srgb())
	if is_water:
		material.set_shader_parameter("flowing", is_stream)
		if entry.has("lake_wind"):
			if not entry.lake_wind.receiveShadow:
				material.shader = load("res://shaders/lake_reference_water.gdshader")
			material.set_shader_parameter("lake_swell", entry.lake_wind.look[2])
			material.set_shader_parameter("lake_look", Vector2(entry.lake_wind.look[0], entry.lake_wind.look[1]))
			var algae: Dictionary = entry.lake_wind.algae
			material.set_shader_parameter("lake_algae_amount", algae.amount)
			material.set_shader_parameter("lake_algae_richness", algae.richness)
			material.set_shader_parameter("lake_algae_seed", algae.seed)
			var anchors := PackedVector3Array()
			for anchor: Array in algae.anchors:
				anchors.append(Vector3(anchor[0], anchor[1], anchor[2]))
			material.set_shader_parameter("lake_algae_anchors", anchors)
			var volume: Array = entry.lake_wind.volume
			material.set_shader_parameter("lake_volume", Vector4(volume[0], volume[1], volume[2], volume[3]))
			material.set_shader_parameter("lake_effects", Vector2(entry.lake_wind.effects[0], entry.lake_wind.effects[1]))
		for pair: Array in [["sky_down", "uDown"], ["sky_up", "uUp"], ["sky_glow", "uGlow"], ["sun_direction", "uSunDir"]]:
			material.set_shader_parameter(pair[0], vector_at(sky[pair[1]]))
		material.set_shader_parameter("dusk_direction", sky.get("uDuskDir", 0.0))
	elif is_fall:
		var f: Dictionary = entry.fall_data
		material.set_shader_parameter("ring_count", f.centers.size())
		material.set_shader_parameter("fall_seed", f.seed)
		material.set_shader_parameter("body_white", f.bodyWhite)
		material.set_shader_parameter("section_white", PackedFloat32Array(f.sectWhite))
		for pair: Array in [["centers_tau", "centers", "tau"], ["axis_a_width", "axA", "halfW"], ["axis_b_thick", "axB", "thick"]]:
			var values := PackedVector4Array()
			values.resize(32)
			for i in range(f.centers.size()):
				var v: Array = f[pair[1]][i]
				values[i] = Vector4(v[0], v[1], v[2], f[pair[2]][i])
			material.set_shader_parameter(pair[0], values)
		var shape := PackedVector2Array()
		shape.resize(32)
		for i in range(f.centers.size()):
			shape[i] = Vector2(f.aer[i], f.steep[i])
		material.set_shader_parameter("aer_steep", shape)
	elif not is_fall:
		material.set_shader_parameter("emissive_color", vector_at(recipe.emissive) * float(recipe.emissiveIntensity))
		material.set_shader_parameter("roughness_value", recipe.roughness)
		material.set_shader_parameter("metalness_value", recipe.metalness)
		material.set_shader_parameter("hemi_sky", vector_at(hemi.color))
		material.set_shader_parameter("hemi_ground", vector_at(hemi.ground))
		material.set_shader_parameter("hemi_energy", hemi.intensity)
		material.set_shader_parameter("wet_ground", entry.attrs.has("aDelay") or entry.name in ["mesh-3", "mesh-4", "mesh-5", "mesh-6", "mesh-7"])
		material.set_shader_parameter("flat_faces", recipe.get("flat", false))
		material.set_shader_parameter("terrain_growth", entry.attrs.has("aDelay"))
		material.set_shader_parameter("plant_growth", entry.count > 0 and (recipe.sway != null or "zs" in recipe.tags))
		material.set_shader_parameter("bird_wings", entry.get("role", "static") == "birds")
		if recipe.sway != null:
			var s: Dictionary = recipe.sway
			material.set_shader_parameter("sway_enabled", true)
			material.set_shader_parameter("wet_droop", s.get("droop", 0.0))
			material.set_shader_parameter("sway_shape", Vector4(s.bendLo, s.bendHi, s.ax, s.az))
			material.set_shader_parameter("sway_frequency", Vector4(s.f1, s.f2, s.w1, s.w2))
			material.set_shader_parameter("sway_phase", Vector3(s.phX, s.phZ, s.ph2))
	return material

func _stream_coordinates(entry: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	if not entry.attrs.has("aDepth") or entry.material.water:
		return result
	var attrs: Dictionary = entry.attrs
	var vertex_count: int = attrs.position.array.size() / 3
	result.resize(vertex_count)
	if attrs.has("aS") and attrs.has("aU"):
		for i in range(vertex_count):
			result[i] = Vector2(attrs.aS.array[i], attrs.aU.array[i])
		return result
	# Version 1 omitted stream attributes. Its unindexed ribbon uses the source
	# water.js five-point section and four six-vertex quads per station.
	if entry.index != null or vertex_count % 24 != 0:
		push_error("Stream export lacks aS/aU; re-export the source scene.")
		return PackedVector2Array()
	var stations: int = vertex_count / 24
	var lengths: Array[float] = [0.0]
	var previous := vector_at(attrs.position.array, 12 * 3)
	for i in range(stations):
		var next := vector_at(attrs.position.array, (i * 24 + 13) * 3)
		lengths.append(lengths[-1] + next.distance_to(previous))
		previous = next
	for station in range(stations):
		for lane in range(4):
			var corners := [Vector2(0, lane), Vector2(1, lane), Vector2(1, lane + 1), Vector2(0, lane), Vector2(1, lane + 1), Vector2(0, lane + 1)]
			for j in range(6):
				result[station * 24 + lane * 6 + j] = Vector2(lengths[station + int(corners[j].x)], [-1.0, -0.72, 0.0, 0.72, 1.0][int(corners[j].y)])
	return result

func matrix_transform(values: Array, offset: int = 0) -> Transform3D:
	return Transform3D(Basis(vector_at(values, offset), vector_at(values, offset + 4), vector_at(values, offset + 8)), vector_at(values, offset + 12))

func vector_at(values: Array, offset: int = 0) -> Vector3:
	return Vector3(values[offset], values[offset + 1], values[offset + 2])

func color_at(values: Array, offset: int = 0) -> Color:
	return Color(values[offset], values[offset + 1], values[offset + 2], 1.0)
