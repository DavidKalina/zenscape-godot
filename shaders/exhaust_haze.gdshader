shader_type spatial;
// The heat off the stubs (scripts/plane_exhaust.gd): a quad along the stream,
// turned round that line to face the eye, showing what's behind it pushed about
// a little by noise running down the stream. Its push is a size in the world, so
// it keeps its look near and far, and it fades at the quad's edges and end on.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float amount = 0.0;
uniform float clock = 0.0;
// The push in toy units, the pattern's scale along and across, its run.
uniform float push = 0.016;
uniform vec2 scale = vec2(6.0, 11.0);
uniform float run = 2.4;

varying float v_face;
varying float v_size;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 along = normalize(MODEL_MATRIX[1].xyz);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - c);
	vec3 across = cross(along, eye);
	v_face = smoothstep(0.08, 0.4, length(across));
	across = normalize(across);
	v_size = length(MODEL_MATRIX[1].xyz);
	vec3 w = c + across * VERTEX.x * length(MODEL_MATRIX[0].xyz) + along * VERTEX.y * v_size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
}

void fragment() {
	// UV.y runs 0 at the far end to 1 at the stubs.
	vec2 q = vec2(UV.x * scale.x, UV.y * scale.y + clock * run);
	vec2 flow = vec2(vnoise(q), vnoise(q + vec2(7.3, 3.1))) - 0.5;
	float m = sin(UV.x * PI) * smoothstep(0.0, 0.2, 1.0 - UV.y) * smoothstep(0.0, 0.75, UV.y) * v_face;
	float reach = PROJECTION_MATRIX[1][1] * push * v_size / max(-VERTEX.z, 0.05);
	vec2 off = flow * reach * m * amount;
	off.x /= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	ALBEDO = texture(screen_tex, SCREEN_UV + off).rgb;
	ALPHA = smoothstep(0.0, 0.2, m * amount);
}
