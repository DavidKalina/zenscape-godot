shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// A shaft of daylight from the oculus (scripts/underground/underground.gd):
// a long soft cone along the light, brighter in streaks that drift, seen
// through the murk. Fades at its sides (so it has no edge), at both ends,
// near the camera (it never walls the screen) and where it meets stone.
uniform vec3 tint : source_color = vec3(1.0, 0.74, 0.44);
uniform float strength = 0.22;
uniform float near_fade = 28.0;
uniform float far_fade = 700.0;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;

uniform float r_low = 40.0;
uniform float r_top = 60.0;
uniform float length_m = 500.0;
varying float along;
varying float inside;

float h21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	along = UV.y;
	// Inside the cone you stand in the shaft, you don't see its wall: it
	// fades as the camera comes within its radius there.
	vec3 cam = (inverse(MODEL_MATRIX) * vec4(INV_VIEW_MATRIX[3].xyz, 1.0)).xyz;
	float at = clamp(cam.y / length_m + 0.5, 0.0, 1.0);
	float rad = mix(r_low, r_top, at);
	inside = smoothstep(rad * 0.8, rad * 1.6, length(cam.xz));
}

void fragment() {
	// Soft sides: a cylinder seen edge-on is its thickest column of light.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float body = pow(facing, 1.6);
	// Streaks drifting round the shaft, long down it.
	float a = UV.x * 24.0;
	float s = vn(vec2(a, along * 3.0 + TIME * 0.03)) * 0.6 + vn(vec2(a * 2.3 + 7.0, along * 7.0 - TIME * 0.05)) * 0.4;
	float streak = 0.15 + 1.6 * smoothstep(0.3, 0.8, s);
	// Brighter low (the light gathers where it lands), thin at the very top.
	float ends = smoothstep(0.0, 0.08, along) * (1.0 - smoothstep(0.82, 1.0, along));
	float low = mix(0.5, 1.0, 1.0 - along);
	float dist = length(VERTEX);
	float near = smoothstep(near_fade * 0.4, near_fade * 2.0, dist);
	float far = 1.0 - smoothstep(far_fade * 0.5, far_fade * 1.6, dist);
	// Where it meets stone the shaft thins out, so no hard cut.
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).x;
	vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene = -up.z / up.w;
	float meet = clamp((scene - (-VERTEX.z)) / 14.0, 0.0, 1.0);
	ALBEDO = tint * strength * inside * body * streak * ends * low * near * far * meet;
}
