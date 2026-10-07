shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// The sky's currents (scripts/sky_currents.gd) drawn as the plate's breeze
// ribbons are (shaders/breeze_ribbon.gdshader, scripts/breeze_ribbons.gd):
// each stroke is the trace of a mote of air carried down a jet stream or
// up a thermal, painted with the same brush (shaders/
// breeze_ribbon_paint.gdshaderinc). Down a jet the mote rides downstream,
// meandering round the stream's core and swelling and sinking, and now and
// then the air curls it through an eddy: a loop up and over, a flat swirl,
// or a helix between. Up a thermal it rises spiralling round the column.
//
// The mote's path is a function of time, so the tail is simply where the
// head was: the vertex at `i` of the strip stands where the mote stood
// that share of the tail ago. The stroke travels with the air and is never
// a mark stamped in place. Each instance lives a stroke after another: born
// somewhere along its current (spread evenly among the current's strokes),
// it grows its tail, rides, fades and is born again further on.
//
// The paths come in `paths` (scripts/sky_currents.gd `_texture`): one row
// per current, `samples` points (xyz, node-local), then (length, speed,
// radius, swirl) and (closed, kind). The mesh is a strip, `x` 0 tail..1
// head along, `y` 0..1 across. Instance custom data: row (0..1), the
// stroke's share of its current's strokes (0..1, evenly spread), a seed,
// how many strokes share the current (/ 64).
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/breeze_ribbon_paint.gdshaderinc"

uniform sampler2D paths : filter_nearest;
uniform int samples = 64;
// The strokes' light (the breeze ribbons' 2), their opacity, and their
// width and the run of their tails, as shares of the design.
uniform float glow = 2.0;
uniform float opacity = 0.8;
uniform float width_scale = 1.0;
uniform float tail_scale = 1.0;
// Drawn at least JR_MIN_PIXELS wide (its paint thinned to match) and at
// most JR_MAX_PIXELS, so near ones never tape (far ones broaden, FAR_BROADEN).
const float JR_MIN_PIXELS = 2.0;
const float JR_MAX_PIXELS = 26.0;
// A jet's stroke: true width (m), tail (s), a stroke's life (s), how far it
// meanders off the core (share of the stream's radius) and how fast (1/s),
// how far it swells and sinks (m) over how long (s).
const vec2 JET_WIDTH = vec2(1.1, 2.2);
const vec2 JET_TAIL = vec2(2.4, 3.6);
const vec2 JET_LIFE = vec2(13.0, 20.0);
const float JET_MEANDER = 0.75;
const float JET_MEANDER_PACE = 0.2;
const vec2 JET_SWELL = vec2(3.5, 4.8);
// Eddies down a jet: the chance a stroke's life has one, how long the curl
// takes (s), and how wide it turns, as a share of the run it would make in
// that time (over 1/(3 pi) it closes into a loop).
const float EDDY_CHANCE = 0.7;
const vec2 EDDY_TIME = vec2(2.6, 3.6);
const vec2 EDDY_WIDE = vec2(0.16, 0.22);
// A thermal's stroke: true width (m), tail (s), life (s), how far round the
// column it turns (share of the column's radius) and how fast (rad/s).
const vec2 THERMAL_WIDTH = vec2(0.7, 1.3);
const vec2 THERMAL_TAIL = vec2(2.2, 3.2);
const vec2 THERMAL_LIFE = vec2(8.0, 12.0);
const float THERMAL_ROUND = 0.65;
const float THERMAL_TURN = 1.5;
// Fades: born and gone over these seconds; gone right at the eye and far off.
const float BORN = 1.4;
const float GONE = 2.4;
const vec2 NEAR = vec2(4.0, 20.0);
const vec2 FAR = vec2(1200.0, 1900.0);
// Metres off over which a stroke grows by its own width again (and pales).
const float FAR_BROADEN = 220.0;
// Jet strokes are ten times a breeze ribbon's: the brush's pressure and
// grain run at a tenth of a metre.
const float BRUSH_SCALE = 0.1;

varying float jr_u;
varying float jr_along;
varying float jr_cover;
varying float jr_facing;
varying float jr_sun;
varying float jr_seed;
varying float jr_alpha;
varying float jr_v;

float jr_hash(float n) {
	return fract(sin(n * 12.9898 + 4.1414) * 43758.5453);
}

// Smooth value noise in time, -1..1.
float jr_wave(float t, float seed) {
	float i = floor(t);
	float f = fract(t);
	f = f * f * (3.0 - 2.0 * f);
	return mix(jr_hash(i + seed * 37.0), jr_hash(i + 1.0 + seed * 37.0), f) * 2.0 - 1.0;
}

vec3 jr_point(int row, float u, bool closed) {
	float x = closed ? fract(u) * float(samples) : clamp(u, 0.0, 1.0) * float(samples - 1);
	int i0 = int(floor(x));
	int i1 = closed ? (i0 + 1) % samples : min(i0 + 1, samples - 1);
	return mix(texelFetch(paths, ivec2(i0 % samples, row), 0).xyz, texelFetch(paths, ivec2(i1, row), 0).xyz, fract(x));
}

struct Stroke {
	int row;
	bool closed;
	bool thermal;
	float len;
	float radius;
	float pace;
	float s0;
	float seed;
	// An eddy: when it starts (s of life, negative for none), how long,
	// how wide (m), its plane's tilt (0 a loop up and over, 1 flat) and
	// which way it turns.
	float eddy_at;
	float eddy_span;
	float eddy_wide;
	float eddy_flat;
	float eddy_spin;
};

// Where the stroke's mote is `t` seconds into its life (node-local).
vec3 jr_mote(Stroke s, float t) {
	float sm = s.s0 + s.pace * t;
	float u = sm / s.len;
	vec3 here = jr_point(s.row, u, s.closed);
	vec3 ahead = jr_point(s.row, u + 2.0 / s.len, s.closed);
	vec3 way = ahead - here;
	way = length(way) > 1e-4 ? normalize(way) : vec3(0.0, 0.0, -1.0);
	vec3 ref = abs(way.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 side = normalize(cross(way, ref));
	vec3 up = cross(side, way);
	if (s.thermal) {
		// Round the column as it rises, its reach easing in and out.
		float reach = s.radius * THERMAL_ROUND * (0.75 + 0.25 * jr_wave(t * 0.4, s.seed));
		float a = s.seed * 6.2831 + t * THERMAL_TURN * (s.eddy_spin);
		return here + (side * cos(a) + up * sin(a)) * reach;
	}
	// Meandering round the core, swelling and sinking.
	vec2 off = vec2(jr_wave(t * JET_MEANDER_PACE + 3.0, s.seed), jr_wave(t * JET_MEANDER_PACE + 11.0, s.seed + 0.5));
	vec3 p = here + (side * off.x + up * off.y * 0.6) * s.radius * JET_MEANDER;
	p += up * JET_SWELL.x * sin(6.2831 * t / JET_SWELL.y + s.seed * 6.2831);
	// Through an eddy: the mote's way turned once round, eased in and out,
	// so it leaves the curl as it came in.
	if (s.eddy_at >= 0.0) {
		float k = clamp((t - s.eddy_at) / s.eddy_span, 0.0, 1.0);
		float phi = 6.2831 * smoothstep(0.0, 1.0, k);
		vec3 lift = normalize(mix(up, side * s.eddy_spin, s.eddy_flat));
		p += (way * sin(phi) + lift * (1.0 - cos(phi))) * s.eddy_wide;
	}
	return p;
}

void vertex() {
	vec4 seed = INSTANCE_CUSTOM;
	int rows = textureSize(paths, 0).y;
	Stroke s;
	s.row = int(seed.x * float(rows));
	vec4 info = texelFetch(paths, ivec2(samples, s.row), 0);
	vec4 flags = texelFetch(paths, ivec2(samples + 1, s.row), 0);
	s.closed = flags.x > 0.5;
	s.thermal = flags.y > 0.5;
	s.len = max(info.x, 1.0);
	s.radius = info.z;
	float h0 = seed.z * 91.7;
	float life = s.thermal ? mix(THERMAL_LIFE.x, THERMAL_LIFE.y, jr_hash(h0)) : mix(JET_LIFE.x, JET_LIFE.y, jr_hash(h0));
	// Which of its lives the stroke is in, and how far into it.
	float clock = zs_motion_time / life + jr_hash(h0 + 1.0);
	float cycle = floor(clock);
	float age = fract(clock) * life;
	float h = h0 + cycle * 7.31;
	s.seed = jr_hash(h + 2.0);
	s.pace = info.y * (s.thermal ? 0.85 + 0.3 * jr_hash(h + 3.0) : 0.8 + 0.35 * jr_hash(h + 3.0));
	// Born spread evenly along the current among its strokes, then on
	// somewhere new each life. A thermal's strokes are born low in it.
	float share = fract(seed.y + jr_hash(h + 4.0) / max(seed.w * 64.0, 1.0));
	s.s0 = s.closed ? share * s.len : share * (s.thermal ? 0.55 : 0.8) * s.len;
	// A thermal's air turns all one way round it.
	s.eddy_spin = jr_hash(s.thermal ? float(s.row) * 3.7 : h + 5.0) < 0.5 ? -1.0 : 1.0;
	s.eddy_at = -1.0;
	if (!s.thermal && jr_hash(h + 6.0) < EDDY_CHANCE) {
		s.eddy_span = mix(EDDY_TIME.x, EDDY_TIME.y, jr_hash(h + 7.0));
		s.eddy_at = mix(BORN + 2.5, life - GONE - s.eddy_span, jr_hash(h + 8.0));
		s.eddy_wide = s.pace * s.eddy_span * mix(EDDY_WIDE.x, EDDY_WIDE.y, jr_hash(h + 9.0));
		float tilt = jr_hash(h + 10.0);
		s.eddy_flat = tilt * tilt;
	}
	float tail = (s.thermal ? mix(THERMAL_TAIL.x, THERMAL_TAIL.y, jr_hash(h + 11.0)) : mix(JET_TAIL.x, JET_TAIL.y, jr_hash(h + 11.0))) * tail_scale;
	// The tail grows from the stroke's birth.
	float grown = min(tail, age);
	jr_u = VERTEX.x;
	jr_v = (VERTEX.y - 0.5) * 2.0;
	float t = age - grown * (1.0 - jr_u);
	float dt = 0.03;
	vec3 local = jr_mote(s, t);
	vec3 world = (MODEL_MATRIX * vec4(local, 1.0)).xyz;
	vec3 way = (MODEL_MATRIX * vec4(jr_mote(s, t + dt) - jr_mote(s, max(t - dt, 0.0)), 0.0)).xyz;
	way = length(way) > 1e-5 ? normalize(way) : vec3(0.0, 1.0, 0.0);
	jr_seed = s.seed * 100.0;
	jr_along = s.pace * grown * (1.0 - jr_u) * BRUSH_SCALE;
	float width = (s.thermal ? mix(THERMAL_WIDTH.x, THERMAL_WIDTH.y, jr_hash(h + 12.0)) : mix(JET_WIDTH.x, JET_WIDTH.y, jr_hash(h + 12.0))) * width_scale;
	float taper = rb_taper_at(jr_u);
	float press = rb_pressure_at(jr_along, jr_seed);
	vec3 to_cam = CAMERA_POSITION_WORLD - world;
	float dist = length(to_cam);
	to_cam /= max(dist, 0.001);
	vec3 across = cross(way, to_cam);
	jr_facing = length(across);
	across = jr_facing > 0.001 ? across / jr_facing : vec3(0.0, 1.0, 0.0);
	// Metres per screen pixel here, measured: a metre across the stroke,
	// projected to the screen.
	vec4 c0 = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	vec4 c1 = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world + across, 1.0);
	float span = length((c1.xy / c1.w - c0.xy / c0.w) * VIEWPORT_SIZE * 0.5);
	float pixel = 1.0 / max(span, 0.001);
	// Far off a stroke broadens and pales, a soft wash rather than a
	// scratch of a hairline.
	float farness = dist / FAR_BROADEN;
	width *= 1.0 + farness;
	float true_w = min(width * taper * press, pixel * JR_MAX_PIXELS);
	float drawn = max(true_w, pixel * JR_MIN_PIXELS * step(0.0005, taper));
	jr_cover = drawn > 0.0 ? clamp(true_w / drawn, 0.0, 1.0) : 0.0;
	world += across * (VERTEX.y - 0.5) * drawn;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	// Born and gone over its life, in and out at an open current's ends,
	// gone right at the eye and far away.
	float u_here = (s.s0 + s.pace * t) / s.len;
	float ends = s.closed ? 1.0 : smoothstep(0.0, 0.06, u_here) * (1.0 - smoothstep(0.86, 1.0, u_here));
	float lived = smoothstep(0.0, BORN, age) * (1.0 - smoothstep(life - GONE, life, age));
	jr_alpha = opacity * ends * lived * smoothstep(NEAR.x, NEAR.y, dist) * (1.0 - smoothstep(FAR.x, FAR.y, dist)) / (1.0 + 0.6 * farness);
	jr_sun = max(dot(-to_cam, normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0))), 0.0);
}

void fragment() {
	float v = jr_v;
	float scatter = pow(jr_sun, 5.0);
	ALBEDO = vec3(0.95, 0.97, 1.0) * rb_paint_light(scatter) * glow;
	ALPHA = clamp(jr_alpha * rb_paint_alpha(jr_u, jr_along, v, jr_seed, jr_facing, jr_cover, scatter), 0.0, 1.0);
}
