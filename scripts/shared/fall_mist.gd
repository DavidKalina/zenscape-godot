extends CanvasLayer
## Source point sprites composited after scene tone mapping, before air/UI.
var material := ShaderMaterial.new()
var particle_count := 0
var fallback_depth: CompositorEffect
var empty_depth: ImageTexture
func setup(data: Dictionary) -> void:
	layer = -1
	particle_count = data.phase.size()
	assert(particle_count <= 64, "Mist shader capacity exceeded")
	var empty := Image.create(1,1,false,Image.FORMAT_RGF)
	empty.fill(Color(0,0,0,0))
	empty_depth = ImageTexture.create_from_image(empty)
	material.set_shader_parameter("surface_depth",empty_depth)
	material.shader = preload("res://shaders/reference_mist_display.gdshader")
	var origins := PackedVector3Array()
	var motion := PackedVector4Array()
	for i in range(64):
		origins.append(Vector3(data.positions[i*3],data.positions[i*3+1],data.positions[i*3+2]) if i < particle_count else Vector3.ZERO)
		motion.append(Vector4(data.velocity[i*3],data.velocity[i*3+2],data.phase[i],data.size[i]) if i < particle_count else Vector4.ZERO)
	material.set_shader_parameter("origins",origins)
	material.set_shader_parameter("motion",motion)
	material.set_shader_parameter("particle_count",particle_count)
	material.set_shader_parameter("rise_height",data.rise)
	# One quad per particle; the vertex shader places and sizes it like the
	# source gl_PointSize sprite, so untouched screen pixels cost nothing.
	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var sprites := MultiMeshInstance2D.new()
	sprites.multimesh = MultiMesh.new()
	sprites.multimesh.transform_format = MultiMesh.TRANSFORM_2D
	sprites.multimesh.mesh = quad
	sprites.multimesh.instance_count = 64
	for i in range(64):
		sprites.multimesh.set_instance_transform_2d(i, Transform2D.IDENTITY)
	sprites.material = material
	add_child(sprites)
func update_view(camera: Camera3D, shared_depth: CompositorEffect = null) -> void:
	var depth: CompositorEffect = shared_depth
	if depth == null:
		if fallback_depth == null:
			fallback_depth = preload("res://scripts/shared/surface_depth.gd").new()
			var compositor := Compositor.new()
			compositor.compositor_effects = [fallback_depth]
			camera.compositor = compositor
		depth = fallback_depth
	# Sprites are placed in the canvas's logical units; the depth copy is physical.
	var size := get_viewport().get_visible_rect().size
	depth.resize(get_window().size)
	if depth.texture.texture_rd_rid.is_valid():
		material.set_shader_parameter("surface_depth",depth.texture)
	material.set_shader_parameter("camera_origin",camera.global_position)
	material.set_shader_parameter("world_to_view",camera.global_basis.transposed())
	material.set_shader_parameter("camera_planes",Vector2(camera.near,camera.far))
	var tangent := tan(deg_to_rad(camera.fov)*0.5)
	material.set_shader_parameter("projection_scale",Vector2(tangent*size.x/size.y,tangent))
	material.set_shader_parameter("viewport_size",size)

func _exit_tree() -> void:
	material.set_shader_parameter("surface_depth",empty_depth)
	material.shader = null
