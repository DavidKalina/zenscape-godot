shader_type spatial;
// The stomper's footfall ring (scripts/endless/stomper_fall.gd): one quad over
// the screen. Each pixel's world point comes off the depth, so the front lies on
// the land as it is, up hills and across valleys. rings[i] = (x, y, z of the
// foot, how far the front has run, m), the run below 0 for none.
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

const int RINGS = 2;
uniform vec4 rings[RINGS];
uniform float reach = 1500.0;
// The front's band (m): the bright lead, then the shaded trough behind it.
uniform float lead = 46.0;
uniform float trough = 120.0;
uniform vec3 light = vec3(0.8, 0.67, 0.5);
uniform vec3 shade = vec3(0.16, 0.12, 0.09);
uniform float strength = 0.6;
// Nearer the eye than this it isn't drawn (m): not on the plane.
uniform vec2 near_fade = vec2(25.0, 90.0);
// Below the sea it isn't drawn: the water writes no depth.
uniform float sea_y = -40.0;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float z = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	if (z <= 0.0) {
		discard;
	}
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, z, 1.0);
	v.xyz /= v.w;
	vec3 w = (INV_VIEW_MATRIX * vec4(v.xyz, 1.0)).xyz;
	float rag = mix(0.5, 1.0, vnoise(w.xz / 54.0));
	// Off the land's face: cliffs and walls would stretch the band up them.
	vec3 flat_n = normalize(cross(dFdx(w), dFdy(w)));
	float lies = smoothstep(0.45, 0.8, abs(flat_n.y));
	float lit = 0.0;
	float dark = 0.0;
	float wobble = (vnoise(w.xz / 70.0) - 0.5) * 34.0 + (vnoise(w.xz / 19.0) - 0.5) * 12.0;
	for (int i = 0; i < RINGS; i++) {
		vec4 c = rings[i];
		if (c.w < 0.0) {
			continue;
		}
		float r = distance(w.xz, c.xz);
		float u = (c.w + wobble - r);
		if (u < -lead || u > trough * 1.6 || r > reach) {
			continue;
		}
		// Up a leg or a tree only so far: it runs along the ground.
		float tall = 1.0 - smoothstep(50.0 + r * 0.55, 90.0 + r * 0.8, abs(w.y - c.y));
		float life = 1.0 - smoothstep(0.35, 1.0, r / reach);
		float k = tall * life * smoothstep(20.0, 90.0, r);
		lit = max(lit, k * smoothstep(-lead, 0.0, u) * (1.0 - smoothstep(0.0, lead, u)));
		dark = max(dark, k * smoothstep(0.0, lead, u) * (1.0 - smoothstep(lead, trough * 1.6, u)));
	}
	float a = max(lit * rag, dark * 0.45) * lies;
	if (a <= 0.003) {
		discard;
	}
	a *= strength * smoothstep(near_fade.x, near_fade.y, -v.z) * step(sea_y, w.y);
	ALBEDO = mix(shade, light, lit / max(lit + dark * 0.45, 0.001));
	ALPHA = clamp(a, 0.0, 1.0);
}
