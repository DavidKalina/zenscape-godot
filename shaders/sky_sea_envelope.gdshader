shader_type canvas_item;
render_mode unshaded, blend_disabled;
// The near cloud sea's envelope, baked (scripts/sky_sea.gd `_bake`): the
// heap-field and the domes of shaders/sky_sea.gdshader `sea_rise`, the
// Storybook sea's own (shaders/sky_sea_domes.gdshaderinc), drawn once over
// a square of the drifting field round the eye so the sea's march reads
// them from a texture instead of working out some forty hashes a step.
// Red the heap-field's mass (-1..1 as 0..1), green the domes' height.
#include "res://shaders/sky_sea_domes.gdshaderinc"

// The square's corner and side (m), in the field's drifting frame (world xz
// plus the drift so far), and the domes' cell (m).
uniform vec2 origin;
uniform float side = 6000.0;
uniform float cell = 72.0;

void fragment() {
	vec2 p = (origin + UV * side) / cell;
	float mass = zs_storybook_sea_gnoise(p * 0.23 + vec2(3.1, 7.7)) * 0.7 + zs_storybook_sea_gnoise(p * 0.51 + vec2(8.3, 1.9)) * 0.3;
	float h = zs_storybook_sea_domes(p / ZS_SEA_DOME) * 0.62 + 0.38 * 0.45;
	COLOR = vec4(mass * 0.5 + 0.5, h, 0.0, 1.0);
}
