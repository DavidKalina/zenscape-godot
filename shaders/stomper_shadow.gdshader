shader_type spatial;
// The stomper's shadow past the sun's own reach (scripts/endless/stomper_shadow.gd):
// one box over the land behind it, down the sun. A ground point is in shadow if
// its line to the sun meets a capsule of the body: seen down the sun that is a
// point against 2D segments, so it lies right on any ground.
render_mode blend_mul, unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_front, shadows_disabled;

// Per capsule: its ends in the plane across the sun, off `at` (ax, ay, bx, by);
// its radius and how far toward the sun it stands off `at`.
uniform vec4 seg[17];
uniform vec2 cap[17];
uniform vec3 at;
uniform vec3 sun = vec3(0.0, 1.0, 0.0);
uniform vec3 across = vec3(1.0, 0.0, 0.0);
uniform vec3 over = vec3(0.0, 0.0, 1.0);
// What the ground is multiplied by in full shadow.
uniform vec3 tint = vec3(0.5, 0.48, 0.58);
// The penumbra's half width (m).
uniform float soft = 7.0;
// From the eye: where this takes over from the sun's own shadow (m).
uniform vec2 takes_over = vec2(740.0, 880.0);
// The environment's depth fog: begin, end, curve.
uniform vec3 haze = vec3(120.0, 7600.0, 0.75);
// Below the sea it isn't drawn: the water writes no depth.
uniform float sea_y = -40.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

void fragment() {
	float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	v.xyz /= v.w;
	float dist = length(v.xyz);
	vec3 w = (INV_VIEW_MATRIX * vec4(v.xyz, 1.0)).xyz;
	if (z <= 0.0 || w.y < sea_y || dist < takes_over.x) {
		discard;
	}
	vec3 off = w - at;
	vec2 p = vec2(dot(off, across), dot(off, over));
	float toward = dot(off, sun);
	float d = 1e9;
	for (int i = 0; i < 17; i++) {
		if (toward > cap[i].y) {
			continue;
		}
		vec2 pa = p - seg[i].xy;
		vec2 ba = seg[i].zw - seg[i].xy;
		float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
		d = min(d, length(pa - ba * h) - cap[i].x);
	}
	float cover = 1.0 - smoothstep(-soft, soft, d);
	if (cover <= 0.003) {
		discard;
	}
	float air = pow(smoothstep(haze.x, haze.y, dist), haze.z);
	ALBEDO = mix(vec3(1.0), tint, cover * smoothstep(takes_over.x, takes_over.y, dist) * (1.0 - air));
}
