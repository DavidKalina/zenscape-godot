// Far grass as clumps with depth (clean look round 7): past the real tufts
// the meadow is drawn as rounded clumps of blades, each lit on its sun side,
// dark and cool in the gaps between, with a soft shadow on the side away
// from the sun, and a few layers of them marched below the surface along
// the view ray so the tips show on top, the dark depth between, and blades
// hide each other at grazing angles. Looking straight down you see into the
// gaps (darker, deeper); looking along the ground you see blade sides
// (lighter, richer). The wind bows the clumps: the sheen's own wave field
// (zs_sheen_field, the near tufts' waves) leans each clump downwind, the top
// layers more than the lower. Texture only: no bumps, the surface stays flat.
// Include after grass_sheen.
#ifndef ZS_FAR_CLUMPS
#define ZS_FAR_CLUMPS

// x strength (0 off), y how deep the layers read (0: only the lit sides and
// gaps), z..w the ring distance (m) it comes in over: from past the near
// tufts' dense ring, as they thin out.
uniform vec4 grass_far_clumps = vec4(0.0, 1.0, 150.0, 240.0);
// The clumps' sizes (m across), fine to broad. Each fades to its mean when a
// pixel nears a third of it (full under 0.14, gone at 0.4), so none draws under
// about three pixels and none shimmers.
uniform vec3 grass_far_clump_sizes = vec3(1.2, 3.0, 9.0);

const int ZS_CLUMP_LAYERS = 6;
// How tall the field stands, for the layers' parallax (m).
const float ZS_CLUMP_DEPTH = 0.9;

vec2 zs_cl_hash2(vec2 c) {
	vec3 p3 = fract(vec3(c.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// The nearest clump centre to `q` (cell units): the vector from it to the
// point, the gap to the second nearest, and the clump's own random 0..1.
void zs_cl_voro(vec2 q, out vec2 d, out float edge, out float id) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	float f1 = 8.0;
	float f2 = 8.0;
	vec2 best = vec2(0.0);
	float best_id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 h = zs_cl_hash2(i + o);
			vec2 r = f - (o + 0.12 + 0.76 * h);
			float dd = dot(r, r);
			if (dd < f1) {
				f2 = f1;
				f1 = dd;
				best = r;
				best_id = h.x;
			} else if (dd < f2) {
				f2 = dd;
			}
		}
	}
	d = best;
	edge = sqrt(f2) - sqrt(f1);
	id = best_id;
}

// One scale of clumps at `q` (cell units, already leaned), seen along `v`
// (xz per unit down: the ray's slide per metre of depth), as a multiplier on
// the grass colour. `lean` is the wind's bow per metre of height (m), `size`
// the clump's width (m), `sun_h` the sun's compass, `sun_w` how much it lights
// sides, `look` 0 (along the ground) to 1 (straight down).
vec3 zs_cl_scale(vec2 q, float fp, vec2 slide, vec2 lean, float size, vec2 sun_h, float sun_w, float look,
		float depth_amt, vec3 tint, vec3 warm, vec3 cool) {
	vec2 d;
	float edge;
	float id;
	zs_cl_voro(q, d, edge, id);
	const float R = 0.62;
	float rim = length(d) / R;
	// The clump's own height: taller ones near their middle, a few shy.
	float hgt = 0.62 + 0.38 * id;
	float dome = clamp(1.0 - rim, 0.0, 1.0);
	// Its lit side: the dome's normal leans outward from its middle, and
	// downwind with the bow; it lights where that faces the sun.
	vec2 nxz = d / R * (0.55 + 0.45 * dome) + lean * 1.6;
	float lit = clamp(dot(nxz, sun_h) * sun_w * 1.5, -1.0, 1.0);
	// The gaps: low and shut between the clumps; the soft shadow on a
	// point on a clump's sun-facing edge (the clump toward the sun throws it).
	float cavity = 1.0 - smoothstep(0.0, 0.62, dome + smoothstep(0.0, 0.3, edge) * 0.35);
	float sun_edge = smoothstep(-0.25, 0.75, dot(d / R, sun_h));
	float shadow = cavity * (0.45 + 0.55 * sun_edge);

	// The layers, top to bottom: each shows where the clump stands as high as
	// the layer; what the ray passes goes on to the layer below.
	// The blades' own ragged tips, a finer noise on the clump's height (gone when
	// a pixel outgrows it).
	float rag = (zs_noise(q * 3.3 + id * 40.0) - 0.5) * 0.4 * (1.0 - smoothstep(size * 0.03, size * 0.09, fp));
	vec3 acc = vec3(0.0);
	float alpha = 0.0;
	for (int k = 0; k < ZS_CLUMP_LAYERS; k++) {
		float t = float(ZS_CLUMP_LAYERS - k) / float(ZS_CLUMP_LAYERS + 1);
		float below = (1.0 - t) * ZS_CLUMP_DEPTH;
		vec2 dk = d + (slide + lean) * below / size * depth_amt;
		float domek = clamp(1.0 - length(dk) / R, 0.0, 1.0);
		float height_k = hgt * smoothstep(0.0, 0.75, domek) + rag * smoothstep(0.0, 0.3, domek);
		float soft = 0.1 + 0.08 * float(k);
		float cover = smoothstep(t - soft, t + soft * 0.5, height_k) * (k == 0 ? 0.85 : 1.0);
		// Tops lit on their sun side; lower layers darker and cooler.
		vec3 col = vec3(1.0 + 0.5 * lit * (0.4 + 0.6 * t) + 0.12 * t);
		col *= mix(vec3(1.0), vec3(1.05, 1.04, 0.9), t);
		col *= mix(vec3(1.0), cool * vec3(0.8), (1.0 - t) * (0.55 + 0.45 * look));
		col *= mix(vec3(1.0), tint * vec3(1.12, 1.1, 0.95), max(lit, 0.0) * t * 0.6);
		acc += (1.0 - alpha) * cover * col;
		alpha += (1.0 - alpha) * cover;
	}
	// The floor: the gaps' dark, cool, shadowed on the side away from the sun.
	vec3 floor_c = cool * vec3(0.7 - 0.1 * look) * (1.0 - 0.28 * shadow);
	acc += (1.0 - alpha) * floor_c;
	return acc;
}

// The grass colour `g` as clumps. `view` the unit ray from the eye to the
// point, `fp` the pixel's footprint (m), `s` the sheen's lean (-1..1,
// zs_sheen_field), `key` the key light's colour, `warm`/`cool` the clean
// look's tints. `on` 0..1 how much.
vec3 zs_far_clumps(vec3 g, vec2 p, vec3 view, float fp, float s, vec3 key, vec3 warm, vec3 cool, float on) {
	float vert = clamp(-view.y, 0.12, 1.0);
	float look = smoothstep(0.25, 0.95, vert);
	vec2 slide = view.xz / vert;
	vec2 sun_h = zs_sun_direction.xz / max(length(zs_sun_direction.xz), 0.001);
	float sun_w = clamp(1.0 - zs_sun_direction.y * 0.7, 0.35, 1.0);
	vec3 tint = mix(vec3(1.0), key / max(max(key.r, max(key.g, key.b)), 0.001), 0.8);
	// The bow: m a clump leans per metre of its height, downwind, more as the
	// wave crests (s), a little always.
	vec2 lean = zs_wind_direction * (0.14 + 0.22 * s);
	vec3 sizes = grass_far_clump_sizes;
	vec3 mul = vec3(1.0);
	float depth_amt = grass_far_clumps.y;
	for (int i = 0; i < 3; i++) {
		float size = sizes[i];
		float keep = 1.0 - smoothstep(size * 0.15, size * 0.36, fp);
		if (keep <= 0.0) continue;
		// Each scale turned a different way, so no grid lines up.
		float ang = 0.9 * float(i) + 0.4;
		mat2 turn = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
		vec2 q = turn * (p - lean * ZS_CLUMP_DEPTH) / size + float(i) * 17.3;
		// The layers' slide and the bow, taken to the turned frame.
		vec3 c = zs_cl_scale(q, fp, turn * slide, turn * lean, size, turn * sun_h, sun_w, look,
				i == 2 ? 0.0 : depth_amt, tint, warm, cool);
		// Broader scales add less, the finest the most; fades to its mean.
		// (How much it reads varies slowly over the meadow, so it is not one even bubble wrap.)
		float patch_k = 0.6 + 0.8 * zs_noise(p / (size * 9.0) + float(i) * 5.0);
		float w = (i == 0 ? 0.9 : (i == 1 ? 0.8 : 0.45)) * keep * patch_k;
		mul *= mix(vec3(1.0), c, w);
	}
	// Looking along the ground: lighter, richer; straight down: deeper.
	vec3 lum = vec3(dot(g, vec3(0.299, 0.587, 0.114)));
	vec3 out_c = g * mul;
	out_c = mix(out_c, lum * mul + (g - lum) * 1.25 * mul, (1.0 - look) * 0.35);
	out_c *= mix(1.2, 1.12, look);
	return mix(g, out_c, on * grass_far_clumps.x);
}
#endif
