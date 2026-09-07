extends CompositorEffect
## Copies scene depth and multisample silhouette coverage for the post-tone CanvasLayer atmosphere pass.
## Texture allocation runs before rendering, never inside the effect callback.
var texture := Texture2DRD.new()
var _size := Vector2i.ZERO
var _rd: RenderingDevice
var _shaders: Array[RID] = []
var _pipelines: Array[RID] = []
var _sampler: RID
var _depth: RID

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_depth = true
	_rd = RenderingServer.get_rendering_device()

func resize(size: Vector2i) -> void:
	if size == _size:
		return
	_size = size
	RenderingServer.call_on_render_thread(_allocate.bind(size))

func _allocate(size: Vector2i) -> void:
	if _rd == null:
		return # Headless state tests have no GPU rendering device.
	if _shaders.is_empty():
		var source := RDShaderSource.new()
		var code := """
#version 450
layout(local_size_x=8, local_size_y=8, local_size_z=1) in;
layout(set=0, binding=0) uniform SAMPLER scene_depth;
layout(rg32f, set=0, binding=1) uniform writeonly image2D output_depth;
void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(output_depth);
    if (any(greaterThanEqual(p, size))) return;
    vec2 uv = (vec2(p) + 0.5) / vec2(size);
    READ_DEPTH
    imageStore(output_depth, p, vec4(depth, coverage, 0.0, 0.0));
}
"""
		for msaa in [false, true]:
			var read := "float depth = textureLod(scene_depth, uv, 0.0).r; float coverage = depth > 0.0 ? 1.0 : 0.0;"
			if msaa:
				read = """
    ivec2 source_pixel = ivec2(uv * vec2(textureSize(scene_depth)));
    int samples = textureSamples(scene_depth);
    float depth = 0.0, coverage = 0.0;
    for (int i = 0; i < samples; i++) {
        float d = texelFetch(scene_depth, source_pixel, i).r;
        depth = max(depth, d);
        coverage += d > 0.0 ? 1.0 / float(samples) : 0.0;
    }
"""
			source.source_compute = code.replace("SAMPLER", "sampler2DMS" if msaa else "sampler2D").replace("READ_DEPTH", read)
			var spirv := _rd.shader_compile_spirv_from_source(source)
			if not spirv.compile_error_compute.is_empty():
				push_error(spirv.compile_error_compute)
				return
			var shader := _rd.shader_create_from_spirv(spirv)
			_shaders.append(shader)
			_pipelines.append(_rd.compute_pipeline_create(shader))
		_sampler = _rd.sampler_create(RDSamplerState.new())
	var format := RDTextureFormat.new()
	format.width = size.x
	format.height = size.y
	format.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var previous := _depth
	_depth = _rd.texture_create(format, RDTextureView.new())
	texture.texture_rd_rid = _depth
	if previous.is_valid():
		_rd.free_rid(previous)

func _render_callback(_type: int, data: RenderData) -> void:
	if not _depth.is_valid() or _pipelines.size() != 2:
		return
	var buffers: RenderSceneBuffersRD = data.get_render_scene_buffers()
	if buffers == null or buffers.get_internal_size() == Vector2i.ZERO:
		return
	var variant := 1 if buffers.get_msaa_3d() != RenderingServer.VIEWPORT_MSAA_DISABLED else 0
	var input := RDUniform.new()
	input.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	input.binding = 0
	input.add_id(_sampler)
	input.add_id(buffers.get_depth_layer(0, variant == 1))
	var output := RDUniform.new()
	output.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	output.binding = 1
	output.add_id(_depth)
	var uniforms := UniformSetCacheRD.get_cache(_shaders[variant], 0, [input, output])
	var commands := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(commands, _pipelines[variant])
	_rd.compute_list_bind_uniform_set(commands, uniforms, 0)
	var format := _rd.texture_get_format(_depth)
	_rd.compute_list_dispatch(commands, ceili(format.width / 8.0), ceili(format.height / 8.0), 1)
	_rd.compute_list_end()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null:
		for resource in _shaders + [_sampler, _depth]:
			if resource.is_valid():
				_rd.free_rid(resource)
