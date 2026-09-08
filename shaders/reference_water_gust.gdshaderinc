// Local gust response shared by native ponds and source lakes. World-space
// phases preserve direction across chunk transforms. No gust means no change.
vec3 zs_water_gust(vec3 world_p) {
	float pulse = zs_gust_pulse_at(world_p.xz, zs_gust_distance);
	vec3 passing_air = vec3(zs_wind_direction.x, 0.0, zs_wind_direction.y) * pulse * 7.0;
	return (zs_local_wind(world_p) + passing_air) * (1.0 - zs_ice);
}
float zs_water_gust_height(vec3 world_p, float depth) {
	vec2 wind = zs_water_gust(world_p).xz;
	float speed = length(wind);
	vec2 direction = wind / max(speed, 0.0001);
	float phase = dot(world_p.xz, direction) * 2.8 - zs_flow_time * 4.0;
	float shore = smoothstep(0.02, 0.35, depth);
	return sin(phase) * min(speed * 0.005, 0.12) * shore;
}
vec3 zs_water_gust_normal(vec3 normal, vec3 world_p, float depth) {
	vec2 wind = zs_water_gust(world_p).xz;
	float speed = length(wind);
	if (speed <= 0.000001) return normal;
	vec2 direction = wind / max(speed, 0.0001);
	vec2 across = vec2(-direction.y, direction.x);
	float phase = dot(world_p.xz, direction) * 10.0 - zs_flow_time * 7.0;
	float broken = sin(dot(world_p.xz, across) * 3.1 + zs_flow_time * 1.5);
	vec2 slope = direction * cos(phase + broken * 0.6);
	float amplitude = min(speed * 0.012, 0.25) * smoothstep(0.02, 0.3, depth);
	return normalize(normal - vec3(slope.x, 0.0, slope.y) * amplitude);
}
// Analytic drag displacement, age-gated so new droplets stay at their emitter.
// Instantaneous field sampling keeps this light; no particle history is stored.
vec3 zs_spray_gust_offset(vec3 world_p, float age) {
	return zs_water_gust(world_p) * (0.20 * age * age);
}
vec3 zs_fall_gust_offset(vec3 world_p, float drop, float steep) {
	vec3 wind = zs_water_gust(world_p);
	// Only lateral deflection; gravity and the authored course dominate. Bound
	// the excursion and pin both lip and impact so the strand meets its foam.
	vec2 lateral = wind.xz / max(1.0, length(wind.xz) / 20.0);
	return vec3(lateral.x, 0.0, lateral.y) * (0.012 * sin(clamp(drop, 0.0, 1.0) * PI) * steep);
}
