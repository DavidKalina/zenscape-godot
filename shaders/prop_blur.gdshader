shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// The plane's propeller at speed (scripts/plane_figure.gd): no hard ring but a
// soft disc of air, clear at the hub, densest across the blades' outer half
// and feathered at the tips, where a faint pale arc marks the tips' path. Two
// soft sweeps, wider and fainter the faster it turns, wheel slowly round it
// (`phase`), the way a filmed propeller seems to crawl, so it reads as
// turning, not as a glass plate.
uniform vec4 tint : source_color = vec4(1.0, 0.96, 0.88, 1.0);
// 0 nothing to 1 full: the plane sets it from the speed and the engine.
uniform float strength = 0.0;
// The sweeps' angle (radians), and how spread they are (0 sharp, 1 even).
uniform float phase = 0.0;
uniform float spread = 0.5;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float body = smoothstep(0.1, 0.42, r) * (1.0 - smoothstep(0.82, 1.0, r));
	float tips = exp(-pow((r - 0.9) / 0.045, 2.0)) * 0.6;
	float sweep = pow(0.5 + 0.5 * cos(2.0 * (a - phase)), mix(6.0, 1.0, spread));
	float along = mix(0.55, 1.0, sweep);
	ALBEDO = tint.rgb;
	ALPHA = clamp((body * 0.75 + tips) * along * strength * tint.a, 0.0, 1.0);
}
