shader_type spatial;
// The hall rise's cloud puffs (scripts/hall_rise.gd): soft greybox
// balls of cloud, each instance's alpha in its colour; lit from above by
// hand (the cloud sea's own colours), feathered at the rim so they read as
// soft heaps rather than balls.
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;
uniform vec3 top : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 under : source_color = vec3(0.66, 0.71, 0.8);
uniform float feather = 0.75;

varying float fade;

void vertex() {
	fade = COLOR.a;
}

void fragment() {
	vec3 n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float rim = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(under, top, clamp(n.y * 0.6 + 0.55, 0.0, 1.0));
	ALPHA = fade * smoothstep(0.0, feather, rim);
}
