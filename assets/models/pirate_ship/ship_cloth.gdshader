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
// A sail: a flat sheet (ship_build.py `sail_geo`) shaped here and nowhere else,
// from the wind every ship sees and her own heading and speed. Pinned at the
// yard, it fills forward; it never bulges aft, it goes slack or flogs instead.
//   COLOR.rgb    the sheet's height, head width and foot width / SAIL_SIZE
//   COLOR.a      1 + skew: the foot's middle off the head's, a share of its half width (the jib)
//   ship_way     her bow (x, z), her speed (m/s), her turn (rad/s): per ship, scripts/endless/ship_sails.gd
//   ship_slack   1 in a sink: no wind in her, the cloth hangs where gravity has it
global uniform float zs_wind_strength;
global uniform vec2 zs_wind_direction;
global uniform float zs_gust_distance;
instance uniform vec4 ship_way;
instance uniform float ship_slack;
// The true wind (m/s) at zs_wind_strength 1, and how much of it a gust adds or takes.
uniform float wind_ms = 20.0;
uniform float gust_swing = 0.42;
// Her speed's share of the air on the cloth.
uniform float ship_share = 1.0;
// How far (as cos of the angle from the bow) the air must come aft to start filling, and to fill.
uniform float draws_from = -1.0;
uniform float draws_full = -0.55;
// The air (m/s) that fills a sail about two thirds.
uniform float fills_at = 11.0;
// The belly at no air and at full, as a share of her height.
uniform float belly_least = 0.06;
uniform float belly_full = 0.4;
// The farthest aft the cloth goes behind its yard (m).
const float AFT = 0.5;
varying float v_form;
const float SIZE = 64.0;

struct Cloth {
	float h;
	float w;
	float wb;
	float seed;
	float fill;
	float depth;
	float lean;
	float flog;
	float taut;
	float air;
	float clock;
	float slack;
	float skew;
	vec3 hang;
};

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

// The cloth at s (-1..1 across), t (0 yard .. 1 foot).
vec3 sail_at(float s, float t, Cloth c) {
	float s2 = s * s;
	float hw = mix(c.w, c.wb, t) * 0.5;
	// The deepest of the belly slides to leeward; the leeches keep theirs.
	float sh = s - c.lean * 0.45 * (1.0 - s2);
	float spine = pow(sin(1.5708 * min(t * 1.12, 1.0)), 0.75) * mix(1.0, 0.42, smoothstep(0.62, 1.0, t));
	float leech = 0.92 * pow(sin(3.14159 * min(t * 1.04, 1.0)), 0.9);
	float breathe = 1.0 + 0.07 * sin(c.clock * 0.31 + c.seed * 6.3 - t * 2.6);
	float belly = c.depth * breathe * (spine * (1.0 - sh * sh) + leech * sh * sh);
	// The cloth the belly takes comes off its width and height; the sheets draw
	// the foot in and the foot arches between them.
	float x = s * hw * (1.0 - c.fill * (0.2 * t * t + 0.03 * sin(3.14159 * t))) + c.skew * c.w * 0.5 * t;
	x += c.lean * c.fill * 0.05 * hw * sin(3.14159 * t);
	float take = c.depth / c.h;
	float y = -c.h * t * (1.0 - 0.9 * take * take) + c.h * 0.1 * c.fill * (1.0 - s2) * t * t * t;
	// Slack, it hangs in long folds.
	float along = s * hw;
	float pleat = (0.7 * sin(along * 0.62 + c.seed * 9.0) + 0.3 * sin(along * 1.37 - c.seed * 5.0));
	pleat *= (0.12 + 0.028 * c.h) * (1.0 - c.taut) * smoothstep(0.0, 0.5, t);
	// Flogging: waves run down and across it, biggest at the leeches and the foot.
	float q = (c.h * t + along * 0.5) * 0.5 - c.clock * 1.7 + c.seed * 11.0;
	float flog = sin(q + 0.7 * sin(q)) + 0.3 * sin(1.7 * q + s * 2.5);
	flog *= c.flog * c.h * 0.06 * (0.18 + 0.82 * t) * (0.4 + 0.6 * s2) * smoothstep(0.0, 0.14, t);
	// The leech and foot never quite stop: quick ripples run out along them,
	// flattest when the cloth is taut.
	float edge = max(smoothstep(0.62, 1.0, abs(s)) * smoothstep(0.0, 0.35, t), smoothstep(0.7, 1.0, t));
	float rq = (abs(s) * hw + c.h * t) * 0.85 - c.clock * 2.2 + c.seed * 20.0;
	float ripple = (sin(rq) + 0.35 * sin(1.83 * rq + s * 4.0)) * edge * (0.09 + 0.02 * min(c.air, 16.0)) * (1.35 - c.taut);
	float out_of = max(belly + pleat + flog + ripple, -AFT * smoothstep(0.0, 0.2, t));
	vec3 p = vec3(x, y, -out_of);
	// In a sink it swings to the true down, about the yard; never aft through the mast.
	vec3 swing = (c.hang - vec3(0.0, -1.0, 0.0)) * vec3(1.0, 1.0, c.hang.z > 0.0 ? 0.15 : 1.0);
	return p + swing * c.h * t * c.slack;
}

void vertex() {
	Cloth c;
	c.h = COLOR.r * SIZE;
	c.w = COLOR.g * SIZE;
	c.wb = COLOR.b * SIZE;
	c.seed = fract((c.h * 3.1 + c.w * 0.77 + c.wb * 0.31) * 0.61803);
	c.skew = COLOR.a - 1.0;
	float t = clamp(-VERTEX.y / c.h, 0.0, 1.0);
	float s = clamp((VERTEX.x - c.skew * c.w * 0.5 * t) / max(mix(c.w, c.wb, t) * 0.5, 0.01), -1.0, 1.0);
	mat3 m = mat3(MODEL_MATRIX);
	vec3 side = normalize(m[0]);
	float gust = sail_gust(MODEL_MATRIX[3].xz);
	// The air on the cloth: the true wind less her own way through it.
	vec2 air = zs_wind_direction * zs_wind_strength * wind_ms * (1.0 + gust_swing * gust) - ship_way.xy * ship_way.z * ship_share;
	float speed = length(air);
	vec2 way = air / max(speed, 0.01);
	float draw = smoothstep(draws_from, draws_full, dot(way, ship_way.xy));
	float power = 1.0 - exp(-pow(speed / fills_at, 1.5));
	c.slack = clamp(ship_slack, 0.0, 1.0);
	c.fill = draw * power * (1.0 - c.slack);
	c.taut = c.fill * (0.72 + 0.28 * gust);
	c.depth = c.h * mix(belly_least, belly_full * (1.0 + 0.18 * gust), c.fill);
	c.lean = clamp((way.x * side.x + way.y * side.z) * 1.1 - ship_way.w * 7.0, -1.0, 1.0) * draw;
	c.flog = (1.0 - draw) * min(speed / 14.0, 1.0) * (1.0 - c.slack * 0.75);
	c.air = speed;
	c.clock = zs_gust_distance * 2.0;
	c.hang = normalize(transpose(m) * vec3(0.0, -1.0, 0.0));
	float ds = 0.04;
	float dt = 0.03;
	vec3 p = sail_at(s, t, c);
	vec3 pu = (s < 1.0 - ds) ? sail_at(s + ds, t, c) - p : p - sail_at(s - ds, t, c);
	vec3 pv = (t < 1.0 - dt) ? sail_at(s, t + dt, c) - p : p - sail_at(s, t - dt, c);
	VERTEX = vec3(p.x, p.y, VERTEX.z + p.z);
	NORMAL = normalize(cross(pu, pv));
	// How far the cloth has turned from its flat: the belly's form, whatever the light.
	v_form = 1.0 - abs(NORMAL.z);
}
uniform float through = 0.4;
uniform float form = 0.75;
void fragment() {
	vec4 t = texture(albedo_tex, UV);
	vec3 base = t.rgb;
	ALBEDO = base;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	BACKLIGHT = base * through;
	ALBEDO *= 1.0 - v_form * form;
	base *= 1.0 - v_form * form;
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = base * hemi * fill + base * zs_hemi_sky * zs_hemi_energy * edge * rim;
}
