shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;
// The sampled bed already contains native fog; avoid applying it twice.
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_water_gust.gdshaderinc"
#include "res://shaders/pool_caustics.gdshaderinc"
uniform bool salt_pool = false;
uniform bool hide_pool_surface = false;
uniform sampler2D planar_reflection : filter_linear, repeat_disable;
uniform mat4 reflection_matrix;
uniform float reflection_strength = 1.0;
uniform sampler2D screen_color : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform float caustics_strength = 0.0;
varying vec3 world_position;
varying float water_depth;
void vertex() {
    water_depth = UV2.x;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    if (hide_pool_surface) discard;
    vec3 p = world_position;
    vec3 normal = normalize(vec3(0.012*cos(p.x*2.2 + zs_flow_time*0.65),1.0,0.014*cos(p.z*2.7-zs_flow_time*0.75)));
    normal = zs_water_gust_normal(normal, p, water_depth);
    vec4 projected = reflection_matrix * vec4(p,1.0);
    vec2 uv = projected.xy / projected.w * vec2(0.5,-0.5) + 0.5;
    uv += normal.xz * 0.12 * smoothstep(0.0,0.3,water_depth);
    vec3 reflected = scene_linear_for_display(texture(planar_reflection,clamp(uv,vec2(0.001),vec2(0.999))).rgb);
    vec3 bed = textureLod(screen_color, SCREEN_UV,0.0).rgb;
    vec3 lit_bed = bed;
    if (caustics_strength > 0.0) {
        float depth = texture(scene_depth, SCREEN_UV).r;
        vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
        vec3 receiver = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
        float submerged = p.y - receiver.y;
        float shallows = smoothstep(0.04,0.22,submerged) * (1.0-smoothstep(0.8,2.4,submerged));
        float light = zs_pool_caustics(receiver.xz, zs_flow_time) * shallows * caustics_strength * (1.0-zs_ice);
        lit_bed *= 1.0 + vec3(0.95,0.90,0.65) * light;
    }
    vec3 absorption = exp(-vec3(2.0,0.7,0.45) * water_depth);
    vec3 body = lit_bed * absorption + vec3(0.012,0.075,0.068)*(1.0-absorption);
    float grazing = 1.0 - max(dot(normal,normalize(CAMERA_POSITION_WORLD-p)),0.0);
    float fresnel = 0.16 + 0.72*pow(grazing,3.0);
    float shore = smoothstep(0.0,salt_pool ? 0.025 : 0.16,water_depth);
    if (salt_pool) { body = lit_bed; fresnel = 0.60+0.28*pow(grazing,3.0); }
    ALBEDO = mix(bed,mix(body,reflected,fresnel * reflection_strength),shore);
    ALPHA = 1.0;
}
