shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, shadows_disabled, fog_disabled;
// A flame as a volume (scripts/flame.gd), after the art direction (AGENTS.md:
// the things in the world are real): not a card, not toon bands. Drawn on the
// back faces of a unit box (x, z -0.5..0.5, y 0 at its foot to 1 at its tip,
// scaled to the flame's width and height), it marches the view ray through
// the box and sums the light of a teardrop of fire torn by rising noise:
// licks that break off the tip, a dim blue-cored foot, a hot pale heart and an
// orange skin going dark red where it thins. The colour comes from how hot a
// point is (a blackbody ramp), so it is never a flat orange. Stopped at the
// scene's depth, so logs and stone in it hide what is behind them.

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// How bright, and the share of its light that is the hot heart.
instance uniform float intensity = 1.0;
instance uniform float seed = 0.0;
// The lean, as a share of the width at the tip (wind), and how fast it
// rises (box heights a second).
instance uniform vec2 lean = vec2(0.0);
instance uniform float rise = 1.4;
// How torn the flame is (0 a calm candle, 1 a roaring fire).
instance uniform float turbulence = 0.6;
uniform int steps = 18;
// Fewer steps with distance, counted in box heights: full to near_far heights
// away, down to far_steps by far_far heights (a far flame is small and soft).
uniform int far_steps = 6;
uniform float near_far = 5.0;
uniform float far_far = 24.0;
uniform float gain = 1.6;

varying vec3 v_local;
varying vec3 v_cam;
varying float v_far;

void vertex() {
	v_local = VERTEX;
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	v_far = distance(CAMERA_POSITION_WORLD, MODEL_MATRIX[3].xyz) / max(length(MODEL_MATRIX[1].xyz), 0.01);
}

float h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x),
			mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x),
			mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// The fire's colour at a heat t (0 cold to 1 white hot), a blackbody's
// run: deep red, orange, gold, a pale cream heart.
vec3 heat(float t) {
	t = clamp(t, 0.0, 1.0);
	vec3 c = vec3(0.32, 0.03, 0.005);
	c = mix(c, vec3(0.95, 0.22, 0.03), smoothstep(0.0, 0.35, t));
	c = mix(c, vec3(1.0, 0.55, 0.12), smoothstep(0.3, 0.62, t));
	c = mix(c, vec3(1.0, 0.86, 0.55), smoothstep(0.6, 0.92, t));
	return c;
}

// The fire at a point in the box: its density and its heat.
vec2 fire(vec3 p, float t) {
	float y = p.y;
	// Kept off the box's walls, so no flame is ever cut square.
	float walls = 1.0 - smoothstep(0.82, 0.98, max(abs(p.x), abs(p.z)) * 2.0);
	// Leaning with the wind, more toward the tip.
	p.xz -= lean * 0.5 * y * y;
	// Rising noise, two scales; it pushes the flame about (more toward the
	// tip) and eats into it from the edge.
	vec3 q = vec3(p.x * 4.0, y * 3.0 - t * rise * 3.0, p.z * 4.0) + seed * 7.31;
	float n1 = vnoise(q);
	float n2 = vnoise(q * 2.3 + vec3(3.1, -t * rise * 1.7, 1.7));
	float n3 = vnoise(q * 5.1 + vec3(-1.3, -t * rise * 3.3, 4.2));
	float n = n1 * 0.55 + n2 * 0.3 + n3 * 0.15;
	float sway = turbulence * (0.08 + 0.2 * y) * y;
	p.x += (vnoise(q * 0.7 + 11.0) - 0.5) * sway;
	p.z += (vnoise(q * 0.7 + 23.0) - 0.5) * sway;
	// The teardrop: round at its foot, drawn to a point at its tip.
	float r = length(p.xz) * 2.0;
	float width = 0.74 * pow(max(1.0 - y, 0.0), 0.55) * smoothstep(-0.02, 0.16, y);
	float body = width - r;
	// Torn: the noise eats in harder up the flame, so licks break off.
	float torn = body + (n - 0.55) * (0.35 + 1.1 * y) * (0.4 + turbulence);
	float d = smoothstep(0.0, 0.18, torn) * walls * (1.0 - smoothstep(0.9, 1.0, y));
	// Heat: hottest low and in the heart, cooling up and out.
	float h = clamp(torn * 1.7 + 0.12, 0.0, 1.0) * (1.0 - 0.7 * y);
	return vec2(d, h);
}

void fragment() {
	vec3 ro = v_cam;
	vec3 rd = normalize(v_local - v_cam);
	// The box: x, z -0.5..0.5, y 0..1.
	vec3 lo = vec3(-0.5, 0.0, -0.5);
	vec3 hi = vec3(0.5, 1.0, 0.5);
	vec3 inv = 1.0 / rd;
	vec3 ta = (lo - ro) * inv;
	vec3 tb = (hi - ro) * inv;
	float t0 = max(max(min(ta.x, tb.x), min(ta.y, tb.y)), min(ta.z, tb.z));
	float t1 = min(min(max(ta.x, tb.x), max(ta.y, tb.y)), max(ta.z, tb.z));
	t0 = max(t0, 0.0);
	// The scene in front: where along the ray it stands.
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	vec3 scene_world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 scene_local = (inverse(MODEL_MATRIX) * vec4(scene_world, 1.0)).xyz;
	t1 = min(t1, dot(scene_local - ro, rd));
	if (t1 <= t0) discard;
	int n_steps = int(mix(float(steps), float(far_steps), smoothstep(near_far, far_far, v_far)));
	float dt = (t1 - t0) / float(n_steps);
	// A jitter a pixel, so the steps never band.
	float jitter = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	float tt = TIME + seed * 13.0;
	vec3 light = vec3(0.0);
	float seen = 1.0;
	// A step's length in the box's own units of height, so a thick flame
	// glows more than a thin one whatever the box's shape.
	float scale = length(rd * dt);
	for (int i = 0; i < n_steps; i++) {
		vec3 p = ro + rd * (t0 + (float(i) + jitter) * dt);
		vec2 f = fire(p, tt);
		if (f.x > 0.001) {
			float a = f.x * scale * 7.0;
			light += heat(f.y) * (0.35 + 1.4 * f.y * f.y) * a * seen;
			seen *= exp(-a * 0.6);
		}
	}
	// Unshaded: what it adds is its albedo.
	ALBEDO = light * gain * intensity;
}
