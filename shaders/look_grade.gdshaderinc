// Look pass grade and vignette (scripts/look_pass.gd), shared by the
// display-fog blend and the standalone grade used when native fog replaces it.
// All zero leaves the colour untouched.
uniform float grade_strength = 0.0;
uniform vec3 grade_shadow = vec3(1.0);
uniform vec3 grade_highlight = vec3(1.0);
uniform float grade_saturation = 1.0;
uniform float vignette = 0.0;
// Night (studies/celestial.gd `night_grade`): x how much colour gives way to
// a cool rod-lit grey, yzw that grey's hue. Zero by day.
uniform vec4 grade_night = vec4(0.0);

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

// The night look: the eye's rods take over, so mid-values lose their colour
// and lean blue-green (the Purkinje shift). `land` masks it to what stands in
// front of the sky (and the air over it), so the aurora keeps its colour, and
// bright lights (fireflies, glints, stars, the moon) keep theirs and pop.
vec3 zs_look_night(vec3 color, float land) {
	if (grade_night.x <= 0.0) return color;
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float rods = dot(color, vec3(0.06, 0.58, 0.36));
	float keep = smoothstep(0.5, 0.95, max(max(color.r, color.g), color.b));
	vec3 rod_lit = grade_night.yzw * mix(luma, rods, 0.6);
	return mix(color, rod_lit, grade_night.x * land * (1.0 - keep));
}
