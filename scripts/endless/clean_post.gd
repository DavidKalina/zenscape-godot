extends CompositorEffect
## The clean look's post pass (shaders/clean_post.glsl; scripts/endless/
## clean_look.gd owns it): the edge line on ridges and silhouettes (--edges=1,
## key J) and the light grade of the clean look (K). Attached to the camera
## only while either is on.

const TINT_WARM := Vector3(1.07, 1.02, 0.92)
const TINT_COOL := Vector3(0.93, 0.98, 1.08)
## The edge starts to show from EDGE_BEGIN m and is whole by EDGE_FULL m.
const EDGE_BEGIN := 140.0
const EDGE_FULL := 500.0

var camera: Camera3D
var edge_strength := 0.0
var grade_strength := 0.0
var edge_colour := Vector3(0.7, 0.8, 0.95)
var edge_reach := 1.0
var _rd: RenderingDevice
var _shader := RID()
var _pipeline := RID()
var _nearest := RID()
var _ready_flag := false

static func available() -> bool:
	return RenderingServer.get_rendering_device() != null

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_depth = true
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
	_nearest = _rd.sampler_create(RDSamplerState.new())
	_ready_flag = true

## Attached while any of it is on, off the camera otherwise (no cost).
func refresh() -> void:
	var on := edge_strength > 0.0 or grade_strength > 0.0
	if camera == null or _rd == null: return
	var compositor := camera.compositor
	if on and compositor == null:
		compositor = Compositor.new()
		camera.compositor = compositor
	if compositor == null: return
	var effects := compositor.compositor_effects
	if on and not effects.has(self):
		effects.append(self)
		compositor.compositor_effects = effects
	elif not on and effects.has(self):
		effects.erase(self)
		compositor.compositor_effects = effects

func _render_callback(_type: int, data: RenderData) -> void:
	if not _ready_flag or not _pipeline.is_valid(): return
	var buffers: RenderSceneBuffersRD = data.get_render_scene_buffers()
	if buffers == null or buffers.get_internal_size() == Vector2i.ZERO: return
	var depth := buffers.get_depth_layer(0,false)
	var color := buffers.get_color_layer(0,false)
	if not depth.is_valid() or not color.is_valid(): return
	var far := camera.far if camera != null else 8000.0
	var near := camera.near if camera != null else 0.05
	var push := PackedFloat32Array([
		near,far,edge_strength,grade_strength,
		edge_colour.x,edge_colour.y,edge_colour.z,edge_reach,
		TINT_WARM.x,TINT_WARM.y,TINT_WARM.z,EDGE_BEGIN,
		TINT_COOL.x,TINT_COOL.y,TINT_COOL.z,EDGE_FULL])
	var u0 := RDUniform.new()
	u0.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u0.binding = 0
	u0.add_id(_nearest)
	u0.add_id(depth)
	var u1 := RDUniform.new()
	u1.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u1.binding = 1
	u1.add_id(color)
	var set := UniformSetCacheRD.get_cache(_shader,0,[u0,u1])
	var size := buffers.get_internal_size()
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_pipeline)
	_rd.compute_list_bind_uniform_set(list,set,0)
	_rd.compute_list_set_push_constant(list,push.to_byte_array(),push.size()*4)
	_rd.compute_list_dispatch(list,ceili(size.x/8.0),ceili(size.y/8.0),1)
	_rd.compute_list_end()

func free_buffers() -> void:
	edge_strength = 0.0
	grade_strength = 0.0
	refresh()
	if _rd == null: return
	RenderingServer.call_on_render_thread(_free)

func _free() -> void:
	for rid: RID in [_pipeline,_shader,_nearest]:
		if rid.is_valid(): _rd.free_rid(rid)
