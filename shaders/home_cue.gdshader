shader_type spatial;
// A far cue (studies/heist_home.gd): a soft column of smoke or spray on a
// quad turned about its own up to the camera, drawn past the fog (the haze
// hides the land, not this) and faded out past `far`. Its foot at the
// node, its far end `up` (+1 over it, -1 under it); `foot` and `end` its
// width there as shares of the quad's.
render_mode unshaded, fog_disabled, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.9, 0.92, 0.95, 0.8);
uniform float foot = 0.2;
uniform float end = 1.0;
uniform float up = 1.0;
uniform float far = 1500.0;
uniform float fade = 375.0;
uniform float seed = 0.0;
uniform float speed = 0.035;

varying float v_far;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Turned about its own up to face the camera (Godot's fixed-Y billboard).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_far = length(CAMERA_POSITION_WORLD - NODE_POSITION_WORLD);
}

void fragment() {
	// h: 0 at the foot, 1 at the far end; x: -1..1 across.
	float h = up > 0.0 ? 1.0 - UV.y : UV.y;
	float x = UV.x * 2.0 - 1.0;
	float t = TIME * speed;
	float width = mix(foot, end, pow(h, 0.7));
	// The column wanders sideways as it goes.
	float sway = (fbm(vec2(h * 2.5 + seed, t * 0.6)) - 0.5) * 0.5 * h;
	float across = abs(x - sway) / max(width, 0.01);
	float body = 1.0 - smoothstep(0.35, 1.0, across);
	float billow = fbm(vec2(x * 3.0 + seed, h * 6.0 - t * 4.0 * up));
	float a = body * smoothstep(0.25, 0.75, billow + 0.25 * (1.0 - across));
	// Dense at the foot, thinning to nothing at the far end.
	a *= smoothstep(0.0, 0.06, h) * (1.0 - smoothstep(0.55, 1.0, h));
	a *= 1.0 - smoothstep(far - fade, far, v_far);
	ALBEDO = tint.rgb * mix(0.85, 1.1, billow);
	ALPHA = clamp(a * tint.a, 0.0, 1.0);
}
