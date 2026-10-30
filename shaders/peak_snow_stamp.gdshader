shader_type canvas_item;
// One length of furrow into the snow's map (scripts/endless/peak_snow.gd, read
// by shaders/peak_snow.gdshaderinc): a quad along the plane's way, summed into
// the half float map (premultiplied with alpha 0 adds, so the groove can go
// below zero). The map is redrawn from these, so a stamp's fill-in is worked
// out from its age. Lengths overlap by half; the cosine window along them
// sums to one, so a chain of them is one groove.
//   COLOR  = (born s, strength 0..1, -, -)
//   CUSTOM = (half width of the groove (m), share of the quad's half width that is, -, -)
// Out: r the height (-1 the groove's floor, over 0 the thrown lip), g the churn.
render_mode blend_premul_alpha, unshaded;

uniform float now = 0.0;
// When the fill starts and when the groove is gone (s).
uniform vec2 fill = vec2(4.0, 22.0);
// The lip's height against the groove's depth.
const float LIP = 0.42;

varying vec4 data;
varying vec2 local;
varying vec2 shape;

void vertex() {
	data = COLOR;
	shape = INSTANCE_CUSTOM.xy;
	local = VERTEX * 2.0;
}

void fragment() {
	float age = now - data.x;
	float left = 1.0 - smoothstep(fill.x, fill.y, age);
	// (The groove fills from its edges in, the churn goes first.)
	float x = abs(local.y) / max(shape.y, 0.01);
	float along = 0.5 + 0.5 * cos(local.x * 3.14159265);
	float width = mix(0.55, 1.0, left);
	float groove = 1.0 - smoothstep(0.0, 1.0, x / width);
	float lip = exp(-pow((x - 1.28) / 0.34, 2.0));
	float h = (lip * LIP - groove * groove * (3.0 - 2.0 * groove)) * data.y * left * along;
	float churn = (1.0 - smoothstep(0.85, 1.65, x)) * data.y * along * (1.0 - smoothstep(fill.x * 0.5, fill.y * 0.7, age));
	COLOR = vec4(h, churn, 0.0, 0.0);
}
