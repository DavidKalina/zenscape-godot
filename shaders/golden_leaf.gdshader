shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// A golden leaf piece (scripts/endless/golden_trees.gd): a flat leaf quad that
// tumbles and flutters as it falls, lit by the scene like any surface, its
// edge cut by the texture's alpha. The tumble is read from the particle's own
// custom data (x: its random angle, which seeds it; y, z: age fraction and
// lifetime), so every leaf turns its own way and nothing is stored per leaf.

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap;
uniform float glow = 0.35;

vec3 rot_x(vec3 v, float a) { float c = cos(a); float s = sin(a); return vec3(v.x, c*v.y - s*v.z, s*v.y + c*v.z); }
vec3 rot_y(vec3 v, float a) { float c = cos(a); float s = sin(a); return vec3(c*v.x + s*v.z, v.y, -s*v.x + c*v.z); }
vec3 rot_z(vec3 v, float a) { float c = cos(a); float s = sin(a); return vec3(c*v.x - s*v.y, s*v.x + c*v.y, v.z); }

vec3 tumble(vec3 v, float seed, float age) {
	float r = fract(seed * 7.13);
	v = rot_z(v, seed + age * (1.5 + r * 3.5));
	v = rot_x(v, 1.1 + 0.95 * sin(age * (2.6 + r * 3.0) + seed * 3.0));
	v = rot_y(v, seed * 2.0 + age * (0.8 + r * 1.4));
	return v;
}

void vertex() {
	float seed = INSTANCE_CUSTOM.x;
	float age = INSTANCE_CUSTOM.y * INSTANCE_CUSTOM.z;
	VERTEX = tumble(VERTEX, seed, age);
	NORMAL = tumble(NORMAL, seed, age);
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	ALPHA = t.a * COLOR.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = t.rgb * COLOR.rgb;
	ROUGHNESS = 0.55;
	SPECULAR = 0.5;
	EMISSION = ALBEDO * glow;
	BACKLIGHT = ALBEDO * 0.5;
	if (!FRONT_FACING) NORMAL = -NORMAL;
}
