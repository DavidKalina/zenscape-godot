shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// The wind's far drift (scripts/endless/endless_motes.gd, "far"): flecks of
// blade, petal and seed fluff carried in streamers over the meadows, seen
// from height and far off. Each instance is one fleck, flown here on the GPU
// from where and when it was let go, so the CPU only writes a streamer's
// flecks once, when it is born:
//   origin      where it starts (m); the basis's x length its size (m)
//   COLOR       its colour (linear); alpha under 0.75 a round fleck (petal,
//               fluff), else a sliver (a blade)
//   CUSTOM      x born (s, on `now`), y life (s), z, w its drift (m/s, xz)
// It's a camera-facing quad that never draws under FLECK_PX pixels, so it
// holds as a fleck out to a few hundred metres; it fades in and out by
// shrinking (no blending: opaque, cut out), and gives way within NEAR_GONE..
// NEAR_FULL m of the eye to the near drift's real blades.

uniform float now = 0.0;

const float FLECK_PX = 4.2;
const float NEAR_GONE = 45.0;
const float NEAR_FULL = 85.0;
const float FAR_FULL = 520.0;
const float FAR_GONE = 700.0;
// The bob and swirl riding the wind (m and rad/s), and the fade in/out (s).
const float BOB = 1.6;
const float SWIRL = 1.2;
const float FADE = 1.6;
// A fleck's shape on screen, across and along its way (shares of its size).
const vec2 STREAK_BLADE = vec2(0.6, 2.4);
const vec2 STREAK_ROUND = vec2(0.9, 1.5);

varying vec2 quad;
varying float round_fleck;

void vertex() {
	float born = INSTANCE_CUSTOM.x;
	float life = INSTANCE_CUSTOM.y;
	float t = now - born;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float ph = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853;
	vec3 pos = origin + vec3(INSTANCE_CUSTOM.z, 0.0, INSTANCE_CUSTOM.w) * t;
	pos += vec3(sin(t * SWIRL + ph) * 0.8, sin(t * SWIRL * 1.3 + ph * 1.7) * BOB, cos(t * SWIRL * 0.9 + ph * 2.3) * 0.8);
	float live = step(0.0, t) * step(t, life) * smoothstep(0.0, FADE, t) * (1.0 - smoothstep(life - FADE, life, t));
	vec3 view = (VIEW_MATRIX * vec4(pos, 1.0)).xyz;
	float d = length(view);
	float hand = smoothstep(NEAR_GONE, NEAR_FULL, d) * (1.0 - smoothstep(FAR_FULL, FAR_GONE, d));
	// Pixels per metre at this depth; never under FLECK_PX across.
	float ppm = PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y * 0.5 / max(-view.z, 0.1);
	// (Its own size never shows: within reach it has handed over already.)
	float s = FLECK_PX / ppm * live * hand;
	round_fleck = COLOR.a < 0.75 ? 1.0 : 0.0;
	// Drawn out along its way across the screen (a streak: the wind's own
	// line), a blade more than a petal, swinging a little about it.
	vec3 drift = vec3(INSTANCE_CUSTOM.z, 0.0, INSTANCE_CUSTOM.w);
	vec2 way = (VIEW_MATRIX * vec4(drift, 0.0)).xy;
	way = length(way) > 1e-3 ? normalize(way) : vec2(1.0, 0.0);
	float swing = 0.35 * sin(t * 2.3 + ph);
	way = vec2(way.x * cos(swing) - way.y * sin(swing), way.x * sin(swing) + way.y * cos(swing));
	vec2 stretch = round_fleck > 0.5 ? STREAK_ROUND : STREAK_BLADE;
	vec2 q = vec2(-way.y, way.x) * VERTEX.x * stretch.x + way * VERTEX.y * stretch.y;
	quad = VERTEX.xy * 2.0;
	// Back to the instance's own space (Godot moves it by MODEL_MATRIX after).
	vec3 world = pos + (INV_VIEW_MATRIX[0].xyz * q.x + INV_VIEW_MATRIX[1].xyz * q.y) * s;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

void fragment() {
	// A round fleck or a sliver's ellipse (the quad is stretched already).
	if (dot(quad, quad) > 1.0) discard;
	ALBEDO = COLOR.rgb;
}
