shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// The islet unit's rock (scripts/kit_isle/islet_unit.gd): dusty, faded
// stone painted in the mesh's own space (triplanar: no stretching on any
// face). Beds run level, warped, each its own tone, split by umber seams;
// blocky joints cut each bed into blocks (cells stretched along the bed);
// the seams and joints are dug in (bumped) and darkened, and fade with the
// pixel's footprint so nothing shimmers far off. Value: bone at the top,
// ash down the faces, a cool dark underside; faces turned down darker
// still. Pale lichen on what faces up. COLOR.r is the mesh's baked shade
// (under the lip, under a shelf, a drip's crease).
uniform vec3 bone : source_color = vec3(0.71, 0.70, 0.67);
uniform vec3 ash : source_color = vec3(0.53, 0.52, 0.50);
uniform vec3 under : source_color = vec3(0.33, 0.33, 0.36);
uniform vec3 umber : source_color = vec3(0.30, 0.23, 0.17);
uniform vec3 lichen : source_color = vec3(0.84, 0.86, 0.77);
uniform vec3 lichen_dark : source_color = vec3(0.62, 0.66, 0.56);
uniform float top_y = 0.0;
uniform float bottom_y = -10.0;
uniform float weather = 0.5;
uniform float bed_scale = 1.0;
uniform vec3 seed_off = vec3(0.0);
uniform float bump_depth = 1.0;
uniform float block_tilt = 0.8;
uniform float fill = 1.0;
// The game's sky light into the shade (the look rig's globals; the scene's
// own ambient is off): the hemisphere by the face's world normal, and the
// look pass's bounce off the cloud sea onto what faces down.
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

// A 2D Voronoi: x the distance to the nearest cell edge (F2 - F1), yz the
// nearest cell's own random pair (its block's tilt and tone).
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
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; id = i + g; } else if (d < d2) { d2 = d; }
		}
	}
	return vec3(d2 - d1, hash2(id + 17.31));
}

void vertex() {
	v_pos = VERTEX;
	v_nrm = NORMAL;
}

void fragment() {
	vec3 p = v_pos * bed_scale + seed_off;
	vec3 n = normalize(v_nrm);
	vec3 wgt = pow(abs(n), vec3(4.0));
	wgt /= (wgt.x + wgt.y + wgt.z);
	float foot = length(fwidth(p));
	float fine = 1.0 - smoothstep(0.05, 0.35, foot);
	float mid = 1.0 - smoothstep(0.25, 1.2, foot);

	float side = 1.0 - smoothstep(0.45, 0.8, abs(n.y));
	// Beds: level bands, warped; each its own tone; thin laminae inside.
	float warp = fbm(p * 0.18) * 1.6 - 0.8 + (vnoise(p * 0.9) - 0.5) * 0.25;
	float yb = p.y * 0.8 + warp;
	float bed_id = floor(yb);
	float bed = fract(yb);
	float bed_tone = 0.78 + 0.42 * hash1(bed_id + seed_off.x);
	float seam_w = 0.025 + 0.035 * vnoise(p * 1.7);
	float seam = (1.0 - smoothstep(0.0, seam_w, min(bed, 1.0 - bed))) * mid;
	seam *= smoothstep(0.25, 0.55, vnoise(p * 0.7 + 3.0) + 0.2);
	float lam = fract(yb * 4.0 + vnoise(p * 2.0) * 0.6);
	float lamina = (1.0 - smoothstep(0.0, 0.12, min(lam, 1.0 - lam))) * fine * 0.35;

	// Joints: blocky cells on the sides, taller than wide across each bed
	// (a bed splits into blocks); faces turned down crack into rough spalls
	// rather than cells; the top's ledges on their plan.
	vec2 sx = vec2(p.z * 1.3, (bed_id + 0.5) * 1.0 + bed * 0.6);
	vec2 sz = vec2(p.x * 1.3, (bed_id + 0.5) * 1.0 + bed * 0.6);
	vec2 sy = p.xz * 0.9;
	float jw = 0.03;
	vec3 cx = cell(sx);
	vec3 cz = cell(sz);
	vec3 cy = cell(sy);
	float jx = 1.0 - smoothstep(0.0, jw, cx.x);
	float jz = 1.0 - smoothstep(0.0, jw, cz.x);
	float jy = 1.0 - smoothstep(0.0, jw * 1.2, cy.x);
	// Each block its own tilt and tone (the facets of a split stone).
	vec2 blk = (cx.yz * wgt.x + cz.yz * wgt.z + cy.yz * wgt.y);
	vec3 tilt = vec3(blk.x - 0.5, (blk.y - 0.5) * 0.6, (blk.y + blk.x) * 0.5 - 0.5) * mid;
	float upf = smoothstep(0.4, 0.8, n.y);
	float joint = ((jx * wgt.x + jz * wgt.z) / max(wgt.x + wgt.z, 0.001) * side + jy * upf * 0.7) * mid;
	// Not every joint opens: some blocks stay whole.
	joint *= smoothstep(0.3, 0.6, vnoise(p * 0.6 + 29.0) + 0.25 * weather);
	// Fine pitting and grain; rough spalling on what faces down.
	float grain = mix(0.5, vnoise(p * 7.0), fine);
	float pits = mix(0.5, vnoise(p * 2.6 + 5.0), mid);
	float spall = fbm(p * 0.8 + 41.0);
	// The bed seams show on the faces, faint on what faces down.
	seam *= mix(0.25, 1.0, side);
	float crack = max(seam, joint * (0.5 + 0.5 * weather));

	// Value from top to bottom, faces turned down darker and cooler.
	float h = clamp((v_pos.y - bottom_y) / max(top_y - bottom_y, 0.01), 0.0, 1.0);
	vec3 c = mix(under, ash, smoothstep(0.05, 0.7, h));
	c = mix(c, bone, smoothstep(0.6, 0.97, h) * 0.85);
	float down = clamp(-n.y, 0.0, 1.0);
	c = mix(c, under * 0.85, down * 0.55);
	// Broad blotches, the beds' tones, grain.
	float blot = fbm(p * 0.09 + 3.0);
	c *= mix(1.0, bed_tone, side * 0.8 + 0.2) * (0.78 + 0.44 * blot) * (0.72 + 0.56 * grain) * (0.9 + 0.2 * pits);
	c *= 1.0 - lamina;
	c *= 0.8 + 0.4 * blk.x * mid;
	// Spalls on the underside: lighter fresh breaks, darker hollows.
	float dn = clamp(-n.y, 0.0, 1.0);
	c *= mix(1.0, 0.7 + 0.6 * smoothstep(0.35, 0.7, spall), dn);
	// Warm umber stain down from the seams (weathering).
	float stain = smoothstep(0.55, 0.95, fbm(vec3(p.x * 0.6, p.y * 0.12, p.z * 0.6))) * weather;
	c = mix(c, umber * 1.6, stain * 0.35 * (1.0 - down));
	// Seams and joints: muted umber, dark.
	c = mix(c, umber * 0.55, crack * 0.85);
	// The mesh's baked shade, and the seams' own.
	float ao = COLOR.r;
	c *= mix(0.22, 1.0, ao);

	// Lichen on what faces up (the world's up), in patches, near white.
	vec3 wn = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	float up = smoothstep(0.25, 0.7, wn.y);
	float lic_patch = fbm(p * 0.7 + 17.0) + (vnoise(p * 4.0) - 0.5) * 0.3 * fine;
	float lic = up * smoothstep(0.62 - 0.22 * weather, 0.7 - 0.22 * weather, lic_patch) * (1.0 - crack);
	vec3 lc = mix(lichen_dark, lichen, vnoise(p * 3.0 + 9.0));
	c = mix(c, lc * mix(0.6, 1.0, ao), lic);

	ALBEDO = c;
	EMISSION = c * (islet_hemi(wn) * fill * mix(0.4, 1.0, ao) + zs_look_bounce_light(wn) * mix(0.5, 1.0, ao));
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;

	// Dig the seams and joints in: a bump from their height.
	float bump = ((fbm(p * 1.1 + 7.0) - 0.5) * 0.12 * mid + (vnoise(p * 4.5) - 0.5) * 0.02 * fine
		- crack * 0.03 - lamina * 0.02 + (spall - 0.5) * 0.08 * dn * mid) * bump_depth;
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
