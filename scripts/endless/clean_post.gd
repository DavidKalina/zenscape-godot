extends CompositorEffect
## The look's post pass (shaders/clean_post.glsl; scripts/endless/clean_look.gd
## owns it): a light grade, highlights a little warm and shadows a little
## cool. Always on where there is a RenderingDevice (Forward+ and Mobile);
## with the Compatibility renderer there is none, and the game runs without it.

## The grade's tints, set each frame from the sun and sky (clean_look.gd _tints);
## these are the values at the default mood and hour.
var tint_warm := Vector3(1.07, 1.02, 0.92)
var tint_cool := Vector3(0.93, 0.98, 1.08)

var camera: Camera3D
var _rd: RenderingDevice
var _shader := RID()
var _pipeline := RID()
var _ready_flag := false

static func available() -> bool:
	return RenderingServer.get_rendering_device() != null

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	_rd = RenderingServer.get_rendering_device()
	if _rd != null: RenderingServer.call_on_render_thread(_allocate)

func _allocate() -> void:
	var spirv: RDShaderSPIRV = preload("res://shaders/clean_post.glsl").get_spirv()
	if not spirv.compile_error_compute.is_empty():
		push_error("clean post: "+spirv.compile_error_compute)
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	_pipeline = _rd.compute_pipeline_create(_shader)
	_ready_flag = true

## Puts the pass on the camera.
func attach() -> void:
	if camera == null or _rd == null: return
	var compositor := camera.compositor
	if compositor == null:
		compositor = Compositor.new()
		camera.compositor = compositor
	var effects := compositor.compositor_effects
	if not effects.has(self):
		effects.append(self)
		compositor.compositor_effects = effects

func _render_callback(_type: int, data: RenderData) -> void:
	if not _ready_flag or not _pipeline.is_valid(): return
	var buffers: RenderSceneBuffersRD = data.get_render_scene_buffers()
	if buffers == null or buffers.get_internal_size() == Vector2i.ZERO: return
	var color := buffers.get_color_layer(0,false)
	if not color.is_valid(): return
	var push := PackedFloat32Array([
		tint_warm.x,tint_warm.y,tint_warm.z,0.0,
		tint_cool.x,tint_cool.y,tint_cool.z,0.0])
	var u0 := RDUniform.new()
	u0.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u0.binding = 0
	u0.add_id(color)
	var set := UniformSetCacheRD.get_cache(_shader,0,[u0])
	var size := buffers.get_internal_size()
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_pipeline)
	_rd.compute_list_bind_uniform_set(list,set,0)
	_rd.compute_list_set_push_constant(list,push.to_byte_array(),push.size()*4)
	_rd.compute_list_dispatch(list,ceili(size.x/8.0),ceili(size.y/8.0),1)
	_rd.compute_list_end()

func free_buffers() -> void:
	if camera != null and is_instance_valid(camera) and camera.compositor != null:
		var effects := camera.compositor.compositor_effects
		if effects.has(self):
			effects.erase(self)
			camera.compositor.compositor_effects = effects
	if _rd == null: return
	RenderingServer.call_on_render_thread(_free)

func _free() -> void:
	for rid: RID in [_pipeline,_shader]:
		if rid.is_valid(): _rd.free_rid(rid)
