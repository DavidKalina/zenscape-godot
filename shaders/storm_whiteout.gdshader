shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// A whiteout's murk (scripts/storm_whiteout.gd): a sheet over the whole
// screen, drawn after the cloud and the far rain (its render priority), that
// greys out all past a few tens of metres: the land by its depth, the sky
// and the cloud (which keep no depth) wholly. Wisps of cloud race past in
// it (noise sampled along the view at a few depths, in the world, so they
// stream by as the plane flies), and a flash lights it from inside, the
// side it struck on a little more.

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// How thick (0 to 1): the seen distance closes from `open` to `seen` m.
uniform float murk = 0.0;
uniform float seen = 16.0;
uniform float open = 500.0;
// Clear round the eye (m): the plane in front of the chase camera.
uniform float clear = 9.0;
uniform vec3 colour : source_color = vec3(0.36, 0.37, 0.39);
uniform vec3 dark : source_color = vec3(0.22, 0.225, 0.235);
uniform vec3 lit : source_color = vec3(0.8, 0.84, 0.95);
// The flash now (0 up) and where it is.
uniform float flash = 0.0;
uniform vec3 flash_at = vec3(0.0);
// The wisps' drift (the wind, m/s) and their size (m).
uniform vec3 drift = vec3(0.0);
uniform float wisp = 9.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return noise(p) * 0.6 + noise(p * 2.03 + 7.1) * 0.3 + noise(p * 4.1 + 3.7) * 0.1;
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * (view.xyz / view.w));
	float depth = texture(depth_texture, SCREEN_UV).r;
	float t_solid = 1e9;
	if (depth > 0.0) {
		vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		t_solid = length(behind.xyz / behind.w);
	}
	float k = clamp(murk, 0.0, 1.0);
	float reach = mix(open, seen, k * k * (3.0 - 2.0 * k));
	float thick = 1.0 - exp(-max(t_solid - clear, 0.0) * 2.3 / reach);
	// The wisps: three shells round the eye, each a slab of noise in the
	// world carried on the wind; nearer ones darker and more ragged.
	vec3 moved = drift * TIME;
	float shade = 0.0;
	float cover = 0.0;
	for (int s = 0; s < 3; s++) {
		float at = clear + float(s + 1) * reach * 0.35;
		if (at > t_solid) break;
		vec3 p = (eye + rd * at - moved) / (wisp * (1.0 + float(s) * 0.8));
		float n = fbm(p + vec3(0.0, TIME * 0.15, 0.0));
		float c = smoothstep(0.38, 0.75, n) * (0.8 - float(s) * 0.2);
		shade += c * (n - 0.5);
		cover = max(cover, c);
	}
	// Wisps lighter where thick, the gaps between them darker.
	vec3 base = mix(dark, colour * 1.3, clamp(0.55 + shade * 3.5, 0.0, 1.0));
	// Brighter up, darker down: still a little sense of up.
	base *= 0.85 + 0.25 * clamp(rd.y * 0.5 + 0.5, 0.0, 1.0);
	// Lit from inside by a flash, more toward where it struck.
	vec3 to_flash = flash_at - eye;
	float facing = length(to_flash) > 1.0 ? dot(rd, normalize(to_flash)) * 0.5 + 0.5 : 0.5;
	float glow = clamp(flash, 0.0, 3.0) * (0.35 + 0.65 * facing * facing);
	base = mix(base, lit, clamp(glow * 0.7, 0.0, 0.95));
	ALBEDO = base;
	ALPHA = clamp(max(thick, cover * k) * k, 0.0, 1.0);
}
