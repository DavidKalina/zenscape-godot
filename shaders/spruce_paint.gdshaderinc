// The sprays spruce's painted crown (--spruce=sprays; scripts/hero_trees.gd
// `spruce_paint`), all off at 0 so every other user of reference_surface is
// unchanged. Three parts, each the world's own technique:
// - the crown lit as a volume: the light normal bends out from the trunk
//   (spruce_round), so light rolls round the crown instead of each bough
//   sheet taking its own flat shade;
// - a blue spruce's glaucous blue-green (spruce_blue), each tree a little
//   bluer or greener, the needle tips frostier;
// - the painted ground's patches (shaders/endless_ground.gdshader's sun/deep
//   patches and warm/cool drift, on endless_patch's ep_fade / ep_patch) and
//   the carved rock's stepped light (shaders/endless_rock.gdshaderinc's
//   "painted light"), with a soft forward scatter so a backlit crown glows
//   instead of going black.
// Needs shaders/endless_patch.gdshaderinc included first.
// --spruce-look=g (shaders/spruce_variety.gdshaderinc): most trees green, a
// share blue by grove, the inner needles olive and the tips fresh.
#include "res://shaders/spruce_variety.gdshaderinc"

// The glaucous hue (linear, over its own luminance): sRGB about (0.39, 0.55, 0.63).
const vec3 SPRUCE_GLAUCOUS = vec3(0.50, 1.08, 1.45);
// The frost the tips lean to (linear multiplier over the crown's colour).
const vec3 SPRUCE_FROST = vec3(1.10, 1.22, 1.34);
// The ground's patch tones (endless_ground SUNLIT / DEEP over GREEN, as
// multipliers) and its warm/cool drift.
const vec3 SPRUCE_SUNLIT = vec3(1.20, 1.18, 1.02);
const vec3 SPRUCE_DEEP = vec3(0.70, 0.78, 0.90);
const vec3 SPRUCE_WARM = vec3(1.32, 1.05, 0.62);
const vec3 SPRUCE_COOL = vec3(0.80, 0.97, 1.16);

float zs_spruce_luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// A hash of the tree's foot: 0..1, one value per tree.
float zs_spruce_tree_rank(vec2 root) {
	return fract(sin(dot(root, vec2(27.17, 63.41))) * 43758.5453);
}

// The sky's fill on the crown over the plain hemisphere term: the world's
// shade sides read soft and lit (the ground's hemisphere, the clouds' lift),
// a dense crown's would read black.
// The shaded side's olive (over the crown's own luminance), like the world's shadows (hue 66-100).
const vec3 SPRUCE_SHADE_OLIVE = vec3(1.20, 1.05, 0.22);

// The light normal of a crown lit as a volume: out from the trunk and up,
// `round` of the way from the face's own normal. `out_xz` is the point's
// offset from the trunk (m).
vec3 zs_spruce_volume_normal(vec3 face, vec2 out_xz, float round) {
	float r = length(out_xz);
	vec2 dir = out_xz / max(r, 1e-3) * smoothstep(0.0, 0.5, r);
	vec3 crown = normalize(vec3(dir.x, 0.62, dir.y));
	return normalize(mix(face, crown, round));
}

// The crown's colour: hue, frost and the painted patches.
// `bake` is the generator's grey (0.42 core, 0.55 at the trunk, 1.02 at the
// tips); `under` 1 where the eye sees a bough's underside.
// `gv` and `gt` are the g look's variety (share, grove scale, lean, green's own
// blue) and needles (inner, fresh, haze, and a blue strength forced for the
// sprites' atlas, -1 off); gv.y 0 is the round-5 look.
vec3 zs_spruce_paint(vec3 tint, vec3 world, vec2 root, float bake, float under, float blue, float paint, vec2 tone, vec4 tone2, float dist, vec4 gv, vec4 gt) {
	float rank = zs_spruce_tree_rank(root);
	float bake_raw = bake;
	// Far off the bake's light and dark and the deep blue ease to the crown's mean (tone2.w is 0 in round 3).
	float away = smoothstep(40.0, 160.0, dist) * step(0.001, tone2.w);
	bake = mix(bake, 0.85, away);
	blue *= 1.0 - 0.45 * away;
	float tip = smoothstep(0.8, 1.0, bake);
	// Blue: the colour's own luminance in the glaucous hue, a little greyer
	// (dusty); some trees greener, some bluer.
	if (blue > 0.0) {
		float l = zs_spruce_luma(tint);
		vec3 glaucous = mix(SPRUCE_GLAUCOUS, vec3(1.0), 0.06) * l;
		float k = mix(0.62, 1.12, rank);
		float frost = 1.0;
		if (gv.y > 0.0) {
			k = gt.w >= 0.0 ? gt.w : zs_sv_blue_k(root, rank, gv);
			frost = clamp(k, 0.0, 1.0);
		}
		tint = mix(tint, glaucous, clamp(blue * k, 0.0, 1.0));
		tint *= mix(vec3(1.0), SPRUCE_FROST, tip * blue * 0.7 * frost);
	}
	// Flatten the bake's light/dark toward its mean (0.7): less contrast.
	tint *= pow(clamp(bake, 0.25, 1.3) / 0.85, -tone.x * 0.6);
	// The g look: the older inner needles olive and dark, the fresh tips light, on the whole bake.
	if (gv.y > 0.0) tint = zs_sv_needles(tint, bake_raw, gt.x, gt.y);
	if (paint <= 0.0) return tint;
	float fp = length(fwidth(world));
	// The world's xz with height folded in, so the dabs differ up the tree.
	vec2 p = world.xz + vec2(world.y * 0.61, -world.y * 0.37);
	// The ground's patches at a tree's scales: the drift across a wood, a
	// tree's light and deep halves, bough clumps and dabs with an edge.
	float grove = ep_fade(p + vec2(311.0, 97.0), 70.0, fp);
	float half_tree = ep_fade(p + vec2(71.0, 13.0), 4.5, fp);
	float clump = ep_fade(p + vec2(5.0, 211.0), 1.5, fp);
	float dab = ep_patch(p + vec2(57.0, 19.0), 0.45, fp) * 1.0 + ep_patch(p + vec2(3.0, 77.0), 1.4, fp) * 0.8;
	// Fine speckle (tone2.x): small dabs with a hard edge, like the ground's
	// edged clumps, so a crown carries grain rather than big tier blocks.
	float speck = ep_patch(p + vec2(19.0, 143.0), 0.16, fp) + ep_patch(p + vec2(88.0, 31.0), 0.33, fp) * 0.9
		+ ep_patch(p + vec2(41.0, 7.0), 0.075, fp) * 0.8;
	float sunny = clamp((half_tree * 1.2 + clump * 1.0 + dab * 1.8 * tone.y + speck * 3.2 * tone2.x + (rank - 0.5) * 0.5) * paint, -1.0, 1.0);
	tint *= mix(vec3(1.0), sunny > 0.0 ? SPRUCE_SUNLIT : mix(SPRUCE_DEEP, vec3(0.80, 0.80, 0.70), tone2.z), abs(sunny));
	float warm = clamp(grove * 2.4 + (rank - 0.5) * 0.6, -1.0, 1.0) * paint;
	tint *= mix(vec3(1.0), warm > 0.0 ? SPRUCE_WARM : SPRUCE_COOL, abs(warm) * 0.35);
	// The undersides and the depths cooler, never black: the bake already
	// darkens them, so this only lifts and cools them a little.
	float depth = 1.0 - smoothstep(0.45, 0.9, bake);
	tint *= mix(vec3(1.0), mix(vec3(0.92, 1.0, 1.16), vec3(1.0, 1.02, 0.94), tone2.z), clamp((under * 0.6 + depth * 0.8) * paint, 0.0, 1.0));
	// The shaded depths lean olive, the lit tips keep the blue-green (tone2.z, round 4).
	tint *= mix(vec3(1.0), vec3(1.10, 1.04, 0.66), depth * tone2.z * 0.45);
	return tint;
}

// Texture variants (--spruce-texture=a|c, scripts/hero_trees.gd; 0 off). Bough
// space from the generator (tools/blender_trees/spruce_sprays.py): `uv` is
// (along the bough 0..1, the bough's own hash 0..1), `uv2` (across: 0 on the
// spine, +-0.4 at a notch, +-1 at a tooth's tip; the bough's length in model
// units). The core has along 0 and length 0.
// - a (1): each bough like a grass blade: dark where it leaves the tier, light at
//   its tip, each tooth lighter to its tip, and its own value and hue.
// - c (3): soft irregular dabs laid along each bough, stretched along it, each
//   bough's own, so they never line up across boughs.
// `gain` scales either; both fade by `dist` (m) and the pixel's footprint.
vec3 zs_spruce_texture(vec3 tint, int mode, vec2 uv, vec2 uv2, float gain, float dist) {
	float t = uv.x;
	float h = uv.y;
	float s = uv2.x;
	float L = uv2.y;
	float near = 1.0 - smoothstep(40.0, 120.0, dist);
	if (mode == 1) {
		float h2 = fract(h * 7.31 + 0.27);
		// Most of a bough's area is a little inside its middle, so the ramp's mean sits there.
		float grad = mix(0.86, 1.20, smoothstep(0.28, 1.0, t));
		grad *= mix(0.97, 1.12, smoothstep(0.4, 1.0, abs(s)));
		float own = 1.0 + (h - 0.5) * 0.22;
		vec3 hue = mix(vec3(1.05, 1.02, 0.88), vec3(0.95, 1.0, 1.08), h2);
		vec3 m = mix(vec3(1.0), grad * own * hue, L > 0.0 ? 1.0 : 0.4);
		return tint * mix(vec3(1.0), m, clamp(gain * mix(0.5, 1.0, near), 0.0, 2.0));
	}
	if (mode == 3 && L > 0.0) {
		float a = t * L;
		float fp = fwidth(a);
		float keep = (1.0 - smoothstep(0.004, 0.02, fp)) * near;
		if (keep <= 0.0) return tint;
		// Along in model units (a tooth is 0.07), across a side in about two.
		vec2 q = vec2(a / 0.05, s * 2.2) + vec2(h * 53.0, h * 29.0);
		q += vec2(ep_noise(q * 0.6 + vec2(h * 31.0, 7.0)) - 0.5, (ep_noise(q * 0.8 + vec2(3.0, h * 17.0)) - 0.5) * 0.6) * 1.4;
		float n = ep_noise(q) * 0.65 + ep_noise(q * vec2(2.1, 1.7) + vec2(11.0, 5.0)) * 0.35;
		float dab = smoothstep(0.54, 0.64, n) - smoothstep(0.46, 0.36, n);
		vec3 lit = vec3(1.27, 1.25, 1.08);
		vec3 deep = vec3(0.76, 0.79, 0.72);
		return tint * mix(vec3(1.0), dab > 0.0 ? lit : deep, abs(dab) * clamp(gain * keep, 0.0, 2.0));
	}
	return tint;
}

// The carved rock's painted light (shaders/endless_rock.gdshaderinc, "the
// painted light"): the facet's sun in three soft steps, part of the way from
// the smooth term, here over a wrapped term so the shade side keeps some
// light. `d` is dot(normal, light).
float zs_spruce_painted_light(float d, float wrap, float stepmix, float soft) {
	float lit = clamp((d + wrap) / (1.0 + wrap), 0.0, 1.0);
	float steps = 3.0;
	float tier = lit * steps;
	float t = floor(tier) + smoothstep(0.5 - soft, 0.5 + soft, fract(tier));
	t = clamp(t / steps, 0.0, 1.0);
	return mix(lit, t, stepmix);
}
