shader_type spatial;
render_mode diffuse_lambert;
// The pilot on foot (scripts/pilot_paint.gd, the model from art/blender/pilot/
// pilot_build.py): soft painted, not lacquered. The sun's light falls in a few
// soft bands (lit, half lit, shade) instead of a smooth gradient, a warm tint
// on the lit side; the shade takes the sky's hemisphere as the folk do
// (shaders/folk_surface.gdshaderinc: the world takes no ambient), cooled; a
// gentle sky rim on the edges; no gloss. Flat colours are broken up by a
// slow mottle and brush-like streaks laid in the body's REST position (its
// UV maps carry it, so the paint stays on the cloth as he moves), and a
// part's own number shifts its colour a touch, so neighbouring pieces of one
// colour read as painted separately; the band edges wander with the same
// noise, as a brush would leave them.
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;

uniform vec4 albedo : source_color = vec4(1.0);
// The shade's colour as a share of the lit (before the hemisphere's fill).
uniform float fill = 3.2;
// Warmth on the lit side, coolness in the shade.
uniform vec3 warm = vec3(1.06, 1.0, 0.9);
uniform vec3 cool = vec3(0.86, 0.92, 1.08);
// The bands: where the light turns to half and to full (in N.L), and how
// soft each step is.
uniform float half_at = -0.05;
uniform float full_at = 0.38;
uniform float soft = 0.09;
uniform float half_share = 0.55;
uniform float rim = 0.12;
// The sun's share (the bands' top), under 1 so the lit side doesn't burn out.
uniform float sun = 0.5;
// The paint: how strong the mottle and the streaks are, how big (per metre).
uniform float mottle = 0.1;
uniform float streaks = 0.07;
uniform float paint_scale = 9.0;
uniform float wobble = 0.08;
// Glass (the goggles' lenses): the sky and ground reflected, stronger at a
// glance (fresnel), a small catchlight from the bright sky above that slides
// over the lens as the view turns, and the sun's own glint. All of it is
// light the lens gives back, so it dims with the sky at night; it never
// glows of itself.
uniform float sheen = 0.0;
// Wet from wading or a swim (scripts/pilot_figure.gd `soak`): up to
// `wet_line` (m, in the rest position's height, so it rides the body) the
// cloth is darkened by `wet_dark`, `wet` 1 soaked drying back to 0.
uniform float wet = 0.0;
uniform float wet_line = 0.0;
uniform float wet_dark = 0.32;
// Lit of itself (the bracelets' stripes): emission as this share of the
// colour, clean over the paint.
uniform float glow = 0.0;
// Gone (the hat, flown off overhead as the pocket sail): not drawn.
uniform float gone = 0.0;
// The face (scripts/pilot_figure.gd drives these): two glowing pill eyes
// painted on the dark head, placed in the rest position (Blender metres:
// x right, y forward, z up; art/blender/pilot/pilot_build.py prints
// PILOT_EYES): the point between them on the head's front, each one's
// middle `eye_apart` out from it, `eye_half` its half height. The
// expressions, 0 to 1 each, morph the pills: `blink` shuts them to a line,
// `happy` bends them into ^ ^ arcs, `surprise` opens them wider and rounder,
// `squint` flattens them under lids slanting down to the middle.
uniform float eyes = 0.0;
uniform vec3 eye_at = vec3(0.0, 0.21, 0.9348);
uniform float eye_apart = 0.0721;
uniform float eye_half = 0.0531;
uniform vec4 eye_colour : source_color = vec4(0.373, 0.902, 0.902, 1.0);
uniform float eye_glow = 2.4;
uniform float blink = 0.0;
uniform float happy = 0.0;
uniform float surprise = 0.0;
uniform float squint = 0.0;
// The worn look (scripts/pilot_paint.gd LOOKS; all 0 is the old clean
// paint). What the stuff is, each 0 to 1, laid over the rest position (Blender
// metres) projected three ways by the rest surface's own facing:
//   cloth   a homespun weave, threads `thread` m apart (twill > 0.5 slants
//           it as denim's), the threads raised and the gaps dark;
//   knit    rows of chevron stitches `thread` m tall;
//   felt    fine matted fibre and a soft sheen at a glance;
//   leather a fine pebbled grain, pale scuffs and darker oiled patches;
//   metal   dull worn brass: dark tarnish and a grey-green patina in the
//           low spots, the high spots rubbed bright.
uniform float cloth = 0.0;
uniform float knit = 0.0;
uniform float felt = 0.0;
uniform float leather = 0.0;
uniform float metal = 0.0;
uniform float thread = 0.012;
uniform float twill = 0.0;
// How lived in, each 0 to 1: dust rising from the boots to `dust_top` (m)
// in the turf's ochre and settled on what faces up; the sun's fade on top
// (paler, greyer); grime in soft dark blotches, lower and underneath; wear
// on the rolled edges and the rubbed places (paler, threadbare).
uniform float dust = 0.0;
uniform float dust_top = 0.32;
uniform vec4 dust_colour : source_color = vec4(0.56, 0.43, 0.29, 1.0);
uniform float fade = 0.0;
uniform float grime = 0.0;
uniform float wear = 0.0;
// The weave, grain and scuffs cut into the normal.
uniform float bump = 0.0;
// The light's bands: 1 the toon steps, 0 a plain soft terminator, as the
// stone's.
uniform float bands = 1.0;

varying vec3 rest;
varying float own;

void vertex() {
	rest = vec3(UV.x, 1.0 - UV.y, UV2.x);
	own = UV2.y;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

varying float paint;

vec3 h33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

float fbm3(vec3 p) {
	return noise3(p) * 0.55 + noise3(p * 2.13 + 7.7) * 0.3 + noise3(p * 4.37 + 3.1) * 0.15;
}

// Cellular: x the nearest point's distance, y the second's, z the cell's own.
vec3 cells(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	float id = 0.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = h33(i + g);
				float d = length(g + o - f);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					id = o.x;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
	}
	return vec3(d1, d2, id);
}

// A woven cloth's height (0 the gaps, 1 a thread's crown) at uv (in
// threads), plain or twill.
float weave(vec2 uv, float tw) {
	vec2 c = floor(uv);
	vec2 f = fract(uv);
	float plain = mod(c.x + c.y, 2.0);
	float diag = step(1.5, mod(c.x + c.y * 3.0, 4.0) );
	float over = mix(plain, diag, tw);
	// Each thread rounded across its width, pinched where it dives under.
	float warp = sin(f.x * PI) * (0.65 + 0.35 * sin(f.y * PI));
	float weft = sin(f.y * PI) * (0.65 + 0.35 * sin(f.x * PI));
	return mix(weft, warp, over);
}

// Knit: rows of V stitches, each a rounded loop.
float knit_rows(vec2 uv) {
	float row = uv.y + abs(fract(uv.x) - 0.5) * 0.9;
	return sin(fract(row) * PI) * (0.7 + 0.3 * sin(fract(uv.x * 2.0) * PI));
}

// One eye's distance field (negative inside), in its half heights about
// its middle, x out from the face's middle.
float eye_field(vec2 q) {
	float hh = mix(mix(1.0, 0.6, squint) * (1.0 + 0.14 * surprise), 0.13, blink);
	vec2 b = vec2(0.4 + 0.14 * surprise + 0.08 * blink, hh);
	float r = min(b.x, b.y);
	vec2 d = abs(q) - b + r;
	float pill = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
	// The squint's lid, slanting down to the inner corner.
	float lid = q.y - (0.12 + 0.55 * q.x);
	pill = mix(pill, max(pill, lid), squint);
	// A ^ arc, rounded at its ends.
	vec2 c = q - vec2(0.0, -0.4);
	float arc = c.y > 0.0 ? abs(length(c) - 0.72) - 0.19 : length(vec2(abs(c.x) - 0.72, c.y)) - 0.19;
	return mix(pill, arc, happy);
}

void fragment() {
	if (gone > 0.5) discard;
	vec3 p = rest * paint_scale;
	float m = noise3(p) * 0.6 + noise3(p * 2.3 + 7.1) * 0.4;
	// Streaks: noise stretched along a slanting stroke.
	float s = noise3(vec3(p.x * 5.0 + p.z * 3.0, p.y * 0.8 - p.x * 0.6, p.z * 5.0 - p.y)) - 0.5;
	paint = m;
	vec3 base = albedo.rgb;
	base *= 1.0 + (m - 0.5) * 2.0 * mottle + s * 2.0 * streaks;
	// A part's own shift, a little warmer or cooler.
	base *= mix(vec3(1.03, 1.0, 0.96), vec3(0.97, 1.0, 1.04), own) ;
	// The worn look. How big a pixel is on the cloth (m): the threads fade
	// to their mean as it nears one, the mid layers later.
	float px = length(fwidth(rest));
	float f_fine = 1.0 - smoothstep(thread * 0.22, thread * 0.6, px);
	float f_mid = 1.0 - smoothstep(0.015, 0.06, px);
	// The rest surface's facing (outward: its winding matched to the view's),
	// and the share each of the three projections takes.
	vec3 rx = dFdx(rest);
	vec3 ry = dFdy(rest);
	vec3 rn = cross(rx, ry);
	rn *= sign(dot(cross(dFdx(VERTEX), dFdy(VERTEX)), NORMAL));
	rn = dot(rn, rn) > 1e-14 ? normalize(rn) : vec3(0.0, 0.0, 1.0);
	vec3 tri = pow(abs(rn), vec3(4.0));
	tri /= tri.x + tri.y + tri.z;
	float upn = rn.z;
	float height = 0.0;
	if (cloth + knit + felt + leather + metal > 0.0) {
		vec3 q = rest / thread;
		if (cloth > 0.0) {
			float g = weave(q.yz, twill) * tri.x + weave(q.xz, twill) * tri.y + weave(q.xy, twill) * tri.z;
			// Slubs: threads a little thicker and thinner along their run.
			float slub = noise3(vec3(rest.x * 9.0, rest.y * 9.0, rest.z * 140.0)) * 0.5 + noise3(vec3(rest.x * 140.0, rest.y * 140.0, rest.z * 9.0)) * 0.5;
			base *= mix(1.0, mix(0.84, 1.05, g) * mix(0.93, 1.05, slub), cloth * f_fine);
			base *= 1.0 + (slub - 0.5) * 0.12 * cloth * f_mid;
			height += (g - 0.5) * thread * 0.3 * cloth * f_fine;
		}
		if (knit > 0.0) {
			float g = knit_rows(vec2(q.y * 0.8, q.z)) * tri.x + knit_rows(vec2(q.x * 0.8, q.z)) * tri.y + knit_rows(vec2(q.x * 0.8, q.y)) * tri.z;
			base *= mix(1.0, mix(0.7, 1.08, g), knit * f_fine);
			base *= 1.0 + (noise3(vec3(rest.x * 30.0, rest.y * 30.0, floor(q.z) * 3.1)) - 0.5) * 0.18 * knit * f_mid;
			// Fuzz pilled up off the yarn.
			base *= 1.0 + (noise3(rest * 160.0) - 0.5) * 0.16 * knit * f_mid;
			height += (g - 0.5) * thread * 0.7 * knit * f_fine;
		}
		if (felt > 0.0) {
			float fib = (noise3(rest * 260.0) - 0.5) * f_fine + (noise3(rest * 70.0 + 3.0) - 0.5) * f_mid;
			base *= 1.0 + fib * 0.22 * felt;
			height += fib * 0.0015 * felt;
		}
		if (leather > 0.0) {
			// The grain: small pebbles, each its own tone, a seam between.
			vec3 lc = cells(rest / 0.0045 + 13.0);
			float lgap = lc.y - lc.x;
			float lf = 1.0 - smoothstep(0.002, 0.006, px);
			base *= mix(1.0, mix(0.86, 1.06, lc.z) * mix(0.82, 1.0, smoothstep(0.0, 0.25, lgap)), leather * lf);
			// Creases: a web of fine dark lines where it has bent.
			vec3 cr = cells(rest * 28.0 + 5.0);
			float crease = (1.0 - smoothstep(0.0, max(0.035, px * 25.0), cr.y - cr.x)) * smoothstep(0.6, 0.8, fbm3(rest * 9.0 + 2.0));
			// Oiled darker patches, scuffed pale ones, the scuffs drawn out.
			float oiled = smoothstep(0.4, 0.75, fbm3(rest * 6.0 + 31.0));
			float scuff = smoothstep(0.6, 0.82, fbm3(vec3(rest.x * 22.0, rest.y * 22.0, rest.z * 5.0) + 17.0));
			base *= 1.0 - oiled * 0.22 * leather - crease * 0.18 * leather * (0.4 + 0.6 * f_mid);
			base = mix(base, base * vec3(1.55, 1.45, 1.3) + 0.03, scuff * 0.55 * leather);
			height += (smoothstep(0.0, 0.3, lgap) * 0.0006 * lf - crease * 0.002) * leather;
		}
		if (metal > 0.0) {
			float t = fbm3(rest * 40.0 + 9.0);
			float pat = smoothstep(0.55, 0.78, fbm3(rest * 28.0 + 51.0));
			float rub = smoothstep(0.62, 0.8, noise3(rest * 70.0 + 1.0));
			base *= mix(1.0, mix(0.55, 0.95, t), metal);
			base = mix(base, vec3(0.34, 0.4, 0.33) * (0.8 + 0.3 * t), pat * 0.65 * metal);
			base = mix(base, base * 1.5 + vec3(0.05, 0.04, 0.02), rub * (1.0 - pat) * 0.5 * metal);
			height += (t - 0.5) * 0.002 * metal;
		}
	}
	if (dust + fade + grime + wear > 0.0) {
		float n1 = fbm3(rest * 7.0 + 23.0);
		float n2 = fbm3(rest * 19.0 + 3.0);
		// Wear: the rolled edges (where the facing turns fast) and rubbed
		// patches go paler and flatter.
		float curv = length(fwidth(rn)) / max(length(fwidth(rest)), 1e-5);
		float edge_w = smoothstep(30.0, 90.0, curv) * smoothstep(0.4, 0.6, n2);
		float rubbed = smoothstep(0.62, 0.82, n1);
		float w = clamp(edge_w + rubbed * 0.6, 0.0, 1.0) * wear;
		base = mix(base, mix(base, vec3(dot(base, vec3(0.333))), 0.4) * 1.45 + 0.02, w * 0.6);
		height *= 1.0 - w * 0.6;
		// Grime: soft dark blotches, more low down and underneath.
		float low = 1.0 - smoothstep(0.2, 0.9, rest.z);
		float g = smoothstep(0.42, 0.75, n1 * 0.7 + n2 * 0.3 + low * 0.25 - upn * 0.15);
		base *= 1.0 - g * 0.38 * grime;
		// The sun's fade: what faces the sky paler and greyer, unevenly.
		float sun_side = smoothstep(-0.3, 0.9, upn) * (0.55 + 0.45 * smoothstep(0.3, 0.7, n2));
		vec3 grey = vec3(dot(base, vec3(0.3, 0.55, 0.15)));
		base = mix(base, mix(base, grey, 0.5) * 1.12 + vec3(0.02, 0.015, 0.0), sun_side * fade);
		// Dust: up from the boots in a ragged line, and settled on the tops.
		float rise = 1.0 - smoothstep(dust_top * 0.3, dust_top, rest.z + (n1 - 0.5) * 0.14);
		float settle = smoothstep(0.6, 0.95, upn) * smoothstep(0.45, 0.7, n2) * 0.55;
		float d = clamp(rise + settle, 0.0, 1.0) * dust;
		vec3 dc = dust_colour.rgb * (0.85 + 0.3 * n2);
		base = mix(base, dc, d * 0.55);
		height *= 1.0 - d * 0.5;
	}
	base *= 1.0 - wet_dark * wet * (1.0 - smoothstep(wet_line - 0.03 + (m - 0.5) * 0.04, wet_line + 0.02, rest.z));
	ALBEDO = clamp(base, 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	if (bump > 0.0) {
		vec3 sx = dFdx(VERTEX);
		vec3 sy = dFdy(VERTEX);
		vec3 r1 = cross(sy, NORMAL);
		vec3 r2 = cross(NORMAL, sx);
		float det = dot(sx, r1);
		vec3 grad = sign(det) * (dFdx(height) * r1 + dFdy(height) * r2);
		NORMAL = normalize(abs(det) * NORMAL - bump * grad);
	}
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = smoothstep(0.6, 0.95, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	EMISSION = ALBEDO * cool * hemi * fill
		// The rim takes the sky's brightness, not its tint, so it doesn't
		// glare green or blue on the edges in the sun.
		+ mix(ALBEDO, vec3(1.0), 0.5) * dot(zs_hemi_sky, vec3(0.3333)) * zs_hemi_energy * edge * rim;
	// Felt's soft sheen at a glance: the fibres catching the sky.
	EMISSION += mix(ALBEDO, vec3(0.6), 0.5) * dot(zs_hemi_sky, vec3(0.3333)) * zs_hemi_energy
		* pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0) * felt * 0.08;
	if (glow > 0.0) {
		ALBEDO = albedo.rgb;
		EMISSION += albedo.rgb * glow;
	}
	if (eyes > 0.0) {
		vec2 e = vec2(abs(rest.x - eye_at.x) - eye_apart, rest.z - eye_at.z) / eye_half;
		float front = smoothstep(eye_at.y - 0.09, eye_at.y - 0.05, rest.y) * eyes;
		float d = eye_field(e);
		float aa = max(fwidth(d), 0.03);
		float lit = (1.0 - smoothstep(-aa, aa, d)) * front;
		float halo = exp(-max(d, 0.0) * 3.5) * front * 0.22;
		ALBEDO = mix(ALBEDO, eye_colour.rgb * 0.6, lit);
		EMISSION = mix(EMISSION, vec3(0.0), lit) + eye_colour.rgb * (lit * eye_glow + halo);
	}
	if (sheen > 0.0) {
		vec3 view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 r = reflect(-view, normal);
		float fresnel = 0.2 + 0.8 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		vec3 seen = mix(zs_hemi_ground * 0.6, zs_hemi_sky, smoothstep(-0.25, 0.5, r.y)) * zs_hemi_energy;
		float catchlight = smoothstep(0.93, 0.975, dot(r, normalize(vec3(0.3, 0.85, 0.4))));
		EMISSION += (seen * fresnel * 0.5 + zs_hemi_sky * zs_hemi_energy * catchlight * 1.2) * sheen;
	}
}

void light() {
	float nl = dot(NORMAL, LIGHT) + (paint - 0.5) * wobble * 2.0;
	float lit = mix(smoothstep(half_at - soft, half_at + soft, nl) * half_share, 1.0,
		smoothstep(full_at - soft, full_at + soft, nl));
	lit = mix(smoothstep(-0.15, 0.75, nl), lit, bands);
	// Shadows step too, softly.
	float shadow = smoothstep(0.25, 0.65, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * warm * lit * shadow * sun / PI;
	if (sheen > 0.0) {
		float glint = pow(max(dot(reflect(-LIGHT, NORMAL), VIEW), 0.0), 90.0);
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * glint * sheen * 0.4;
	}
}
