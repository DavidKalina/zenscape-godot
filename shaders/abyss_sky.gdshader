shader_type sky;
// The abyss sky (scripts/underground/underground.gd): near-black cool blue,
// a little lighter toward the horizon so rock silhouettes read, and one
// faint, far, cool glow straight up: the surface the run climbs toward.
uniform vec3 low_color : source_color = vec3(0.02, 0.03, 0.05);
uniform vec3 horizon_color : source_color = vec3(0.09, 0.12, 0.18);
uniform vec3 high_color : source_color = vec3(0.035, 0.055, 0.1);
uniform vec3 surface_color : source_color = vec3(0.45, 0.62, 0.85);
uniform float surface_strength = 0.55;
uniform float surface_size = 0.16;
uniform float surface_tilt = 0.0;

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = d.y;
	vec3 col = mix(horizon_color, high_color, smoothstep(0.0, 0.9, up));
	col = mix(col, low_color, smoothstep(0.0, -0.6, up));
	// The far light: a soft disc and a wide halo round the zenith.
	vec3 axis = normalize(vec3(surface_tilt, 1.0, 0.0));
	float a = acos(clamp(dot(d, axis), -1.0, 1.0));
	float disc = exp(-pow(a / surface_size, 2.0));
	float halo = exp(-pow(a / (surface_size * 4.5), 2.0));
	col += surface_color * (disc * surface_strength + halo * surface_strength * 0.18);
	COLOR = col;
}
