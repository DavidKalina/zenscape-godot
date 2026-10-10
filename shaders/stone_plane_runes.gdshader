shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// The runes along the stone plane's deck (scripts/stone_plane_figure.gd),
// its speed cue: glyphs of light (a dash, then a pair of dots) that run back
// along the hull, faster the faster it flies (`scroll`, metres, integrated
// by the script). UV.x is metres along the strip from the nose, UV.y 0..1
// across. The sync pulse passes along them as along the seams.
uniform vec3 glow : source_color = vec3(1.0, 0.86, 0.6);
uniform float energy = 0.0;
uniform float scroll = 0.0;
uniform float cell = 0.045;
uniform float streak = 0.0;
uniform float pulse_front = -10.0;
uniform float pulse_amp = 0.0;
varying float along;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void vertex() {
	along = VERTEX.z;
}

void fragment() {
	float u = (UV.x - scroll) / cell;
	float id = floor(u);
	float f = fract(u);
	float y = UV.y;
	float mask;
	if (hash(id) < 0.55) {
		// A dash, drawn longer as it streaks at speed.
		float half_len = 0.3 + 0.18 * streak;
		mask = smoothstep(0.5 - half_len - 0.08, 0.5 - half_len, f) * (1.0 - smoothstep(0.5 + half_len, 0.5 + half_len + 0.08, f));
		mask *= smoothstep(0.1, 0.3, y) * (1.0 - smoothstep(0.7, 0.9, y));
	} else {
		// A pair of dots.
		float a = length(vec2((f - 0.32) * 2.2, y - 0.5));
		float b = length(vec2((f - 0.68) * 2.2, y - 0.5));
		mask = (1.0 - smoothstep(0.22, 0.34, min(a, b))) * (1.0 - 0.4 * streak);
	}
	float d = (along - pulse_front) / 0.14;
	float pulse = pulse_amp * exp(-d * d);
	ALBEDO = glow * mask * (energy + pulse * 3.0);
}
