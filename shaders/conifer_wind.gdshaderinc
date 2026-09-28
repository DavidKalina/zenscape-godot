uniform float conifer_height = 4.3;
// Shared by trunk and crown so their overlapping geometry stays connected.
// Delayed spatial samples soften a traveling gust without per-tree CPU state.
vec3 zs_conifer_offset(vec3 vertex, mat4 model) {
	vec2 root = model[3].xz;
	float height = max(vertex.y, 0.0);
	float bend = pow(clamp(height / conifer_height, 0.0, 1.0), 2.4);
	float phase = dot(root, vec2(0.43, 0.71));
	float travel = zs_gust_distance;
	float speed = zs_gust_speed;
	float field = zs_breeze_field_at(root, travel) * 0.2
		+ zs_breeze_field_at(root, travel - speed * 0.7) * 0.5
		+ zs_breeze_field_at(root, travel - speed * 1.4) * 0.3;
	float air = clamp(zs_wind_strength, 0.0, 2.0);
	float slow = 0.8 + 0.2 * sin(zs_motion_time * 0.9 + phase);
	vec2 motion = zs_wind_direction * bend * air * (0.08 + field * field * 0.42) * slow;
	vec3 local = zs_local_wind(vec3(root.x, model[3].y + height, root.y));
	motion += local.xz / (10.0 + length(local)) * bend * 0.32;
	// Wide cone rims move a little; the narrow trunk receives no tip flutter.
	float rim = smoothstep(0.25, 0.85, length(vertex.xz));
	vec2 crosswind = vec2(-zs_wind_direction.y, zs_wind_direction.x);
	motion += crosswind * rim * bend * air * field * 0.025
		* sin(zs_motion_time * 3.2 + height * 4.1 + phase);
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
	return inverse(mat3(model)) * vec3(motion.x, -droop, motion.y) * length(model[1].xyz);
}
