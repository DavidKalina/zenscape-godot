shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never, world_vertex_coords;
// The rain round the eye (scripts/endless/weather_rain.gd; lifted from the
// old storm's storm_rain.gdshader): one mesh of thin quads, each a drop. A
// drop's place is fixed in the world, falling and blown with the wind on the
// clock, wrapped into a box round the eye, so the plane flies through it;
// drawn as a streak back along its motion relative to the eye over one
// exposure. Each drop shows where its seed is under the rain where it falls
// (zs_rain_at), so a drizzle is a few streaks and a cell's heart many, with
// no step between. Off (no weather, or no rain near): the node is hidden.

#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/weather.gdshaderinc"

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
uniform float wind_push = 5.0;
// One exposure (s): a streak's length is its speed past the eye times it,
// up to `longest` m.
uniform float exposure = 0.022;
uniform float eye_share = 0.17;
uniform float longest = 1.6;
// The most a streak leans from straight down (radians), by the wind and the
// eye's speed together, looking level; gone looking up (see vertex()).
uniform float slant = 0.3;
uniform vec2 slant_up = vec2(0.05, 0.5);
// The streak's width (m) and opacity, and how near the eye a drop fades.
uniform float width = 0.016;
uniform float opacity = 0.75;
uniform vec2 near_fade = vec2(0.6, 2.5);
// The streak's own colour, lit by the sky's brightness.
uniform vec3 tint = vec3(0.78, 0.82, 0.86);
uniform float brightness = 1.6;
// How many drops show at a rain of 1 (a share; the rest stay folded away),
// so even the heaviest rain is streaks, never a sheet.
uniform float most = 0.8;
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
	bool near_one = UV2.x < near_count;
	vec3 b = near_one ? near_box : box;
	vec3 centre = cam + vec3(0.0, near_one ? 0.0 : box_drop, 0.0);
	// The rain where the box stands: one read for the drop's show (the
	// field changes over kilometres, the box is 64 m).
	float rain = zs_rain_at(cam.xz);
	float shown = step(r2.y, rain * most);
	if (shown <= 0.0) {
		VERTEX = cam - vec3(0.0, 1000.0, 0.0);
		v_alpha = 0.0;
		v_light = vec3(0.0);
	} else {
		vec2 wind = zs_wind_direction * wind_push * (0.8 + 0.4 * r2.x) * zs_weather_sky.y;
		vec3 vel = vec3(wind.x, -mix(fall.x, fall.y, r.w), wind.y);
		vec3 p = r.xyz * b + vel * clock;
		p = centre + mod(p - centre + b * 0.5, b) - b * 0.5;
		// The eye's own motion shared in part only: all of it draws every
		// streak from the point ahead like stars in a warp.
		vec3 rel = vel - eye_velocity * eye_share;
		// Every streak in one world direction draws as lines meeting at that
		// direction's point in the sky (its vanishing point). Tipped far from
		// the vertical by the eye's speed, that point climbs into the frame
		// ahead and the streaks high against the sky radiate from it like
		// stars. So the streak's direction is held within `slant` of straight
		// down (the point stays above the frame looking level), always
		// falling (a dive never lays it flat), and only its length takes the
		// full speed past the eye. Looking up, the frame's top climbs to that
		// point, and the lines far from it (a wide lens) lie nearly flat: the
		// lean gives way as the view tips up (`slant_up`: the view's rise, the
		// sine of its pitch, over which it goes), so there the rain falls from
		// straight overhead.
		float tl = min(length(rel) * exposure, longest);
		float down = min(rel.y, -fall.x * 0.5);
		vec2 lean = rel.xz;
		float pitch = -INV_VIEW_MATRIX[2].y;
		float most_lean = -down * tan(slant * (1.0 - smoothstep(slant_up.x, slant_up.y, pitch)));
		float ll = length(lean);
		if (ll > most_lean) lean *= most_lean / ll;
		vec3 trail = normalize(vec3(lean.x, down, lean.y)) * tl;
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
		vec3 o = abs(p - centre) / (b * 0.5);
		float edge = 1.0 - smoothstep(0.65, 1.0, max(o.x, max(o.y, o.z)));
		float near = smoothstep(near_fade.x, near_fade.y, dist);
		v_alpha = opacity * smear * (near_one ? 1.0 : 0.4) * edge * near * (width / w) * (0.6 + 0.4 * r2.z);
		VERTEX = mid + side * (UV.x - 0.5) * w;
		vec3 sky = zs_hemi_sky * zs_hemi_energy / PI;
		vec3 sun = zs_key_irradiance / PI * zs_daylight;
		// Lit by the light's brightness alone: rain is cold grey-white,
		// never the warm tint a low sun gives the hemisphere.
		float lum = dot(sky * 1.4 + sun * 0.12, vec3(0.2126, 0.7152, 0.0722));
		v_light = tint * (lum + 0.004) * brightness;
	}
}

void fragment() {
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	// Brightest at the head, thinning down the tail.
	float run = smoothstep(0.0, 0.5, UV.y) * (0.55 + 0.45 * UV.y);
	ALBEDO = v_light;
	ALPHA = clamp(v_alpha * across * run, 0.0, 1.0);
}
