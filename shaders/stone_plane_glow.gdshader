shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The stone plane's seams and gaps (scripts/stone_plane_figure.gd): a carved
// channel of dark gold stone that glows with the lodestone's pull. `energy`
// is the channel's level (the seam compass), 0 when no stone is seated. The
// sync pulse runs nose to tail: a band of light at `pulse_front` along the
// plane's length (model z, the nose at -z).
uniform vec3 base : source_color = vec3(0.42, 0.35, 0.23);
uniform vec3 glow : source_color = vec3(1.0, 0.847, 0.588);
uniform float energy = 0.0;
uniform float pulse_front = -10.0;
uniform float pulse_amp = 0.0;
varying float along;

void vertex() {
	along = VERTEX.z;
}

void fragment() {
	float d = (along - pulse_front) / 0.14;
	float pulse = pulse_amp * exp(-d * d);
	ALBEDO = base;
	ROUGHNESS = 0.5;
	SPECULAR = 0.3;
	EMISSION = glow * (energy + pulse * 5.0);
}
