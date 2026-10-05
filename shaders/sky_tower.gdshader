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
// Light, in the glide's clouds' own colours (zs_cloud_sun, zs_cloud_sky)
// but with a painter's contrast: the sun's side takes the sun's hue (gold,
// peach at golden hour), kept under white so it never bleaches; the shaded
// side and the crevices between lobes the sky's cool lavender-blue, darker
// under a bump and deep in the body (a look overhead and a look toward the
// sun at each lobe, two more along the grid); thin edges against the sun
// a silver or gold lining. In the cloud the fog round the eye turns a
// bright, faintly sun-tinted white, never grey, and thins into drifting
// pockets and holes, so glimpses of sky and sunlit cloud open and close
// as it is flown through.
//
// Into the glide's haze by how far off the cloud the ray met is
// (glide_haze.gdshaderinc, on a landform's gentler curve): its colour goes
// to the dome's own along the ray (zsSkyBase, with the sun's aureole), so a
// far tower melts into the sky behind it without going see-through (the
// sun never shows through it), and only near where the haze is whole does
// it thin away. Its foot thins into the cloud sea.
//
// Cost: two reads a step (the body, the noise), two more close to the eye
// (the finer bumps), and up to six more to light it (a pair overhead and a
// pair toward the sun near the surface, two along the grid), the near
// pairs skipped once the ray is mostly spent. The ray stops once all but 3%
// of the light is gone.
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

// How thick the cloud is (per metre at full density) seen from outside
// and round an eye inside it, and how it is shaded along the sun.
const float SIGMA = 0.1;
const float SIGMA_IN = 0.045;
// The scene's exposure lifts what is drawn here about twice over: the
// cloud is lit at this share so its sunny side keeps the sun's hue rather
// than bleaching white; the fog round an eye inside it at GLOW.
const float LIT_SHARE = 0.46;
const float GLOW = 1.4;
const float SUN_SIGMA = 0.028;
const int STEPS = 56;
// The noise's tile (m) and how far its bumps swell the body (m); the finer
// octaves' tiles and swells, and how near the eye (m) they show; how soft
// the edge is at the crown and the foot (m); how fast the crown boils up
// and the pockets drift (m/s).
const float TILE = 170.0;
const float SWELL = 44.0;
const float FINE = 46.0;
const float FINE_SWELL = 10.0;
const float FINEST = 15.0;
const float FINEST_SWELL = 1.8;
const float FINE_NEAR = 240.0;
const vec2 SOFT = vec2(2.5, 8.0);
const vec3 DRIFT = vec3(0.9, -0.7, 0.5);

float body_at(vec3 p) {
	return texture(body, (p - box_mid) / (2.0 * box_half) + 0.5).r;
}

// How far into the cloud a point is (m, below 0 outside): the body `d`
// swollen by the cauliflower `n` (red the bumps, green the wisps), bigger
// toward the crown (h, 0 at the sea to 1 at the top), and frayed.
float cloud_at(float d, vec2 n, float h) {
	return mix(0.45, 1.0, h) * SWELL * (n.r - 0.45) - d + (n.g - 0.5) * mix(8.0, 3.0, h);
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
	float golden = smoothstep(0.35, 0.04, sun.y) * smoothstep(-0.1, 0.02, sun.y);
	// The sun's hue, deepened toward peach and gold as it gets low, at no
	// more than white; and the shade's cool lavender-blue off the sky.
	float sun_level = max(max(zs_cloud_sun.r, zs_cloud_sun.g), max(zs_cloud_sun.b, 1e-3));
	vec3 sun_hue = zs_cloud_sun / sun_level;
	sun_hue *= mix(vec3(1.0), vec3(1.0, 0.8, 0.66), golden);
	vec3 sun_col = sun_hue * min(sun_level, 1.0);
	vec3 shade_col = zs_cloud_sky * vec3(1.3, 1.02, 0.98) * 1.55;
	float lining = pow(toward_sun, 10.0) * 0.6 + pow(toward_sun, 60.0) * 1.6;
	vec3 boil = DRIFT * time + noise_shift;
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float span = top - sea;
	float reach = SWELL * 0.6 + FINE_SWELL * 0.5 + 9.0;
	// How deep in the cloud the eye itself is: in it, the fog round it is
	// lit as a sunlit cloud's heart is, a glowing white, and thins into
	// pockets.
	float immersed = 0.0;
	if (t_in <= 0.0) {
		float h0 = clamp((ro.y - sea) / span, 0.0, 1.0);
		immersed = smoothstep(-4.0, 24.0, cloud_at(body_at(ro), texture(cauliflower, (ro + boil) / TILE).rg, h0));
	}
	vec3 glow_col = mix(vec3(0.95, 0.97, 1.0), sun_hue, 0.3) * GLOW;

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
		float step = clamp(2.5 + t * 0.02, 2.5, 16.0);
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
		float pocket = n.g;
		if (fine > 0.0) {
			vec2 f = texture(cauliflower, (p + boil * 1.6 + 71.0) / FINE).rg;
			inside += fine * (FINE_SWELL * (f.r - 0.45) + FINEST_SWELL * (texture(cauliflower, (p + boil * 2.2 + 13.0) / FINEST).r - 0.45));
			pocket = mix(pocket, f.g, 0.6 * fine);
		}
		// Crisper close to the eye, so flying up to it the edge is never
		// a blur.
		float soft = mix(SOFT.y, SOFT.x, h) * mix(0.5, 1.0, smoothstep(40.0, 300.0, t));
		float density = smoothstep(0.0, soft, inside) * mix(0.55, 1.0, smoothstep(0.3, 0.68, n.g));
		// Round an eye inside: drifting pockets and holes.
		density *= mix(1.0, smoothstep(0.47, 0.64, pocket), immersed);
		// The foot thins into the cloud sea.
		density *= smoothstep(sea - 8.0, sea + 40.0, p.y);
		if (density > 0.002) {
			// Overhead and toward the sun, close by (while the ray still
			// shows much): how much deeper in the cloud it gets, so a
			// bump's top and sunny face are lit and its underside and far
			// side shaded; then how much of the body lies sunward.
			float up_open = 1.0;
			float near_sun = 0.0;
			if (T > 0.3) {
				vec3 u = p + vec3(0.0, 12.0, 0.0);
				up_open = 1.0 - clamp((cloud_at(body_at(u), texture(cauliflower, (u + boil) / TILE).rg, h) - inside) / 12.0, 0.0, 1.0);
				vec3 q = p + sun * 14.0;
				near_sun = clamp(cloud_at(body_at(q), texture(cauliflower, (q + boil) / TILE).rg, h) - inside, 0.0, 30.0);
			}
			float o2 = clamp((-body_at(p + sun * 40.0) + 12.0) / 40.0, 0.0, 1.0);
			float o3 = clamp((-body_at(p + sun * 110.0) + 12.0) / 40.0, 0.0, 1.0);
			float thick = near_sun * 1.2 + o2 * 60.0 + o3 * 100.0;
			float sunlit = exp(-thick * SUN_SIGMA);
			float deep = smoothstep(0.0, 45.0, inside);
			// The sky's light, less of it where the sun's is strong, so the
			// sunny side keeps the sun's hue.
			vec3 ambient = shade_col * mix(0.4, 1.0, up_open) * mix(0.55, 1.0, h) * mix(1.0, 0.7, deep) * mix(1.0, 0.3, sunlit);
			vec3 direct = sun_col * (sunlit * 0.88 + exp(-thick * 0.004) * 0.1);
			// A lining on thin edges against the sun.
			vec3 rim = sun_col * lining * (1.0 - smoothstep(0.1, 0.9, density)) * exp(-thick * 0.012) * 2.2;
			vec3 col = (ambient + direct + rim) * LIT_SHARE;
			// In it: bright, brightest looking toward the sun and where
			// the sun comes through thin cloud.
			col = mix(col, glow_col * (0.85 + 0.3 * sunlit + 0.7 * pow(toward_sun, 3.0)), immersed);
			float alpha = 1.0 - exp(-density * mix(SIGMA, SIGMA_IN, immersed) * step);
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
