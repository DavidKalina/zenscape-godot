shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;
// The climbers' flags on the Peak (scripts/endless/peak_flags.gd): one mesh of
// cloth, rope, poles and cairn stones, moved here and nowhere else. Nothing
// runs on the CPU per frame.
//
// A cloth is a strip of rows hung from its attached edge. Each vertex walks
// its own column from that edge row by row, turning by an angle at each row
// (`flap`), so the cloth keeps its length: a wave crest pulls the free edge in
// and throws it out again, which a displacement off a flat plane can't do.
// The angle is a steep-fronted wave running from the attached edge to the free
// edge, growing on the way, with two faster ones on top near the free edge and
// a crack: a kink thrown down the cloth when a gust arrives. The crests run
// slantwise and bend across the width, and the columns drift along the rope
// (`drift`), so the outline changes: seen from downwind a wave off the plane
// alone only looks like a stiff wobble.
//
// The gusts come baked (gust_tex, PeakFlags._gust_texture), one texel every
// gust_dt seconds round a loop, read at (time - this place's delay) so a gust
// runs down a string from one end to the other:
//   r  how far the gust has the cloth up: a stiff spring, it overshoots
//   g  the flap's phase in cycles: wind speed integrated, so a gust quickens
//      the flapping without the phase jumping
//   b  seconds since the last gust began
//   a  the rope's swing: a slow spring on the same gusts
// zs_wind_strength scales how far the cloth stands out, never the phase.

// Vertex attributes (PeakFlags):
//   VERTEX   the column's point on its rope or pole (a stone: itself)
//   NORMAL   the attached edge's way, or the rope's or pole's (a stone: its normal)
//   UV       cloth: (across 0..1, attached 0 .. free 1); rope, pole: (side -1..1, metres along)
//   UV2      x the kind: 0 cloth on a rope, 1 pennant, 2 rope, 3 pole, 4 stone
//   COLOR    rgb its colour, a how sun-bleached
//   CUSTOM0  gust delay (s), rope swing here (m), metres along the string, seed
//   CUSTOM1  cloth: width, length, spread at the free edge (m), wear (<0: plain cord)
//            rope, pole: radius, -, -, -

global uniform float zs_motion_time;
global uniform float zs_wind_strength;
global uniform vec2 zs_wind_direction;

uniform sampler2D gust_tex : filter_nearest, repeat_disable;
uniform float gust_dt = 0.25;
uniform float gust_cycles = 300.0;
// The air up here against the land's zs_wind_strength.
uniform float wind_gain = 1.6;
// The thinnest a rope or pole draws, in pixels.
uniform float least_px = 1.15;

const int GUST_N = 512;
const int ROWS = 10;

varying vec2 v_uv;
varying flat vec4 v_cloth;
varying flat float v_kind;
varying float v_fold;

// (lift, phase in cycles, seconds since the gust, rope swing) at time t.
vec4 gust_at(float t) {
	float n = float(GUST_N);
	float x = t / gust_dt;
	float loops = floor(x / n);
	float xw = x - loops * n;
	int i = clamp(int(xw), 0, GUST_N - 1);
	float f = xw - float(i);
	vec4 a = texelFetch(gust_tex, ivec2(i, 0), 0);
	vec4 b = texelFetch(gust_tex, ivec2((i + 1) % GUST_N, 0), 0);
	float dg = b.g - a.g;
	if (i + 1 == GUST_N) dg += gust_cycles;
	return vec4(mix(a.r, b.r, f), loops * gust_cycles + a.g + f * dg, a.b + f * gust_dt, mix(a.a, b.a, f));
}

// The leeward swing of a rope and everything tied to it.
vec3 sway(float swing, float along, vec4 g, vec3 wind, float air) {
	float ripple = sin(along * 0.19 - g.g * 0.31) * 0.08 + sin(along * 0.47 - g.g * 0.53) * 0.035;
	return (wind * (g.a * air + ripple) + vec3(0.0, 0.22 * g.a * air + ripple * 0.7, 0.0)) * swing;
}

// The angle (rad) a cloth turns by at s (0 attached .. 1 free), u across.
float flap(float s, float u, float phase, float lift, float age, float seed, float ripples, float skew) {
	// The crest bends across the width, and slowly wanders.
	float bend = sin(2.9 * u + seed * 9.0 + phase * 0.11) * 1.5 * s;
	float x = s * ripples * TAU + skew * (u - 0.5) + bend;
	float q = x - phase;
	float main = sin(q + 0.85 * sin(q));
	float second = sin(1.71 * x - 1.37 * phase + seed * 17.0) * s;
	float third = sin(3.13 * x - 2.21 * phase + seed * 41.0) * s * s * lift;
	float corner = (2.0 * u - 1.0);
	float env = (0.22 + 0.78 * pow(s, 1.1)) * (1.0 + 0.7 * corner * corner * s);
	float kink = (s - age * 3.4) / 0.17;
	float crack = 1.5 * lift * exp(-kink * kink) * exp(-age * 2.2) * (0.35 + s);
	return env * (mix(0.5, 0.8, lift) * main + 0.38 * second + 0.26 * third) + crack * (seed < 0.5 ? -1.0 : 1.0);
}

// How far a cloth's run slips along its rope (or pole) at s: the free edge
// swings side to side, its corners out of step, more the more air there is.
float drift(float s, float u, float phase, float lift, float seed) {
	float slow = sin(phase * 0.43 + seed * 11.0) + 0.6 * sin(phase * 0.71 + seed * 23.0);
	float quick = sin(phase * 1.27 - s * 4.0 + (u - 0.5) * 5.0 + seed * 31.0);
	return s * (0.2 * slow + (0.16 + 0.2 * lift) * quick);
}

// The way a cloth runs at s, before it is normalized.
vec3 way(float s, float angle, float droop, float tilt, float slip, vec3 b0, vec3 b1, vec3 t) {
	float a = angle * (1.0 - droop * s);
	return cos(a) * b0 + sin(a) * b1 + t * (tilt * (0.35 + 0.65 * s) + slip);
}

// The column at u walked to `row` rows from the attached edge; `tip` the way
// it runs there.
vec3 walk(float u, int row, float h, float stream, float droop, float tilt, vec3 b0, vec3 b1, vec3 t,
		float phase, float lift, float age, float seed, float ripples, float skew, out vec3 tip) {
	vec3 p = vec3(0.0);
	float step_len = h / float(ROWS);
	for (int k = 0; k < row; k++) {
		float s = (float(k) + 0.5) / float(ROWS);
		float a = stream + flap(s, u, phase, lift, age, seed, ripples, skew);
		p += normalize(way(s, a, droop, tilt, drift(s, u, phase, lift, seed), b0, b1, t)) * step_len;
	}
	float s = float(row) / float(ROWS);
	float a = stream + flap(s, u, phase, lift, age, seed, ripples, skew);
	tip = normalize(way(s, a, droop, tilt, drift(s, u, phase, lift, seed), b0, b1, t));
	return p;
}

void vertex() {
	v_uv = UV;
	v_kind = UV2.x;
	v_cloth = vec4(CUSTOM1.x, CUSTOM1.y, CUSTOM1.w, CUSTOM0.w);
	v_fold = 0.0;
	if (UV2.x < 3.5) {
		float air = clamp(zs_wind_strength * wind_gain, 0.0, 1.5);
		vec3 wind = vec3(zs_wind_direction.x, 0.0, zs_wind_direction.y);
		vec4 at_rope = gust_at(zs_motion_time - CUSTOM0.x);
		vec3 anchor = VERTEX + sway(CUSTOM0.y, CUSTOM0.z, at_rope, wind, air);
		if (UV2.x > 1.5) {
			// A rope or a pole: a ribbon turned to the eye, never under a pixel.
			vec3 t = NORMAL;
			vec3 cam = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
			vec3 to = cam - anchor;
			float dist = length(to);
			// Only a perspective view has pixels to hold: a shadow's ortho
			// view keeps the true radius. The matrix's y may be flipped.
			bool perspective = abs(PROJECTION_MATRIX[3][3]) < 0.5;
			float px = dist / max(abs(PROJECTION_MATRIX[1][1]) * 0.5 * VIEWPORT_SIZE.y, 1.0);
			vec3 side = normalize(cross(t, to));
			float r = perspective ? max(CUSTOM1.x, 0.5 * least_px * px) : CUSTOM1.x;
			VERTEX = anchor + side * UV.x * r;
			NORMAL = normalize(normalize(to - t * dot(to, t)) + side * UV.x * 0.9);
		} else {
			float seed = CUSTOM0.w;
			float w = CUSTOM1.x;
			float h = CUSTOM1.y;
			float u = UV.x;
			int row = int(UV.y * float(ROWS) + 0.5);
			vec3 t = NORMAL;
			// Each cloth sits in the air a little off its neighbours.
			vec4 g = gust_at(zs_motion_time - CUSTOM0.x - (seed - 0.5) * 0.7);
			float lift = g.r;
			float size = sqrt(3.5 / max(h, 1.0));
			float rate = (0.86 + 0.28 * fract(seed * 13.7)) * clamp(size, 0.6, 1.5);
			float phase = TAU * (g.g * rate + seed * 3.0);
			float push = air * (0.45 + 0.95 * lift);
			float ang = (seed - 0.5) * 0.6;
			vec3 w3 = wind * cos(ang) + vec3(-wind.z, 0.0, wind.x) * sin(ang);
			vec3 b0;
			vec3 b1;
			float stream;
			float droop;
			float tilt;
			if (UV2.x < 0.5) {
				// Tied along a rope: it hangs, and the wind across the rope
				// swings it up round the rope; the wind along it drags the
				// free edge sideways.
				b0 = normalize(vec3(0.0, -1.0, 0.0) + t * t.y);
				b1 = normalize(cross(t, b0));
				float across = clamp(dot(w3, b1) * 1.4, -1.0, 1.0);
				// Near linear in the push: a lull lets it fall, a gust heaves it up.
				stream = 1.5 * pow(clamp(push / 1.5, 0.0, 1.0), 1.15) * across;
				stream += 0.3 * sin(TAU * g.g * 0.17 + seed * 20.0) * (1.0 - abs(across) * 0.5);
				droop = 0.55 * (1.0 - clamp(push, 0.0, 1.0));
				tilt = dot(w3, t) * clamp(push, 0.0, 1.0) * 0.7;
			} else {
				// Tied up a pole: it runs straight off downwind, and sags down
				// the pole when the wind drops.
				b0 = w3 - t * dot(w3, t);
				b0 = dot(b0, b0) > 0.0001 ? normalize(b0) : normalize(vec3(1.0, 0.0, 0.0) - t * t.x);
				b1 = normalize(cross(t, b0));
				stream = 0.0;
				droop = 0.0;
				tilt = -1.15 * (1.0 - clamp(push * 1.2, 0.0, 1.0)) - 0.08;
			}
			float ripples = mix(1.2, 2.3, clamp(lift, 0.0, 1.0)) * clamp(h / 3.5, 0.8, 1.5);
			// Slantwise, one way or the other, never straight across.
			float lean = fract(seed * 5.3) - 0.5;
			float skew = (lean < 0.0 ? -1.0 : 1.0) * (0.5 + 1.6 * abs(lean)) * max(w, 1.0);
			vec3 tip;
			vec3 c = walk(u, row, h, stream, droop, tilt, b0, b1, t, phase, lift, g.b, seed, ripples, skew, tip);
			vec3 tip2;
			float du = 0.14;
			float side_u = u < 0.5 ? du : -du;
			vec3 c2 = walk(u + side_u, row, h, stream, droop, tilt, b0, b1, t, phase, lift, g.b, seed, ripples, skew, tip2);
			float spread = CUSTOM1.z;
			float s = UV.y;
			VERTEX = anchor + c + t * (u - 0.5) * spread * s;
			vec3 across_u = t * (w + spread * s) + (c2 - c) / side_u;
			NORMAL = normalize(cross(across_u, tip));
			// Where the cloth folds the most, its fold stays dark.
			float here = flap(s, u, phase, lift, g.b, seed, ripples, skew);
			float next = flap(min(s + 0.1, 1.0), u, phase, lift, g.b, seed, ripples, skew);
			v_fold = clamp(abs(next - here) * 1.7, 0.0, 1.0);
		}
	}
}

float flag_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float flag_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(flag_hash(i), flag_hash(i + vec2(1.0, 0.0)), f.x),
		mix(flag_hash(i + vec2(0.0, 1.0)), flag_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float flag_fbm(vec2 p) {
	return flag_noise(p) * 0.62 + flag_noise(p * 2.3 + 7.1) * 0.38;
}

void fragment() {
	float dist = length(VERTEX);
	if (v_kind > 3.5) {
		ALBEDO = COLOR.rgb;
		ROUGHNESS = 0.95;
		SPECULAR = 0.2;
	} else if (v_kind > 2.5) {
		float grain = flag_noise(vec2(v_uv.x * 2.2, v_uv.y * 0.7));
		ALBEDO = COLOR.rgb * (0.72 + 0.5 * grain);
		ROUGHNESS = 0.9;
		SPECULAR = 0.25;
	} else if (v_kind > 1.5) {
		ALBEDO = COLOR.rgb * (0.82 + 0.18 * sin(v_uv.y * 11.0 + v_uv.x * 2.0));
		ROUGHNESS = 0.95;
		SPECULAR = 0.15;
	} else {
		float u = v_uv.x;
		float s = v_uv.y;
		float w = v_cloth.x;
		float h = v_cloth.y;
		float wear = abs(v_cloth.z);
		bool plain = v_cloth.z < 0.0;
		float seed = v_cloth.w;
		float near = 1.0 - smoothstep(30.0, 150.0, dist);
		vec2 m = vec2(u * w, s * h);
		vec2 o = vec2(seed * 91.7, seed * 37.3);

		// The free edge torn back in tongues, its strands finer close to.
		float tongue = flag_noise(vec2(m.x * 0.8 + o.x, o.y));
		float strand = flag_noise(vec2(m.x * 6.5 + o.y, m.y * 0.35 + o.x));
		float edge = 1.0 - wear * (0.1 + 0.62 * tongue * tongue) - (0.03 + 0.13 * wear) * strand * mix(0.4, 1.0, near);
		if (v_kind > 0.5) edge -= 0.34 * (1.0 - abs(2.0 * u - 1.0));
		if (s > edge) discard;
		if (!plain) {
			// One rip up from the free edge.
			float ru = fract(seed * 7.31) * 0.7 + 0.15;
			float rs = mix(0.92, 0.2, wear);
			float rw = max(s - rs, 0.0) / max(1.0 - rs, 0.01) * (0.03 + 0.09 * wear);
			if (abs(u - ru - 0.05 * sin(s * 9.0 + seed * 30.0)) < rw) discard;
			// Worn through, more toward the free edge.
			float hole = flag_fbm(m * 0.85 + o);
			if (hole < wear * wear * 0.27 * (0.3 + 0.7 * s)) discard;
			// The sides nibbled away.
			float side_m = min(u, 1.0 - u) * w;
			if (side_m < wear * 0.28 * s * flag_noise(vec2(m.y * 1.9 + o.x, o.y))) discard;
		}

		vec3 base = COLOR.rgb;
		float bleach = clamp(COLOR.a * (0.5 + 0.7 * s) + (flag_noise(m * 0.5 + o) - 0.5) * 0.7 * COLOR.a, 0.0, 1.0);
		vec3 c = mix(base, vec3(0.34, 0.31, 0.255), bleach * 0.72);
		// Weather run down from the seam.
		float stain = flag_noise(vec2(m.x * 1.6 + o.y, m.y * 0.16));
		c *= 1.0 - 0.3 * smoothstep(0.42, 0.85, stain) * (1.0 - 0.5 * s);
		if (!plain) {
			// The block print, worn: a frame, rows of marks and a disc, gone by a
			// hundred and fifty metres.
			vec2 q = vec2(u - 0.5, (s - 0.5) * h / max(w, 0.1));
			float box = max(abs(q.x) - 0.34, abs(q.y) - 0.36);
			// (A pennant is too long for it: it only keeps the disc.)
			float frame = v_kind > 0.5 ? 0.0 : 1.0 - smoothstep(0.006, 0.014, abs(box));
			// Lines of script: thin strokes on each line, broken up finely, the
			// lines themselves a little uneven.
			float row_y = (q.y + 0.012 * sin(q.x * 9.0 + seed * 20.0)) / 0.052;
			float stroke = 1.0 - smoothstep(0.1, 0.24, abs(fract(row_y) - 0.5));
			float gaps = smoothstep(0.38, 0.5, flag_noise(vec2(q.x * 46.0 + o.x, floor(row_y) * 3.1 + o.y)));
			float marks = v_kind > 0.5 ? 0.0 : stroke * gaps * (1.0 - smoothstep(-0.05, -0.03, box));
			float disc = 1.0 - smoothstep(0.1, 0.112, length(v_kind > 0.5 ? vec2(q.x, s * h / max(w, 0.1) - 0.5) : q));
			float ink = max(max(frame, marks * (1.0 - disc)), disc);
			float rub = smoothstep(0.3, 0.7, flag_noise(m * 1.7 + o.yx));
			c *= 1.0 - 0.34 * ink * rub * near * (1.0 - 0.6 * wear);
			// The seam along the rope.
			c *= mix(0.5, 1.0, smoothstep(0.015, 0.05, s));
		}
		// Grime in the folds and along the torn edge.
		c *= 1.0 - 0.34 * v_fold;
		c *= mix(1.0, 0.74, smoothstep(edge - 0.1, edge, s));
		ALBEDO = c;
		BACKLIGHT = c * 1.0;
		ROUGHNESS = 0.93;
		SPECULAR = 0.22;
	}
}
