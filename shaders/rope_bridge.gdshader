// A rope bridge alive (scripts/rope_bridge.gd): the static faceted mesh
// (scripts/footbridge.gd `build_mesh`) moved, vertex by vertex, by how far
// its ropes stand off their sag pose (scripts/rope_bridge_sim.gd `pack`).
// Each vertex finds its place along the span (t) and across it from where
// it stands in the mesh, against the ends `end_a`, `end_b` and the sag
// `bow`: at deck height it moves with the foot ropes (left and right blended
// across the deck, so a plank rolls when one side sinks), high up with the
// hand ropes, the cords between stretching. The ends never move. While the
// deck moves fast its planks rattle a little each on its own beat. Lit as the
// footbridge's own material is: its vertex colours, rough.
shader_type spatial;
render_mode cull_disabled;

const int SAMPLES = 33;

uniform vec3 end_a = vec3(0.0);
uniform vec3 end_b = vec3(1.0, 0.0, 0.0);
uniform float bow = 0.0;
uniform float width = 0.74;
uniform int nodes = 10;
uniform float planks = 30.0;
uniform float rattle = 0.0;
uniform vec4 deck[SAMPLES];
uniform vec4 hand[SAMPLES];

void vertex() {
	vec2 flat_way = end_b.xz - end_a.xz;
	float span = max(length(flat_way), 0.01);
	vec2 way = flat_way / span;
	vec2 across = vec2(-way.y, way.x);
	vec2 rel = VERTEX.xz - end_a.xz;
	float t = clamp(dot(rel, way) / span, 0.0, 1.0);
	float side = dot(rel, across);
	float s = sin(3.14159265 * t);
	float rest = mix(end_a.y, end_b.y, t) + bow * s * s;
	float h = VERTEX.y - rest;
	float at = t * float(nodes);
	int i = min(int(floor(at)), nodes - 1);
	float f = at - float(i);
	vec4 d = mix(deck[i], deck[i + 1], f);
	vec4 r = mix(hand[i], hand[i + 1], f);
	float right = clamp(0.5 + side / width, 0.0, 1.0);
	vec2 low = vec2(mix(d.x, d.y, right), d.z);
	vec2 high = side < 0.0 ? vec2(r.x, r.z) : vec2(r.y, r.w);
	vec2 move = mix(low, high, smoothstep(0.3, 0.65, h));
	// The planks' rattle, each its own beat, only at deck height.
	float plank = floor(t * planks);
	float beat = fract(sin(plank * 12.9898 + 1.7) * 43758.5453);
	float on_deck = 1.0 - smoothstep(0.03, 0.08, abs(h + 0.02));
	move.x += rattle * on_deck * sin(TIME * (26.0 + beat * 9.0) + beat * 6.2832);
	VERTEX += vec3(across.x * move.y, move.x, across.y * move.y);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
}
