shader_type spatial;
// The hot air balloon's cloth (scripts/endless/endless_balloons.gd, the mesh
// from art/blender/balloon/balloon_build.py). UV.x counts gores (a whole
// number on each load tape), UV.y runs 0 at the crown to 1 at the mouth.
// One material for every balloon: the pattern, its three tones and the
// moving parts are instance uniforms.
//
// Painted here: the pattern (`pattern` 0 gore stripes, 1 hoops, 2 a spiral,
// 3 a zigzag belt, 4 salvaged panels), sun-fade toward the crown, patches
// sewn over holes, the tapes and panel seams with their stitches, rain
// stains, soot round the mouth, a ripstop weave up close.
// Moving: `shudder` ripples the slack lower cloth, `wash` (a direction in
// the envelope's frame, w its depth) dents the side a plane's wash hits,
// `burn` lights the inside from the burner and glows through the cloth.
// In the dark (`zs_daylight` low) the cloth is a lantern: `glow` (the burn,
// eased by the manager) and a low ember between burns come through it, most
// near the mouth, in the dye's colour, tapes, seams and patches dark in it.
// Lit as the world is: no ambient, the sky's hemisphere as emission
// (shaders/folk_surface.gdshaderinc).
render_mode diffuse_lambert, specular_disabled, cull_disabled;

global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform float zs_daylight;

instance uniform vec3 tone_a : source_color = vec3(0.45, 0.16, 0.11);
instance uniform vec3 tone_b : source_color = vec3(0.62, 0.55, 0.42);
instance uniform vec3 tone_c : source_color = vec3(0.16, 0.2, 0.22);
instance uniform float pattern = 0.0;
instance uniform float seed = 0.0;
instance uniform float burn = 0.0;
instance uniform float shudder = 0.0;
instance uniform vec4 wash = vec4(0.0);
instance uniform float fade = 1.0;
// How sun-worn the cloth is: 1 the old muted cloth, less for festival dyes.
instance uniform float wear = 1.0;
// The burner's light held in the cloth: up with the burn, easing back slower.
instance uniform float glow = 0.0;

uniform float gores = 16.0;
uniform float panels = 14.0;
uniform float fill = 1.8;
uniform float rim = 0.25;
// How much sun comes through the cloth on the side turned from it.
uniform float through = 0.45;
uniform vec3 flame_colour : source_color = vec3(1.0, 0.52, 0.17);
uniform float glow_inside = 2.6;
uniform float glow_through = 0.3;
// The lantern, in the dark. `night` scales all of it (0: none, the bench's
// A/B); `lantern` the light through the cloth at a full burn; `ember` the
// share of it between burns; `lantern_crown` what reaches the crown and
// `lantern_fall` how fast it thins on the way up; `lantern_far` its lift
// where a balloon is a few pixels (`ember_far` the ember's, over that); `lantern_inside` the inside's lift over
// the day's; `lantern_hot` over the flame, `lantern_deep` far from it; `dark_from` the
// daylight (celestial zs_daylight) it starts and ends coming in over.
uniform float night = 1.0;
uniform float lantern = 1.9;
uniform float ember = 0.3;
uniform float lantern_crown = 0.12;
uniform float lantern_fall = 2.3;
uniform float lantern_far = 3.0;
uniform float ember_far = 2.4;
uniform float lantern_inside = 0.4;
uniform vec2 dark_from = vec2(0.62, 0.04);
uniform vec3 lantern_hot : source_color = vec3(1.0, 0.8, 0.46);
uniform vec3 lantern_deep : source_color = vec3(0.9, 0.2, 0.05);
uniform vec3 faded : source_color = vec3(0.66, 0.61, 0.52);
uniform vec3 soot : source_color = vec3(0.07, 0.06, 0.055);

varying vec3 local;
varying float ripple;

float hash1(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030) + seed * 0.137);
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1.0, 0.0)), f.x), mix(hash1(i + vec2(0.0, 1.0)), hash1(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The cloth's ripple at (u, v): the same in the vertex push and the shading.
float ripple_at(vec2 uv) {
	float low = smoothstep(0.12, 0.85, uv.y);
	float a = sin(uv.x * 1.178 + uv.y * 6.0 + TIME * 8.5 + seed) * sin(uv.y * 23.0 - TIME * 12.0 + seed * 1.7);
	float b = sin(uv.x * 0.785 - TIME * 5.1) * sin(uv.y * 9.0 + TIME * 6.3);
	return (a * 0.6 + b * 0.4) * low;
}

void vertex() {
	local = VERTEX;
	float r = ripple_at(UV);
	// The cloth breathes a little always; a pass sets it shuddering.
	float idle = sin(UV.y * 7.0 + TIME * 0.9 + seed) * sin(UV.x * 0.785 + TIME * 0.6) * 0.035 * smoothstep(0.3, 0.9, UV.y);
	float push = shudder * 0.3 * r + idle;
	// The wash's dent: the side facing it pressed in, deepest low down.
	if (wash.w > 0.0) {
		float facing = max(dot(normalize(VERTEX * vec3(1.0, 0.6, 1.0)), wash.xyz), 0.0);
		push -= wash.w * facing * facing * (0.35 + 0.65 * smoothstep(0.1, 0.8, UV.y)) * sin(clamp(UV.y, 0.0, 1.0) * PI);
	}
	VERTEX += NORMAL * push;
	ripple = r * shudder;
}

// The pattern's tone at gore coordinate `u`, crown-to-mouth `v`.
vec3 pattern_tone(float u, float v, out float edge) {
	float g = floor(u);
	edge = 0.0;
	int kind = int(pattern + 0.5);
	if (kind == 0) {
		// Gore stripes, two and two, a belt of the third tone under the widest ring.
		vec3 t = mod(floor(g * 0.5), 2.0) < 0.5 ? tone_a : tone_b;
		float belt = step(0.44, v) * step(v, 0.5);
		return mix(t, tone_c, belt);
	} else if (kind == 1) {
		// Hoops: wide bands of the three tones, uneven.
		float b = v * 9.0;
		float k = floor(b);
		float pick = mod(k, 4.0);
		edge = 0.0;
		return pick < 0.5 ? tone_a : (pick < 1.5 ? tone_b : (pick < 2.5 ? tone_a : tone_c));
	} else if (kind == 2) {
		// A spiral: each panel row steps one gore round.
		float k = mod(g + floor(v * panels), 4.0);
		return k < 1.5 ? tone_a : (k < 2.5 ? tone_b : tone_c);
	} else if (kind == 3) {
		// A zigzag belt on a plain ground, edged in the third tone.
		float tri = abs(fract(u * 0.5) - 0.5) * 2.0;
		float mid = 0.34 + tri * 0.16;
		float d = abs(v - mid);
		vec3 t = tone_a;
		t = mix(t, tone_c, step(d, 0.105));
		t = mix(t, tone_b, step(d, 0.075));
		// A plain cap in the second tone.
		t = mix(t, tone_b, step(v, 0.1));
		return t;
	}
	// Salvaged panels: mostly the ground, panels of the others sewn in.
	float h = hash1(vec2(g, floor(v * panels)) + 7.0);
	return h < 0.62 ? tone_a : (h < 0.85 ? tone_b : tone_c);
}

void fragment() {
	// A fade-in far off (the manager's), dithered.
	if (fade < 1.0) {
		float d = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		if (d > fade) discard;
	}
	float u = UV.x;
	float v = UV.y;
	float g = floor(u);
	float gu = fract(u);
	float row = floor(v * panels);
	float rv = fract(v * panels);
	// How big a gore and a panel are on screen, to fade the fine work out.
	float px = max(fwidth(u), fwidth(v) * panels);
	float fine = 1.0 - smoothstep(0.02, 0.09, px);
	float finer = 1.0 - smoothstep(0.004, 0.02, px);

	float edge;
	vec3 base = pattern_tone(u, v, edge);
	// The crown's vent panel and the scoop at the mouth.
	base = mix(base, tone_c * 0.8, step(v, 0.045));
	float skirt = smoothstep(0.925, 0.93, v);
	base = mix(base, vec3(0.2, 0.17, 0.13), skirt);
	// The dye as light comes through it: the pattern before sun and dirt.
	vec3 dye = base;
	float thick = 0.0;

	// Each panel dyed and faded a little apart from its neighbours.
	float cell = hash1(vec2(g, row));
	base *= 0.86 + 0.28 * cell * mix(0.6, 1.0, wear);
	// Sun-faded: drained toward its grey and lifted to a chalky pale, most on
	// the crown and shoulders where the sun sits.
	float sun_side = 1.0 - smoothstep(0.1, 0.62, v);
	float mottle = vnoise(vec2(u * 1.3, v * 11.0)) * 0.6 + vnoise(vec2(u * 4.1, v * 37.0)) * 0.4;
	float fade_k = clamp(0.2 + 0.4 * sun_side + (mottle - 0.5) * 0.5, 0.0, 1.0) * wear;
	base = mix(base, vec3(dot(base, vec3(0.3, 0.55, 0.15))), 0.3 * fade_k);
	base = mix(base, faded, 0.42 * fade_k);

	// Patches: a few panels carry a square of other cloth, sewn round.
	float bump = 0.0;
	float hp = hash1(vec2(g, row) + 31.7);
	if (hp < 0.075 && v > 0.08 && v < 0.9) {
		vec2 at = vec2(0.3 + 0.4 * hash1(vec2(g, row) + 3.3), 0.3 + 0.4 * hash1(vec2(g, row) + 9.1));
		vec2 half_size = vec2(0.14, 0.2) + 0.12 * vec2(hash1(vec2(row, g) + 5.0), hash1(vec2(row, g) + 6.0));
		vec2 q = (vec2(gu, rv) - at) / half_size;
		float inside = step(max(abs(q.x), abs(q.y)), 1.0);
		float border = inside * smoothstep(0.8, 0.9, max(abs(q.x), abs(q.y)));
		vec3 patch_tone = hp < 0.025 ? mix(base, vec3(0.5, 0.45, 0.36), 0.7) : (hp < 0.05 ? mix(base, tone_c, 0.8) : mix(base, tone_b, 0.6) * 0.9);
		base = mix(base, patch_tone * (0.9 + 0.2 * cell), inside);
		// The stitching round it: dashes of pale thread.
		float dash = step(0.5, fract((abs(q.x) > abs(q.y) ? q.y : q.x) * 5.0));
		base = mix(base, vec3(0.6, 0.56, 0.47), border * dash * fine * 0.8);
		bump += inside * 0.4;
		dye = mix(dye, patch_tone, inside);
		thick += inside * 0.5 + border * 0.3;
	}

	// The load tapes down each gore's edge and the seams across the panels.
	float tape_d = min(gu, 1.0 - gu);
	float tape = 1.0 - smoothstep(0.018, 0.03 + px * 0.8, tape_d);
	float seam_d = min(rv, 1.0 - rv) / panels;
	float seam = (1.0 - smoothstep(0.0012, 0.0022 + px * 0.06, seam_d)) * step(v, 0.925);
	base = mix(base, base * 0.42 + vec3(0.03, 0.025, 0.02), tape * 0.85);
	base = mix(base, base * 0.6, seam * 0.7 * mix(0.45, 1.0, fine));
	// Stitches beside the tapes, up close.
	float stitch = (1.0 - smoothstep(0.004, 0.008, abs(tape_d - 0.045))) * step(0.5, fract(v * 420.0));
	base = mix(base, vec3(0.62, 0.58, 0.5), stitch * finer * 0.7);
	bump -= tape * 0.8 + seam * 0.5;

	// Rain stains run down from the seams; grime gathers in the lower cloth.
	float streak = vnoise(vec2(u * 9.0, v * 2.2 + cell * 3.0));
	float stain = smoothstep(0.52, 0.8, streak) * smoothstep(0.1, 0.5, v);
	base *= 1.0 - 0.3 * stain;
	base = mix(base, base * vec3(0.8, 0.74, 0.62), 0.5 * smoothstep(0.45, 0.95, v) * (0.5 + 0.5 * mottle));
	// Soot licked up from the mouth.
	float lick = smoothstep(0.78 + 0.08 * vnoise(vec2(u * 2.0, 3.0)), 0.97, v);
	base = mix(base, soot, lick * 0.75 * (1.0 - skirt * 0.4));

	// The weave: a ripstop grid, up close.
	vec2 w = vec2(u * 26.0, v * 300.0);
	float grid = max(1.0 - smoothstep(0.03, 0.09, abs(fract(w.x) - 0.5) * 2.0 - 0.0), 0.0);
	grid = max(smoothstep(0.82, 0.95, abs(fract(w.x) - 0.5) * 2.0), smoothstep(0.82, 0.95, abs(fract(w.y) - 0.5) * 2.0));
	base *= 1.0 - 0.13 * grid * finer;
	bump += grid * finer * 0.12;

	// Wrinkles: the slack lower cloth hangs in soft folds between the tapes,
	// and the shudder's ripple shades as it moves.
	float folds = vnoise(vec2(u * 3.0, v * 5.0)) * smoothstep(0.35, 0.95, v);
	float height = bump * 0.02 + folds * 0.11 * fine + ripple * 0.34;
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	float hx = dFdx(height);
	float hy = dFdy(height);
	vec3 n = normalize(NORMAL);
	vec3 r1 = cross(dpy, n);
	vec3 r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	vec3 grad = sign(det) * (hx * r1 + hy * r2);
	vec3 bent = abs(det) * n - grad;
	// A sliver's derivatives can come out empty or not a number.
	NORMAL = (dot(bent, bent) > 1e-12 && !any(isnan(bent))) ? normalize(bent) : n;

	// (The tapes widen with distance to stay drawn: there they only dim it a little.)
	thick += mix(0.12, tape * 0.9, fine) + seam * 0.45 * fine + stain * 0.2 + lick * 0.25 + skirt * 0.5;
	bool inner = !FRONT_FACING;
	// The inside is the cloth's back: paler, the pattern showing through dimly.
	if (inner) base = mix(base, vec3(dot(base, vec3(0.333))), 0.35) * 0.8;
	ALBEDO = base;
	ROUGHNESS = 0.95;

	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, wn.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float rim_k = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	// Inside, only what comes in at the mouth and through the cloth.
	EMISSION = base * hemi * fill * (inner ? 0.55 : 1.0) + base * zs_hemi_sky * zs_hemi_energy * rim_k * rim * (inner ? 0.0 : 1.0);

	// The burner: the inside lit from the mouth up, and the glow coming
	// through the cloth, warmer and stronger low down, the seams dark in it.
	float flick_n = 0.0;
	if (burn > 0.0) {
		float flick = 0.82 + 0.18 * sin(TIME * 31.0 + seed * 5.0) * sin(TIME * 17.3 + 1.0);
		float up = 0.25 + 0.75 * smoothstep(0.0, 1.0, v) * smoothstep(0.0, 1.0, v);
		vec3 lit = flame_colour * burn * flick * up;
		if (inner) EMISSION += mix(base, vec3(0.5), 0.25) * lit * glow_inside;
		else EMISSION += mix(base, vec3(dot(base, vec3(0.333))), 0.2) * lit * glow_through * (1.0 - 0.7 * tape) * (1.0 - 0.6 * lick);
		flick_n = flick;
	}

	// The lantern: in the dark the burner's light fills the envelope and comes
	// through the cloth. Most low down by the flame, thinning to the crown;
	// each panel its own weight of cloth; the limb a little dimmer, so it
	// stays round.
	float dark = night * smoothstep(dark_from.x, dark_from.y, zs_daylight);
	if (dark > 0.001) {
		// The ember breathes; the burn flickers.
		float breath = 0.85 + 0.15 * sin(TIME * 1.3 + seed * 3.1) * sin(TIME * 0.83 + seed);
		float fired = glow * mix(1.0, flick_n, step(0.001, burn));
		float h = smoothstep(0.0, 0.92, v);
		// The burn fills the envelope; the ember only warms the cloth low down.
		// Far off, where a balloon is a few pixels, it is lifted and evened to read.
		float off = smoothstep(0.06, 0.4, px);
		float fall = mix(lantern_fall, 1.1, off);
		float reach = fired * mix(lantern_crown, 1.0, pow(h, fall)) + ember * mix(1.0, ember_far, off) * breath * (1.0 - fired) * mix(lantern_crown * 0.6, 1.0, pow(h, fall * 1.3));
		reach *= mix(1.0, lantern_far, off);
		// Deep red far from the flame, its own orange nearer, a hot heart
		// over it while it fires.
		float heart = smoothstep(0.5, 0.95, v) * fired;
		vec3 fire = mix(lantern_deep, flame_colour, smoothstep(0.1, 0.75, h));
		fire = mix(fire, lantern_hot, 0.55 * heart);
		if (inner) {
			EMISSION += mix(base, vec3(0.5), 0.25) * fire * reach * dark * glow_inside * lantern_inside;
		} else {
			// Each panel its own weight of cloth; tapes, seams, patches, soot
			// and the scoop pass little.
			float weight = (0.78 + 0.34 * cell) * clamp(1.0 - thick, 0.05, 1.0);
			// Pale cloth passes the flame's own colour, dyed cloth its dye,
			// dark cloth little.
			float top = max(max(dye.r, dye.g), max(dye.b, 0.001));
			vec3 tint = mix(vec3(1.0), dye / top, 0.8) * pow(top, 0.6) * 1.15;
			float facing = 0.6 + 0.4 * clamp(dot(n, VIEW), 0.0, 1.0);
			EMISSION += tint * fire * reach * weight * facing * dark * lantern;
		}
	}
}

void light() {
	// Wrapped a little, and the sun through the cloth on the far side.
	// A lamp (the burner's own, endless_balloons.gd) is left off the cloth:
	// the lantern term is its light there.
	float sun = LIGHT_IS_DIRECTIONAL ? 1.0 : 0.0;
	float nl = dot(NORMAL, LIGHT);
	float wrap = clamp((nl + 0.25) / 1.25, 0.0, 1.0);
	float back = clamp(-nl, 0.0, 1.0) * through;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (wrap + back) * sun / PI;
}
