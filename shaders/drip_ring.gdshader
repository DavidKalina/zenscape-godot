shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
 float radius = length(UV * 2.0 - 1.0);
 float line = smoothstep(0.86, 0.92, radius) * (1.0-smoothstep(0.95, 1.0, radius));
 ALBEDO = vec3(0.65,0.84,0.86);
 ALPHA = line * tint.a * 0.48;
}
