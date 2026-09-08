shader_type fog;
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_growth.gdshaderinc"
uniform sampler2D ground_map : filter_nearest, repeat_disable;
uniform sampler2D stream_map : filter_nearest, repeat_disable;
uniform float density = 0.17;
void fog() {
    vec3 p = WORLD_POSITION;
    vec2 uv = (p.xz + 16.0) / 32.0;
    float ground = zs_surface_height(texture(ground_map, uv), texture(stream_map, uv));
    float height = p.y - ground;
    float edge = 1.0 - smoothstep(9.0, 13.0, length(p.xz));
    float patches = smoothstep(0.28, 0.72, wxFbm(p * vec3(0.23, 0.35, 0.23) + vec3(zs_motion_time * 0.025, 0.0, zs_motion_time * 0.012)));
    float pool = exp(-max(height, 0.0) * 0.8);
    DENSITY = ground < -100.0 || height < -0.15 ? 0.0 : edge * density * exp(-max(p.y - 2.0, 0.0) * 0.38) * (0.055 + pool * patches);
    ALBEDO = vec3(0.85, 0.91, 0.96);
    EMISSION = vec3(0.0);
}
