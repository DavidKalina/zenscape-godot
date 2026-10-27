#include "res://shaders/reference_globals.gdshaderinc"
// The original wind.js two-octave gust field, advected by integrated air travel.
// All scenery samples the same world-space parcel of air.

float zs_noise_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float zs_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(zs_noise_hash(i), zs_noise_hash(i + vec2(1.0, 0.0)), f.x),
		mix(zs_noise_hash(i + vec2(0.0, 1.0)), zs_noise_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Each parcel rides its own heading (zs_puff_heading_N, set by the wind tool,
// scripts/wind_gust.gd), or the global wind when it has none. `push` is the
// pulse as a direction: each parcel along its heading, the clap ring outward.
// `breeze` leaves out the wind tool's parcels (those with a heading) and its
// burst's ring: foliage takes those as zs_blow_at, along their own way.
float zs_gust_pulse_core(vec2 position, float travel, bool breeze, out vec2 push) {
	float pulse = 0.0;
	push = vec2(0.0);
	vec4 parcels[6] = vec4[6](zs_puff_0, zs_puff_1, zs_puff_2, zs_puff_3, zs_puff_4, zs_puff_5);
	vec4 headings[3] = vec4[3](zs_puff_heading_0, zs_puff_heading_1, zs_puff_heading_2);
	for (int i = 0; i < 6; i++) {
		vec4 parcel = parcels[i];
		if (parcel.w <= 0.0) continue;
		vec4 pair = headings[i / 2];
		vec2 heading = (i % 2 == 0) ? pair.xy : pair.zw;
		bool headed = dot(heading, heading) > 0.25;
		if (breeze && headed) continue;
		vec2 dir = headed ? heading : zs_wind_direction;
		float age = travel - parcel.z;
		vec2 relative = position - (parcel.xy + dir * age);
		float along = dot(relative, dir);
		float across = dot(relative, vec2(-dir.y, dir.x));
		float shape = exp(-(along * along * 0.02778 + across * across * 0.07716));
		float life = smoothstep(0.0, 1.5, age) * (1.0 - smoothstep(30.0, 52.0, age));
		pulse += parcel.w * shape * life;
		push += dir * (parcel.w * shape * life);
	}
	if (breeze && zs_burst_a.w > 0.0) return pulse;
	vec2 out_from = position - zs_clap.xy;
	float distance = length(out_from) - zs_clap.z;
	float ring = zs_clap.w * exp(-distance * distance * (distance > 0.0 ? 0.17361 : 0.02041));
	push += out_from / max(length(out_from), 0.001) * ring;
	return pulse + ring;
}

float zs_gust_pulse_push(vec2 position, float travel, out vec2 push) {
	return zs_gust_pulse_core(position, travel, false, push);
}

float zs_gust_pulse_at(vec2 position, float travel) {
	vec2 push;
	return zs_gust_pulse_push(position, travel, push);
}

vec2 zs_gust_push_at(vec2 position, float travel) {
	vec2 push;
	zs_gust_pulse_push(position, travel, push);
	return push;
}

float zs_gust_parts_at(vec2 position, float travel, out float puff) {
	vec2 dir = zs_wind_direction;
	vec2 q = position - dir * travel;
	vec2 p = vec2(dot(q, dir), dot(q, vec2(-dir.y, dir.x))) * vec2(0.09, 0.20);
	float field = zs_noise(p) * 0.62 + zs_noise(p * 2.3 + vec2(3.7, 9.1 + travel * 0.05)) * 0.38;
	puff = zs_gust_pulse_at(position, travel);
	return min(1.0, field + puff);
}

float zs_gust_field_at(vec2 position, float travel) {
	float puff;
	return zs_gust_parts_at(position, travel, puff);
}

// The gust field foliage leans along the global wind with: the same field,
// less the wind tool's own air, which bends foliage its own way (zs_blow_at).
// With no wind-tool gust about it equals zs_gust_field_at exactly.
float zs_breeze_field_at(vec2 position, float travel) {
	vec2 dir = zs_wind_direction;
	vec2 q = position - dir * travel;
	vec2 p = vec2(dot(q, dir), dot(q, vec2(-dir.y, dir.x))) * vec2(0.09, 0.20);
	float field = zs_noise(p) * 0.62 + zs_noise(p * 2.3 + vec2(3.7, 9.1 + travel * 0.05)) * 0.38;
	vec2 push;
	return min(1.0, field + zs_gust_pulse_core(position, travel, true, push));
}

float zs_breeze_field(vec2 position) {
	return zs_breeze_field_at(position, zs_gust_distance);
}

// --- The wind tool's air for foliage (scripts/wind_gust.gd) -----------------
// Plants have no memory in a shader, so a gust's follow-through is written
// as a function of when its head passed: each point knows that time from the
// run's shape, and plays a damped swing from it. Keep in step with WindGust
// `blow_at`, its CPU mirror, and its WIND_UP, BUILD and FADE.
const float ZS_BLOW_WIND_UP = 0.14;
// The swing: 1 as the head arrives (rising over the 0.3 s before), then back
// past rest by about 29 % at 0.57 s and dying away (ZS_BLOW_RING rad/s,
// ZS_BLOW_DAMP 1/s): the spring-back and the sway after.
const float ZS_BLOW_RING = 5.5;
const float ZS_BLOW_DAMP = 2.2;
// Everything leans at most this far, in the lean's units (1 is a full head).
const float ZS_BLOW_MAX = 1.4;

float zs_blow_swing(float tau) {
	float after = max(tau, 0.0);
	return smoothstep(-0.3, 0.05, tau) * exp(-ZS_BLOW_DAMP * after) * cos(ZS_BLOW_RING * after);
}

// A run's air at share u of it: builds over 18 %, fades from 55 %.
float zs_blow_air(float u) {
	return mix(0.25, 1.0, smoothstep(0.0, 0.18, u)) * (1.0 - smoothstep(0.55, 1.0, u));
}

// A front running `along` a line (or out from a centre): its lean share at a
// point that far along, and how hard foliage there shivers. `run` is (s since
// release, run s, start m, travel m). The head eases out, from + travel *
// (1 - (1 - u)^2), so the time it passed a point inverts exactly. While the
// air draws back (the wind-up) foliage near the start leans back toward it.
float zs_blow_front(float along, vec4 run, float reach, out float shiver) {
	float k = clamp((along - run.z) / max(run.w, 0.001), 0.0, 1.0);
	float u = 1.0 - sqrt(1.0 - k);
	float tau = run.x - (ZS_BLOW_WIND_UP + u * run.y);
	float ends = smoothstep(run.z - 3.0, run.z, along) * (1.0 - smoothstep(reach, reach + 2.5, along));
	float amp = zs_blow_air(u) * ends;
	shiver = amp * smoothstep(-0.2, 0.1, tau) * exp(-1.2 * max(tau, 0.0));
	float draw_back = run.x < ZS_BLOW_WIND_UP ? sin(run.x / ZS_BLOW_WIND_UP * PI) * 0.25 * exp(-abs(along - run.z) * 0.25) : 0.0;
	return amp * zs_blow_swing(tau) - draw_back;
}

// The Feather's live wake (scripts/wind_gust.gd "The wake"): the air laid
// along the path the feather took, as it passed. Each point finds the nearest
// stretch of the path and leans along it by when the feather went by there:
// it stirs ZS_WAKE_LEAD s before, holds while the feather's air streams past
// (ZS_WAKE_HOLD s, easing a little), then lets go into the lanes' damped
// swing. It parts out from the path by ZS_WAKE_PART of its lean. Keep in step
// with WindGust `_wake_at` and its WAKE_HOLD, WAKE_LEAD and WAKE_PART.
const float ZS_WAKE_HOLD = 0.3;
const float ZS_WAKE_LEAD = 0.12;
const float ZS_WAKE_PART = 0.3;

float zs_wake_swing(float tau) {
	float after = max(tau - ZS_WAKE_HOLD, 0.0);
	return smoothstep(-ZS_WAKE_LEAD, 0.0, tau) * mix(1.0, 0.8, smoothstep(0.0, ZS_WAKE_HOLD, tau))
		* exp(-ZS_BLOW_DAMP * after) * cos(ZS_BLOW_RING * after);
}

vec2 zs_wake_at(vec2 p, float phase, out float shiver) {
	shiver = 0.0;
	int count = int(zs_wake_a.y + 0.5);
	if (count < 2 || p.x < zs_wake_c.x || p.y < zs_wake_c.y || p.x > zs_wake_c.z || p.y > zs_wake_c.w) return vec2(0.0);
	vec4 pts[12] = vec4[12](zs_wake_0, zs_wake_1, zs_wake_2, zs_wake_3, zs_wake_4, zs_wake_5, zs_wake_6, zs_wake_7, zs_wake_8, zs_wake_9, zs_wake_10, zs_wake_11);
	float best = 1e9;
	vec2 h = vec2(0.0);
	vec2 off = vec2(0.0);
	float when = 0.0;
	float strength = 0.0;
	for (int j = 0; j < 11; j++) {
		if (j + 1 >= count) break;
		vec4 a = pts[j];
		vec4 b = pts[j + 1];
		// b starts a new stroke: nothing joins it to the one before.
		if (b.w < 0.0) continue;
		vec2 ab = b.xy - a.xy;
		float len2 = dot(ab, ab);
		float s = len2 > 0.000001 ? clamp(dot(p - a.xy, ab) / len2, 0.0, 1.0) : 0.0;
		vec2 d = p - (a.xy + ab * s);
		float dist2 = dot(d, d);
		if (dist2 < best) {
			best = dist2;
			if (len2 > 0.000001) h = ab * inversesqrt(len2);
			off = d;
			when = mix(a.z, b.z, s);
			strength = mix(abs(a.w), b.w, s);
		}
	}
	if (dot(h, h) < 0.5) return vec2(0.0);
	float hw = max(zs_wake_a.z, 0.5);
	float lateral = 1.0 - smoothstep(0.6 * hw, 1.3 * hw, sqrt(best));
	if (lateral <= 0.0 || strength <= 0.0) return vec2(0.0);
	float tau = zs_wake_a.x - when;
	// Ahead of the feather the air only stirs, as it comes.
	vec2 feather = pts[min(count, 12) - 1].xy;
	float ahead = dot(p - feather, zs_wake_b.xy);
	if (tau < 0.2 && ahead > 0.0) tau = min(tau, -ahead / max(zs_wake_b.z, 2.0));
	vec2 side = vec2(-h.y, h.x);
	float across = dot(off, side);
	float part = sign(across) * smoothstep(0.0, 0.5 * hw, abs(across));
	float swirl = sin(when * 9.0 + dot(p, vec2(0.9, 1.3)) + phase) * 0.12;
	float s = strength * lateral * zs_wake_swing(tau);
	shiver = strength * lateral * smoothstep(-0.2, 0.1, tau) * exp(-1.2 * max(tau, 0.0));
	return (h + side * (part * ZS_WAKE_PART + swirl)) * s;
}

// The wind tool's lean at world x, z: a horizontal direction and size (0
// calm, about 1 where a full gust's head is), and how hard foliage there
// should shiver (0..1). `phase` varies it per plant.
vec2 zs_blow_at(vec2 p, float phase, out float shiver) {
	vec2 lean = vec2(0.0);
	shiver = 0.0;
	vec4 lane_a[4] = vec4[4](zs_blow_0_a, zs_blow_1_a, zs_blow_2_a, zs_blow_3_a);
	vec4 lane_b[4] = vec4[4](zs_blow_0_b, zs_blow_1_b, zs_blow_2_b, zs_blow_3_b);
	vec4 lane_c[4] = vec4[4](zs_blow_0_c, zs_blow_1_c, zs_blow_2_c, zs_blow_3_c);
	for (int i = 0; i < 4; i++) {
		vec4 c = lane_c[i];
		if (c.x <= 0.0) continue;
		vec2 h = lane_a[i].zw;
		vec2 side = vec2(-h.y, h.x);
		vec2 rel = p - lane_a[i].xy;
		float across = dot(rel, side);
		float lateral = 1.0 - smoothstep(0.75 * c.y, 1.35 * c.y, abs(across));
		if (lateral <= 0.0) continue;
		float along = dot(rel, h);
		float sh;
		float s = zs_blow_front(along, lane_b[i], c.z, sh) * c.x * lateral;
		// A little crosswise turbulence rides with the front.
		float swirl = sin(along * 1.3 - lane_b[i].x * 8.0 + phase) * 0.15;
		lean += (h + side * swirl) * s;
		shiver = max(shiver, sh * c.x * lateral);
	}
	if (zs_burst_a.w > 0.0) {
		vec2 rel = p - zs_burst_a.xy;
		float r = length(rel);
		vec2 out_dir = rel / max(r, 0.001);
		float sh;
		float s = zs_blow_front(r, vec4(zs_burst_a.z, zs_burst_b.xyz), zs_burst_b.w, sh) * zs_burst_a.w * smoothstep(0.2, 1.0, r);
		lean += out_dir * s;
		shiver = max(shiver, sh * zs_burst_a.w);
	}
	if (zs_aim_b.w > 0.5 && zs_aim_b.y > 0.0) {
		vec2 rel = p - zs_aim_a.xy;
		float tremble = sin(zs_motion_time * 9.0 + phase * 3.0 + length(rel) * 2.0);
		if (zs_aim_b.w < 1.5) {
			// Held still: pressure builds round the press, leaning out and
			// swirling round it, and everything under it trembles.
			float reach = max(zs_aim_b.x, 0.5);
			float r = length(rel);
			vec2 out_dir = rel / max(r, 0.001);
			float w = zs_aim_b.y * (1.0 - smoothstep(0.35 * reach, 1.15 * reach, r)) * smoothstep(0.1, 0.8, r);
			lean += (out_dir * (0.8 + 0.25 * tremble) + vec2(-out_dir.y, out_dir.x) * (0.45 + 0.15 * sin(zs_motion_time * 1.7 + r * 0.8))) * w;
			shiver = max(shiver, w);
		} else {
			// Dragging: the forming lane rustles and parts, most near the hand.
			vec2 h = zs_aim_a.zw;
			vec2 side = vec2(-h.y, h.x);
			float hw = max(zs_aim_b.z, 0.5);
			float along = dot(rel, h);
			float across = dot(rel, side);
			float lateral = 1.0 - smoothstep(0.6 * hw, 1.3 * hw, abs(across));
			float swept = zs_aim_b.x;
			float w = zs_aim_b.y * lateral * smoothstep(-1.5, 0.3, along) * (1.0 - smoothstep(swept, swept + 2.5, along))
				* (0.45 + 0.55 * smoothstep(swept - 6.0, swept, along));
			float part = sign(across) * smoothstep(0.0, 0.5 * hw, abs(across));
			lean += (h * 0.55 + side * (part * 0.5 + tremble * 0.15)) * w;
			shiver = max(shiver, w);
		}
	}
	float wake_shiver;
	lean += zs_wake_at(p, phase, wake_shiver);
	shiver = max(shiver, wake_shiver);
	float size = length(lean);
	if (size > ZS_BLOW_MAX) lean *= ZS_BLOW_MAX / size;
	return lean;
}

// How much of a plant of `height` (world m) gives to the lean: small plants
// lie over, big trees lean. The lean at a plant's tip is about this share of
// its height per unit of lean.
float zs_blow_give(float height) {
	return mix(1.0, 0.3, smoothstep(0.5, 3.0, height));
}

// A plant's bend under the wind tool, as an offset in its own (model) space:
// the part above `bend_from` (model units) of a plant `height` tall bends as
// a cantilever, most at the tip, keeping its length. `shiver` is how hard it
// should tremble; the bend already includes the tremble.
vec3 zs_blow_bend(vec3 vertex, mat4 model, float bend_from, float height, out float shiver) {
	vec2 root = model[3].xz;
	float phase = dot(root, vec2(0.43, 0.71));
	vec2 blow = zs_blow_at(root, phase, shiver);
	float h = max(vertex.y - bend_from, 0.0);
	float span = max(height - bend_from, 0.05);
	float k = clamp(h / span, 0.0, 1.5);
	float bend = k * k;
	// Trailing the block's dip (zs_heave): the tip lags, stretching or
	// shrinking the plant along its own up.
	vec3 heave = vec3(0.0, zs_heave * span * bend, 0.0);
	if (dot(blow, blow) < 0.000001 && shiver <= 0.0) return heave;
	float scale = length(model[1].xyz);
	vec2 lean = blow * zs_blow_give(height * scale) * span * bend;
	// Canopies and blades shiver in the passing air: a quick flutter across it.
	float size = length(blow);
	vec2 across = size > 0.0001 ? vec2(-blow.y, blow.x) / size : vec2(0.0);
	lean += across * shiver * sin(zs_motion_time * 13.0 + h * 3.0 + phase * 5.0) * 0.06 * span * bend;
	float drop = min(dot(lean, lean) / (2.0 * max(h, 0.05)), h * 0.7);
	return inverse(mat3(model)) * vec3(lean.x, 0.0, lean.y) * scale + vec3(0.0, -drop, 0.0) + heave;
}

// --- The ambient breeze (docs/scenic/breeze.md) -----------------------------
// What every plant does in the world's own air, between the wind tool's
// gusts. It leans downwind by zs_breeze, more in the gust field's patches and
// in slow gust bands rolling across the land, and low plants ride the
// meadow's long waves. Stiff at the root, it bends most at the tip, which
// lags the air there, sways round its lean at the plant's own pace and
// flutters. Everything rides the air's travel (zs_gust_distance) and
// zs_motion_time, so it is frame-rate independent and holds when paused.
//
// Flowers and other new plants: call zs_breeze_bend (model-space offset, as
// zs_blow_bend) or zs_breeze_offset (world metres) for the stem's bend, and
// add your own head nod or petal flutter from its `gust` and `bow`.

// The meadow's waves: metres between crests, their speed as a share of the
// air's travel, and the lean a crest adds per unit of breeze.
const float ZS_BREEZE_WAVE_LENGTH = 9.0;
const float ZS_BREEZE_WAVE_SPEED = 1.0;
const float ZS_BREEZE_WAVE = 0.42;
// Lean everywhere, and what a full gust patch adds, per unit of breeze.
const float ZS_BREEZE_BASE = 0.16;
const float ZS_BREEZE_GUST = 0.5;
// The lean eases off toward this (zs_blow_at's units: 1 lays a small plant
// over by about 45 degrees).
const float ZS_BREEZE_MAX = 0.9;
// Seconds a plant's tip lags the air at its root, per metre of plant.
const float ZS_BREEZE_LAG = 0.3;
// How far a plant sways round its lean, as a share of it.
const float ZS_BREEZE_SWING = 0.4;

float zs_breeze_air() {
	return clamp(zs_breeze, 0.0, 2.5);
}

// 0.6..1.5: slow gust bands, about 30 m along the wind and 18 m across,
// rolling downwind with the air. The stronger ones are the rarer.
float zs_gust_band_at(vec2 position, float travel) {
	vec2 dir = zs_wind_direction;
	vec2 q = position - dir * travel;
	vec2 p = vec2(dot(q, dir) * 0.035, dot(q, vec2(-dir.y, dir.x)) * 0.055) + vec2(17.3, 4.1);
	return 0.6 + 0.9 * smoothstep(0.42, 0.8, zs_noise(p));
}

// 0..1: how near a meadow wave's crest `root` stands, the air having
// travelled `travel` m. A train of crests `crest_length` m apart and a longer
// one 24 degrees across it roll downwind at `crest_speed` of the air's
// travel, bent by noise (shifted by `offset`), so the crests wander and swell
// rather than march in stripes. Soft-edged, with a clear trough.
float zs_wave_crest_at(vec2 root, float crest_length, float crest_speed, vec2 offset, float travel) {
	vec2 dir = zs_wind_direction;
	float along = dot(root, dir);
	float side = dot(root, vec2(-dir.y, dir.x));
	float wander = zs_noise(vec2(side * 0.11, along * 0.04) + offset) * 3.6;
	float a = 0.5 + 0.5 * sin((along - travel * crest_speed) * TAU / crest_length + wander);
	vec2 skew = vec2(dir.x * 0.9135 - dir.y * 0.4067, dir.x * 0.4067 + dir.y * 0.9135);
	float b = 0.5 + 0.5 * sin((dot(root, skew) - travel * crest_speed * 0.92) * TAU / (crest_length * 1.7) + wander * 0.6 + 1.3);
	return smoothstep(0.25, 0.95, a * 0.68 + b * 0.32);
}

// --- Gust fronts (scripts/shared/gust_fronts.gd, docs/scenic/gust-fronts.md) -------
// A front of stronger air rolling across the plate along its way. At a point
// it arrives fast, holds and lets go slowly, overshooting at the hit. Its
// line is ragged and its strength patchy across it. Keep in step with
// GustFronts `push` and `front_lean`, and their constants.
float zs_front_push(float fr_tau) {
	float fr_rise = smoothstep(-0.35, 0.25, fr_tau);
	if (fr_rise <= 0.0) return 0.0;
	float fr_after = max(fr_tau, 0.0);
	float fr_hold = exp(-max(fr_tau - 0.5, 0.0) / 2.2);
	float fr_ring = 0.4 * exp(-2.4 * fr_after) * sin(6.0 * fr_after);
	return fr_rise * (fr_hold + fr_ring);
}

// One front's lean at `p` along its own way, `lag` s behind the air there.
float zs_front_one(vec4 fr_a, vec4 fr_b, vec2 p, float lag) {
	if (fr_b.y <= 0.0) return 0.0;
	vec2 fr_dir = fr_a.zw;
	vec2 fr_rel = p - fr_a.xy;
	float fr_across = dot(fr_rel, vec2(-fr_dir.y, fr_dir.x));
	float fr_lateral = 1.0 - smoothstep(0.55 * fr_b.w, fr_b.w, abs(fr_across));
	if (fr_lateral <= 0.0) return 0.0;
	float fr_seed = fract(dot(fr_a.xy, vec2(0.137, 0.291)) * 7.31) * 40.0;
	float fr_ragged = (zs_noise(vec2(fr_across * 0.06, fr_seed)) - 0.5) * 8.0;
	float fr_tau = fr_b.x - lag - (dot(fr_rel, fr_dir) + fr_ragged) / fr_b.y;
	float fr_cell = 0.35 + 0.65 * smoothstep(0.2, 0.75, zs_noise(vec2(fr_across * 0.12 + 5.3, fr_seed * 1.7)));
	return fr_b.z * fr_lateral * fr_cell * zs_front_push(fr_tau);
}

// Every front's lean at `p`, along the wind (zs_wind_direction).
float zs_front_at(vec2 p, float lag) {
	return zs_front_one(zs_front_0_a, zs_front_0_b, p, lag) * dot(zs_front_0_a.zw, zs_wind_direction)
		+ zs_front_one(zs_front_1_a, zs_front_1_b, p, lag) * dot(zs_front_1_a.zw, zs_wind_direction);
}

// --- Breeze ribbons' wakes (scripts/breeze_ribbons.gd) ----------------------
// A ribbon bows what it passes over: a little ahead of its head, most just
// behind it, easing back down its trail over about a second, about 2 m to
// either side, and less the higher it flies. `lag` s puts a plant's tip
// where the head was then. Keep in step with BreezeRibbons WAKE and
// `wake_at`.
const float ZS_RIBBON_SPEED = 5.5;
float zs_ribbon_one(vec4 rw_head, float rw_lift, vec2 p, float lag) {
	float rw_s = length(rw_head.zw);
	if (rw_s <= 0.0001) return 0.0;
	vec2 rw_dir = rw_head.zw / rw_s;
	vec2 rw_rel = p - rw_head.xy;
	float rw_across = dot(rw_rel, vec2(-rw_dir.y, rw_dir.x));
	if (abs(rw_across) > 6.0) return 0.0;
	float rw_along = dot(rw_rel, rw_dir) + ZS_RIBBON_SPEED * lag;
	float rw_shape = rw_along > 0.0 ? exp(-rw_along * rw_along * 1.2) : exp(rw_along / (ZS_RIBBON_SPEED * 1.2));
	float rw_high = 1.0 - smoothstep(3.0, 7.0, rw_lift);
	return rw_s * rw_shape * exp(-rw_across * rw_across * 0.2) * rw_high * dot(rw_dir, zs_wind_direction);
}

float zs_ribbon_wake(vec2 p, float lag) {
	return zs_ribbon_one(zs_ribbon_0, zs_ribbon_lift_a.x, p, lag) + zs_ribbon_one(zs_ribbon_1, zs_ribbon_lift_a.y, p, lag)
		+ zs_ribbon_one(zs_ribbon_2, zs_ribbon_lift_a.z, p, lag) + zs_ribbon_one(zs_ribbon_3, zs_ribbon_lift_a.w, p, lag)
		+ zs_ribbon_one(zs_ribbon_4, zs_ribbon_lift_b.x, p, lag) + zs_ribbon_one(zs_ribbon_5, zs_ribbon_lift_b.y, p, lag)
		+ zs_ribbon_one(zs_ribbon_6, zs_ribbon_lift_b.z, p, lag) + zs_ribbon_one(zs_ribbon_7, zs_ribbon_lift_b.w, p, lag);
}

// The storm's gust front (storm_gust: zs_storm_lean; nothing when it's off).
#include "res://shaders/storm_gust.gdshaderinc"

// The breeze's lean at a plant's root, in zs_blow_at's units, `lag` s
// behind the air there. `wave` is how much of the meadow's waves it rides
// (0 trees, 1 grass), crests `crest_length` m apart rolling at `crest_speed`.
// `bow` 0..1: how far it is bowed, for the paling of bowed grass.
float zs_breeze_lean_wave(vec2 root, float lag, float wave, float crest_length, float crest_speed, out float bow) {
	float travel = zs_gust_distance - zs_gust_speed * lag;
	float g = zs_breeze_field_at(root, travel);
	float band = zs_gust_band_at(root, travel);
	float crest_now = wave > 0.0 ? zs_wave_crest_at(root, crest_length, crest_speed, zs_grass_offset, travel) : 0.0;
	float lean = zs_breeze_air() * (ZS_BREEZE_BASE + ZS_BREEZE_GUST * g * g + ZS_BREEZE_WAVE * crest_now * wave) * band;
	lean += zs_front_at(root, lag) + zs_ribbon_wake(root, lag) + zs_storm_lean(root, lag, 0.0);
	lean /= sqrt(1.0 + lean * lean / (ZS_BREEZE_MAX * ZS_BREEZE_MAX));
	bow = smoothstep(0.08, 0.6, lean);
	return lean;
}

float zs_breeze_lean_at(vec2 root, float lag, float wave, out float bow) {
	return zs_breeze_lean_wave(root, lag, wave, ZS_BREEZE_WAVE_LENGTH, ZS_BREEZE_WAVE_SPEED, bow);
}

// A plant's own sway pace in rad/s, from its bending length in metres:
// a 0.35 m tuft about 0.7 Hz, a 2 m crown 0.3 Hz, a 7 m spruce 0.16 Hz.
float zs_breeze_pace(float span) {
	return 2.6 / sqrt(max(span, 0.3));
}

// How much of the breeze a reference plant takes, from its sway amount
// (`sway_shape.z`, 0.05 a grass tuft or flower, 0.012 to 0.018 the stiff
// shrubs and reeds): stiff ones lean about half as far.
float zs_breeze_flex(float sway_amount) {
	return mix(0.45, 1.0, smoothstep(0.012, 0.05, sway_amount));
}

// How hard its tips flutter, from the same sway amount.
float zs_breeze_flutter(float sway_amount) {
	return clamp(sway_amount / 0.05, 0.3, 1.5);
}

// The breeze's bend of `vertex`, as a horizontal world offset in metres. The
// part above `bend_from` (model units) of a plant `height` tall bends as a
// cantilever, stiff at the root ((h / span)^2). Big plants give less
// (zs_blow_give^1.5: trunks barely move, crowns sway). The tip lags the root
// and sways round its lean with the tip a beat behind, a whip rather than a
// pendulum, and wanders a little across the wind. `flex` 0..1 is how much
// of the lean it takes; `flutter_share` (0 none, 1 a blade or leaf) a quick
// tremble in its outer part. `gust` out: 0..1, how hard the air is on it
// now; `bow`: 0..1, how far a wave or gust bows it.
// zs_breeze_offset with the lean already read (zs_breeze_lean_at), for a
// plant that reads it once for several uses: a meadow flower's stem and
// its head's nod share one, which halves the head's cost.
vec2 zs_breeze_offset_lean(vec3 vertex, mat4 model, float bend_from, float height, float flex, float flutter_share, float lean, out float gust) {
	vec2 root = model[3].xz;
	float scale = length(model[1].xyz);
	float span = max(height - bend_from, 0.05);
	float k = clamp(max(vertex.y - bend_from, 0.0) / span, 0.0, 1.5);
	float tall = height * scale;
	float span_m = span * scale;
	gust = clamp(lean / 0.6, 0.0, 1.0);
	float phase = dot(root, vec2(0.43, 0.71));
	float pace = zs_breeze_pace(span_m);
	float t = zs_motion_time;
	float swing = sin(t * pace + phase - k * 0.9) * 0.7 + sin(t * pace * 1.63 + phase * 1.7 - k * 1.3) * 0.3;
	float wander = sin(t * pace * 0.71 + phase * 2.3 - k * 0.6);
	float give = zs_blow_give(tall);
	// Trees give less than grass, but enough that a crown visibly answers
	// the air (was give^1.5, which held a spruce top to a sixth).
	float reach = give * flex * span_m * k * k;
	vec2 dir = zs_wind_direction;
	vec2 side = vec2(-dir.y, dir.x);
	vec2 offset = (dir * (1.0 + ZS_BREEZE_SWING * swing) + side * (0.22 * wander)) * lean * reach;
	if (flutter_share > 0.0) {
		float leaf = sin(t * 11.0 + phase * 5.0 + dot(vertex, vec3(5.1, 7.0, 3.7))) * smoothstep(0.55, 1.0, k);
		offset += side * leaf * (0.015 + 0.03 * gust) * zs_breeze_air() * min(tall, 1.0) * flutter_share;
	}
	return offset;
}

vec2 zs_breeze_offset(vec3 vertex, mat4 model, float bend_from, float height, float flex, float flutter_share, out float gust, out float bow) {
	vec2 root = model[3].xz;
	float scale = length(model[1].xyz);
	float span = max(height - bend_from, 0.05);
	float k = clamp(max(vertex.y - bend_from, 0.0) / span, 0.0, 1.5);
	float tall = height * scale;
	float span_m = span * scale;
	float wave = 1.0 - smoothstep(0.7, 1.8, tall);
	float lean = zs_breeze_lean_at(root, ZS_BREEZE_LAG * span_m * min(k, 1.0), wave, bow);
	return zs_breeze_offset_lean(vertex, model, bend_from, height, flex, flutter_share, lean, gust);
}

// zs_breeze_offset as an offset in the plant's own (model) space, like
// zs_blow_bend: the tip dips as it leans, keeping the plant's length.
vec3 zs_breeze_bend(vec3 vertex, mat4 model, float bend_from, float height, float flex, float flutter_share, out float gust, out float bow) {
	vec2 offset = zs_breeze_offset(vertex, model, bend_from, height, flex, flutter_share, gust, bow);
	float h = max(vertex.y - bend_from, 0.0) * length(model[1].xyz);
	float drop = min(dot(offset, offset) / (2.0 * max(h, 0.05)), h * 0.7);
	return inverse(mat3(model)) * vec3(offset.x, -drop, offset.y);
}

float zs_gust_field(vec2 position) {
	return zs_gust_field_at(position, zs_gust_distance);
}

float zs_wind_at(vec2 position) {
	return zs_wind_strength * (0.45 + 1.1 * zs_gust_field(position));
}

// Same spherical field as LocalWindField.sample_local. Temporal envelopes are
// computed once by the CPU and published, avoiding render/physics clock drift.
vec3 zs_local_wind(vec3 worldpos) {
	vec4 local_gust_centers[8] = vec4[8](zs_local_gust_origin_0, zs_local_gust_origin_1, zs_local_gust_origin_2, zs_local_gust_origin_3, zs_local_gust_origin_4, zs_local_gust_origin_5, zs_local_gust_origin_6, zs_local_gust_origin_7);
	vec4 local_gust_flows[8] = vec4[8](zs_local_gust_vector_0, zs_local_gust_vector_1, zs_local_gust_vector_2, zs_local_gust_vector_3, zs_local_gust_vector_4, zs_local_gust_vector_5, zs_local_gust_vector_6, zs_local_gust_vector_7);
	vec3 velocity = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		if (local_gust_centers[i].w <= 0.0 || local_gust_flows[i].w <= 0.0) continue;
		float weight = 1.0 - smoothstep(0.0, 1.0, length(worldpos - local_gust_centers[i].xyz) / local_gust_centers[i].w);
		velocity += local_gust_flows[i].xyz * local_gust_flows[i].w * weight;
	}
	return velocity;
}

vec3 zs_wind_vector_at(vec3 worldpos) {
	return zs_local_ambient_velocity + zs_local_wind(worldpos);
}
