shader_type spatial;
// The skydive's canopy (scripts/canopy_figure.gd): doped cloth over its
// cells, faceted as every solid is, soft as cloth moves. Each face is lit
// flat (its normal from the screen-space slope of the surface, so the
// facets stay crisp as the cloth moves); ripples run along the span, most
// at the trailing edge (UV.y 1) and as hard as `flutter`; the sun through
// the cloth glows on its underside (BACKLIGHT).
render_mode cull_disabled, specular_schlick_ggx;

uniform float flutter = 0.3;
uniform float glow : hint_range(0.0, 1.0) = 0.5;

void vertex() {
	float s = UV.x;
	float u = UV.y;
	float ripple = sin(TIME * 9.0 + s * 17.0 + u * 3.0) * 0.6 + sin(TIME * 13.7 - s * 23.0) * 0.4;
	float reach = 0.2 + u * u * 1.5;
	VERTEX.y += ripple * flutter * reach * 0.035;
	// The whole wing breathes a little.
	VERTEX.y += sin(TIME * 2.1 + s * 4.0) * flutter * 0.012;
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VIEW) < 0.0) n = -n;
	NORMAL = n;
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.78;
	SPECULAR = 0.35;
	BACKLIGHT = COLOR.rgb * glow;
}
