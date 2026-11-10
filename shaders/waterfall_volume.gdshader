shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled, depth_draw_always, blend_mix;
// A waterfall as a thick body (study: studies/waterfall_study.tscn), marched
// inside a box by an ordinary spatial shader. It is a fluid, not a cloud: the
// body is solid and its front is one continuous surface (opaque, a hard
// silhouette), pushed out by a height over the plain front:
// - surges: fronts of denser water across the fall, in soft-shouldered
//   pieces several metres wide, each a blunt head trailing a tail that thins
//   upward; a front lags in broad curves and leads in points (chevrons
//   pointing down). They are carried down with the water, are born and die
//   partway down, and two layers at different speeds overtake each other.
//   Heads are the whitest; between surges the water is a little darker and
//   its streaks show more, so pulses read as bands travelling down;
// - veils: a broad slow bulge and lag across the face;
// - packets: small surges a metre or so wide on those, falling faster, the
//   face falling away below each over a long run (no ledge, no round lumps);
// - a few short gaps, mostly toward the foot and the sides.
// The streaking and the aerated roughness are shading only (a detail height
// that bends the normal, and the tone), not carved geometry: short streaks
// of three widths and a fine streaked grain, so the face reads as broken
// falling water, not as long combed lines. The fine parts fade with distance
// so they never alias into hatching.
// Over the lip the water is smooth and glassy and turns white within a few
// metres. The sides fray into lumps, more toward the foot. At the foot it
// explodes into a low, wide churn with a broken top and lobes thrown out and
// up, whose white runs on into the pool's foam
// (shaders/waterfall_pool.gdshader).
//
// The field is close to a distance (the front is a height over a plane, its
// slopes gentle), so the march steps by it and lands in a few steps; only in
// the churn, whose pieces are thin, does it keep to short steps.
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
// Surges: how wide a piece of a surge front is (m), how far apart the fronts
// come down (m), how far out a full surge bulges (m), and how far a front lags
// behind its leading points (in piece widths: the chevrons).
uniform float surge_width : hint_range(1.0, 12.0) = 5.0;
uniform float surge_spacing : hint_range(3.0, 30.0) = 11.0;
uniform float surge_bulge : hint_range(0.0, 3.0) = 1.0;
uniform float surge_chevron : hint_range(0.0, 3.0) = 0.8;
// The broad bulge and lag across the face (m).
uniform float veil_bulge : hint_range(0.0, 3.0) = 0.5;
// Packets on the surges: how far they stand out (m) and how wide one is (m).
uniform float clump_bulge : hint_range(0.0, 1.0) = 0.3;
uniform float packet_width : hint_range(0.5, 4.0) = 1.5;
// Metres per second the water falls at the lip.
uniform float fall_speed : hint_range(0.0, 30.0) = 9.0;
// How much faster it falls at the foot (pattern speed x (1 + fall_accel)).
uniform float fall_accel : hint_range(0.0, 4.0) = 1.6;
// How fast the shapes change as they fall.
uniform float churn_rate : hint_range(0.0, 3.0) = 0.9;
// How much the water comes apart toward the foot and the sides (short gaps).
uniform float breakup : hint_range(0.0, 1.0) = 0.35;
// How far (m) the sides fray in and out in lumps at the foot (less at the lip).
uniform float edge_break : hint_range(0.0, 4.0) = 1.4;
// Metres over the lip that the water stays smooth and glassy before it whitens.
uniform float lip_glass : hint_range(0.0, 8.0) = 3.0;
// Streaks along the fall and the aerated roughness, in the shading only.
uniform float streaks : hint_range(0.0, 1.0) = 0.5;
uniform float aeration : hint_range(0.0, 1.0) = 0.5;
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
// March: the shortest step (m) near the eye (grows past lod_distance; the
// steps are otherwise sized by the field), the most steps a ray takes.
uniform float step_len : hint_range(0.02, 1.0) = 0.1;
uniform float lod_distance = 35.0;
uniform int steps : hint_range(8, 128) = 64;
// Inside the water: how opaque each metre of water ahead of the eye is.
uniform float inside_density : hint_range(0.1, 10.0) = 1.4;
// World direction toward the sun.
uniform vec3 sun_dir = vec3(0.3, 0.7, 0.65);
uniform vec3 white_color : source_color = vec3(0.98, 0.99, 1.0);
uniform vec3 shade_color : source_color = vec3(0.50, 0.63, 0.76);
// The smooth water over the lip, before it whitens.
uniform vec3 glass_color : source_color = vec3(0.17, 0.31, 0.38);

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

float h21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// Cheaper value noise where a pattern needs only two dimensions, or one.
float vn2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float vn1(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(h21(vec2(i, 0.5)), h21(vec2(i + 1.0, 0.5)), f * f * (3.0 - 2.0 * f));
}

// Distance along the fall warped so patterns stretch (and speed up) toward
// the bottom.
float warp_by(float d, float a) {
	float k = a / max(front_z + lip_y, 1.0);
	return log(1.0 + k * d) / max(k, 0.0001);
}
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

// One layer of surges: fronts of denser water across the fall, one every
// `per` metres of the carried distance `u`. A front is not straight: it lags
// behind in broad curves and leads in sharp points (chevrons pointing down).
// Along a front the surge comes in pieces about `w` wide, each with soft
// shoulders. Behind its head a surge trails a tail that thins upward; below
// the head the face drops back. Each piece is born and dies somewhere along
// the fall (`s`). 0..1; `head` is how much of that is the head.
float surge_layer(float x, float u, float s, float w, float per, float seed, out float head) {
	float Ev = TIME * churn_rate;
	float ln = vn2(vec2(x * 0.55 / w + seed, Ev * 0.06 + seed * 0.3));
	float pn = vn2(vec2(x * 1.3 / w + seed * 2.0, Ev * 0.08 + seed + 1.0));
	float lag = surge_chevron * w * (abs(2.0 * ln - 1.0) + 0.7 * (1.0 - pn))
		+ 0.9 * vn2(vec2(x * 1.1 + seed, Ev * 0.25 + 2.0));
	float y = (u + lag) / per + seed * 0.37;
	float cyc = floor(y);
	float ph = fract(y);
	// The pieces along this front.
	float an = vn1(x / w + cyc * 13.71 + seed * 5.0);
	float amp = smoothstep(0.3, 0.6, an) * smoothstep(0.2, 0.55, pn);
	// Born at s0, gone by s0 + len (the pieces of a front differ a little).
	float bn = vn1(x * 0.06 + cyc * 5.1 + seed * 3.0 + 40.0);
	float s0 = bn * 40.0 - 16.0;
	float len = 18.0 + 24.0 * h31(vec3(cyc, seed, 4.0));
	float life = smoothstep(s0, s0 + 4.0, s) * (1.0 - smoothstep(s0 + len - 6.0, s0 + len, s));
	// No ledge under a head: the face falls away below it over a long run.
	float along = smoothstep(0.0, 0.7, ph);
	float hd = 1.0 - smoothstep(0.6, 1.0, ph);
	float g = amp * life;
	head = g * smoothstep(0.4, 0.7, ph) * hd;
	return g * along * sqrt(along) * hd;
}

// How far the front stands out (m) at a point of the fall: surges, veils,
// clumps and gaps. `sh` the surge heads (0..1), `gp` the gaps (0..1), `dens`
// how much surge water is there (0 between surges).
float body_h(float x, float s, float sw, float k, float e, float q, bool full, out float sh, out float gp, out float dens) {
	float T = TIME * fall_speed;
	float Ev = TIME * churn_rate;
	float u = sw - T;
	// Lanes wander, so they do not run in straight columns.
	float xw = x + 2.4 * (vn2(vec2(x * 0.09, u * 0.03 + Ev * 0.05)) - 0.5);
	float h1, h2;
	// Surges stretch less toward the foot than the rest (they stay pulses).
	float ss = s < 0.0 ? s : warp_by(s, fall_accel * 0.35);
	float Ts = T * (1.0 + fall_accel * 0.2);
	float l1 = surge_layer(xw, ss - Ts, s, surge_width, surge_spacing, 0.0, h1);
	// A second, faster layer of narrower surges overtakes the first.
	float l2 = surge_layer(xw + 1.9, ss - Ts * 1.25, s, surge_width * 0.7, surge_spacing * 0.75, 13.0, h2);
	sh = max(h1, h2 * 0.8);
	dens = clamp(l1 + 0.75 * l2, 0.0, 1.0);
	// Broad veils: the face bulges and lags as a whole.
	float veil = vn2(vec2(x * 0.1 + 5.0, (ss - Ts * 0.9) * 0.075 + Ev * 0.05)) - 0.5;
	// Smooth over the lip; the forms grow in over the first metres.
	float grow = smoothstep(0.5, lip_glass + 4.0, s);
	gp = 0.0;
	float hc = grow * (surge_bulge * (l1 + 0.75 * l2) + veil_bulge * veil * 2.0);
	// The most the clumps add; well clear of that, they need no working out.
	float clmax = grow * clump_bulge * 2.0;
	if (!full || hc + clmax - q < -0.3) {
		return hc + (full ? clmax : 0.0);
	}
	// Packets: small surges a metre or so wide, falling faster than the big
	// ones, each with a sharp underside and a short tail (not round lumps).
	float h3;
	float l3 = surge_layer(xw + 7.3, ss - Ts * 1.45, s, packet_width, packet_width * 3.0, 29.0, h3);
	sh = max(sh, h3 * 0.7);
	float cl = l3 * 1.6 + (vn2(vec2(xw * 1.7 + 8.0, (ss - Ts * 1.15) * 0.7 + Ev * 0.4)) - 0.5) * 0.5;
	// Short gaps, mostly low and by the sides.
	float gw = breakup * max(smoothstep(0.3, 1.0, k), 1.0 - smoothstep(0.0, 4.0, e));
	if (gw > 0.02) {
		float gn = vnoise(vec3(xw * 0.55 + 9.0, (ss - Ts * 1.15) * 0.3, Ev * 0.35 + 4.0)) * 0.75
			+ vn2(vec2(x * 2.1, (ss - Ts * 1.2) * 1.1 + Ev * 0.5)) * 0.25;
		gp = smoothstep(0.6, 0.85, gn) * gw;
	}
	return hc + grow * clump_bulge * cl * (0.6 + 0.4 * (l1 + l2)) - gp * 0.9;
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
		vec3 pa = P - pos + vel * 0.2;
		vec3 ba = vel * 0.2;
		float hh = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
		float life = age / per;
		float rad = (0.11 + 0.1 * r2) * (1.0 - 0.5 * life) * smoothstep(0.0, 0.08, life) * (0.45 + 0.55 * hh);
		best = max(best, rad - length(pa - ba * hh));
	}
	// Ragged, not round.
	if (best > -0.2) {
		best += (vnoise(P * 6.0 + vec3(0.0, -TIME * 7.0, TIME * 2.0)) - 0.5) * 0.12;
	}
	return best;
}

// The most the front stands out past q = 0 (m).
float h_max() {
	return surge_bulge * 1.75 + veil_bulge + clump_bulge * 2.5 + 0.1;
}

// Positive inside the water; about the distance to the surface (it may
// overstate it a little on steep lumps). `full` adds what the shadow tap does
// without: the packets and the churn (whose envelope is not a solid: in the
// tap it drew a thin dark line on the fall along the envelope's top).
float field_i(vec3 P, bool full, out vec4 info) {
	info = vec4(0.0, 0.0, 0.0, 1.0);
	float ax = abs(P.x);
	float lv = lip_var(P.x);
	float s, q, k;
	flow(P, lv, s, q, k);
	float sw = s < 0.0 ? s : warp(s);
	float T = TIME * fall_speed;
	float Ev = TIME * churn_rate;
	float u = sw - T;

	// The sides: width grows toward the foot and wanders as the water falls,
	// and frays in lumps, more toward the foot (only worked out near a side).
	float side = P.x < 0.0 ? 0.0 : 17.0;
	float hw = half_width + spread * pow(k, 1.4);
	float fr = edge_break * (0.2 + 0.8 * k) * smoothstep(0.0, 4.0, s);
	if (ax > half_width - edge_wobble * 1.3 - fr - 0.5) {
		hw += (vnoise(vec3(side, u * 0.16, Ev * 0.3)) - 0.5) * 2.0 * edge_wobble * (0.3 + k);
		float fn = vnoise(vec3(P.x * 0.55 + side, u * 0.2, q * 0.6 + Ev * 0.5));
		hw += (fn - 0.5) * 2.0 * fr;
	}
	float e = hw - ax;

	float hm = h_max();
	float v;
	if (q > hm) {
		// In the air in front of the water. (Biased, so the march steps into
		// the band the front can be in instead of creeping up to its edge.)
		v = hm - q - 0.4;
	} else if (q < -2.5) {
		// Deep in the body.
		v = 2.0;
	} else {
		float sh, gp, dn;
		float hb = body_h(P.x, s, sw, k, e, q, full, sh, gp, dn);
		v = hb - q;
		info = vec4(hb, sh, gp, dn);
	}
	v = min(v, e + 0.2);
	v = min(v, thickness + q);
	// Off the wall face below its top; over the top the water comes from
	// behind (the river above).
	v = min(v, P.z - (P.y > wall_top ? box_z0 - 50.0 : wall_gap));
	v = min(v, P.y + 0.05);

	// The churn at the foot: a low, wide body of water exploding on impact.
	// A core that keeps re-forming, a broken top of crisp pieces rising and
	// pushed out, and lobes thrown out and up that fall back.
	if (full && P.y < churn_height * 1.9 + 3.0) {
		float zf = front_z + (lv + 0.5) * lip_unevenness * 0.8 + throw_out;
		// Out from the impact (0 a little behind the front, 1 the outer edge);
		// the edge wanders, so it does not meet the pool in a line.
		float ro = (P.z - zf + 1.2) / max(churn_reach + 1.2, 0.1);
		ro += 0.12 * sin(P.x * 1.3 + TIME * 1.9) + 0.08 * sin(P.x * 3.7 - TIME * 2.6);
		float cw = clamp(e + 1.0, 0.0, 1.0);
		float rr = clamp(ro, 0.0, 1.0);
		float hmd = churn_height * cw * (1.0 - rr) * (1.0 - rr);
		float top = hmd * 1.55 + 0.05;
		float mv = min((ro + 0.2) * 2.0, (1.05 - ro) * 2.0);
		if (P.y > top || mv < v) {
			// Kept clear of zero: the envelope's top is not a surface, and a
			// ray skimming it at tiny steps ran out of them (a dotted dark
			// line on the fall along the top of the churn).
			mv = min(mv, (top - P.y) * 0.6 - 0.2);
		} else {
			// Pieces rising fast at the impact, pushed out as they go.
			// Ridged, so the pieces are thin sheets and crests, not lumps.
			vec3 cp = vec3(P.x * 1.5, P.y * 0.85 - TIME * 3.2, P.z * 1.5 - TIME * 1.8);
			float c1 = vnoise(cp);
			float c2 = vnoise(cp * 2.3 + vec3(3.0, -TIME * 2.0, 1.0));
			float n = (1.0 - abs(c1 * 2.0 - 1.0)) * 0.65 + c2 * 0.35;
			// The core is solid to about half the height; above it the noise
			// has to clear a bar that rises, so the top comes apart in pieces.
			float h01 = clamp((P.y - hmd * 0.45) / max(hmd * 1.1, 0.05), 0.0, 1.0);
			float pv = (n - (0.42 + 0.4 * h01)) * 0.7;
			mv = min(mv, max(pv, (hmd * (0.35 + 0.3 * c1) - P.y) * 0.6));
			mv = min(mv, (top - P.y) * 0.6);
		}
		v = max(v, mv);
		// Lobes thrown out and up from the impact, falling back.
		// (Not in the shadow taps: too small to matter there.)
		float jtop = churn_height * 0.6 + jet_speed * jet_speed * 0.08 + 0.4;
		if (jets > 0.0 && P.y < jtop && ro > -0.3 && ro < 1.4 && cw > 0.1 && v < 0.0) {
			float jf = jet_field(P, zf);
			v = max(v, min(jf, cw - 0.1));
		}
	}
	return v;
}

float field(vec3 P, bool full) {
	vec4 info;
	return field_i(P, full, info);
}

// The surface's fine relief, for the shading only: streaks along the fall
// (varied width, uneven spacing, short, carried down and changing) and the
// rough, aerated grain. `xw` is x with the streaks' uneven spacing in it
// (streak_x). The height (about 0..1) bends the light; `tex` is the middle
// streaks (x), the middle and fine ones faded with distance (y) and the
// grain (z), for the tone.
float streak_x(float x, float sw) {
	return x + 0.9 * vn2(vec2(x * 0.35, (sw - TIME * fall_speed) * 0.05 + TIME * churn_rate * 0.1));
}

float detail(float xw, float x, float sw, float q, float dist, out vec3 tex) {
	float T = TIME * fall_speed;
	float Ev = TIME * churn_rate;
	float b = vn2(vec2(xw * 4.3 + 3.0, (sw - T * 1.15) * 0.85 + Ev * 0.6));
	float f = vn2(vec2(xw * 11.0 + 5.0, (sw - T * 1.2) * 2.0 + Ev * 1.0));
	float c = vn2(vec2(xw * 15.0 + 7.0, (sw - T * 1.3) * 2.6 + Ev * 1.5 + q * 3.0));
	// Far off the fine parts fade to their mean (no shimmer, no hatching).
	float wf = 1.0 - smoothstep(12.0, 30.0, dist);
	float wb = 1.0 - smoothstep(25.0, 60.0, dist);
	tex.x = b;
	f = mix(0.5, f, wf);
	c = mix(0.5, c, wf);
	b = mix(0.5, b, wb);
	tex.yz = vec2(b * 0.5 + f * 0.5, c);
	// The relief that bends the light is the fine part only (the broad
	// streaks are tone): no drapes.
	return (b * 0.4 + f * 0.6) * streaks * 0.6 + c * aeration * 0.5;
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
	float colw = half_width + spread + edge_wobble * 1.3 + edge_break + 0.5;
	float colz = front_z + lip_unevenness * 0.8 + throw_out + h_max() + 0.2;
	float topy = lip_y + lip_unevenness * 0.5 + h_max() + 0.2;
	vec2 ia = slab(ro, inv, vec3(-colw, 0.0, wall_gap), vec3(colw, topy, colz));
	vec2 ic = slab(ro, inv, vec3(-colw, wall_top - 0.5, box_z0), vec3(colw, topy, colz));
	float chw = half_width + spread + edge_wobble * 1.3 + 1.0;
	float chz = front_z + lip_unevenness * 0.8 + throw_out + churn_reach + 0.6;
	float chy = churn_height * 1.9 + 3.0;
	// Below this the churn's pieces and the thrown lobes can be.
	float jtop = max(churn_height * 1.6, churn_height * 0.6 + jet_speed * jet_speed * 0.08 + 0.4);
	vec2 ib = slab(ro, inv, vec3(-chw, 0.0, wall_gap), vec3(chw, chy, chz));
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

	// Step by the field (about a distance), never shorter than the footprint
	// step, and in the churn (thin pieces, not a distance) never longer than
	// a short fixed one.
	float smin = step_len * max(1.0, t0 / max(lod_distance, 1.0));
	float t = t0 + smin * ign(FRAGCOORD.xy);
	float tp = t0;
	bool hit = false;
	for (int i = 0; i < 128; i++) {
		if (i >= steps || t > t1) break;
		vec3 ps = ro + rd * t;
		float v = field(ps, true);
		if (v > 0.0) {
			hit = true;
			break;
		}
		float lo = step_len * max(1.0, t / max(lod_distance, 1.0));
		float st = max(-v * 0.8, lo);
		if (ps.y < jtop) {
			st = min(st, max(lo * 2.0, v < -0.4 ? 0.3 : 0.2));
			// Near a churn piece: look between the last two samples, so thin
			// pieces at grazing angles are not stepped over.
			if (v > -0.15 && ps.y < churn_height * 1.6 && i > 0) {
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
		}
		tp = t;
		t += st;
	}
	if (!hit && inside <= 0.0) discard;

	vec3 col = white_color;
	float tw = lin;
	if (hit) {
		// Settle on the surface between the last miss and the first hit.
		for (int j = 0; j < 2; j++) {
			float tm = 0.5 * (tp + t);
			if (field(ro + rd * tm, true) > 0.0) t = tm; else tp = tm;
		}
		vec3 p = ro + rd * t;
		tw = t;

		// Normal from the field's gradient (the big forms).
		float ge = 0.1;
		vec4 info;
		float v0 = field_i(p, true, info);
		vec3 g = vec3(field(p + vec3(ge, 0, 0), true) - v0, field(p + vec3(0, ge, 0), true) - v0, field(p + vec3(0, 0, ge), true) - v0);
		vec3 n = -normalize(g + vec3(1e-5));

		float s, q, k;
		flow(p, lip_var(p.x), s, q, k);
		float sw = s < 0.0 ? s : warp(s);
		float hb = info.x;
		float sh = info.y;
		float gp = info.z;
		float dens = info.w;

		// The fine relief bends the normal: across the fall and down the flow.
		// Around the body: across the front, then back along a flank (so the
		// flanks are streaked down the fall too, not across).
		float xd = p.x + sign(p.x) * max(-q, 0.0) * smoothstep(half_width - 4.0, half_width, abs(p.x));
		vec3 tx0, tx1;
		float xw = streak_x(xd, sw);
		float d0 = detail(xw, xd, sw, q, t, tx0);
		// The streak tone: broad streaks and the middle ones, at any distance.
		float st0 = vn2(vec2(xw * 1.7, (sw - TIME * fall_speed * 1.1) * 0.38 + TIME * churn_rate * 0.3)) * 0.6 + tx0.x * 0.4;
		float fs0 = tx0.y;
		float ae0 = tx0.z;
		float dd = 0.06;
		float dx = detail(xw + dd, xd + dd, sw, q, t, tx1) - d0;
		float ds = detail(xw, xd, sw + dd, q, t, tx1) - d0;
		vec3 tf = cross(vec3(1.0, 0.0, 0.0), n);
		tf = dot(tf, tf) < 0.01 ? vec3(0.0, -1.0, 0.0) : normalize(tf);
		vec3 tx = cross(n, tf);
		// Less on the churn (its own shape carries it) and over the glassy lip.
		float churn_w = max(smoothstep(0.1, 0.6, q - hb) * (1.0 - smoothstep(churn_height * 0.6, churn_height * 1.3, p.y)),
			1.0 - smoothstep(0.1, 0.6, p.y));
		float glass = 1.0 - smoothstep(lip_glass * 0.4, lip_glass + 1.5, s + (st0 - 0.5) * 3.0);
		float bend = 2.6 * (1.0 - churn_w) * (1.0 - 0.4 * glass);
		n = normalize(n - (tx * dx + tf * ds) / dd * bend * 0.12);

		vec3 nw = normalize(mat3(MODEL_MATRIX) * n);
		vec3 L = normalize(sun_dir);
		vec3 Lf = normalize(transpose(mat3(MODEL_MATRIX)) * L);

		// Shadow: do the lobes and the lip's curve block the sun? One tap
		// of the coarse field.
		float occ = 0.0;
		vec3 so = p + n * 0.15;
		occ += 2.0 * smoothstep(-0.3, 0.3, field(so + Lf * 1.2, false));
		float sun = clamp(dot(nw, L) * 0.8 + 0.22, 0.0, 1.0) * (1.0 - 0.2 * occ);
		float sky = 0.5 + 0.5 * nw.y;
		float lit = clamp(sun * 0.8 + sky * 0.25, 0.0, 1.0);

		float T = TIME * fall_speed;
		float Ev = TIME * churn_rate;
		// Low, soft contrast: mostly the light on the big forms; darker only
		// in the gaps and deep between lobes; surge heads whiter; a broken
		// grain of aerated water; streaks a little lighter and darker.
		float fl = vnoise(vec3(p.x * 0.25, (sw - T * 1.2) * 0.12, Ev * 0.6));
		float shade = (1.0 - lit) * 1.0;
		// Between the lobes the water lies back and darker.
		shade += (1.0 - smoothstep(-0.2, surge_bulge * 0.8, hb)) * 0.12;
		shade += gp * 0.2 + clamp(-hb, 0.0, 1.5) * 0.12;
		// Between surges the water is thinner: a little darker, its streaks
		// show more. Surge heads are the whitest.
		shade += (1.0 - dens) * 0.16 - sh * 0.22;
		// Thin dark streaks of varied width, short and broken; broad streaks
		// only as a gentle tone.
		float far = smoothstep(15.0, 50.0, t);
		float dk = smoothstep(0.6, 0.72, mix(fs0, st0, far)) * mix(smoothstep(0.3, 0.6, st0), 1.0, far);
		shade += dk * streaks * (mix(0.38, 0.5, far) - 0.22 * dens) + (st0 - 0.5) * streaks * mix(0.25, 0.9, smoothstep(15.0, 60.0, t));
		float cr = 1.0 - abs(2.0 * ae0 - 1.0);
		shade += smoothstep(0.7, 0.85, ae0) * aeration * 0.13 - cr * cr * cr * aeration * 0.1;
		shade += (0.5 - fl) * flicker * 0.3;
		shade = max(shade, 0.0) * 0.9;
		// The churn: whiter than the fall, no fall streaks, shaded only by its
		// own shape; where it meets the pool it is the foam's white.
		float cs = (1.0 - lit) * 1.1 * smoothstep(0.1, 0.7, p.y);
		shade = mix(shade, cs, churn_w);
		shade = clamp(shade * shade_range, 0.0, 1.0);
		col = mix(white_color, shade_color, shade);

		// Over the lip: smooth, glassy water reflecting the sky, whitening as
		// it starts to fall.
		if (glass > 0.0) {
			vec3 vd = normalize(mat3(MODEL_MATRIX) * rd);
			vec3 rf = reflect(vd, nw);
			float fres = 0.15 + 0.85 * pow(1.0 - clamp(dot(-vd, nw), 0.0, 1.0), 4.0);
			vec3 skyc = mix(vec3(0.7, 0.8, 0.9), vec3(0.45, 0.62, 0.88), clamp(rf.y, 0.0, 1.0));
			vec3 gc = mix(glass_color * (0.75 + 0.35 * lit), skyc, fres) * (0.88 + 0.24 * st0);
			gc += vec3(1.0) * pow(clamp(dot(rf, L), 0.0, 1.0), 40.0) * 0.6;
			col = mix(col, gc, glass * (1.0 - churn_w));
		}
	}
	// The water between the eye and the surface, when the eye is in it, and
	// the front right at the eye when it is in the band at the front: there a
	// surface a hand's width away would fill the screen with one flat shade,
	// so close hits fade into the whiteout by their distance.
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
