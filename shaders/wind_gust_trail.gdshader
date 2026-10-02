shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never, world_vertex_coords;
// A gust's streaks of moving air (scripts/wind_gust.gd, docs/scenic/wind-gust.md
// "How it looks"). Each strand is laid along the whole lane (or curving out
// round a burst, or along a Feather's path) when the gust goes; only one
// streak of it shows, riding behind the air's head, so the streaks travel with
// it. A streak is a hair of light, not a painted band: a few pixels wide
// whatever the distance, tapered to nothing at both ends, brightest just
// behind its front and fading out down its tail, soft across, translucent,
// lit by the sky and the sun (brighter looking toward the sun, as air full of
// dust is) and fogged with the scene. It curls slowly round its line where
// the air is.
// Attributes: UV.x metres along the strand, UV.y 0..1 across it; CUSTOM0.x
// the metres the streak lags the head, .y its phase (0..1), .z its length
// (m); NORMAL the strand's way (world, unit).
#include "res://shaders/reference_globals.gdshaderinc"
uniform float head = -1000.0;
// Kept for the callers; a streak's own length (CUSTOM0.z) sets what shows.
uniform float trail_length = 8.0;
uniform float opacity = 0.0;
uniform float clock = 0.0;
// The streak's true width (m) at its fullest. Drawn at least MIN_PIXELS wide,
// with its opacity thinned to match, so far streaks are faint threads rather
// than fat lines.
uniform float width = 0.035;
// How fast (m/s) the light inside a streak runs along it.
uniform float flow = 6.0;
uniform vec4 tint : source_color = vec4(0.93, 0.96, 1.0, 1.0);
// The most a streak ever covers what is behind it.
const float PEAK = 0.75;
const float MIN_PIXELS = 2.5;
// Nor over MAX_PIXELS wide, so a streak passing by the lens stays a hair.
const float MAX_PIXELS = 5.0;
// The curl: radius (m) round the strand's line and its turn along it (rad/m)
// and in time (rad/s).
const float CURL = 0.22;
const float CURL_TWIST = 0.55;
const float CURL_TURN = 1.6;
varying float along_streak;
varying float coverage;
varying float facing;
varying float toward_sun;
varying float strand_phase;

void vertex() {
	float length_m = max(CUSTOM0.z, 0.5);
	float behind = head - CUSTOM0.x - UV.x;
	// 0 at the streak's front, 1 at its tail; outside 0..1 it is not drawn.
	along_streak = behind / length_m;
	float phase = CUSTOM0.y * TAU;
	strand_phase = phase;
	vec3 way = normalize(NORMAL);
	vec3 side = normalize(cross(way, vec3(0.0, 1.0, 0.0)) + vec3(1e-4, 0.0, 0.0));
	vec3 lift = cross(side, way);
	// The air's own motion: a slow curl round the line, larger toward the
	// tail, where the air has had time to turn.
	float here = smoothstep(-0.3, 0.2, along_streak) * (1.0 - smoothstep(1.0, 1.6, along_streak));
	float turn = UV.x * CURL_TWIST - clock * CURL_TURN + phase;
	float radius = CURL * (0.35 + 0.65 * clamp(along_streak, 0.0, 1.0)) * here;
	vec3 centre = VERTEX + (side * cos(turn) + lift * sin(turn)) * radius;
	// Tapered at both ends: a needle at the front, a long thinning tail.
	float s = clamp(along_streak, 0.0, 1.0);
	float taper = smoothstep(0.0, 0.18, s) * (1.0 - smoothstep(0.45, 1.0, s));
	taper = sqrt(taper);
	// Screen-facing across the strand's way, at least MIN_PIXELS wide.
	vec3 to_camera = CAMERA_POSITION_WORLD - centre;
	float distance = length(to_camera);
	to_camera /= max(distance, 0.001);
	vec3 across = cross(way, to_camera);
	facing = length(across);
	across = facing > 0.001 ? across / facing : side;
	float pixel = 2.0 * distance / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float true_width = min(width, pixel * MAX_PIXELS) * taper;
	float drawn = max(true_width, pixel * MIN_PIXELS * step(0.001, taper));
	coverage = drawn > 0.0 ? clamp(true_width / max(drawn, 0.0001), 0.0, 1.0) : 0.0;
	VERTEX = centre + across * (UV.y - 0.5) * drawn;
	toward_sun = max(dot(-to_camera, normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0))), 0.0);
}

void fragment() {
	if (along_streak < 0.0 || along_streak > 1.0) discard;
	float s = along_streak;
	float phase = strand_phase;
	// Brightest just behind the front, fading down the tail.
	float body = smoothstep(0.0, 0.08, s) * (1.0 - s);
	// Light running along it, slower than a dash and never off.
	float run = 0.78 + 0.22 * sin(UV.x * 1.1 - clock * flow * 0.9 + phase);
	// Soft across: a hair, with no edge.
	float v = (UV.y - 0.5) * 2.0;
	float soft = exp(-v * v * 3.2) * (1.0 - smoothstep(0.75, 1.0, abs(v)));
	// Seen end-on a strand would pile up into a blob: it fades instead.
	float side_on = smoothstep(0.15, 0.55, facing);
	vec3 sun = zs_key_irradiance / PI * zs_celestial_clear * zs_daylight;
	vec3 sky = zs_hemi_sky * zs_hemi_energy / PI;
	// Air light: mostly sky, the sun's share rising toward it (forward
	// scatter), and a little of its own so it never goes black at night.
	float scatter = pow(toward_sun, 6.0);
	vec3 light = sky * 1.1 + sun * (0.35 + 0.9 * scatter) + vec3(0.015 + 0.025 * zs_night);
	ALBEDO = tint.rgb * light;
	ALPHA = clamp(PEAK * opacity * body * run * soft * side_on * mix(0.8, 1.0, coverage) * (0.8 + 0.6 * scatter), 0.0, 1.0);
}
