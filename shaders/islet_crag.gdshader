shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// The islet unit's crag rock (scripts/kit_isle/islet_crag.gd), round 2's
// rock (shaders/islet_rock.gdshader: triplanar in the mesh's own space,
// joints, seams, grain, a value gradient, the sky's fill) pushed toward a
// cut through real ground and broken stone:
//   strata   bands of several stones (pale sand, ochre clay, grey, dark
//            shale), each block's bands offset by its own share (COLOR.b),
//            so they break at the buttresses; streaked down the faces
//   joints   bigger, angular blocks (Voronoi cells squared off)
//   topsoil  a dark earth skin under the rim where the turf runs to the
//            edge (COLOR.a), root threads in it
//   green    moss on what faces up (ledges, steps, the cap) and streaks of
//            green carried down the face from the rim (COLOR.g)
// COLOR.r is the baked shade.
uniform vec3 bone : source_color = vec3(0.72, 0.70, 0.66);
uniform vec3 ash : source_color = vec3(0.54, 0.52, 0.50);
uniform vec3 under : source_color = vec3(0.33, 0.33, 0.36);
uniform vec3 umber : source_color = vec3(0.30, 0.23, 0.17);
uniform vec3 sand : source_color = vec3(0.84, 0.79, 0.68);
uniform vec3 clay : source_color = vec3(0.70, 0.56, 0.42);
uniform vec3 grey : source_color = vec3(0.64, 0.63, 0.60);
uniform vec3 shale : source_color = vec3(0.40, 0.40, 0.42);
uniform vec3 soil : source_color = vec3(0.26, 0.20, 0.15);
uniform vec3 moss : source_color = vec3(0.33, 0.38, 0.18);
uniform vec3 moss_lit : source_color = vec3(0.50, 0.53, 0.27);
uniform float top_y = 0.0;
uniform float bottom_y = -10.0;
uniform float weather = 0.5;
uniform float bed_scale = 1.0;
uniform float band_m = 1.4;
uniform float strata = 0.85;
uniform float greenery = 1.0;
uniform vec3 seed_off = vec3(0.0);
uniform float bump_depth = 1.0;
uniform float block_tilt = 0.6;
uniform float fill = 1.0;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform vec3 zs_cloud_sun;
#include "res://shaders/look_fill.gdshaderinc"
vec3 islet_hemi(vec3 wn) {
	return mix(zs_hemi_ground, zs_hemi_sky, wn.y * 0.5 + 0.5) * zs_hemi_energy / PI;
}

varying vec3 v_pos;
varying vec3 v_nrm;

float hash1(float n) { return fract(sin(n * 127.1) * 43758.5453); }
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}
float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
				   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
				   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + 11.0) * 0.3 + vnoise(p * 4.1 + 23.0) * 0.15;
}

// A squared-off Voronoi (Chebyshev-leaning distance): x the distance to the
// nearest edge, yz the cell's own pair.
vec3 cell(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 id = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = hash2(i + g) * 0.8 + 0.1;
			vec2 r = abs(g + o - f);
			float d = mix(length(r), max(r.x, r.y), 0.25);
			if (d < d1) { d2 = d1; d1 = d; id = i + g; } else if (d < d2) { d2 = d; }
		}
	}
	return vec3(d2 - d1, hash2(id + 17.31));
}

//VERTEX_BEGIN
void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}
//VERTEX_END

void fragment() {
	vec3 p = v_pos * bed_scale + seed_off;
	vec3 n = normalize(v_nrm);
	vec3 wgt = pow(abs(n), vec3(4.0));
	wgt /= (wgt.x + wgt.y + wgt.z);
	float foot = length(fwidth(p));
	float fine = 1.0 - smoothstep(0.05, 0.35, foot);
	float mid = 1.0 - smoothstep(0.25, 1.2, foot);
	float side = 1.0 - smoothstep(0.45, 0.8, abs(n.y));
	vec3 wn = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);

	// Strata: bands by height, each block's offset its own (COLOR.b),
	// warped a little; a stone each band, laminae within.
	float shift = (COLOR.b - 0.5) * band_m * 1.1;
	float warp = (fbm(p * 0.15) - 0.5) * 1.2 + (vnoise(p * 0.8) - 0.5) * 0.25;
	float yb = (v_pos.y + shift) / band_m + warp + (vnoise(p * 1.6 + 5.0) - 0.5) * 0.18 * mid;
	float bed_id = floor(yb);
	float bed = fract(yb);
	float pick = hash1(bed_id * 1.37 + seed_off.x);
	vec3 band_c = pick < 0.3 ? sand : (pick < 0.52 ? clay : (pick < 0.8 ? grey : shale));
	// Thin beds of the next stone inside the thick ones.
	float pick2 = hash1(bed_id * 3.11 + 7.0 + seed_off.z);
	vec3 band_b = pick2 < 0.5 ? grey : sand;
	float thin = smoothstep(0.55, 0.6, bed) * (1.0 - smoothstep(0.68, 0.73, bed)) * step(0.45, hash1(bed_id + 91.0));
	band_c = mix(band_c, band_b, thin * 0.7);
	band_c = mix(band_c, vec3(dot(band_c, vec3(0.33))), 0.3);
	float seam_w = 0.035 + 0.04 * vnoise(p * 1.7);
	float seam = (1.0 - smoothstep(0.0, seam_w, min(bed, 1.0 - bed))) * mid;
	float lam = fract(yb * 5.0 + vnoise(p * 2.0) * 0.6);
	float lamina = (1.0 - smoothstep(0.0, 0.18, min(lam, 1.0 - lam))) * fine * 0.12;

	// Joints: angular blocks on the sides (tall across a band) and the top.
	vec2 sx = vec2(p.z * 0.75, p.y * 0.42 + bed_id * 0.37);
	vec2 sz = vec2(p.x * 0.75, p.y * 0.42 + bed_id * 0.37);
	vec2 sy = p.xz * 0.55;
	float jw = 0.04;
	vec3 cx = cell(sx);
	vec3 cz = cell(sz);
	vec3 cy = cell(sy);
	float jx = 1.0 - smoothstep(0.0, jw, cx.x);
	float jz = 1.0 - smoothstep(0.0, jw, cz.x);
	float jy = 1.0 - smoothstep(0.0, jw * 1.2, cy.x);
	vec2 blk = (cx.yz * wgt.x + cz.yz * wgt.z + cy.yz * wgt.y);
	vec3 tilt = vec3(blk.x - 0.5, (blk.y - 0.5) * 0.6, (blk.y + blk.x) * 0.5 - 0.5) * mid;
	float upf = smoothstep(0.4, 0.8, n.y);
	float joint = ((jx * wgt.x + jz * wgt.z) / max(wgt.x + wgt.z, 0.001) * side + jy * upf * 0.7) * mid;
	joint *= smoothstep(0.42, 0.68, vnoise(p * 0.5 + 29.0) + 0.25 * weather);
	float grain = mix(0.5, vnoise(p * 7.0), fine);
	float pits = mix(0.5, vnoise(p * 2.6 + 5.0), mid);
	float spall = fbm(p * 0.8 + 41.0);
	seam *= mix(0.3, 1.0, side);
	float crack = max(seam * 0.8, joint * (0.55 + 0.45 * weather));

	// Value from top to bottom; faces turned down darker and cooler.
	float h = clamp((v_pos.y - bottom_y) / max(top_y - bottom_y, 0.01), 0.0, 1.0);
	vec3 c = mix(under, ash, smoothstep(0.0, 0.6, h));
	c = mix(c, bone, smoothstep(0.55, 0.97, h) * 0.7);
	// The bands' stone over it, on the faces (fading down into the cool
	// underside).
	float band_on = strata * side * smoothstep(0.08, 0.45, h);
	c = mix(c, band_c * mix(0.85, 1.05, h), band_on);
	float down = clamp(-n.y, 0.0, 1.0);
	c = mix(c, under * 0.85, down * 0.5);
	// Streaks down the faces: long vertical runs.
	float streak = vnoise(vec3(p.x * 2.2, p.y * 0.12, p.z * 2.2) + 13.0);
	float streak2 = vnoise(vec3(p.x * 6.0, p.y * 0.3, p.z * 6.0) + 51.0);
	c *= mix(1.0, 0.8 + 0.38 * streak + 0.16 * (streak2 - 0.5), side);
	float blot = fbm(p * 0.09 + 3.0);
	float rough = fbm(p * 0.45 + 61.0);
	c *= (0.86 + 0.3 * blot) * (0.76 + 0.48 * grain) * (0.88 + 0.24 * pits) * mix(1.0, 0.72 + 0.56 * rough, mid);
	c *= 1.0 - lamina;
	c *= 0.82 + 0.36 * blk.x * mid;
	float dn = clamp(-n.y, 0.0, 1.0);
	c *= mix(1.0, 0.7 + 0.6 * smoothstep(0.35, 0.7, spall), dn);
	// Umber stain running down from the seams.
	float stain = smoothstep(0.55, 0.95, fbm(vec3(p.x * 0.6, p.y * 0.1, p.z * 0.6))) * weather;
	c = mix(c, umber * 1.5, stain * 0.3 * (1.0 - down));
	c = mix(c, umber * 0.5, crack * 0.7);

	// The topsoil skin under the rim, root threads in it.
	float skin = COLOR.a * side;
	float threads = smoothstep(0.75, 0.9, vnoise(vec3(p.x * 9.0, p.y * 1.2, p.z * 9.0))) * fine;
	vec3 sc = mix(soil, soil * 1.9, threads) * (0.8 + 0.4 * grain);
	c = mix(c, sc, skin);

	float ao = COLOR.r;
	c *= mix(0.22, 1.0, ao);

	// Green: moss on what faces up, in patches; green carried down the face
	// from the rim in streaks (COLOR.g).
	float up = smoothstep(0.2, 0.65, wn.y);
	float patch = fbm(p * 0.6 + 17.0) + (vnoise(p * 3.5) - 0.5) * 0.35 * fine;
	float on_top = up * smoothstep(0.46, 0.58, patch + 0.12 * weather);
	float run = COLOR.g * smoothstep(0.45, 0.7, streak + 0.35 * COLOR.g) * side;
	float m = clamp(max(on_top, run * 0.85), 0.0, 1.0) * greenery * (1.0 - crack * 0.6);
	vec3 mc = mix(moss, moss_lit, vnoise(p * 2.5 + 9.0) * 0.7 + up * 0.3) * mix(0.55, 1.0, ao);
	c = mix(c, mc, m);

	ALBEDO = c;
	EMISSION = c * (islet_hemi(wn) * fill * mix(0.4, 1.0, ao) + zs_look_bounce_light(wn) * mix(0.5, 1.0, ao));
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;

	float bump = ((fbm(p * 1.1 + 7.0) - 0.5) * 0.14 * mid + (vnoise(p * 4.5) - 0.5) * 0.025 * fine
		- crack * 0.035 - lamina * 0.02 + (spall - 0.5) * 0.08 * dn * mid + (m - 0.5) * 0.01) * bump_depth;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhx = dFdx(bump);
	float dhy = dFdy(bump);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * MODEL_MATRIX * vec4(tilt, 0.0)).xyz * block_tilt);
}
