// The meadow flower kit's look (scripts/meadow_flower_mesh.gd,
// docs/scenic/flowers.md), for reference_surface.gdshader with
// `flower_heads`. Include after grass_look, which supplies the living green
// and the field's rolling wave. Adds no varyings: the surface shader is at
// Metal's limit.
#ifndef ZS_MEADOW_FLOWER
#define ZS_MEADOW_FLOWER

// The mesh's parts (UV2.x).
const float ZS_FLOWER_STEM = 0.0;
const float ZS_FLOWER_LEAF = 1.0;
const float ZS_FLOWER_DISC = 2.0;
const float ZS_FLOWER_PETAL = 3.0;
const float ZS_FLOWER_PUFF = 4.0;

// How much of the backlit glow each part takes: the seed puff glows fully,
// petals nearly, leaves a little, stems and discs hardly. The fragment
// reads 0.85 and over as petal or puff, and 1 as the puff alone.
const float ZS_FLOWER_PETAL_SHARE = 0.9;
// The seed clock's own soft glow, a share of the sky's light.
const float ZS_FLOWER_PUFF_LIGHT = 0.45;
float zs_flower_glow_share(float f_part) {
	if (f_part > 3.5) return 1.0;
	if (f_part > 2.5) return ZS_FLOWER_PETAL_SHARE;
	if (f_part > 1.5) return 0.3;
	if (f_part > 0.5) return 0.45;
	return 0.12;
}

// `f_v` turned `f_angle` radians about the unit `f_axis`.
vec3 zs_flower_turn(vec3 f_v, vec3 f_axis, float f_angle) {
	float f_c = cos(f_angle);
	float f_s = sin(f_angle);
	return f_v * f_c + cross(f_axis, f_v) * f_s + f_axis * dot(f_axis, f_v) * (1.0 - f_c);
}

// A petal colour leaned `f_pull` toward the family's grass ratio (the
// family over the source green), at unit luminance and clamped, so petals
// keep their own hue and only warm or cool a touch with the palette.
vec3 zs_flower_palette(vec3 f_color, vec3 f_ratio, float f_pull) {
	float f_lum = dot(f_ratio, vec3(0.30, 0.55, 0.15));
	vec3 f_lean = clamp(f_ratio / max(f_lum, 0.05), vec3(0.6), vec3(1.5));
	return f_color * mix(vec3(1.0), f_lean, clamp(f_pull, 0.0, 1.0));
}

// Sunlight through petals, strongest looking toward the sun and where the
// light comes from behind the head's mass. Called from light() under
// ZS_FLOWER_TRANSLUCENCY with the shadowed light energy. A petal glows its
// own colour, warmed a little.
vec3 zs_flower_translucency(vec3 f_to_light, vec3 f_to_view, vec3 f_normal, vec3 f_albedo, float f_share, float f_strength) {
	float f_toward = pow(max(dot(-f_to_light, f_to_view), 0.0), 3.0);
	float f_behind = 0.45 + 0.55 * max(-dot(f_normal, f_to_light), 0.0);
	return f_albedo * vec3(1.0, 0.96, 0.86) * f_strength * f_share * f_behind * (0.15 + 0.85 * f_toward) / PI;
}
#endif
