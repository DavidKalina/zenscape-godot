shader_type spatial;
// The endless forests' floor (scripts/endless/land_trees.gd): a sheet draped
// over the land where the woods stand (its vertex alpha the woods' weight),
// the shade and needle litter under the spruces, so a wood reads as one
// mass from the air. Pulled toward the eye (lift, more with distance) so the
// land's coarser far chunks don't cover it; shown over `band` m from the
// eye (grown in over band.x..+y, gone over band.z-w..z), so the near and
// far sheets hand over.
// Past the sprites (land_trees.gd CANOPY: from canopy.x m, in over canopy.y)
// it turns to the woods' canopy painted: the crowns' mean colour, dappled
// crown by crown (canopy_scale m) with each crown's sunward side lit and its
// gaps dark, lit as the sprites are (the sky's hemisphere as emission, leaning
// olive, `canopy_fill` more of it; the sun wrapped, `canopy_light`), its cover
// the woods' weight eased up so a dense wood is near solid and a thin one thin.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert, specular_disabled;

global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
// The canopy's shade olive turns with the shade's hue (light_leans).
#include "res://shaders/light_leans.gdshaderinc"

uniform vec4 band = vec4(-1.0, 1.0, 1e6, 1.0);
uniform vec4 colour : source_color = vec4(0.1, 0.16, 0.08, 1.0);
uniform float strength = 0.8;
// Pulled toward the eye: lift.x m plus lift.y of its distance.
uniform vec2 lift = vec2(0.25, 0.004);
// The litter's mottle: its scale (m) and how much it moves the colour.
uniform vec2 mottle = vec2(9.0, 0.25);
uniform vec2 canopy = vec2(1e9, 1.0);
uniform vec3 canopy_colour = vec3(0.06, 0.1, 0.08);
uniform float canopy_fill = 1.0;
// wrap, floor (light kept in shadow), warm (fill olive), hemiolive: the crowns' (spruce_light, spruce_tone)
uniform vec4 canopy_light = vec4(1.0, 0.85, 1.0, 0.85);
uniform float canopy_scale = 7.0;
// How far the crowns tilt the light (their bumps' slope).
uniform float canopy_bump = 0.9;

varying float fade;
varying float crown;
varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// The crowns as bumps: a cell's crown a dome round a jittered middle.
float crowns(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float best = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 mid = o + vec2(hash(i + o), hash(i + o + 17.3)) * 0.8 + 0.1;
			float r = length(f - mid) / (0.55 + 0.25 * hash(i + o + 5.1));
			best = max(best, 1.0 - r * r);
		}
	}
	return max(best, 0.0);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(world, CAMERA_POSITION_WORLD);
	fade = smoothstep(band.x, band.x + band.y, d) * (1.0 - smoothstep(band.z - band.w, band.z, d));
	crown = smoothstep(canopy.x, canopy.x + canopy.y, d);
	vec3 to = normalize(CAMERA_POSITION_WORLD - world);
	VERTEX += to * (lift.x + lift.y * d);
}

void fragment() {
	float m = noise(world.xz / mottle.x) * 0.65 + noise(world.xz / (mottle.x * 0.31)) * 0.35;
	vec3 litter = colour.rgb * (1.0 + (m - 0.5) * 2.0 * mottle.y);
	float alpha = COLOR.a * strength;
	if (crown > 0.0) {
		vec2 p = world.xz / canopy_scale;
		float e = 0.08;
		float b = crowns(p);
		vec2 slope = vec2(crowns(p + vec2(e, 0.0)) - b, crowns(p + vec2(0.0, e)) - b) / e;
		// The bumps fade with distance, as the crowns go under a pixel.
		float far = 1.0 - smoothstep(2500.0, 6000.0, distance(world, CAMERA_POSITION_WORLD));
		vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 bumped = normalize(wn - vec3(slope.x, 0.0, slope.y) * canopy_bump * far);
		NORMAL = normalize((VIEW_MATRIX * vec4(mix(wn, bumped, crown), 0.0)).xyz);
		float patch = noise(world.xz / 90.0);
		vec3 top = canopy_colour * mix(0.55, 1.0, mix(0.7, b, far)) * mix(0.85, 1.12, patch);
		litter = mix(litter, top, crown);
		// Thin woods thin, and the gaps between crowns let the land through.
		alpha = mix(alpha, smoothstep(0.05, 0.75, COLOR.a) * mix(0.55, 0.95, mix(0.8, b, far)), crown);
		vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, bumped.y * 0.5 + 0.5) * zs_hemi_energy / PI;
		vec3 ol = zs_cool(vec3(1.20, 1.05, 0.22), 1.0) * dot(top, vec3(0.2126, 0.7152, 0.0722));
		EMISSION = (mix(top, ol, canopy_light.w) * hemi + mix(top, ol, canopy_light.z) * hemi * canopy_fill) * crown;
	}
	ALBEDO = litter;
	ROUGHNESS = 1.0;
	ALPHA = clamp(alpha * fade, 0.0, 1.0);
}

void light() {
	float d = dot(NORMAL, LIGHT);
	vec3 ground = LIGHT_COLOR * ATTENUATION * max(d, 0.0);
	vec3 crowns_lit = LIGHT_COLOR * mix(canopy_light.y, 1.0, ATTENUATION) * clamp((d + canopy_light.x) / (1.0 + canopy_light.x), 0.0, 1.0);
	DIFFUSE_LIGHT += mix(ground, crowns_lit, crown) / PI;
}
