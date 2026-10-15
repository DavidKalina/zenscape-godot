shader_type spatial;
// [linger] The colossus's cloud bank (scripts/roguelike/linger_colossus_cloud.gd):
// soft painted puffs, billboards in a MultiMesh, a broad wash with a noisy
// edge, lit from above, faded where they meet the stone (a soft depth fade),
// so his body goes down into them rather than being cut by a quad.
// INSTANCE_CUSTOM: x seed, y opacity, z churn phase, w tone (0 shade .. 1 lit).
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec3 light_col : source_color = vec3(0.86, 0.84, 0.80);
uniform vec3 shade_col : source_color = vec3(0.46, 0.47, 0.52);
uniform float opacity = 1.0;
uniform float clock = 0.0;
// Metres over which a puff fades into what stands in it.
uniform float soft_fade = 30.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying vec4 v_custom;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
	float s = 0.0;
	float w = 0.5;
	for (int i = 0; i < 4; i++) { s += vnoise(p) * w; p = p * 2.03 + vec2(1.7, 9.2); w *= 0.5; }
	return s;
}

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	// A billboard keeping the instance's own size (x across, y up).
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float seed = v_custom.x * 17.0;
	float t = clock * 0.03 + v_custom.z;
	float n = fbm(p * 1.6 + vec2(seed, seed * 0.37) + vec2(t, -t * 0.6));
	float n2 = fbm(p * 4.2 + vec2(seed * 1.3, t * 1.7));
	// The puff: a flattened blob, its edge eaten by the noise.
	float d = length(vec2(p.x, p.y * 1.15 + 0.1));
	float blob = 1.0 - smoothstep(0.38, 1.0, d + (n - 0.5) * 0.7 + (n2 - 0.5) * 0.2);
	// Lit from above: the tops pale, the bellies grey.
	float lit = clamp(0.5 - p.y * 0.55 + (n - 0.5) * 0.6 + v_custom.w * 0.4 - 0.2, 0.0, 1.0);
	ALBEDO = mix(shade_col, light_col, lit);
	// Soft against what stands in it.
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float behind = -(world.z / world.w);
	float here = -VERTEX.z;
	float soft = clamp((behind - here) / soft_fade, 0.0, 1.0);
	ALPHA = clamp(blob * opacity * v_custom.y * soft, 0.0, 1.0);
}
