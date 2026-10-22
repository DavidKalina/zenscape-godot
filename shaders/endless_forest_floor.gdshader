shader_type spatial;
// The endless forests' floor (scripts/endless/land_trees.gd): a sheet draped
// over the land where the woods stand (its vertex alpha the woods' weight),
// the shade and needle litter under the spruces, so a wood reads as one
// mass from the air. Pulled toward the eye (lift, more with distance) so the
// land's coarser far chunks don't cover it; shown over `band` m from the
// eye (grown in over band.x..+y, gone over band.z-w..z), so the near and
// far sheets hand over.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_lambert, specular_disabled;

uniform vec4 band = vec4(-1.0, 1.0, 1e6, 1.0);
uniform vec4 colour : source_color = vec4(0.1, 0.16, 0.08, 1.0);
uniform float strength = 0.8;
// Pulled toward the eye: lift.x m plus lift.y of its distance.
uniform vec2 lift = vec2(0.25, 0.004);
// The litter's mottle: its scale (m) and how much it moves the colour.
uniform vec2 mottle = vec2(9.0, 0.25);

varying float fade;
varying vec3 world;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(world, CAMERA_POSITION_WORLD);
	fade = smoothstep(band.x, band.x + band.y, d) * (1.0 - smoothstep(band.z - band.w, band.z, d));
	vec3 to = normalize(CAMERA_POSITION_WORLD - world);
	VERTEX += to * (lift.x + lift.y * d);
}

void fragment() {
	float m = noise(world.xz / mottle.x) * 0.65 + noise(world.xz / (mottle.x * 0.31)) * 0.35;
	ALBEDO = colour.rgb * (1.0 + (m - 0.5) * 2.0 * mottle.y);
	ROUGHNESS = 1.0;
	ALPHA = clamp(COLOR.a * strength * fade, 0.0, 1.0);
}
