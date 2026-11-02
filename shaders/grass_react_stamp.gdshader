shader_type canvas_item;
// One stamp into the grass's push map (scripts/endless/grass_react.gd,
// read by shaders/grass_react.gdshaderinc): a quad over the stamp's reach,
// summed into the map (premultiplied with alpha 0 adds; the map is half
// float, so pushes are signed). Per instance:
//   COLOR  = (way x, way z, strength, swirl): `way` the drag along the air's
//            way (the wash blown back, his walk, the wind), added to the
//            push out from the centre; swirl the share turned about it.
//   CUSTOM = (press share, age s, front speed m/s (0: at once), hold s;
//            a negative hold is a calm stamp).
// The reach (m) is the quad's own size: its side is 2 x reach x px_per_m.
// The spring, as plants have no memory here: a point's push rises once the
// front reaches it (at reach/speed), holds `hold` s, then swings back past
// rest and settles (the wind tool's zs_blow_swing, a little slower for wide
// stamps). A calm stamp, air that stays (the prop's wash, what's parked),
// eases back critically damped instead: it never goes past rest, so a stream
// of them sums to a steady push with no beat in it. The middle is pressed while it is pushed (times the press share:
// 1 the wash and the walker, less for the eddies' swept bands, which bow
// the grass without laying it down), and pops up a touch.
render_mode blend_premul_alpha, unshaded;

const float DAMP = 2.4;
const float RING = 5.2;
const float EASE = 3.5; // grass_react.gd EASE
uniform float px_per_m = 1.0;

varying vec4 way;
varying vec4 shape;
varying vec2 local;
varying float shape_press;

void vertex() {
	way = COLOR;
	shape = INSTANCE_CUSTOM;
	shape.x = length(MODEL_MATRIX[0].xy) * 0.5 / px_per_m;
	shape_press = INSTANCE_CUSTOM.x;
	local = VERTEX * 2.0;
}

void fragment() {
	float reach = max(shape.x, 0.01);
	vec2 o = local * reach;
	float r = length(o);
	float u = r / reach;
	if (u >= 1.0) discard;
	float wide = smoothstep(4.0, 30.0, reach);
	float arrive = shape.z > 0.0 ? r / shape.z : 0.0;
	float rise = 0.1 + 0.35 * wide;
	float t = shape.y - arrive - rise;
	float after = max(t - abs(shape.w), 0.0);
	float ring = RING * mix(1.0, 0.55, wide);
	float damp = DAMP * mix(1.0, 0.6, wide);
	float back = shape.w < 0.0 ? (1.0 + EASE * after) * exp(-EASE * after) : exp(-damp * after) * cos(ring * after);
	float swing = smoothstep(-rise, 0.0, t) * back;
	float fall = 1.0 - smoothstep(0.45, 1.0, u);
	vec2 out_way = o / sqrt(r * r + 0.04 * reach * reach);
	vec2 turn = vec2(-out_way.y, out_way.x) * way.w;
	vec2 push = (out_way + turn + way.xy) * (way.z * swing * fall);
	float core = 1.0 - smoothstep(0.0, 0.5, u);
	float press = way.z * shape_press * core * (swing > 0.0 ? swing : swing * 0.5);
	COLOR = vec4(push, press, 0.0);
}
