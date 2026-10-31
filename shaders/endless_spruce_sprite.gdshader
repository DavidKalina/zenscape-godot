shader_type spatial;
// The endless spruces past their near crowns (scripts/endless/land_trees.gd,
// scripts/endless/spruce_sprites.gd): each tree a quad facing the eye, its
// picture the real crown's from the atlas (the cell for the eye's turn about
// the tree and its height over it, dithered between the nearest two of each),
// lit as reference_surface lights a sprays crown (spruce_paint.gdshaderinc,
// reference_direct_light.gdshaderinc): the sky's hemisphere and fill as
// emission leaning olive in the shade, the sun in soft steps over a wrapped
// term, the porous own shadow (`tone.z`) and the backlit glow. The atlas
// holds the painted albedo premultiplied by its cover and the light normal
// in the bake camera's view space; both are un-premultiplied here so the
// mips keep the crown's colour to its edge. The atlas is sRGB bytes whose
// mips were averaged as bytes, so it is read raw, un-premultiplied, then
// decoded (decoding first darkens every edge texel: a black rim).
// Each tree draws while its foot is band.x..band.y m off, dithered `fade` m
// round each end with the near crowns' noise and distance (reference_surface
// `lod_fade`), so it takes over from them with no pop.
// Soft (scripts/endless/spruce_sprites.gd `soft`, the default): the nearest
// views blended by the eye's turn and height, not dithered between (the
// grain), and the crown's outline smoothed by alpha to coverage over the
// screen's MSAA (the hard cut-out stepped and crawled); off, the first look.
render_mode world_vertex_coords, cull_disabled, diffuse_lambert, specular_disabled, alpha_to_coverage_and_one;

// The woods alive (reference_globals' hemisphere, cloud sun and key with it):
// each sprite leans and sways in the breeze as its near crown does, and gust
// waves rolling through the woods light it as they lift its boughs.
#include "res://shaders/tree_wind.gdshaderinc"
#include "res://shaders/look_fill.gdshaderinc"
// The shade's olive turns with the shade's hue (light_leans; 0 fixed).
#include "res://shaders/light_leans.gdshaderinc"
#include "res://shaders/backlight.gdshaderinc"
// --spruce-look=g: the variety, the mid-distance contrast and the rim, as the
// near crowns' (spruce_variety.gdshaderinc, spruce_paint.gdshaderinc).
#include "res://shaders/spruce_variety.gdshaderinc"
// --spruce-look=b (spruce_tiers.gdshaderinc): the atlas holds the tiers' tones and
// tilted light normal; the sprite paints the cool shade, the warm light and its own dabs.
#include "res://shaders/spruce_tiers.gdshaderinc"
// Backlight's gain on the crown's silhouette (shaders/backlight.gdshaderinc).
const float BACKLIGHT_GAIN = 2.0;
// The crown's outline in the atlas (its cover near the cut), for backlight.
varying float edge;

uniform sampler2D albedo_atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D normal_atlas : filter_linear_mipmap, repeat_disable;
// The atlas's columns (variants x yaws) and rows (heights).
uniform vec2 cells = vec2(24.0, 3.0);
uniform int variant = 0;
uniform int yaws = 4;
uniform bool soft = false;
uniform float row_step = 0.5235988;
uniform float cell_px = 192.0;
// x the cell's centre up the trunk, y its size, z how far the quad stands toward the eye (m at scale 1)
uniform vec3 fit = vec3(2.2, 5.0, 0.6);
uniform vec2 band = vec2(0.0, 1e9);
uniform vec2 fade = vec2(0.0);
// Each tree's ends moved by up to half this (m), its own way, as the crowns'
// lod_spread (reference_surface, the same hash of the foot).
uniform float spread = 0.0;
// The crowns' tint the atlas was baked in (each tree's own over it is its shade).
uniform vec3 tint = vec3(1.0);
// wrap, glow, steps, soft (spruce_light)
uniform vec4 sun = vec4(1.0, 0.35, 0.25, 0.5);
// fill, warm (fill olive), floor (own shadow), hemiolive
uniform vec4 tone = vec4(2.6, 1.0, 0.85, 0.85);
uniform float olive = 1.0;
uniform float shade_follow : hint_range(0.0, 2.0) = 1.0;
// The g look (scripts/hero_trees.gd SPRUCE_G; all off at 0, the first look):
// var is spruce_var (share of blue, grove scale, lean, a green's own blue),
// g (inner, fresh, haze, the blue strength the atlas was baked at), rim
// (gain over the crown's 3.0, warm, floor, the tips' share), blue_far the
// blue knob as the atlas holds it (eased at range), mean_luma the atlas's.
uniform vec4 spruce_var = vec4(0.0);
uniform vec4 spruce_g = vec4(0.0, 0.0, 0.0, 0.5);
uniform vec4 spruce_rim = vec4(0.0);
uniform float blue_far = 0.55;
uniform float mean_luma = 0.1;
// The b look (see reference_surface spruce_tier): all off at 0.
uniform vec4 spruce_tier = vec4(0.0);
uniform vec4 spruce_tier2 = vec4(0.0);

// The far trees' look (scripts/endless/spruce_sprites.gd `far_look`, land_trees.gd
// far_trees_wanted; --far-trees=old leaves it off): past the near crowns a tree
// keeps their weight, not one flat pale cone. x the value (the atlas's pale
// mint taken down to the crowns' tone), y the share of the crown's lower part
// in its own shade (a wood's dark understorey), z the shade side's depth
// (against the sun), w the contrast about the crowns' mean. far_size is the
// per-tree size spread, far_tone the per-tree value and hue spread.
uniform float far_look = 0.0;
uniform vec4 far_shape = vec4(0.88, 0.32, 0.30, 0.35);
uniform vec2 far_vary = vec2(0.14, 0.2);

const vec3 OLIVE = vec3(1.20, 1.05, 0.22);
const float SLACK = 25.0;
// The breeze's lean on a sprite (as zs_breeze_lean_at's base share and its
// gust patches average) and how far its top lags the air, s per m of tree.
const float ZS_SPRITE_LEAN = 0.3;
const float ZS_SPRITE_LAG = 0.3;

varying flat vec3 sprite_foot;
varying flat vec3 sprite_right;
varying flat vec3 sprite_up;
varying flat vec3 sprite_toward;
// How far up the tree this point of the quad is (0 the foot, 1 the top), and how steeply the eye looks down on it.
varying float sprite_up_tree;
varying flat float sprite_look_down;
// x the height's row (fraction), y the turn's column (fraction)
varying flat vec2 sprite_view;
// How far a gust wave lifts the tree's boughs (tree_wind.gdshaderinc).
varying float sprite_sheen;
// How much of a fresh tip this pixel is (the atlas's light against the crown's mean), for the rim.
varying float sprite_tip;

float sprite_lod_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float sprite_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 sprite_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
	vec3 foot = MODEL_MATRIX[3].xyz;
	sprite_foot = foot;
	float d = distance(foot, CAMERA_POSITION_WORLD);
	vec3 x_axis = MODEL_MATRIX[0].xyz;
	float sc = length(MODEL_MATRIX[1].xyz);
	float wide = length(x_axis) / max(sc, 1e-4);
	if (far_look > 0.0) {
		// Each tree its own size, from where the near crowns end: the plan's
		// scales read as one at range.
		sc *= 1.0 + (sprite_lod_hash(foot.xz + vec2(3.7, 19.1)) - 0.5) * far_vary.x * smoothstep(120.0, 300.0, d);
	}
	vec3 centre = foot + vec3(0.0, fit.x * sc, 0.0);
	vec3 toward = normalize(CAMERA_POSITION_WORLD - centre);
	vec3 right = cross(vec3(0.0, 1.0, 0.0), toward);
	right = length(right) > 1e-4 ? normalize(right) : vec3(1.0, 0.0, 0.0);
	vec3 up = cross(toward, right);
	sprite_right = right;
	sprite_up = up;
	sprite_toward = toward;
	float yaw = atan(-x_axis.z, x_axis.x);
	float az = atan(toward.x, toward.z);
	float elev = asin(clamp(toward.y, -1.0, 1.0));
	sprite_view = vec2(clamp(elev / row_step, 0.0, cells.y - 1.0), -(az - yaw) / (TAU / float(yaws)));
	vec2 q = UV - 0.5;
	sprite_up_tree = (fit.x - q.y * fit.y) / max(fit.x * 2.0, 0.1);
	sprite_look_down = clamp(toward.y, 0.0, 1.0);
	VERTEX = centre + right * q.x * fit.y * sc * wide - up * q.y * fit.y * sc + toward * fit.z * sc;
	// The breeze's lean and sway, as conifer_wind bends the near crown: the
	// quad's top corners go with the tree's upper crown, its foot stays.
	sprite_sheen = 0.0;
	float air = zs_tree_air();
	if (air > 0.0) {
		float tall = fit.x * 2.0 * sc;
		float k = clamp((VERTEX.y - foot.y) / max(tall, 0.1), 0.0, 1.2);
		vec2 root = foot.xz;
		float phase = dot(root, vec2(0.43, 0.71));
		float wave = zs_tree_wave(root, ZS_SPRITE_LAG * tall * k);
		float lean = (ZS_SPRITE_LEAN * clamp(zs_breeze, 0.0, 2.5) * ZS_TREE_SWAY_LEAN + wave * ZS_TREE_WAVE_LEAN) * min(zs_tree_alive, 2.0);
		float pace = 2.6 / sqrt(max(tall, 0.3));
		float swing = sin(zs_motion_time * pace + phase - k * 0.9) * 0.7 + sin(zs_motion_time * pace * 1.63 + phase * 1.7 - k * 1.3) * 0.3;
		vec2 dir = zs_wind_direction;
		vec2 motion = (dir * (1.0 + ZS_TREE_SWAY_SWING * swing) + vec2(-dir.y, dir.x) * 0.22 * sin(zs_motion_time * pace * 0.71 + phase * 2.3)) * lean * 0.3 * tall * k * k;
		// The grass's stirring (eddies, gusts landing, the prop's wash).
		float stir;
		vec2 react = zs_tree_react(root, stir);
		motion += (zs_tree_gust(root, swing, phase, react, stir) + react) * 0.3 * tall * k * k;
		VERTEX.xz += motion;
		sprite_sheen = max(wave, stir * 0.8 * max(zs_gust_rect.w, 1.0));
	}
	if (d < band.x - (fade.x > 0.0 ? fade.x + SLACK : 0.0) || d >= band.y + (fade.y > 0.0 ? fade.y + SLACK : 0.0)) VERTEX = foot;
	NORMAL = toward;
}

// The atlas's albedo and light normal for column `col` (a turn) and `row`.
void sprite_sample(float col, float row, vec2 uv_in, vec2 gx, vec2 gy, out vec4 a, out vec4 nb) {
	vec2 cell = vec2(float(variant * yaws) + col, row);
	vec2 uv = (cell + uv_in) / cells;
	a = textureGrad(albedo_atlas, uv, gx, gy);
	nb = textureGrad(normal_atlas, uv, gx, gy);
}

void fragment() {
	vec3 to_eye = CAMERA_POSITION_WORLD - sprite_foot;
	float d = length(to_eye);
	if (spread > 0.0) d += (sprite_lod_hash(sprite_foot.xz) - 0.5) * spread;
	float h = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float fin = fade.x > 0.0 ? smoothstep(band.x - fade.x, band.x + fade.x, d) : 1.0;
	float fout = fade.y > 0.0 ? 1.0 - smoothstep(band.y - fade.y, band.y + fade.y, d) : 1.0;
	if (1.0 - h > fin || h >= fout) discard;
	vec2 uv_in = clamp(UV, vec2(0.002), vec2(0.998));
	vec2 gx = dFdx(UV) / cells;
	vec2 gy = dFdy(UV) / cells;
	vec4 a;
	vec4 nb;
	if (soft) {
		// The nearest two heights and turns, blended (premultiplied), each
		// view alone over the middle of its span and eased into the next.
		float r0 = min(floor(sprite_view.x), cells.y - 1.0);
		float r1 = min(r0 + 1.0, cells.y - 1.0);
		float wr = smoothstep(0.25, 0.75, fract(sprite_view.x));
		float c0 = mod(floor(sprite_view.y), float(yaws));
		float c1 = mod(c0 + 1.0, float(yaws));
		float wc = smoothstep(0.25, 0.75, fract(sprite_view.y));
		sprite_sample(c0, r0, uv_in, gx, gy, a, nb);
		a *= (1.0 - wc) * (1.0 - wr);
		nb *= (1.0 - wc) * (1.0 - wr);
		vec4 a2;
		vec4 n2;
		if (wc > 0.0) {
			sprite_sample(c1, r0, uv_in, gx, gy, a2, n2);
			a += a2 * wc * (1.0 - wr);
			nb += n2 * wc * (1.0 - wr);
		}
		if (wr > 0.0) {
			sprite_sample(c0, r1, uv_in, gx, gy, a2, n2);
			a += a2 * (1.0 - wc) * wr;
			nb += n2 * (1.0 - wc) * wr;
			if (wc > 0.0) {
				sprite_sample(c1, r1, uv_in, gx, gy, a2, n2);
				a += a2 * wc * wr;
				nb += n2 * wc * wr;
			}
		}
	} else {
		// The cell: the nearest two heights and turns, dithered by their fractions.
		float h2 = fract(52.9829189 * fract(dot(FRAGCOORD.xy + vec2(23.0, 7.0), vec2(0.00583715, 0.06711056))));
		float h3 = fract(h2 * 7.31 + h * 0.61);
		float row = floor(sprite_view.x) + (h2 < fract(sprite_view.x) ? 1.0 : 0.0);
		row = min(row, cells.y - 1.0);
		float col = mod(floor(sprite_view.y) + (h3 < fract(sprite_view.y) ? 1.0 : 0.0), float(yaws));
		sprite_sample(col, row, uv_in, gx, gy, a, nb);
	}
	// The mips thin the cover: lift it with the mip so a far crown keeps its mass.
	float lod = log2(max(max(length(dFdx(UV)), length(dFdy(UV))) * cell_px, 1.0));
	float cover = a.a * (1.0 + 0.32 * lod);
	if (soft) {
		ALPHA = clamp(cover, 0.0, 1.0);
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		ALPHA_ANTIALIASING_EDGE = 0.3;
		ALPHA_TEXTURE_COORDINATE = UV * cell_px;
	} else {
		if (cover < 0.5) discard;
		ALPHA = 1.0;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
	edge = 1.0 - smoothstep(0.5, 0.95, cover);
	vec3 c = sprite_linear(clamp(a.rgb / max(a.a, 1e-3), 0.0, 1.0));
	c *= COLOR.rgb / max(tint, vec3(1e-3));
	sprite_tip = 0.0;
	if (spruce_var.y > 0.0) {
		// This tree's blue against the strength the atlas was baked at.
		float rank = fract(sin(dot(sprite_foot.xz, vec2(27.17, 63.41))) * 43758.5453);
		vec3 h = tint / max(sprite_luma(tint), 1e-3);
		vec3 glaucous = mix(ZS_SV_GLAUCOUS, vec3(1.0), 0.06);
		float kt = clamp(zs_sv_blue_k(sprite_foot.xz, rank, spruce_var) * blue_far, 0.0, 1.0);
		float kb = clamp(spruce_g.w * blue_far, 0.0, 1.0);
		c *= mix(h, glaucous, kt) / mix(h, glaucous, kb);
		sprite_tip = smoothstep(1.12, 1.45, sprite_luma(c) / max(mean_luma, 1e-3));
		c = zs_sv_keep(c, d, spruce_g.z);
	}
	if (spruce_tier2.y > 0.0) {
		// The dabs in the tree's own frame, on the quad's plane, sized for this distance.
		vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float rank_d = fract(sin(dot(sprite_foot.xz, vec2(27.17, 63.41))) * 43758.5453);
		c = zs_st_dabs(c, (wp.xz - sprite_foot.xz) + vec2(wp.y * 0.61, -wp.y * 0.37) + vec2(rank_d * 91.0, rank_d * 37.0), d, zs_st_pixel(d, PROJECTION_MATRIX[1][1], VIEWPORT_SIZE.y), spruce_tier2);
	}
	vec3 nv = sprite_linear(clamp(nb.rgb / max(nb.a, 1e-3), 0.0, 1.0)) * 2.0 - 1.0;
	vec3 n = normalize(nv.x * sprite_right + nv.y * sprite_up + nv.z * sprite_toward);
	if (sprite_sheen > 0.0) c = zs_tree_sheen(c, sprite_sheen);
	if (far_look > 0.0) {
		// Weight and depth: the tone of the near crowns, the understorey dark,
		// the side away from the sun in its shade, each tree its own.
		float r1 = sprite_lod_hash(sprite_foot.xz + vec2(7.3, 2.9));
		float r2 = sprite_lod_hash(sprite_foot.xz + vec2(41.7, 13.3));
		float l = sprite_luma(c);
		c *= pow(clamp(l / max(mean_luma, 1e-3), 0.3, 3.0), far_shape.w);
		c *= far_shape.x;
		float low = 1.0 - smoothstep(0.0, 0.7, sprite_up_tree);
		c *= 1.0 - far_shape.y * low * (1.0 - 0.7 * sprite_look_down);
		float s = dot(n, zs_key_direction);
		c *= mix(1.0 - far_shape.z, 1.0, smoothstep(-0.55, 0.4, s));
		c *= 1.0 + (r1 - 0.5) * 2.0 * far_vary.y;
		c *= mix(vec3(1.05, 1.0, 0.9), vec3(0.93, 1.0, 1.08), r2);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	vec3 ol = zs_cool(zs_st_shade(spruce_tier.w), shade_follow) * sprite_luma(c);
	EMISSION = mix(c, ol, tone.w) * hemi + mix(c, ol, tone.y) * hemi * tone.x + mix(c, ol, olive) * zs_look_bounce_light(n);
}

void light() {
	float d = dot(NORMAL, LIGHT);
	vec3 crown_sun = LIGHT_COLOR * mix(tone.z, 1.0, ATTENUATION);
	float lit = clamp((d + sun.x) / (1.0 + sun.x), 0.0, 1.0);
	float tier = lit * 3.0;
	float t = clamp((floor(tier) + smoothstep(0.5 - sun.w, 0.5 + sun.w, fract(tier))) / 3.0, 0.0, 1.0);
	t = mix(lit, t, sun.z);
	DIFFUSE_LIGHT += crown_sun * t * mix(mix(vec3(0.96, 0.99, 1.04), vec3(1.04, 1.02, 0.94), t), ZS_ST_WARM, spruce_tier2.x * t) / PI;
	float through = pow(max(dot(-LIGHT, VIEW), 0.0), 2.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * sun.y * max(-d, 0.0) * (0.3 + 0.7 * through) * vec3(0.9, 1.0, 0.85) / PI;
	// Backlight: the crown's silhouette, seen against a low sun, catches it.
	if (max(zs_backlight, spruce_rim.z) > 0.0 && LIGHT_IS_DIRECTIONAL && dot((INV_VIEW_MATRIX * vec4(LIGHT, 0.0)).xyz, zs_key_direction) > 0.999) {
		float edge_glow = max(0.6 * pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0), edge);
		if (spruce_rim.x > 0.0) {
			edge_glow = max(edge_glow, sprite_tip * spruce_rim.w);
			DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * zs_backlight_tint_warm(ALBEDO, zs_backlight_amount_floor(max(zs_backlight, spruce_rim.z), dot(-LIGHT, VIEW), edge_glow, BACKLIGHT_GAIN * spruce_rim.x / 3.0), spruce_rim.y) / PI;
		} else if (zs_backlight > 0.0) {
			DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * zs_backlight_tint(ALBEDO, zs_backlight_amount(dot(-LIGHT, VIEW), edge_glow, BACKLIGHT_GAIN)) / PI;
		}
	}
	if (zs_look_fill > 0.0 && LIGHT_IS_DIRECTIONAL) {
		vec3 fill_light = zs_look_fill_light(1.0 - ATTENUATION * smoothstep(0.0, 0.2, max(d, 0.0)));
		float la = sprite_luma(ALBEDO);
		fill_light *= mix(vec3(1.0), clamp(zs_cool(zs_st_shade(spruce_tier.w), shade_follow) * la / max(ALBEDO, vec3(0.03)), 0.0, 3.0), olive);
		DIFFUSE_LIGHT += fill_light;
	}
}
