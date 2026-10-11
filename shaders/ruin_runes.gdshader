shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;
// The ruins' night runes (scripts/kit_isle/kit_night_lights.gd): a few
// glyphs cut into a stone's face, in the rune serpent's language
// (shaders/rune_glyphs.gdshaderinc), glowing faintly and cool after dark.
// One quad per carving, laid a hair off the face (a MultiMesh); added over
// the stone, so by day (`night` 0) nothing is drawn at all.
// Per instance (INSTANCE_CUSTOM): x the carving's seed, y how many glyphs
// side by side, z its breathing's phase, w its strength. UV across the
// quad, 0..1. No fog (an added colour would glow through it): it fades out
// with distance instead, by `reach` m.
#include "res://shaders/rune_glyphs.gdshaderinc"

uniform vec3 colour : source_color = vec3(0.55, 0.85, 1.0);
uniform float energy = 1.0;
uniform float night = 0.0;
// A stroke's half width and its soft glow in the stone (share, spread).
uniform float width = 0.05;
uniform float halo = 0.3;
uniform float halo_spread = 5.0;
// The slow breathing: seconds a breath, how deep.
uniform float breath_period = 7.0;
uniform float breath_depth = 0.35;
uniform float reach = 260.0;

varying vec4 info;
varying float far_fade;

void vertex() {
	info = INSTANCE_CUSTOM;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	far_fade = 1.0 - smoothstep(reach * 0.5, reach, length(CAMERA_POSITION_WORLD - world));
}

void fragment() {
	float n = max(floor(info.y + 0.5), 1.0);
	float u = UV.x * n;
	float id = floor(u);
	// A glyph's cell is 0.62 as wide as it is tall (the quad is made so).
	vec2 p = vec2((fract(u) - 0.5) * 0.62, 0.5 - UV.y);
	float d = rs_rune(p, rs_hash(info.x * 31.0 + id));
	float aa = max(fwidth(d), 1e-4);
	float core = 1.0 - smoothstep(width - aa, width + aa, d);
	float soft = exp(-d * d / (width * width * halo_spread));
	float lit = core + halo * soft;
	float breath = 1.0 - breath_depth * 0.5 + breath_depth * 0.5 * sin(6.28318 * (TIME / breath_period + info.z));
	// The edges of the quad give nothing, whatever the halo.
	float edge = smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.92, UV.y) * smoothstep(0.0, 0.04, UV.x) * smoothstep(1.0, 0.96, UV.x);
	ALBEDO = colour * lit * energy * night * info.w * breath * far_fade * edge;
}
