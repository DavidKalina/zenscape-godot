// A warm light's reflection on a lake (scripts/lake_dress.gd): a soft
// streak lying on the water where the light's mirror image shows from
// the eye, stretched toward the eye and broken by the ripples into
// drifting dashes, as a lantern's light lies on a still lake at night.
// Each instance stands on the water under its light (its origin), its
// scale the streak's width; INSTANCE_CUSTOM.x the light's height over the
// water (m), .y how far open water reaches round that point (m: the streak
// never leaves it). Colour is its tint, alpha its strength; `glow` the
// night's. Drawn after the water (render priority).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform float zs_flow_time;
uniform float glow = 0.0;
uniform float far_size = 0.012;
uniform float stretch = 7.0;

varying float v_fade;
varying float v_length;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 water = MODEL_MATRIX[3].xyz;
	float h = max(INSTANCE_CUSTOM.x, 0.05);
	float open_r = max(INSTANCE_CUSTOM.y, 0.3);
	vec3 eye = CAMERA_POSITION_WORLD;
	float over = eye.y - water.y;
	// Where the mirror image shows on the water from the eye.
	vec2 flat_to_eye = eye.xz - water.xz;
	float flat_d = length(flat_to_eye);
	vec2 toward = flat_d > 0.001 ? flat_to_eye / flat_d : vec2(0.0, 1.0);
	float shift = flat_d * h / max(over + h, 0.05);
	float held = min(shift, open_r);
	vec2 at = water.xz + toward * held;
	float d = length(eye - vec3(at.x, water.y, at.y));
	float width = max(s, d * far_size);
	// Grazing views stretch it long toward the eye, looking down it pools.
	float graze = 1.0 - clamp(over / max(d, 0.001), 0.0, 1.0);
	float len = width * (1.0 + stretch * graze * graze);
	len = min(len, open_r * 2.0 + width);
	v_length = len;
	v_fade = (over > 0.0 ? 1.0 : 0.0) * (1.0 - smoothstep(0.6, 1.0, (shift - open_r) / max(open_r, 0.3)));
	vec3 across = vec3(-toward.y, 0.0, toward.x) * width;
	vec3 along = vec3(toward.x, 0.0, toward.y) * len;
	vec3 centre = vec3(at.x, water.y + 0.025, at.y);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(across, 0.0), vec4(along, 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(centre, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float core = exp(-p.x * p.x * 9.0) * (1.0 - smoothstep(0.55, 1.0, abs(p.y)));
	// The ripples break it into dashes drifting along it.
	float wave = p.y * v_length * 2.6;
	float dash = 0.55 + 0.45 * sin(wave * 3.1 + zs_flow_time * 1.7 + sin(wave * 1.3 - zs_flow_time * 0.9) * 1.6);
	float a = core * mix(1.0, dash, 0.75) * glow * COLOR.a * v_fade;
	ALBEDO = COLOR.rgb;
	ALPHA = clamp(a, 0.0, 1.0);
}
