extends CanvasLayer
## Source-style display-space atmosphere compositor.
##
## The air march lands on a quarter of the pixels the composite reads: a target
## half the size of `buffer` in each axis, its rays nudged a quarter texel in a
## four-frame cycle so four marches between them visit every pixel. A resolve
## pass at `buffer` size then finds where each pixel's fog stood last frame,
## clamps that history to the new sample's neighbourhood and blends the new
## sample in, keeping the result as the next frame's history (source
## weather.js §2c). A still camera integrates the start dither away over a
## dozen frames instead of paying for more steps every frame.
var surface_haze_enabled := not OS.get_cmdline_user_args().has("--no-surface-haze")
var depth = preload("res://studies/surface_depth.gd").new()
var blend := ShaderMaterial.new()
## The march.
var material := ShaderMaterial.new()
## The temporal resolve that fills `buffer` from `march` and `history`.
var resolve := ShaderMaterial.new()
var air: Node3D
var camera: Camera3D
## The resolved field the composite reads.
var buffer := SubViewport.new()
## Where the march lands: half of `buffer` in each axis.
var march := SubViewport.new()
## Resolved-field scale relative to the window. The source volumes render at
## 0.5 (0.35 on low quality): the march cost is linear in its square.
var buffer_scale := 0.5
## Weight of the new sample where history is valid (source TEMPORAL_BLEND).
## Lower integrates more dither away and lags a moving field more; the
## neighbourhood clamp bounds the lag.
var temporal_blend := 0.12
## The four quarter-texel nudges, in march texels (source JITTER).
const JITTER := [Vector2(-0.25, -0.25), Vector2(0.25, -0.25), Vector2(-0.25, 0.25), Vector2(0.25, 0.25)]
## Last frame's resolved field, copied on the rendering device before each draw.
var history := Texture2DRD.new()
var _rd: RenderingDevice
var _history_rid := RID()
var _history_size := Vector2i.ZERO
var _history_ok := false
var _frame := 0

func setup(atmosphere: Node3D, view: Camera3D, ground: Texture2D, stream: Texture2D) -> void:
	layer = 0
	var post_inversion := not OS.get_cmdline_user_args().has("--native-inversion-paint")
	RenderingServer.global_shader_parameter_set("zs_surface_post", post_inversion)
	air = atmosphere
	camera = view
	_rd = RenderingServer.get_rendering_device()
	var compositor := Compositor.new()
	compositor.compositor_effects = [depth]
	camera.compositor = compositor
	material.shader = preload("res://shaders/reference_air_composite.gdshader")
	material.set_shader_parameter("ground_map", ground)
	material.set_shader_parameter("stream_map", stream)
	buffer.name = "AirBuffer"
	buffer.disable_3d = true
	buffer.transparent_bg = true
	buffer.use_hdr_2d = true
	buffer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(buffer)
	# A child viewport draws before its parent, so the march is fresh when the
	# resolve reads it.
	march.name = "AirMarch"
	march.disable_3d = true
	march.transparent_bg = true
	march.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	buffer.add_child(march)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	march.add_child(rect)
	resolve.shader = preload("res://shaders/reference_air_resolve.gdshader")
	resolve.set_shader_parameter("march", march.get_texture())
	resolve.set_shader_parameter("history", history)
	resolve.set_shader_parameter("surface_depth", depth.texture)
	resolve.set_shader_parameter("blend_weight", temporal_blend)
	var resolved := ColorRect.new()
	resolved.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resolved.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resolved.material = resolve
	buffer.add_child(resolved)
	var composite := ColorRect.new()
	composite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	composite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blend.shader = preload("res://shaders/reference_air_blend.gdshader")
	blend.set_shader_parameter("surface_inversion_enabled", post_inversion)
	blend.set_shader_parameter("air_color", buffer.get_texture())
	blend.set_shader_parameter("surface_depth", depth.texture)
	composite.material = blend
	add_child(composite)
	RenderingServer.frame_pre_draw.connect(_before_draw)
	update_view()

func update_view() -> void:
	material.set_shader_parameter("floor_height", air._ground_min)
	material.set_shader_parameter("camera_basis", camera.global_basis)
	var tangent := tan(deg_to_rad(camera.fov) * 0.5)
	# Physical pixels: the canvas visible rect is in DPI-scaled logical units.
	var size := Vector2(get_window().size)
	var orthographic := camera.projection == Camera3D.PROJECTION_ORTHOGONAL
	var projection_scale := Vector2(tangent * size.x / size.y, tangent)
	if orthographic:
		var projection := camera.get_camera_projection()
		projection_scale = Vector2(1.0 / projection.x.x, 1.0 / projection.y.y)
	material.set_shader_parameter("orthographic", orthographic)
	blend.set_shader_parameter("surface_orthographic", orthographic)
	resolve.set_shader_parameter("orthographic", orthographic)
	buffer.size = Vector2i((size * buffer_scale).max(Vector2(64, 64)))
	march.size = Vector2i(ceili(buffer.size.x / 2.0), ceili(buffer.size.y / 2.0))
	resolve.set_shader_parameter("low_res", Vector2(march.size))
	depth.resize(Vector2i(size))
	blend.set_shader_parameter("camera_planes", Vector2(camera.near, camera.far))
	resolve.set_shader_parameter("camera_planes", Vector2(camera.near, camera.far))
	blend.set_shader_parameter("surface_camera_basis", camera.global_basis)
	blend.set_shader_parameter("surface_projection_scale", projection_scale)
	blend.set_shader_parameter("surface_density", air.haze_amount * 0.014 + air.fog_amount * 0.004 + air.shroud * air.shroud * 0.010 if surface_haze_enabled else 0.0)
	blend.set_shader_parameter("aerial_gain", (1.0 - air.shroud) * (1.0 - air.shroud))
	material.set_shader_parameter("projection_scale", projection_scale)
	resolve.set_shader_parameter("projection_scale", projection_scale)
	material.set_shader_parameter("shroud", air.shroud)
	material.set_shader_parameter("loosen", air.loosen)
	material.set_shader_parameter("density", air.fog_amount)
	material.set_shader_parameter("haze", air.haze_amount)
	var rays = air._fog_material.get_shader_parameter("rays") if air._fog_material != null else 1.0
	material.set_shader_parameter("rays", 1.0 if rays == null else rays)

## Drop the history: the next frame stands on its march alone.
func forget() -> void:
	_history_ok = false

func _before_draw() -> void:
	# Today's camera, for the resolve to reconstruct rays through; last frame's
	# is what it reprojects through.
	resolve.set_shader_parameter("prev_camera_basis", resolve.get_shader_parameter("camera_basis"))
	resolve.set_shader_parameter("prev_camera_position", resolve.get_shader_parameter("camera_position"))
	resolve.set_shader_parameter("prev_projection_scale", resolve.get_shader_parameter("projection_scale"))
	resolve.set_shader_parameter("camera_basis", camera.global_basis)
	resolve.set_shader_parameter("camera_position", camera.global_position)
	resolve.set_shader_parameter("blend_weight", temporal_blend)
	_frame = (_frame + 1) % 64
	material.set_shader_parameter("frame", _frame)
	var jitter: Vector2 = JITTER[_frame & 3]
	material.set_shader_parameter("jitter", jitter)
	resolve.set_shader_parameter("jitter", jitter)
	resolve.set_shader_parameter("history_ok", _keep_history())

## Keep last frame's resolved field as history. Returns whether it can be trusted:
## a resize or a forget() starts fresh, as does a frame with no device.
func _keep_history() -> bool:
	if _rd == null:
		return false
	var source := RenderingServer.texture_get_rd_texture(buffer.get_texture().get_rid())
	var size := buffer.size
	var usable := _history_ok and source.is_valid() and size == _history_size
	if size != _history_size and source.is_valid():
		_history_size = size
		RenderingServer.call_on_render_thread(_allocate_history.bind(size, source))
	if usable:
		RenderingServer.call_on_render_thread(_copy_history.bind(source, size))
	_history_ok = source.is_valid() and size == _history_size
	return usable

func _allocate_history(size: Vector2i, like: RID) -> void:
	var format := RDTextureFormat.new()
	format.width = size.x
	format.height = size.y
	format.format = _rd.texture_get_format(like).format
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	var previous := _history_rid
	_history_rid = _rd.texture_create(format, RDTextureView.new())
	history.texture_rd_rid = _history_rid
	if previous.is_valid():
		_rd.free_rid(previous)

func _copy_history(source: RID, size: Vector2i) -> void:
	if _history_rid.is_valid() and _rd.texture_is_valid(source):
		_rd.texture_copy(source, _history_rid, Vector3.ZERO, Vector3.ZERO, Vector3(size.x, size.y, 1), 0, 0, 0, 0)

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("zs_surface_post", false)
	if RenderingServer.frame_pre_draw.is_connected(_before_draw):
		RenderingServer.frame_pre_draw.disconnect(_before_draw)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null and _history_rid.is_valid():
		history.texture_rd_rid = RID()
		_rd.free_rid(_history_rid)
		_history_rid = RID()
