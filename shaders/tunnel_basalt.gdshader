shader_type spatial;
// The tunnels' carved rock as columnar basalt (scripts/endless/land_tunnels.gd
// `_rock_material`): upright columns `cell` m across on a jittered hex
// lattice in world XZ, so a wall shows their faceted sides as upright bands
// broken by cross joints every `course` m or so, and the vault and floor
// show their hexagonal ends. Each column's facet that faces out bends the
// normal (`facet`), so a smooth wall shades as prisms under the torches.
// Moss and lichen gather on what faces up, in the joints and low on the
// walls, as much as the vertex colour's green says (the light the place
// gets: mouths, shafts, patches). Vertex colour: r the rock's tone, g the
// growth, alpha 0 on a column of its own (its faces its own: no lattice). Torch lit only: no sky fill, no haze.
render_mode diffuse_burley, specular_schlick_ggx, ambient_light_disabled, fog_disabled, cull_disabled;

uniform float cell = 1.8;
uniform float jitter = 0.42;
uniform float joint = 0.05;
uniform float course = 1.3;
uniform float facet = 0.8;
uniform float floor_y = 0.0;
uniform vec3 basalt_lo : source_color = vec3(0.06, 0.066, 0.075);
uniform vec3 basalt_hi : source_color = vec3(0.17, 0.172, 0.178);
uniform vec3 rust : source_color = vec3(0.24, 0.16, 0.1);
uniform vec3 moss_dark : source_color = vec3(0.05, 0.1, 0.025);
uniform vec3 moss_lit : source_color = vec3(0.24, 0.36, 0.08);
uniform float moss = 0.85;
uniform float moss_low = 2.4;
// A faint cold fill (emitted, linear), so the dark between the torches
// reads as grey stone rather than nothing.
uniform vec3 fill : source_color = vec3(0.07, 0.085, 0.11);
uniform float fill_gain = 0.22;
// What the floor and the columns' tops gather: grit and silt.
uniform vec3 silt : source_color = vec3(0.12, 0.11, 0.095);

varying vec3 wpos;
varying vec3 wnrm;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), u.x), mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s;
}

// The column under XZ point `p` (m): its centre (xy), its id hash (z) and
// the distance to its nearest joint (w); `out_face` the outward facet
// normal (XZ) nearest along `toward` (the surface's own facing).
vec4 columns(vec2 p, vec2 toward, out vec2 out_face) {
	// Hex lattice: a along x, b at 60 degrees.
	const float S3 = 0.8660254;
	vec2 q = vec2(p.x / cell - p.y / (cell * S3) * 0.5, p.y / (cell * S3));
	vec2 base = floor(q);
	vec2 best = vec2(0.0);
	vec2 best_cell = vec2(0.0);
	float bd = 1e9;
	for (int j = -1; j <= 2; j++) {
		for (int i = -1; i <= 2; i++) {
			vec2 c = base + vec2(float(i), float(j));
			vec2 o = (hash2(c) - 0.5) * jitter;
			vec2 w = vec2((c.x + 0.5 * c.y + o.x) * cell, (c.y + o.y) * cell * S3);
			float d = dot(w - p, w - p);
			if (d < bd) {
				bd = d;
				best = w;
				best_cell = c;
			}
		}
	}
	// The nearest joint: the Voronoi edge to each neighbour.
	float edge = 1e9;
	vec2 face = vec2(0.0);
	float face_score = -1e9;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 c = best_cell + vec2(float(i), float(j));
			if (c == best_cell) continue;
			vec2 o = (hash2(c) - 0.5) * jitter;
			vec2 w = vec2((c.x + 0.5 * c.y + o.x) * cell, (c.y + o.y) * cell * S3);
			vec2 n = w - best;
			float len = length(n);
			if (len > cell * 1.6) continue;
			n /= len;
			float e = dot((best + w) * 0.5 - p, n);
			edge = min(edge, e);
			// The facet that faces out most, near this point.
			float score = dot(n, toward) * 2.0 - e / cell;
			if (score > face_score) {
				face_score = score;
				face = n;
			}
		}
	}
	out_face = face;
	return vec4(best, hash1(best_cell * 1.37 + 3.1), edge);
}

float up_face(vec3 n) {
	return smoothstep(0.6, 0.9, n.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	// cull_disabled: the inside is what is seen.
	if (!FRONT_FACING) n = -n;
	float wall = 1.0 - smoothstep(0.55, 0.85, abs(n.y));
	vec2 toward = length(n.xz) > 0.001 ? normalize(n.xz) : vec2(0.0, 1.0);
	vec2 face;
	vec4 col = columns(wpos.xz, toward, face);
	float own = 1.0 - COLOR.a;
	float id = mix(col.z, COLOR.r, own);
	float edge = mix(col.w, 1.0, own);
	// Cross joints on the sides, each column its own offset and drums.
	float drum = course * mix(0.7, 1.4, fract(id * 7.3));
	float yy = (wpos.y + id * 9.7 + edge * 0.35) / drum;
	float cross_j = abs(fract(yy) - 0.5) * 2.0;
	float cross_line = smoothstep(1.0 - joint * 2.5 / drum, 1.0, cross_j) * wall;
	float jw = joint * mix(0.6, 1.6, vnoise(wpos.xz * 1.3 + wpos.y * 0.7));
	float joint_line = 1.0 - smoothstep(jw * 0.5, jw * 1.6, edge);
	float arris = (1.0 - smoothstep(jw * 1.6, jw * 5.0, edge)) * (1.0 - joint_line);
	float crack = max(joint_line, cross_line);
	// The tone: per column, the vertex's own, a slow mottle.
	float mott = fbm(wpos.xz * 0.21 + wpos.y * 0.13);
	float tone = clamp(id * 0.55 + mott * 0.45, 0.0, 1.0) * mix(mix(0.6, 1.0, COLOR.r), 1.0, own);
	vec3 rock = mix(basalt_lo, basalt_hi, tone);
	// Iron weathering in streaks down the walls.
	float streak = smoothstep(0.62, 0.8, fbm(vec2((wpos.x + wpos.z) * 1.7, wpos.y * 0.09)));
	rock = mix(rock, rust, streak * 0.35 * wall);
	rock *= 1.0 + arris * 0.12;
	// On what faces up (the floor, a column's top) silt and grit soften
	// the joints and break up the ends.
	float grit = up_face(n) * smoothstep(0.3, 0.7, fbm(wpos.xz * 0.6) + vnoise(wpos.xz * 7.0) * 0.25);
	rock = mix(rock, silt * mix(0.7, 1.2, vnoise(wpos.xz * 3.0)), grit * 0.8);
	rock *= 1.0 - crack * 0.7 * (1.0 - grit * 0.7);
	// The growth: up-facing, in the joints, low on the walls; the vertex's
	// green the light the place gets.
	float green = COLOR.g;
	float h = wpos.y - floor_y;
	float up = smoothstep(0.25, 0.75, n.y);
	float low = (1.0 - smoothstep(0.2, moss_low, h)) * wall;
	float patch = fbm(wpos.xz * 0.35 + vec2(wpos.y * 0.2, 0.0));
	float grow = max(up * 0.9, low * 0.8) * smoothstep(0.35, 0.65, patch + green * 0.35);
	grow = max(grow, crack * smoothstep(0.45, 0.7, patch) * 0.8);
	grow = clamp(grow * moss * (0.35 + 0.95 * green), 0.0, 1.0);
	vec3 m = mix(moss_dark, moss_lit, fbm(wpos.xz * 1.9 + wpos.y));
	ALBEDO = mix(rock, m, grow);
	// Wet basalt glints under the torches; moss is dull.
	float wet = smoothstep(0.5, 0.75, fbm(wpos.xz * 0.5 + vec2(0.0, wpos.y * 0.3)));
	ROUGHNESS = mix(mix(0.62, 0.32, wet), 0.95, grow);
	SPECULAR = 0.5;
	// The normal: bent to the facet facing out on the sides, a little tilt
	// on a column's end, the joints sunk.
	vec3 fn = normalize(vec3(face.x, 0.0, face.y));
	vec3 bent = normalize(mix(n, fn, facet * wall * (1.0 - joint_line) * (1.0 - own)));
	vec2 tilt = (hash2(vec2(id * 31.0, id * 17.0)) - 0.5) * 0.25 * (1.0 - wall);
	bent = normalize(bent + vec3(tilt.x, 0.0, tilt.y));
	if (joint_line > 0.0) {
		vec2 into = normalize(col.xy - wpos.xz + vec2(1e-4));
		bent = normalize(mix(bent, normalize(bent + vec3(into.x, 0.0, into.y) * 0.35), joint_line));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(bent, 0.0)).xyz);
	AO = 1.0 - crack * 0.6;
	EMISSION = fill * fill_gain * (1.0 - crack * 0.8) * mix(0.7, 1.2, tone) * mix(1.0, 0.6, grow);
	AO_LIGHT_AFFECT = 0.6;
}
