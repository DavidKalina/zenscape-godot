shader_type spatial;
// A far lightning bolt in a storm (scripts/endless/weather_lightning.gd; lifted
// from the storm front's storm_bolt.gdshader): each channel a ribbon turned to
// the eye, built in world space. Per vertex: NORMAL the channel's way, UV.x the
// side (-1, 1), UV.y how far along its channel (0 at its root in the cloud, 1
// at its tip), UV2.x its half width (m), UV2.y its brightness, COLOR.r 1 on the
// main channel (lit by every pulse) and 0 on a branch (lit by the first only).
// A ribbon is never thinner than `min_px` pixels; a thinner channel dims by the
// share it fills instead, so a far bolt stays a thin hair. Its root comes out
// of the cloud base, and its lower part greys into the rain's air (`veil`).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, world_vertex_coords;

uniform vec3 tint = vec3(0.86, 0.9, 1.0);
uniform vec3 halo_tint = vec3(0.45, 0.52, 0.9);
// The flash now, on the main channel and on the branches.
uniform float flash = 0.0;
uniform float branch_flash = 0.0;
// The core's peak (HDR), the halo's, and how many core widths the halo spreads.
uniform float hot = 5.0;
uniform float halo = 0.4;
uniform float spread = 8.0;
// Radians a pixel spans, and the least core width in pixels.
uniform float pixel = 0.001;
// (2: the 3D is drawn at 0.75 of the window and thinner aliased away.)
uniform float min_px = 2.0;
// The air between: far off a bolt dims to this share (by `far` m), and the
// rain (0 none, 1 the heaviest) dims it more and greys its foot.
uniform float far_keep = 0.35;
uniform float far = 8000.0;
uniform float veil = 0.0;

varying float across;
varying float lit;
varying float along;
varying float main_k;

void vertex() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 to = VERTEX - eye;
	float d = max(length(to), 1.0);
	vec3 side = cross(NORMAL, to / d);
	float sl = length(side);
	side = sl > 1e-4 ? side / sl : normalize(cross(NORMAL, vec3(0.0, 1.0, 0.0)) + vec3(1e-4));
	float floor_w = d * pixel * min_px * 0.5;
	float core = max(UV2.x, floor_w);
	VERTEX += side * UV.x * core * spread;
	across = UV.x;
	along = UV.y;
	main_k = COLOR.r;
	float on = mix(branch_flash, flash, COLOR.r);
	float share = clamp(UV2.x / floor_w, 0.45, 1.0);
	float air = mix(1.0, far_keep, smoothstep(500.0, far, d));
	air *= mix(1.0, 0.5, veil);
	lit = UV2.y * on * share * air;
}

void fragment() {
	float x = abs(across) * spread;
	float core = exp(-x * x * 1.6);
	float glow = exp(-x * 0.9) * halo + exp(-across * across * 4.0) * halo * 0.25;
	// A branch fades to its tip; the main channel comes out of the cloud base
	// and fades toward its foot into the rain's grey.
	float tip = mix(1.0, 1.0 - along * along * 0.85, 1.0 - main_k);
	tip *= smoothstep(0.0, 0.1, along);
	tip *= mix(1.0, mix(1.0, 0.35, smoothstep(0.45, 1.0, along)), veil);
	ALBEDO = (tint * core * hot + halo_tint * glow) * lit * tip;
	ALPHA = 1.0;
}
