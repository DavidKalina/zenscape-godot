shader_type canvas_item;
// The chain plate's fire (scripts/endless/near_miss_hud_plate.gd): flames off
// the plate's top, taller and brighter with `heat` (the line's multiplier, 0 at
// x1 to 1 at its cap); `flare` (0..1) a multiplier step's leap. UV: x along the
// plate, y 1 at the flames' foot (behind the plate) to 0 at their most.
// The shape is a seamless noise texture read twice, at two sizes and speeds:
// less than one tile across the quad, so nothing repeats along it, and no
// grid of cells to show as seams.

uniform float heat = 0.0;
uniform float flare = 0.0;
uniform sampler2D grain : repeat_enable, filter_linear;
uniform vec3 ember : source_color = vec3(1.0, 0.416, 0.169);
uniform vec3 gold : source_color = vec3(1.0, 0.827, 0.42);
uniform vec3 glint : source_color = vec3(1.0, 0.953, 0.788);

void fragment() {
	float up = 1.0 - UV.y;
	float t = TIME;
	// A slow sideways sway, more toward the tips.
	float sway = (texture(grain, vec2(UV.x * 0.35 + t * 0.03, t * 0.11)).r - 0.5) * 0.12 * up;
	float a1 = texture(grain, vec2(UV.x * 1.0 + sway, UV.y * 0.2 + t * 0.2)).r;
	float a2 = texture(grain, vec2(UV.x * 1.7 - sway + 0.37, UV.y * 0.3 + t * 0.31 + 0.5)).r;
	float n = a1 * 0.6 + a2 * 0.4;
	float reach = mix(0.3, 0.8, heat) + 0.15 * flare;
	// Tongues taper to points, and none reaches the quad's top.
	float body = (n - 0.5) * 5.0 + 0.9 - up / reach - 0.45 * up * up;
	float ends = smoothstep(0.0, 0.14, UV.x) * smoothstep(1.0, 0.8, UV.x);
	float a = smoothstep(0.0, 0.14, body) * ends * smoothstep(0.0, 0.12, heat) * smoothstep(1.0, 0.8, up);
	// Three flat tones with soft joins, as brushed on.
	vec3 col = mix(ember, gold, smoothstep(0.36, 0.5, body));
	col = mix(col, glint, smoothstep(0.78, 0.92, body) * 0.8);
	COLOR = vec4(col, a * COLOR.a * mix(0.75, 0.95, heat));
}
