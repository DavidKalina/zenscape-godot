// aerial.js AERIAL_FOG_GLSL, applied after tone mapping as in Three.js.
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_inversion_surface.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/glide_haze.gdshaderinc"
uniform sampler2D surface_depth : repeat_disable, filter_nearest;
uniform vec2 camera_planes;
uniform mat3 surface_camera_basis;
uniform bool surface_orthographic = false;
uniform vec2 surface_projection_scale;
uniform bool surface_inversion_enabled = true;
uniform float surface_density = 0.0;
uniform float aerial_gain = 1.0;
uniform vec3 surface_fog_color;
uniform vec3 aerial_sun_color;
// Islands still rising into place (scripts/sky_haze.gd `emerging`): each
// box's low corner and how hidden it still is (w, 0 to 1), and its high
// corner, in world metres. What stands inside is hazed that much more, so
// a new island comes up out of the haze rather than appearing.
uniform vec4 glide_emerge_lo[4];
uniform vec4 glide_emerge_hi[4];
// Mountain ranges risen through the sea (scripts/sky_haze.gd `publish`):
// each (x, z) middle, reach (m), and 1 if standing. What stands within a
// reach takes the landform's gentler curve (zs_glide_fog_far).
uniform vec4 glide_peaks[2];
// The mountain ring (scripts/sky_world.gd, sky_haze.gd `publish`): the
// world's middle (x, z), and the distance from it (m) the ring's curve
// starts at (z) and has taken over by (w); w 0 with no ring.
uniform vec4 glide_ring = vec4(0.0);
// The build view's mountains (scripts/sky_haze.gd `overview`): the plate's
// middle (x, z), and the distance from it (m) where its own haze gives way
// (z) to the ring's skyline curve (w), so ranges a kilometre and more off
// stand pale in the distance rather than gone into the plate's haze. Only
// the ranges stand that far off in the build view. w 0 with no ring.
uniform vec4 overview_far = vec4(0.0);

// The cloud sea the glide flies over, as the sky's material has it
// (scripts/sky_haze.gd `publish`): x its strength, y its style (0 Opal,
// 1 Storybook, 2 Mystic).
uniform vec2 glide_sea = vec2(0.0);

// The air the cloud sea lifts into far off, below the horizon, in its own
// style (shaders/sky_cloud_sea_*.gdshaderinc), from the horizon it is given:
// Opal's luminous pearl haze, Storybook's heaps fading into the horizon,
// and Mystic's by day cleaned of a dusty horizon to a pale pearl.
vec3 zs_glide_sea_air(vec3 horizon) {
	const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);
	float overcast = smoothstep(0.35, 0.9, zs_cloud.x);
	float lum = dot(horizon, LUMA);
	if (glide_sea.y > 1.5) {
		float day = smoothstep(0.1, 0.32, zs_sun_direction.y) * (1.0 - zs_night) * (1.0 - 0.6 * overcast);
		float top = max(horizon.r, max(horizon.g, horizon.b));
		float sat = (top - min(horizon.r, min(horizon.g, horizon.b))) / max(top, 1e-4);
		float dusty = smoothstep(0.0, 0.08, (horizon.r - horizon.b) / max(top, 1e-4)) * (1.0 - smoothstep(0.28, 0.5, sat));
		vec3 hue = mix(max(horizon, vec3(0.0)) / max(lum, 1e-4), max(zs_sky_up, vec3(0.0)) / max(dot(zs_sky_up, LUMA), 1e-4), 0.8);
		return mix(horizon, lum * 0.96 * mix(vec3(1.0), hue, 0.12), day * dusty);
	}
	if (glide_sea.y > 0.5) return horizon;
	float level = max(lum, 0.17 * zs_night * zs_celestial_clear) * (1.0 + 0.3 * overcast * (1.0 - zs_night));
	vec3 sun_hue = zs_cloud_sun / max(max(max(zs_cloud_sun.r, zs_cloud_sun.g), zs_cloud_sun.b), 1e-3);
	float golden = smoothstep(0.35, 0.06, zs_sun_direction.y) * smoothstep(-0.12, 0.0, zs_sun_direction.y) * (1.0 - overcast);
	vec3 pearl = mix(vec3(0.97, 0.97, 1.0), sun_hue, mix(0.35, 0.5, golden));
	return mix(horizon, pearl * level, 0.45);
}

// The glide's haze colour along a world ray: what the sky draws behind it
// there. Above the horizon that is the dome's own gradient (zsSkyBase) with
// the sun's aureole, so far things warm toward the sun as the air round it
// does; below, the cloud sea's far air (zs_glide_sea_air) as its veil comes
// in (shaders/sky_cloud_sea.gdshaderinc zs_sea_veil), so islands below the
// eye melt into the sea's haze, not into a colour of their own. Dimmed with
// the night as the sea's horizon is, and at night the sea is pulled down
// under the stars as the dome pulls it, so the dark is never lifted.
// Display colour, as the dome writes it.
vec3 zs_glide_horizon(vec3 ray) {
	vec3 toward = normalize(vec3(ray.x, max(ray.y, 0.0), ray.z) + vec3(0.0, 1e-5, 0.0));
	float dim = mix(1.0, 0.4, zs_night * zs_celestial_clear);
	vec3 col = zsSkyBase(toward);
	float high = smoothstep(0.02, 0.4, zs_sun_direction.y);
	float sun_away = sqrt(max(2.0 * (1.0 - dot(toward, zs_sun_direction)), 0.0));
	vec3 glow = mix(vec3(1.0, 0.42, 0.12), vec3(1.0, 0.8, 0.52), high);
	col += glow * exp(-sun_away / 0.16) * mix(0.16, 0.07, high) * zs_celestial_clear * smoothstep(-0.06, 0.01, zs_sun_direction.y);
	col *= dim;
	vec2 seen = normalize(ray.xz + 1e-5);
	vec3 sea = zs_glide_sea_air(zsSkyBase(vec3(seen.x, 0.0, seen.y)) * dim);
	float deep = zs_night * zs_celestial_clear;
	float veil = glide_sea.x * smoothstep(-0.02, -0.16, ray.y) * mix(1.0, smoothstep(-0.34, -0.66, ray.y), deep);
	col = max(mix(col, sea, veil), vec3(0.0));
	return col * 0.98 / max(max(max(col.r, col.g), col.b), 0.98);
}

// How much more a rising island at `point` is hidden.
float zs_glide_emerge(vec3 point) {
	float hidden = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 lo = glide_emerge_lo[i];
		if (lo.w <= 0.0) continue;
		vec3 hi = glide_emerge_hi[i].xyz;
		vec3 inside = min(point - lo.xyz, hi - point);
		hidden = max(hidden, lo.w * smoothstep(-3.0, 1.0, min(min(inside.x, inside.y), inside.z)));
	}
	return hidden;
}

// How far onto the landform's curve a surface point is: inside a range's
// reach, eased off over its last tenth.
float zs_glide_peak(vec3 point) {
	float far = 0.0;
	for (int i = 0; i < 2; i++) {
		vec4 p = glide_peaks[i];
		if (p.w <= 0.0) continue;
		far = max(far, p.w * (1.0 - smoothstep(p.z * 0.9, p.z, length(point.xz - p.xy))));
	}
	return far;
}

// How far onto the ring's curve a surface point is: none inside the
// world's bounds, all past the ring's start.
float zs_glide_ring(vec3 point) {
	if (glide_ring.w <= 0.0) return 0.0;
	return smoothstep(glide_ring.z, glide_ring.w, length(point.xz - glide_ring.xy));
}

vec3 zs_surface_haze(vec3 color, vec2 uv) {
	vec2 depth_sample = texture(surface_depth, uv).rg;
	float depth = depth_sample.r;
	if (depth <= 0.0) return color;
	float view_depth = camera_planes.x * camera_planes.y / (camera_planes.x + depth * (camera_planes.y - camera_planes.x));
	vec3 view_ray = vec3((uv.x * 2.0 - 1.0) * surface_projection_scale.x, (1.0 - uv.y * 2.0) * surface_projection_scale.y, -1.0);
	vec3 offset = surface_camera_basis * view_ray * view_depth;
	float ray_length = max(length(offset), 0.001);
	vec3 ray = offset / ray_length;
	vec3 ray_origin = zs_camera_position;
	if (surface_orthographic) {
		view_depth = mix(camera_planes.y, camera_planes.x, depth);
		vec3 lateral = surface_camera_basis * vec3(view_ray.xy, 0.0);
		ray_origin += lateral;
		ray = -surface_camera_basis[2];
		offset = lateral + ray * view_depth;
	}
	float multiplier = 1.0;
	vec3 fog_color = surface_fog_color;
	if (aerial_gain > 0.0) {
		float relief = max(zs_summit.y - 0.15, 1.0);
		float a = 1.6 / relief;
		float c = (ray_origin.y - 0.15 - 0.85 * relief) * a;
		float p = c + (surface_orthographic ? ray.y * view_depth : offset.y) * a;
		float mean_density = abs(p - c) > 0.001 ? (exp(-c) - exp(-p)) / (p - c) : exp(-c);
		multiplier = mix(1.0, clamp(mean_density, 0.4, 2.2), aerial_gain);
		vec3 tint = mix(vec3(0.88, 0.87, 0.87), vec3(1.10, 1.12, 1.18), smoothstep(-0.3, 0.3, ray.y));
		fog_color *= mix(vec3(1.0), tint, aerial_gain);
		float sun = max(dot(ray, zs_cloud_direction), 0.0);
		fog_color = mix(fog_color, aerial_sun_color, (pow(sun, 4.0) * 0.7 + sun * 0.3) * aerial_gain);
	}
	float d = surface_density * view_depth * multiplier;
	vec3 result = mix(color, fog_color, 1.0 - exp(-d * d));
	if (surface_inversion_enabled) {
		float inversion = zs_inversion_surface_amount(zs_camera_position + offset);
		result = mix(result, zs_inversion_color, inversion);
	}
	if (overview_far.w > 0.0) {
		vec3 point = ray_origin + offset;
		float share = smoothstep(overview_far.z, overview_far.w, length(point.xz - overview_far.xy));
		if (share > 0.0) result = mix(result, mix(color, zs_glide_horizon(ray), zs_glide_fog_ring(ray_length, point.y)), share);
	}
	// Gliding, the plate's haze gives way to the sky's own colour with
	// distance (glide_haze.gdshaderinc), the aerial perspective that ties
	// near islands, far ones and the sky together.
	if (zs_glide_haze.x > 0.0) {
		vec3 point = ray_origin + offset;
		// A range's rock keeps the landform's gentler curve.
		float glide = zs_glide_fog_far(ray_length, point.y, zs_glide_peak(point));
		// The ring's rock keeps its skyline's curve.
		glide = mix(glide, min(glide, zs_glide_fog_ring(ray_length, point.y)), zs_glide_ring(point));
		glide = max(glide, zs_glide_emerge(point));
		result = mix(result, mix(color, zs_glide_horizon(ray), glide), zs_glide_haze.x);
	}
	return mix(color, result, depth_sample.g);
}
