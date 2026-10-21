shader_type spatial;
// A lightning bolt seen from the plane (scripts/plane_lightning.gd): each
// channel a ribbon turned to the eye, built in world space. Per vertex:
// NORMAL the channel's way, UV.x the side (-1, 1), UV.y how far along its
// channel (0 at its root, 1 at its tip), UV2.x its half width (m), UV2.y its
// brightness, COLOR.r 1 on the main channel (lit by every stroke) and 0 on
// a branch (lit by the first stroke only), COLOR.g 1 where its far end
// fades. A ribbon is never thinner than `min_px` pixels; a thinner channel
// dims by the share it fills instead, so a far bolt stays a crisp hair.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, world_vertex_coords;

uniform vec3 tint = vec3(0.8, 0.86, 1.0);
uniform vec3 halo_tint = vec3(0.45, 0.55, 1.0);
// The flash now, on the main channel and on the branches.
uniform float flash = 0.0;
uniform float branch_flash = 0.0;
// The core's peak (HDR, so it blooms), the halo's, and how many core
// widths the halo spreads.
uniform float hot = 9.0;
uniform float halo = 0.8;
uniform float spread = 9.0;
// Radians a pixel spans, and the least core width in pixels.
uniform float pixel = 0.001;
uniform float min_px = 1.3;
// The air between: far off a bolt dims to this share (by `far` m).
uniform float far_keep = 0.45;
uniform float far = 3000.0;

varying float across;
varying float lit;
varying float along;

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
	float main = COLOR.r;
	float on = mix(branch_flash, flash, main);
	// Thinner than the floor: as bright as the share of it it fills, but
	// never so faint a far bolt goes.
	float share = clamp(UV2.x / floor_w, 0.3, 1.0);
	lit = UV2.y * on * share * mix(1.0, far_keep, smoothstep(300.0, far, d));
}

void fragment() {
	float x = abs(across) * spread;
	float core = exp(-x * x * 1.6);
	float glow = exp(-x * 0.9) * halo + exp(-abs(across) * abs(across) * 4.0) * halo * 0.25;
	// A branch fades to its tip; every channel thins in from its root.
	float tip = mix(1.0, 1.0 - along * along * 0.85, 1.0 - COLOR.r);
	// The main channel comes out of the cloud base (and, cloud to cloud,
	// goes back into it: COLOR.g).
	tip *= mix(1.0, smoothstep(0.0, 0.1, along), COLOR.r);
	tip *= mix(1.0, smoothstep(1.0, 0.9, along), COLOR.g);
	vec3 col = (tint * core * hot + halo_tint * glow) * lit * tip;
	ALBEDO = col;
	ALPHA = 1.0;
}
