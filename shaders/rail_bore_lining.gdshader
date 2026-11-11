shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The railroad tunnels' lining (scripts/endless/rail_bore.gd): the courses,
// bricks, rock and timber drawn from the mesh's UV, so the bore reads as
// built at speed without the triangles. UV: x along the line (m), y round
// the section (m). UV2.x the surface kind (rail_bore_mesh.gd K_*), UV2.y the
// soot over it (0..1). COLOR.rgb the base tint, per piece of stone already
// varied by the builder; COLOR.a the height over the bed (m / HEIGHT_SCALE,
// 1 where the builder gave none), which is where the wear is tied: dirt at
// the foot of a wall, damp and drips higher up.
//
// Worn the way a bore is: courses with depth (the mortar sunk, darker and
// rougher than the faces), stone to stone tone, damp streaks running down
// from the crown and the joints, soot along the crown, dirt at the foot,
// rust on the iron, checks in the timber. Everything reads one shared noise
// map (wear_tex), so near and far agree and no piece builds its own.
//
// Each joint fades out by its screen size (fwidth), so far courses blend to
// their average instead of shimmering.

uniform sampler2D wear_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
// 0 the clean stone of before, 1 the worn.
uniform float weather : hint_range(0.0, 1.0) = 1.0;
// Depth of the relief (a scale on the heights below).
uniform float relief = 1.0;
uniform float course_h = 1.0;
uniform float ashlar_len = 2.7;
uniform float brick_h = 0.42;
uniform float brick_len = 1.15;
uniform float joint = 0.07;
uniform float joint_dark = 0.45;
uniform vec3 soot_color : source_color = vec3(0.045, 0.04, 0.036);
// The lamps' light bounced round the bore: a faint fill, so the dark
// between their pools still shows the shape.
uniform float fill = 0.07;
// Out of doors (the portals): the sky's light on a face in shade, more on
// what faces up, as the ruins' stone takes it.
uniform float sky_fill = 0.0;
// The arch's half width and crown over the bed (m) on a portal's face, where the soot fans up from.
uniform float arch_half = 0.0;
uniform float arch_crown = 0.0;
uniform vec3 sky_tint : source_color = vec3(0.62, 0.70, 0.85);
uniform vec3 ground_tint : source_color = vec3(0.45, 0.42, 0.36);

const float HEIGHT_SCALE = 40.0;

varying vec2 kind_soot;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// One tap of the shared noise (0..1).
float W(vec2 p) {
	return texture(wear_tex, p).r;
}

// A running-bond pattern: x the joint's darkening (0 none, 1 full), y the
// block's own shade (-1..1), z the distance to the nearest joint (m), w a
// second per-block random (0..1). Courses `h` high, blocks `len` long.
vec4 bond(vec2 uv, float h, float len, float j) {
	float row = floor(uv.y / h);
	float x = uv.x / len + 0.5 * mod(row, 2.0);
	float col = floor(x);
	vec2 f = vec2(fract(x) * len, fract(uv.y / h) * h);
	vec2 w = fwidth(uv) + 1e-4;
	float dx = min(f.x, len - f.x);
	float dy = min(f.y, h - f.y);
	float jx = 1.0 - smoothstep(j * 0.5, j * 0.5 + w.x, dx);
	float jy = 1.0 - smoothstep(j * 0.5, j * 0.5 + w.y, dy);
	// The joints fade as they shrink under a pixel.
	float fade = 1.0 - smoothstep(0.25, 1.0, max(w.x / j, w.y / j) * 0.5);
	float jn = max(jx, jy) * fade;
	return vec4(jn, hash2(vec2(col, row)) * 2.0 - 1.0, min(dx, dy), hash2(vec2(row, col) + 7.3));
}

// The surface's normal bent by a height field `ht` (m) read off the
// screen's own derivatives, so there are no tangents to carry.
vec3 bump(float ht, vec3 vpos, vec3 nrm) {
	vec3 dpdx = dFdx(vpos);
	vec3 dpdy = dFdy(vpos);
	vec3 r1 = cross(dpdy, nrm);
	vec3 r2 = cross(nrm, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(ht) * r1 + dFdy(ht) * r2);
	float gl = length(grad);
	float cap = abs(det) * 1.2;
	if (gl > cap) grad *= cap / gl;
	return normalize(abs(det) * nrm - grad);
}

void vertex() {
	kind_soot = UV2;
}

void fragment() {
	float kind = floor(kind_soot.x + 0.5);
	vec3 base = COLOR.rgb;
	vec2 uv = UV;
	float hgt = COLOR.a * HEIGHT_SCALE;
	float wk = weather;
	bool outdoors = sky_fill > 0.0;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float far = smoothstep(0.03, 0.2, length(fwidth(uv)));
	float near_k = 1.0 - far;

	// The shared noise at its scales: broad blotches, medium, grit, and
	// the run that streaks down a wall (stretched along the section).
	float blotch = W(uv * 0.11 + vec2(0.13, 0.41));
	float mid = W(uv * 0.47 + vec2(0.71, 0.29));
	float grit = W(uv * 2.3 + vec2(0.37, 0.83));
	float run = W(vec2(uv.x * 0.3 + 0.27, uv.y * 0.05 + 0.52));
	float run2 = W(vec2(uv.x * 0.22 + 0.6, uv.y * 0.03 + 0.12));

	float shade = 0.0;
	float jn = 0.0;
	float ht = 0.0;
	float rough = 0.85;
	float rust = 0.0;
	float rib_wear = 0.0;
	float damp = 0.0;
	bool wall = true;

	if (kind < 0.5) {
		// Ashlar: dressed courses, each stone its own tone, tooled faces.
		vec4 b = bond(uv, course_h, ashlar_len, joint);
		jn = b.x;
		shade = b.y * 0.24 + (blotch - 0.5) * 0.34 + (grit - 0.5) * 0.14;
		base *= mix(1.0, 0.86, wk);
		// Some stones greyer, some warmer.
		base *= mix(vec3(0.94, 0.97, 1.02), vec3(1.07, 1.0, 0.9), b.w);
		ht = -jn * 0.045 + smoothstep(0.0, 0.14, b.z) * 0.014 * (0.6 + b.w * 0.8) + (grit - 0.5) * 0.02 + (mid - 0.5) * 0.03;
		rough = mix(0.78, 0.95, grit);
	} else if (kind < 1.5) {
		// Brick: small courses in a warmer, darker red, a burnt one now and then.
		vec4 b = bond(uv, brick_h, brick_len, joint * 0.8);
		jn = b.x * 0.85;
		float burnt = step(0.88, b.w);
		shade = b.y * 0.18 + (blotch - 0.5) * 0.2 + (grit - 0.5) * 0.12 - burnt * 0.22;
		base *= mix(vec3(1.0), vec3(0.92, 1.05, 1.12), step(0.8, b.w) * 0.5);
		ht = -jn * 0.03 + smoothstep(0.0, 0.05, b.z) * 0.008 + (grit - 0.5) * 0.012;
		rough = mix(0.8, 0.97, grit);
	} else if (kind < 2.5) {
		// Bare rock: broken, streaked by water down the walls, its strata
		// weathering back in bands.
		float n = W(uv * vec2(0.09, 0.14) + 0.3);
		float cr = W(uv * 0.12 + 0.77);
		float cracks = 1.0 - smoothstep(0.0, 0.035 + fwidth(cr) * 2.0, abs(cr - 0.5));
		float strata = W(vec2(uv.x * 0.012, uv.y * 0.16) + 0.5);
		shade = (n - 0.5) * 0.5 + (run2 - 0.5) * 0.2 + (strata - 0.5) * 0.4 + (grit - 0.5) * 0.1;
		jn = cracks * 0.2 * near_k;
		// A soft band weathers back, a hard one stands.
		ht = (n - 0.5) * 0.3 + smoothstep(0.3, 0.7, strata) * 0.1 + (grit - 0.5) * 0.04 - cracks * 0.06;
		rough = mix(0.8, 1.0, grit);
		// Damp holds in the strata's troughs.
		damp = smoothstep(0.42, 0.3, strata) * 0.55;
	} else if (kind < 3.5) {
		// Timber: grain along the beam (UV y runs along it), checks, ends.
		float g = W(vec2(uv.x * 5.0, uv.y * 0.35) + 0.2);
		float g2 = W(vec2(uv.x * 14.0, uv.y * 0.9) + 0.6);
		float chk = 1.0 - smoothstep(0.0, 0.035 + fwidth(g) * 2.0, abs(W(vec2(uv.x * 3.0, uv.y * 0.22) + 0.9) - 0.5));
		shade = (g - 0.5) * 0.2 + (g2 - 0.5) * 0.12 + (blotch - 0.5) * 0.2 - chk * 0.22;
		ht = (g - 0.5) * 0.008 - chk * 0.02;
		jn = chk * 0.4 * near_k;
		rough = mix(0.82, 0.96, g2);
		// Weathered grey-brown, darker with age.
		base = mix(base, base * vec3(0.78, 0.74, 0.72), 0.7 * wk);
	} else if (kind < 4.5) {
		// The floor: ballast, speckled.
		shade = (grit - 0.5) * 0.35 + (blotch - 0.5) * 0.2;
		ht = (grit - 0.5) * 0.05;
		rough = 0.97;
		wall = false;
	} else if (kind < 5.5) {
		// The drain: an iron grate across its channel.
		float bars = abs(fract(uv.x / 0.35) - 0.5);
		jn = (1.0 - smoothstep(0.18, 0.18 + fwidth(uv.x) / 0.35 * 2.0, bars)) * (1.0 - smoothstep(0.2, 0.8, fwidth(uv.x)));
		shade = -0.2;
		rough = 0.7;
		rust = smoothstep(0.45, 0.7, blotch) * 0.6;
		wall = false;
	} else if (kind < 6.5) {
		// Dressed stone in single pieces (voussoirs, keystone, coping, ribs):
		// a tone each, the faces pitted.
		float piece = hash2(floor(uv * 0.9) + floor(base.rg * 61.0));
		shade = (blotch - 0.5) * 0.3 + (grit - 0.5) * 0.18 + (piece - 0.5) * 0.14;
		ht = (grit - 0.5) * 0.02 + (mid - 0.5) * 0.02;
		rough = mix(0.8, 0.95, grit);
		rib_wear = 1.0;
	} else {
		// Iron: dull, pitted, rusted in patches.
		shade = (grit - 0.5) * 0.2;
		ht = (grit - 0.5) * 0.01;
		rough = 0.72;
		rust = smoothstep(0.38, 0.62, blotch * 0.6 + mid * 0.4) * (0.5 + 0.6 * (1.0 - abs(wn.y)));
	}

	// ---- The relief ------------------------------------------------------
	ht *= relief * wk * near_k;
	if (wk > 0.0) NORMAL = bump(ht, VERTEX, NORMAL);

	vec3 c = base * (1.0 + shade * mix(0.55, 1.0, wk));

	// Mortar: darker and rougher than the faces.
	c = mix(c, c * joint_dark, jn);
	rough = mix(rough, 1.0, jn * 0.9);

	// ---- Wear tied to where it happens ------------------------------------
	float vert = 1.0 - abs(wn.y);
	float flat_up = smoothstep(0.5, 0.95, wn.y);
	float under = smoothstep(-0.3, -0.9, wn.y);

	// Damp streaks running down: from the crown and from the joints, dark
	// and smooth where wet; a pale mineral crust at the joints they run from.
	float up = smoothstep(0.6, 4.0, hgt);
	float drip = smoothstep(0.55, 0.8, run) * (0.35 + 0.65 * smoothstep(0.35, 0.7, blotch)) * mix(0.5, 1.0, up);
	float wetness = clamp(drip * vert * (1.0 - flat_up), 0.0, 1.0);
	wetness = max(wetness, damp * 0.6);
	wetness *= wk * (1.0 - far * 0.5);
	c *= 1.0 - 0.38 * wetness;
	float crust = clamp(jn * smoothstep(0.6, 0.85, run) * wk * 1.2, 0.0, 1.0);
	if (kind < 2.0) c = mix(c, vec3(0.7, 0.66, 0.58) * (0.35 + 0.65 * dot(c, vec3(0.3, 0.55, 0.15))), crust * 0.5);
	rough = mix(rough, 0.62, wetness * 0.8 * near_k);

	// Dirt at the foot of a wall, splashed and wicked up in a ragged line.
	float foot_top = 0.45 + 0.9 * mid;
	float foot = (1.0 - smoothstep(foot_top * 0.4, foot_top + 0.5, hgt)) * vert * (wall ? 1.0 : 0.0);
	foot *= wk * (0.45 + 0.7 * blotch);
	c = mix(c, c * vec3(0.4, 0.34, 0.27), clamp(foot, 0.0, 0.8));
	rough = mix(rough, 1.0, clamp(foot, 0.0, 1.0) * 0.6);

	// Soot: thick at its source, along the crown, running down it in
	// fingers where the draught carries it; the undersides of ribs and
	// ledges, which catch it, take a veil.
	float soot = kind_soot.y;
	float fingers = smoothstep(0.45, 0.85, run2) * 0.5 + 0.5;
	soot = clamp(soot * (0.55 + 0.9 * blotch) * mix(1.0, fingers + 0.25, wk), 0.0, 1.0);
	soot = clamp(soot + wk * under * 0.25 * (0.4 + blotch), 0.0, 1.0);
	if (outdoors && arch_half > 0.0 && wk > 0.0 && vert > 0.6) {
		// A portal's face: soot fanning up and out from the arch, in plumes.
		float spread = arch_half * 0.9 + 3.0 + max(uv.y - arch_crown, 0.0) * 0.55;
		float fa = clamp(1.0 - abs(uv.x) / spread, 0.0, 1.0);
		float fan = fa * fa * smoothstep(arch_crown * 0.45, arch_crown * 0.9, uv.y) * (1.0 - smoothstep(arch_crown, arch_crown + 8.0, uv.y));
		fan *= (0.55 + 0.7 * blotch) * (0.75 + 0.35 * mid);
		soot = clamp(soot + fan * 0.65 * wk, 0.0, 1.0);
	}
	c = mix(c, soot_color, soot * (outdoors ? 0.9 : 1.0));
	rough = mix(rough, 0.97, soot * 0.7);

	// Outdoors: weathered from the top down. Rain streaks under copings and
	// the keystone, moss and damp low down, a duller grey over all.
	if (outdoors && wk > 0.0) {
		float low = 1.0 - smoothstep(0.0, 2.6, hgt);
		float moss = low * smoothstep(0.42, 0.7, mid) * (0.4 + 0.6 * blotch) * vert * wk;
		c = mix(c, vec3(0.12, 0.16, 0.07) * (0.6 + c.g), clamp(moss, 0.0, 0.7));
		float dark_rain = smoothstep(0.42, 0.72, run) * vert * wk * (0.3 + 0.7 * smoothstep(1.0, 7.0, hgt));
		c *= 1.0 - 0.42 * dark_rain;
		// Run-off from the top edge: the stone under a coping stays darker.
		c *= 1.0 - 0.18 * wk * vert * smoothstep(0.35, 0.65, run2) * smoothstep(5.0, 12.0, hgt);
		c *= 0.96;
		c *= mix(1.0, 0.82, wk * flat_up * (0.4 + blotch));
		rough = mix(rough, 0.55, dark_rain * 0.4);
	}

	// A weathered stone is duller than the builder's tint.
	float luma = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(c, vec3(luma), 0.12 * wk);

	// Iron: dull dark metal, rust in the rough.
	if (kind > 6.5 || (kind > 4.5 && kind < 5.5)) {
		vec3 rust_c = vec3(0.30, 0.13, 0.055) * (0.6 + 0.9 * grit);
		float r = clamp(rust * wk, 0.0, 1.0);
		c = mix(c, rust_c, r);
		rough = mix(rough, 0.95, r);
	}

	ALBEDO = c;
	ROUGHNESS = clamp(rough + (grit - 0.5) * 0.12 * wk, 0.25, 1.0);
	SPECULAR = mix(0.3, 0.2, wk) + 0.12 * wetness * near_k;
	float fill_k = mix(1.0, mix(0.7, 1.15, clamp(wn.y * 0.5 + 0.5, 0.0, 1.0)), wk);
	EMISSION = c * fill * fill_k * (1.0 - 0.35 * jn * wk) + c * sky_fill * mix(ground_tint, sky_tint, wn.y * 0.5 + 0.5) * (1.0 - 0.3 * jn * wk);
}
