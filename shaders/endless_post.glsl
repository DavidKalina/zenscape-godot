#[compute]
#version 450
// The endless flight's light pass (scripts/endless/endless_post.gd, docs/
// design/endless-flight/light-atmosphere-handoff.md): a compute pass on the
// frame after everything is drawn (the clouds and the valley fog too), that
//   - lays the haze's colour per pixel: the depth fog is one colour for the
//     whole view, so the sky's own horizon toward each pixel's heading
//     (`lut`, by the angle to the sun) replaces it by the fog's own share,
//     then a second air goes cool away from the sun and warm toward it, so
//     ridges layer;
//   - splits the light: shade pulled toward the mood's shadow colour, the lit
//     side toward the sun's, contrast and saturation;
//   - gathers light shafts toward the sun through the gaps the land, the
//     cloud and the valley fog leave: a radial march over the sky's openness
//     (the depth buffer) and the clouds' opacity.
// Each pixel reads and writes only itself in the colour image.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
	vec4 lens;     // tan_x, tan_y, near, far
	vec4 right;    // camera basis x
	vec4 up;       // y
	vec4 back;     // z
	vec4 sun;      // direction xyz; the flat sun direction (x, z) in zw, unit
	vec4 haze;     // begin, end, curve, share
	vec4 facing;   // the haze colour the fog painted (rgb); hue share
	vec4 air;      // strength, scale m, air_sun power, -
	vec4 air_cool;
	vec4 air_warm;
	vec4 split;    // split, contrast, saturation, -
	vec4 shade;    // shade tint
	vec4 light;    // light tint
	vec4 luma;     // luma x, y; rim strength; rim reach (px at 900 lines)
	vec4 rays;     // sun uv xy; strength; reach
	vec4 rays_col; // rgb; the sky's share
	vec4 frame;    // aspect, width, height, taps
	vec4 lut[17];  // the horizon's colour by the angle to the sun (0 away, 1 toward)
} P;

layout(set = 0, binding = 1) uniform sampler2D scene_depth;
layout(set = 0, binding = 2) uniform sampler2D cloud_shape;
layout(rgba16f, set = 0, binding = 3) uniform restrict image2D color_image;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

vec3 horizon_toward(vec3 rd) {
	vec2 flat_dir = rd.xz / max(length(rd.xz), 1e-4);
	float t = clamp(dot(flat_dir, P.sun.zw) * 0.5 + 0.5, 0.0, 1.0) * 16.0;
	int i = min(int(t), 15);
	return mix(P.lut[i].rgb, P.lut[i + 1].rgb, t - float(i));
}

float interleaved(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(color_image);
	if (any(greaterThanEqual(pixel, size))) return;
	vec2 uv = (vec2(pixel) + 0.5) / vec2(size);
	vec4 src = imageLoad(color_image, pixel);
	vec3 col = src.rgb;
	float d = texelFetch(scene_depth, min(pixel, textureSize(scene_depth, 0) - 1), 0).r;
	bool land = d > 0.0;
	vec3 vd = normalize(vec3((uv.x * 2.0 - 1.0) * P.lens.x, (1.0 - uv.y * 2.0) * P.lens.y, -1.0));
	vec3 rd = normalize(P.right.xyz * vd.x + P.up.xyz * vd.y + P.back.xyz * vd.z);
	float cloud = texelFetch(cloud_shape, min(pixel, textureSize(cloud_shape, 0) - 1), 0).x;
	float clear = 1.0 - clamp(cloud, 0.0, 1.0);
	float dist = 0.0;
	if (land) {
		float z = P.lens.z * P.lens.w / (P.lens.z + d * (P.lens.w - P.lens.z));
		dist = z / max(-vd.z, 1e-4);
	}
	float toward = max(dot(rd, P.sun.xyz), 0.0);

	if (land) {
		vec3 sky = horizon_toward(rd);
		if (P.facing.w > 0.0) {
			float f = pow(smoothstep(P.haze.x, P.haze.y, dist), P.haze.z) * P.haze.w;
			col += f * P.facing.w * clear * (sky - P.facing.rgb);
		}
		if (P.air.x > 0.0) {
			float k = (1.0 - exp(-dist / P.air.y)) * P.air.x;
			float s = pow(toward, P.air.z);
			col = mix(col, sky * mix(P.air_cool.rgb, P.air_warm.rgb, s), clamp(k, 0.0, 0.85) * clear);
		}
	}

	if (P.split.x > 0.0 && land) {
		float l = dot(col, LUMA);
		float shade = 1.0 - smoothstep(P.luma.x, P.luma.y * 0.6, l);
		float lit = smoothstep(P.luma.y * 0.35, P.luma.y * 1.6, l);
		float near = 1.0 - smoothstep(1500.0, 6000.0, dist);
		col *= mix(vec3(1.0), P.shade.rgb, shade * P.split.x * near);
		col *= mix(vec3(1.0), P.light.rgb, lit * P.split.x);
		float l2 = dot(col, LUMA);
		col = mix(vec3(l2), col, P.split.z);
		col *= pow(clamp(max(l2, 1e-3) / 0.2, 0.25, 4.0), P.split.y - 1.0);
	}

	// A rim of the sun's light where land meets the sky on the sun's side.
	if (land && P.luma.z > 0.0 && P.rays.z > 0.0) {
		vec2 dir = P.rays.xy - uv;
		float len = length(dir * vec2(P.frame.x, 1.0));
		if (len > 0.02) {
			dir = normalize(dir * vec2(P.frame.x, 1.0)) / vec2(P.frame.x, 1.0);
			float reach = P.luma.w * float(size.y) / 900.0;
			float rim = 0.0;
			for (int i = 1; i <= 6; i++) {
				float r = reach * float(i) / 6.0;
				vec2 q = uv + dir * (r / float(size.y));
				ivec2 qp = ivec2(q * vec2(size));
				bool inside = all(greaterThanEqual(qp, ivec2(0))) && all(lessThan(qp, size));
				float open = (!inside || texelFetch(scene_depth, qp, 0).r > 0.0) ? 0.0 : 1.0;
				rim = max(rim, open * (1.0 - float(i - 1) / 6.0));
			}
			float lum = dot(col, LUMA);
			col += P.rays_col.rgb * rim * P.luma.z * P.rays.z * (0.35 + 0.65 * smoothstep(0.0, 0.3, lum)) * (0.4 + 0.6 * smoothstep(0.0, 0.5, dot(rd, P.sun.xyz)));
		}
	}
	// Sky pixels already carry the sun's glow: shafts are for the land.
	if (land && P.rays.z > 0.0) {
		vec2 aspect = vec2(P.frame.x, 1.0);
		vec2 to_sun = P.rays.xy - uv;
		float reach = length(to_sun * aspect);
		float fall = 1.0 - smoothstep(0.1, P.rays.w, reach);
		if (fall > 0.0) {
			float jitter = interleaved(vec2(pixel));
			int taps = int(P.frame.w);
			float acc = 0.0;
			for (int i = 0; i < taps; i++) {
				float t = (float(i) + jitter) / float(taps);
				vec2 q = mix(uv, P.rays.xy, t * 0.95);
				ivec2 qp = ivec2(q * vec2(size));
				float open = texelFetch(scene_depth, min(qp, textureSize(scene_depth, 0) - 1), 0).r > 0.0 ? 0.0 : 1.0;
				float c = texelFetch(cloud_shape, min(qp, textureSize(cloud_shape, 0) - 1), 0).x;
				float source = open * (1.0 - clamp(c, 0.0, 1.0) * 0.9) * exp(-length((q - P.rays.xy) * aspect) * 6.0);
				acc += source * (1.0 - t * 0.4);
			}
			acc /= float(taps) * 0.5;
			float veil = 1.0 - exp(-dist / 700.0);
			col += P.rays_col.rgb * acc * fall * P.rays.z * veil;
		}
	}
	imageStore(color_image, pixel, vec4(max(col, vec3(0.0)), src.a));
}
