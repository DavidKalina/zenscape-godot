shader_type spatial;
render_mode unshaded, blend_mix, cull_front, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// A towering cumulus (scripts/sky_towers.gd, scripts/sky_tower.gd), drawn
// as a volume marched through its box. Only the box's inside faces are
// drawn, and only to start the rays: each ray runs from the eye (or where
// it enters the box) to where it leaves, or to the scene's depth if
// something solid stands nearer, so the eye can be inside the cloud with
// no face to clip and nothing to sort.
//
// The body is the shape's smooth heap of lobes as a coarse grid of signed
// distances (`body`, metres). Far out of it the ray leaps by that distance;
// near it, it steps, finer near the eye. On the body the cauliflower
// swells: round bumps (`cauliflower` red, inverted cellular noise), bigger
// toward the crown and boiling slowly upward, a finer octave of them close
// to the eye, and soft wisps (green) fray the edge and leave pockets in the
// heart, which is what the eye sees streaming past inside.
//
// Light, as the glide's other clouds take it (shaders/sky_cloud_puff
// .gdshader): the sky's colour all round, cooler and dimmer low down and
// deep in; the sun's where the body toward the sun is thin (three looks
// along the sun through the grid), a soft glow of it everywhere (light
// scattered on through the cloud, so the heart glows rather than going
// grey), and a silver lining looking into the sun. At golden hour the
// sun's colour carries the gold.
//
// Into the glide's haze by how far off the cloud the ray met is
// (glide_haze.gdshaderinc, on a landform's gentler curve): its colour goes
// to the dome's own along the ray (zsSkyBase, with the sun's aureole), so a
// far tower melts into the sky behind it without going see-through (the
// sun never shows through it), and only near where the haze is whole does
// it thin away. Its foot thins into the cloud sea.
//
// Cost: two reads a step (the body, the noise), a third close to the eye,
// and eight more to light it (two pairs toward the sun near by, a pair
// overhead, two along the grid), the near pairs skipped once the ray is
// mostly spent. The ray stops
// once all but 3% of the light is gone.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/glide_haze.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"

uniform sampler3D body : filter_linear, repeat_disable;
uniform sampler3D cauliflower : filter_linear, repeat_enable;
// The body's box in the tower's frame: middle and half size. The box mesh
// stands at box_mid in the tower's frame.
uniform vec3 box_mid;
uniform vec3 box_half;
// The sea's top and the crown's top, the tower's frame.
uniform float sea = -105.0;
uniform float top = 300.0;
uniform float strength = 1.0;
uniform float haze_far = 1.0;
uniform vec3 noise_shift = vec3(0.0);
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

// How thick the cloud is (per metre at full density), and how it is lit
// along the sun.
const float SIGMA = 0.085;
const float SUN_SIGMA = 0.03;
const int STEPS = 56;
// The noise's tile (m) and how far its bumps swell the body (m); the finer
// octave's tile and swell, and how near the eye (m) it shows; how soft the
// edge is at the crown and the foot (m); how fast the crown boils up (m/s).
const float TILE = 170.0;
const float SWELL = 40.0;
const float FINE = 46.0;
const float FINE_SWELL = 10.0;
const float FINE_NEAR = 220.0;
const vec2 SOFT = vec2(3.0, 9.0);
const float RISE = 0.6;

float body_at(vec3 p) {
	return texture(body, (p - box_mid) / (2.0 * box_half) + 0.5).r;
}

// How far into the cloud a point is (m, below 0 outside): the body `d`
// swollen by the cauliflower `n` (red the bumps, green the wisps), bigger
// toward the crown (h, 0 at the sea to 1 at the top), and frayed.
float cloud_at(float d, vec2 n, float h) {
	return mix(0.4, 1.0, h) * SWELL * (n.r - 0.45) - d + (n.g - 0.5) * mix(9.0, 4.0, h);
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 seen = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 rd = normalize(seen - eye);
	// The tower's frame: the node stands at box_mid in it.
	vec3 frame = NODE_POSITION_WORLD - box_mid;
	vec3 ro = eye - frame;
	vec3 inv = 1.0 / (rd + vec3(equal(rd, vec3(0.0))) * 1e-6);
	vec3 a = (box_mid - box_half - ro) * inv;
	vec3 b = (box_mid + box_half - ro) * inv;
	vec3 near_ = min(a, b);
	vec3 far_ = max(a, b);
	float t_in = max(max(near_.x, near_.y), max(near_.z, 0.0));
	float t_out = min(min(far_.x, far_.y), far_.z);
	// Stopped by anything solid nearer.
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	t_out = min(t_out, length(behind.xyz / behind.w));
	if (t_out <= t_in) discard;

	float time = zs_motion_time;
	vec3 sun = normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0));
	float toward_sun = max(dot(rd, sun), 0.0);
	// The sun's colour on the cloud, warmed toward gold as it gets low.
	float golden = smoothstep(0.35, 0.05, sun.y) * smoothstep(-0.1, 0.02, sun.y);
	vec3 sun_col = zs_cloud_sun * mix(vec3(1.0), vec3(1.0, 0.62, 0.36) * 0.85, golden * 0.9);
	float lining = pow(toward_sun, 5.0) * 0.8 + pow(toward_sun, 30.0) * 1.5;
	vec3 boil = vec3(0.0, -time * RISE, 0.0) + noise_shift;
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float span = top - sea;
	float reach = SWELL * 0.6 + FINE_SWELL * 0.5 + 9.0;

	// How deep in the cloud the eye itself is: in it, the fog round it is
	// lit as the heart of a sunlit cloud is, a glowing white (gold at
	// golden hour), not as its shaded side seen from out in the air.
	float immersed = 0.0;
	if (t_in <= 0.0) {
		float h0 = clamp((ro.y - sea) / span, 0.0, 1.0);
		immersed = smoothstep(-4.0, 24.0, cloud_at(body_at(ro), texture(cauliflower, (ro + boil) / TILE).rg, h0));
	}

	float T = 1.0;
	vec3 lit = vec3(0.0);
	float met = 0.0;
	float t = t_in;
	bool started = false;
	for (int i = 0; i < STEPS; i++) {
		if (t >= t_out || T < 0.03) break;
		vec3 p = ro + rd * t;
		float d = body_at(p);
		if (d > reach) {
			// Far out of it: leap.
			t += max(d - reach, 3.0);
			continue;
		}
		float step = clamp(3.0 + t * 0.022, 3.0, 18.0);
		if (!started) {
			started = true;
			t += step * jitter;
			p = ro + rd * t;
			if (t >= t_out) break;
		}
		float h = clamp((p.y - sea) / span, 0.0, 1.0);
		vec2 n = texture(cauliflower, (p + boil) / TILE).rg;
		float inside = cloud_at(d, n, h);
		// The finer bumps, close to the eye only.
		float fine = 1.0 - smoothstep(FINE_NEAR * 0.6, FINE_NEAR, t);
		if (fine > 0.0) inside += fine * FINE_SWELL * (texture(cauliflower, (p + boil * 1.6 + 71.0) / FINE).r - 0.45);
		// Crisper close to the eye, so flying up to it the edge is never
		// a blur.
		float soft = mix(SOFT.y, SOFT.x, h) * mix(0.45, 1.0, smoothstep(40.0, 260.0, t));
		float density = smoothstep(0.0, soft, inside) * mix(0.45, 1.0, smoothstep(0.3, 0.68, n.g));
		// The foot thins into the cloud sea.
		density *= smoothstep(sea - 8.0, sea + 45.0, p.y);
		if (density > 0.002) {
			// Toward the sun: its own bump in the way close by (while the
			// ray still shows much): how much deeper in the cloud it gets
			// going sunward, so a bump's sunny face is lit and its far side
			// and underside shaded; then how much of the body lies beyond.
			float near_sun = 0.0;
			// And how open it is to the sky over it: a bump's top takes the
			// dome's light, its underside and the folds under the next bump
			// up are shaded, which is what models it on the shaded side.
			float up_open = 1.0;
			if (T > 0.3) {
				vec3 u = p + vec3(0.0, 10.0, 0.0);
				up_open = 1.0 - clamp((cloud_at(body_at(u), texture(cauliflower, (u + boil) / TILE).rg, h) - inside) / 14.0, 0.0, 1.0);
				vec3 q = p + sun * 8.0;
				near_sun = clamp(cloud_at(body_at(q), texture(cauliflower, (q + boil) / TILE).rg, h) - inside, 0.0, 30.0) * 0.9;
				q = p + sun * 22.0;
				near_sun += clamp(cloud_at(body_at(q), texture(cauliflower, (q + boil) / TILE).rg, h) - inside, 0.0, 40.0) * 0.7;
			}
			float o2 = clamp((-body_at(p + sun * 40.0) + 12.0) / 40.0, 0.0, 1.0);
			float o3 = clamp((-body_at(p + sun * 110.0) + 12.0) / 40.0, 0.0, 1.0);
			float thick = near_sun + o2 * 60.0 + o3 * 100.0;
			float sunlit = exp(-thick * SUN_SIGMA);
			// Light scattered on through the cloud: the heart glows.
			float glow = mix(exp(-thick * 0.004) * 0.12, 1.4 + 1.0 * exp(-thick * 0.006), immersed);
			// Open to the sky near the surface and high up; deep in and
			// low down, less so, and cooler.
			float open = mix(mix(0.72, 1.0, smoothstep(-40.0, 0.0, -inside)), 1.0, immersed);
			vec3 sky = zs_cloud_sky * mix(vec3(0.76, 0.84, 1.0), vec3(0.95, 0.97, 1.0), h) * mix(0.4, 0.85, h) * open * mix(mix(0.5, 1.2, up_open), 0.6, immersed);
			vec3 col = sky + sun_col * (sunlit * (0.85 + lining) + glow) * mix(0.6, 1.0, h);
			// Thinner round an eye inside, so the wisps and pockets show.
			float alpha = 1.0 - exp(-density * SIGMA * mix(1.0, 0.35, immersed) * step);
			lit += T * alpha * col;
			met += T * alpha * t;
			T *= 1.0 - alpha;
		}
		t += step;
	}
	float alpha = clamp((1.0 - T) / 0.97, 0.0, 1.0);
	if (alpha < 0.003) discard;
	float dist = met / max(1.0 - T, 1e-4);
	float haze = zs_glide_fog_far(dist, (ro + rd * dist + frame).y, haze_far) * zs_glide_haze.x;
	// The sky's own colour along the ray, its aureole round the sun.
	vec3 toward = normalize(vec3(rd.x, max(rd.y, 0.0) + 0.01, rd.z));
	float sun_away = sqrt(max(2.0 * (1.0 - dot(toward, sun)), 0.0));
	float high = smoothstep(0.02, 0.4, sun.y);
	vec3 air = zsSkyBase(toward) + mix(vec3(1.0, 0.42, 0.12), vec3(1.0, 0.8, 0.52), high) * exp(-sun_away / 0.16) * mix(0.16, 0.07, high) * zs_celestial_clear;
	ALBEDO = mix(lit / (1.0 - T), air, haze);
	ALPHA = alpha * (1.0 - smoothstep(0.8, 1.0, haze)) * strength;
}
