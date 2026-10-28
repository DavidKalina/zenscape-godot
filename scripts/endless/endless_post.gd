extends CompositorEffect
## The endless flight's light pass (shaders/endless_post.glsl; docs/design/
## endless-flight/light-atmosphere-handoff.md): a compute pass on the frame
## after everything is drawn, the clouds and the valley fog too. It lays the
## haze's colour per pixel with a second, sun-sided air over it, splits the
## light into a shadow colour and a sun colour, and gathers light shafts
## toward the sun through the gaps the land, the cloud and the fog leave.
##
## Off by default (all of it together read processed, comic-book): --post=1
## puts it in. Flags: --rays=X the shafts'
## strength times X (0 off); --grade=X the light split's; --air=X the second
## air's; --haze-hue=0 leaves the haze one colour as before; --rays-taps=N.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const LUT := 17
## Float slots: 17 vec4 of settings, then the LUT.
const FLOATS := (17+LUT)*4

## Per mood: rays (strength), split, contrast, air, sat, shade and light
## (tints), and the key and fill (EndlessLook scales the sun and the sky's
## fill by them). Missing keys take DEFAULT.
const DEFAULT := {"rays":0.9,"split":0.65,"contrast":1.08,"air":0.55,"sat":1.06,
	"shade":Vector3(0.84,0.9,1.12),"light":Vector3(1.14,1.02,0.86),"key":1.0,"fill":1.0,"airpow":2.0,"rim":0.9,"lift":0.5,"relief":1.2,"hot":0.7}
const MOODS := {
	"alpine_morning": {"rays":0.9,"shade":Vector3(0.86,0.91,1.1),"key":1.05,"fill":0.95,"lift":0.6},
	"golden_meadow": {"rays":1.0,"split":0.7,"shade":Vector3(0.82,0.88,1.16),"light":Vector3(1.22,1.03,0.80),"key":1.15,"fill":0.75,"air":0.6},
	"rosewater_dusk": {"rays":1.4,"split":0.95,"contrast":1.14,"air":0.7,"sat":1.1,"shade":Vector3(0.78,0.66,1.22),"light":Vector3(1.28,1.0,0.82),"key":1.15,"fill":0.5},
	"rose_dusk": {"rays":1.4,"split":0.95,"contrast":1.14,"air":0.7,"sat":1.1,"shade":Vector3(0.80,0.64,1.15),"light":Vector3(1.32,0.98,0.78),"key":1.15,"fill":0.5},
	"ocean_light": {"rays":0.9,"shade":Vector3(0.88,0.92,1.08),"key":1.1,"fill":0.95,"lift":0.65,"relief":1.4},
	"meadow_morning": {"rays":1.1,"shade":Vector3(0.86,0.92,1.08),"light":Vector3(1.12,1.04,0.88),"key":1.1,"fill":0.9,"lift":0.5},
	"after_the_rain": {"rays":1.4,"split":0.6,"air":0.6,"fill":1.05,"lift":0.75,"shade":Vector3(0.88,0.94,1.08),"light":Vector3(1.12,1.04,0.9),"sat":1.1,"contrast":1.1},
	"desert_afternoon": {"rays":0.9,"shade":Vector3(0.86,0.8,1.06),"light":Vector3(1.2,1.02,0.82),"key":1.15,"fill":0.85,"lift":0.6,"hot":1.0,"relief":1.5},
	"amber_hour": {"rays":1.1,"split":0.7,"air":0.7,"sat":0.92,"shade":Vector3(0.93,0.9,0.97),"light":Vector3(1.17,1.03,0.85),"key":1.08,"fill":0.9,"lift":0.7,"hot":0.8,"relief":1.3},
	"moonlit_stillness": {"rays":0.0,"split":0.0,"air":0.2},
}

var rays_scale := 1.0
var grade_scale := 1.0
var air_scale := 1.0
var haze_hue := 1.0
var rim_scale := 1.0
var lift_scale := 1.0
var relief_scale := 1.0
var taps := 16
var camera: Camera3D
## The clouds' resolved shape texture (x is the cloud's opacity), or null.
var cloud_shape: Texture2D
var _rd: RenderingDevice
var _shader := RID()
var _pipeline := RID()
var _buffer := RID()
var _flat := RID()
var _nearest := RID()
var _params := PackedFloat32Array()
var _mood := {}
var _haze := Vector3(120.0,7600.0,0.75)
var _ready_flag := false

static func wanted() -> bool:
	return "--post=1" in LaunchArgs.user_args() and RenderingServer.get_rendering_device() != null

## The tuning of mood `id`.
static func tuning(id: String) -> Dictionary:
	var t: Dictionary = DEFAULT.duplicate()
	t.merge(MOODS.get(id,{}),true)
	return t

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_depth = true
	access_resolved_color = true
	needs_motion_vectors = false
	_rd = RenderingServer.get_rendering_device()
	_params.resize(FLOATS)
	_mood = tuning("")
	if _rd != null: RenderingServer.call_on_render_thread(_allocate)

func _allocate() -> void:
	var spirv: RDShaderSPIRV = preload("res://shaders/endless_post.glsl").get_spirv()
	if not spirv.compile_error_compute.is_empty():
		push_error("endless post: "+spirv.compile_error_compute)
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	_pipeline = _rd.compute_pipeline_create(_shader)
	_buffer = _rd.storage_buffer_create(FLOATS*4)
	_nearest = _rd.sampler_create(RDSamplerState.new())
	var flat := RDTextureFormat.new()
	flat.width = 1
	flat.height = 1
	flat.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	flat.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	_flat = _rd.texture_create(flat,RDTextureView.new(),[PackedFloat32Array([0.0,0.0]).to_byte_array()])
	_ready_flag = true

func setup(look: Node3D, haze: Vector3) -> void:
	_haze = haze
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--rays="): rays_scale = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--grade="): grade_scale = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--air="): air_scale = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--haze-hue="): haze_hue = clampf(a.get_slice("=",1).to_float(),0.0,1.0)
		elif a.begins_with("--lift="): lift_scale = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--relief="): relief_scale = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--rim="): rim_scale = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--rays-taps="): taps = clampi(int(a.get_slice("=",1)),4,64)
	set_mood(look.mood)

func set_mood(id: String) -> void:
	_mood = tuning(id)

## A tuning made by hand (EndlessLook.blend_moods: moods blended by weight).
func set_tuning(t: Dictionary) -> void:
	_mood = t

static func _put4(p: PackedFloat32Array, at: int, v: Vector4) -> void:
	p[at] = v.x
	p[at+1] = v.y
	p[at+2] = v.z
	p[at+3] = v.w

## One frame, on the main thread: the view, the sun and the colours the
## shader reads (`look` is the EndlessLook, for the horizon's colour).
func step(view: Camera3D, look: Node3D, facing: Vector3) -> void:
	if view == null: return
	if view != camera:
		_detach()
		camera = view
		_attach()
	var p := _params
	var window := view.get_window()
	var aspect := 16.0/9.0
	var size := Vector2(1280,720)
	if view.get_viewport() != null: size = view.get_viewport().get_visible_rect().size
	if window != null and window.size.y > 0: aspect = float(window.size.x)/window.size.y
	var tan_y := tan(deg_to_rad(view.fov)*0.5)
	var tan_x := tan_y*aspect
	if view.keep_aspect == Camera3D.KEEP_WIDTH:
		tan_x = tan_y
		tan_y = tan_x/aspect
	var xf := view.global_transform
	var st: Dictionary = look.celestial.state
	var sun: Vector3 = st.zs_sun_direction
	var flat := Vector2(sun.x,sun.z)
	flat = flat.normalized() if flat.length() > 1e-4 else Vector2.RIGHT
	_put4(p,0,Vector4(tan_x,tan_y,view.near,view.far))
	_put4(p,4,Vector4(xf.basis.x.x,xf.basis.x.y,xf.basis.x.z,0.0))
	_put4(p,8,Vector4(xf.basis.y.x,xf.basis.y.y,xf.basis.y.z,0.0))
	_put4(p,12,Vector4(xf.basis.z.x,xf.basis.z.y,xf.basis.z.z,0.0))
	_put4(p,16,Vector4(sun.x,sun.y,flat.x,flat.y))
	_put4(p,20,Vector4(_haze.x,_haze.y,_haze.z,1.0))
	var hz: Color = look.horizon(facing)
	_put4(p,24,Vector4(hz.r,hz.g,hz.b,haze_hue))
	_put4(p,28,Vector4(float(_mood.air)*air_scale,5200.0,float(_mood.airpow),0.0))
	_put4(p,32,Vector4(0.62,0.78,1.25,0.0))
	_put4(p,36,Vector4(1.35,1.05,0.72,0.0))
	_put4(p,40,Vector4(float(_mood.split)*grade_scale,1.0+(float(_mood.contrast)-1.0)*grade_scale,1.0+(float(_mood.sat)-1.0)*grade_scale,float(_mood.lift)*lift_scale*grade_scale))
	var sh: Vector3 = _mood.shade
	var li: Vector3 = _mood.light
	_put4(p,44,Vector4(sh.x,sh.y,sh.z,float(_mood.relief)*relief_scale))
	_put4(p,48,Vector4(li.x,li.y,li.z,float(_mood.hot)*relief_scale))
	_put4(p,52,Vector4(0.05,0.9,float(_mood.rim)*rim_scale,5.0))
	# The sun on screen and the shafts' strength.
	var strength := 0.0
	var screen := Vector2(0.5,0.5)
	var fwd := -xf.basis.z
	var toward := fwd.dot(sun)
	if rays_scale > 0.0 and float(_mood.rays) > 0.0 and sun.y > -0.04 and toward > 0.05:
		screen = view.unproject_position(xf.origin+sun*400.0)/size
		strength = float(_mood.rays)*rays_scale*smoothstep(-0.04,0.12,sun.y)*smoothstep(0.05,0.4,toward)
	_put4(p,56,Vector4(screen.x,screen.y,strength,0.9))
	var c: Vector3 = st.zs_cloud_sun
	c = c/maxf(maxf(c.x,c.y),maxf(c.z,0.001))*0.9
	_put4(p,60,Vector4(c.x,c.y,c.z,0.08))
	_put4(p,64,Vector4(aspect,size.x,size.y,float(taps)))
	# The horizon's colour by the angle to the sun: the LUT's t runs from
	# facing away (0) to toward it (1).
	for i in LUT:
		var t := float(i)/float(LUT-1)
		var a := acos(clampf(t*2.0-1.0,-1.0,1.0))
		var dir := flat.rotated(a)
		var col: Color = look.horizon(Vector3(dir.x,0.0,dir.y))
		_put4(p,68+i*4,Vector4(col.r,col.g,col.b,0.0))

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

func _render_callback(_type: int, data: RenderData) -> void:
	if not _ready_flag or not _pipeline.is_valid(): return
	var buffers: RenderSceneBuffersRD = data.get_render_scene_buffers()
	if buffers == null or buffers.get_internal_size() == Vector2i.ZERO: return
	var depth := buffers.get_depth_layer(0,false)
	var color := buffers.get_color_layer(0,false)
	if not depth.is_valid() or not color.is_valid(): return
	var bytes := _params.to_byte_array()
	_rd.buffer_update(_buffer,0,bytes.size(),bytes)
	var shape := RID()
	if cloud_shape != null: shape = RenderingServer.texture_get_rd_texture(cloud_shape.get_rid())
	var u0 := RDUniform.new()
	u0.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u0.binding = 0
	u0.add_id(_buffer)
	var u1 := RDUniform.new()
	u1.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u1.binding = 1
	u1.add_id(_nearest)
	u1.add_id(depth)
	var u2 := RDUniform.new()
	u2.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u2.binding = 2
	u2.add_id(_nearest)
	u2.add_id(shape if shape.is_valid() and _rd.texture_is_valid(shape) else _flat)
	var u3 := RDUniform.new()
	u3.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u3.binding = 3
	u3.add_id(color)
	var set := UniformSetCacheRD.get_cache(_shader,0,[u0,u1,u2,u3])
	var size := buffers.get_internal_size()
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_pipeline)
	_rd.compute_list_bind_uniform_set(list,set,0)
	_rd.compute_list_dispatch(list,ceili(size.x/8.0),ceili(size.y/8.0),1)
	_rd.compute_list_end()

func free_buffers() -> void:
	_detach()
	if _rd == null: return
	RenderingServer.call_on_render_thread(_free)

func _free() -> void:
	for rid: RID in [_pipeline,_shader,_buffer,_flat,_nearest]:
		if rid.is_valid(): _rd.free_rid(rid)
