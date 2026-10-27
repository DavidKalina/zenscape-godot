shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never, world_vertex_coords;
// The rain round the eye (scripts/endless/storm_rain.gd): one mesh of thin
// quads, each a drop. A drop's place is fixed in the world, falling and
// blown with the wind on the clock, wrapped into a box round the eye, so the
// plane flies through it; drawn as a streak from where it is back along its
// motion relative to the eye over one exposure, so at speed the streaks
// stretch toward the eye's way. Each drop shows where its seed is under
// the storm's rain there (zs_storm_rain), so the rain thins to nothing at
// the core's edges and the line's ends. No storm: the node is never built.

#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/storm_front.gdshaderinc"

// The boxes round the eye (m, full extents): the first `near_count` drops
// in the small one, dense close by, the rest in the big one.
uniform vec3 box = vec3(64.0, 40.0, 64.0);
uniform vec3 near_box = vec3(22.0, 18.0, 22.0);
uniform float near_count = 7000.0;
uniform float box_drop = -7.0;
// The eye's velocity (m/s), set each frame.
uniform vec3 eye_velocity = vec3(0.0);
// The drops' fall (m/s, least and most) and the wind's push (m/s, along
// zs_wind_direction).
uniform vec2 fall = vec2(8.0, 11.0);
uniform float wind_push = 6.0;
// One exposure (s): a streak's length is its speed past the eye times it,
// up to `longest` m.
uniform float exposure = 0.022;
uniform float eye_share = 0.28;
uniform float longest = 1.6;
// The streak's width (m) and opacity, and how near the eye a drop fades.
uniform float width = 0.018;
uniform float opacity = 0.7;
uniform vec2 near_fade = vec2(0.6, 2.5);
// The streak's own colour, lit by the sky.
uniform vec3 tint = vec3(0.78, 0.82, 0.86);
uniform float brightness = 1.0;
// The clock the drops fall on (s), set each frame.
uniform float clock = 0.0;

varying float v_alpha;
varying vec3 v_light;

vec4 rain_hash4(float n) {
	vec4 p4 = fract(vec4(n) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + 33.33);
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

void vertex() {
	// UV2.x: the drop's index; UV: the corner (x across, y tail 0 to head 1).
	vec4 r = rain_hash4(UV2.x + 0.5);
	vec4 r2 = rain_hash4(UV2.x * 1.618 + 17.0);
	vec3 cam = CAMERA_POSITION_WORLD;
	vec2 wind = zs_wind_direction * wind_push * (0.8 + 0.4 * r2.x);
	vec3 vel = vec3(wind.x, -mix(fall.x, fall.y, r.w), wind.y);
	vec3 b = UV2.x < near_count ? near_box : box;
	// The big box sits a little low: the chase eye looks down at the plane,
	// and drops high against the sky read as stars streaking past.
	vec3 centre = cam + vec3(0.0, UV2.x < near_count ? 0.0 : box_drop, 0.0);
	vec3 p = r.xyz * b + vel * clock;
	p = centre + mod(p - centre + b * 0.5, b) - b * 0.5;
	// The storm's rain where this drop falls.
	float rain = zs_storm_rain(p.xz);
	float shown = step(r2.y, rain);
	// The eye's own motion shared in part only: all of it draws every
	// streak from the point ahead like stars in a warp.
	vec3 rel = vel - eye_velocity * eye_share;
	vec3 trail = rel * exposure;
	float tl = length(trail);
	if (tl > longest) trail *= longest / tl;
	// A long streak is a drop smeared thin: fainter.
	float smear = clamp(0.6 / max(min(tl, longest), 0.01), 0.35, 1.0);
	vec3 head = p;
	vec3 tail = p - trail;
	vec3 mid = mix(tail, head, UV.y);
	vec3 to_eye = cam - mid;
	float dist = length(to_eye);
	vec3 along = normalize(head - tail + vec3(0.0, -1e-4, 0.0));
	vec3 side = normalize(cross(along, to_eye));
	// At least about a pixel wide, paid for in opacity.
	float px = 2.0 * dist / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float w = max(width, px * 0.9);
	vec3 half_box = b * 0.5;
	vec3 o = abs(p - centre) / half_box;
	float edge = 1.0 - smoothstep(0.65, 1.0, max(o.x, max(o.y, o.z)));
	float near = smoothstep(near_fade.x, near_fade.y, dist);
	v_alpha = opacity * smear * (UV2.x < near_count ? 1.0 : 0.4) * shown * edge * near * (width / w) * (0.6 + 0.4 * r2.z);
	if (v_alpha < 0.002) {
		VERTEX = cam - vec3(0.0, 1000.0, 0.0);
	} else {
		VERTEX = mid + side * (UV.x - 0.5) * w;
	}
	vec3 sky = zs_hemi_sky * zs_hemi_energy / PI;
	vec3 sun = zs_key_irradiance / PI * zs_daylight;
	// Lit by the light's brightness alone, not its colour: under the storm
	// the sky's hemisphere and a low sun went warm, and the streaks read
	// orange-brown; rain is cold grey-white.
	float lum = dot(sky * 1.4 + sun * 0.12, vec3(0.2126, 0.7152, 0.0722));
	v_light = tint * (lum + 0.004) * brightness;
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	// Brightest at the head, thinning down the tail.
	float run = smoothstep(0.0, 0.5, UV.y) * (0.55 + 0.45 * UV.y);
	ALBEDO = v_light;
	ALPHA = clamp(v_alpha * across * run, 0.0, 1.0);
}
