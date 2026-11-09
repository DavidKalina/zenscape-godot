shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// The disturbed pool at the foot of the waterfall (study:
// studies/waterfall_study.tscn): foam rings broken by noise, spreading from
// the fall's footprint and fading within a few metres. A flat plane just
// above the pool's surface; `local` x is across the fall, z out from the wall.
uniform float half_width = 13.0;
uniform float front_z = 4.0;
// How far the ring disturbance reaches from the fall (m).
uniform float reach : hint_range(1.0, 14.0) = 6.0;
varying vec3 v_world;
void vertex() { v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float h21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 p = v_world.xz;
	// Distance from the footprint (a rect hugging the wall, wall to front_z).
	vec2 d = vec2(max(abs(p.x) - half_width, 0.0), max(p.y - front_z, 0.0));
	float dist = length(d);
	float fade = 1.0 - smoothstep(0.0, reach, dist);
	float wob = vn(p * 0.7 + vec2(0.0, -TIME * 0.3)) * 1.6;
	float ring = 0.5 + 0.5 * sin((dist + wob) * 2.6 - TIME * 2.2);
	ring = smoothstep(0.55, 0.95, ring);
	float brk = smoothstep(0.35, 0.7, vn(p * 1.3 + vec2(TIME * 0.2, 0.0)));
	float foam = clamp(ring * brk * fade + (1.0 - smoothstep(0.0, 1.8, dist)) * (0.5 + 0.5 * vn(p * 2.0 + vec2(0.0, -TIME * 2.0))), 0.0, 1.0);
	ALBEDO = vec3(0.95, 0.98, 1.0);
	ALPHA = foam * 0.9;
}
