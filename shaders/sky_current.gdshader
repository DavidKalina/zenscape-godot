shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// The sky's currents (scripts/sky_currents.gd): faint threads of air
// flowing along each jet stream and drifting up each thermal, so the air
// you can ride shows if you look for it. Each is a fine stroke that swells
// and fades, tinted by the sky it crosses and only a touch warmer towards
// the sun: air, not ice.
// The paths come in `paths`: one row per current, `samples` points (xyz,
// node-local), then (length, speed, radius, swirl) and (closed, kind).
// Instance custom data: row (0..1), where along it starts, a seed, a size.
#include "res://shaders/reference_globals.gdshaderinc"

uniform sampler2D paths : filter_nearest;
uniform int samples = 64;
// Strokes are kept at least MIN_PIXELS wide; far off they are threads.
const float MIN_PIXELS = 1.0;

varying float opacity;
varying vec2 across;
varying float sun;

vec3 point_at(int row, float u, bool closed) {
	float x = closed ? fract(u) * float(samples) : clamp(u, 0.0, 1.0) * float(samples - 1);
	int i0 = int(floor(x));
	int i1 = closed ? (i0 + 1) % samples : min(i0 + 1, samples - 1);
	return mix(texelFetch(paths, ivec2(i0 % samples, row), 0).xyz, texelFetch(paths, ivec2(i1, row), 0).xyz, fract(x));
}

void vertex() {
	vec4 seed = INSTANCE_CUSTOM;
	int rows = textureSize(paths, 0).y;
	int row = int(seed.x * float(rows));
	vec4 info = texelFetch(paths, ivec2(samples, row), 0);
	vec4 flags = texelFetch(paths, ivec2(samples + 1, row), 0);
	bool closed = flags.x > 0.5;
	bool thermal = flags.y > 0.5;
	float len = max(info.x, 1.0);
	// Each wisp runs a little faster or slower than the air.
	float pace = info.y * (0.75 + 0.5 * seed.z);
	float u = seed.y + zs_motion_time * pace / len;
	u = fract(u);
	float step_u = 1.0 / len;
	vec3 here = (MODEL_MATRIX * vec4(point_at(row, u, closed), 1.0)).xyz;
	vec3 ahead = (MODEL_MATRIX * vec4(point_at(row, u + step_u, closed), 1.0)).xyz;
	vec3 way = normalize(ahead - here + vec3(0.0, 1e-5, 0.0));
	// Spread through the current's width, turning round it as it goes.
	vec3 ref = abs(way.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 side = normalize(cross(way, ref));
	vec3 up = cross(side, way);
	float angle = seed.z * 6.2831 + u * len * info.w;
	float r = info.z * (thermal ? 0.35 + 0.65 * sqrt(fract(seed.z * 7.31)) : 0.75 * sqrt(fract(seed.z * 7.31)));
	vec3 round_ = side * cos(angle) + up * sin(angle);
	vec3 centre = here + round_ * r;
	// A thermal's wisps lean round as they rise.
	vec3 dir = normalize(way + (thermal ? cross(way, round_) * r * info.w : vec3(0.0)));
	vec3 to_eye = CAMERA_POSITION_WORLD - centre;
	float away = length(to_eye);
	vec3 wide = cross(dir, to_eye / max(away, 0.001));
	wide = length(wide) > 0.001 ? normalize(wide) : INV_VIEW_MATRIX[0].xyz;
	float pixel = away * 2.0 * tan(0.5 * 1.2) / max(VIEWPORT_SIZE.y, 1.0);
	float width = (thermal ? 0.14 : 0.2) * (0.6 + 0.8 * seed.w);
	float drawn = max(width, pixel * MIN_PIXELS);
	float long_ = (thermal ? 4.0 : 16.0) * (0.6 + 0.8 * seed.w);
	vec3 world = centre + wide * VERTEX.x * drawn + dir * VERTEX.y * long_;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	across = VERTEX.xy * 2.0;
	// In and out at an open current's ends, thinned when drawn wider than
	// it is, gone right at the eye and far away.
	float ends = closed ? 1.0 : smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(0.8, 1.0, u));
	opacity = ends * (width / drawn) * smoothstep(2.0, 8.0, away) * (1.0 - smoothstep(900.0, 1600.0, away)) * (0.07 + 0.09 * seed.w);
	sun = max(dot(-to_eye / max(away, 0.001), normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0))), 0.0);
}

void fragment() {
	// Soft across, a swell in the middle along.
	float a = 1.0 - smoothstep(0.0, 1.0, abs(across.x));
	float b = 1.0 - smoothstep(0.2, 1.0, abs(across.y));
	// The sky's own light, a breath brighter, warming a little sunward.
	vec3 air = min(zs_cloud_sky * 1.05 + zs_cloud_sun * 0.2, vec3(1.0));
	ALBEDO = air * mix(vec3(1.0), vec3(1.04, 1.0, 0.94), sun);
	ALPHA = a * a * b * b * opacity;
}
