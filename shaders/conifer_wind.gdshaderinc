#include "res://shaders/tree_wind.gdshaderinc"
uniform float conifer_height = 4.3;
// Shared by trunk and crown so their overlapping geometry stays connected.
// Delayed spatial samples soften a traveling gust without per-tree CPU state.
// `alive` adds the woods' gust waves, the boughs' own motion, more sway
// and the grass's stirring (eddies, gusts landing, the prop's wash)
// (tree_wind.gdshaderinc); `sheen` out: 0..1, how far a wave or a stir
// lifts the boughs here, for the crown's light.
vec3 zs_conifer_offset_alive(vec3 vertex, mat4 model, bool alive, out float sheen) {
	sheen = 0.0;
	vec2 root = model[3].xz;
	float height = max(vertex.y, 0.0);
	float bend = pow(clamp(height / conifer_height, 0.0, 1.0), 2.4);
	float phase = dot(root, vec2(0.43, 0.71));
	// The ambient breeze (reference_wind, docs/scenic/breeze.md): trunk and
	// crown lean together, the top lagging the air at the root and swaying
	// round its lean at a tall tree's slow pace, a beat behind the trunk.
	float k = clamp(height / conifer_height, 0.0, 1.0);
	float tall = conifer_height * length(model[1].xyz);
	float bow;
	float lean = zs_breeze_lean_at(root, ZS_BREEZE_LAG * tall * k, 0.0, bow);
	float wave = alive ? zs_tree_wave(root, ZS_BREEZE_LAG * tall * k) : 0.0;
	float sway = ZS_BREEZE_SWING;
	if (alive) {
		lean = lean * ZS_TREE_SWAY_LEAN + wave * ZS_TREE_WAVE_LEAN;
		sway = ZS_TREE_SWAY_SWING;
	}
	float gust = clamp(lean / 0.6, 0.0, 1.0);
	float pace = zs_breeze_pace(tall);
	float t = zs_motion_time;
	float swing = sin(t * pace + phase - k * 0.9) * 0.7 + sin(t * pace * 1.63 + phase * 1.7 - k * 1.3) * 0.3;
	float give = zs_blow_give(tall);
	vec2 crosswind = vec2(-zs_wind_direction.y, zs_wind_direction.x);
	vec2 motion = (zs_wind_direction * (1.0 + sway * swing) + crosswind * (0.22 * sin(t * pace * 0.71 + phase * 2.3 - k * 0.6)))
		* lean * give * conifer_height * bend;
	float stir = 0.0;
	if (alive) {
		// The grass's stirring, and the burrower's gust: all the wind's lean, only
		// more, swaying round it at this tree's pace as it lets go (zs_tree_gust).
		vec2 react = zs_tree_react(root, stir);
		vec2 over = zs_tree_gust(root, swing, phase, react, stir);
		// `over` shears, straight up the whole height (height / conifer_height, not
		// `k`): the trunk has a handful of rings and the crown many, so any curve or
		// clamp here parts them, more the harder it blows, and the trunk stands out.
		motion += (react * bend + over * (height / conifer_height)) * give * conifer_height;
	}
	vec3 local = zs_local_wind(vec3(root.x, model[3].y + height, root.y));
	motion += local.xz / (10.0 + length(local)) * bend * 0.32;
	// Wide cone rims flutter; the narrow trunk receives no tip flutter.
	float rim = smoothstep(0.25, 0.85, length(vertex.xz));
	motion += crosswind * rim * bend * zs_breeze_air() * (0.015 + 0.03 * gust)
		* sin(t * 6.5 + height * 4.1 + phase + dot(vertex.xz, vec2(3.1, 2.3)));
	// The wind tool (scripts/wind_gust.gd) bends the whole tree its own way,
	// trunk and crown together, with spring-back and a shiver in the rims.
	float blow_shiver;
	vec2 blow = zs_blow_at(root, phase, blow_shiver);
	float blow_size = length(blow);
	if (blow_size > 0.0001 || blow_shiver > 0.0) {
		float scale = length(model[1].xyz);
		motion += blow * zs_blow_give(conifer_height * scale) * conifer_height * bend;
		vec2 blow_across = blow_size > 0.0001 ? vec2(-blow.y, blow.x) / blow_size : crosswind;
		motion += blow_across * blow_shiver * rim * bend * conifer_height * 0.05 * sin(zs_motion_time * 11.0 + height * 4.1 + phase * 3.0);
	}
	float droop = dot(motion, motion) / max(2.0 * height, 0.5);
	// Trailing the block's dip (zs_heave, scripts/pull_feel.gd), trunk and
	// crown together.
	float heave = zs_heave * conifer_height * bend;
	vec3 offset = inverse(mat3(model)) * vec3(motion.x, heave - droop, motion.y) * length(model[1].xyz);
	if (alive) {
		float lift;
		offset += zs_tree_bough(vertex, phase, max(zs_tree_wave(root, 0.0), stir), lift);
		sheen = max(wave, stir * 0.8);
	}
	return offset;
}

vec3 zs_conifer_offset(vec3 vertex, mat4 model) {
	float sheen;
	return zs_conifer_offset_alive(vertex, model, false, sheen);
}
