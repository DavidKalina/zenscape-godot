shader_type spatial;
// The splash of a fish the plane flung (scripts/endless/wake_fish.gd): one
// instance is one splash, one mesh of quads, and all of it is worked out here
// from the moment it began, so a splash costs the CPU nothing once laid.
// The instance's origin: the spot on the water.
// INSTANCE_CUSTOM: x the moment it began (`clock`'s s), y its size (about 1
// for a metre of fish), z 1 going in, 0 coming out, w a seed.
// COLOR: r the quad's sort (0 a ring on the water, 0.5 a drop, 1 a puff),
// g its heading (of a turn), b how far out, a how far up. UV2: x its size,
// y the wait (s) before it starts.
// Lit as the water's face (normal up), as shaders/endless_splash.gdshader.
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert_wrap, specular_disabled, world_vertex_coords, shadows_disabled;

uniform float clock = 0.0;
uniform float gravity = 9.8;
uniform vec3 tint : source_color = vec3(0.9, 0.95, 1.0);
uniform vec3 trough_tint : source_color = vec3(0.12, 0.18, 0.2);
uniform float glow = 0.3;
// A ring: how far it runs (m at size 1) and how long it lives (s).
uniform float ring_reach = 2.4;
uniform float ring_life = 1.7;

varying flat float sort;
varying float fade;
varying float band;
varying flat float wobble;

void vertex() {
	float start = INSTANCE_CUSTOM.x + UV2.y;
	float t = clock - start;
	float size = INSTANCE_CUSTOM.y;
	float going_in = INSTANCE_CUSTOM.z;
	vec3 at = MODEL_MATRIX[3].xyz;
	vec2 q = UV * 2.0 - 1.0;
	sort = COLOR.r;
	wobble = INSTANCE_CUSTOM.w + COLOR.g;
	fade = 0.0;
	band = 0.2;
	float heading = (COLOR.g + INSTANCE_CUSTOM.w) * TAU;
	vec2 out_way = vec2(cos(heading), sin(heading));
	vec3 place = at;
	float half_size = 0.0;
	if (t >= 0.0) {
		if (sort < 0.25) {
			// A ring lying on the water: out fast, then slowing, thinning as it goes.
			float first = step(UV2.y, 0.001);
			float life = ring_life * mix(1.0, 0.45, first) * mix(0.75, 1.15, going_in);
			float k = t / life;
			if (k < 1.0) {
				float r = max(mix(ring_reach, ring_reach * 0.4, first) * size * (0.4 + UV2.x) * (1.0 - pow(1.0 - k, 2.2)), 0.05);
				// (The first is the boil, only where it comes out.)
				fade = (1.0 - k) * smoothstep(0.0, 0.06, k) * mix(1.0, 0.55, first) * (1.0 - first * going_in);
				band = mix(0.09, 0.04, k);
				VERTEX = at + vec3(q.x * r, 0.0, q.y * r);
				place = VERTEX;
			}
		} else if (sort < 0.75) {
			// A drop, thrown up and out; half of them only when it goes in.
			float live = 0.55 + 0.5 * COLOR.b;
			float up = (2.4 + 5.0 * COLOR.a) * sqrt(size) * mix(0.7, 1.0, going_in);
			float out_speed = (0.8 + 3.4 * COLOR.b) * sqrt(size) * mix(0.75, 1.0, going_in);
			float y = up * t - 0.5 * gravity * t * t;
			if (t < live && y > -0.05 && (going_in > 0.5 || COLOR.a > 0.45)) {
				place = at + vec3(out_way.x * out_speed * t, y, out_way.y * out_speed * t);
				half_size = UV2.x * sqrt(size);
				fade = 0.95 * (1.0 - smoothstep(0.65, 1.0, t / live));
			}
		} else {
			// A puff of spray over it.
			float live = 0.9;
			float k = t / live;
			if (k < 1.0) {
				place = at + vec3(out_way.x * 0.5 * t, 0.3 + (0.9 + COLOR.a) * t * (1.0 - 0.4 * k), out_way.y * 0.5 * t) * vec3(1.0, size, 1.0);
				half_size = UV2.x * size * mix(0.6, 1.9, sqrt(k));
				fade = 0.24 * (1.0 - k) * (1.0 - k) * smoothstep(0.0, 0.1, k) * mix(0.6, 1.0, going_in);
			}
		}
	}
	if (sort >= 0.25) {
		// Turned to the eye.
		VERTEX = place + (INV_VIEW_MATRIX[0].xyz * q.x + INV_VIEW_MATRIX[1].xyz * q.y) * half_size;
	} else if (fade <= 0.0) {
		VERTEX = at;
	}
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	if (sort < 0.25) {
		float w = max(band, 0.02);
		// The crest: a bright band at the rim; inside it a darker trough.
		float crest = smoothstep(1.0, 1.0 - w * 0.45, r) * smoothstep(1.0 - w * 1.4, 1.0 - w * 0.55, r);
		float trough = smoothstep(1.0 - w * 1.2, 1.0 - w * 2.0, r) * smoothstep(1.0 - w * 3.6, 1.0 - w * 2.3, r) * 0.35;
		// Broken along its length a little, as wind ruffles it.
		float a = atan(q.y, q.x);
		float broken = 0.75 + 0.25 * sin(a * 7.0 + wobble * 6.2832) * sin(a * 3.0 + 1.3);
		vec3 c = mix(trough_tint, tint, crest / max(crest + trough, 1e-3));
		ALBEDO = c;
		EMISSION = c * glow;
		ALPHA = clamp((crest + trough) * broken * fade * 0.45, 0.0, 1.0);
	} else {
		float soft = sort < 0.75 ? 0.45 : 0.9;
		float disc = 1.0 - smoothstep(1.0 - soft, 1.0, r);
		ALBEDO = tint;
		EMISSION = tint * glow;
		ALPHA = disc * fade;
	}
}
