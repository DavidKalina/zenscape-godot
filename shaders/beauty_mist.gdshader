shader_type fog;
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_growth.gdshaderinc"
uniform sampler2D ground_map : filter_nearest, repeat_disable;
uniform sampler2D stream_map : filter_nearest, repeat_disable;
uniform float density = 0.145;
// The wind (scripts/redwood_biome_mist.gd `_blow`): how far the mist has
// drifted downwind (m, in the stretched frame), how much it is drawn out
// along the wind (1 still, less in a wind), and the eased wind strength.
uniform float air_travel = 0.0;
uniform float air_stretch = 1.0;
uniform float air_strength = 0.0;
void fog() {
    vec3 p = WORLD_POSITION;
    vec2 uv = (p.xz + zs_map_half) / (zs_map_half * 2.0);
    float ground = zs_surface_height(texture(ground_map, uv), texture(stream_map, uv));
    float height = p.y - ground;
    float edge = 1.0 - smoothstep(zs_plate_half - 5.0, zs_plate_half - 1.0, length(p.xz));
    // A passing gust (the weather's or the wind tool's) shoves the mist along
    // its way and tears it thin.
    vec2 push;
    float passing_air = clamp(zs_gust_pulse_push(p.xz, zs_gust_distance, push), 0.0, 1.0);
    vec2 air = p.xz - push * 3.0;
    // Drawn in the wind's frame: drifting downwind, and drawn out into
    // streaks along it as the wind rises.
    float along = dot(air, zs_wind_direction) * air_stretch - air_travel;
    float across = dot(air, vec2(-zs_wind_direction.y, zs_wind_direction.x));
    float patches = smoothstep(0.28, 0.72, wxFbm(vec3(across, p.y, along) * vec3(0.23, 0.35, 0.23)));
    patches *= 1.0 - 0.6 * passing_air;
    // A strong wind scours the pooled mist out of the low ground.
    patches *= 1.0 - 0.45 * smoothstep(0.8, 2.5, air_strength);
    // Pooled mist thins over open water, so ponds read clear rather than milky.
    float pool = exp(-max(height, 0.0) * 0.8) * (1.0 - 0.8 * zs_open_water(texture(ground_map, uv), texture(stream_map, uv)));
    DENSITY = ground < -100.0 || height < -0.15 ? 0.0 : edge * density * exp(-max(p.y - 2.0, 0.0) * 0.38) * (0.055 + pool * patches);
    ALBEDO = vec3(0.85, 0.91, 0.96);
    EMISSION = vec3(0.0);
}
