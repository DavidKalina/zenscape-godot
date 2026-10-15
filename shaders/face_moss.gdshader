shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
// The Face's moss (scripts/kit_isle/greybox/face_colossus.gd): a thin shell
// on the colossus's up-faces, built in Blender (art/blender/face_colossus/
// colossus_build.py `Moss`). Its vertex alpha is how deep in a patch a
// vertex lies (0 at the patch's edge); the edge is broken by noise in world
// space and cut (alpha scissor: no sorting), so the patches end raggedly on
// the stone. Its colour: olive and dark moss greens, dry ochre in the
// highs, in solid noise on the rest place; the fine layer fades by pixel
// footprint so it never shimmers far off. Its vertex colour's rgb is a
// shade (the shell's own occlusion).
uniform vec3 moss_dark : source_color = vec3(0.13, 0.16, 0.07);
uniform vec3 moss_lit : source_color = vec3(0.28, 0.33, 0.13);
uniform vec3 moss_dry : source_color = vec3(0.36, 0.32, 0.18);
uniform float ragged = 0.55;

varying vec3 v_world;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
				   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
				   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float foot = length(fwidth(v_world));
	float fine_w = 1.0 - smoothstep(0.04, 0.18, foot);
	float n1 = vnoise(v_world * 0.45);
	float n2 = vnoise(v_world * 1.9 + 7.0);
	float n3 = mix(0.5, vnoise(v_world * 6.5 + 13.0), fine_w);
	vec3 c = mix(moss_dark, moss_lit, smoothstep(0.3, 0.75, n1 * 0.6 + n2 * 0.4));
	c = mix(c, moss_dry, smoothstep(0.62, 0.9, n1 * 0.5 + n2 * 0.5) * 0.55);
	c *= 0.82 + 0.36 * n3;
	ALBEDO = c * COLOR.rgb;
	ROUGHNESS = 1.0;
	ALPHA = COLOR.a + (n2 - 0.5) * ragged + (n3 - 0.5) * ragged * 0.5;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
