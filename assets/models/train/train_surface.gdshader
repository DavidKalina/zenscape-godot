shader_type spatial;
// Written by art/blender/train/train_build.py. Lit as the world is: no ambient,
// the sky's hemisphere added as emission (the pirate ship's surface), so a stock
// material would go black out of the sun. Albedo: the tile times the vertex
// colour (the paint, its grime baked in), then weathered here from the model's
// own position and one shared wear map (no per-car texture, so a car looks the
// same near and far): paint faded and patchy, streaks running down, soot on
// what faces up, dust low down, the underside dark, and a roughness that varies
// (matte soot and dust, a polish where the relief catches). `tint` colours a
// block the game builds itself (rail_train.gd), which has no vertex colours.
render_mode diffuse_lambert, specular_schlick_ggx;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float normal_depth = 0.0;
uniform float roughness_value = 0.9;
uniform float metallic_value = 0.0;
uniform float fill = 1.6;
uniform float rim = 0.3;
uniform float rough_var = 0.0;
uniform float patch = 0.0;
uniform float streak = 0.0;
uniform float soot = 0.0;
uniform float dust = 0.0;
uniform float cavity = 0.0;
uniform float polish = 0.0;
varying vec3 lpos;
varying vec3 lnrm;
void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
}
void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb * COLOR.rgb * tint.rgb;
	// Position on the face: h along it, v up it (the top's v runs along the car).
	vec3 an = abs(lnrm);
	float h = an.x > an.z ? lpos.z : lpos.x;
	float v = an.y > max(an.x, an.z) ? lpos.z : lpos.y;
	vec2 pq = vec2(h, v);
	float blotch = texture(wear_tex, pq * 0.21 + 0.13).r;
	float blotch2 = texture(wear_tex, pq * 0.83 + 0.41).r;
	float run = texture(wear_tex, vec2(pq.x * 0.9, pq.y * 0.11) + 0.27).g;
	float grit = texture(wear_tex, pq * 3.3).b;
	// The paint: lighter or darker panel by panel, faded and greyed in patches.
	base *= 1.0 + patch * (blotch - 0.5) * 1.5;
	float luma = dot(base, vec3(0.3, 0.55, 0.15));
	base = mix(base, vec3(luma) * 1.12, patch * 0.4 * smoothstep(0.45, 0.72, blotch2));
	// The relief: slope darkens a seam's groove, and catches a polish.
	float slope = 0.0;
	if (normal_depth > 0.0) {
		vec3 nm = texture(normal_tex, UV).rgb;
		NORMAL_MAP = nm;
		NORMAL_MAP_DEPTH = normal_depth;
		slope = clamp(length(nm.xy * 2.0 - 1.0) * 2.0, 0.0, 1.0);
	}
	base *= 1.0 - cavity * slope * 0.35;
	// Streaks running down: a dark rusty wash, strongest low.
	float low = 1.0 - smoothstep(0.5, 3.5, lpos.y);
	float s = smoothstep(0.52, 0.78, run) * streak * (0.45 + 0.55 * blotch2) * (0.5 + 0.5 * low);
	base = mix(base, base * vec3(0.5, 0.36, 0.28), s);
	// Soot on what faces up, matte; dust low down; the underside dark.
	float sk = soot * smoothstep(0.35, 0.95, lnrm.y) * (0.45 + 0.9 * blotch);
	base *= 1.0 - 0.6 * clamp(sk, 0.0, 1.0);
	float dd = dust * (1.0 - smoothstep(0.15, 1.5, lpos.y)) * (0.3 + 1.0 * blotch2);
	base = mix(base, vec3(0.2, 0.16, 0.115) * (0.5 + luma * 1.2), clamp(dd, 0.0, 1.0) * 0.55);
	base *= mix(0.55, 1.0, smoothstep(-0.9, 0.1, lnrm.y));
	ALBEDO = base;
	float r = roughness_value + rough_var * ((grit - 0.5) * 1.1 + (blotch - 0.5) * 1.5);
	r += 0.35 * clamp(sk, 0.0, 1.0) + 0.25 * clamp(dd, 0.0, 1.0) + 0.2 * s;
	r -= polish * slope;
	ROUGHNESS = clamp(r, 0.12, 1.0);
	METALLIC = metallic_value * (1.0 - 0.6 * clamp(sk + dd, 0.0, 1.0));
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = base * hemi * fill + base * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
