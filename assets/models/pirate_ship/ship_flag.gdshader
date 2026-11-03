shader_type spatial;
// Written by art/blender/ship/ship_build.py. Lit as the world is: no ambient,
// the sky's hemisphere added as emission (shaders/folk_surface.gdshaderinc),
// so a stock material would go black out of the sun.
render_mode diffuse_lambert, cull_disabled;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float fill = 1.6;
uniform float rim = 0.3;
// A flag: a flat sheet off its hoist (ship_build.py `flag_geo`), streamed here down
// the air on it, the air the sails take (ship_cloth.gdshader): the true wind less her
// way. The hoist stays on its mast or staff (local y); the fly turns about it, hangs
// as the air drops, and ripples out along it.
//   VERTEX       x along the fly from the hoist, y up the hoist, as built
//   COLOR.r      the fly's length / FLAG_SIZE; COLOR.g a seed
//   ship_way, ship_slack: as the sails' (scripts/endless/ship_sails.gd)
global uniform float zs_wind_strength;
global uniform vec2 zs_wind_direction;
global uniform float zs_gust_distance;
instance uniform vec4 ship_way;
instance uniform float ship_slack;
uniform float wind_ms = 20.0;
uniform float gust_swing = 0.42;
// The air (m/s) that has a flag two thirds out, and how far (rad) below level it hangs in none.
uniform float flies_at = 4.5;
uniform float droop = 1.0;
// The ripple: its reach at the fly's end (a share of the fly), waves along the fly, their pace.
uniform float wave = 0.085;
uniform float waves = 1.5;
uniform float pace = 0.8;
const float SIZE = 64.0;

float sail_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float sail_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(sail_hash(i), sail_hash(i + vec2(1.0, 0.0)), f.x),
		mix(sail_hash(i + vec2(0.0, 1.0)), sail_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The land's gust field (zs_gust_field_at) at a sail's size: the same air, the
// same run downwind, in parcels a sail can feel. -1 a lull, 1 a gust.
float sail_gust(vec2 p) {
	vec2 dir = zs_wind_direction;
	vec2 q = p - dir * zs_gust_distance;
	vec2 e = vec2(dot(q, dir), dot(q, vec2(-dir.y, dir.x))) * vec2(0.016, 0.028);
	float field = sail_noise(e) * 0.62 + sail_noise(e * 2.3 + vec2(3.7, 9.1)) * 0.38;
	return smoothstep(0.28, 0.72, field) * 2.0 - 1.0;
}

vec3 flag_at(float x, float y, float len, vec3 fly, vec3 side, float out_of, float clock, float seed) {
	float f = clamp(x / len, 0.0, 1.0);
	float q = (f * waves - y / len * 0.4) * 6.28318 - clock + seed * 6.28318;
	float amp = wave * len * pow(f, 1.2) * mix(1.7, 1.0, out_of);
	float ripple = sin(q) + 0.3 * sin(2.3 * q + 1.7);
	float lift = 0.3 * sin(0.7 * q + 2.0) * amp;
	return vec3(0.0, y + lift, 0.0) + fly * x + side * ripple * amp;
}

void vertex() {
	float len = max(COLOR.r * SIZE, 0.1);
	float seed = COLOR.g;
	vec2 air = zs_wind_direction * zs_wind_strength * wind_ms * (1.0 + gust_swing * sail_gust(MODEL_MATRIX[3].xz)) - ship_way.xy * ship_way.z;
	float speed = length(air);
	// The air in the flag's own frame, across its hoist; none, and it keeps its built line.
	vec3 w = transpose(mat3(MODEL_MATRIX)) * vec3(air.x, 0.0, air.y);
	vec2 d = w.xz;
	float dl = length(d);
	d = dl > 0.05 ? d / dl : vec2(1.0, 0.0);
	float out_of = (1.0 - exp(-pow(speed / flies_at, 1.5))) * (1.0 - clamp(ship_slack, 0.0, 1.0));
	float a = droop * (1.0 - out_of);
	vec3 fly = vec3(d.x, 0.0, d.y) * cos(a) - vec3(0.0, sin(a), 0.0);
	vec3 side = vec3(-d.y, 0.0, d.x);
	float clock = zs_gust_distance * 2.0 * pace;
	vec3 p = flag_at(VERTEX.x, VERTEX.y, len, fly, side, out_of, clock, seed);
	float dx = len * 0.02;
	vec3 px = flag_at(VERTEX.x + dx, VERTEX.y, len, fly, side, out_of, clock, seed) - p;
	vec3 py = flag_at(VERTEX.x, VERTEX.y + 0.2, len, fly, side, out_of, clock, seed) - p;
	VERTEX = p;
	NORMAL = normalize(cross(px, py));
}
uniform float through = 0.4;
void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec3 base = t.rgb;
	ALBEDO = base;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	BACKLIGHT = base * through;
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = base * hemi * fill + base * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
