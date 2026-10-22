shader_type spatial;
// The grass carpet's far ring on the endless land (scripts/endless/
// endless_grass.gd): the game's lite tuft (scripts/grass_tuft_mesh.gd
// build_lite) a few pixels across, 20 to 230 m off, drawn plainly. The near
// ring keeps the isles' own tuft material (shaders/reference_surface.gdshader
// with `grass_blades`), whose sway, ground colour and light, worked out at
// every vertex and pixel, cost ten times this over a field that reaches the
// horizon. Here: the same rings (reference_surface `grass_ring`: each tuft
// shrinks into the ground at its own distance over grass_ring), the ring
// distance the endless grass's (shaders/endless_ring.gdshaderinc: along the
// ground, led out ahead of the view), the tuft's own colours (the vertex
// colour, its instance tint the painted ground's patches) toned to the near
// tuft's look (`root_tone`, `tip_tone`), the sun by Godot, the sky's fill as
// emission (as the isles' surfaces take it), the clouds' shade at its root,
// and the night's grade.
//
// The handoff from the near ring: each far tuft comes up at its own
// distance in `grass_ring_in`.x..y (over .z m), as the near ring's tufts go
// at theirs over the same band, at the near tuft's size there
// (`grow_near`), and grows only slowly past it (to `grass_ring_grow`.zw
// wide and tall by .y m). A tuft in a flower drift's colour (its instance
// alpha k/16: wash_colours[k-1] on its upper blades) comes up over `wash_in`
// instead, as the drawn flowers go.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/cloud_volume_shadow.gdshaderinc"
#include "res://shaders/endless_ring.gdshaderinc"
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/grass_silver.gdshaderinc"
#include "res://shaders/grass_react.gdshaderinc"

uniform vec4 grass_ring = vec4(0.0);
uniform vec4 grass_ring_in = vec4(0.0, 1.0, 1.0, 0.0);
uniform vec2 grow_near = vec2(1.0);
uniform vec4 grass_ring_grow = vec4(0.0, 1.0, 1.0, 1.0);
uniform vec4 wash_in = vec4(0.0, 1.0, 1.0, 0.0);
uniform vec3 wash_colours[8];
// How far up the blade the wash takes over (along the blade, 0 root, 1 tip).
uniform vec2 wash_tip = vec2(0.3, 0.75);
// The tuft mesh's own colours at its root and tip (linear; scripts/
// grass_tuft_mesh.gd, its `grass_root`, `grass_tip` meta), divided out so
// only each blade's jitter and the instance's tint are left, and the colours
// the far tuft takes there instead (and how the tip's climbs).
uniform vec3 grass_source_root = vec3(0.0396, 0.1329, 0.0423);
uniform vec3 grass_source_tip = vec3(0.2917, 0.5271, 0.1145);
uniform vec3 root_colour = vec3(0.10, 0.22, 0.07);
uniform vec3 tip_colour = vec3(0.30, 0.45, 0.12);
uniform float tip_curve = 1.0;
// The share of the normal leant up, so the clump lights as one soft mass.
uniform float mass_normal : hint_range(0.0, 1.0) = 0.8;
uniform float cloud_shade : hint_range(0.0, 1.0) = 0.5;
// Seen at a glance the near tufts show their shaded sides: the far ones
// take this much of their light there (the eye's elevation over the root,
// full light from `graze_angles.y`).
uniform float graze_tone : hint_range(0.0, 1.0) = 0.72;
uniform vec2 graze_angles = vec2(0.04, 0.4);
uniform vec4 night_grade = vec4(0.0);

varying float along;
varying float shade;
varying vec3 mass;
varying float glance;
varying vec3 wash;
varying float washed;
varying float silver;
// How stirred its patch is (shaders/grass_react.gdshaderinc).
varying float react;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float ring_d = endless_ring_d(CAMERA_POSITION_WORLD, root);
	float ring_rank = fract(sin(dot(root.xz, vec2(19.31, 71.87))) * 43758.5453);
	float ring_at = mix(grass_ring.x, grass_ring.y, ring_rank);
	float ring_keep = 1.0 - smoothstep(ring_at - grass_ring.z, ring_at, ring_d);
	// The handoff: up at its own distance in the near ring's band (a flower
	// tuft: in the flowers'), at the near tuft's size.
	washed = COLOR.a < 0.99 ? 1.0 : 0.0;
	int kind = clamp(int(COLOR.a * 16.0 + 0.5) - 1, 0, 7);
	wash = wash_colours[kind];
	vec4 band = washed > 0.5 ? wash_in : grass_ring_in;
	float in_rank = fract(sin(dot(root.xz, vec2(41.37, 17.93))) * 24634.6345);
	float in_at = mix(band.x, band.y, in_rank);
	ring_keep *= smoothstep(in_at, in_at + band.z, ring_d);
	vec2 size = mix(grow_near, grass_ring_grow.zw, smoothstep(grass_ring_grow.x, grass_ring_grow.y, ring_d));
	VERTEX.xz *= ring_keep * size.x;
	VERTEX.y *= ring_keep * size.y;
	// The grass reacting: bent and laid over by the wash, the walker, a gust.
	react = 0.0;
	if (zs_react_live() && ring_keep > 0.0) {
		float react_scale = length(MODEL_MATRIX[1].xyz);
		VERTEX += zs_react_offset(root.xz, max(VERTEX.y, 0.0) * react_scale, 1.0, MODEL_MATRIX, react_scale, CAMERA_POSITION_WORLD.xz - root.xz, react);
	}
	along = clamp(UV.y, 0.0, 1.0);
	glance = mix(graze_tone, 1.0, smoothstep(graze_angles.x, graze_angles.y, normalize(CAMERA_POSITION_WORLD - MODEL_MATRIX[3].xyz).y));
	shade = ring_keep > 0.0 ? zs_cloud_volume_shade(MODEL_MATRIX[3].xyz) : 0.0;
	// The light's normal: the clump as one soft mass, mostly up, either face.
	vec3 world_n = normalize(mat3(MODEL_MATRIX) * NORMAL);
	if (world_n.y < 0.0) world_n = -world_n;
	mass = normalize(mix(world_n, vec3(0.0, 1.0, 0.0), mass_normal));
	// The underside the wind flips (grass_silver): its field at the root, as
	// the near tufts and the ground's paint read it, at a pixel's footprint.
	silver = 0.0;
	if (grass_silver.x > 0.0 && ring_keep > 0.0) {
		float seen = length(CAMERA_POSITION_WORLD - root);
		float rise = max(normalize(CAMERA_POSITION_WORLD - root).y, 0.08);
		silver = zs_silver_drive(root.xz, seen * 0.0016 * (0.6 + 0.4 / rise));
	}
}

void fragment() {
	vec3 source = max(mix(grass_source_root, grass_source_tip, along), vec3(0.002));
	vec3 own = clamp(COLOR.rgb / source, vec3(0.0), vec3(3.0));
	vec3 c = own * mix(root_colour, tip_colour, pow(along, tip_curve)) * glance;
	c = mix(c, wash * glance, washed * smoothstep(wash_tip.x, wash_tip.y, along));
	if (grass_silver.x > 0.0) c = zs_silver_paint(c, silver, smoothstep(0.15, 0.85, along), 0.8);
	c = zs_react_tone(c, react * along);
	c = mix(c, vec3(dot(c, vec3(0.2126, 0.7152, 0.0722))) * night_grade.yzw, night_grade.x);
	ALBEDO = c * (1.0 - shade * cloud_shade);
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
	NORMAL = normalize((VIEW_MATRIX * vec4(mass, 0.0)).xyz);
	vec3 n = mass;
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	EMISSION = c * hemi * (0.75 + 0.25 * along);
}
