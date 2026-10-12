// The stone lamps' halo (scripts/stone_lamp_lights.gd): a soft warm glow
// round each fire box, a camera-facing quad added over what is behind it.
// Its strength is the night's glow; by day it is off.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform float glow = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.7, 0.42, 1.0);
// How far toward the eye the quad is drawn, as a share of its size, so a
// halo set inside a mesh (the dragon's eyes) isn't cut by it. 0 for lamps.
uniform float toward_eye = 0.0;

void vertex() {
	// Face the camera, keeping the instance's size and place.
	float s = length(MODEL_MATRIX[0].xyz);
	vec4 o = MODEL_MATRIX[3];
	o.xyz += normalize(CAMERA_POSITION_WORLD - o.xyz) * toward_eye * s;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, o);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r2 = dot(p, p);
	// A soft falloff, a little brighter at the heart, nothing at the edge.
	float a = (exp(-r2 * 5.0) * 0.75 + exp(-r2 * 18.0) * 0.5) * (1.0 - smoothstep(0.6, 1.0, r2));
	ALBEDO = tint.rgb;
	ALPHA = clamp(a * glow, 0.0, 1.0);
}
