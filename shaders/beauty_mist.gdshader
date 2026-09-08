shader_type fog;
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_growth.gdshaderinc"
uniform sampler2D ground_map : filter_nearest, repeat_disable;
uniform sampler2D stream_map : filter_nearest, repeat_disable;
uniform float density = 0.145;
void fog() {
    vec3 p = WORLD_POSITION;
    vec2 uv = (p.xz + 16.0) / 32.0;
    float ground = zs_surface_height(texture(ground_map, uv), texture(stream_map, uv));
    float height = p.y - ground;
    float edge = 1.0 - smoothstep(9.0, 13.0, length(p.xz));
    vec3 drift = vec3(zs_wind_offset.x, 0.0, zs_wind_offset.y) * 0.03;
    float patches = smoothstep(0.28, 0.72, wxFbm(p * vec3(0.23, 0.35, 0.23) - drift));
    float passing_air = zs_gust_pulse_at(p.xz, zs_gust_distance);
    patches *= 1.0 - 0.35 * clamp(passing_air, 0.0, 1.0);
    float pool = exp(-max(height, 0.0) * 0.8);
    DENSITY = ground < -100.0 || height < -0.15 ? 0.0 : edge * density * exp(-max(p.y - 2.0, 0.0) * 0.38) * (0.055 + pool * patches);
    ALBEDO = vec3(0.85, 0.91, 0.96);
    EMISSION = vec3(0.0);
}
