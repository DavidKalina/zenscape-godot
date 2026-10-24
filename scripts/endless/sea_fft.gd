extends CompositorEffect
## The sea's FFT cascades (on unless --sea-fft=0; docs/design/endless-flight/sea-fft-handoff.md):
## the wind sea and its chop as Tessendorf waves, CASCADES tiles of N^2,
## each holding its own band of a JONSWAP spectrum (the wind's speed and
## fetch, spread round the wind), moved on by deep-water dispersion and
## turned into heights, shoves and slopes by an inverse FFT on the GPU each
## frame. The sea shader (shaders/endless_sea.gdshader, sea_fft 1) samples
## `texture` (a 2D array, 2*CASCADES layers with mips; layout in
## shaders/sea_fft_unpack.glsl) at world xz / the cascade's size.
##
## Passes (all compute, as the drawing camera's compositor effect before the
## opaque pass, put ahead of the foam's so the foam can read the folds):
##   spectrum  h0(k), when built or a knob changes (shaders/sea_fft_spectrum.glsl)
##   evolve    h(k, t) into four packed spectra a cascade (sea_fft_evolve.glsl)
##   fft       rows then columns, Stockham in shared memory (sea_fft_fft.glsl)
##   unpack    into the maps' mip 0 (sea_fft_unpack.glsl)
##   mips      a 2x2 mean a level (sea_fft_mips.glsl)
## Every read of something written earlier goes through a storage buffer or
## imageLoad, never texture() (sampling what a pass wrote hung Metal in the
## foam round, water-handoff.md). Without a rendering device (headless)
## `ready()` is false and the sea keeps its Gerstner wind sea and noise chop.
##
## Knobs: --sea-fft-set=name:value;name:value (values through str_to_var):
##   wind    m/s of wind (default: the look's wind strength x WIND_SPEED)
##   fetch   m of open water the wind has blown over (longer: longer, taller waves)
##   sizes   Vector3, each cascade's tile in m
##   chop    how far the shove pulls points into the crests (0 round crests)
##   spread  how tightly the waves follow the wind (cos(theta/2)^(2 spread))
##   gamma   JONSWAP peak sharpness
##   short   m: waves near this length and shorter are damped
##   long    m: no waves longer than this (0 keeps all the tile holds)
##   scale   height scale over the spectrum's
##   seed    the random phases

const N := 256
const CASCADES := 3
const MIPS := 9
## A band edge between two cascades: waves longer than the finer tile / CUT
## go to the coarser one.
const CUT := 6.0
## m/s of wind per unit of the look's wind strength (EndlessLook WIND 0.75 -> 10 m/s).
const WIND_SPEED := 13.3
const FLOATS := 20
const GRAVITY := 9.81
## RenderingDevice TEXTURE_SLICE_2D_ARRAY (every layer of one mip), which
## the engine has but does not name to scripts.
const SLICE_2D_ARRAY := 3 as RenderingDevice.TextureSliceType

var texture := Texture2DArrayRD.new()
var camera: Camera3D
## The knobs (see the header); `set_knob` marks the spectrum to be built again.
var knobs := {"wind":10.0,"fetch":30000.0,"sizes":Vector3(250.0,37.0,5.7),"chop":1.6,"spread":5.0,"gamma":3.3,"short":0.012,"long":0.0,"scale":1.0,"seed":1}
## The wind's heading (world xz).
var heading := Vector2(1.0,0.0)
## Per cascade: the height's standard deviation (m) and the slope variance
## (both directions together) its spectrum holds, from `stats()`.
var height_sigma := Vector3.ZERO
var slope_var := Vector3.ZERO
## Each cascade's band as wavelengths (m): longest (x of `band_long`) to
## shortest (`band_short`).
var band_long := Vector3.ZERO
var band_short := Vector3.ZERO
## --sea-fft-time: GPU timestamps round the passes; `gpu_ms` the last read.
var timing := false
var gpu_ms := 0.0

var _rd: RenderingDevice
var _shaders := {}
var _pipelines := {}
var _params := RID()
var _h0 := RID()
var _buffers: Array[RID] = [RID(),RID()]
var _maps := RID()
var _mip_views: Array[RID] = []
var _sets := {}
var _mip_sets: Array[RID] = []
var _bytes := PackedByteArray()
var _pending := false
var _dirty := true
var _time := 0.0
var _norm := 1.0

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_OPAQUE
	needs_motion_vectors = false
	_rd = RenderingServer.get_rendering_device()
	if _rd == null: return # Headless: no rendering device.
	RenderingServer.call_on_render_thread(_allocate)

func ready() -> bool:
	return _rd != null

func _compile(name: String) -> bool:
	var file: RDShaderFile = load("res://shaders/sea_fft_%s.glsl" % name)
	var spirv := file.get_spirv()
	if not spirv.compile_error_compute.is_empty():
		push_error("sea fft %s: %s" % [name,spirv.compile_error_compute])
		return false
	_shaders[name] = _rd.shader_create_from_spirv(spirv)
	_pipelines[name] = _rd.compute_pipeline_create(_shaders[name])
	return true

func _image(binding: int, rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(rid)
	return u

func _buffer(binding: int, rid: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = binding
	u.add_id(rid)
	return u

func _allocate() -> void:
	for name: String in ["spectrum","evolve","fft","unpack","mips"]:
		if not _compile(name):
			_rd = null
			return
	_params = _rd.storage_buffer_create(FLOATS*4)
	var h0 := RDTextureFormat.new()
	h0.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY
	h0.width = N
	h0.height = N
	h0.array_layers = CASCADES
	h0.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	h0.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	_h0 = _rd.texture_create(h0,RDTextureView.new())
	var bytes := CASCADES*4*N*N*8
	for i in 2: _buffers[i] = _rd.storage_buffer_create(bytes)
	var maps := RDTextureFormat.new()
	maps.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY
	maps.width = N
	maps.height = N
	maps.array_layers = CASCADES*2
	maps.mipmaps = MIPS
	maps.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	maps.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	_maps = _rd.texture_create(maps,RDTextureView.new())
	_rd.texture_clear(_maps,Color(0,0,0,0),0,MIPS,0,CASCADES*2)
	for m in MIPS:
		_mip_views.append(_rd.texture_create_shared_from_slice(RDTextureView.new(),_maps,0,m,1,SLICE_2D_ARRAY))
	_sets.spectrum = _rd.uniform_set_create([_buffer(0,_params),_image(1,_h0)],_shaders.spectrum,0)
	_sets.evolve = _rd.uniform_set_create([_buffer(0,_params),_image(1,_h0),_buffer(2,_buffers[0])],_shaders.evolve,0)
	_sets.fft_ab = _rd.uniform_set_create([_buffer(0,_buffers[0]),_buffer(1,_buffers[1])],_shaders.fft,0)
	_sets.fft_ba = _rd.uniform_set_create([_buffer(0,_buffers[1]),_buffer(1,_buffers[0])],_shaders.fft,0)
	_sets.unpack = _rd.uniform_set_create([_buffer(0,_buffers[0]),_image(1,_mip_views[0])],_shaders.unpack,0)
	for m in range(1,MIPS):
		_mip_sets.append(_rd.uniform_set_create([_image(0,_mip_views[m-1]),_image(1,_mip_views[m])],_shaders.mips,0))
	texture.texture_rd_rid = _maps

## Mip `m`'s view of the maps (all layers), for another pass to imageLoad
## (the foam reads the folds; RID() before the maps exist).
func mip_view(m: int) -> RID:
	return _mip_views[m] if m < _mip_views.size() else RID()

## Sets a knob (see the header); the spectrum is built again next frame.
func set_knob(name: String, value: Variant) -> void:
	knobs[name] = value
	_dirty = true
	stats()

## The wind sea's heading (radians) and strength (the look's 0..2 scale).
func set_wind(angle: float, strength: float, keep_speed := false) -> void:
	heading = Vector2(cos(angle),sin(angle))
	if not keep_speed: knobs.wind = strength*WIND_SPEED
	_dirty = true
	stats()

## Takes --sea-fft-set=name:value;name:value from `args`.
func read_args(args: PackedStringArray) -> bool:
	var wind_set := false
	for a: String in args:
		if not a.begins_with("--sea-fft-set="): continue
		for pair in a.get_slice("=",1).split(";"):
			var kv := pair.split(":")
			if kv.size() != 2 or not knobs.has(kv[0]): continue
			var v: Variant = str_to_var(kv[1])
			if typeof(knobs[kv[0]]) == TYPE_FLOAT and (v is int): v = float(v)
			knobs[kv[0]] = v
			if kv[0] == "wind": wind_set = true
	_dirty = true
	stats()
	return wind_set

func _sizes() -> Vector3:
	return knobs.sizes

## The band edges (k): 0|1, 1|2.
func _cuts() -> Vector2:
	var s := _sizes()
	return Vector2(TAU/s.y*CUT,TAU/s.z*CUT)

## The spread's normaliser: 1 / the integral of cos(theta/2)^(2s) round the circle.
func _spread_norm() -> float:
	var s := float(knobs.spread)
	var sum := 0.0
	var steps := 720
	for i in steps:
		var th := -PI+(i+0.5)*TAU/steps
		sum += pow(absf(cos(th*0.5)),2.0*s)
	return 1.0/(sum*TAU/steps)

## S(omega) JONSWAP (m^2 s), as the spectrum pass has it.
func _jonswap(omega: float) -> float:
	var u := maxf(float(knobs.wind),0.5)
	var f := maxf(float(knobs.fetch),100.0)
	var alpha := 0.076*pow(u*u/(f*GRAVITY),0.22)
	var wp := 22.0*pow(GRAVITY*GRAVITY/(u*f),1.0/3.0)
	var sigma := 0.07 if omega <= wp else 0.09
	var r := exp(-(omega-wp)*(omega-wp)/(2.0*sigma*sigma*wp*wp))
	return alpha*GRAVITY*GRAVITY/pow(omega,5.0)*exp(-1.25*pow(wp/omega,4.0))*pow(float(knobs.gamma),r)

## Works out each cascade's band, height sigma and slope variance from the
## spectrum (a 1D integral over its band; the spread integrates to 1).
func stats() -> void:
	_norm = _spread_norm()
	var s := _sizes()
	var cuts := _cuts()
	var sc := float(knobs.scale)
	var short := float(knobs.short)
	var long_k := TAU/float(knobs.long) if float(knobs.long) > 0.0 else 0.0
	for c in CASCADES:
		var lo := TAU/s[c]
		lo = maxf(lo,[0.0,cuts.x,cuts.y][c])
		lo = maxf(lo,long_k)
		var hi := PI*N/s[c]
		if c < 2: hi = minf(hi,cuts[c])
		band_long[c] = TAU/lo
		band_short[c] = TAU/hi
		var h2 := 0.0
		var s2 := 0.0
		var steps := 400
		var a := log(lo)
		var b := log(hi)
		for i in steps:
			var k := exp(a+(i+0.5)*(b-a)/steps)
			var dk := k*(b-a)/steps
			var omega := sqrt(GRAVITY*k)
			var e := _jonswap(omega)*GRAVITY/(2.0*omega)*exp(-k*k*short*short)*dk
			h2 += e
			s2 += e*k*k
		height_sigma[c] = sqrt(h2)*sc
		slope_var[c] = s2*sc*sc

## One frame: the sea's clock (zs_flow_time) and the camera that draws.
func step(time: float, view: Camera3D) -> void:
	if view != null and view.is_inside_tree():
		var drawing := view.get_viewport().get_camera_3d()
		if drawing != null: view = drawing
	if view != camera:
		_detach()
		camera = view
		_attach()
	_time = time
	if _rd == null: return
	var s := _sizes()
	var cuts := _cuts()
	var p := PackedFloat32Array([
		s.x,s.y,s.z,float(knobs.seed),
		heading.x,heading.y,float(knobs.wind),float(knobs.fetch),
		float(knobs.gamma),float(knobs.spread),_norm,float(knobs.short),
		cuts.x,cuts.y,TAU/float(knobs.long) if float(knobs.long) > 0.0 else 0.0,float(knobs.scale),
		time,float(knobs.chop),0.0,0.0])
	_bytes = p.to_byte_array()
	_pending = true
	if timing: _read_timing()

func _attach() -> void:
	if camera == null or _rd == null: return
	var compositor := camera.compositor
	if compositor == null:
		compositor = Compositor.new()
		camera.compositor = compositor
	var effects := compositor.compositor_effects
	if not effects.has(self):
		# Ahead of the foam's pass, which reads the folds.
		effects.insert(0,self)
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
	if _rd == null or not _sets.has("unpack"): return
	var bytes := _bytes
	_rd.buffer_update(_params,0,bytes.size(),bytes)
	if timing: _rd.capture_timestamp("sea fft begin")
	var list := _rd.compute_list_begin()
	if _dirty:
		_dirty = false
		_rd.compute_list_bind_compute_pipeline(list,_pipelines.spectrum)
		_rd.compute_list_bind_uniform_set(list,_sets.spectrum,0)
		_rd.compute_list_dispatch(list,N/8,N/8,CASCADES)
		_rd.compute_list_add_barrier(list)
	_rd.compute_list_bind_compute_pipeline(list,_pipelines.evolve)
	_rd.compute_list_bind_uniform_set(list,_sets.evolve,0)
	_rd.compute_list_dispatch(list,N/8,N/8,CASCADES)
	_rd.compute_list_add_barrier(list)
	_rd.compute_list_bind_compute_pipeline(list,_pipelines.fft)
	_rd.compute_list_bind_uniform_set(list,_sets.fft_ab,0)
	_rd.compute_list_dispatch(list,N,CASCADES*4,1)
	_rd.compute_list_add_barrier(list)
	_rd.compute_list_bind_uniform_set(list,_sets.fft_ba,0)
	_rd.compute_list_dispatch(list,N,CASCADES*4,1)
	_rd.compute_list_add_barrier(list)
	_rd.compute_list_bind_compute_pipeline(list,_pipelines.unpack)
	_rd.compute_list_bind_uniform_set(list,_sets.unpack,0)
	_rd.compute_list_dispatch(list,N/8,N/8,CASCADES)
	_rd.compute_list_bind_compute_pipeline(list,_pipelines.mips)
	var size := N
	for m in _mip_sets.size():
		_rd.compute_list_add_barrier(list)
		size = maxi(size/2,1)
		_rd.compute_list_bind_uniform_set(list,_mip_sets[m],0)
		var groups := maxi((size+7)/8,1)
		_rd.compute_list_dispatch(list,groups,groups,CASCADES*2)
	_rd.compute_list_end()
	if timing: _rd.capture_timestamp("sea fft end")

## The last finished frame's GPU time between the two timestamps (ms).
func _read_timing() -> void:
	var count := _rd.get_captured_timestamps_count()
	var begin := -1
	for i in count:
		var name := _rd.get_captured_timestamp_name(i)
		if name == "sea fft begin": begin = i
		elif name == "sea fft end" and begin >= 0:
			gpu_ms = float(_rd.get_captured_timestamp_gpu_time(i)-_rd.get_captured_timestamp_gpu_time(begin))/1.0e6
			return

func free_buffers() -> void:
	_detach()
	if _rd == null: return
	RenderingServer.call_on_render_thread(_free)

func _free() -> void:
	texture.texture_rd_rid = RID()
	var rids: Array[RID] = []
	for s: RID in _mip_sets: rids.append(s)
	for k: String in _sets: rids.append(_sets[k])
	for v: RID in _mip_views: rids.append(v)
	rids.append_array([_maps,_buffers[0],_buffers[1],_h0,_params])
	for k: String in _pipelines: rids.append(_pipelines[k])
	for k: String in _shaders: rids.append(_shaders[k])
	for rid: RID in rids:
		if rid.is_valid(): _rd.free_rid(rid)
	_mip_sets.clear()
	_sets.clear()
	_mip_views.clear()
