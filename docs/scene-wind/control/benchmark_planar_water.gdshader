shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;
// The sampled bed already contains native fog; avoid applying it twice.
#include "res://shaders/reference_display.gdshaderinc"
uniform sampler2D planar_reflection : filter_linear, repeat_disable;
uniform mat4 reflection_matrix;
uniform float reflection_strength = 1.0;
uniform sampler2D screen_color : hint_screen_texture, filter_linear_mipmap;
varying vec3 world_position;
varying float water_depth;
void vertex() {
    water_depth = UV2.x;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec3 p = world_position;
    vec3 normal = normalize(vec3(0.012*cos(p.x*2.2 + zs_flow_time*0.65),1.0,0.014*cos(p.z*2.7-zs_flow_time*0.75)));
    vec4 projected = reflection_matrix * vec4(p,1.0);
    vec2 uv = projected.xy / projected.w * vec2(0.5,-0.5) + 0.5;
    uv += normal.xz * 0.12 * smoothstep(0.0,0.3,water_depth);
    vec3 reflected = scene_linear_for_display(texture(planar_reflection,clamp(uv,vec2(0.001),vec2(0.999))).rgb);
    vec3 bed = textureLod(screen_color, SCREEN_UV,0.0).rgb;
    vec3 absorption = exp(-vec3(2.0,0.7,0.45) * water_depth);
    vec3 body = bed * absorption + vec3(0.012,0.075,0.068)*(1.0-absorption);
    float grazing = 1.0 - max(dot(normal,normalize(CAMERA_POSITION_WORLD-p)),0.0);
    float fresnel = 0.16 + 0.72*pow(grazing,3.0);
    float shore = smoothstep(0.0,0.16,water_depth);
    ALBEDO = mix(bed,mix(body,reflected,fresnel * reflection_strength),shore);
    ALPHA = 1.0;
}
