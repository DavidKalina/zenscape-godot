shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// The disturbed pool at the foot of the waterfall (study:
// studies/waterfall_study.tscn): a flat plane just above the pool's surface.
// Next to the churn mound the foam is nearly solid, then it breaks into
// patches and streaks carried out from the fall, thinning within a few
// metres. `v_world` x is across the fall, z out from the wall.
uniform float half_width = 13.0;
// The fall's front at the foot (m out from the wall) and how far its churn
// mound reaches past it: the foam starts there.
uniform float front_z = 5.4;
uniform float mound_reach = 3.4;
// How much wider each side of the fall is at the foot than at the lip (m).
uniform float spread = 2.6;
// How far the foam reaches out past the mound (m).
uniform float reach : hint_range(1.0, 14.0) = 7.0;
// Metres per second the foam drifts out.
uniform float drift : hint_range(0.0, 6.0) = 1.6;
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
	float hw = half_width + spread;
	// Distance out from the mound's edge (a rect hugging the wall).
	vec2 d = vec2(max(abs(p.x) - hw, 0.0), max(p.y - front_z - mound_reach * 0.75, 0.0));
	float dist = length(d);
	// The foam is carried outward: sample it in a frame that moves away.
	float out_c = dist - TIME * drift;
	float along = p.x * 0.6 + (abs(p.x) > hw ? p.y * 0.6 : 0.0);
	float fade = 1.0 - smoothstep(0.0, reach, dist);
	// Patches: two scales, carried out, crisp edged.
	float n1 = vn(vec2(along * 1.6, out_c * 1.4));
	float n2 = vn(vec2(along * 5.0 + 9.0, out_c * 5.0 + TIME * 0.4));
	float patches = smoothstep(0.5, 0.54, n1 * 0.55 + n2 * 0.45 + 0.3 * (1.0 - smoothstep(0.0, reach * 0.5, dist)) - dist * 0.02);
	// Streaks pulled out from the mound.
	float st = smoothstep(0.64, 0.7, vn(vec2(along * 6.0, out_c * 0.6)));
	// Right at the mound: nearly solid, broken by holes; its edge ragged.
	float near = 1.0 - smoothstep(0.0, 0.25, dist - 0.9 * vn(vec2(p.x * 1.3, TIME * 0.7)));
	float holes = smoothstep(0.3, 0.36, vn(p * 3.0 + vec2(0.0, -TIME * 1.5)));
	float foam = max(max(patches, st * 0.8) * fade, near * mix(0.6, 1.0, holes));
	ALBEDO = vec3(0.95, 0.98, 1.0);
	ALPHA = clamp(foam, 0.0, 1.0) * 0.95;
}
