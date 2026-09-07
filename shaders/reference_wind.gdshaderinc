#include "res://shaders/reference_globals.gdshaderinc"
// The original wind.js two-octave gust field, advected by integrated air travel.
// All scenery samples the same world-space parcel of air.

float zs_noise_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float zs_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(zs_noise_hash(i), zs_noise_hash(i + vec2(1.0, 0.0)), f.x),
		mix(zs_noise_hash(i + vec2(0.0, 1.0)), zs_noise_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float zs_gust_parts_at(vec2 position, float travel, out float puff) {
	vec2 dir = zs_wind_direction;
	vec2 q = position - dir * travel;
	vec2 p = vec2(dot(q, dir), dot(q, vec2(-dir.y, dir.x))) * vec2(0.09, 0.20);
	float field = zs_noise(p) * 0.62 + zs_noise(p * 2.3 + vec2(3.7, 9.1 + travel * 0.05)) * 0.38;
	float pulse = 0.0;
	vec4 parcels[6] = vec4[6](zs_puff_0, zs_puff_1, zs_puff_2, zs_puff_3, zs_puff_4, zs_puff_5);
	for (int i = 0; i < 6; i++) {
		vec4 parcel = parcels[i];
		if (parcel.w <= 0.0) continue;
		float age = travel - parcel.z;
		vec2 relative = position - (parcel.xy + dir * age);
		float along = dot(relative, dir);
		float across = dot(relative, vec2(-dir.y, dir.x));
		float shape = exp(-(along * along * 0.02778 + across * across * 0.07716));
		float life = smoothstep(0.0, 1.5, age) * (1.0 - smoothstep(30.0, 52.0, age));
		pulse += parcel.w * shape * life;
	}
	float distance = length(position - zs_clap.xy) - zs_clap.z;
	float ring = zs_clap.w * exp(-distance * distance * (distance > 0.0 ? 0.17361 : 0.02041));
	puff = pulse + ring;
	return min(1.0, field + puff);
}

float zs_gust_field_at(vec2 position, float travel) {
	float puff;
	return zs_gust_parts_at(position, travel, puff);
}

float zs_gust_field(vec2 position) {
	return zs_gust_field_at(position, zs_gust_distance);
}

float zs_wind_at(vec2 position) {
	return zs_wind_strength * (0.45 + 1.1 * zs_gust_field(position));
}
