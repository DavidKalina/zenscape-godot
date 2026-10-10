// The lodestone's wind swirl (scripts/lodestone.gd): where a mote of the
// current stands, in the lodestone's own frame (metres, its middle at the
// origin, up +Y), `back` seconds ago. Shared by its painted strokes
// (shaders/lodestone_ribbon.gdshader) and its motes, petals, glints and
// wisps (shaders/lodestone_motes.gdshader), so a stroke's head is where a
// mote rides and its tail is where the mote was.
//
// At rest the current turns round the stone as the water ball's vortex
// turns round its axis (shaders/water_ball.gdshader, scripts/water_ball.gd
// `_swim`): each mote on its own orbit at its own pace, the inner ones
// quicker, weaving up and down and breathing in and out. Pointing
// (`stream` 0..1, toward `stream_dir`), the swirl lets go of the stone and
// pours off it toward the place it knows: each mote is born at the stone,
// spirals round the stream's axis as it is carried out along it, its
// orbit narrowing, and is born again, so the swirl reads as a comet's
// tail drawn out toward the target.
#ifndef ZS_LODESTONE_VORTEX
#define ZS_LODESTONE_VORTEX

// The swirl's turned angle (radians, integrated by the script so a change
// of pace never jumps) and its pace now (rad/s); the clock (s).
uniform float swirl = 0.0;
uniform float spin = 0.6;
uniform float clock = 0.0;
// The swirl's size: its orbits' widest radius and its half height (m).
uniform float swirl_radius = 0.24;
uniform float swirl_height = 0.14;
// How much it hums (0 still, 1 the pilot beside it): the orbits tighten a
// little and the weave quickens.
uniform float hum = 0.0;
// Pointing: how far (0..1), which way (the lodestone's frame), how far the
// stream reaches (m) and how long a mote takes to ride it (s).
uniform float stream = 0.0;
uniform vec3 stream_dir = vec3(0.0, 0.0, -1.0);
uniform float stream_length = 1.2;
uniform float stream_life = 2.6;
// Carried on a moving plane, the stream is swept back by the air past it
// as it rides out (m at the far end, the lodestone's frame): it bends
// behind, where the chase camera sees it, whatever way it points.
uniform vec3 stream_drift = vec3(0.0);

// A mote's draws: `seed` 0..1, `orbit` 0..1 (inner to outer), `level`
// -1..1 (low to high).
vec3 lv_rest(float seed, float orbit, float level, float back) {
	float pace = mix(1.45, 0.75, orbit) * (1.0 + 0.25 * hum);
	float t = clock - back;
	float angle = seed * 6.2831853 + (swirl - back * spin) * pace;
	float weave = sin(t * (0.55 + seed * 0.4) + seed * 23.0) * 0.28 + sin(t * 1.3 + seed * 7.0) * 0.08;
	float y = clamp(level + weave, -1.15, 1.15) * swirl_height;
	// Wider round the middle, drawn in toward the top and the foot (a
	// lens of air round the stone), breathing in and out.
	float r = swirl_radius * mix(0.45, 1.0, orbit) * (1.0 - 0.18 * hum);
	r *= sqrt(max(1.0 - 0.45 * pow(y / max(swirl_height, 1e-4), 2.0), 0.2));
	r *= 1.0 + 0.1 * sin(t * 0.7 + seed * 11.0);
	return vec3(cos(angle) * r, y, sin(angle) * r);
}

// The stream's frame: its way and two across it.
mat3 lv_stream_frame() {
	vec3 d = normalize(stream_dir + vec3(1e-4, 0.0, 0.0));
	vec3 side = abs(d.y) < 0.95 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 a = normalize(cross(side, d));
	vec3 b = cross(d, a);
	return mat3(a, b, d);
}

// Where along its ride a mote is (0 at the stone, 1 at the far end), the
// tail clamped at its birth: `head` the mote's own share now.
float lv_stream_share(float seed, float back) {
	float head = fract(clock / stream_life + seed * 3.7);
	return max(head - back / stream_life, 0.0);
}

vec3 lv_streaming(float seed, float orbit, float level, float back) {
	float s = lv_stream_share(seed, back);
	mat3 f = lv_stream_frame();
	// Round the stream's axis as it rides: two and a half turns over the ride,
	// so the stroke's tail draws a helix back to the stone.
	float angle = seed * 6.2831853 + (swirl - back * spin) * mix(1.4, 0.9, orbit) + s * 6.2831853 * 2.5;
	// Born round the stone, the orbit narrowing as it is carried out.
	float r = swirl_radius * mix(0.5, 1.0, orbit) * mix(1.0, 0.35, pow(s, 0.8));
	float along = stream_length * pow(s, 1.25) + level * swirl_height * 0.4 * (1.0 - s);
	return f[2] * along + (f[0] * cos(angle) + f[1] * sin(angle)) * r + stream_drift * s * s;
}

vec3 lv_path(float seed, float orbit, float level, float back) {
	vec3 rest = lv_rest(seed, orbit, level, back);
	if (stream <= 0.001) return rest;
	return mix(rest, lv_streaming(seed, orbit, level, back), smoothstep(0.0, 1.0, stream));
}

// How much of a mote shows at its place in the stream: born and gone soft.
float lv_stream_fade(float seed) {
	float head = fract(clock / stream_life + seed * 3.7);
	float fade = smoothstep(0.0, 0.12, head) * (1.0 - smoothstep(0.7, 1.0, head));
	return mix(1.0, fade, smoothstep(0.0, 1.0, stream));
}

float lv_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

#endif
