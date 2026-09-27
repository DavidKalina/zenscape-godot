// Display-space fog field adapted from the native/source shared atmosphere.
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_growth.gdshaderinc"
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"

uniform float shroud = 0.0;
uniform float loosen = 0.0;
uniform vec3 fog_display;
uniform float density = 0.45;
uniform float floor_height = 0.15;
uniform float haze = 0.15;
uniform float rays = 1.0;
uniform sampler2D stream_map : filter_nearest, repeat_disable;
uniform sampler2D ground_map : filter_nearest, repeat_disable;

float groundAt(vec2 p) {
	if (max(abs(p.x), abs(p.y)) > 16.0) return -1000.0;
	return zs_surface_height(texture(ground_map, (p + 16.0) / 32.0), texture(stream_map, (p + 16.0) / 32.0));
}
#include "res://shaders/reference_orographic.gdshaderinc"
#include "res://shaders/reference_inversion.gdshaderinc"

vec4 zs_air_sample(vec3 p) {
	float ground = groundAt(p.xz);
	float over = p.y - ground;
	float pool = exp(-max(over, 0.0) * 0.55) * exp(-max(p.y - mix(0.6, 0.15, smoothstep(0.13, 0.43, zs_growth.x)), 0.0) * 0.085);
	vec3 q = p * vec3(0.22, 0.42, 0.22) + vec3(zs_cloud_drift.x * 3.0, zs_motion_time * 0.012, zs_cloud_drift.z * 3.0)
		- vec3(zs_wind_direction.x, 0.0, zs_wind_direction.y) * zs_gust_distance * (0.03 + 0.19 * loosen);
	float noise = 0.55 + 0.75 * wxFbm(q);
	float fade = 1.0 - smoothstep(0.75, 1.0, max(abs(p.x), abs(p.z)) / 14.0);
	float lid = 0.6 + 1.8 + (noise - 0.9) * 1.8;
	float bank = 1.0 - smoothstep(lid - 1.2, lid + 1.6, p.y);
	float g = 0.5, puff = 0.0;
	if (bank > 0.002 || pool > 0.03) g = zs_gust_parts_at(p.xz, zs_gust_distance, puff);
	float along = dot(p.xz, zs_wind_direction) / 14.0;
	float torn = 0.5 - 0.22 * along + (0.42 + 0.4 * loosen) * (g - 0.5);
	float left = shroud * 1.12;
	float keep = 1.0 - smoothstep(left - 0.14, left + 0.14, torn);
	keep *= 1.0 - loosen * 0.75 * smoothstep(0.55, 0.95, g);
	keep *= 1.0 - smoothstep(0.12, 0.5, puff) * (0.55 + 0.45 * loosen);
	float blank = shroud * (0.38 + 0.28 * noise) * bank * keep;
	float stream = 0.72 + 0.56 * g;
	// A fresh land stroke parts the fog over what it made (scripts/stroke_feedback.gd).
	float reveal = zs_reveal_keep(p.xz);
	float d = (density * pool * noise * 0.36 * stream + haze * 0.026 + blank) * fade * reveal;
	if (over < -0.4 || ground < -100.0) d = 0.0;
	float open_sky = cloudShadeAt(p, zs_cloud_direction);
	float ag_band = max(0.8, 0.08 * (zs_summit.y - 0.15));
	float ag_line = mix(0.15 - ag_band, zs_summit.y + ag_band, zs_alpen.y);
	open_sky *= mix(1.0, smoothstep(ag_line - ag_band * 0.5, ag_line + ag_band * 0.5, p.y), zs_alpen.x);
	vec3 rd = normalize(p - zs_camera_position);
	float phase = hg(dot(rd, zs_cloud_direction), 0.35) * 1.6 + 0.30;
	vec3 lit = zs_cloud_sun * open_sky * phase * rays * 0.55
		+ zs_cloud_sky * (0.85 + 0.45 * clamp(over * 0.12, 0.0, 1.0));
	float altitude = clamp((p.y - 0.15) / max(zs_summit.y - 0.15, 0.001), 0.0, 1.0);
	lit += vec3(1.0, 0.42, 0.40) * zs_alpen.z * smoothstep(0.30, 0.90, altitude) * 0.22;
	float cap = orogAt(p, ground) * fade;
	if (over < -0.4 || ground < -100.0) cap = 0.0;
	if (cap > 0.0005) {
		vec3 ps = p + zs_cloud_direction * 1.3;
		float shadow = orogAt(ps, groundAt(ps.xz));
		float sun_amount = exp(-shadow * 0.9) + 0.25;
		float cap_phase = hg(dot(rd, zs_cloud_direction), 0.55) * 3.0 + 1.0;
		vec3 cap_light = zs_cloud_sun * open_sky * sun_amount * min(cap_phase, 1.7) * 0.42 + zs_cloud_sky * 0.7;
		lit = (lit * d + cap_light * cap) / (d + cap);
	}
	float inversion = ground < -100.0 || over < -0.4 ? 0.0 : zs_inversion_at(p) * (1.0 - shroud) * reveal;
	if (inversion > 0.0) {
		lit = (lit * (d + cap) + zs_inversion_color * mix(0.8, 1.0, open_sky) * inversion) / max(d + cap + inversion, 0.0001);
	}
	d += inversion;
	lit = mix(lit, fog_display, shroud);
	float fd = length(p - zs_flash.xyz);
	lit += vec3(0.7, 0.82, 1.0) * zs_flash.w * 120.0 / (fd * fd + 60.0);
	d += cap;
	return vec4(lit, d);
}
