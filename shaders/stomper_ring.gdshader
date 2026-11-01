shader_type spatial;
// The stomper's footfall ring (scripts/endless/stomper_fall.gd): one quad over
// the screen. Each pixel's world point comes off the depth, so the front lies on
// the land as it is, up hills and across valleys. rings[i] = (x, y, z of the
// foot, how far the front has run, m), the run below 0 for none.
// Multiplied on the land, not painted over it: the front is a swell passing under
// the ground, lit on the side it turns to the sun and dark in the trough behind,
// so it can't wash pale, whatever the ground is and however low the eye.
render_mode blend_mul, unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

const int RINGS = 2;
uniform vec4 rings[RINGS];
uniform float reach = 1500.0;
// The front's band (m): the bright lead, then the shaded trough behind it.
uniform float lead = 46.0;
uniform float trough = 62.0;
// What the land is multiplied by: the lead's brightest, the trough's darkest, and
// what the swell's sun side and lee side add to them.
uniform vec3 raised = vec3(2.0, 1.85, 1.6);
uniform vec3 pressed = vec3(0.6, 0.54, 0.46);
uniform float sun_side = 0.6;
global uniform vec3 zs_sun_direction;
// Nearer the eye than this it isn't drawn (m): not on the plane.
uniform vec2 near_fade = vec2(25.0, 90.0);
// The environment's depth fog: begin, end, curve.
uniform vec3 haze = vec3(120.0, 7600.0, 0.75);
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
	float facing = 0.0;
	vec2 sun_flat = normalize(zs_sun_direction.xz + vec2(0.0001, 0.0));
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
		float this_lit = k * smoothstep(-lead, 0.0, u) * (1.0 - smoothstep(0.0, lead, u));
		if (this_lit > lit) {
			// Which way this front's swell leans to the sun here: its outer face
			// looks out from the foot, the trough's wall back at it.
			facing = dot((w.xz - c.xz) / max(r, 1.0), sun_flat);
		}
		lit = max(lit, this_lit);
		dark = max(dark, k * smoothstep(0.0, lead, u) * (1.0 - smoothstep(lead, trough * 1.6, u)));
	}
	lit *= rag * lies;
	dark *= mix(0.6, 1.0, rag) * lies;
	if (max(lit, dark) <= 0.003 || w.y < sea_y) {
		discard;
	}
	float show = smoothstep(near_fade.x, near_fade.y, -v.z);
	show *= 1.0 - pow(smoothstep(haze.x, haze.y, length(v.xyz)), haze.z);
	vec3 m = mix(vec3(1.0), raised, clamp(lit * (1.0 + facing * sun_side), 0.0, 1.5));
	m *= mix(vec3(1.0), pressed, clamp(dark * (1.0 - facing * sun_side * 0.5), 0.0, 1.0));
	ALBEDO = mix(vec3(1.0), m, show);
}
