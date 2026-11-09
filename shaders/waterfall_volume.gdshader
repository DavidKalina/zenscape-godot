shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled, depth_draw_always, blend_mix;
// A waterfall as a thick body (study: studies/waterfall_study.tscn), marched
// inside a box by an ordinary spatial shader. It is a fluid, not a cloud: the
// density is a solid body whose front is carved into ropes by noise stretched
// along the fall, so the first sample inside the water is the surface
// (opaque, a hard silhouette). The noise is carried down the fall at a speed
// that grows toward the foot, and it also changes as it goes, so strands tear,
// merge and split instead of sliding by. Toward the foot the body widens,
// frays and breaks into packets; at the foot it explodes into a low, wide
// churn with a broken top and lobes thrown out and up, whose white runs on
// into the pool's foam (shaders/waterfall_pool.gdshader).
//
// Depth: the hit is written to DEPTH and depth-tested by the hardware, so rock
// in front hides it and later transparent things sort against it. It draws in
// the transparent pass: one march per pixel, and the inside-the-water alpha
// works. It is not in the opaque depth texture, so effects that read that
// (a cloud composite, fog) do not see it. As an opaque material (drop
// blend_mix and ALPHA) it is marched twice, in the depth prepass and again in
// the colour pass, and the colour pass only draws where its depth matches the
// prepass's; the two compiled passes differ in the last bits, so scattered
// pixels fail and stay dark. Snapping the hit distance (t) to 5 cm before
// writing DEPTH makes them agree (tried, no dots); it also casts a shadow then.
//
// Inside the water (the plane flying through) the march starts in the body:
// the stretch of water ahead of the eye is a dense medium (alpha from its
// length), over whatever surface lies past it.
//
// Fall space: x across the fall (centred), y up from the pool (0 at the
// foot), z out from the wall (0 at the wall face). The mesh is a box of
// `box_size` whose back face is `box_z0` out from the wall (negative: back in
// the rock, hidden, so the water can come over the wall top), so its centre is
// at (0, box_size.y/2, box_z0 + box_size.z/2) from the node's origin; the
// node's origin is the wall face at the foot.

uniform vec3 box_size = vec3(42.0, 43.0, 16.0);
uniform float box_z0 = -6.0;
// The wall's top (m up from the foot): below it the water keeps `wall_gap`
// off the wall face; above it the water runs back over the top.
uniform float wall_top = 40.0;
uniform float wall_gap = 0.3;
// Half the width of the fall at the lip (m), the water's top over the lip (m
// up from the foot), the front of the falling water at the lip (m out from
// the wall).
uniform float half_width = 13.0;
uniform float lip_y = 41.2;
uniform float front_z = 4.0;
// How much wider each side is at the foot than at the lip (m).
uniform float spread : hint_range(0.0, 6.0) = 2.6;
// How far the sides wander in and out as the water falls (m).
uniform float edge_wobble : hint_range(0.0, 3.0) = 0.9;
// How uneven the lip is: the front bulges in tongues and the top dips (m).
uniform float lip_unevenness : hint_range(0.0, 2.0) = 1.0;
// How far the front leans out from the lip to the foot (m).
uniform float throw_out : hint_range(0.0, 4.0) = 1.4;
// Radius (m) of the curve where the water bends over the lip.
uniform float curve_radius : hint_range(0.5, 6.0) = 2.2;
// How deep the body is behind its front (m).
uniform float thickness : hint_range(0.5, 8.0) = 5.0;
// Strand columns per metre across the fall (bigger: finer ropes).
uniform float streak_scale : hint_range(0.5, 6.0) = 1.5;
// How much longer a strand is than it is wide, at the lip (it halves toward
// the foot, where the water comes apart).
uniform float streak_stretch : hint_range(2.0, 40.0) = 14.0;
// Metres per second the water falls at the lip.
uniform float fall_speed : hint_range(0.0, 30.0) = 9.0;
// How much faster it falls at the foot (pattern speed x (1 + fall_accel)).
uniform float fall_accel : hint_range(0.0, 4.0) = 1.6;
// How fast the strands change shape as they fall (tear, merge, split).
uniform float churn_rate : hint_range(0.0, 3.0) = 0.9;
// How far the front is carved into ropes (0 a smooth slab, 1 deeply ribbed).
uniform float surface_relief : hint_range(0.0, 1.0) = 0.8;
// How much the water comes apart toward the foot (gaps and packets).
uniform float breakup : hint_range(0.0, 1.0) = 0.65;
// Fine streaks along the fall over the ropes (0 none).
uniform float fine_streaks : hint_range(0.0, 1.0) = 0.55;
// Metres in from each side over which the body thins into separate strands.
uniform float edge_break : hint_range(0.0, 4.0) = 1.8;
// How far past the sides thin streams peel off (m at the foot).
uniform float peel_reach : hint_range(0.0, 5.0) = 2.6;
// Height (m) of the churn mound at the foot.
uniform float churn_height : hint_range(0.0, 8.0) = 2.4;
// How far the churn mound pushes out past the front (m).
uniform float churn_reach : hint_range(0.0, 6.0) = 3.2;
// How many of the lobes thrown out of the churn fly (0 none, 1 every throw), and
// how fast they leave it upward (m/s; a lobe rises speed^2/20 m).
uniform float jets : hint_range(0.0, 1.0) = 0.8;
uniform float jet_speed : hint_range(0.0, 10.0) = 6.0;
// White to pale blue-grey: how far down the shading goes.
uniform float shade_range : hint_range(0.0, 1.0) = 0.85;
// How much the brightness flickers down the fall.
uniform float flicker : hint_range(0.0, 1.0) = 0.5;
// March: metres per step near the eye (grows past lod_distance), the most
// steps a ray takes.
uniform float step_len : hint_range(0.05, 1.0) = 0.2;
uniform float lod_distance = 35.0;
uniform int steps : hint_range(8, 128) = 72;
// Inside the water: how opaque each metre of water ahead of the eye is.
uniform float inside_density : hint_range(0.1, 10.0) = 1.4;
// World direction toward the sun.
uniform vec3 sun_dir = vec3(0.3, 0.7, 0.65);
uniform vec3 white_color : source_color = vec3(0.98, 0.99, 1.0);
uniform vec3 shade_color : source_color = vec3(0.50, 0.63, 0.76);

varying vec3 v_local;
varying vec3 v_cam;

vec3 box_centre() {
	return vec3(0.0, box_size.y * 0.5, box_z0 + box_size.z * 0.5);
}

void vertex() {
	v_local = VERTEX + box_centre();
	v_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz + box_centre();
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

// Distance along the fall warped so patterns stretch (and speed up) toward
// the bottom.
float warp(float d) {
	float k = fall_accel / max(front_z + lip_y, 1.0);
	return log(1.0 + k * d) / max(k, 0.0001);
}

// The lip's unevenness at x: -0.5..0.5, fixed in place.
float lip_var(float x) {
	return 0.3 * sin(x * 0.31 + 1.7) + 0.14 * sin(x * 0.83 + 0.4) + 0.06 * sin(x * 2.1 + 2.2);
}

// The water's own frame at a point: s metres along the flow from where it
// leaves the wall, q metres out from the front surface (0 on it, negative
// inside), k how far down the fall (0 at the lip, 1 at the foot).
// Horizontal over the lip, a quarter circle, then down, leaning out.
void flow(vec3 P, float lv, out float s, out float q, out float k) {
	// Uneven only outward and upward, so the lip's rock never shows.
	float fz = front_z + (lv + 0.5) * lip_unevenness * 0.8;
	float ly = lip_y + (lv + 0.5) * lip_unevenness * 0.5;
	float yc = ly - curve_radius;
	float zc = fz - curve_radius;
	k = 0.0;
	if (P.y <= yc) {
		float d = yc - P.y;
		k = clamp(d / max(yc, 1.0), 0.0, 1.0);
		s = curve_radius * 1.5707963 + d;
		q = P.z - fz - throw_out * (1.0 - (1.0 - k) * (1.0 - k));
	} else if (P.z <= zc) {
		s = P.z - zc;
		q = P.y - ly;
	} else {
		vec2 d = vec2(P.z - zc, P.y - yc);
		q = length(d) - curve_radius;
		s = curve_radius * (1.5707963 - atan(d.y, d.x));
	}
}

// Lobes of water thrown from the impact: one per cell along the foot, each
// a short streak flying a ballistic arc out and up, thinning as it goes,
// then launched again (a cell sits some throws out). A point looks at its
// own cell and the nearer neighbour. Positive inside one.
float jet_field(vec3 P, float zf) {
	float best = -10.0;
	float cwid = 1.0;
	float fx = P.x / cwid;
	float ci = floor(fx);
	float side = fx - ci < 0.5 ? -1.0 : 1.0;
	for (int o = 0; o < 2; o++) {
		float c = ci + float(o) * side;
		float r0 = h31(vec3(c, 3.1, 7.7));
		float vy0 = jet_speed * (0.65 + 0.35 * r0);
		float per = 2.0 * vy0 / 9.8 + 0.1;
		float tt = TIME / per + r0 * 7.0;
		float cyc = floor(tt);
		float r2 = h31(vec3(c, cyc, 1.3));
		float r3 = fract(r2 * 7.31 + r0 * 3.7);
		if (r3 > jets) continue;
		float age = fract(tt) * per;
		float vy = vy0 * (0.75 + 0.5 * r2);
		vec3 o0 = vec3((c + 0.15 + 0.7 * r2) * cwid, churn_height * 0.6, zf - 0.4 + 1.2 * r3);
		vec3 v0 = vec3((r3 - 0.5) * 0.7, vy, 1.2 + 2.8 * fract(r2 * 3.17));
		vec3 pos = o0 + v0 * age - vec3(0.0, 4.9 * age * age, 0.0);
		vec3 vel = v0 - vec3(0.0, 9.8 * age, 0.0);
		vec3 pa = P - pos + vel * 0.13;
		vec3 ba = vel * 0.13;
		float hh = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
		float life = age / per;
		float rad = (0.15 + 0.14 * r2) * (1.0 - 0.5 * life) * smoothstep(0.0, 0.08, life) * (0.45 + 0.55 * hh);
		best = max(best, rad - length(pa - ba * hh));
	}
	// Ragged, not round.
	if (best > -0.2) {
		best += (vnoise(P * 6.0 + vec3(0.0, -TIME * 7.0, TIME * 2.0)) - 0.5) * 0.12;
	}
	return best;
}

// Positive inside the water. `full` adds the fine detail (streaks, spray)
// that the shadow taps can do without.
float field(vec3 P, bool full) {
	float ax = abs(P.x);
	float lv = lip_var(P.x);
	float s, q, k;
	flow(P, lv, s, q, k);
	float sw = s < 0.0 ? s : warp(s);
	float T = TIME * fall_speed;
	float Ev = TIME * churn_rate;
	float cx = streak_scale;
	// Strands shorten toward the foot as the water comes apart.
	float st = streak_stretch * (1.0 - 0.5 * k);
	float u = sw - T;

	// The sides: width grows toward the foot and wanders as the water falls
	// (only worked out near a side; it changes nothing in the middle).
	float side = P.x < 0.0 ? 0.0 : 17.0;
	float hw = half_width + spread * pow(k, 1.4);
	if (ax > half_width - edge_wobble * 1.3 - edge_break - 0.5) {
		hw += (vnoise(vec3(side, u * 0.16, Ev * 0.3)) - 0.5) * 2.0 * edge_wobble * (0.3 + k);
	}
	float e = hw - ax;

	float carve = mix(1.6, 2.8, k);
	float bk = breakup * smoothstep(0.15, 1.0, k);
	// The most the packets push the front out.
	float bulge = bk * 1.6 + 0.05;
	float v;
	if (q > bulge) {
		// In the air in front of the water: no need for the rope noise.
		v = (bulge - q) * 0.5;
	} else if (q < -carve - 0.6 && e > edge_break + 0.1) {
		// Deep in the body, away from the sides: solid.
		v = 0.4;
	} else {
		// Ropes: two layers; the pattern is carried down and changes as it goes.
		vec3 a = vec3(P.x * cx, u * 0.62 * cx / st, q * cx * 0.8 + Ev);
		float na = vnoise(a) * 0.65 + vnoise(a * vec3(2.3, 2.3, 1.7) + 7.0) * 0.35;
		vec3 b = vec3(P.x * cx * 2.1 + 11.0, (sw - T * 1.25) * cx * 2.1 / st + 5.0, q * cx * 1.4 + 3.0 + Ev * 1.6);
		float nb = vnoise(b);
		float n = mix(na, nb, smoothstep(-2.4, -0.2, q));
		// By the sides the ropes are stacked front to back instead, so the
		// flank (seen from the side) is strands, not one smooth face.
		float ew = 1.0 - smoothstep(0.0, edge_break + 0.8, e);
		if (ew > 0.0) {
			vec3 c = vec3(q * cx * 1.6 + 2.0, u * 0.9 * cx / st + 9.0, P.x * cx * 0.9 + Ev);
			float ns = vnoise(c) * 0.65 + vnoise(c * vec3(2.3, 2.3, 1.7) + 4.0) * 0.35;
			n = mix(n, ns, ew);
		}
		if (full) {
			// Fine streaks: thin, long, fast; they fray the strand ends.
			float f = vnoise(vec3(P.x * cx * 6.0, (sw - T * 1.15) * cx * 6.0 / (st * 2.2), Ev * 2.0 + q * 2.0));
			float f2 = vnoise(vec3(P.x * cx * 15.0 + 3.0, (sw - T * 1.2) * cx * 15.0 / (st * 4.0), Ev * 3.0 + q * 4.0));
			n += ((f - 0.5) * 0.5 + (f2 - 0.5) * 0.25) * fine_streaks;
		}
		// Packets: water arriving in clumps lower down, with gaps behind them.
		float pk = vnoise(vec3(P.x * cx * 0.45 + 31.0, (sw - T * 1.05) * 0.3, Ev * 0.7));

		// Carving: near the front the noise must clear a bar; the band
		// carved grows toward the foot.
		// Over the lip it is smooth (glassy), except near the sides, where a
		// clean tube would show edge-on from the side.
		float lipr = 0.4 * (1.0 - smoothstep(0.0, edge_break + 1.5, e));
		float thr = surface_relief * 0.7 * smoothstep(-carve, 0.0, q) * mix(lipr, 1.0, smoothstep(1.0, 7.0, s));
		thr += bk * (0.55 - pk) * 0.9 * smoothstep(-carve - 0.5, 0.0, q);
		// Sides: strands thin out toward the edge.
		thr = max(thr, 0.95 * (1.0 - smoothstep(0.0, max(edge_break, 0.01), e)));
		v = n - thr;
		// Packets bulge the front out a little.
		v = min(v, (bk * (pk - 0.35) * 2.4 - q) * 0.5);
	}
	v = min(v, (e + 0.2) * 0.5);
	v = min(v, (thickness + q) * 0.5);
	// Off the wall face below its top; over the top the water comes from
	// behind (the river above).
	v = min(v, (P.z - (P.y > wall_top ? box_z0 - 50.0 : wall_gap)) * 2.0);
	v = min(v, P.y * 2.0 + 0.05);

	// Streams that peel off past the sides, drifting out as they fall.
	float pw = peel_reach * k;
	if (k > 0.05 && e < 0.5 && e > -pw - 1.0) {
		float xo = -e;
		float drift = xo - peel_reach * 0.6 * k * k;
		float cell = floor(drift / 1.1);
		float r = h31(vec3(cell, side, 4.0));
		float xc = (cell + 0.25 + 0.5 * h31(vec3(cell, side, 9.0))) * 1.1;
		float lane = vnoise(vec3(cell * 3.7 + side, u * 0.45, Ev * 0.8));
		float rad = (0.08 + 0.18 * r) * smoothstep(0.35, 0.7, lane);
		float sv = rad - length(vec2(drift - xc, (q + 0.6 + r) * 0.8));
		sv = min(sv, (pw + 0.3 - xo));
		v = max(v, sv);
	}

	// The churn at the foot: a low, wide body of water exploding on impact.
	// A core that keeps re-forming, a broken top of crisp pieces rising and
	// pushed out, and lobes thrown out and up that fall back.
	if (P.y < churn_height * 1.9 + 3.0) {
		float zf = front_z + (lv + 0.5) * lip_unevenness * 0.8 + throw_out;
		// Out from the impact (0 a little behind the front, 1 the outer edge);
		// the edge wanders, so it does not meet the pool in a line.
		float ro = (P.z - zf + 1.2) / max(churn_reach + 1.2, 0.1);
		ro += 0.12 * sin(P.x * 1.3 + TIME * 1.9) + 0.08 * sin(P.x * 3.7 - TIME * 2.6);
		float cw = clamp(e + 1.0, 0.0, 1.0);
		float rr = clamp(ro, 0.0, 1.0);
		float hm = churn_height * cw * (1.0 - rr) * (1.0 - rr);
		float top = hm * 1.55 + 0.05;
		float mv = min((ro + 0.2) * 2.0, (1.05 - ro) * 2.0);
		if (P.y > top || mv < v) {
			mv = min(mv, (top - P.y) * 0.6);
		} else {
			// Pieces rising fast at the impact, pushed out as they go.
			// Ridged, so the pieces are thin sheets and crests, not lumps.
			vec3 cp = vec3(P.x * 1.5, P.y * 0.85 - TIME * 3.2, P.z * 1.5 - TIME * 1.8);
			float c1 = vnoise(cp);
			float c2 = vnoise(cp * 2.3 + vec3(3.0, -TIME * 2.0, 1.0));
			float n = (1.0 - abs(c1 * 2.0 - 1.0)) * 0.65 + c2 * 0.35;
			// The core is solid to about half the height; above it the noise
			// has to clear a bar that rises, so the top comes apart in pieces.
			float h01 = clamp((P.y - hm * 0.45) / max(hm * 1.1, 0.05), 0.0, 1.0);
			float pv = (n - (0.42 + 0.4 * h01)) * 0.7;
			mv = min(mv, max(pv, (hm * (0.35 + 0.3 * c1) - P.y) * 0.6));
			mv = min(mv, (top - P.y) * 0.6);
		}
		v = max(v, mv);
		// Lobes thrown out and up from the impact, falling back.
		// (Not in the shadow taps: too small to matter there.)
		float jtop = churn_height * 0.6 + jet_speed * jet_speed * 0.08 + 0.4;
		if (full && jets > 0.0 && P.y < jtop && ro > -0.3 && ro < 1.4 && cw > 0.1 && v < 0.0) {
			float jf = jet_field(P, zf);
			v = max(v, min(jf, cw - 0.1));
		}
	}
	return v;
}

float ign(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

// Where a ray (in fall space) is inside box [lo, hi]: (t0, t1), t1 < t0 if never.
vec2 slab(vec3 ro, vec3 inv, vec3 lo, vec3 hi) {
	vec3 ta = (lo - ro) * inv;
	vec3 tb = (hi - ro) * inv;
	vec3 tmn = min(ta, tb);
	vec3 tmx = max(ta, tb);
	return vec2(max(max(tmn.x, tmn.y), max(tmn.z, 0.0)), min(min(tmx.x, tmx.y), tmx.z));
}

void fragment() {
	vec3 ro = v_cam;
	vec3 rd = normalize(v_local - v_cam);
	vec3 inv = 1.0 / (rd + vec3(1e-6));
	float hx = box_size.x * 0.5;
	// Two tighter boxes the water can be in: the falling column, and the
	// churn at the foot. March only their hull along the ray.
	float colw = half_width + spread + edge_wobble * 1.3 + peel_reach + 0.5;
	float colz = front_z + lip_unevenness * 0.8 + throw_out + 1.2;
	float topy = lip_y + lip_unevenness * 0.5 + 0.4;
	vec2 ia = slab(ro, inv, vec3(-colw, 0.0, wall_gap), vec3(colw, topy, colz));
	vec2 ic = slab(ro, inv, vec3(-colw, wall_top - 0.5, box_z0), vec3(colw, topy, colz));
	float chw = half_width + spread + edge_wobble * 1.3 + 1.0;
	float chz = front_z + lip_unevenness * 0.8 + throw_out + churn_reach + 0.6;
	vec2 ib = slab(ro, inv, vec3(-chw, 0.0, wall_gap), vec3(chw, churn_height * 1.9 + 3.0, chz));
	vec2 ab = slab(ro, inv, vec3(-hx, 0.0, box_z0), vec3(hx, box_size.y, box_z0 + box_size.z));
	float t0 = 1e9;
	float t1 = -1.0;
	if (ia.y > ia.x) { t0 = ia.x; t1 = ia.y; }
	if (ib.y > ib.x) { t0 = min(t0, ib.x); t1 = max(t1, ib.y); }
	if (ic.y > ic.x) { t0 = min(t0, ic.x); t1 = max(t1, ic.y); }
	t0 = max(t0, ab.x);
	t1 = min(t1, ab.y);
	if (t1 <= t0) discard;

	// Inside the water: the stretch ahead of the eye is a dense medium.
	float inside = 0.0;
	float lin = 0.0;
	if (t0 <= 0.0 && field(ro, true) > 0.0) {
		float ti = 0.0;
		float tl = 0.0;
		bool out_w = false;
		for (int i = 0; i < 24; i++) {
			tl = ti;
			ti += 0.25;
			if (ti >= t1) break;
			if (field(ro + rd * ti, true) <= 0.0) {
				out_w = true;
				break;
			}
		}
		// Settle on the way out, so the length (and the alpha) is smooth.
		if (out_w) {
			for (int j = 0; j < 5; j++) {
				float tm = 0.5 * (tl + ti);
				if (field(ro + rd * tm, true) > 0.0) tl = tm; else ti = tm;
			}
		}
		lin = ti;
		inside = 1.0 - exp(-lin * inside_density);
		t0 = ti;
	}

	float stp = step_len * max(1.0, t0 / max(lod_distance, 1.0));
	stp = max(stp, (t1 - t0) / float(steps));
	float t = t0 + stp * ign(FRAGCOORD.xy);
	float tp = t0;
	bool hit = false;
	float band = max(0.12, stp * 0.8);
	for (int i = 0; i < 128; i++) {
		if (i >= steps || t > t1) break;
		vec3 ps = ro + rd * t;
		float v = field(ps, true);
		if (v > 0.0) {
			hit = true;
			break;
		}
		// Near a surface: look between the last two samples, so thin strands
		// at grazing angles are not stepped over.
		// Only when the steps are long (far, or along the fall), or by the
		// sides where the strands are thin: elsewhere the plain steps are
		// already finer than a strand.
		if (v > -band && (stp > 0.3 || abs(ps.x) > half_width - edge_break - 0.5 || ps.y < churn_height)) {
			float h = (t - tp) / 3.0;
			for (int j = 1; j < 3; j++) {
				float tm = tp + h * float(j);
				if (field(ro + rd * tm, true) > 0.0) {
					t = tm;
					hit = true;
					break;
				}
			}
			if (hit) break;
		}
		tp = t;
		t += stp;
	}
	if (!hit && inside <= 0.0) discard;

	vec3 col = white_color;
	float tw = lin;
	if (hit) {
		// Settle on the surface between the last miss and the first hit.
		for (int j = 0; j < 3; j++) {
			float tm = 0.5 * (tp + t);
			if (field(ro + rd * tm, true) > 0.0) t = tm; else tp = tm;
		}
		vec3 p = ro + rd * t;
		tw = t;

		// Normal from the field's gradient.
		float ge = 0.07;
		float v0 = field(p, true);
		vec3 g = vec3(field(p + vec3(ge, 0, 0), true) - v0, field(p + vec3(0, ge, 0), true) - v0, field(p + vec3(0, 0, ge), true) - v0);
		vec3 n = -normalize(g + vec3(1e-5));
		vec3 nw = normalize(mat3(MODEL_MATRIX) * n);
		vec3 L = normalize(sun_dir);
		vec3 Lf = normalize(transpose(mat3(MODEL_MATRIX)) * L);

		// Shadow: do the ribs and the lip's curve block the sun? Three taps
		// of the coarse field.
		float occ = 0.0;
		vec3 so = p + n * 0.15;
		occ += field(so + Lf * 0.4, false) > 0.0 ? 1.0 : 0.0;
		occ += field(so + Lf * 1.0, false) > 0.0 ? 1.0 : 0.0;
		occ += field(so + Lf * 2.2, false) > 0.0 ? 1.0 : 0.0;
		float sun = clamp(dot(nw, L) * 0.9 + 0.15, 0.0, 1.0) * (1.0 - 0.8 * min(occ / 2.0, 1.0));
		float sky = 0.5 + 0.5 * nw.y;
		float lit = clamp(sun * 0.8 + sky * 0.2, 0.0, 1.0);

		float s, q, k;
		flow(p, lip_var(p.x), s, q, k);
		float sw = s < 0.0 ? s : warp(s);
		float T = TIME * fall_speed;
		float Ev = TIME * churn_rate;
		// Troughs: the deeper into the carved band, the darker.
		float carve = mix(1.6, 2.8, k);
		// Not on the flanks, where deep in is just the side of the body.
		float trough = (1.0 - smoothstep(-carve, -0.15, q)) * smoothstep(0.0, edge_break + 1.0, half_width + spread * pow(k, 1.4) - abs(p.x));
		// Brightness that flickers down the fall, and fine dark streaks.
		float fl = vnoise(vec3(p.x * streak_scale * 1.3, (sw - T * 1.2) * 0.45, Ev * 1.5));
		float fine = vnoise(vec3(p.x * streak_scale * 9.0, (sw - T * 1.1) * streak_scale * 9.0 / (streak_stretch * 2.5), Ev * 3.0));
		float shade = (1.0 - lit) * 1.35 + trough * 0.55;
		shade += (0.5 - fl) * flicker * 0.7 + smoothstep(0.55, 0.78, fine) * fine_streaks * 0.6 - 0.1;
		// The churn: whiter than the fall, no fall streaks, shaded only by its
		// own shape; where it meets the pool it is the foam's white.
		float zf = front_z + (lip_var(p.x) + 0.5) * lip_unevenness * 0.8 + throw_out;
		// Churn shading out in front of the fall's face, and at the very bottom.
		float cb = max(smoothstep(0.1, 0.6, q) * (1.0 - smoothstep(churn_height * 0.6, churn_height * 1.3, p.y)),
			1.0 - smoothstep(0.1, 0.6, p.y));
		float cs = (1.0 - lit) * 1.1 * smoothstep(0.1, 0.7, p.y);
		shade = mix(shade, cs, cb);
		shade = clamp(shade * shade_range, 0.0, 1.0);
		col = mix(white_color, shade_color, shade);
	}
	// The water between the eye and the surface, when the eye is in it, and
	// strands right at the eye when it is in the carved band at the front:
	// there a surface a hand's width away would fill the screen with one
	// flat shade (the rope noise blown up), so close hits fade into the
	// whiteout by their distance.
	float es, eq, ek;
	flow(ro, lip_var(ro.x), es, eq, ek);
	float eband = (1.0 - smoothstep(-0.2, 1.0, eq)) * step(abs(ro.x), half_width + spread + 1.0) * step(0.0, ro.y) * step(ro.y, lip_y);
	float wclose = hit ? eband * (1.0 - smoothstep(0.4, 3.5, tw)) : 0.0;
	if (inside > 0.0 || wclose > 0.0) {
		// Falling streaks on the whiteout, darker where the water ahead is thin.
		// (rd is in fall space: around the vertical, and up.)
		float az = atan(rd.x, rd.z) * 12.0;
		float wn = vnoise(vec3(az, rd.y * 2.0 + TIME * 4.0, 0.5));
		float wf = vnoise(vec3(az * 3.5, rd.y * 4.0 + TIME * 7.0, 1.5));
		vec3 ic = mix(white_color, shade_color, 0.1 + 0.3 * wn + 0.2 * smoothstep(0.55, 0.8, wf));
		col = hit ? mix(col, ic, max(inside, wclose)) : ic;
	}
	ALBEDO = col;
	ALPHA = hit ? 1.0 : inside;

	vec3 wp = (MODEL_MATRIX * vec4(ro + rd * max(tw, 0.15) - box_centre(), 1.0)).xyz;
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(wp, 1.0));
	DEPTH = clip.z / clip.w;
}
