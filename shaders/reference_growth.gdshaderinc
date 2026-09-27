#include "res://shaders/reference_globals.gdshaderinc"
// weather.js uses the mean terrain delay for its baked height-field occlusion.
// Retain the invalid-height sentinel outside the imported island.
float zs_drawn_ground(float height) {
	if (height < -100.0) return height;
	float hn = clamp((height - 0.6) / max(zs_summit.y - 0.6, 0.001), 0.0, 1.0);
	float grown = smoothstep(0.13 + hn * 0.48, 0.43 + hn * 0.48, zs_growth.x);
	return mix(0.6, height, grown);
}

// RGBA: finished surface, terrain, water bed, water level. Separate terrain
// from water so rain/fog follow a filling lake instead of its final waterline.
float zs_surface_height(vec4 data, vec4 stream) {
	float ground = zs_drawn_ground(data.g);
	if (zs_growth.x < 0.995 || zs_water_growth < 0.001 || data.a < -100.0) return ground;
	float water = data.a;
	if (data.b < data.a - 0.001) {
		float fill = smoothstep(0.2, 0.85, zs_water_growth);
		if (fill < 0.001) return ground;
		water = mix(data.b, data.a, fill);
	} else {
		float arrived = smoothstep(stream.r, stream.r + 0.14, smoothstep(0.1, 0.7, zs_water_growth));
		if (stream.a < 0.5 || arrived < max(stream.g, 0.001)) return ground;
		water = mix(stream.b, water, arrived);
	}
	return max(ground, water);
}

// 1 where a grown pond or stream stands over the ground, 0 on dry land. Ground
// mists thin over it so water reads clear and reflective.
float zs_open_water(vec4 data, vec4 stream) {
	if (data.a < -100.0) return 0.0;
	return smoothstep(0.02, 0.12, zs_surface_height(data, stream) - zs_drawn_ground(data.g));
}
