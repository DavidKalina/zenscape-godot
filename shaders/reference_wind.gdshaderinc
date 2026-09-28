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
	if (dot(blow, blow) < 0.000001 && shiver <= 0.0) return vec3(0.0);
	float scale = length(model[1].xyz);
	float h = max(vertex.y - bend_from, 0.0);
	float span = max(height - bend_from, 0.05);
	float k = clamp(h / span, 0.0, 1.5);
	float bend = k * k;
	vec2 lean = blow * zs_blow_give(height * scale) * span * bend;
	// Canopies and blades shiver in the passing air: a quick flutter across it.
	float size = length(blow);
	vec2 across = size > 0.0001 ? vec2(-blow.y, blow.x) / size : vec2(0.0);
	lean += across * shiver * sin(zs_motion_time * 13.0 + h * 3.0 + phase * 5.0) * 0.06 * span * bend;
	float drop = min(dot(lean, lean) / (2.0 * max(h, 0.05)), h * 0.7);
	return inverse(mat3(model)) * vec3(lean.x, 0.0, lean.y) * scale + vec3(0.0, -drop, 0.0);
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
