#include "res://shaders/reference_cloud_field.gdshaderinc"
// Source cloud deck / 3-tap self-shadow march: 26 steps as a ceiling with the
// source's world-unit step floor, composited in the sky.
vec4 zs_cloud_march(vec3 ro, vec3 rd, vec2 pixel) {
	if (rd.y < 0.002 || zs_cloud.x < 0.001) return vec4(0.0);
	float ta = (zs_cloud.z - ro.y) / rd.y;
	float tb = (zs_cloud.z + zs_cloud.w - ro.y) / rd.y;
	float enter = max(min(ta, tb), 0.0);
	float leave = min(max(ta, tb), 900.0);
	if (leave <= enter) return vec4(0.0);
	float step_length = max((leave - enter) / 26.0, zs_cloud.w * 0.085);
	float t = enter + step_length * wxDither(pixel);
	float phase = hg(dot(rd, zs_cloud_direction), 0.62) * 5.0 + 1.15;
	vec3 col = vec3(0.0);
	float trans = 1.0;
	for (int i = 0; i < 26; i++) {
		if (trans < 0.02 || t > leave) break;
		vec3 p = ro + rd * t;
		float d = cloudAt(p);
		if (d > 0.002) {
			float lit = 0.0;
			float ls = zs_cloud.w * 0.16;
			for (int k = 1; k <= 3; k++) lit += cloudRough(p + zs_cloud_direction * (float(k) * ls)) * ls;
			float sun_amount = exp(-lit * 0.42) + 0.28 * exp(-lit * 0.06);
			float h = clamp((p.y - zs_cloud.z) / zs_cloud.w, 0.0, 1.0);
			vec3 ambient = mix(zs_cloud_sky, zs_cloud_sky * 0.30, zs_cloud.y) * (0.55 + 1.10 * h);
			vec3 shade = zs_cloud_sun * sun_amount * phase + ambient;
			float fd = length(p - zs_flash.xyz);
			shade += vec3(0.75, 0.85, 1.0) * zs_flash.w * 90.0 / (fd * fd + 40.0);
			float alpha = 1.0 - exp(-d * step_length * 0.09);
			col += shade * alpha * trans;
			trans *= 1.0 - alpha;
		}
		t += step_length;
	}
	float alpha = (1.0 - trans) * smoothstep(0.0, 0.11, rd.y);
	col = mix(col, zs_cloud_sky * 1.1, clamp(zs_haze * 0.9 * smoothstep(0.35, 0.0, rd.y), 0.0, 1.0));
	if (alpha < 0.004) return vec4(0.0);
	// Preserve source wxOut's premultiplied output convention.
	return vec4(col * alpha, alpha);
}
