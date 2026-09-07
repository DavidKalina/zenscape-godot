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
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	add_child(rect)
func update_view(camera: Camera3D, shared_depth: CompositorEffect = null) -> void:
	var depth: CompositorEffect = shared_depth
	if depth == null:
		if fallback_depth == null:
			fallback_depth = preload("res://studies/surface_depth.gd").new()
			var compositor := Compositor.new()
			compositor.compositor_effects = [fallback_depth]
			camera.compositor = compositor
		depth = fallback_depth
	var size := get_viewport().get_visible_rect().size
	depth.resize(Vector2i(size))
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
