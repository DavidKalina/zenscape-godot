extends CompositorEffect
## The sea's lingering foam (shaders/endless_sea_foam.glsl): a SIDE m square
## of the sea, TEXELS on a side, kept round the eye (set ahead of it along
## the view) and addressed by world position wrapped on its side, so it
## moves for free. Each frame a compute pass carries last frame's foam
## downstream, spreads and fades it, and adds what the wind sea's breaking
## crests leave now; the sea shader (shaders/endless_sea.gdshader, sea_foam
## 1) reads it as `foam_buffer`, at `foam_at`, and turns it into lace.
## The pass runs as the drawing camera's compositor effect, before the
## opaque pass, and reads last frame's half with imageLoad (sampling the
## half it wrote the frame before hung Metal within a few seconds). Without
## a rendering device (headless) there is no buffer: `ready()` is false and
## the sea draws its analytic foam everywhere.

const TEXELS := 1024
const SIDE := 512.0
## How far ahead of the eye the square's middle sits, as a share of SIDE.
const AHEAD := 0.28
const FLOATS := 36

## The two halves of the ping-pong: a frame reads one and writes the other;
## `side` says which holds the newest.
var textures: Array[Texture2DRD] = [Texture2DRD.new(),Texture2DRD.new()]
var side := 0
var origin := Vector2.ZERO
var drift := Vector2.ZERO
var _rd: RenderingDevice
var _shader := RID()
var _pipeline := RID()
var _tex: Array[RID] = [RID(),RID()]
var _params := RID()
var _sets: Array[RID] = [RID(),RID()]
var _before := Vector2.INF
var _bytes := PackedByteArray()
var _from := 0
var _pending := false
var camera: Camera3D

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_OPAQUE
	needs_motion_vectors = false
	_rd = RenderingServer.get_rendering_device()
	if _rd == null: return # Headless: no rendering device.
	RenderingServer.call_on_render_thread(_allocate)

func ready() -> bool:
	return _rd != null

func _allocate() -> void:
	var spirv: RDShaderSPIRV = preload("res://shaders/endless_sea_foam.glsl").get_spirv()
	if not spirv.compile_error_compute.is_empty():
		push_error("sea foam: "+spirv.compile_error_compute)
		_rd = null
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	_pipeline = _rd.compute_pipeline_create(_shader)
	var format := RDTextureFormat.new()
	format.width = TEXELS
	format.height = TEXELS
	format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	for i in 2:
		_tex[i] = _rd.texture_create(format,RDTextureView.new())
		_rd.texture_clear(_tex[i],Color(0,0,0,0),0,1,0,1)
	_params = _rd.storage_buffer_create(FLOATS*4)
	var b := RDUniform.new()
	b.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	b.binding = 0
	b.add_id(_params)
	# _sets[i] reads _tex[i] and writes the other.
	for i in 2:
		var s := RDUniform.new()
		s.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		s.binding = 1
		s.add_id(_tex[i])
		var o := RDUniform.new()
		o.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		o.binding = 2
		o.add_id(_tex[1-i])
		_sets[i] = _rd.uniform_set_create([b,s,o],_shader,0)
		textures[i].texture_rd_rid = _tex[i]

## One frame. `eye` and `facing` place the square; `time` is the sea's clock
## (zs_flow_time); `knobs` the material's values the crests and the flow
## read; `wake` the plane (x, z, strength 0..1, radius m).
func step(delta: float, eye: Vector3, facing: Vector3, time: float, knobs: Dictionary, wake: Vector4, view: Camera3D = null) -> void:
	if view != null and view.is_inside_tree():
		var drawing := view.get_viewport().get_camera_3d()
		if drawing != null: view = drawing
	if view != camera:
		_detach()
		camera = view
		_attach()
	var wind: Vector2 = Vector2(knobs.body_wind).normalized()
	var flow: Vector4 = knobs.foam_flow
	drift += wind*flow.x*delta
	if _rd == null: return
	var ahead := Vector2(facing.x,facing.z)
	ahead = ahead.normalized()*AHEAD*SIDE if ahead.length() > 0.1 else Vector2.ZERO
	var texel := SIDE/TEXELS
	var middle := Vector2(eye.x,eye.z)+ahead
	origin = ((middle-Vector2.ONE*SIDE*0.5)/texel).floor()*texel
	var swell: Vector3 = knobs.body_swell
	var bpatch: Vector3 = knobs.body_patch
	var caps: Vector3 = knobs.whitecaps
	var spread: Vector2 = knobs.foam_spread
	var p := PackedFloat32Array([
		origin.x,origin.y,SIDE,TEXELS,
		_before.x if _before.is_finite() else 0.0,_before.y if _before.is_finite() else 0.0,delta,time,
		swell.x,swell.y,swell.z,float(knobs.swell_groups),
		bpatch.x,bpatch.y,bpatch.z,Vector2(knobs.wind_patches).x,
		wind.x,wind.y,1.0 if _before.is_finite() else 0.0,spread.x,
		caps.x,caps.y,caps.z,spread.y,
		flow.x,flow.y,flow.z,flow.w,
		wake.x,wake.y,wake.z,wake.w,
		Vector3(knobs.foam_caps).x,Vector3(knobs.foam_caps).y,Vector3(knobs.foam_caps).z,0.0])
	_before = origin
	_bytes = p.to_byte_array()
	_from = side
	_pending = true
	side = 1-side

func _attach() -> void:
	if camera == null or _rd == null: return
	var compositor := camera.compositor
	if compositor == null:
		compositor = Compositor.new()
		camera.compositor = compositor
	var effects := compositor.compositor_effects
	if not effects.has(self):
		effects.append(self)
		compositor.compositor_effects = effects

func _detach() -> void:
	if camera == null or not is_instance_valid(camera) or camera.compositor == null: return
	var effects := camera.compositor.compositor_effects
	if effects.has(self):
		effects.erase(self)
		camera.compositor.compositor_effects = effects

func _render_callback(_type: int, _data: RenderData) -> void:
	if not _pending: return
	_pending = false
	var bytes := _bytes
	var from := _from
	if _rd == null or not _sets[from].is_valid(): return
	_rd.buffer_update(_params,0,bytes.size(),bytes)
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_pipeline)
	_rd.compute_list_bind_uniform_set(list,_sets[from],0)
	_rd.compute_list_dispatch(list,TEXELS/8,TEXELS/8,1)
	_rd.compute_list_end()

func free_buffers() -> void:
	_detach()
	if _rd == null: return
	RenderingServer.call_on_render_thread(_free)

func _free() -> void:
	for rid: RID in [_sets[0],_sets[1],_pipeline,_shader,_params]:
		if rid.is_valid(): _rd.free_rid(rid)
