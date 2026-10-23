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

// A pixel's view-space position from the depth buffer (false: sky).
bool view_pos(ivec2 q, out vec3 pos) {
	ivec2 ts = textureSize(scene_depth, 0);
	q = clamp(q, ivec2(0), ts - 1);
	float d = texelFetch(scene_depth, q, 0).r;
	if (d <= 0.0) { pos = vec3(0.0); return false; }
	float z = P.lens.z * P.lens.w / (P.lens.z + d * (P.lens.w - P.lens.z));
	vec2 uv = (vec2(q) + 0.5) / vec2(ts);
	pos = vec3((uv.x * 2.0 - 1.0) * P.lens.x * z, (1.0 - uv.y * 2.0) * P.lens.y * z, -z);
	return true;
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

	// Fog and cloud in front of land are laid over it as the opaque pass left
	// it, so a dark tuft or tree behind thin fog shows as a cutout in it: the
	// fog's own colour is the floor under it, in step with its opacity.
	if (land && cloud > 0.03) {
		// Mostly grey: the sky's own blue lifted per channel turned every shadow
		// in the fog violet.
		vec3 h = horizon_toward(rd);
		vec3 fogc = mix(vec3(dot(h, LUMA)), h, 0.3) * mix(vec3(0.95, 0.97, 1.03), vec3(1.06, 1.0, 0.94), pow(toward, P.air.z)) * 0.8;
		col = max(col, fogc * clamp(cloud, 0.0, 1.0) * P.rays_col.w * 7.0);
	}
	if (P.split.x > 0.0 && land) {
		float l = dot(col, LUMA);
		float shade = 1.0 - smoothstep(P.luma.x, P.luma.y * 0.6, l);
		float lit = smoothstep(P.luma.y * 0.35, P.luma.y * 1.6, l);
		float near = 1.0 - smoothstep(1500.0, 6000.0, dist);
		// The surface's normal and curvature from the depth buffer: the shade's
		// fill (bounce and sky) and the sunlit face's relief read off them.
		vec3 nrm = vec3(0.0, 1.0, 0.0);
		float curv = 0.0;
		float have_n = 0.0;
		if (near > 0.0 && (P.split.w > 0.0 || P.shade.w > 0.0 || P.light.w > 0.0)) {
			vec3 c0, xl, xr, yu, yd;
			bool ok = view_pos(pixel, c0);
			ok = ok && view_pos(pixel + ivec2(-2, 0), xl) && view_pos(pixel + ivec2(2, 0), xr);
			ok = ok && view_pos(pixel + ivec2(0, -2), yu) && view_pos(pixel + ivec2(0, 2), yd);
			if (ok) {
				vec3 dx = abs(xr.z - c0.z) < abs(c0.z - xl.z) ? xr - c0 : c0 - xl;
				vec3 dy = abs(yd.z - c0.z) < abs(c0.z - yu.z) ? yd - c0 : c0 - yu;
				vec3 nv = normalize(cross(dx, -dy));
				if (nv.z < 0.0) nv = -nv;
				nrm = normalize(P.right.xyz * nv.x + P.up.xyz * nv.y + P.back.xyz * nv.z);
				// Second difference of the range over a pixel's footprint: + convex.
				float foot = 2.0 * dist * P.lens.y / (0.5 * float(size.y)) * 2.0;
				curv = clamp((xl.z + xr.z + yu.z + yd.z - 4.0 * c0.z) * -1.0 / max(foot, 1e-3), -1.5, 1.5);
				have_n = 1.0;
			}
		}
		float ndl = dot(nrm, P.sun.xyz);
		float facing = have_n * smoothstep(0.3, 0.95, ndl) * smoothstep(-0.02, 0.15, P.sun.y);
		col *= mix(vec3(1.0), P.shade.rgb, shade * P.split.x * near);
		// Sky fill and bounce into the shade: proportional to the surface's own
		// colour, so the rock keeps its form, with the cool sky colour as a floor.
		if (P.split.w > 0.0) {
			float up_fill = have_n > 0.5 ? 0.55 + 0.45 * nrm.y : 1.0;
			float away = have_n > 0.5 ? 1.0 - 0.5 * clamp(ndl, 0.0, 1.0) : 1.0;
			col += shade * near * P.split.w * up_fill * away * (mix(P.air_cool.rgb * horizon_toward(-P.sun.xyz), vec3(0.55), 0.35) * 0.13 + col * 0.95);
		}
		col *= mix(vec3(1.0), P.light.rgb, lit * P.split.x);
		// The sunlit face: ridges catch the light and creases keep their shade,
		// the brightest face going warm to hot.
		if (facing > 0.0) {
			float rel = facing * near * (0.5 + 0.5 * lit);
			col *= 1.0 + clamp(curv * 0.9, -0.5, 0.6) * P.shade.w * rel;
			col *= mix(vec3(1.0), vec3(1.22, 1.05, 0.78), smoothstep(0.7, 1.0, ndl) * lit * rel * P.light.w);
		}
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
	// Sky pixels already carry the sun's glow: shafts are for the land (and
	// the air over it). A radial march toward the sun over how open the line
	// is: even weights, so pixels whose lines cross a ridge or a cloud's edge
	// differ from their neighbours' (rays), not one glow round the sun.
	if (P.rays.z > 0.0) {
		vec2 aspect = vec2(P.frame.x, 1.0);
		vec2 to_sun = P.rays.xy - uv;
		float reach = length(to_sun * aspect);
		float fall = (1.0 - smoothstep(0.12, P.rays.w * 1.8, reach)) * smoothstep(0.03, 0.14, reach);
		if (fall > 0.0) {
			float jitter = interleaved(vec2(pixel));
			int taps = int(P.frame.w);
			float acc = 0.0;
			for (int i = 0; i < taps; i++) {
				float t = (float(i) + jitter) / float(taps);
				vec2 q = mix(uv, P.rays.xy, t * 0.97);
				ivec2 qp = ivec2(q * vec2(size));
				float open = texelFetch(scene_depth, min(qp, textureSize(scene_depth, 0) - 1), 0).r > 0.0 ? 0.0 : 1.0;
				float c = texelFetch(cloud_shape, min(qp, textureSize(cloud_shape, 0) - 1), 0).x;
				acc += open * (1.0 - clamp(c, 0.0, 1.0) * 0.95);
			}
			acc /= float(taps);
			// Rays are the line's open share where a lit sky is in reach: the
			// low sun's air carries them, the high sun's is thin.
			float low_sun = 1.0 - smoothstep(0.12, 0.65, P.sun.y);
			float shaft = pow(acc, 1.3) * (land ? 1.0 : 1.2);
			float veil = land ? 1.0 - exp(-dist / mix(900.0, 450.0, low_sun)) : 0.8;
			float gain = P.rays.z * mix(0.5, 5.5, low_sun);
			col += P.rays_col.rgb * shaft * fall * gain * veil * (0.55 + 0.45 * toward);
		}
	}
	imageStore(color_image, pixel, vec4(max(col, vec3(0.0)), src.a));
}
