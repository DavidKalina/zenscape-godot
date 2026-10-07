#[compute]
#version 450
// The unified cloud volume's march (scripts/cloud_volume.gd,
// scripts/cloud_volume_effect.gd): the near cloud sea's heaps and the
// towering cumulus as one body of cloud, marched at a quarter of the
// render's pixels (one of each 2x2 block a frame, in turn; the resolve
// fills in the rest) after the opaque pass, stopped by the scene's depth.
//
// Where the cloud stands is a weather map round the eye: the sea's baked
// heap-field and domes (scripts/sky_sea.gd `_bake`, red mass, green dome
// height) and its swells under the islands and round the ranges' feet
// (`_bake_swells`), plus each live tower's body (its baked signed-distance
// pair, scripts/sky_tower.gd `bake`, morphed by its rising). Both are
// swollen by the shared cauliflower noise (scripts/cumulus_noise.gd: red
// round bumps, green wisps), a finer octave near the eye, so the towers
// rise out of the sea as one continuous cloud.
//
// The light is not coloured here. Each pixel stores how much of each light
// term reached it (premultiplied by the cloud's coverage), and the
// composite (shaders/cloud_volume_composite.gdshader) colours them with the
// sky's own palettes (shaders/cumulus_light.gdshaderinc and the sea styles),
// so the art stays in Godot's shader language: A = (sky ambient, sun single
// scattering, sun multiple scattering, lining), B = (coverage, distance,
// height in the cloud, in-cloud glow). C holds the solid's distance at the
// pixel, for the resolve's depth-aware upsample.
//
// Light per sample: a short cone of taps toward the light (the sun, the
// moon at night) through a cheap version of the same density gives the
// optical depth, so the towers shade the sea and their own flanks; Beer's
// law plus two softer octaves stand in for multiple scattering; a powder
// term darkens the near side of a thick body; the islands' shadows fall on
// the heaps. The phase (forward silver lining, back glow) is per pixel and
// applied in the composite.
//
// Cost: the march leaps through clear air (over the heaps' envelope, out
// of every tower's box or far from its body), steps through cloud growing
// with distance, and stops when 3% of the light is left. Taps are only
// taken while the ray still shows much.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
	mat4 camera;        // world from view (basis, origin)
	vec4 lens;          // tan half fov x, tan half fov y, near, far
	vec4 eye;           // xyz, motion time
	vec4 sun;           // xyz the sun, w dull weather (zs_cloud.x)
	vec4 key;           // xyz the light on the cloud (sun, moon at night), w the glide's parting (zs_sea_flight.w)
	vec4 sea;           // floor y, tall, reach, sea strength
	vec4 sea2;          // eye xz, hand over share, has noise
	vec4 envelope_at;   // corner xy (drifting field), side, baked
	vec4 swells_at;     // corner xy (world), side, baked
	vec4 frame;         // frame index, towers, wakes, deep night (night under a clear sky)
	vec4 islands[8];    // x, z, reach, underside y
	vec4 tower_a[4];    // frame origin xyz (world), strength
	vec4 tower_b[4];    // box middle xyz (tower frame), morph
	vec4 tower_c[4];    // box half xyz, wane
	vec4 tower_d[4];    // noise shift xyz, lift
	vec4 tower_e[4];    // sea y, top y (tower frame), 0, 0
	vec4 wake_at[8];    // xyz, time laid
	vec4 wake_way[8];   // back to the previous point xyz, radius
} P;

layout(set = 0, binding = 1) uniform sampler2D envelope;
layout(set = 0, binding = 2) uniform sampler2D swells;
layout(set = 0, binding = 3) uniform sampler3D cauliflower;
layout(set = 0, binding = 4) uniform sampler2D scene_depth;
layout(set = 0, binding = 5) uniform sampler3D body0;
layout(set = 0, binding = 6) uniform sampler3D body1;
layout(set = 0, binding = 7) uniform sampler3D body2;
layout(set = 0, binding = 8) uniform sampler3D body3;
layout(rgba16f, set = 0, binding = 9) uniform restrict writeonly image2D out_a;
layout(rgba16f, set = 0, binding = 10) uniform restrict writeonly image2D out_b;
layout(r32f, set = 0, binding = 11) uniform restrict writeonly image2D out_depth;

// --- The sea's heaps (as shaders/sky_sea.gdshader) ---------------------------------
const vec2 DRIFT = vec2(0.6, 0.35) * 1.2;
const float SWELL = 22.0;
const float HEADROOM = 1.3;
const float TILE = 280.0;
const float LOBE = 32.0;
const float MID = 95.0;
const float MID_SWELL = 6.0;
const float WISP = 2.5;
const float FINE = 34.0;
const float FINE_SWELL = 4.0;
const float FINE_NEAR = 260.0;
const vec2 SOFT = vec2(1.5, 3.5);
const vec3 BOIL = vec3(0.72, -0.4, 0.42);
const float SEA_SIGMA = 0.18;
const float SLOPE = 1.6;
const float OVER = LOBE * 0.6 + WISP * 0.5 + MID_SWELL * 0.6 + FINE_SWELL * 0.6 + 2.0;
const vec2 NEAR_FADE = vec2(6.0, 45.0);

// --- The towers (as shaders/sky_tower.gdshader) ------------------------------------
const float T_TILE = 170.0;
const float T_SWELL = 44.0;
const float T_FINE = 46.0;
const float T_FINE_SWELL = 10.0;
const float T_FINEST = 15.0;
const float T_FINEST_SWELL = 1.8;
const float T_FINE_NEAR = 240.0;
const vec2 T_SOFT = vec2(2.5, 8.0);
const vec3 T_DRIFT = vec3(0.9, -0.7, 0.5);
const float ERODE = 30.0;
const float T_SIGMA = 0.1;
const float T_SIGMA_IN = 0.045;
const float T_REACH = T_SWELL * 0.6 + T_FINE_SWELL * 0.5 + 9.0;

// --- The march --------------------------------------------------------------------
const int STEPS = 112;
const vec2 STEP = vec2(2.0, 18.0);
const float STEP_GROW = 0.014;
// The light's cone: tap distances (m) toward it and their lengths.
const int TAPS = 5;
const float TAP_AT[5] = float[](4.0, 12.0, 28.0, 60.0, 125.0);
const float TAP_LEN[5] = float[](8.0, 10.0, 22.0, 42.0, 90.0);
// How strongly cloud toward the light shades (per metre of full density):
// cumulus_light's ZS_CUMULUS_SUN_SIGMA, on real optical depth now.
const float SUN_SIGMA = 0.028;
// How much cloud (m) a lobe's face turned from the light counts as lying
// toward it (shaders/sky_sea.gdshader FACE_SHADE).
const float FACE_SHADE = 70.0;
// How strongly the powder term darkens thin edges.
const float POWDER = 0.3;

const float WAKE_OPEN = 0.35;
const float WAKE_HOLD = 7.0;
const float WAKE_LIFE = 29.0;
const float WAKE_WIDEN = 1.5;
const float WAKE_WIDEN_TIME = 3.0;

// Which pixel of its 2x2 block a march pixel takes this frame.
ivec2 zs_block_offset(int frame) {
	int k = frame & 3;
	return k == 0 ? ivec2(0, 0) : (k == 1 ? ivec2(1, 1) : (k == 2 ? ivec2(1, 0) : ivec2(0, 1)));
}

float sstep(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

float wake_strength(float age) {
	if (age < 0.0 || age >= WAKE_LIFE) return 0.0;
	return sstep(0.0, WAKE_OPEN, age) * (1.0 - sstep(WAKE_HOLD, WAKE_LIFE, age));
}

float wake_radius(float laid, float age) {
	return laid * (1.0 + WAKE_WIDEN * sstep(0.0, WAKE_WIDEN_TIME, age)) * sqrt(wake_strength(age));
}

float wake_keep(vec3 p, float rag) {
	float keep = 1.0;
	int n = int(P.frame.z);
	for (int i = 0; i < n; i++) {
		float age = P.eye.w - P.wake_at[i].w;
		float s = wake_strength(age);
		if (s <= 0.0) continue;
		float rad = wake_radius(P.wake_way[i].w, age);
		vec3 b = P.wake_at[i].xyz;
		vec3 back = P.wake_way[i].xyz;
		vec3 a = b - back;
		float len2 = dot(back, back);
		float h = len2 > 1e-4 ? clamp(dot(p - a, back) / len2, 0.0, 1.0) : 1.0;
		float d = distance(p, a + back * h);
		keep = min(keep, 1.0 - s * (1.0 - sstep(rad * 0.5, rad * 1.1, d + (rag - 0.5) * rad * 0.9)));
	}
	return keep;
}

// The heaps' envelope: how high they stand over their feet (0 to 1).
float sea_rise(vec2 xz) {
	if (P.envelope_at.w < 0.5 || P.sea.w <= 0.0) return 0.0;
	vec2 drifted = xz + DRIFT * P.eye.w;
	vec2 baked = texture(envelope, (drifted - P.envelope_at.xy) / P.envelope_at.z).rg;
	float mass = baked.r * 2.0 - 1.0;
	float h = baked.g;
	float heap = sstep(-0.2, 0.3, mass);
	float lift = 0.0;
	float foot = 0.0;
	if (P.swells_at.w > 0.5) {
		vec2 s = texture(swells, (xz - P.swells_at.xy) / P.swells_at.z).rg;
		lift = s.r;
		foot = s.g;
	}
	heap = mix(heap, 1.0, lift * 0.85);
	heap = mix(heap, 1.0, 0.9 * foot);
	float rise = max(h * (0.35 + 0.65 * heap) - (1.0 - heap) * 0.55, 0.0);
	rise *= 1.0 + max(lift, foot) * SWELL / P.sea.y;
	float part = P.key.w;
	if (part > 0.0) {
		float fray = texture(cauliflower, vec3(drifted * 0.004, 0.37)).g * 18.0;
		float d = length(xz - P.sea2.xy) + fray;
		rise *= mix(1.0, sstep(part * 130.0, part * 130.0 + 45.0, d), sstep(0.0, 0.25, part));
	}
	return rise;
}

vec3 tower_box_mid(int i) { return P.tower_b[i].xyz; }
vec3 tower_box_half(int i) { return P.tower_c[i].xyz; }

float body_at(int i, vec3 local) {
	vec3 uvw = (local - P.tower_b[i].xyz) / (2.0 * P.tower_c[i].xyz) + 0.5;
	vec2 d;
	if (i == 0) d = texture(body0, uvw).rg;
	else if (i == 1) d = texture(body1, uvw).rg;
	else if (i == 2) d = texture(body2, uvw).rg;
	else d = texture(body3, uvw).rg;
	return mix(d.r, d.g, P.tower_b[i].w) + P.tower_c[i].w * ERODE;
}

// Distance (m) from a point in a tower's frame to its box, 0 inside.
float box_gap(int i, vec3 local) {
	vec3 q = abs(local - P.tower_b[i].xyz) - P.tower_c[i].xyz;
	return length(max(q, vec3(0.0)));
}

// A sample of the cloud: its density (0..1 per sigma), sigma, how far into
// it (m), its height in its own cloud (0 foot, 1 crown), and the wisps.
struct Sample {
	float density;
	float sigma;
	float inside;
	float h;
	float pocket;
};

// How far a ray may leap from `p` before it can meet cloud (0: step here).
float clear_ahead(vec3 p, vec3 rd, float level, float t) {
	float gap = 1e9;
	float top_y = P.sea.x + (P.sea.y + SWELL) * HEADROOM;
	float far = length(p.xz - P.eye.xz);
	if (P.sea.w > 0.0 && far < P.sea.z) {
		if (p.y < P.sea.x - 2.0) gap = rd.y < 0.0 ? 1e9 : (P.sea.x - 2.0 - p.y) / max(rd.y, 1e-4);
		else if (p.y > top_y) gap = rd.y > 0.0 ? 1e9 : (p.y - top_y) / max(-rd.y, 1e-4) + 0.5;
		else {
			float env = P.sea.x + P.sea.y * sea_rise(p.xz);
			float over = p.y - env - OVER;
			gap = over > 0.0 ? over / (abs(rd.y) + SLOPE * level) : 0.0;
		}
	}
	int towers = int(P.frame.y);
	for (int i = 0; i < towers; i++) {
		vec3 local = p - P.tower_a[i].xyz;
		float b = box_gap(i, local);
		if (b > 0.0) gap = min(gap, b + 0.5);
		else gap = min(gap, max(body_at(i, local) - T_REACH, 0.0));
	}
	return gap;
}

Sample cloud_at(vec3 p, float t, float immersed, bool fine) {
	Sample s = Sample(0.0, SEA_SIGMA, -1e3, 0.0, 0.5);
	float has_noise = P.sea2.w;
	// The sea's heaps.
	if (P.sea.w > 0.0) {
		float far = length(p.xz - P.eye.xz);
		float rise = sea_rise(p.xz);
		float env = P.sea.x + P.sea.y * rise;
		if (p.y < env + OVER && p.y > P.sea.x - 2.0 && far < P.sea.z) {
			vec3 boil = BOIL * P.eye.w;
			vec2 n = has_noise > 0.5 ? texture(cauliflower, (p + boil) / TILE).rg : vec2(0.45, 0.5);
			float hh = clamp((p.y - P.sea.x) / max(env - P.sea.x, 4.0), 0.0, 1.0);
			float lobe = sstep(0.0, 0.15, rise);
			float inside = env - p.y + lobe * (mix(0.4, 1.0, hh) * LOBE * (n.r - 0.45) + (n.g - 0.5) * WISP);
			if (has_noise > 0.5) {
				inside += lobe * MID_SWELL * (texture(cauliflower, (p + boil * 1.3 + 37.0) / MID).r - 0.45);
				float f = fine ? (1.0 - sstep(FINE_NEAR * 0.6, FINE_NEAR, t)) : 0.0;
				if (f > 0.0) inside += f * lobe * FINE_SWELL * (texture(cauliflower, (p + boil * 1.6 + 71.0) / FINE).r - 0.45);
			}
			float soft = mix(SOFT.y, SOFT.x, hh) * mix(0.5, 1.0, sstep(40.0, 300.0, t));
			float d = sstep(0.0, soft, inside) * mix(0.55, 1.0, sstep(0.3, 0.68, n.g));
			d *= sstep(P.sea.x - 1.0, P.sea.x + 10.0, p.y);
			// Handed over to the dome's sea far out, and thin low toward the
			// horizon, where the dome's veil is (shaders/sky_sea.gdshader).
			d *= 1.0 - sstep(P.sea.z * P.sea2.z, P.sea.z, far);
			vec3 to = normalize(p - P.eye.xyz);
			float veiled = sstep(-0.02, -0.16, to.y) * mix(1.0, sstep(-0.34, -0.66, to.y), P.frame.w);
			d *= mix(1.0, veiled, sstep(150.0, 700.0, t));
			d *= P.sea.w;
			if (d > 0.0) {
				s.density = d;
				s.inside = inside;
				s.h = hh;
				s.pocket = n.g;
			}
		}
	}
	// The towers.
	int towers = int(P.frame.y);
	for (int i = 0; i < towers; i++) {
		vec3 local = p - P.tower_a[i].xyz;
		if (box_gap(i, local) > 0.0) continue;
		float bd = body_at(i, local);
		if (bd > T_REACH) continue;
		float sea_y = P.tower_e[i].x;
		float span = max(P.tower_e[i].y - sea_y, 40.0);
		float h = clamp((local.y - sea_y) / span, 0.0, 1.0);
		vec3 boil = T_DRIFT * P.eye.w + P.tower_d[i].xyz - vec3(0.0, P.tower_d[i].w, 0.0);
		vec2 n = texture(cauliflower, (local + boil) / T_TILE).rg;
		float inside = mix(0.45, 1.0, h) * T_SWELL * (n.r - 0.45) - bd + (n.g - 0.5) * mix(8.0, 3.0, h);
		float pocket = n.g;
		float f = fine ? 1.0 - sstep(T_FINE_NEAR * 0.6, T_FINE_NEAR, t) : 0.0;
		if (f > 0.0) {
			vec2 fn = texture(cauliflower, (local + boil * 1.6 + 71.0) / T_FINE).rg;
			inside += f * (T_FINE_SWELL * (fn.r - 0.45) + T_FINEST_SWELL * (texture(cauliflower, (local + boil * 2.2 + 13.0) / T_FINEST).r - 0.45));
			pocket = mix(pocket, fn.g, 0.6 * f);
		}
		float soft = mix(T_SOFT.y, T_SOFT.x, h) * mix(0.5, 1.0, sstep(40.0, 300.0, t));
		float d = sstep(0.0, soft, inside) * mix(0.55, 1.0, sstep(0.3, 0.68, n.g));
		d *= mix(1.0, sstep(0.47, 0.64, pocket), immersed);
		d *= sstep(sea_y - 8.0, sea_y + 40.0, local.y);
		float wane = P.tower_c[i].w;
		float gone = clamp(wane * 1.4 + (1.0 - h) * 0.4 - 0.4, 0.0, 1.0);
		d *= sstep(gone * 0.75, gone * 0.75 + 0.2, n.g) * (1.0 - gone * gone);
		d *= P.tower_a[i].w;
		if (d > s.density) {
			s.density = d;
			s.sigma = mix(T_SIGMA, T_SIGMA_IN, immersed);
			s.inside = inside;
			s.h = h;
			s.pocket = pocket;
		} else {
			s.inside = max(s.inside, inside);
		}
	}
	if (s.density > 0.002 && int(P.frame.z) > 0) s.density *= wake_keep(p, s.pocket);
	return s;
}

// How much tower body lies far along the light from `p` (m of cloud): a
// few long taps through the towers' smooth bodies only, so a tower casts
// its shadow down onto the sea and onto its neighbours.
const int LONG_TAPS = 4;
const float LONG_AT[4] = float[](180.0, 260.0, 360.0, 480.0);
const float LONG_LEN = 90.0;
float tower_shade(vec3 p, vec3 key) {
	int towers = int(P.frame.y);
	if (towers == 0) return 0.0;
	float thick = 0.0;
	for (int k = 0; k < LONG_TAPS; k++) {
		vec3 q = p + key * LONG_AT[k];
		for (int i = 0; i < towers; i++) {
			vec3 local = q - P.tower_a[i].xyz;
			if (box_gap(i, local) > 0.0) continue;
			thick += sstep(10.0, -20.0, body_at(i, local)) * LONG_LEN * P.tower_a[i].w;
		}
	}
	return thick;
}

// The cheap form for light taps: how far into the cloud (m), no fine
// octaves, no wakes.
float inside_cheap(vec3 p) {
	float inside = -1e3;
	if (P.sea.w > 0.0 && length(p.xz - P.eye.xz) < P.sea.z * 1.1) {
		float rise = sea_rise(p.xz);
		float env = P.sea.x + P.sea.y * rise;
		if (p.y < env + OVER) {
			vec2 n = P.sea2.w > 0.5 ? texture(cauliflower, (p + BOIL * P.eye.w) / TILE).rg : vec2(0.45, 0.5);
			float hh = clamp((p.y - P.sea.x) / max(env - P.sea.x, 4.0), 0.0, 1.0);
			inside = env - p.y + sstep(0.0, 0.15, rise) * mix(0.4, 1.0, hh) * LOBE * (n.r - 0.45);
		}
	}
	int towers = int(P.frame.y);
	for (int i = 0; i < towers; i++) {
		vec3 local = p - P.tower_a[i].xyz;
		if (box_gap(i, local) > 0.0) continue;
		float bd = body_at(i, local);
		if (bd > T_REACH) continue;
		float span = max(P.tower_e[i].y - P.tower_e[i].x, 40.0);
		float h = clamp((local.y - P.tower_e[i].x) / span, 0.0, 1.0);
		vec3 boil = T_DRIFT * P.eye.w + P.tower_d[i].xyz - vec3(0.0, P.tower_d[i].w, 0.0);
		float nr = texture(cauliflower, (local + boil) / T_TILE).r;
		inside = max(inside, (mix(0.45, 1.0, h) * T_SWELL * (nr - 0.45) - bd) * P.tower_a[i].w);
	}
	return inside;
}

// How much of the sun an island keeps off a point (shaders/sky_sea.gdshader).
float island_shadow(vec3 p, vec3 sun) {
	float shade = 0.0;
	float up = max(sun.y, 0.25);
	for (int i = 0; i < 8; i++) {
		if (P.islands[i].z <= 0.0) break;
		vec2 at = p.xz + sun.xz / up * (P.islands[i].w - p.y);
		float d = length(at - P.islands[i].xy);
		shade = max(shade, 1.0 - sstep(P.islands[i].z * 0.55, P.islands[i].z * 1.25, d));
	}
	return shade;
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(out_a);
	if (any(greaterThanEqual(pixel, size))) return;
	// Each march pixel stands for a 2x2 block of the render; it marches
	// through one of the four, a different one each frame (the resolve
	// fills the render's every pixel in over four frames).
	ivec2 full_size = textureSize(scene_depth, 0);
	ivec2 full = min(pixel * 2 + zs_block_offset(int(P.frame.x)), full_size - 1);
	vec2 uv = (vec2(full) + 0.5) / vec2(full_size);
	vec3 view_dir = normalize(vec3((uv.x * 2.0 - 1.0) * P.lens.x, (1.0 - uv.y * 2.0) * P.lens.y, -1.0));
	vec3 rd = normalize(mat3(P.camera) * view_dir);
	vec3 ro = P.eye.xyz;

	// The solid's distance along the ray (reversed-Z depth, linearised).
	float d = texelFetch(scene_depth, full, 0).r;
	float near = P.lens.z;
	float far = P.lens.w;
	float t_solid = 1e9;
	if (d > 0.0) {
		float z = near * far / (near + d * (far - near));
		t_solid = z / max(-view_dir.z, 1e-4);
	}
	imageStore(out_depth, pixel, vec4(t_solid));

	// Where along the ray there is any cloud to march: the sea's slab out to
	// its reach, and each tower's box.
	float level = max(length(rd.xz), 1e-4);
	float t_in = 1e9;
	float t_out = 0.0;
	if (P.sea.w > 0.0) {
		float top_y = P.sea.x + (P.sea.y + SWELL) * HEADROOM;
		float bottom = P.sea.x - 2.0;
		float a, b;
		if (abs(rd.y) < 1e-4) {
			a = (ro.y < top_y && ro.y > bottom) ? 0.0 : 1e9;
			b = 1e9;
		} else {
			float ta = (top_y - ro.y) / rd.y;
			float tb = (bottom - ro.y) / rd.y;
			a = max(min(ta, tb), 0.0);
			b = max(ta, tb);
		}
		b = min(b, P.sea.z / level);
		if (b > a) {
			t_in = min(t_in, a);
			t_out = max(t_out, b);
		}
	}
	int towers = int(P.frame.y);
	for (int i = 0; i < towers; i++) {
		vec3 o = ro - P.tower_a[i].xyz;
		vec3 inv = 1.0 / (rd + vec3(equal(rd, vec3(0.0))) * 1e-6);
		vec3 lo = (P.tower_b[i].xyz - P.tower_c[i].xyz - o) * inv;
		vec3 hi = (P.tower_b[i].xyz + P.tower_c[i].xyz - o) * inv;
		vec3 n3 = min(lo, hi);
		vec3 f3 = max(lo, hi);
		float a = max(max(n3.x, n3.y), max(n3.z, 0.0));
		float b = min(min(f3.x, f3.y), f3.z);
		if (b > a) {
			t_in = min(t_in, a);
			t_out = max(t_out, b);
		}
	}
	t_out = min(t_out, t_solid);
	if (t_out <= t_in) {
		imageStore(out_a, pixel, vec4(0.0));
		imageStore(out_b, pixel, vec4(0.0));
		return;
	}

	// Blue-ish noise jitter on the start, new each frame (the temporal
	// resolve averages it away).
	float frame_index = P.frame.x;
	vec2 jp = vec2(pixel) + vec2(5.588238, 5.588238) * mod(frame_index, 64.0);
	float jitter = fract(52.9829189 * fract(dot(jp, vec2(0.06711056, 0.00583715))));

	vec3 key = normalize(P.key.xyz + vec3(0.0, 1e-4, 0.0));
	vec3 sun = normalize(P.sun.xyz + vec3(0.0, 1e-4, 0.0));
	float day_shadow = sstep(0.02, 0.2, sun.y) * (1.0 - sstep(0.35, 0.9, P.sun.w));

	// How deep in a tower the eye itself is: the fog round it glows.
	float immersed = 0.0;
	{
		Sample e = cloud_at(ro, 60.0, 0.0, false);
		if (e.sigma != SEA_SIGMA) immersed = sstep(-4.0, 24.0, e.inside);
	}

	float T = 1.0;
	vec4 acc_a = vec4(0.0);
	float met = 0.0;
	float crown = 0.0;
	float glow = 0.0;
	float t = t_in;
	bool started = false;
	// The face of the lobe the ray first meets (found once, as the near sea
	// did): a face turned from the light counts FACE_SHADE metres of cloud
	// toward it, so every billow has a lit side and a shaded one even where
	// nothing stands between it and the sun.
	bool faced = false;
	float turned = 1.0;
	for (int i = 0; i < STEPS; i++) {
		if (t >= t_out || T < 0.03) break;
		vec3 p = ro + rd * t;
		float gap = clear_ahead(p, rd, level, t);
		if (gap > 0.0) {
			t += clamp(gap, STEP.x, 400.0);
			continue;
		}
		float step = clamp(STEP.x + t * STEP_GROW, STEP.x, STEP.y);
		if (!started) {
			started = true;
			t += step * jitter;
			if (t >= t_out) break;
			p = ro + rd * t;
		}
		Sample s = cloud_at(p, t, immersed, true);
		// Close to the eye the sea thins away (the glide's vapour takes over).
		if (s.sigma == SEA_SIGMA) s.density *= sstep(NEAR_FADE.x, NEAR_FADE.y, t);
		if (s.density > 0.002) {
			// Toward the light: optical depth through a short cone of taps.
			float thick = 0.0;
			int taps = T > 0.15 ? (t < 900.0 ? TAPS : 3) : 2;
			for (int k = 0; k < taps; k++) {
				vec3 q = p + key * TAP_AT[k];
				float qi = inside_cheap(q);
				thick += sstep(0.0, 6.0, qi) * TAP_LEN[k];
			}
			if (!faced) {
				faced = true;
				float e = mix(6.0, 14.0, sstep(60.0, 900.0, t));
				float here = inside_cheap(p);
				vec3 grad = vec3(inside_cheap(p + vec3(e, 0.0, 0.0)), inside_cheap(p + vec3(0.0, e, 0.0)), inside_cheap(p + vec3(0.0, 0.0, e))) - here;
				if (dot(grad, grad) > 1e-6) turned = sstep(-0.15, 0.8, dot(-normalize(grad), key));
			}
			thick += (1.0 - turned) * FACE_SHADE;
			if (T > 0.1) thick += tower_shade(p, key);
			thick += island_shadow(p, sun) * day_shadow * 140.0;
			// Open overhead or under a bump.
			float up_open = 1.0;
			if (T > 0.3) {
				float above = inside_cheap(p + vec3(0.0, 12.0, 0.0));
				up_open = 1.0 - clamp((above - s.inside) / 12.0, 0.0, 1.0);
			}
			float deep = sstep(0.0, 35.0, s.inside);
			float beer = exp(-thick * SUN_SIGMA);
			// Softer octaves for the light scattered many times inside.
			float ms = 0.6 * exp(-thick * SUN_SIGMA * 0.35) + 0.3 * exp(-thick * SUN_SIGMA * 0.12) + 0.15 * exp(-thick * SUN_SIGMA * 0.05);
			// Powder: a thin edge facing the eye takes less of the sun than
			// the body behind it, so lobes read round, not cut out.
			float powder = mix(1.0, 1.0 - exp(-max(s.inside, 0.0) * 0.15), POWDER);
			// The terms of shaders/cumulus_light.gdshaderinc zs_cumulus_shade,
			// each its own channel so the composite colours them.
			float crease = mix(0.26, 1.0, up_open);
			float ambient = crease * mix(0.55, 1.0, s.h) * mix(1.0, 0.55, deep) * mix(1.0, 0.3, beer);
			float direct = beer * 0.88 * powder;
			float multi = (ms * 0.32 + exp(-thick * 0.004) * 0.1);
			float rim = (1.0 - sstep(0.1, 0.9, s.density)) * exp(-thick * 0.012) * 2.2;
			float alpha = 1.0 - exp(-s.density * s.sigma * step);
			float w = T * alpha;
			float in_cloud = s.sigma == SEA_SIGMA ? 0.0 : immersed;
			acc_a += w * (1.0 - in_cloud) * vec4(ambient, direct, multi, rim);
			glow += w * in_cloud * (0.85 + 0.3 * beer);
			met += w * t;
			crown += w * s.h;
			T *= 1.0 - alpha;
		}
		t += step;
	}
	float cover = 1.0 - T;
	imageStore(out_a, pixel, acc_a);
	imageStore(out_b, pixel, vec4(cover, met, crown, glow));
}
