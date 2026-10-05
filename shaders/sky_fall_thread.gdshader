shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never, world_vertex_coords;
// A floating island's fall carried down to the cloud sea (scripts/
// sky_fall_thread.gd): one mesh holding two kinds of piece.
// - The thread: a ribbon down the fall's line, turned to face the eye about
//   it (as shaders/sky_tepui_fall.gdshader), so it reads as a falling column
//   from any side. Near the top it is running white strands, thin and quick;
//   frayed (COLOR.r) it is a wider, softer veil of spray, its streaks
//   stretching longer and running slower the lower they are. Its opacity
//   down the fall is the script's (COLOR.a), so it never thins to nothing on
//   the way and only melts away into the bloom at the sea.
// - The bloom: billboard puffs at its foot, one steady glow and a few that
//   billow up out of it, swell and thin, each on its own beat (as
//   shaders/sky_tepui_mist.gdshader), faintly glowing with a cool light.
// Both lean downwind and sway on the breeze, the lower the more, so the
// foot and its bloom go together. Lit as the glide's clouds are, glowing
// round the sun when lit through; into the haze as the islets are.
// Thread vertex: the line's point; NORMAL its way down; UV (side -1 or 1,
// metres along it); UV2 (half width m, share of the drop); COLOR (fray, -,
// -, opacity). Puff vertex: its middle; NORMAL the way it drifts; UV the
// corner (-1 to 1); UV2 (-radius m, life s, 0 for the steady glow); COLOR
// (phase, seed, drift as a share of drift_max, brightness).
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/glide_haze.gdshaderinc"

uniform float seed = 0.0;
// Metres from the lip to the thread's foot, and how far it leans downwind
// at the foot on a full breeze (share of that).
uniform float drop = 100.0;
uniform float lean = 0.07;
// The flat way across the fall (world), for its sway.
uniform vec3 across_axis = vec3(1.0, 0.0, 0.0);
// The thread's travel at its foot, where the puffs sway with it.
uniform float foot_travel = 100.0;
uniform float drift_max = 24.0;
// The bloom's faint cool glow, over the clouds' own light.
uniform vec3 glow_tint : source_color = vec3(0.86, 0.95, 1.0);
uniform float soft_depth = 6.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying float puff;
varying vec2 corner;
varying float side;
varying float travel;
varying float share;
varying float half_width;
varying float fray;
varying float opacity;
varying float age;
varying float pseed;
varying vec3 shade;
varying float glow;

float thread_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float thread_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(thread_hash(i), thread_hash(i + vec2(1.0, 0.0)), f.x),
		mix(thread_hash(i + vec2(0.0, 1.0)), thread_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Where the breeze has blown the line `s` of the way down (at `along` m of
// travel): downwind, breathing with the air, and swaying across.
vec3 blown(float s, float along) {
	vec2 way = length(zs_wind_direction) > 1e-3 ? normalize(zs_wind_direction) : vec2(1.0, 0.0);
	float breeze = clamp(zs_breeze, 0.0, 1.5);
	float t = zs_motion_time;
	float s2 = s * s;
	float push = breeze * lean * drop * (1.0 + 0.25 * sin(t * 0.31 + seed));
	float sway = sin(t * 0.23 + along * 0.02 + seed) * 0.6 + sin(t * 0.57 + along * 0.045 + seed * 2.0) * 0.4;
	return vec3(way.x, 0.0, way.y) * push * s2 + across_axis * sway * s2 * (1.0 + 2.5 * breeze);
}

void vertex() {
	puff = UV2.x < 0.0 ? 1.0 : 0.0;
	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	vec3 centre;
	float away;
	if (puff > 0.5) {
		corner = UV;
		float radius = -UV2.x;
		float life = UV2.y;
		pseed = COLOR.g;
		centre = VERTEX + blown(1.0, foot_travel);
		float live = 1.0;
		if (life > 0.0) {
			age = fract(zs_motion_time / life + COLOR.r);
			float eased = 1.0 - (1.0 - age) * (1.0 - age);
			centre += normalize(NORMAL) * COLOR.b * drift_max * eased;
			radius *= mix(0.45, 1.45, eased);
			live = smoothstep(0.0, 0.22, age) * (1.0 - smoothstep(0.5, 1.0, age));
		} else {
			// The steady glow breathes slowly.
			age = 0.5;
			radius *= 1.0 + 0.06 * sin(zs_motion_time * 0.4 + seed);
			live = 0.75;
		}
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		vec3 up = INV_VIEW_MATRIX[1].xyz;
		VERTEX = centre + (right * UV.x + up * UV.y) * radius;
		away = distance(CAMERA_POSITION_WORLD, centre);
		opacity = live * COLOR.a * smoothstep(radius * 0.3, radius * 1.3, away);
	} else {
		side = UV.x;
		travel = UV.y;
		half_width = UV2.x;
		share = UV2.y;
		fray = COLOR.r;
		vec3 down = normalize(NORMAL);
		centre = VERTEX + blown(share, travel);
		// The veil breathes in width.
		float breathe = 1.0 + 0.08 * fray * sin(zs_motion_time * 0.7 + travel * 0.05 + seed);
		vec3 to_eye = CAMERA_POSITION_WORLD - centre;
		// Turned to face the eye about its line; looking down along it, it
		// eases back to lie square across the fall.
		vec3 facing = cross(down, normalize(to_eye));
		float square = length(facing);
		facing = square > 1e-4 ? facing / square : across_axis;
		if (dot(facing, across_axis) < 0.0) facing = -facing;
		vec3 right = normalize(mix(across_axis, facing, smoothstep(0.25, 0.7, square)));
		VERTEX = centre + right * side * half_width * breathe;
		away = length(to_eye);
		// Thinned away close up, so flying through the spray is soft.
		opacity = COLOR.a * smoothstep(1.5, 9.0, away);
	}
	// Into the glide's haze as the islets are, thicker low down.
	opacity *= 1.0 - zs_glide_fog(away, centre.y) * zs_glide_haze.x;
	vec3 view = normalize(CAMERA_POSITION_WORLD - centre);
	float sunward = clamp(dot(view, sun) * 0.5 + 0.5, 0.0, 1.0);
	shade = zs_cloud_sky * vec3(0.93, 0.97, 1.04) + zs_cloud_sun * (0.35 + 0.65 * sunward) * 0.9;
	// Lit through from behind: the spray glows round the sun.
	glow = pow(clamp(dot(-view, sun), 0.0, 1.0), 5.0) * smoothstep(-0.05, 0.15, sun.y + 0.1);
}

void fragment() {
	float t = zs_motion_time;
	float a;
	vec3 colour;
	if (puff > 0.5) {
		float r = length(corner);
		float rag = thread_noise(corner * 2.0 + vec2(pseed * 17.0, age * 3.0)) * 0.6 + thread_noise(corner * 4.7 + pseed * 9.0) * 0.4;
		float edge = 1.0 - smoothstep(0.3, 1.0, r + (rag - 0.5) * 0.5);
		a = edge * (0.5 + 0.5 * (1.0 - r * r)) * 0.36;
		// A soft cool glow in the middle, the mist lit from within.
		colour = shade * glow_tint * (1.0 + 0.18 * (1.0 - r)) + zs_cloud_sun * glow * 0.5;
	} else {
		float x = side;
		float across = x * half_width;
		// Streaks: quick and tight in the strands, stretching longer and
		// running slower as the spray falls and slows.
		float run = travel - t * mix(9.0, 3.2, fray);
		float fine = thread_noise(vec2(across / mix(0.22, 1.1, fray) + seed, run / mix(4.0, 30.0, share)));
		float broad = thread_noise(vec2(across / mix(0.7, 3.0, fray) + seed * 3.1, (travel - t * mix(7.0, 2.4, fray)) / mix(12.0, 48.0, share)));
		float billow = thread_noise(vec2(across / 4.0 + seed * 5.0, (travel - t * 1.8) / 16.0)) * 0.6 + thread_noise(vec2(across / 1.7, (travel - t * 2.3) / 7.0)) * 0.4;
		// Ragged edges, softer as it frays.
		float rag = (thread_noise(vec2(across / 2.5 + seed, run / 9.0)) - 0.5) * mix(0.25, 0.7, fray);
		float edge = 1.0 - smoothstep(mix(0.45, 0.0, fray), 1.0, abs(x) + rag);
		float strands = smoothstep(0.3, 0.7, fine * 0.6 + broad * 0.4) * 1.1;
		float spray = (0.55 + 0.45 * billow) * (0.75 + 0.35 * broad);
		float body = mix(strands, spray, fray) * (1.0 - 0.35 * x * x * fray);
		a = edge * body;
		// White water at the top, the veil a touch cooler and softer.
		colour = shade * mix(vec3(0.95 + 0.1 * fine), glow_tint * (1.0 + 0.06 * billow), fray);
		colour += zs_cloud_sun * glow * (0.3 + 0.3 * fray);
	}
	a *= opacity;
	// Soft where it passes behind rock or into anything solid.
	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float gap = -VERTEX.z + behind.z / behind.w;
	a *= clamp(-gap / soft_depth, 0.0, 1.0);
	ALBEDO = colour;
	ALPHA = clamp(a, 0.0, 1.0);
}
