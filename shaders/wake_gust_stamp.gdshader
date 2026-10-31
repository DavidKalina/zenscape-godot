shader_type canvas_item;
// One stretch of the gust the burrower drives through a wood, into the trees'
// own map (scripts/endless/grass_react.gd `gust_strip`, read by shaders/
// tree_wind.gdshaderinc zs_gust_at). Only he writes this map, so nothing here
// can touch the prop's wash or the wind's bands, and no grass reads it.
//   rg  the lean's way and size (world x, z; 1 full), signed: on the spring
//       back it goes past upright, toward him
//   b   how loose the crown is: 0 held over, up once it is let go, dying away
//       (the tree sways round its lean by this, at its own pace)
// A strip's stretches overlap as a triangle along his way, so they sum to 1 on
// a straight run. A disc (way 0) goes straight out from its centre.
// The shape: arrives fast and holds like the wind's front, then as he passes
// the bent tree springs back, past upright and back again, dying away.
// Per instance:
//   COLOR  = (centre x, z, his unit way x, z; 0, 0 a disc)
//   CUSTOM = (half length m along his way, reach m, born s, strength)
// Stamps sit in the ring for life, so only `now` and `map_min` change each frame
// and nothing is rewritten per stamp.
render_mode blend_add, unshaded, skip_vertex_transform;

// Keep in step with grass_react.gd WAKE_*.
const float FRONT = 30.0; // m/s out from his line: the ripple.
const float RISE = 0.7;
const float HOLD = 0.5;
const float SPRING_HZ = 1.2; // The swings after the release: well under a shake.
const float SPRING_TAU = 0.85; // s, each swing about 0.6 of the last.
const float GONE = 6.0; // s after the hold, nothing left.
const float LOOSE_RISE = 1.4;
const float LOOSE_TAU = 1.6;
const float WAY_ON_LINE = 1.0; // A tree right on his line goes along his way.

uniform vec2 map_min = vec2(0.0);
uniform float px_per_m = 1.0;
uniform float now = 0.0;

varying vec4 centre_way;
varying vec4 shape;
varying vec2 metres;

void vertex() {
	centre_way = COLOR;
	shape = INSTANCE_CUSTOM;
	float age = now - shape.z;
	vec2 size = vec2(shape.x > 0.0 ? shape.x : shape.y, shape.y);
	bool alive = shape.w > 0.0 && age >= 0.0 && age < shape.y / FRONT + RISE + HOLD + GONE;
	vec2 way = dot(COLOR.zw, COLOR.zw) > 0.25 ? COLOR.zw : vec2(1.0, 0.0);
	vec2 across = vec2(-way.y, way.x);
	metres = VERTEX * 2.0 * size;
	vec2 world = COLOR.xy + way * metres.x + across * metres.y;
	VERTEX = alive ? (world - map_min) * px_per_m : vec2(-100.0);
	COLOR = vec4(1.0);
}

void fragment() {
	bool strip = shape.x > 0.0;
	vec2 way = strip ? centre_way.zw : vec2(1.0, 0.0);
	vec2 across = vec2(-way.y, way.x);
	float reach = max(shape.y, 0.01);
	float d = strip ? abs(metres.y) : length(metres);
	float u = d / reach;
	float along = strip ? 1.0 - abs(metres.x) / shape.x : 1.0;
	if (u >= 1.0 || along <= 0.0) discard;
	float t = now - shape.z - d / FRONT;
	float after = max(t - RISE - HOLD, 0.0);
	float push = smoothstep(0.0, RISE, t) * cos(TAU * SPRING_HZ * after) * exp(-after / SPRING_TAU)
		* (1.0 - smoothstep(GONE * 0.7, GONE, after));
	float loose = smoothstep(0.0, LOOSE_RISE, after) * exp(-after / LOOSE_TAU)
		* (1.0 - smoothstep(GONE * 0.7, GONE, after));
	float fall = pow(1.0 - smoothstep(0.5, 1.0, u), 1.3) * along * shape.w;
	vec2 out_way;
	if (strip) {
		float side = metres.y / sqrt(metres.y * metres.y + 4.0);
		out_way = across * side + way * (1.0 - abs(side)) * WAY_ON_LINE;
	} else {
		out_way = metres / sqrt(d * d + 1.0);
	}
	// blend_add multiplies by alpha, which is 1 here; the map's alpha is unread.
	COLOR = vec4(out_way * push * fall, loose * fall, 1.0);
}
