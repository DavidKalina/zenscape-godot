// Many-pieces motion for the layered broadleaf (scripts/layered_tree.gd):
// each lump swings whole about its own pivot, the boughs sway slowly under
// them, and gusts roll through the crown as a front rather than all at once.
// Needs reference_wind.gdshaderinc. Model-space throughout.

vec3 zs_clump_rot(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

// A slow, smooth bob of the bough field, offset in model units. A function of
// position only (no per-piece data), so a bough's wood and the lump on its tip
// move together: both read it at points a few tenths of a metre apart.
// Nothing at the trunk's axis, most at the outer tips.
vec3 zs_bough_sway(vec3 p, mat4 model, float air_now) {
	vec2 flat_p = p.xz;
	float reach = length(flat_p);
	float lever = clamp((reach - 0.15) / 2.0, 0.0, 1.0);
	lever *= lever * smoothstep(2.4, 3.4, p.y);
	if (lever <= 0.0) return vec3(0.0);
	float phase = dot(flat_p, vec2(1.3, 0.9)) + dot(model[3].xz, vec2(0.37, 0.61));
	float t = zs_motion_time;
	float live = 0.55 + 0.6 * min(air_now, 1.5);
	float bob = (0.055 * sin(t * 0.75 + phase) + 0.03 * sin(t * 1.3 + phase * 1.9)) * live;
	float drift = 0.04 * sin(t * 0.55 + phase * 1.4 + 1.7) * live;
	vec2 out_dir = flat_p / max(reach, 0.001);
	vec2 around = vec2(-out_dir.y, out_dir.x);
	return lever * vec3(around.x * drift, bob, around.y * drift);
}
