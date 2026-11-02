shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// The plane's propeller at speed (scripts/plane_figure.gd): a thin disc of air
// you see the nose through. Nearly clear over the spinner and the cowl, a little
// denser out past the cowl where the blades' tips move fastest, with a faint arc
// at the tips' path and fine rings round it. Two soft sweeps with a leading edge
// and a long trail wheel slowly round (`phase`), the way a filmed propeller seems
// to crawl, so it reads as turning. It takes the world's light, not a fixed
// white, so it stays air on a dark cowl, and at dusk and night.
// Under the pace a disc fits, the blades are drawn as a camera with an open
// shutter would: each smeared along the path it went this frame (`blade_went`),
// as faint as it is spread, so the frames join up and it cannot strobe.
global uniform vec3 zs_hemi_sky;
global uniform float zs_hemi_energy;
global uniform vec3 zs_key_irradiance;
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.92);
// 0 nothing to 1 full: the plane sets it from the speed and the engine.
uniform float strength = 0.0;
// The sweeps' angle (radians), and how spread they are (0 sharp, 1 even).
uniform float phase = 0.0;
uniform float spread = 0.5;
// The smear: how much of it (0 none), the prop's angle at the frame's end, and
// how far it went in the frame (radians).
uniform float blades = 0.0;
uniform float blade_angle = 0.0;
uniform float blade_went = 0.0;
uniform vec3 wood : source_color = vec3(0.24, 0.13, 0.08);
uniform vec3 brass : source_color = vec3(0.79, 0.64, 0.35);

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
	vec3 light = zs_hemi_sky * zs_hemi_energy * 1.4 + zs_key_irradiance / PI * 0.4;
	vec3 air = tint * light;
	float air_a = clamp(((over_nose + past_nose) * rings * edge + tips) * along * strength, 0.0, 1.0);
	float blade_a = 0.0;
	vec3 blade = wood;
	if (blades > 0.0) {
		// The blade's half width here as an angle; blades lie along the prop's y.
		float half_w = 0.075 / max(r, 0.2);
		float went = min(blade_went, PI - 2.0 * half_w);
		float c = mod(a + blade_angle + PI * 0.5 + half_w, PI);
		float smear = smoothstep(0.0, 2.0 * half_w, c) * (1.0 - smoothstep(went, went + 2.0 * half_w, c));
		float tip = 1.0 - smoothstep(0.86, 0.94, r);
		float root = smoothstep(0.14, 0.2, r);
		blade_a = blades * smear * tip * root * min(1.0, 2.0 * half_w / max(went, 0.001)) * 1.1;
		blade_a = clamp(blade_a, 0.0, 1.0);
		blade = mix(wood, brass, smoothstep(0.76, 0.8, r)) * (light + 0.4);
	}
	ALBEDO = mix(air, blade, blade_a / max(blade_a + air_a * (1.0 - blade_a), 0.001));
	ALPHA = blade_a + air_a * (1.0 - blade_a);
}
