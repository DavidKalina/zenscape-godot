shader_type spatial;
// The sunk tunnels' raw rock (scripts/endless/land_tunnels.gd `_basalt_material`):
// no lattice, no joints. Tilted strata and water-worn pits from 3D noise, so
// walls, vault and floor run into one another; damp where the rock dips,
// mineral streaks down the walls, silt in the low places, moss near the
// daylight. Vertex colour: r the rock's tone, g the growth. Lit by the
// glows and the mouths only: no sky fill, no haze.
render_mode diffuse_burley, specular_schlick_ggx, ambient_light_disabled, fog_disabled, cull_disabled;

uniform float floor_y = 0.0;
uniform vec3 rock_lo : source_color = vec3(0.085, 0.07, 0.062);
uniform vec3 rock_hi : source_color = vec3(0.33, 0.285, 0.24);
uniform vec3 band : source_color = vec3(0.3, 0.17, 0.1);
uniform vec3 mineral : source_color = vec3(0.17, 0.27, 0.26);
uniform vec3 silt : source_color = vec3(0.2, 0.175, 0.14);
uniform vec3 moss_dark : source_color = vec3(0.05, 0.1, 0.025);
uniform vec3 moss_lit : source_color = vec3(0.24, 0.36, 0.08);
// A faint fill (emitted, linear), so the dark between the glows reads as rock.
uniform vec3 fill : source_color = vec3(0.07, 0.09, 0.1);
uniform float fill_gain = 0.8;
uniform vec3 tilt = vec3(0.16, 1.0, 0.09);

varying vec3 wpos;
varying vec3 wnrm;

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), u.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), u.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), u.x), u.y),
		u.z);
}

float fbm(vec3 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec3(17.1, 9.2, 4.7);
		a *= 0.5;
	}
	return s;
}

// The rock's height field for the bent normal: strata ledges and pits.
float relief(vec3 p) {
	float warp = fbm(p * 0.09) * 9.0;
	float layer = dot(p, normalize(tilt)) * 0.42 + warp;
	float ledge = abs(fract(layer) - 0.5) * 2.0;
	ledge = smoothstep(0.0, 0.55, ledge);
	return ledge * 0.55 + fbm(p * 0.8) * 0.9 + fbm(p * 3.1) * 0.22;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	// cull_disabled: the inside is what is seen, and a lump can fold over, so
	// the side facing the eye (not the triangle's own) is the front.
	if (dot(n, CAMERA_POSITION_WORLD - wpos) < 0.0) n = -n;
	float wall = 1.0 - smoothstep(0.55, 0.85, abs(n.y));
	float up = smoothstep(0.3, 0.8, n.y);
	float warp = fbm(wpos * 0.09) * 9.0;
	float layer = dot(wpos, normalize(tilt)) * 0.12 + warp * 0.3;
	float strata = fbm(vec3(layer * 3.0, 0.3, 1.7));
	float mott = fbm(wpos * 0.17);
	float tone = clamp(mott * 0.55 + strata * 0.65 - 0.1, 0.0, 1.0) * mix(0.72, 1.08, COLOR.r);
	vec3 rock = mix(rock_lo, rock_hi, tone);
	rock = mix(rock, band, smoothstep(0.52, 0.68, strata) * 0.55);
	// Mineral streaks run down the walls where water has.
	float streak = smoothstep(0.58, 0.74, fbm(vec3(wpos.x * 0.8, wpos.y * 0.05, wpos.z * 0.8)));
	rock = mix(rock, mineral, streak * 0.6 * wall);
	// Silt lies in the low places.
	float grit = up * smoothstep(0.3, 0.62, fbm(wpos * vec3(0.3, 0.05, 0.3)));
	rock = mix(rock, silt * mix(0.7, 1.2, vnoise(wpos * 2.3)), grit * 0.85);
	// The growth: only where the light gets in.
	float green = COLOR.g;
	float patch_g = fbm(wpos * 0.31 + vec3(0.0, 11.0, 0.0));
	float grow = smoothstep(0.38, 0.6, patch_g + green * 0.4) * clamp(green * 1.3, 0.0, 1.0) * mix(0.6, 1.0, up);
	vec3 m = mix(moss_dark, moss_lit, fbm(wpos * 1.3));
	ALBEDO = mix(rock, m, grow);
	float wet = smoothstep(0.42, 0.66, fbm(wpos * 0.21 + vec3(3.0)));
	ROUGHNESS = mix(mix(0.82, 0.28, wet), 0.95, grow);
	SPECULAR = 0.5;
	// The normal from the relief, by differences along the surface.
	const float STEP_E = 0.14;
	vec3 u_a = normalize(cross(n, abs(n.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 v_a = cross(n, u_a);
	float r0 = relief(wpos);
	float du = relief(wpos + u_a * STEP_E) - r0;
	float dv = relief(wpos + v_a * STEP_E) - r0;
	vec3 bent = normalize(n - (u_a * du + v_a * dv) * 7.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	AO = mix(0.55, 1.0, smoothstep(0.3, 0.8, r0 * 0.6));
	AO_LIGHT_AFFECT = 0.5;
	EMISSION = fill * fill_gain * mix(0.6, 1.2, tone) * mix(1.0, 0.6, grow);
}
