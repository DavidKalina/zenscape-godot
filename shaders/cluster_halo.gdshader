// The sky clusters' night lights (scripts/cluster_dresser.gd): a soft warm
// glow round each window, lamp and lantern, a camera-facing quad added over
// what is behind it, as the stone lamps' halo (shaders/stone_lamp_halo.
// gdshader). Seen from far it never shrinks under `far_size` of its
// distance (a few pixels), and brightens a little, so a cluster's lights
// read as warm points from a plane passing a hundred metres off. Drawn
// toward the eye by part of its size, so the wall it hangs on never cuts
// it in half. Each instance's colour is its tint, alpha its strength; its
// scale its size near. `glow` is the night's.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float glow = 0.0;
uniform float far_size = 0.02;
uniform float far_boost = 2.2;

varying float v_far;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 to_eye = CAMERA_POSITION_WORLD - centre;
	float d = length(to_eye);
	float size = max(s, d * far_size);
	v_far = clamp((size - s) / max(s, 0.001), 0.0, 1.0);
	centre += to_eye / max(d, 0.001) * min(size * 0.45, d * 0.2);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * size, INV_VIEW_MATRIX[1] * size, INV_VIEW_MATRIX[2] * size, vec4(centre, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	float a = (exp(-r2 * 5.0) * 0.7 + exp(-r2 * 22.0) * 0.6) * (1.0 - smoothstep(0.6, 1.0, r2));
	ALBEDO = COLOR.rgb;
	ALPHA = clamp(a * glow * COLOR.a * mix(1.0, far_boost, v_far), 0.0, 1.0);
}
