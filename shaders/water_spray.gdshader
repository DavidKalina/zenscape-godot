shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;
// The drawn spray (scripts/endless/water_contact.gd, shaders/water_spray_process.gdshader):
// `kind` 0 drops, quads stretched along their velocity (the particle's Y
// axis, scaled by the process pass) and turned to face the eye, round
// across like a falling thread of water, glinting; 1 mist, soft round
// billboards of broken spume, lit through from behind. Both fade near the
// eye, so the camera passing through the plume doesn't fill with it.

global uniform vec3 zs_hemi_sky;
global uniform float zs_hemi_energy;

uniform int kind = 0;
uniform vec4 tint : source_color = vec4(0.76, 0.9, 1.0, 1.0);
// The sky's light in it, over the lit sun (water is never dark in the open).
uniform float glow = 0.35;
uniform float opacity = 0.75;
// Faded out this near the eye (m: gone, whole).
uniform vec2 near_fade = vec2(0.6, 2.5);
uniform float backlight = 0.6;

varying float fade;
varying float seed;
varying float spin;

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.55);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.55);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.55);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.55);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz;
	float width = length(MODEL_MATRIX[0].xyz);
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	vec3 to_eye = normalize(eye - centre);
	vec3 world;
	if (kind == 0) {
		vec3 along = normalize(axis + vec3(0.0, 1e-5, 0.0));
		vec3 across = cross(along, to_eye);
		if (length(across) < 0.05) across = INV_VIEW_MATRIX[0].xyz;
		across = normalize(across) * width;
		world = centre + across * VERTEX.x + axis * VERTEX.y;
	} else {
		float a = INSTANCE_CUSTOM.x + INSTANCE_CUSTOM.y * 1.5;
		vec2 r = vec2(cos(a), sin(a));
		vec2 q = vec2(VERTEX.x * r.x - VERTEX.y * r.y, VERTEX.x * r.y + VERTEX.y * r.x);
		world = centre + (INV_VIEW_MATRIX[0].xyz * q.x + INV_VIEW_MATRIX[1].xyz * q.y) * width;
	}
	float dist = length(eye - centre);
	fade = COLOR.a * smoothstep(near_fade.x, near_fade.y, dist);
	seed = INSTANCE_CUSTOM.z;
	spin = INSTANCE_CUSTOM.x;
	MODELVIEW_MATRIX = VIEW_MATRIX;
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX);
	VERTEX = world;
	NORMAL = to_eye;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float alpha;
	if (kind == 0) {
		// A thin thread, brightest down its core, fading to the ends.
		float core = exp(-p.x * p.x * 5.0);
		float end = smoothstep(1.0, 0.3, abs(p.y + 0.2));
		alpha = core * end;
		NORMAL = normalize(vec3(p.x * 0.9, 0.0, 1.0));
		ROUGHNESS = 0.05;
		SPECULAR = 1.0;
		ALBEDO = tint.rgb * 0.7;
	} else {
		float r = length(p);
		vec2 q = p * 1.6 + vec2(seed * 37.0, seed * 11.0);
		float n = vnoise(q * 2.0) * 0.55 + vnoise(q * 4.3 + 3.1) * 0.3 + vnoise(q * 9.1 + 7.7) * 0.15;
		alpha = smoothstep(1.0, 0.25, r) * smoothstep(0.25, 0.75, n + 0.25 * (1.0 - r));
		ROUGHNESS = 0.9;
		SPECULAR = 0.2;
		ALBEDO = tint.rgb;
		NORMAL = normalize(vec3(p.x * 0.6, p.y * 0.6, 1.0));
	}
	BACKLIGHT = vec3(backlight);
	EMISSION = tint.rgb * zs_hemi_sky * zs_hemi_energy / PI * glow;
	ALPHA = clamp(alpha * fade * opacity, 0.0, 1.0);
}
