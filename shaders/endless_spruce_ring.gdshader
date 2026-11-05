shader_type spatial;
// The endless land's mid and far rings of sprays spruce (scripts/endless/
// land_trees.gd, the default look): the generator's "low" crown in a small
// copy of the near crowns' painted light (reference_surface with
// shaders/spruce_paint.gdshaderinc), so value and hue carry to the horizon at
// a fraction of reference_surface's cost on ~30k trees. What it keeps of that
// path: the crown's blue (eased at range as there), its value, the crown lit as
// a volume (the normal out from the trunk and up), the wrapped, softly stepped
// sun with the crown's porous own shadow (`floor`) and backlit glow, and the
// sky's fill and hemisphere leaning olive in the shade. The patches and dabs
// are gone at range in any case. `gain` matches its albedo to the near
// crowns' (their scene palette), measured on a view of forced rings.
// Each tree draws while its foot is band.x..band.y m off, dithered `fade` m
// round each end as reference_surface's `lod_fade` (the same noise and
// distance), so it hands over to the mid crowns with no pop.
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// The globals (hemisphere, cloud sun, key) and the woods' wind by place
// (tree_wind.gdshaderinc zs_tree_far_sway, wind_field.gdshaderinc).
#include "res://shaders/tree_wind.gdshaderinc"
#include "res://shaders/look_fill.gdshaderinc"
// The shade's olive turns with the shade's hue (light_leans; 0 fixed).
#include "res://shaders/light_leans.gdshaderinc"
#include "res://shaders/backlight.gdshaderinc"
// --spruce-look=g (spruce_variety.gdshaderinc), as the near crowns'.
#include "res://shaders/spruce_variety.gdshaderinc"
// --spruce-look=b (spruce_tiers.gdshaderinc): the tiers' tones, tilt, the cool shade, the dabs.
#include "res://shaders/spruce_tiers.gdshaderinc"
// Backlight's gain on the crown's silhouette (shaders/backlight.gdshaderinc).
const float BACKLIGHT_GAIN = 2.0;

uniform vec2 band = vec2(0.0, 1e9);
// The crown's height in model units (its sway's reach; the near crowns' conifer_height).
uniform float sway_tall = 4.3;
uniform vec2 fade = vec2(0.0);
uniform vec3 gain = vec3(1.0);
// x value (value x ringlift), y blue, z luminance of the crowns' tint (to read the bake), w volume (round)
uniform vec4 paint = vec4(1.0, 1.0, 1.0, 0.7);
// wrap, glow, steps, soft (spruce_light)
uniform vec4 sun = vec4(1.0, 0.35, 0.25, 0.5);
// fill, warm (fill olive), floor (own shadow), hemiolive
uniform vec4 tone = vec4(2.6, 1.0, 0.85, 0.85);
// olive of the look fill (tone2.z)
uniform float olive = 1.0;
uniform float shade_follow : hint_range(0.0, 2.0) = 1.0;
// The g look (see endless_spruce_sprite.gdshader): variety, (inner, fresh, haze), rim; all off at 0.
uniform vec4 spruce_var = vec4(0.0);
uniform vec4 spruce_g = vec4(0.0);
uniform vec4 spruce_rim = vec4(0.0);
// The b look (see reference_surface spruce_tier): all off at 0.
uniform vec4 spruce_tier = vec4(0.0);
uniform vec4 spruce_tier2 = vec4(0.0);

const vec3 GLAUCOUS = vec3(0.50, 1.08, 1.45);
const vec3 FROST = vec3(1.10, 1.22, 1.34);
const vec3 OLIVE = vec3(1.20, 1.05, 0.22);
const float SLACK = 25.0;

varying vec3 ring_world;
varying flat vec3 ring_foot;

float ring_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void vertex() {
	ring_foot = MODEL_MATRIX[3].xyz;
	float d = distance(ring_foot, CAMERA_POSITION_WORLD);
	if (d < band.x - (fade.x > 0.0 ? fade.x + SLACK : 0.0) || d >= band.y + (fade.y > 0.0 ? fade.y + SLACK : 0.0)) VERTEX = vec3(0.0);
	ring_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// The cheap sway: the crown leans and swings with the wind where it stands.
	if (zs_tree_alive > 0.0) {
		float tall = sway_tall * length(MODEL_MATRIX[1].xyz);
		vec2 m = zs_tree_far_sway(ring_foot.xz, clamp(VERTEX.y / sway_tall, 0.0, 1.2), tall);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(m.x, 0.0, m.y);
	}
}

void fragment() {
	vec2 across = CAMERA_POSITION_WORLD.xz - ring_foot.xz;
	float d = length(vec3(across.x, CAMERA_POSITION_WORLD.y - ring_world.y, across.y));
	float h = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float fin = fade.x > 0.0 ? smoothstep(band.x - fade.x, band.x + fade.x, d) : 1.0;
	float fout = fade.y > 0.0 ? 1.0 - smoothstep(band.y - fade.y, band.y + fade.y, d) : 1.0;
	if (1.0 - h > fin || h >= fout) discard;
	vec3 c = COLOR.rgb * gain;
	float bake = ring_luma(COLOR.rgb) / max(paint.z, 1e-3);
	float rank = fract(sin(dot(ring_foot.xz, vec2(27.17, 63.41))) * 43758.5453);
	// The blue as the near crowns' at range (spruce_paint: eased 0.45 past 160 m).
	float blue = paint.y * 0.55;
	float k = mix(0.62, 1.12, rank);
	float frost = 1.0;
	if (spruce_var.y > 0.0) {
		k = zs_sv_blue_k(ring_foot.xz, rank, spruce_var);
		frost = clamp(k, 0.0, 1.0);
	}
	c = mix(c, mix(GLAUCOUS, vec3(1.0), 0.06) * ring_luma(c), clamp(blue * k, 0.0, 1.0));
	c *= mix(vec3(1.0), FROST, smoothstep(0.8, 1.0, bake) * blue * 0.7 * frost);
	if (spruce_var.y > 0.0) c = zs_sv_needles(c, bake, spruce_g.x, spruce_g.y);
	// The b look: the tiers' lit top and dark skirt band (the facing from the mesh's own normal), and the dabs.
	if (spruce_tier.y > 0.0 || spruce_tier.z > 0.0) c = zs_st_paint(c, bake, 1.0 - smoothstep(-0.6, 0.0, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y), spruce_tier, 1.0);
	if (spruce_tier2.y > 0.0) c = zs_st_dabs(c, (ring_world.xz - ring_foot.xz) + vec2(ring_world.y * 0.61, -ring_world.y * 0.37) + vec2(rank * 91.0, rank * 37.0), d, zs_st_pixel(d, PROJECTION_MATRIX[1][1], VIEWPORT_SIZE.y), spruce_tier2);
	c *= paint.x;
	if (spruce_var.y > 0.0) c = zs_sv_keep(c, d, spruce_g.z);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	// The crown as a volume: out from the trunk and up.
	vec2 out_xz = ring_world.xz - ring_foot.xz;
	float r = length(out_xz);
	vec3 n = normalize(vec3(out_xz / max(r, 1e-3) * smoothstep(0.0, 0.5, r), 0.62).xzy);
	if (spruce_tier.x > 0.0) n = zs_st_normal(n, bake, spruce_tier.x, 1.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	vec3 ol = zs_cool(zs_st_shade(spruce_tier.w), shade_follow) * ring_luma(c);
	EMISSION = mix(c, ol, tone.w) * hemi + mix(c, ol, tone.y) * hemi * tone.x + mix(c, ol, olive) * zs_look_bounce_light(n);
}

void light() {
	float d = dot(NORMAL, LIGHT);
	// As the sprites': the sun's shadow keeps a floor, a local light falls off.
	float fall = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	vec3 crown_sun = LIGHT_COLOR * (LIGHT_IS_DIRECTIONAL ? mix(tone.z, 1.0, ATTENUATION) : ATTENUATION);
	float lit = clamp((d + sun.x) / (1.0 + sun.x), 0.0, 1.0);
	float tier = lit * 3.0;
	float t = clamp((floor(tier) + smoothstep(0.5 - sun.w, 0.5 + sun.w, fract(tier))) / 3.0, 0.0, 1.0);
	t = mix(lit, t, sun.z);
	DIFFUSE_LIGHT += crown_sun * t * mix(mix(vec3(0.96, 0.99, 1.04), vec3(1.04, 1.02, 0.94), t), ZS_ST_WARM, spruce_tier2.x * t) / PI;
	float through = pow(max(dot(-LIGHT, VIEW), 0.0), 2.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * fall * sun.y * max(-d, 0.0) * (0.3 + 0.7 * through) * vec3(0.9, 1.0, 0.85) / PI;
	// Backlight: the crown's silhouette, seen against a low sun, catches it.
	if (max(zs_backlight, spruce_rim.z) > 0.0 && LIGHT_IS_DIRECTIONAL && dot((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz, zs_key_direction) > 0.999) {
		float edge_glow = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
		if (spruce_rim.x > 0.0) {
			DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * zs_backlight_tint_warm(ALBEDO, zs_backlight_amount_floor(max(zs_backlight, spruce_rim.z), dot(-LIGHT, VIEW), edge_glow, BACKLIGHT_GAIN * spruce_rim.x / 3.0), spruce_rim.y) / PI;
		} else if (zs_backlight > 0.0) {
			DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * zs_backlight_tint(ALBEDO, zs_backlight_amount(dot(-LIGHT, VIEW), edge_glow, BACKLIGHT_GAIN)) / PI;
		}
	}
	if (zs_look_fill > 0.0 && LIGHT_IS_DIRECTIONAL) {
		vec3 fill_light = zs_look_fill_light(1.0 - ATTENUATION * smoothstep(0.0, 0.2, max(d, 0.0)));
		float la = ring_luma(ALBEDO);
		fill_light *= mix(vec3(1.0), clamp(zs_cool(zs_st_shade(spruce_tier.w), shade_follow) * la / max(ALBEDO, vec3(0.03)), 0.0, 3.0), olive);
		DIFFUSE_LIGHT += fill_light;
	}
}
