shader_type spatial;
render_mode cull_disabled, unshaded;
// A curtain waterfall: a solid white sheet of falling strands (study:
// studies/waterfall_study.tscn). Opaque, never blended: the body hides
// whatever is behind it, and the edges are a hard cutoff (discard), not a
// fade. Strands are noise stretched hard along the fall, in three layers
// falling at their own speeds, and each layer speeds up toward the bottom.
// The quad's local X is across the fall, local Y up; its size comes in as
// `sheet_size` (m). Everything look-related is a uniform below.

uniform vec2 sheet_size = vec2(26.0, 39.6);
// Strand columns per metre across the fall (bigger: finer strands).
uniform float streak_scale : hint_range(0.5, 8.0) = 2.6;
// How much longer a strand is than it is wide (bigger: longer, thinner).
uniform float streak_stretch : hint_range(2.0, 40.0) = 14.0;
// Metres per second the layers fall near the lip (the layers run 0.6x, 1x, 1.5x of it).
uniform float fall_speed : hint_range(0.0, 30.0) = 7.0;
// How much faster it falls toward the bottom than at the lip (0 none).
uniform float fall_accel : hint_range(0.0, 4.0) = 1.5;
uniform float fall_height = 39.6;
// How deep the sides and lip are bitten, in metres.
uniform float edge_raggedness : hint_range(0.0, 3.0) = 1.0;
// The lip's raggedness as a share of the sides'.
uniform float lip_raggedness : hint_range(0.0, 1.0) = 0.5;
// White to pale blue-grey: how far down the shading goes (0 all white, 1 full range).
uniform float shade_range : hint_range(0.0, 1.0) = 0.7;
uniform vec3 white_color : source_color = vec3(0.97, 0.985, 1.0);
uniform vec3 shade_color : source_color = vec3(0.62, 0.72, 0.80);
// Metres at the base where the strands go whiter (tight foam, no mist).
uniform float foam_height = 1.6;

varying vec2 sheet_pos;

float h21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Value noise smoothed along y only: columns stay separate across x.
float strand_noise(vec2 p) {
	vec2 i = floor(p);
	float f = fract(p.y);
	f = f * f * (3.0 - 2.0 * f);
	return mix(h21(i), h21(vec2(i.x, i.y + 1.0)), f);
}

float full_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	sheet_pos = VERTEX.xy + 0.5 * sheet_size;
}

// Depth below the lip, warped so a pattern stretches (seems to fall faster)
// toward the bottom.
float warp(float d) {
	float k = fall_accel / max(fall_height, 1.0);
	return log(1.0 + k * d) / max(k, 0.0001);
}

void fragment() {
	float x = sheet_pos.x;
	float depth = sheet_size.y - sheet_pos.y;
	float side = min(x, sheet_size.x - x);
	float left = x < sheet_size.x * 0.5 ? 0.0 : 1.0;
	float w = warp(depth);

	// Three layers: different column widths, speeds and offsets.
	float c1 = streak_scale;
	float c2 = streak_scale * 1.7;
	float c3 = streak_scale * 3.1;
	float l1 = strand_noise(vec2(x * c1, (w - TIME * fall_speed * 0.6) * c1 / streak_stretch + 3.0));
	float l2 = strand_noise(vec2(x * c2 + 11.0, (w - TIME * fall_speed) * c2 / streak_stretch));
	float l3 = strand_noise(vec2(x * c3 + 23.0, (w - TIME * fall_speed * 1.5) * c3 / (streak_stretch * 1.3) + 7.0));
	float s = l1 * 0.45 + l2 * 0.35 + l3 * 0.2;
	// Sharpen into distinct strands rather than a smooth gradient.
	s = smoothstep(0.3, 0.6, s);

	// Hard, ragged edges: the sides and the lip are bitten by strand noise.
	float rag = strand_noise(vec2(left * 5.0 + 3.0, (w - TIME * fall_speed * 0.8) * 0.5)) * 0.3
		+ strand_noise(vec2(left * 9.0 + 1.0, (w - TIME * fall_speed * 1.2) * 1.3)) * 0.35
		+ strand_noise(vec2(left * 13.0 + 7.0, (w - TIME * fall_speed * 1.5) * 3.5)) * 0.35;
	if (side < 0.15 + rag * edge_raggedness * (0.4 + 0.6 * s) * 2.0) discard;
	float lip_n = strand_noise(vec2(x * 2.2 + 40.0, 0.0)) * 0.6 + h21(vec2(floor(x * 5.0), 3.0)) * 0.4;
	if (depth < 0.1 + lip_n * edge_raggedness * lip_raggedness * 2.0) discard;

	// Shading: white strands, the troughs between them pale blue-grey.
	float shade = (1.0 - s) * shade_range;
	shade += (full_noise(vec2(x * 0.3, w * 0.05 - TIME * 0.5)) - 0.5) * 0.15 * shade_range;
	// Foam: whiter at the base.
	float foam = 1.0 - smoothstep(0.0, foam_height, sheet_pos.y);
	shade *= 1.0 - 0.85 * foam;
	ALBEDO = mix(white_color, shade_color, clamp(shade, 0.0, 1.0));
}
