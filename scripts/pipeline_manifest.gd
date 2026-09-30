extends RefCounted
## What the GPU has to build a pipeline for, written down so the load can
## build it first (scripts/pipeline_warmup.gd, docs/performance/stutter.md).
## A pipeline is fixed by the shader, the vertex layout it reads, how the
## geometry is drawn (mesh, multimesh with colours or custom data, particles)
## and the pass it draws in (shadows, transparency). Uniform values and
## textures do not matter, so an entry keeps only those, and a stand-in built
## from it is one triangle with that layout and that material.
##
## tools/profile_play_session.gd `--record-manifest` plays the game and
## writes every entry it sees drawn; the warm-up replays them.

const DIR := "res://assets/pipeline_warmup"
const FILE := "manifest.json"

## One entry per surface `node` draws, or [] for geometry drawn by nothing
## this manifest knows. `save_material` stores a material that has no shader
## file and returns its name in DIR/materials.
static func describe(node: GeometryInstance3D, save_material: Callable) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var base := {"shadow":int(node.cast_shadow),"transparent":node.transparency > 0.0}
	if node is MultiMeshInstance3D:
		var multimesh := (node as MultiMeshInstance3D).multimesh
		if multimesh == null or multimesh.mesh == null: return entries
		base.kind = "multimesh"
		base.colors = multimesh.use_colors
		base.custom = multimesh.use_custom_data
		base.transform = int(multimesh.transform_format)
		_surfaces(multimesh.mesh,node.material_override,base,entries,save_material)
	elif node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh == null or instance.skeleton != NodePath() and instance.skin != null: return entries
		base.kind = "mesh"
		for i in range(instance.mesh.get_surface_count()):
			var material: Material = node.material_override
			if material == null: material = instance.get_surface_override_material(i)
			_surface(instance.mesh,i,material,base,entries,save_material)
	elif node is GPUParticles3D:
		var particles := node as GPUParticles3D
		if particles.draw_pass_1 == null or particles.process_material == null: return entries
		base.kind = "particles"
		base.process = _material(particles.process_material,save_material)
		_surfaces(particles.draw_pass_1,node.material_override,base,entries,save_material)
	return entries

static func _surfaces(mesh: Mesh, override: Material, base: Dictionary, entries: Array[Dictionary], save_material: Callable) -> void:
	for i in range(mesh.get_surface_count()): _surface(mesh,i,override,base,entries,save_material)

static func _surface(mesh: Mesh, surface: int, override: Material, base: Dictionary, entries: Array[Dictionary], save_material: Callable) -> void:
	var material: Material = override if override != null else mesh.surface_get_material(surface)
	if material == null: return
	var entry := base.duplicate()
	entry.format = format(mesh,surface)
	entry.primitive = primitive(mesh,surface)
	entry.material = _material(material,save_material)
	if entry.material.is_empty() or (base.has("process") and base.process.is_empty()): return
	entries.append(entry)

static func primitive(mesh: Mesh, surface: int) -> int:
	if mesh is ArrayMesh: return int((mesh as ArrayMesh).surface_get_primitive_type(surface))
	return int(RenderingServer.mesh_get_surface(mesh.get_rid(),surface).get("primitive",Mesh.PRIMITIVE_TRIANGLES))

static func format(mesh: Mesh, surface: int) -> int:
	if mesh is ArrayMesh: return (mesh as ArrayMesh).surface_get_format(surface)
	return int(RenderingServer.mesh_get_surface(mesh.get_rid(),surface).get("format",0))

## A material as the pipeline sees it: a shader file and priority, inline
## shader code, or a stored copy (built-in materials, whose shader follows
## their flags). A next pass is its own pipeline and comes along.
static func _material(material: Material, save_material: Callable) -> Dictionary:
	var found := {"priority":material.render_priority}
	if material is ShaderMaterial:
		var shader := (material as ShaderMaterial).shader
		if shader == null: return {}
		if shader.resource_path.begins_with("res://") and not "::" in shader.resource_path: found.shader = shader.resource_path
		else: found.code = shader.code
	else:
		var saved: String = save_material.call(material)
		if saved.is_empty(): return {}
		found.file = saved
	if material.next_pass != null:
		var next := _material(material.next_pass,save_material)
		if not next.is_empty(): found.next = next
	return found

## A copy of `material` fit to store: textures become a 1-pixel stand-in (a
## texture's presence can switch a feature on; its pixels never matter), and
## its feature flags name it.
static func storable(material: Material) -> Array:
	var copy: Material = material.duplicate()
	copy.next_pass = null
	var flags := PackedStringArray([material.get_class()])
	for property in copy.get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE): continue
		var value: Variant = copy.get(property.name)
		if value is Texture:
			copy.set(property.name,_pixel(value))
			flags.append(property.name)
		elif value is Resource and not (value is Texture):
			copy.set(property.name,null)
		elif typeof(value) in [TYPE_BOOL,TYPE_INT]:
			flags.append("%s=%s" % [property.name,value])
	return [copy,"|".join(flags).md5_text()]

static func _pixel(texture: Texture) -> Texture:
	if texture is Texture2D:
		var image := Image.create(1,1,false,Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		return ImageTexture.create_from_image(image)
	return null

## Read back what `describe` wrote: the entries, with their materials built.
static func load_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var path := DIR.path_join(FILE)
	if not FileAccess.file_exists(path): return entries
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Array: return entries
	for entry: Variant in parsed:
		if entry is Dictionary: entries.append(entry)
	return entries

static func build_material(found: Dictionary) -> Material:
	var material: Material
	if found.has("shader"):
		if not ResourceLoader.exists(found.shader): return null
		material = ShaderMaterial.new()
		(material as ShaderMaterial).shader = load(found.shader)
	elif found.has("code"):
		var shader := Shader.new()
		shader.code = found.code
		material = ShaderMaterial.new()
		(material as ShaderMaterial).shader = shader
	elif found.has("file"):
		var file: String = DIR.path_join("materials").path_join(found.file)
		if not ResourceLoader.exists(file): return null
		material = (load(file) as Material).duplicate()
	else: return null
	material.render_priority = int(found.get("priority",0))
	if found.has("next"): material.next_pass = build_material(found.next)
	return material

## One triangle (or a few points or lines) carrying every attribute
## `format` names, in its layout.
static func standin_mesh(entry: Dictionary, material: Material) -> ArrayMesh:
	var format := int(entry.format)
	var primitive := int(entry.primitive)
	var count := 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var points := PackedVector3Array()
	for i in range(count): points.append(Vector3(float(i%2),float(i/2)*0.5,0.0))
	arrays[Mesh.ARRAY_VERTEX] = points
	if format & Mesh.ARRAY_FORMAT_NORMAL:
		var normals := PackedVector3Array()
		normals.resize(count)
		normals.fill(Vector3.BACK)
		arrays[Mesh.ARRAY_NORMAL] = normals
	if format & Mesh.ARRAY_FORMAT_TANGENT:
		var tangents := PackedFloat32Array()
		for i in range(count): tangents.append_array([1.0,0.0,0.0,1.0])
		arrays[Mesh.ARRAY_TANGENT] = tangents
	if format & Mesh.ARRAY_FORMAT_COLOR:
		var colors := PackedColorArray()
		colors.resize(count)
		colors.fill(Color.WHITE)
		arrays[Mesh.ARRAY_COLOR] = colors
	for pair in [[Mesh.ARRAY_FORMAT_TEX_UV,Mesh.ARRAY_TEX_UV],[Mesh.ARRAY_FORMAT_TEX_UV2,Mesh.ARRAY_TEX_UV2]]:
		if format & pair[0]:
			var uvs := PackedVector2Array()
			uvs.resize(count)
			arrays[pair[1]] = uvs
	var custom_flags := [Mesh.ARRAY_FORMAT_CUSTOM0,Mesh.ARRAY_FORMAT_CUSTOM1,Mesh.ARRAY_FORMAT_CUSTOM2,Mesh.ARRAY_FORMAT_CUSTOM3]
	for c in range(4):
		if not (format & custom_flags[c]): continue
		var kind := (format >> (Mesh.ARRAY_FORMAT_CUSTOM_BASE+c*Mesh.ARRAY_FORMAT_CUSTOM_BITS)) & Mesh.ARRAY_FORMAT_CUSTOM_MASK
		match kind:
			Mesh.ARRAY_CUSTOM_RGBA8_UNORM, Mesh.ARRAY_CUSTOM_RGBA8_SNORM, Mesh.ARRAY_CUSTOM_RG_HALF:
				var bytes := PackedByteArray()
				bytes.resize(count*4)
				arrays[Mesh.ARRAY_CUSTOM0+c] = bytes
			Mesh.ARRAY_CUSTOM_RGBA_HALF:
				var bytes := PackedByteArray()
				bytes.resize(count*8)
				arrays[Mesh.ARRAY_CUSTOM0+c] = bytes
			_:
				var width: int = {Mesh.ARRAY_CUSTOM_R_FLOAT:1,Mesh.ARRAY_CUSTOM_RG_FLOAT:2,Mesh.ARRAY_CUSTOM_RGB_FLOAT:3}.get(kind,4)
				var floats := PackedFloat32Array()
				floats.resize(count*width)
				arrays[Mesh.ARRAY_CUSTOM0+c] = floats
	if format & Mesh.ARRAY_FORMAT_INDEX:
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,3,4,5])
	var custom_bits := ((1 << (4*Mesh.ARRAY_FORMAT_CUSTOM_BITS))-1) << Mesh.ARRAY_FORMAT_CUSTOM_BASE
	var flags := format & (custom_bits | Mesh.ARRAY_FLAG_USE_2D_VERTICES | Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(primitive,arrays,[],{},flags)
	if mesh.get_surface_count() == 0: return null
	mesh.surface_set_material(0,material)
	return mesh

## The node an entry draws with, holding its stand-in.
static func standin(entry: Dictionary) -> GeometryInstance3D:
	var material := build_material(entry.material)
	if material == null: return null
	var mesh := standin_mesh(entry,material)
	if mesh == null: return null
	var node: GeometryInstance3D
	match str(entry.kind):
		"multimesh":
			var batch := MultiMeshInstance3D.new()
			batch.multimesh = MultiMesh.new()
			batch.multimesh.transform_format = int(entry.get("transform",MultiMesh.TRANSFORM_3D))
			batch.multimesh.use_colors = bool(entry.get("colors",false))
			batch.multimesh.use_custom_data = bool(entry.get("custom",false))
			batch.multimesh.mesh = mesh
			batch.multimesh.instance_count = 1
			# A zero transform collapses the instance and its bounds.
			batch.multimesh.set_instance_transform(0,Transform3D.IDENTITY)
			node = batch
		"particles":
			var process := build_material(entry.process)
			if process == null: return null
			var particles := GPUParticles3D.new()
			particles.amount = 1
			particles.lifetime = 1.0
			particles.process_material = process
			particles.draw_pass_1 = mesh
			particles.visibility_aabb = AABB(Vector3(-1,-1,-1),Vector3(2,2,2))
			node = particles
		_:
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			node = instance
	node.cast_shadow = int(entry.get("shadow",1)) as GeometryInstance3D.ShadowCastingSetting
	if bool(entry.get("transparent",false)): node.transparency = 0.01
	node.extra_cull_margin = 1.0
	return node
