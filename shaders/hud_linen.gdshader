shader_type canvas_item;
// The HUD's linen in shadow (design "ZenScape HUD 4c", scripts/hud_linen.gd):
// a rounded strip of warm grey-brown cloth with a fine weave, a little grain,
// a 1 px highlight along its top, a dashed hem stitched inside its edge and a
// soft drop shadow. The node is the strip plus `margin` pixels round it for
// the shadow; every length is in viewport pixels.

uniform vec2 strip = vec2(100.0, 100.0);
uniform float margin = 24.0;
uniform float radius = 12.0;
// One design pixel in viewport pixels.
uniform float px = 1.0;
uniform vec4 cloth : source_color = vec4(0.384, 0.345, 0.290, 0.76);
uniform vec4 weave : source_color = vec4(0.078, 0.055, 0.031, 0.12);
uniform vec4 weft : source_color = vec4(1.0, 0.941, 0.843, 0.035);
uniform float grain = 0.16;
uniform vec4 highlight : source_color = vec4(1.0, 0.941, 0.843, 0.09);
// The hem: inset from the edge, its radius, colour and dash; 0 inset hides it.
uniform float hem_inset = 5.0;
uniform float hem_radius = 8.0;
uniform vec4 hem : source_color = vec4(0.890, 0.843, 0.741, 0.3);
uniform float dash = 3.0;
uniform vec4 shadow : source_color = vec4(0.071, 0.086, 0.118, 0.2);
uniform float shadow_y = 6.0;
uniform float shadow_blur = 18.0;

float box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec4 over(vec4 top, vec4 under) {
	float a = top.a + under.a * (1.0 - top.a);
	vec3 c = (top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / max(a, 1e-5);
	return vec4(c, a);
}

void fragment() {
	vec2 node = strip + vec2(margin * 2.0);
	vec2 p = UV * node - vec2(margin);
	vec2 centre = strip * 0.5;
	float r = radius * px;
	float d = box(p - centre, centre, r);
	// The shadow, falling under the cloth.
	float ds = box(p - centre - vec2(0.0, shadow_y * px), centre, r);
	float blur = max(shadow_blur * px * 0.5, 1.0);
	vec4 colour = vec4(shadow.rgb, shadow.a * (1.0 - smoothstep(-blur, blur, ds)));
	float inside = 1.0 - smoothstep(-0.5, 0.5, d);
	if (inside > 0.0) {
		vec3 c = cloth.rgb;
		vec2 cell = floor(p / px);
		// Weave: dark rows every 3 px, faint light threads every 2.
		if (mod(cell.y, 3.0) < 1.0) c = mix(c, weave.rgb, weave.a);
		if (mod(cell.x, 2.0) < 1.0) c = mix(c, weft.rgb, weft.a);
		// Grain, as an overlay of fine noise.
		c += (hash(cell) - 0.5) * grain * 0.35;
		// The highlight along the top edge.
		if (p.y < px) c = mix(c, highlight.rgb, highlight.a);
		vec4 top = vec4(c, cloth.a);
		// The hem stitch, dashed along whichever edge is nearer.
		if (hem_inset > 0.0) {
			vec2 hc = centre - vec2(hem_inset * px);
			float dh = box(p - centre, hc, hem_radius * px);
			float line = 1.0 - smoothstep(0.0, px, abs(dh + 0.5 * px));
			vec2 q = abs(p - centre) - hc;
			float along = q.x > q.y ? p.y : p.x;
			float on = step(mod(along / px, dash * 2.0), dash);
			top = over(vec4(hem.rgb, hem.a * line * on), top);
		}
		colour = over(vec4(top.rgb, top.a * inside), colour);
	}
	COLOR = colour;
}
