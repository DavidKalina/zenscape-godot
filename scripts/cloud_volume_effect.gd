extends CompositorEffect
## The unified cloud volume's GPU passes (scripts/cloud_volume.gd), run on
## the camera's compositor after the opaque pass and before the
## see-through one. shaders/cloud_volume_march.glsl runs four times: the
## weather map round the eye (`weather`), its ceiling of highest crowns,
## the cloud's shade looking up toward the sun (`shadow`, which the land
## reads next frame through the zs_cloud_shadow global), then the march at
## half the render size each axis (one pixel of each 2x2 block a frame, in
## turn; the whole render on Ultra, `scale` 1). Then the temporal resolve
## (shaders/cloud_volume_resolve.glsl) at the render's full size into
## `resolved_a`/`resolved_b`, kept as next frame's history. The composite (shaders/cloud_volume_composite.gdshader)
## draws them into the scene in the see-through pass, where the near sea
## used to draw, so sorting against waterfalls, puffs and glass is as it was.
##
## Textures are made off the callback (`resize`, on the render thread);
## the inputs' RIDs and the two parameter blocks are handed in by the
## driver every frame before drawing (`set_inputs`, `march_params`,
## `resolve_params`).

## What the composite reads: the resolved light terms and coverage at the
## render's size; and the march's solid distances (probes).
var resolved_a := Texture2DRD.new()
var resolved_b := Texture2DRD.new()
var march_depth := Texture2DRD.new()
## The weather map (crown height, density, base, slope) and the cloud's
## shade on the land (light kept from on high, from the heaps, the shade's
## height), both over the square `weather_at` (march Params) round the eye.
var weather := Texture2DRD.new()
var shadow := Texture2DRD.new()
## The parameter blocks (std430 floats, as the shaders' Params).
var march_params := PackedFloat32Array()
var resolve_params := PackedFloat32Array()
## The inputs: the sea's envelope and swells bakes, the noise volume and up
## to four towers' bodies (invalid RIDs fall back to empty placeholders).
var envelope := RID()
var swells := RID()
var noise := RID()
var bodies: Array[RID] = [RID(), RID(), RID(), RID()]
## The march's size (half the render's each axis), the render's (the
## resolve's), and whether last frame's resolve can be trusted as history.
var size := Vector2i.ZERO
var full_size := Vector2i.ZERO
## 2: the march takes one pixel of each 2x2 block a frame; 1: every pixel.
var scale := 2
## Above 1, the weather map is drawn a slice of rows a frame into a second
## map, round the square the driver asks for when the slice cycle begins,
## and the two swap (and the ceiling is redrawn) when it is whole: the map
## costs 1/weather_slices of a whole draw each frame, and is at most two
## cycles old. 0 or 1: whole, when the driver says it is due (as before).
## The driver's march shader reads the slice's square from SLICE_SQUARE.
var weather_slices := 0
var history_ok := false
## Frames the passes actually ran (tests, probes).
var runs := 0

const MARCH_FLOATS := 16+4*9+4*8+4*4*5+4*4+4*32*2
const RESOLVE_FLOATS := 16+16+4*4
## The weather map's texels a side, its ceiling's (a block is the march
## shader's CEILING_BLOCK texels), and the shade's.
const WEATHER_TEXELS := 1024
const CEILING_TEXELS := WEATHER_TEXELS/32
const SHADOW_TEXELS := 256
## Where in the march's block the driver says whether the weather map (with
## its ceiling) and the shade are redrawn this frame (shadow_at z, w), for
## when a lighter tier draws them less often (CloudVolume WEATHER_EVERY,
## SHADE_EVERY).
const WEATHER_DUE := 178
const SHADE_DUE := 179
## The march block's weather square (corner xz, side, texels), and where the
## sliced weather pass reads the square its slice is drawn round.
const WEATHER_SQUARE := 164
const SLICE_SQUARE := 160
## Sliced, the endless march's block (shaders/endless_cloud_march.glsl):
## the low layer's drift, the high layer's (with whether the high layer has
## its own), the clouds' life clock, and where the march reads how far each
## layer has drifted since the front map was drawn (low xz, high xz). Every
## slice of a cycle is drawn at the drift and clock the cycle began with, so
## each map is one moment, and the march shifts its look-ups by the drift
## since that moment, so the clouds move smoothly between swaps.
const LOW_DRIFT := 36
const HIGH_DRIFT := 74
const HIGH_OWN := 72
const LIFE_CLOCK := 76
const DRIFT_SINCE := 156
## With `layer_phase` (the endless march), where the march reads how far
## within a texel the high layer's samples stand from the low layer's, in the
## map read (xy) and in the slice being drawn (zw). The driver snaps the
## map's corner in the low layer's drifting frame, and the high layer is
## sampled this far off it in its own, so every map samples each layer's
## field at the same points: a fresh map is the last one moved by the drift,
## and the shade on the land no longer jumps as a map swaps in (the grid
## fixed to the world, the clouds' edges slid between its texels as they
## drifted and snapped back at each new map, the shade's edges with them).
const LAYER_PHASE := 152
var layer_phase := false
var _front_phase := Vector2.ZERO
var _back_phase := Vector2.ZERO
## The march shader's passes (its push constant).
enum {PASS_WEATHER, PASS_CEILING, PASS_SHADOW, PASS_MARCH}

var _rd: RenderingDevice
var _march_shader := RID()
var _march_pipeline := RID()
var _resolve_shader := RID()
var _resolve_pipeline := RID()
var _linear := RID()
var _repeat := RID()
var _nearest := RID()
var _flat := RID()
var _empty_body := RID()
var _march_buffer := RID()
var _resolve_buffer := RID()
var _march_a := RID()
var _march_b := RID()
var _depth := RID()
var _resolved_a := RID()
var _resolved_b := RID()
var _history_a := RID()
var _history_b := RID()
var _weather := RID()
var _weather_back := RID()
var _front_square := Vector4.ZERO
var _back_square := Vector4.ZERO
var _slice := 0
## The drifts and clock (low xz, high xz; clock) the front map and the
## cycle being drawn were drawn at.
var _front_drift := Vector4.ZERO
var _back_drift := Vector4.ZERO
var _back_clock := 0.0
## The endless march's weather push (shaders/weather_cloud.glslinc: P.spare[5],
## [6], the map's), held for a slice cycle as the clock is; zeros where no
## driver writes it.
const WEATHER_MAP := 88
var _back_weather := PackedFloat32Array()
var _ceiling := RID()
var _shadow := RID()
var _scratch := RID()
var _fresh := true

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT
	access_resolved_depth = true
	needs_motion_vectors = false
	_rd = RenderingServer.get_rendering_device()
	march_params.resize(MARCH_FLOATS)
	resolve_params.resize(RESOLVE_FLOATS)

## The render's internal size; the march is `march_scale` (2: half each
## axis, 1: whole) of it.
func resize(render_size: Vector2i, march_scale := 2) -> void:
	var whole := render_size.max(Vector2i(16,16))
	if whole == full_size and march_scale == scale: return
	full_size = whole
	scale = march_scale
	size = Vector2i(ceili(whole.x/float(scale)),ceili(whole.y/float(scale)))
	history_ok = false
	RenderingServer.call_on_render_thread(_allocate.bind(size,whole))

func set_inputs(envelope_texture: Texture, swells_texture: Texture, noise_texture: Texture, body_textures: Array) -> void:
	envelope = _rd_of(envelope_texture)
	swells = _rd_of(swells_texture)
	noise = _rd_of(noise_texture)
	for i in range(4):
		bodies[i] = _rd_of(body_textures[i]) if i < body_textures.size() else RID()

static func _rd_of(texture: Texture) -> RID:
	if texture == null: return RID()
	return RenderingServer.texture_get_rd_texture(texture.get_rid())

func ready() -> bool:
	return _march_pipeline.is_valid() and _resolve_pipeline.is_valid() and _resolved_a.is_valid()

func _allocate(want: Vector2i, whole: Vector2i) -> void:
	if _rd == null: return # Headless: no rendering device.
	if not _march_shader.is_valid():
		_march_shader = _compile(preload("res://shaders/cloud_volume_march.glsl"))
		_resolve_shader = _compile(preload("res://shaders/cloud_volume_resolve.glsl"))
		if not _march_shader.is_valid() or not _resolve_shader.is_valid(): return
		_march_pipeline = _rd.compute_pipeline_create(_march_shader)
		_resolve_pipeline = _rd.compute_pipeline_create(_resolve_shader)
		var state := RDSamplerState.new()
		state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
		state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		state.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
		_linear = _rd.sampler_create(state)
		state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
		state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
		state.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
		_repeat = _rd.sampler_create(state)
		_nearest = _rd.sampler_create(RDSamplerState.new())
		_march_buffer = _rd.storage_buffer_create(MARCH_FLOATS*4)
		_resolve_buffer = _rd.storage_buffer_create(RESOLVE_FLOATS*4)
		var flat := RDTextureFormat.new()
		flat.width = 1
		flat.height = 1
		flat.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
		flat.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		_flat = _rd.texture_create(flat,RDTextureView.new(),[PackedFloat32Array([0.0,0.0]).to_byte_array()])
		var empty := RDTextureFormat.new()
		empty.texture_type = RenderingDevice.TEXTURE_TYPE_3D
		empty.width = 1
		empty.height = 1
		empty.depth = 1
		empty.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
		empty.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		_empty_body = _rd.texture_create(empty,RDTextureView.new(),[PackedFloat32Array([1000.0,1000.0]).to_byte_array()])
		_weather = _target(Vector2i(WEATHER_TEXELS,WEATHER_TEXELS),RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
		if weather_slices > 1: _weather_back = _target(Vector2i(WEATHER_TEXELS,WEATHER_TEXELS),RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
		_ceiling = _target(Vector2i(CEILING_TEXELS,CEILING_TEXELS),RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
		_shadow = _target(Vector2i(SHADOW_TEXELS,SHADOW_TEXELS),RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
		# Stands in for whichever of those a pass does not write.
		_scratch = _target(Vector2i(1,1),RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
		_rd.texture_clear(_shadow,Color(1.0,1.0,0.0,0.0),0,1,0,1)
		weather.texture_rd_rid = _weather
		shadow.texture_rd_rid = _shadow
	# The new targets are made and the textures repointed to them before
	# the old ones go. Repointing a Texture2DRD replaces its server texture
	# in place (the same RID), so the composite's material, which holds that
	# RID from when `cloud_light` was set (scripts/cloud_volume.gd), reads
	# the new target. Never blank it (texture_rd_rid = RID()) here: that
	# frees the server texture, the next repoint makes a new RID the
	# material never hears of, and the composite samples a dead texture,
	# washing the whole view out to fog over the land (the title's grey
	# murk of 2026-10-11; the round 5 resize fix 4f3c9ed6). Replacing the
	# server texture can free the old target with it, so an old one is
	# freed here only if it still stands (no 'free invalid ID').
	var old := [_march_a,_march_b,_depth,_resolved_a,_resolved_b,_history_a,_history_b]
	_march_a = _target(want,RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	_march_b = _target(want,RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	_depth = _target(want,RenderingDevice.DATA_FORMAT_R32_SFLOAT)
	_resolved_a = _target(whole,RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	_resolved_b = _target(whole,RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	_history_a = _target(whole,RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	_history_b = _target(whole,RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT)
	resolved_a.texture_rd_rid = _resolved_a
	resolved_b.texture_rd_rid = _resolved_b
	march_depth.texture_rd_rid = _depth
	for rid: RID in old:
		if rid.is_valid() and _rd.texture_is_valid(rid): _rd.free_rid(rid)
	_fresh = true

func _target(want: Vector2i, data_format: int) -> RID:
	var format := RDTextureFormat.new()
	format.width = want.x
	format.height = want.y
	format.format = data_format
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	return _rd.texture_create(format,RDTextureView.new())

func _compile(file: RDShaderFile) -> RID:
	var spirv := file.get_spirv()
	if not spirv.compile_error_compute.is_empty():
		push_error("cloud volume: "+spirv.compile_error_compute)
		return RID()
	return _rd.shader_create_from_spirv(spirv)

func _sampled(binding: int, sampler: RID, texture: RID, fallback: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = binding
	u.add_id(sampler)
	u.add_id(texture if texture.is_valid() and _rd.texture_is_valid(texture) else fallback)
	return u

func _image(binding: int, texture: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(texture)
	return u

func _buffer(binding: int, buffer: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = binding
	u.add_id(buffer)
	return u

func _render_callback(_type: int, data: RenderData) -> void:
	if not ready(): return
	var buffers: RenderSceneBuffersRD = data.get_render_scene_buffers()
	if buffers == null or buffers.get_internal_size() == Vector2i.ZERO: return
	var depth := buffers.get_depth_layer(0,false)
	if not depth.is_valid(): return
	_rd.capture_timestamp("Cloud volume")
	var trust := history_ok and not _fresh
	resolve_params[16+16+3] = 1.0 if trust else 0.0
	var params := march_params
	var sliced := weather_slices > 1
	var swap := false
	var want := Vector4(params[WEATHER_SQUARE],params[WEATHER_SQUARE+1],params[WEATHER_SQUARE+2],params[WEATHER_SQUARE+3])
	var own := params[HIGH_OWN] > 0.5
	var drift_now := Vector4(params[LOW_DRIFT],params[LOW_DRIFT+1],params[HIGH_DRIFT] if own else params[LOW_DRIFT],params[HIGH_DRIFT+1] if own else params[LOW_DRIFT+1])
	if layer_phase and not sliced and (_fresh or march_params[WEATHER_DUE] > 0.5): _front_phase = _phase(drift_now,want)
	if sliced:
		# The square the driver wants now starts the next cycle; the passes
		# read the front map's square, and the slice its own.
		params = march_params.duplicate()
		if _fresh or _front_square == Vector4.ZERO:
			_front_square = want
			_front_drift = drift_now
			_front_phase = _phase(drift_now,want)
			_slice = 0
		else:
			if _slice == 0:
				_back_square = want
				_back_drift = drift_now
				_back_clock = params[LIFE_CLOCK]
				_back_phase = _phase(drift_now,want)
				_back_weather = params.slice(WEATHER_MAP,WEATHER_MAP+8)
			# The weather the map bakes, as the cycle began (one moment, as
			# the drift and clock).
			if _back_weather.size() == 8:
				for i in 8: params[WEATHER_MAP+i] = _back_weather[i]
			swap = _slice == weather_slices-1
			for i in 4:
				params[SLICE_SQUARE+i] = _back_square[i]
				params[WEATHER_SQUARE+i] = _front_square[i]
			params[LOW_DRIFT] = _back_drift.x
			params[LOW_DRIFT+1] = _back_drift.y
			if own:
				params[HIGH_DRIFT] = _back_drift.z
				params[HIGH_DRIFT+1] = _back_drift.w
			params[LIFE_CLOCK] = _back_clock
		for i in 4: params[DRIFT_SINCE+i] = drift_now[i]-_front_drift[i]
		if not _weather_back.is_valid(): sliced = false
	if layer_phase: _put_phase(params)
	_rd.buffer_update(_march_buffer,0,MARCH_FLOATS*4,params.to_byte_array())
	_rd.buffer_update(_resolve_buffer,0,RESOLVE_FLOATS*4,resolve_params.to_byte_array())
	# The weather map, its ceiling, the shade on the land, then the march:
	# each pass writes one target and reads what the ones before it wrote.
	if _fresh or (not sliced and march_params[WEATHER_DUE] > 0.5):
		_pass(PASS_WEATHER,depth,_weather,_flat,_scratch,_scratch,_flat,Vector2i(WEATHER_TEXELS,WEATHER_TEXELS))
		_pass(PASS_CEILING,depth,_scratch,_weather,_scratch,_ceiling,_flat,Vector2i(CEILING_TEXELS,CEILING_TEXELS))
	elif sliced:
		var rows := ceili(WEATHER_TEXELS/float(weather_slices))
		_pass(PASS_WEATHER,depth,_weather_back,_flat,_scratch,_scratch,_flat,Vector2i(WEATHER_TEXELS,rows),_slice*rows)
		_slice = (_slice+1)%weather_slices
		if swap:
			# Next frame's params carry the new front's square (the driver's
			# want); this frame's passes after here read the new map, so the
			# march block is rewritten with its square first.
			var front := _weather
			_weather = _weather_back
			_weather_back = front
			_front_square = _back_square
			_front_drift = _back_drift
			_front_phase = _back_phase
			for i in 4:
				params[WEATHER_SQUARE+i] = _front_square[i]
				params[DRIFT_SINCE+i] = drift_now[i]-_front_drift[i]
			if layer_phase: _put_phase(params)
			_rd.buffer_update(_march_buffer,0,MARCH_FLOATS*4,params.to_byte_array())
			_pass(PASS_CEILING,depth,_scratch,_weather,_scratch,_ceiling,_flat,Vector2i(CEILING_TEXELS,CEILING_TEXELS))
	_rd.capture_timestamp("Cloud weather done")
	if march_params[SHADE_DUE] > 0.5 or _fresh:
		_pass(PASS_SHADOW,depth,_scratch,_weather,_shadow,_scratch,_ceiling,Vector2i(SHADOW_TEXELS,SHADOW_TEXELS))
	_rd.capture_timestamp("Cloud shade done")
	_pass(PASS_MARCH,depth,_scratch,_weather,_scratch,_scratch,_ceiling,size)
	_rd.capture_timestamp("Cloud march done")
	var resolve := UniformSetCacheRD.get_cache(_resolve_shader,0,[
		_buffer(0,_resolve_buffer),
		_sampled(1,_nearest,_march_a,_flat),
		_sampled(2,_nearest,_march_b,_flat),
		_sampled(3,_nearest,_depth,_flat),
		_sampled(4,_nearest,depth,_flat),
		_sampled(5,_linear,_history_a,_flat),
		_sampled(6,_linear,_history_b,_flat),
		_image(7,_resolved_a),
		_image(8,_resolved_b)])
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_resolve_pipeline)
	_rd.compute_list_bind_uniform_set(list,resolve,0)
	_rd.compute_list_dispatch(list,ceili(full_size.x/8.0),ceili(full_size.y/8.0),1)
	_rd.compute_list_end()
	_rd.capture_timestamp("Cloud resolve done")
	var whole := Vector3(full_size.x,full_size.y,1)
	_rd.texture_copy(_resolved_a,_history_a,Vector3.ZERO,Vector3.ZERO,whole,0,0,0,0)
	_rd.texture_copy(_resolved_b,_history_b,Vector3.ZERO,Vector3.ZERO,whole,0,0,0,0)
	_rd.capture_timestamp("Cloud volume done")
	_fresh = false
	history_ok = true
	runs += 1

## How far within a texel of `square` (corner xz, side, texels) the high
## layer's samples stand from the low layer's, for a map drawn at `drift`
## (low xz, high xz).
static func _phase(drift: Vector4, square: Vector4) -> Vector2:
	var texel := square.z/maxf(square.w,1.0)
	return Vector2(fposmod(drift.z-drift.x,texel),fposmod(drift.w-drift.y,texel))

func _put_phase(params: PackedFloat32Array) -> void:
	params[LAYER_PHASE] = _front_phase.x
	params[LAYER_PHASE+1] = _front_phase.y
	params[LAYER_PHASE+2] = _back_phase.x
	params[LAYER_PHASE+3] = _back_phase.y

## One run of the march shader: `mode` its pass, the targets it may write
## (`weather_out`, `shadow_out`, `ceiling_out`; the scratch texel where a
## pass writes none) and the maps it reads (`weather_in`, `ceiling_in`),
## over `texels` threads.
## `first_row` 0 or more: a weather slice from that row, round SLICE_SQUARE.
func _pass(mode: int, depth: RID, weather_out: RID, weather_in: RID, shadow_out: RID, ceiling_out: RID, ceiling_in: RID, texels: Vector2i, first_row := -1) -> void:
	var set := UniformSetCacheRD.get_cache(_march_shader,0,[
		_buffer(0,_march_buffer),
		_sampled(1,_linear,envelope,_flat),
		_sampled(2,_linear,swells,_flat),
		_sampled(3,_repeat,noise,_empty_body),
		_sampled(4,_nearest,depth,_flat),
		_sampled(5,_linear,bodies[0],_empty_body),
		_sampled(6,_linear,bodies[1],_empty_body),
		_sampled(7,_linear,bodies[2],_empty_body),
		_sampled(8,_linear,bodies[3],_empty_body),
		_image(9,_march_a),
		_image(10,_march_b),
		_image(11,_depth),
		_image(12,weather_out),
		_sampled(13,_linear,weather_in,_flat),
		_image(14,shadow_out),
		_image(15,ceiling_out),
		_sampled(16,_linear,ceiling_in,_flat)])
	var push := PackedInt32Array([mode,1 if first_row >= 0 else 0,maxi(first_row,0),0]).to_byte_array()
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list,_march_pipeline)
	_rd.compute_list_bind_uniform_set(list,set,0)
	_rd.compute_list_set_push_constant(list,push,push.size())
	_rd.compute_list_dispatch(list,ceili(texels.x/8.0),ceili(texels.y/8.0),1)
	_rd.compute_list_end()

func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE or _rd == null: return
	resolved_a.texture_rd_rid = RID()
	resolved_b.texture_rd_rid = RID()
	march_depth.texture_rd_rid = RID()
	weather.texture_rd_rid = RID()
	shadow.texture_rd_rid = RID()
	for rid in [_march_a,_march_b,_depth,_resolved_a,_resolved_b,_history_a,_history_b,_weather,_weather_back,_ceiling,_shadow,_scratch,_march_buffer,_resolve_buffer,_flat,_empty_body,_linear,_repeat,_nearest,_march_pipeline,_resolve_pipeline,_march_shader,_resolve_shader]:
		if rid.is_valid(): _rd.free_rid(rid)
