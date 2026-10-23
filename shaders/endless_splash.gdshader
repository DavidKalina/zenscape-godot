shader_type spatial;
// A fish's splash (scripts/endless/endless_fish.gd), drawn as MultiMesh
// quads. `ring` false: spray, each quad turned to the eye (drops and the
// mist over a splash); true: a ripple ring lying on the water.
// INSTANCE_CUSTOM: x its opacity, y (spray) the soft share of its disc or
// (ring) the band's width as a share of the radius, z (ring) the trough's
// depth inside the crest.
// Lit as the water's face (normal up), so it takes the hour's light.
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform bool ring = false;
uniform vec3 tint : source_color = vec3(0.9, 0.95, 1.0);
uniform vec3 trough_tint : source_color = vec3(0.12, 0.18, 0.2);
uniform float glow = 0.18;

varying vec4 cust;

void vertex() {
	cust = INSTANCE_CUSTOM;
	if (!ring) {
		float s = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX);
		NORMAL = vec3(0.0, 1.0, 0.0);
	}
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	if (ring) {
		float w = max(cust.y, 0.02);
		// The crest: a bright band at the rim; inside it a darker trough.
		float crest = smoothstep(1.0, 1.0 - w * 0.45, r) * smoothstep(1.0 - w * 1.4, 1.0 - w * 0.55, r);
		float trough = smoothstep(1.0 - w * 1.2, 1.0 - w * 2.0, r) * smoothstep(1.0 - w * 3.6, 1.0 - w * 2.3, r);
		// Broken along its length a little, as wind ruffles it.
		float a = atan(q.y, q.x);
		float broken = 0.75 + 0.25 * sin(a * 7.0 + cust.w * 6.2832) * sin(a * 3.0 + 1.3);
		vec3 c = mix(trough_tint, tint, crest / max(crest + trough * cust.z, 1e-3));
		ALBEDO = c;
		EMISSION = c * glow;
		ALPHA = clamp((crest + trough * cust.z) * broken * cust.x, 0.0, 1.0);
	} else {
		float soft = clamp(cust.y, 0.02, 0.98);
		float disc = 1.0 - smoothstep(1.0 - soft, 1.0, r);
		ALBEDO = tint;
		EMISSION = tint * glow;
		ALPHA = disc * cust.x;
	}
}
