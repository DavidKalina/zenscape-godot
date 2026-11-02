shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// The plane's propeller at speed (scripts/plane_figure.gd): a thin disc of air
// you see the nose through. Nearly clear over the spinner and the cowl, a little
// denser out past the cowl where the blades' tips move fastest, with a faint arc
// at the tips' path and fine rings round it. Two soft sweeps with a leading edge
// and a long trail wheel slowly round (`phase`), the way a filmed propeller seems
// to crawl, so it reads as turning. It takes the world's light, not a fixed
// white, so it stays air on a dark cowl, and at dusk and night.
global uniform vec3 zs_hemi_sky;
global uniform float zs_hemi_energy;
global uniform vec3 zs_key_irradiance;
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.92);
// 0 nothing to 1 full: the plane sets it from the speed and the engine.
uniform float strength = 0.0;
// The sweeps' angle (radians), and how spread they are (0 sharp, 1 even).
uniform float phase = 0.0;
uniform float spread = 0.5;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float over_nose = smoothstep(0.2, 0.34, r) * 0.05;
	float past_nose = smoothstep(0.55, 0.8, r) * 0.1;
	float edge = 1.0 - smoothstep(0.88, 1.0, r);
	float tips = exp(-pow((r - 0.915) / 0.03, 2.0)) * 0.09;
	float rings = 0.82 + 0.18 * sin(r * 46.0) * sin(r * 17.0 + 1.3);
	// The way round from the last blade, 0 to 1: a soft front, a long trail.
	float turn = fract((a - phase) / PI);
	float front = smoothstep(0.0, 0.05, turn) * (1.0 - smoothstep(0.92, 1.0, turn));
	float sweep = front * pow(1.0 - turn, mix(3.5, 1.4, spread));
	float along = 0.5 + sweep * mix(1.5, 0.9, spread);
	ALBEDO = tint * (zs_hemi_sky * zs_hemi_energy * 1.4 + zs_key_irradiance / PI * 0.4);
	ALPHA = clamp(((over_nose + past_nose) * rings * edge + tips) * along * strength, 0.0, 1.0);
}
