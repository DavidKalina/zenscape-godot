shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The railroad tunnels' lining (scripts/endless/rail_bore.gd): the courses,
// bricks, rock and timber drawn from the mesh's UV, so the bore reads as
// built at speed without the triangles. UV: x along the line (m), y round
// the section (m). UV2.x the surface kind (rail_bore_mesh.gd K_*), UV2.y the
// soot over it (0..1). COLOR the base tint, per piece of stone already
// varied by the builder.
//
// Each joint fades out by its screen size (fwidth), so far courses blend to
// their average instead of shimmering.

uniform float course_h = 1.0;
uniform float ashlar_len = 2.7;
uniform float brick_h = 0.42;
uniform float brick_len = 1.15;
uniform float joint = 0.07;
uniform float joint_dark = 0.45;
uniform vec3 soot_color : source_color = vec3(0.07, 0.06, 0.055);
// The lamps' light bounced round the bore: a faint fill, so the dark
// between their pools still shows the shape.
uniform float fill = 0.07;
// Out of doors (the portals): the sky's light on a face in shade, more on
// what faces up, as the ruins' stone takes it.
uniform float sky_fill = 0.0;
uniform vec3 sky_tint : source_color = vec3(0.62, 0.70, 0.85);
uniform vec3 ground_tint : source_color = vec3(0.45, 0.42, 0.36);

varying vec2 kind_soot;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * noise2(p);
		p = p * 2.03 + vec2(17.1, 3.7);
		a *= 0.5;
	}
	return s;
}

// A running-bond pattern: the joint's darkening (0 none, 1 full) and the
// block's own shade (-1..1), courses `h` high, blocks `len` long.
vec2 bond(vec2 uv, float h, float len, float j) {
	float row = floor(uv.y / h);
	float x = uv.x / len + 0.5 * mod(row, 2.0);
	float col = floor(x);
	vec2 f = vec2(fract(x) * len, fract(uv.y / h) * h);
	vec2 w = fwidth(uv) + 1e-4;
	float jx = 1.0 - smoothstep(j * 0.5, j * 0.5 + w.x, min(f.x, len - f.x));
	float jy = 1.0 - smoothstep(j * 0.5, j * 0.5 + w.y, min(f.y, h - f.y));
	// The joints fade as they shrink under a pixel.
	float fade = 1.0 - smoothstep(0.25, 1.0, max(w.x / j, w.y / j) * 0.5);
	float jn = max(jx, jy) * fade;
	return vec2(jn, hash2(vec2(col, row)) * 2.0 - 1.0);
}

void vertex() {
	kind_soot = UV2;
}

void fragment() {
	float kind = floor(kind_soot.x + 0.5);
	vec3 base = COLOR.rgb;
	vec2 uv = UV;
	float shade = 0.0;
	float jn = 0.0;
	float rough = 0.92;
	float grain = fbm(uv * vec2(1.3, 1.3));
	if (kind < 0.5) {
		// Ashlar: dressed courses, each stone its own tone, tooled faces.
		vec2 b = bond(uv, course_h, ashlar_len, joint);
		jn = b.x;
		shade = b.y * 0.16 + (grain - 0.5) * 0.18;
	} else if (kind < 1.5) {
		// Brick: small courses in a warmer, darker red.
		vec2 b = bond(uv, brick_h, brick_len, joint * 0.8);
		jn = b.x * 0.85;
		shade = b.y * 0.14 + (grain - 0.5) * 0.12;
	} else if (kind < 2.5) {
		// Bare rock: broken, streaked by water down the walls.
		float n = fbm(uv * vec2(0.35, 0.6));
		float cracks = 1.0 - smoothstep(0.0, 0.06 + fwidth(n) * 2.0, abs(fbm(uv * 0.5 + 9.0) - 0.5));
		float streak = noise2(vec2(uv.x * 0.8, uv.y * 0.08));
		float strata = noise2(vec2(uv.x * 0.04, uv.y * 0.55));
		shade = (n - 0.5) * 0.45 + (streak - 0.5) * 0.2 + (strata - 0.5) * 0.35;
		jn = cracks * 0.2 * (1.0 - smoothstep(0.3, 1.2, length(fwidth(uv))));
	} else if (kind < 3.5) {
		// Timber: grain along the beam (UV x runs round the set), knots.
		float g = noise2(vec2(uv.x * 0.6, uv.y * 9.0));
		shade = (g - 0.5) * 0.35 + (grain - 0.5) * 0.15;
		rough = 0.85;
	} else if (kind < 4.5) {
		// The floor: ballast, speckled.
		shade = (noise2(uv * 6.0) - 0.5) * 0.25 + (grain - 0.5) * 0.15;
	} else if (kind < 5.5) {
		// The drain: an iron grate across its channel.
		float bars = abs(fract(uv.x / 0.35) - 0.5);
		jn = (1.0 - smoothstep(0.18, 0.18 + fwidth(uv.x) / 0.35 * 2.0, bars)) * (1.0 - smoothstep(0.2, 0.8, fwidth(uv.x)));
		shade = -0.2;
		rough = 0.6;
	} else if (kind < 6.5) {
		// Dressed stone in single pieces (voussoirs, keystone, coping).
		shade = (grain - 0.5) * 0.2;
	} else {
		// Iron.
		shade = (grain - 0.5) * 0.1;
		rough = 0.5;
	}
	vec3 c = base * (1.0 + shade);
	c = mix(c, c * joint_dark, jn);
	// Soot: thick at its source, broken by the grain.
	float soot = clamp(kind_soot.y * (0.75 + 0.5 * grain), 0.0, 1.0);
	c = mix(c, soot_color, soot);
	ALBEDO = c;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	EMISSION = c * fill + c * sky_fill * mix(ground_tint, sky_tint, wn.y * 0.5 + 0.5);
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
