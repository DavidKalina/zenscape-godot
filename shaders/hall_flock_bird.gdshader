shader_type spatial;
// The hall flock's swift (scripts/hall_flock.gd): one small dark bird drawn
// as a MultiMesh instance, its wings beaten here. The mesh lies along -Z
// (its nose), +X its right wing, wing vertices carrying their reach out
// from the shoulder in UV.x (0 on the body, 1 at the tip) and their sweep
// back in UV.y. INSTANCE_CUSTOM: r how hard it beats (0 a glide, 1 full),
// g its beat's phase offset (0..1), b how folded (1 perched: the long
// wings laid back over the tail), a its dihedral in a glide (rad).
render_mode cull_disabled, diffuse_lambert_wrap, specular_disabled;

uniform vec3 tone : source_color = vec3(0.075, 0.066, 0.060);
uniform float beat_rate = 4.2;
uniform float sweep = 0.75;
// A faint rim where the light behind them catches the edges (they read
// against the dim stone).
uniform vec3 rim_tone : source_color = vec3(0.55, 0.6, 0.7);
uniform float rim_amount = 0.1;

void vertex() {
	float r = UV.x;
	if (r > 0.001) {
		float side = sign(VERTEX.x);
		float beat = INSTANCE_CUSTOM.r;
		float phase = INSTANCE_CUSTOM.g;
		float fold = INSTANCE_CUSTOM.b;
		float glide = INSTANCE_CUSTOM.a;
		// The stroke: down fast, up slower; the tip trails the shoulder.
		float w = TAU * (TIME * beat_rate + phase) - r * 0.9;
		float stroke = sin(w) + 0.25 * sin(2.0 * w);
		float a = glide + beat * sweep * stroke;
		float shoulder = 0.018 * side;
		float ox = VERTEX.x - shoulder;
		vec3 v = VERTEX;
		v.x = shoulder + ox * cos(a);
		v.y = VERTEX.y + abs(ox) * sin(a);
		// The tips sweep back a touch on the upstroke.
		v.z += r * r * 0.03 * beat * (1.0 - stroke);
		// Folded: laid back along the body, crossing over the tail.
		vec3 folded = vec3(shoulder + ox * 0.18, VERTEX.y + 0.012 * r, VERTEX.z + abs(ox) * 0.95 + 0.01);
		VERTEX = mix(v, folded, fold);
	}
}

void fragment() {
	// Sooty all over, the wings' trailing edges a shade paler.
	ALBEDO = tone * (1.0 + 0.5 * UV.y);
	ROUGHNESS = 0.9;
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = rim_tone * edge * rim_amount;
}
