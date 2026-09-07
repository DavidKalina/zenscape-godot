shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Source weather.js §2c temporal reuse: the march landed on a target half
// this size in each axis, drawn with its rays nudged `jitter` march texels, so
// what stands at this pixel is stored `jitter` texels along. Last frame's field
// is found by reprojecting where this pixel's fog stands through last frame's
// camera, clamped to the new sample's 3x3 neighbourhood so a field that
// changes lands in a frame or two, and blended under the new sample.
uniform sampler2D march : filter_linear, repeat_disable;
uniform sampler2D history : filter_linear, repeat_disable;
uniform sampler2D surface_depth : filter_nearest, repeat_disable;
uniform bool history_ok = false;
uniform float blend_weight = 0.12;
uniform vec2 low_res = vec2(1.0);
uniform vec2 jitter = vec2(0.0);
uniform vec2 camera_planes = vec2(0.05, 100.0);
uniform mat3 camera_basis;
uniform vec3 camera_position;
uniform vec2 projection_scale = vec2(1.0);
uniform bool orthographic = false;
uniform mat3 prev_camera_basis;
uniform vec3 prev_camera_position;
uniform vec2 prev_projection_scale = vec2(1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 uv_march = uv + jitter / low_res;
	vec4 cur = texture(march, uv_march);
	// The neighbourhood the history may not leave.
	vec4 lo = cur, hi = cur;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			if (x == 0 && y == 0) continue;
			vec4 s = texture(march, uv_march + vec2(float(x), float(y)) / low_res);
			lo = min(lo, s);
			hi = max(hi, s);
		}
	}
	vec4 kept = cur;
	float weight = 1.0;
	if (history_ok) {
		// Where this pixel's fog stands: the march stops at the surface behind
		// it, and mass pools just above it, so the surface depth is its stand-in;
		// open sky is treated as the far plane. A reprojection error from that
		// stand-in is the clamp's job.
		float depth = texture(surface_depth, uv).r;
		vec3 view_ray = vec3((uv.x * 2.0 - 1.0) * projection_scale.x, (1.0 - uv.y * 2.0) * projection_scale.y, -1.0);
		vec3 p;
		if (orthographic) {
			float view_depth = depth > 0.0 ? mix(camera_planes.y, camera_planes.x, depth) : camera_planes.y;
			p = camera_position + camera_basis * vec3(view_ray.xy, -view_depth);
		} else {
			float view_depth = depth > 0.0 ? camera_planes.x * camera_planes.y / (camera_planes.x + depth * (camera_planes.y - camera_planes.x)) : camera_planes.y;
			p = camera_position + camera_basis * (view_ray * view_depth);
		}
		vec3 v = transpose(prev_camera_basis) * (p - prev_camera_position);
		vec2 ndc;
		bool ahead;
		if (orthographic) {
			ndc = v.xy / prev_projection_scale;
			ahead = true;
		} else {
			ndc = (v.xy / -v.z) / prev_projection_scale;
			ahead = v.z < 0.0;
		}
		vec2 puv = vec2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
		if (ahead && all(greaterThan(puv, vec2(0.0))) && all(lessThan(puv, vec2(1.0)))) {
			kept = clamp(texture(history, puv), lo, hi);
			weight = blend_weight;
		}
	}
	COLOR = mix(kept, cur, weight);
}
