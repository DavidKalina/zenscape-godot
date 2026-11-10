// Autumn by place: a world map of where the land wears autumn (0..1), over
// a square (zs_autumn_rect: its corner x, z, its side in m; side 0 none).
// Set by the Peak's shelf (scripts/endless/peak_massif.gd `autumn_map`);
// without one the rect's side is 0 and every reader leaves its colour be.
#ifndef ZS_AUTUMN_PLACE
#define ZS_AUTUMN_PLACE

global uniform sampler2D zs_autumn_mask : filter_linear, repeat_disable;
global uniform vec4 zs_autumn_rect;

// (.x the ground that wears it, .y its colour spilt down the drops by it.)
vec2 zs_autumn_map(vec2 xz) {
	if (zs_autumn_rect.z <= 0.0) return vec2(0.0);
	vec2 uv = (xz - zs_autumn_rect.xy) / zs_autumn_rect.z;
	if (uv.x <= 0.0 || uv.y <= 0.0 || uv.x >= 1.0 || uv.y >= 1.0) return vec2(0.0);
	return texture(zs_autumn_mask, uv).rg;
}

float zs_autumn_here(vec2 xz) {
	return zs_autumn_map(xz).x;
}

// A tree's crown turned: gold, amber or red by the tree (one pick per root),
// keyed on the crown's green (or blue-green) over red, so trunks and bark stay.
void zs_autumn_tree(inout vec3 color, vec2 root, float amount) {
	if (amount <= 0.004) return;
	float green = smoothstep(-0.01, 0.04, color.g - color.r);
	float pick = fract(sin(dot(root, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 hue = pick < 0.4 ? vec3(1.0, 0.62, 0.10) : (pick < 0.75 ? vec3(1.0, 0.40, 0.07) : vec3(0.78, 0.17, 0.05));
	float lum = dot(color, vec3(0.30, 0.55, 0.15));
	color = mix(color, hue * (lum * 3.4), amount * green);
}

// Turf turned: gold through amber to rust in drifts tens of metres across
// (`drift` 0..1, the caller's noise), keeping the colour's own light.
vec3 zs_autumn_turf(vec3 color, float drift) {
	float lum = dot(color, vec3(0.30, 0.55, 0.15));
	vec3 hue = mix(vec3(1.0, 0.60, 0.12), vec3(1.0, 0.40, 0.08), smoothstep(0.25, 0.6, drift));
	hue = mix(hue, vec3(0.70, 0.18, 0.06), smoothstep(0.6, 0.9, drift));
	return hue * (lum * 3.1);
}

#endif
