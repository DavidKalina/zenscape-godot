shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never, world_vertex_coords, fog_disabled;
// The rain curtains (scripts/endless/storm_rain.gd): grey veils hanging from
// the storm's cloud base to the ground under its core, seen from afar. One
// mesh of tall cards, each placed on the storm's own frame (UV2: along the
// line from its middle, d behind the leading edge), so they ride the front
// with zs_storm_line; each turned about the vertical to face the eye and
// sheared downwind toward its foot. Ragged: broad shafts drifting across,
// fine streaks falling, a torn top, all shown only where the storm rains
// (zs_storm_rain at the pixel), faded near the eye (the streaks round the
// eye take over). Not fogged by the scene's haze, which would grey them out
// past a few km: they thin by their own, gentler, toward the fog's end.

#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/storm_front.gdshaderinc"

// The sea's level (world y), the cards' foot (m under it, so under any
// ground the curtain falls behind) and the cloud base they hang from (m
// over it, before each card's jitter; the storm's pushed cumulus have
// their bases 60-110 m over the sea, lifted over the land: the card's top
// frays out in them, shaders/storm_cloud.glslinc).
uniform float sea_y = -40.0;
uniform float foot = 15.0;
uniform float base = 235.0;
// Downwind shear at the foot (m per m of drop).
uniform float shear = 0.25;
// Faded in from near.x to near.y m from the eye.
uniform vec2 near = vec2(180.0, 650.0);
// The scene's depth fog's end (m): the curtains thin from `far_from` of it.
uniform float fog_end = 7600.0;
uniform float far_from = 0.8;
uniform float opacity = 1.0;
uniform vec3 tint = vec3(0.74, 0.77, 0.8);
// The light left on a curtain seen from out in the sun.
uniform float shade = 0.7;
// How much rain is left between the shafts (0: clear gaps).
uniform float gap_floor = 0.08;
uniform float brightness = 1.0;
// The rain's fall in the streaks (m/s) and the shafts' drift (m/s).
uniform float fall = 22.0;
uniform float drift = 6.0;
uniform float clock = 0.0;

varying vec3 v_world;
varying float v_u;
varying float v_width;
varying float v_seed;
varying float v_top;
varying float v_dist;
varying vec3 v_light;

float cu_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float cu_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(cu_hash(i), cu_hash(i + vec2(1.0, 0.0)), u.x),
		mix(cu_hash(i + vec2(0.0, 1.0)), cu_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	// UV2: (along, d) on the storm's frame; COLOR: r the width (/2000 m),
	// g the seed, b the top's jitter (x 100 m, about 0.5).
	vec2 heading = zs_storm_line.zw;
	vec2 side = vec2(-heading.y, heading.x);
	vec2 c = zs_storm_line.xy + side * UV2.x + heading * UV2.y;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec2 to = cam.xz - c;
	float flat_dist = max(length(to), 1.0);
	vec2 right = vec2(-to.y, to.x) / flat_dist;
	float width = COLOR.r * 2000.0;
	float top = sea_y + base + (COLOR.b - 0.5) * 50.0;
	float y = mix(sea_y - foot, top, UV.y);
	vec2 xz = c + right * (UV.x - 0.5) * width + zs_wind_direction * (top - y) * shear;
	VERTEX = vec3(xz.x, y, xz.y);
	v_world = VERTEX;
	v_u = UV.x;
	v_width = width;
	v_seed = COLOR.g;
	v_top = top;
	v_dist = flat_dist;
	vec3 sky = zs_hemi_sky * zs_hemi_energy / PI;
	vec3 sun = zs_key_irradiance / PI * zs_daylight;
	// Grey, not the sky's blue, and in the storm's own shade even while the
	// eye is still in the sun (the light is already dimmed under it).
	vec3 lit = sky * 1.25 + sun * 0.08 + vec3(0.003);
	float luma = dot(lit, vec3(0.2126, 0.7152, 0.0722));
	v_light = tint * mix(vec3(luma), lit, 0.25) * mix(shade, 1.0, zs_storm_here) * brightness;
}

void fragment() {
	float rain = zs_storm_rain(v_world.xz);
	if (rain <= 0.001) discard;
	float d_eye = length(v_world.xz - CAMERA_POSITION_WORLD.xz);
	float shown = smoothstep(near.x, near.y, d_eye);
	shown *= 1.0 - smoothstep(fog_end * far_from, fog_end * 1.2, d_eye);
	if (shown <= 0.001) discard;
	float um = v_u * v_width;
	float s = v_seed * 97.0;
	// Broad shafts drifting across the card, their edges frayed.
	float shafts = cu_noise(vec2(um / 380.0 + s + clock * drift / 380.0, s * 0.3)) * 0.6
		+ cu_noise(vec2(um / 140.0 - s - clock * drift / 160.0, s * 0.7 + v_world.y / 500.0)) * 0.4;
	shafts = mix(gap_floor, 1.0, smoothstep(0.3, 0.72, shafts));
	// Falls: noise stretched tall and scrolled down, a coarse layer that
	// reads from kilometres (the curtain's hatching) and a fine one near,
	// each gone where it would be finer than the pixel.
	float upx = fwidth(um);
	float coarse = cu_noise(vec2(um / 38.0 + s * 3.0, (v_world.y + clock * fall) / 320.0));
	float fine = cu_noise(vec2(um / 11.0 + s, (v_world.y + clock * fall * 1.2) / 120.0));
	float streak = mix(1.0, mix(0.45, 1.2, coarse), 1.0 - smoothstep(6.0, 16.0, upx))
		* mix(1.0, mix(0.7, 1.12, fine), 1.0 - smoothstep(2.0, 5.0, upx));
	// The top lost in the cloud base, frayed; the card's sides soft.
	float torn = (cu_noise(vec2(um / 90.0 + s, s)) - 0.5) * 60.0;
	float h = (v_world.y - sea_y) / max(v_top - sea_y, 1.0);
	float top = 1.0 - smoothstep(0.45 + torn / 250.0, 1.0 + torn / 250.0, h);
	float sides = smoothstep(0.0, 0.35, v_u) * smoothstep(1.0, 0.65, v_u);
	// Thickest low down, where the curtain meets the ground.
	float low = mix(1.0, 0.7, smoothstep(0.0, 1.0, h));
	ALBEDO = v_light;
	ALPHA = clamp(opacity * rain * shown * shafts * streak * top * sides * low, 0.0, 1.0);
}
