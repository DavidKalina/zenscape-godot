shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never, world_vertex_coords;
// A tepui's giant waterfall (scripts/sky_tepuis.gd): a ribbon down the
// fall's course (scripts/sky_tepui.gd `fall_arrays`), turned about its line
// to face the eye, so it reads as a falling column from every side and from
// behind the curtain. The core (`layer` 0): glassy dark water over the lip,
// whitening within metres into running streaks; lower down it breaks into
// clumps with ragged, thinning edges and fades into the mist at the sea. The
// veil (`layer` 1): a wider, softer sheet of spray round it, thickening as
// the fall goes down. Lit as the glide's clouds are (the sky's colour all
// round, the sun's on the side facing it), and glowing when the sun is
// behind it; hazed as the rock it falls past.
// Vertex: the line's point; NORMAL its way down; UV (side -1 or 1, metres
// along it); UV2 (half width m, share of the drop).
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/glide_haze.gdshaderinc"

uniform float layer = 0.0;
uniform float strength = 1.0;
// Metres a second the streaks run down.
uniform float speed = 16.0;
uniform float seed = 0.0;
// The horizontal way across the fall (world), for its slow sway.
uniform vec3 across_axis = vec3(1.0, 0.0, 0.0);
uniform vec3 water_tint : source_color = vec3(0.18, 0.3, 0.32);
uniform float soft_depth = 6.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

varying float side;
varying float travel;
varying float share;
varying float half_width;
varying vec3 world_at;
varying vec3 shade;
varying float glow;
varying float seen;

float fall_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float fall_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(fall_hash(i), fall_hash(i + vec2(1.0, 0.0)), f.x),
		mix(fall_hash(i + vec2(0.0, 1.0)), fall_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 centre = VERTEX;
	vec3 down = normalize(NORMAL);
	side = UV.x;
	travel = UV.y;
	half_width = UV2.x;
	share = UV2.y;
	// The lower fall sways slowly on the wind, and breathes in width.
	float sway = sin(zs_motion_time * 0.21 + travel * 0.011 + seed) * 0.6 + sin(zs_motion_time * 0.53 + travel * 0.03 + seed * 2.0) * 0.4;
	centre += across_axis * sway * share * share * 7.0;
	float breathe = 1.0 + 0.06 * sin(zs_motion_time * 0.7 + travel * 0.05 + seed);
	vec3 to_eye = CAMERA_POSITION_WORLD - centre;
	// Turned to face the eye about its line; looking along the line (down
	// the fall from the lip) it eases back to lie square to the wall.
	vec3 facing = cross(down, normalize(to_eye));
	float square = length(facing);
	facing = square > 1e-4 ? facing / square : across_axis;
	if (dot(facing, across_axis) < 0.0) facing = -facing;
	vec3 right = normalize(mix(across_axis, facing, smoothstep(0.25, 0.7, square)));
	VERTEX = centre + right * side * half_width * breathe;
	world_at = VERTEX;
	float away = length(to_eye);
	// Into the glide's haze as the tepui's rock is (a landform's curve).
	seen = 1.0 - zs_glide_fog_far(away, centre.y, 1.0) * zs_glide_haze.x;
	// Thinned away close up, so flying through spray is soft.
	seen *= smoothstep(1.5, 10.0, away);
	vec3 view = normalize(to_eye);
	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	float sunward = clamp(dot(view, sun) * 0.5 + 0.5, 0.0, 1.0);
	shade = zs_cloud_sky * vec3(0.93, 0.96, 1.03) + zs_cloud_sun * (0.3 + 0.7 * sunward) * 0.9;
	// Lit through from behind: the spray glows round the sun.
	glow = pow(clamp(dot(-view, sun), 0.0, 1.0), 5.0) * smoothstep(-0.05, 0.15, sun.y + 0.1);
}

void fragment() {
	float t = zs_motion_time;
	float x = side;
	float across = x * half_width;
	float veil = step(0.5, layer);
	float run = travel - t * speed * mix(1.0, 0.55, veil);
	// Streaks: long, thin, running down.
	float fine = fall_noise(vec2(across / 0.8 + seed, run / 9.0));
	float broad = fall_noise(vec2(across / 2.2 + seed * 3.1, run / 26.0));
	float streak = fine * 0.45 + broad * 0.55;
	// Clumps lower down: lumps of water and their trailing spray.
	float clump = fall_noise(vec2(across / 5.0 + seed * 7.0, (travel - t * speed * 1.12) / 12.0));
	float billow = fall_noise(vec2(across / 7.0 + seed * 5.0, (travel - t * speed * 0.4) / 18.0)) * 0.6 + fall_noise(vec2(across / 3.0, (travel - t * speed * 0.5) / 7.0)) * 0.4;
	// Ragged edges, more ragged as it falls.
	float rag = (fall_noise(vec2(across / 3.5 + seed, run / 11.0)) - 0.5) * mix(0.2, 0.8, share);
	float a;
	vec3 colour;
	if (veil < 0.5) {
		float edge = 1.0 - smoothstep(mix(0.55, 0.2, share), 1.0, abs(x) + rag);
		// Lower down it breaks into clumps, gaps of air between.
		float body = mix(0.98, smoothstep(0.28, 0.72, clump) * 1.1, smoothstep(0.12, 0.75, share));
		a = edge * body * (0.6 + 0.55 * streak);
		a *= 1.0 - smoothstep(0.78, 1.0, share);
		// Glassy over the lip: the stream's dark water and a sheen of sky,
		// whitening within metres.
		float glass = 1.0 - smoothstep(0.0, 9.0, travel);
		vec3 white = shade * (0.92 + 0.16 * streak);
		vec3 dark = water_tint * (zs_cloud_sky * 0.55 + zs_cloud_sun * 0.25) + shade * 0.35 * smoothstep(0.55, 0.85, fine);
		colour = mix(white, dark, glass * 0.85);
		a = mix(a, max(a, 0.92 * (1.0 - smoothstep(0.75, 1.0, abs(x)))), glass);
	} else {
		float edge = 1.0 - smoothstep(0.15, 1.0, abs(x) + rag * 0.8);
		a = edge * smoothstep(0.2, 0.85, billow) * smoothstep(0.1, 0.6, share) * mix(0.2, 0.36, share);
		a *= 1.0 - smoothstep(0.9, 1.0, share);
		colour = shade * (0.96 + 0.08 * billow);
	}
	colour += zs_cloud_sun * glow * (0.35 + 0.35 * veil);
	a *= strength * seen;
	// Soft where it meets the cloud sea or rock behind.
	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float gap = -VERTEX.z + behind.z / behind.w;
	a *= clamp(-gap / soft_depth, 0.0, 1.0);
	ALBEDO = colour;
	ALPHA = clamp(a, 0.0, 1.0);
}
