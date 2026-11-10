shader_type spatial;
// The hot air balloon's gondola: wicker basket, leather, rope, the burner's
// iron and brass (scripts/endless/endless_balloons.gd, the mesh from
// art/blender/balloon/balloon_build.py). The vertex colour is the part's
// tint and its alpha how much of the burner's light it catches; UV is in
// metres on the wicker (UV.x >= 0) and (-1, -1) elsewhere. Lit as the world
// is (shaders/folk_surface.gdshaderinc).
render_mode diffuse_lambert, specular_schlick_ggx;

global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;

instance uniform float burn = 0.0;
instance uniform float fade = 1.0;
instance uniform float seed = 0.0;

uniform float fill = 1.5;
uniform float rim = 0.3;
uniform vec3 flame_colour : source_color = vec3(1.0, 0.52, 0.17);
uniform float glow = 1.6;
// The weave: stakes a metre round, rows a metre up.
uniform vec2 weave = vec2(11.0, 42.0);

varying vec3 local;

float hash1(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), f.x), mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	if (fade < 1.0) {
		float d = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (d > fade) discard;
	}
	vec3 base = COLOR.rgb;
	float rough = 0.85;
	if (UV.x >= 0.0) {
		// Wicker: flat rows woven over and under upright stakes.
		vec2 w = UV * weave;
		float px = max(fwidth(w.x), fwidth(w.y));
		float fine = 1.0 - smoothstep(0.25, 0.9, px);
		float row = floor(w.y);
		float sx = w.x + mod(row, 2.0) * 0.5;
		float over = cos(sx * TAU) * 0.5 + 0.5;
		float strand = sin(fract(w.y) * PI);
		float h = strand * (0.35 + 0.65 * over);
		float tone = hash1(vec2(floor(sx), row));
		base *= mix(1.0, (0.45 + 0.75 * h) * (0.82 + 0.36 * tone), fine);
		// Stained: darker toward the floor, weathered grey up the sunny rim,
		// blotches where it has been dragged and wetted.
		float blot = vnoise(UV * vec2(2.3, 5.0) + seed);
		base *= 0.7 + 0.3 * smoothstep(0.0, 0.6, UV.y);
		base = mix(base, vec3(dot(base, vec3(0.333))) * 1.25, 0.3 * smoothstep(0.45, 0.8, blot));
		base *= 1.0 - 0.35 * smoothstep(0.55, 0.9, vnoise(UV * vec2(1.1, 9.0) + 4.0 + seed));
		// The weave's relief.
		float height = h * fine * 0.006;
		vec3 dpx = dFdx(VERTEX);
		vec3 dpy = dFdy(VERTEX);
		vec3 n = normalize(NORMAL);
		vec3 r1 = cross(dpy, n);
		vec3 r2 = cross(n, dpx);
		float det = dot(dpx, r1);
		vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
		vec3 bent = abs(det) * n - grad;
		// A sliver's derivatives can come out empty or not a number.
		if (dot(bent, bent) > 1e-12 && !any(isnan(bent))) NORMAL = normalize(bent);
	} else {
		// Rope, leather, iron, sacking: a mottle and a fray along the part.
		float m = vnoise(local.xy * 9.0 + local.z * 7.0 + seed);
		float twist = sin((local.y * 60.0 + local.x * 25.0 + local.z * 25.0)) * 0.5 + 0.5;
		base *= 0.78 + 0.3 * m + 0.12 * twist * (1.0 - smoothstep(0.02, 0.2, fwidth(local.y) * 60.0));
		rough = mix(0.9, 0.5, step(COLOR.r + COLOR.g + COLOR.b, 0.3));
	}
	ALBEDO = base;
	ROUGHNESS = rough;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, wn.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = base * hemi * fill + base * zs_hemi_sky * zs_hemi_energy * edge * rim;
	if (burn > 0.0) {
		float flick = 0.82 + 0.18 * sin(TIME * 31.0 + seed * 5.0) * sin(TIME * 17.3 + 1.0);
		// Faces that look up catch more of it.
		EMISSION += base * flame_colour * burn * flick * glow * COLOR.a * (0.45 + 0.55 * clamp(wn.y, 0.0, 1.0));
	}
}
