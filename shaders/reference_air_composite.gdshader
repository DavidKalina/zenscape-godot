shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
#include "res://shaders/reference_air_sample.gdshaderinc"
uniform mat3 camera_basis;
uniform bool orthographic = false;
uniform vec2 projection_scale;
// Source AIR_STEPS: 16, integrated over frames by the temporal reuse in
// reference_air_resolve.gdshader, which also cycles `frame` and `jitter`.
uniform int air_steps = 16;
uniform int frame = 0;
// Ray nudge in this target's texels, so four marches between them visit every
// pixel of the resolved field.
uniform vec2 jitter = vec2(0.0);

void fragment() {
	vec2 uv = SCREEN_UV - jitter * SCREEN_PIXEL_SIZE;
	vec3 ro = zs_camera_position;
	vec3 rd = normalize(camera_basis * vec3((uv.x * 2.0 - 1.0) * projection_scale.x, (1.0 - uv.y * 2.0) * projection_scale.y, -1.0));
	if (orthographic) {
		ro += camera_basis * vec3((uv.x * 2.0 - 1.0) * projection_scale.x, (1.0 - uv.y * 2.0) * projection_scale.y, 0.0);
		rd = -camera_basis[2];
	}
	float drawn_floor = mix(0.6, floor_height, smoothstep(0.13, 0.43, zs_growth.x));
	float drawn_top = mix(9.6, zs_summit.y + 9.0, smoothstep(0.13, 0.43, zs_growth.x));
	vec3 inv = 1.0 / (rd + vec3(0.000001));
	vec3 a = (vec3(-14.0, drawn_floor - 0.5, -14.0) - ro) * inv;
	vec3 b = (vec3(14.0, drawn_top, 14.0) - ro) * inv;
	vec3 lo = min(a, b), hi = max(a, b);
	float near_t = max(max(max(lo.x, lo.y), lo.z), 0.0);
	float far_t = min(min(hi.x, hi.y), hi.z);
	vec3 scatter = vec3(0.0);
	float trans = 1.0;
	if (far_t > near_t) {
		float step_length = (far_t - near_t) / float(air_steps);
		float t = near_t + step_length * wxDither(SCREEN_UV / SCREEN_PIXEL_SIZE + float(frame) * 5.588238);
		for (int i = 0; i < air_steps; i++) {
			vec3 p = ro + rd * t;
			if (p.y < groundAt(p.xz) - 0.15 || trans < 0.03) break;
			vec4 air = zs_air_sample(p);
			float alpha = 1.0 - exp(-air.a * step_length);
			scatter += air.rgb * alpha * trans;
			trans *= 1.0 - alpha;
			t += step_length;
		}
	}
	// Source wxOut writes vec4(col * alpha, alpha) although col is already
	// premultiplied by each step's alpha and transmittance, so the stored
	// colour carries the ray's alpha twice. Thin air is then nearly pure
	// extinction and only thick air shows its colour: the fog reads as a dark
	// veil on lit ground instead of a milky one. Kept for parity.
	float alpha = 1.0 - trans;
	COLOR = vec4(scatter * alpha, alpha);
}
