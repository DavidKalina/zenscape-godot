extends CanvasLayer
## Source-style display-space atmosphere compositor.
var surface_haze_enabled := not OS.get_cmdline_user_args().has("--no-surface-haze")
var depth = preload("res://studies/surface_depth.gd").new()
var blend := ShaderMaterial.new()
var material := ShaderMaterial.new()
var air: Node3D
var camera: Camera3D
var buffer := SubViewport.new()

func setup(atmosphere: Node3D, view: Camera3D, ground: Texture2D, stream: Texture2D) -> void:
	layer = 0
	var post_inversion := not OS.get_cmdline_user_args().has("--native-inversion-paint")
	RenderingServer.global_shader_parameter_set("zs_surface_post", post_inversion)
	air = atmosphere
	camera = view
	var compositor := Compositor.new()
	compositor.compositor_effects = [depth]
	camera.compositor = compositor
	material.shader = preload("res://shaders/reference_air_composite.gdshader")
	material.set_shader_parameter("ground_map", ground)
	material.set_shader_parameter("stream_map", stream)
	buffer.name = "AirBuffer"
	buffer.disable_3d = true
	buffer.transparent_bg = true
	buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(buffer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	buffer.add_child(rect)
	var composite := ColorRect.new()
	composite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	composite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blend.shader = preload("res://shaders/reference_air_blend.gdshader")
	blend.set_shader_parameter("surface_inversion_enabled", post_inversion)
	blend.set_shader_parameter("air_color", buffer.get_texture())
	blend.set_shader_parameter("surface_depth", depth.texture)
	composite.material = blend
	add_child(composite)
	update_view()

func update_view() -> void:
	material.set_shader_parameter("floor_height", air._ground_min)
	material.set_shader_parameter("camera_basis", camera.global_basis)
	var tangent := tan(deg_to_rad(camera.fov) * 0.5)
	var size := get_viewport().get_visible_rect().size
	var orthographic := camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	var projection_scale := Vector2(tangent * size.x / size.y, tangent)
	if orthographic:
		var projection := camera.get_camera_projection()
		projection_scale = Vector2(1.0 / projection.x.x, 1.0 / projection.y.y)
	material.set_shader_parameter("orthographic", orthographic)
	blend.set_shader_parameter("surface_orthographic", orthographic)
	buffer.size = Vector2i(size * 0.5)
	depth.resize(Vector2i(size))
	blend.set_shader_parameter("camera_planes", Vector2(camera.near, camera.far))
	blend.set_shader_parameter("surface_camera_basis", camera.global_basis)
	blend.set_shader_parameter("surface_projection_scale", projection_scale)
	blend.set_shader_parameter("surface_density", air.haze_amount * 0.014 + air.fog_amount * 0.004 + air.shroud * air.shroud * 0.010 if surface_haze_enabled else 0.0)
	blend.set_shader_parameter("aerial_gain", (1.0 - air.shroud) * (1.0 - air.shroud))
	material.set_shader_parameter("projection_scale", projection_scale)
	material.set_shader_parameter("shroud", air.shroud)
	material.set_shader_parameter("loosen", air.loosen)
	material.set_shader_parameter("density", air.fog_amount)
	material.set_shader_parameter("haze", air.haze_amount)
	var rays = air._fog_material.get_shader_parameter("rays") if air._fog_material != null else 1.0
	material.set_shader_parameter("rays", 1.0 if rays == null else rays)

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("zs_surface_post", false)
