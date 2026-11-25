#ifndef ZS_DISTANCE_READ_INC
#define ZS_DISTANCE_READ_INC
// The land reading with depth from flying height (scripts/endless/
// distance_read.gd, docs/design/endless-flight/handoff-distance-read.md).
// No dependencies; every global is 0 off the endless land, so the isles'
// surfaces that include it are unchanged.
//
// zs_dread: x the tree crowns' extra haze at full, y how far the grass under a
// full wood goes to the floor's shade, z the trees' per-tree spread, w how
// much the tufts under a full wood shrink.
global uniform vec4 zs_dread;
// The crowns' haze colour (scene linear: endless_look `horizon` toward the
// facing, greyed a little) and in w how much of zs_dread.x shows now (less
// at a low sun, when a wood against the glow reads dark).
global uniform vec4 zs_haze_tint;
// The near woods' floor weight, a texel every 16 m over 4096 m, wrapped
// (scripts/endless/wood_map.gd).
global uniform sampler2D zs_wood_map : filter_linear, repeat_enable;

// The crowns' extra haze at `dist` m: none in the first 150 m, all of
// zs_dread.x by 1.8 km. Dark shapes give distance away; the engine's fog lays
// its own on top.
float zs_tree_haze(float dist) {
	return zs_dread.x * zs_haze_tint.w * smoothstep(150.0, 1800.0, dist);
}

// The same mixed into a lit surface: albedo scaled down and the haze added as
// emission is mix(lit, haze, e) on the lit colour (light() and the ambient
// both go through ALBEDO).
#define ZS_TREE_HAZE(e) ALBEDO *= 1.0 - (e); EMISSION = EMISSION * (1.0 - (e)) + zs_haze_tint.rgb * (e)

// The woods' weight (0..1) at a world xz (0 with the part off).
float zs_wood_at(vec2 xz) {
	if (zs_dread.y <= 0.0 && zs_dread.w <= 0.0) return 0.0;
	return textureLod(zs_wood_map, xz / 4096.0, 0.0).r;
}

// The grass colour under the woods: darker and cooler, toward the floor's
// shade (land_trees FLOOR_COLOUR over the meadow's green).
vec3 zs_wood_grass(vec3 c, float w) {
	return c * mix(vec3(1.0), vec3(0.5, 0.6, 0.72), clamp(w * zs_dread.y, 0.0, 1.0));
}

// A tuft's size under the woods.
float zs_wood_tuft(float w) {
	return 1.0 - w * zs_dread.w;
}

// Each spruce its own value and hue, from a hash of its foot (the same on the
// near crown, the rings and the sprites): most a little lighter or darker,
// a fifth near blue-black, a quarter olive, the odd one paler and greyer.
vec3 zs_tree_vary(vec3 c, vec2 root) {
	float s = zs_dread.z;
	if (s <= 0.0) return c;
	float h1 = fract(sin(dot(root, vec2(91.7, 23.3))) * 43758.5453);
	float h2 = fract(sin(dot(root, vec2(17.1, 57.9))) * 24634.6345);
	vec3 k = vec3(0.82 + 0.34 * h1);
	vec3 hue = vec3(1.0);
	if (h2 < 0.2) hue = vec3(0.6, 0.7, 0.86);
	else if (h2 < 0.45) hue = vec3(1.12, 1.04, 0.66);
	else if (h2 > 0.93) {
		float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
		c = mix(c, vec3(l), 0.5 * s);
		hue = vec3(1.15);
	}
	return mix(c, c * k * hue, s);
}
#endif
