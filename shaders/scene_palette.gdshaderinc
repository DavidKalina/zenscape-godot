// Multipliers preserve authored facet variation and explicit per-object tints.
global uniform vec3 zs_palette_grass;
global uniform vec3 zs_palette_foliage;
global uniform vec3 zs_palette_rock;
global uniform vec3 zs_palette_earth;
// 0 = creatures/petals, 1 = ground, 2 = foliage, 3 = stone, 4 = earth/wood, 5 = grass.
uniform int palette_role = 0;
// The ground's palette: green takes the grass, earthy colours the earth,
// grey ones the rock, near-white (snow) none. The plate's earth sides use it
// too, so their strata match the cut ground beside them (scripts/strata.gd).
vec3 scene_palette_ground(vec3 color) {
	float green = smoothstep(0.005, 0.06, color.g - max(color.r, color.b));
	float snow = smoothstep(0.55, 0.82, min(color.r, min(color.g, color.b)));
	float earth = max(smoothstep(0.06, 0.10, color.r - color.g) * smoothstep(0.08, 0.13, color.g - color.b),
		smoothstep(0.015, 0.04, color.r - color.g) * (1.0 - smoothstep(0.16, 0.25, color.r)));
	vec3 mineral = mix(zs_palette_rock, zs_palette_earth, earth);
	return color * mix(mix(mineral, zs_palette_grass, green), vec3(1.0), snow);
}
vec3 scene_palette(vec3 color) {
	if (palette_role == 1) return scene_palette_ground(color);
	if (palette_role == 2) return color * zs_palette_foliage;
	if (palette_role == 3) return color * zs_palette_rock;
	if (palette_role == 4) return color * zs_palette_earth;
	if (palette_role == 5) return color * zs_palette_grass;
	return color;
}
