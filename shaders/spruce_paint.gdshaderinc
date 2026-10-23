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
const float SPRUCE_FILL = 0.6;

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
vec3 zs_spruce_paint(vec3 tint, vec3 world, vec2 root, float bake, float under, float blue, float paint) {
	float rank = zs_spruce_tree_rank(root);
	float tip = smoothstep(0.8, 1.0, bake);
	// Blue: the colour's own luminance in the glaucous hue, a little greyer
	// (dusty); some trees greener, some bluer.
	if (blue > 0.0) {
		float l = zs_spruce_luma(tint);
		vec3 glaucous = mix(SPRUCE_GLAUCOUS, vec3(1.0), 0.06) * l;
		tint = mix(tint, glaucous, clamp(blue * mix(0.62, 1.12, rank), 0.0, 1.0));
		tint *= mix(vec3(1.0), SPRUCE_FROST, tip * blue * 0.7);
	}
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
	float sunny = clamp((half_tree * 1.2 + clump * 1.0 + dab * 1.8 + (rank - 0.5) * 0.5) * paint, -1.0, 1.0);
	tint *= mix(vec3(1.0), sunny > 0.0 ? SPRUCE_SUNLIT : SPRUCE_DEEP, abs(sunny));
	float warm = clamp(grove * 2.4 + (rank - 0.5) * 0.6, -1.0, 1.0) * paint;
	tint *= mix(vec3(1.0), warm > 0.0 ? SPRUCE_WARM : SPRUCE_COOL, abs(warm) * 0.35);
	// The undersides and the depths cooler, never black: the bake already
	// darkens them, so this only lifts and cools them a little.
	float depth = 1.0 - smoothstep(0.45, 0.9, bake);
	tint *= mix(vec3(1.0), vec3(0.92, 1.0, 1.16), clamp((under * 0.6 + depth * 0.8) * paint, 0.0, 1.0));
	return tint;
}

// The carved rock's painted light (shaders/endless_rock.gdshaderinc, "the
// painted light"): the facet's sun in three soft steps, part of the way from
// the smooth term, here over a wrapped term so the shade side keeps some
// light. `d` is dot(normal, light).
float zs_spruce_painted_light(float d, float wrap) {
	float lit = clamp((d + wrap) / (1.0 + wrap), 0.0, 1.0);
	float steps = 3.0;
	float soft = 0.18;
	float tier = lit * steps;
	float t = floor(tier) + smoothstep(0.5 - soft, 0.5 + soft, fract(tier));
	t = clamp(t / steps, 0.0, 1.0);
	return mix(lit, t, 0.7);
}
