// Look pass grade and vignette (scripts/look_pass.gd), shared by the
// display-fog blend and the standalone grade used when native fog replaces it.
// All zero leaves the colour untouched.
uniform float grade_strength = 0.0;
uniform vec3 grade_shadow = vec3(1.0);
uniform vec3 grade_highlight = vec3(1.0);
uniform float grade_saturation = 1.0;
uniform float vignette = 0.0;

vec3 zs_look_grade(vec3 color, vec2 uv, vec2 pixel_size) {
	if (grade_strength > 0.0) {
		float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
		// Light that has burnt out to white (the sun's disc, hot glints) stays
		// white: tinting it turned the sun a cold cyan.
		float burnt = smoothstep(0.78, 0.98, min(min(color.r, color.g), color.b));
		vec3 tint = mix(mix(grade_shadow, grade_highlight, smoothstep(0.05, 0.85, luma)), vec3(1.0), burnt);
		vec3 toned = color * tint;
		toned = mix(vec3(dot(toned, vec3(0.2126, 0.7152, 0.0722))), toned, grade_saturation);
		color = mix(color, toned, grade_strength);
	}
	if (vignette > 0.0) {
		vec2 centered = (uv - 0.5) * vec2(pixel_size.y / pixel_size.x, 1.0);
		color *= 1.0 - vignette * smoothstep(0.35, 1.0, length(centered) * 1.4);
	}
	return color;
}
