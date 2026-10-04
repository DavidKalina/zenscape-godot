shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;
// Fallen leaves. The mesh stacks every leaf shape, one id per shape in UV.x; an
// instance picks its shape with INSTANCE_CUSTOM.x and the others collapse to
// a point. INSTANCE_CUSTOM.y curls the edges up. Soft like the grass: wrapped
// light, a little light through the blade, a faint warm glow, no shine.
uniform float glow : hint_range(0.0, 0.5) = 0.10;
uniform float through : hint_range(0.0, 1.0) = 0.35;

void vertex() {
	if (abs(UV.x - INSTANCE_CUSTOM.x) > 0.5) {
		VERTEX = vec3(0.0);
	} else {
		VERTEX.y += INSTANCE_CUSTOM.y * VERTEX.x * VERTEX.x;
	}
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.0);
	EMISSION = COLOR.rgb * (glow + 0.12 * rim);
	BACKLIGHT = COLOR.rgb * through;
}
