// The land's haze with a height term (scripts/endless/endless_look.gd, docs/
// design/endless-flight/spec-peak.md): the engine's depth fog, laid by the
// material instead (writing FOG replaces it), so ground standing high keeps
// its form from far off. The same distance curve and the same colour as the
// engine's (the horizon colour toward the eye's facing, a share of the sky
// behind each pixel, the sun's scatter), its amount scaled down by
// `haze_height.z` where the ground stands over `haze_height.x` m above the sea,
// reaching the full cut `haze_height.y` m higher. Strength 0 is the engine's
// own look again, only drawn here.
// Needs reference_sky_common and reference_display included, and `sea_y`.
uniform vec4 haze_depth = vec4(120.0, 7600.0, 0.75, 1.0);
uniform vec4 haze_height = vec4(350.0, 300.0, 0.6, 0.0);
uniform vec3 haze_light = vec3(0.5, 0.6, 0.8);
uniform vec3 haze_sun = vec3(0.0);
uniform vec2 haze_mix = vec2(0.35, 0.18);

vec4 zs_land_haze(vec3 view_pos, float ground_y, mat4 inv_view) {
	float t = smoothstep(haze_depth.x, haze_depth.y, length(view_pos));
	float amount = pow(t, haze_depth.z) * haze_depth.w;
	float up = smoothstep(haze_height.x, haze_height.x + haze_height.y, ground_y - sea_y + haze_height.w);
	amount *= 1.0 - up * haze_height.z;
	vec3 rd = normalize((inv_view * vec4(view_pos, 0.0)).xyz);
	vec3 dome = zsSkyBase(rd);
	dome *= 0.98 / max(max(max(dome.r, dome.g), dome.b), 0.98);
	vec3 col = mix(haze_light, scene_linear_for_display(dome), haze_mix.x);
	col += haze_sun * pow(max(dot(rd, zs_sun_direction), 0.0), 8.0) * haze_mix.y;
	return vec4(col, amount);
}
