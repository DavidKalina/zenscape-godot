shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded, shadows_disabled;
// The endless flight's sea (scripts/endless/endless_sea.gd), forked from the
// lower world's ocean (shaders/sky_ocean.gdshader, kept as `--water=old`).
//
// - Waves: a few Gerstner swells heave the sheet near the eye (and their
//   normal is worked out per pixel from the rest position), with two
//   scrolling noise-normal layers at three scales for the chop. Every layer
//   fades where it is finer than a pixel, into a rougher sheen.
// - Colour by the water's real depth: a baked map of the land's height round
//   the eye (`depth_map`), so the turquoise shelf and the deep blue read the
//   same from any height; the bed behind each pixel (the depth buffer) still
//   shows through the shallows.
// - Reflective: fresnel toward the hour's sky, the cloud field mirrored from
//   the clouds' shade map (zs_cloud_shadow), what stands on screen by a short
//   march, a soft sun path and a crisp, stylised glitter.
// - Foam: a broken line at the shore, bands rolling in over the shelf, a
//   touch on the steepest crests, and the plane's wake (a trail of its recent
//   points: a churned centre line and the two arms of a V spreading out).
// - Whitecaps that linger (sea_foam 1): a dense cap on the breaking crest,
//   then the foam it leaves, kept in a buffer round the eye
//   (shaders/endless_sea_foam.glsl), opening into marbled lace and fading.
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_tonemap.gdshaderinc"
#include "res://shaders/reference_lake_lighting.gdshaderinc"
#include "res://shaders/reference_lake_glint.gdshaderinc"
#include "res://shaders/cloud_volume_shadow.gdshaderinc"
global uniform vec3 zs_palette_water;
uniform sampler2D sea_screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D sea_depth : hint_depth_texture, filter_nearest, repeat_disable;

// The chop's normal maps (seamless noise, EndlessSea `_detail`).
uniform sampler2D detail_a : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_b : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// The detail layers' sizes (m a tile) and strengths.
uniform vec3 detail_size = vec3(46.0, 15.0, 4.6);
uniform vec3 detail_strength = vec3(0.16, 0.12, 0.08);
// Fine ripples: two more layers (m a tile, strength), faded out with the
// pixel's footprint so they never sparkle into noise at range.
uniform vec2 ripple_size = vec2(1.3, 0.55);
uniform vec2 ripple_strength = vec2(0.0, 0.0);
// How much of the detail slope the reflections see: the sky's mirror and
// fresnel (`calm_share`), the soft sun path (`path_share`). 1 = all of it.
uniform float calm_share = 0.5;
uniform float path_share = 0.2;

// The motion (EndlessSea, `--sea-motion=old` sets 0): 0 the rigidly
// scrolling layers and four Gerstner swells; 1 a live surface:
// - eight swells in two crossing trains (the second `swell_cross.x` rad off
//   the first, at `swell_cross.y` of its height), crests sharpened toward
//   `swell_peak` (1 = a cusp where they all line up), rising and falling
//   in wave groups (`swell_groups`, 0 = even);
// - the noise chop cross-faded between two copies that live `flow_cycle` s
//   each, so its lumps rise and fade as they drift instead of sliding;
// - packets of peaked wavelets (`wavelet_size` longest..shortest m,
//   `wavelet_strength`, crest sharpness `wavelet_peak`, headings spread
//   `wavelet_spread` rad round the wind, each living `wavelet_life` s per
//   sqrt m of length), crests running at deep-water speed, so they cross,
//   build and vanish;
// - the wind over the sea varying in broad patches (`wind_patches`: size m,
//   contrast) as well as the paws;
// - what each layer loses to the pixel's footprint widening the sun's
//   glitter into a soft sheen (`glitter_filter`).
uniform int sea_motion = 0;
uniform float swell_peak = 0.8;
uniform vec2 swell_cross = vec2(1.05, 0.6);
uniform float swell_groups = 0.9;
uniform float flow_cycle = 2.6;
uniform vec2 wavelet_size = vec2(2.5, 0.25);
uniform float wavelet_strength = 0.25;
uniform float wavelet_peak = 1.0;
uniform float wavelet_spread = 1.25;
uniform float wavelet_life = 1.6;
uniform vec2 wind_patches = vec2(380.0, 0.35);
uniform float glitter_filter = 1.0;
// How much the water's body brightens on slopes toward the sun (and darkens
// away), so the chop's shape reads where the sky's mirror is faint.
uniform float body_shade = 0.0;

// The body (EndlessSea, `--sea-body=old` sets 0): 1 a sea with mass:
// - a long swell (`body_swell.x` m a wave's height scale) in two crossing
//   trains and a wind sea along the steady wind (`body_wind`, steepness
//   `body_swell.y`), crests peaked toward `body_swell.z` with the squeeze
//   shared out so the sheet never folds; the whole heave out to `body_reach`
//   m (fading to `.y`), on a finer sheet near the eye;
// - stretches of glossy slick and rough water (`wind_patches` size): the wind
//   sea at `body_patch.x` of its height in a slick, `.y` in the rough, the
//   chop's contrast `.z`; whitecaps, darkness and gloss follow;
// - light across the wave: troughs at `body_value.x` of the body's light,
//   crests at `.y`; thin crests glowing `sss_color` with the sun behind them
//   (`sss_strength`);
// - whitecaps: born where the wind sea's crests are steepest (more in the
//   rough), left behind as the crest moves on, streaking downwind and fading
//   (`whitecaps`: amount, life s, streak).
// The swell is mirrored on the CPU (EndlessSea `height_at`) for the plane's
// skim, so its noise is a sine-free hash that reads the same there.
uniform int sea_body = 0;
uniform vec3 body_swell = vec3(0.85, 1.0, 0.9);
uniform vec2 body_wind = vec2(1.0, 0.0);
uniform vec2 body_reach = vec2(420.0, 800.0);
uniform vec3 body_patch = vec3(0.3, 1.3, 1.0);
uniform vec2 body_value = vec2(0.6, 1.2);
uniform vec3 sss_color : source_color = vec3(0.10, 0.80, 0.62);
uniform float sss_strength = 0.8;
uniform vec3 whitecaps = vec3(1.0, 2.2, 1.0);

// The foam (EndlessSea, `--sea-foam=old` sets 0): 1 whitecaps that linger.
// The crest's own cap is bright and dense for `foam_fresh` s; what it
// leaves is kept in a buffer round the eye (scripts/endless/sea_foam.gd,
// `foam_buffer` at `foam_at`: corner xz, side m, on), drifting downwind at
// `foam_flow.x` m/s and swirled at `.y` m/s by eddies `.z` m across, so a
// patch is pulled into streaks; it spreads (`foam_spread`: foam, churned
// water, m^2/s), opens from a solid cap into lace and veins over
// `foam_flow.w` s and fades over `whitecaps.y` s. Past the buffer the same
// trail is worked out per crest. Lace: `foam_lace` cell size m, how thick
// the veins stay, how far the cells are bent, the churned water's lift.
// `whitecaps.x` sets how many, as before; `foam_caps` where they start.
uniform int sea_foam = 0;
uniform sampler2D foam_buffer : filter_linear, repeat_enable;
uniform sampler2D foam_buffer_b : filter_linear, repeat_enable;
// Which of the ping-pong pair holds the newest foam.
uniform int foam_side = 0;
uniform vec4 foam_at = vec4(0.0);
uniform vec2 foam_drift = vec2(0.0);
uniform float foam_fresh = 0.5;
// Where caps start (the wind sea's height x its group, 0.72 in the body
// round), how many stand outside the gusts (0.25 then), and the least
// height a slick counts as (x its group), so slicks keep a few.
uniform vec3 foam_caps = vec3(0.42, 0.4, 0.5);
uniform vec4 foam_flow = vec4(0.45, 0.35, 14.0, 0.9);
uniform vec2 foam_spread = vec2(0.03, 0.3);
uniform vec4 foam_lace = vec4(2.8, 1.0, 1.0, 1.0);

// The land's height (world y) over a square round the eye: corner xz, side,
// on (EndlessSea `_depth`).
uniform sampler2D depth_map : filter_linear, repeat_disable;
uniform vec4 depth_at = vec4(0.0);
// Up a river's mouth the sea lies still (the depth map's green, LandField
// `calm_here`; river-mouths-handoff.md): its swell and its shore foam are
// taken away by this share there, and its colour reads the bed it sees.
uniform float river_calm = 1.0;
// ...and over this many m of water it fades in over what lies under it (the
// river's drawn water sinking under it), not on a line.
uniform float river_calm_fade = 2.0;
uniform float sea_level = -40.0;

// The water's colour by depth (m of water under the surface).
uniform vec3 tint_shallow : source_color = vec3(0.42, 0.90, 0.82);
uniform vec3 tint_mid : source_color = vec3(0.07, 0.52, 0.66);
uniform vec3 tint_deep : source_color = vec3(0.04, 0.27, 0.55);
uniform vec3 tint_abyss : source_color = vec3(0.02, 0.12, 0.36);
uniform vec4 tint_depths = vec4(1.5, 7.0, 22.0, 55.0);
uniform vec3 absorb = vec3(0.30, 0.075, 0.06);
uniform float bed_fade = 5.0;
uniform float water_light = 2.6;

// The swell's heading (world xz), its strength, and the chop's.
uniform vec2 swell_heading = vec2(0.8, 0.6);
uniform float swell = 1.0;
uniform float chop = 1.0;
uniform vec2 heave_reach = vec2(90.0, 150.0);
// Which waves the sheet holds and how far it heaves, by the distance from the
// eye (1) or from the sheet's middle (0, the earlier sea, which popped as
// the sheet jumped under the eye).
uniform int lod_from_eye = 1;
// How far the eye stands from the sheet's middle at most, each way (m: half
// its 64 m snap). A vertex's own reach (the larger of |x|, |z|) is never
// past its distance from the eye plus this, so the held waves are never
// finer than the sheet's cells; at the eye it is 1 m, as the middle was.
const float SNAP_SLACK = 32.0;
uniform vec2 paw_size = vec2(90.0, 55.0);
uniform float paws = 1.0;

// Reflection: the fresnel's floor and power, how much the cloud field is
// mirrored and the height (world y) it is taken at.
uniform float fresnel_floor = 0.05;
uniform float fresnel_power = 4.0;
uniform float cloud_mirror = 0.8;
uniform float cloud_mirror_y = 20.0;
uniform int mirror_steps = 12;
uniform vec2 mirror_march = vec2(2.5, 1.55);
uniform float mirror_calm = 0.4;
// The sun: its soft path, and the crisp glitter on the chop.
uniform float glint_share = 1.0;
uniform float glitter = 1.0;
uniform float cloud_shade = 1.0;
// The clouds' shade map's square as drawn this frame (corner xz, side, on;
// scripts/endless/endless_clouds.gd sets it). The sea draws with the see-
// through pass, after the clouds' passes have redrawn the map, while the
// global square (zs_cloud_shadow_at) is the one the solid land reads, drawn
// the frame before; read with that one, the sea's shade and mirrored cloud
// jumped a texel (23 m) for a frame each time the square moved, a flicker.
// w 0: the global.
uniform vec4 shade_square = vec4(0.0);
// The light through the crests facing the sun.
uniform float crest_glow = 0.5;

// Foam: at the shore (the line's depth, the bands' reach m deep), on the
// crests, and overall.
uniform float shore_foam = 0.7;
uniform float wash_depth = 7.0;
uniform float crest_foam = 0.6;
uniform float foam = 1.0;

// The wake: the plane's recent points (xz, the time it passed, strength),
// newest first, the clock, and the plane now (xz, strength, reach m).
const int WAKE_POINTS = 40;
uniform vec4 wake_points[40];
uniform int wake_count = 0;
uniform float wake_now = 0.0;
uniform vec4 wake_head = vec4(0.0);
uniform float wake = 1.0;
// How fast the V's arms ride out (m/s, from the plane's speed).
uniform float wake_spread = 6.0;
// 1: the water's depth (red 0..10 m, green 10..60 m), 2: foam cover,
// 6 (sea_foam 1): the lace's density, youth, buffer reach and churn, 7: the
// foam worked out per crest everywhere (no buffer).
uniform int debug_view = 0;

varying vec3 world_position;
varying vec2 rest_xz;

const int SWELLS = 4;
const float GRAVITY = 9.81;
const float DEEP = 1.0e4;

// The live swell (sea_motion 1): eight Gerstner waves in two crossing
// trains, each rising and falling in its own wave groups. The slope is the
// displaced sheet's (divided by its squeeze), so crests come out peaked and
// troughs broad and flat. `crest` is scaled to the old swell's range.
vec2 zs_swell_live(vec2 p, float t, float footprint, out vec3 shift, out float crest, out float rough) {
	const int N = 8;
	const float LENGTH[8] = float[8](64.0, 45.0, 33.0, 24.0, 17.5, 12.8, 9.4, 6.9);
	const float TRAIN[8] = float[8](0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0);
	const float TURN[8] = float[8](0.0, 0.0, 0.34, -0.22, -0.46, 0.62, 0.3, -0.8);
	const float STEEP[8] = float[8](0.05, 0.05, 0.055, 0.05, 0.055, 0.05, 0.045, 0.045);
	vec2 h0 = normalize(swell_heading);
	float cx = cos(swell_cross.x), sx = sin(swell_cross.x);
	vec2 h1 = vec2(cx * h0.x - sx * h0.y, sx * h0.x + cx * h0.y);
	// Wave groups: two broad fields riding each train at its group speed.
	vec2 g0p = vec2(dot(p, h0), dot(p, vec2(-h0.y, h0.x)));
	vec2 g1p = vec2(dot(p, h1), dot(p, vec2(-h1.y, h1.x)));
	float g0 = zs_noise((g0p - vec2(t * 4.5, 0.0)) / vec2(150.0, 260.0) + vec2(1.7, 5.3));
	float g1 = zs_noise((g1p - vec2(t * 3.8, 0.0)) / vec2(120.0, 210.0) + vec2(8.2, 2.6));
	float g2 = zs_noise(p / 70.0 + vec2(t * 0.02, 3.3));
	// The crests bend: a broad, slow warp of every wave's phase.
	float bend = (zs_noise(p / 95.0 + vec2(t * 0.01, 7.1)) - 0.5) * 3.0 + (zs_noise(p / 37.0 + vec2(2.4, t * 0.015)) - 0.5) * 1.2;
	vec2 slope = vec2(0.0);
	shift = vec3(0.0);
	float squeeze = 0.0;
	rough = 0.0;
	float wind = 0.6 + 0.4 * min(zs_wind_strength, 1.5);
	for (int i = 0; i < N; i++) {
		vec2 h = TRAIN[i] > 0.5 ? h1 : h0;
		float c = cos(TURN[i]), s = sin(TURN[i]);
		vec2 d = vec2(c * h.x - s * h.y, s * h.x + c * h.y);
		float k = TAU / LENGTH[i];
		// Each wave's own groups, a few lengths long along it and wider
		// across, riding at half its speed: crests that build and die off.
		vec2 along = vec2(dot(p, d), dot(p, vec2(-d.y, d.x)));
		float own = zs_noise((along - vec2(0.5 * sqrt(GRAVITY / k) * t, 0.0)) / (LENGTH[i] * vec2(2.6, 3.2)) + vec2(float(i) * 3.7, float(i) * 1.3));
		// Shaped so a crest often dies out entirely between its groups.
		float group = smoothstep(0.22, 0.78, mix(mix(TRAIN[i] > 0.5 ? g1 : g0, g2, 0.3), own, 0.7));
		group = mix(1.0, 0.12 + 1.6 * group * group, swell_groups);
		float share = TRAIN[i] > 0.5 ? swell_cross.y : 1.0;
		float steep = STEEP[i] * swell * wind * share * group;
		float held = 1.0 - smoothstep(LENGTH[i] * 0.06, LENGTH[i] * 0.18, footprint);
		float phase = dot(p, d) * k - sqrt(GRAVITY * k) * t + float(i) * 2.39 + bend * (0.6 + 0.15 * float(i));
		float a = steep / k;
		float q = clamp(swell_peak / (STEEP[i] * float(N)), 0.0, 2.5);
		float cp = cos(phase), sp = sin(phase);
		shift.xz += d * q * a * cp * held;
		shift.y += a * sp * held;
		slope += d * steep * cp * held;
		squeeze += q * steep * sp * held;
		rough += 0.5 * steep * steep * (1.0 - held * held);
	}
	crest = squeeze / max(swell_peak, 0.05) * 0.2;
	return slope / max(1.0 - squeeze, 0.12);
}

// A hash with no sine (so the CPU's mirror, EndlessSea, reads the same).
float zs_body_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float zs_body_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(zs_body_hash(i), zs_body_hash(i + vec2(1.0, 0.0)), f.x), mix(zs_body_hash(i + vec2(0.0, 1.0)), zs_body_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// How rough the sea is at `p`: 0 a glossy slick .. 1 a rough stretch, in
// broad patches drifting downwind.
float zs_body_rough(vec2 p, float t) {
	vec2 w = normalize(body_wind);
	vec2 a = vec2(dot(p, w), dot(p, vec2(-w.y, w.x))) - vec2(t * 1.5, 0.0);
	vec2 r = a / vec2(wind_patches.x, wind_patches.x * 0.7);
	float n = zs_body_noise(r + vec2(5.9, 1.3)) * 0.65 + zs_body_noise(r * 2.3 + vec2(2.2, 9.1)) * 0.35;
	return smoothstep(0.3, 0.7, n);
}

// The body's waves: a long swell in two trains (0, 1) and the wind sea (2).
const int BODY = 11;
const float BODY_LENGTH[11] = float[11](118.0, 86.0, 64.0, 74.0, 52.0, 28.0, 20.0, 14.5, 10.5, 7.6, 5.5);
const int BODY_TRAIN[11] = int[11](0, 0, 0, 1, 1, 2, 2, 2, 2, 2, 2);
const float BODY_TURN[11] = float[11](0.0, 0.16, -0.22, 0.0, 0.3, 0.0, 0.38, -0.32, 0.62, -0.55, 0.9);
// The swell's heights (m, by body_swell.x) and the wind sea's steepness.
const float BODY_SIZE[11] = float[11](0.45, 0.42, 0.38, 0.32, 0.28, 0.07, 0.068, 0.064, 0.06, 0.055, 0.05);

// One crest of wave `fi` (sea_foam 1): `k` 0 the crest that passed last
// (returns its fresh cap), 1 the one before; with `analytic` over 0 its
// trail goes into `trail` (density, youth).
float zs_cap_crest(vec2 p, vec2 d, float L, float fi, float since, float id, float period, float chance, float soft, float fine, float footprint, vec2 hw, float k, float analytic, inout vec2 trail) {
	vec2 across = vec2(-d.y, d.x);
	float sk = since + k;
	float age = sk * period;
	float idk = id - k;
	// Where it was laid: upstream by the drift since.
	vec2 lp = p - hw * age * foam_flow.x;
	float nn = zs_body_noise(vec2(dot(lp, across) / (L * 0.3), dot(lp, d) / (L * 0.4)) + vec2(idk * 1.37 + fi * 5.1, idk * 2.71));
	float ragged = zs_body_noise(lp / 1.7 + vec2(idk * 0.73, fi * 2.9));
	float birth = smoothstep(1.0 - chance, 1.0 + soft - chance, nn + (ragged - 0.5) * 0.3) * smoothstep(0.0, soft * 0.7, chance);
	float cap = 0.0;
	if (k < 0.5) {
		float front = smoothstep(0.0, max(footprint / L * 4.0, 0.03), since + (ragged - 0.5) * 0.04);
		cap = birth * front * exp(-age / max(foam_fresh, 0.05)) * 1.25;
		float mean = chance * 0.25 * (foam_fresh / period) * 2.0;
		cap = mix(mean, cap, fine);
	}
	if (analytic > 0.0) {
		float life = max(whitecaps.y, 0.2);
		float laid = smoothstep(0.03, 0.12, sk);
		float dens = birth * laid * max(exp(-age / life) - age * 0.012, 0.0);
		float mean = chance * 0.25 * (life / period) * 0.9;
		trail.x = max(trail.x, mix(mean, dens, fine));
		trail.y = max(trail.y, birth * laid * exp(-age / max(foam_flow.w, 0.05)) * fine);
	}
	return cap;
}

// The body's heave at `p` (rest xz): the shove and rise (`shift`), the
// sheet's squeeze (`jac`, 1 flat .. 0 a fold), the slope lost to the
// footprint (`rough`), the slope of the displaced sheet (returned) and, with
// `foamy`, the whitecaps' cover (`caps`). `held` waves only (finer than
// `footprint` they fade); the CPU mirror holds them all.
// sea_foam 1: `caps` is the crest's own fresh cap only, and with `analytic`
// over 0 `trail` is the foam it left (density, youth) worked out per crest
// (the buffer's stand-in, past its reach).
vec2 zs_swell_body(vec2 p, float t, float footprint, bool foamy, float analytic, out vec3 shift, out float jac, out float rough, out float caps, out vec2 trail) {
	trail = vec2(0.0);
	vec2 h0 = normalize(swell_heading);
	float cx = cos(swell_cross.x), sx = sin(swell_cross.x);
	vec2 h1 = vec2(cx * h0.x - sx * h0.y, sx * h0.x + cx * h0.y);
	vec2 hw = normalize(body_wind);
	float patch = zs_body_rough(p, t);
	float wsea = mix(body_patch.x, body_patch.y, patch);
	float bend = (zs_body_noise(p / 95.0 + vec2(t * 0.01, 7.1)) - 0.5) * 2.4 + (zs_body_noise(p / 37.0 + vec2(2.4, t * 0.015)) - 0.5) * 0.9;
	float gt[3];
	gt[0] = zs_body_noise(vec2(dot(p, h0) - t * 6.0, dot(p, vec2(-h0.y, h0.x))) / vec2(260.0, 420.0) + vec2(1.7, 5.3));
	gt[1] = zs_body_noise(vec2(dot(p, h1) - t * 5.0, dot(p, vec2(-h1.y, h1.x))) / vec2(200.0, 330.0) + vec2(8.2, 2.6));
	gt[2] = zs_body_noise(vec2(dot(p, hw) - t * 2.6, dot(p, vec2(-hw.y, hw.x))) / vec2(90.0, 120.0) + vec2(3.1, 6.6));
	vec2 dirs[11];
	float ks[11], amps[11], phases[11], steeps[11];
	float total = 0.0;
	for (int i = 0; i < BODY; i++) {
		int train = BODY_TRAIN[i];
		vec2 h = train == 0 ? h0 : (train == 1 ? h1 : hw);
		float c = cos(BODY_TURN[i]), s = sin(BODY_TURN[i]);
		vec2 d = vec2(c * h.x - s * h.y, s * h.x + c * h.y);
		float k = TAU / BODY_LENGTH[i];
		float omega = sqrt(GRAVITY * k);
		// Each wave's own groups riding at half its speed, mixed with its
		// train's: crests that build and die away.
		vec2 along = vec2(dot(p, d) - 0.5 * omega / k * t, dot(p, vec2(-d.y, d.x)));
		float own = zs_body_noise(along / (BODY_LENGTH[i] * vec2(2.6, 3.4)) + vec2(float(i) * 3.7, float(i) * 1.3));
		float group = smoothstep(0.2, 0.8, mix(gt[train], own, 0.65));
		group = mix(1.0, 0.12 + 1.6 * group * group, swell_groups);
		float a = train < 2 ? BODY_SIZE[i] * body_swell.x * (train == 1 ? swell_cross.y / 0.6 : 1.0) * group : BODY_SIZE[i] * body_swell.y * wsea * group / k;
		dirs[i] = d;
		ks[i] = k;
		amps[i] = a;
		steeps[i] = a * k;
		phases[i] = dot(p, d) * k - omega * t + float(i) * 2.39 + bend * (0.5 + 0.1 * float(i));
		total += a * k;
	}
	// Where the wind gusts hardest: whitecaps cluster in loose drifting
	// clumps instead of along every crest.
	vec2 gp = (p - hw * t * 2.0) / 55.0;
	float gust = smoothstep(0.45, 0.8, zs_body_noise(gp + vec2(9.1, 3.7)) * 0.7 + zs_body_noise(gp * 2.7 + vec2(1.3, 8.8)) * 0.3);
	// The squeeze shared out: the crests peak toward body_swell.z together.
	float q = body_swell.z / max(total, 0.35);
	shift = vec3(0.0);
	vec2 slope = vec2(0.0);
	vec3 j = vec3(1.0, 1.0, 0.0);
	rough = 0.0;
	caps = 0.0;
	for (int i = 0; i < BODY; i++) {
		float L = BODY_LENGTH[i];
		float held = 1.0 - smoothstep(L * 0.06, L * 0.18, footprint);
		vec2 d = dirs[i];
		float cp = cos(phases[i]), sp = sin(phases[i]);
		float steep = steeps[i];
		shift.xz += d * q * amps[i] * cp * held;
		shift.y += amps[i] * sp * held;
		slope += d * steep * cp * held;
		j -= vec3(d.x * d.x, d.y * d.y, d.x * d.y) * q * steep * sp * held;
		rough += 0.5 * steep * steep * (1.0 - held * held);
	}
	// The whitecaps, apart from the heave (one pass over the wind sea's
	// waves 5..8; kept out of the loop above so the shader compiles fast).
	if (foamy) {
		for (int i = 5; i <= 8; i++) {
			float L = BODY_LENGTH[i];
			vec2 d = dirs[i];
			float steep = steeps[i];
			if (sea_foam > 0) {
				// The crest's own cap (as the buffer's pass finds it,
				// shaders/endless_sea_foam.glsl), bright for foam_fresh s.
				float omega = sqrt(GRAVITY * ks[i]);
				float period = TAU / omega;
				float u = (PI * 0.5 - phases[i]) / TAU;
				float since = fract(u), id = floor(u);
				float r = steep / (BODY_SIZE[i] * max(body_swell.y, 0.05));
				// Slicks keep a few, in their wave groups' peaks.
				r = max(r, foam_caps.z * r / max(wsea, 0.05));
				float chance = clamp((r - foam_caps.x) * 0.32 * whitecaps.x, 0.0, 0.3) * (foam_caps.y + (1.0 - foam_caps.y) * gust);
				float fine = 1.0 - smoothstep(L * 0.04, L * 0.15, footprint);
				float soft = 0.2 + clamp(footprint / L * 3.0, 0.0, 0.35);
				caps = max(caps, zs_cap_crest(p, d, L, float(i), since, id, period, chance, soft, fine, footprint, hw, 0.0, analytic, trail));
				if (analytic > 0.0) zs_cap_crest(p, d, L, float(i), since, id, period, chance, soft, fine, footprint, hw, 1.0, analytic, trail);
			} else {
				// The whitecaps of this wave's crests: whether the crest that
				// passed last was breaking here (more where its group is high and
				// the sea rough), and how long ago it passed.
				float omega = sqrt(GRAVITY * ks[i]);
				float u = (PI * 0.5 - phases[i]) / TAU;
				float since = fract(u), id = floor(u);
				float age = since * TAU / omega;
				float r = steep / (BODY_SIZE[i] * max(body_swell.y, 0.05));
				float chance = clamp((r - 0.72) * 0.32 * whitecaps.x, 0.0, 0.3) * (0.25 + 0.75 * gust);
				vec2 lp = p - hw * age * 0.5;
				float n = zs_body_noise(vec2(dot(lp, vec2(-d.y, d.x)) / (L * 0.3), dot(lp, d) / (L * 0.4)) + vec2(id * 1.37 + float(i) * 5.1, id * 2.71));
				// Ragged edges: the outline wanders with a finer noise.
				float ragged = zs_body_noise(lp / 1.7 + vec2(id * 0.73, float(i) * 2.9)) * 0.6 + zs_body_noise(lp / 0.6 + vec2(4.4, id)) * 0.4;
				ragged = mix(0.5, ragged, 1.0 - smoothstep(0.15, 0.6, footprint));
				float soft = 0.2 + clamp(footprint / L * 3.0, 0.0, 0.35);
				float birth = smoothstep(1.0 - chance, 1.0 + soft - chance, n + (ragged - 0.5) * 0.3) * smoothstep(0.0, soft * 0.7, chance);
				float front = smoothstep(0.0, max(footprint / L * 4.0, 0.03), since + (ragged - 0.5) * 0.04) * (1.0 - smoothstep(0.45, 0.9, since));
				float life = max(whitecaps.y, 0.1);
				float cap = birth * front * (exp(-age / life) * 0.7 + exp(-age / 0.35) * 0.6);
				// Older foam pulled out in streaks downwind.
				vec2 sp = vec2(dot(lp, hw) / 9.0, dot(lp, vec2(-hw.y, hw.x)) / 1.8) + vec2(id * 3.3, float(i));
				float streak = zs_body_noise(sp) * 0.65 + zs_body_noise(sp * vec2(1.7, 2.3) + 4.1) * 0.35;
				streak = mix(0.5, streak, 1.0 - smoothstep(0.2, 0.8, footprint));
				cap *= mix(1.0, smoothstep(0.3, 0.7, streak) * 1.4, smoothstep(0.3, 2.5, age) * 0.6 * whitecaps.z);
				// Finer than the pixel: the crests' mean cover instead.
				float period = TAU / omega;
				float mean = chance * 0.25 * (life / period) * (1.0 - exp(-period / life)) * 0.8;
				cap = mix(mean, cap, 1.0 - smoothstep(L * 0.04, L * 0.15, footprint));
				caps = 1.0 - (1.0 - caps) * (1.0 - clamp(cap, 0.0, 1.0));
			}
		}
	}
	jac = j.x * j.y - j.z * j.z;
	if (foamy) caps = max(caps, smoothstep(0.24, 0.08, jac) * patch * (0.25 + 0.75 * gust) * min(whitecaps.x, 1.0));
	float det = max(jac, 0.1);
	return vec2(j.y * slope.x - j.z * slope.y, j.x * slope.y - j.z * slope.x) / det;
}

// The Gerstner swells at `p` (rest xz): the sideways shove and rise
// (`shift`), the slope, the crest's sharpness (`crest`, toward 1 at a cusp),
// each faded out where finer than `footprint`; `rough` gathers what fades.
vec2 zs_swell(vec2 p, float t, float footprint, out vec3 shift, out float crest, out float rough) {
	if (sea_motion > 0) return zs_swell_live(p, t, footprint, shift, crest, rough);
	const float LENGTH[4] = float[4](44.0, 27.0, 17.0, 10.5);
	const float TURN[4] = float[4](0.0, 0.45, -0.38, 0.9);
	const float STEEP[4] = float[4](0.055, 0.05, 0.05, 0.045);
	const float SHARP[4] = float[4](0.55, 0.7, 0.8, 0.85);
	vec2 heading = normalize(swell_heading);
	vec2 slope = vec2(0.0);
	shift = vec3(0.0);
	crest = 0.0;
	rough = 0.0;
	float wind = 0.6 + 0.4 * min(zs_wind_strength, 1.5);
	for (int i = 0; i < SWELLS; i++) {
		float c = cos(TURN[i]), s = sin(TURN[i]);
		vec2 d = vec2(c * heading.x - s * heading.y, s * heading.x + c * heading.y);
		float k = TAU / LENGTH[i];
		float steep = STEEP[i] * swell * wind;
		float held = 1.0 - smoothstep(LENGTH[i] * 0.06, LENGTH[i] * 0.18, footprint);
		float phase = dot(p, d) * k - sqrt(GRAVITY * k) * t + float(i) * 1.7;
		float a = steep / k;
		float q = SHARP[i];
		shift.xz += d * q * a * cos(phase) * held;
		shift.y += a * sin(phase) * held;
		slope += d * steep * cos(phase) * held;
		crest += q * steep * sin(phase) * held;
		rough += 0.5 * steep * steep * (1.0 - held * held);
	}
	return slope;
}

vec4 zs_sea_hash4(vec2 p) {
	vec4 q = vec4(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)), dot(p, vec2(419.2, 371.9)), dot(p, vec2(89.3, 241.7)));
	return fract(sin(q) * 43758.5453);
}

// One noise layer that lives and dies in place: two copies, each drifting
// `speed` m/s along `dir` for one `flow_cycle` then jumping to a fresh spot,
// cross-faded half a cycle apart (and kept at the same contrast through
// the fade), so the lumps rise and fade as they go instead of sliding.
vec2 zs_flow_layer(sampler2D tex, vec2 p, vec2 dir, float speed, float size, float offset, float t) {
	float cycle = max(flow_cycle * sqrt(size / 15.0), 0.2);
	float c0 = t / cycle + offset;
	float c1 = c0 + 0.5;
	float f0 = fract(c0), f1 = fract(c1);
	vec2 j0 = fract(vec2(0.3183, 0.6180) * floor(c0) + offset);
	vec2 j1 = fract(vec2(0.7071, 0.2360) * floor(c1) + offset * 1.7);
	vec2 s0 = texture(tex, (p - dir * speed * cycle * f0) / size + j0).xy * 2.0 - 1.0;
	vec2 s1 = texture(tex, (p - dir * speed * cycle * f1) / size + j1).xy * 2.0 - 1.0;
	float w0 = 1.0 - abs(2.0 * f0 - 1.0);
	float w1 = 1.0 - w0;
	return (s0 * w0 + s1 * w1) * inversesqrt(w0 * w0 + w1 * w1);
}

// The live chop (sea_motion 1): the noise layers living in place, crossing
// three ways at speeds that grow with their size, under packets of peaked
// wavelets that build and vanish in place rather than slide. Each fades into `rough` where finer
// than the pixel.
vec2 zs_chop_live(vec2 p, float t, float air, float footprint, out float rough) {
	vec2 wind = zs_wind_direction;
	vec2 side = vec2(-wind.y, wind.x);
	vec2 d1 = normalize(wind * 0.9 + side * 0.3);
	vec2 d2 = normalize(wind * 0.5 - side * 0.85);
	vec2 d3 = normalize(wind * 0.6 + side * 0.8);
	// Deep-water phase speed sqrt(g L / 2 pi), slowed: the pattern's lumps
	// are crests of many lengths, not one wave.
	vec3 speed = sqrt(GRAVITY * detail_size / TAU) * 0.35;
	vec2 a = zs_flow_layer(detail_a, p, d1, speed.x, detail_size.x, 0.0, t);
	vec2 b = zs_flow_layer(detail_b, p.yx * vec2(1.0, -1.0), vec2(d2.y, -d2.x), speed.y, detail_size.y, 0.37, t);
	vec2 c = zs_flow_layer(detail_a, p * vec2(-1.0, 1.0) + vec2(13.7, 5.1), vec2(-d3.x, d3.y), speed.z, detail_size.z, 0.71, t);
	b = vec2(-b.y, b.x);
	c.x = -c.x;
	vec3 held = vec3(1.0) - smoothstep(detail_size * 0.04, detail_size * 0.2, vec3(footprint));
	vec3 strength = detail_strength * air;
	rough = dot(strength * strength * (vec3(1.0) - held * held), vec3(0.5));
	vec2 slope = a * strength.x * held.x + b * strength.y * held.y + c * strength.z * held.z;
	// The wavelets: packets of a few peaked crests, one round a jittered
	// spot in each cell of a grid per size (each size's grid turned its own
	// way). Each packet swells and dies over its life, then comes back with a
	// new heading and phase; its crests run through it at their deep-water
	// speed. So the small waves build, peak and vanish in place, crossing
	// every way, with no lattice.
	const int SIZES = 6;
	float base = atan(wind.y, wind.x);
	float peak = max(wavelet_peak, 0.0);
	float norm = 1.0 + 0.45 * peak;
	for (int i = 0; i < SIZES; i++) {
		float f = float(i) / float(SIZES - 1);
		float len = wavelet_size.x * pow(wavelet_size.y / wavelet_size.x, f);
		float hold = 1.0 - smoothstep(len * 0.07, len * 0.28, footprint);
		float s = wavelet_strength * (0.6 + 0.4 * (1.0 - f)) * mix(1.0, air, 0.35 + 0.65 * f);
		rough += 0.5 * s * s * 0.35 * (1.0 - hold * hold);
		if (hold <= 0.0) continue;
		float spin = float(i) * 2.399 + 0.6;
		mat2 to_grid = mat2(vec2(cos(spin), -sin(spin)), vec2(sin(spin), cos(spin)));
		float cell = len * 2.4;
		vec2 q = to_grid * p / cell + vec2(float(i) * 7.31, float(i) * 3.17);
		vec2 corner = floor(q - 0.5);
		float k = TAU / len;
		float omega = sqrt(GRAVITY * k);
		float life = max(wavelet_life * sqrt(len), 0.1);
		vec2 sum = vec2(0.0);
		for (int n = 0; n < 4; n++) {
			vec2 id = corner + vec2(float(n % 2), float(n / 2));
			vec4 h = zs_sea_hash4(id);
			vec2 r = (q - (id + 0.25 + 0.5 * h.xy)) * cell;
			float w = exp(-dot(r, r) / (cell * cell * 0.3));
			float age = t / life + h.z;
			vec4 g = zs_sea_hash4(id + floor(age) * vec2(17.13, 3.71));
			float pulse = sin(PI * fract(age));
			pulse *= pulse * smoothstep(0.1, 0.45, g.w);
			float angle = base - spin + wavelet_spread * (g.x * 2.0 - 1.0) + (g.y > 0.88 ? 2.6 : 0.0);
			vec2 d = vec2(cos(angle), sin(angle));
			float phase = dot(r, d) * k - omega * t + g.z * TAU;
			float e = exp(peak * (sin(phase) - 1.0));
			sum += d * (cos(phase) * e * w * pulse);
		}
		// Back from the grid's turn to the world's.
		slope += (sum * to_grid) * (s * norm * hold * 1.6);
	}
	return slope;
}

// The chop: two noise normal maps at three scales, scrolling three ways.
vec2 zs_chop(vec2 p, float t, float air, float footprint, out float rough) {
	if (sea_motion > 0) return zs_chop_live(p, t, air, footprint, rough);
	vec2 wind = zs_wind_direction;
	vec2 side = vec2(-wind.y, wind.x);
	vec2 d1 = wind;
	vec2 d2 = normalize(wind * 0.6 + side * 0.8);
	vec2 d3 = normalize(wind * 0.7 - side * 0.7);
	vec2 a = texture(detail_a, (p + d1 * t * 1.1) / detail_size.x).xy * 2.0 - 1.0;
	vec2 b = texture(detail_b, (p + d2 * t * 0.75) / detail_size.y).xy * 2.0 - 1.0;
	vec2 c = texture(detail_a, (p.yx * vec2(1.0, -1.0) + d3 * t * 0.5) / detail_size.z).xy * 2.0 - 1.0;
	vec3 held = vec3(1.0) - smoothstep(detail_size * 0.04, detail_size * 0.2, vec3(footprint));
	vec3 strength = detail_strength * air;
	rough = dot(strength * strength * (vec3(1.0) - held * held), vec3(0.5));
	vec2 slope = a * strength.x * held.x + b * strength.y * held.y + c * strength.z * held.z;
	if (ripple_strength.x + ripple_strength.y > 0.0) {
		vec2 e = texture(detail_b, (p.yx * vec2(-1.0, 1.0) + (d1 * 0.7 + d2 * 0.5) * t) / ripple_size.x).xy * 2.0 - 1.0;
		vec2 f = texture(detail_a, (p * 0.8 + vec2(d3.y, -d3.x) * t * 0.6) / ripple_size.y + vec2(0.37, 0.61)).xy * 2.0 - 1.0;
		vec2 hf = vec2(1.0) - smoothstep(ripple_size * 0.05, ripple_size * 0.3, vec2(footprint));
		// Ripples ride the wind a little harder than the broad chop.
		vec2 rs = ripple_strength * (0.35 + 0.65 * air);
		rough += dot(rs * rs * (vec2(1.0) - hf * hf), vec2(0.5));
		slope += e * rs.x * hf.x + f * rs.y * hf.y;
	}
	return slope;
}

// How hard the wind works the sea at `p`: cat's paws and slicks.
float zs_sea_air(vec2 p, out float paw) {
	vec2 dir = zs_wind_direction;
	vec2 across = vec2(-dir.y, dir.x);
	vec2 q = p - dir * zs_gust_distance;
	vec2 a = vec2(dot(q, dir), dot(q, across));
	float big = zs_noise(a / paw_size + vec2(3.1, 7.7)) * 0.65 + zs_noise(a / (paw_size * 0.43) + vec2(11.3, 2.9)) * 0.35;
	paw = smoothstep(0.42, 0.78, big) * paws;
	float lane = zs_noise(vec2(dot(p, across) * 0.06, dot(p, dir) * 0.004 - zs_gust_distance * 0.002));
	float slick = smoothstep(0.62, 0.86, lane) * (1.0 - paw);
	float air = clamp(zs_wind_strength, 0.0, 2.5);
	float patch = 1.0;
	if (sea_motion > 0) {
		// Broad stretches of rougher and calmer sea, drifting downwind.
		vec2 r = (a - vec2(zs_gust_distance * 0.4, 0.0)) / vec2(wind_patches.x, wind_patches.x * 0.7);
		float wide = zs_noise(r + vec2(5.9, 1.3)) * 0.7 + zs_noise(r * 2.3 + vec2(2.2, 9.1)) * 0.3;
		patch = max(1.0 + wind_patches.y * (smoothstep(0.2, 0.8, wide) * 2.0 - 1.0), 0.15);
	}
	// The body: the chop follows the same slicks and rough stretches as the
	// wind sea and its whitecaps.
	if (sea_body > 0) patch = mix(1.0 - 0.65 * body_patch.z, 1.0 + 0.45 * body_patch.z, zs_body_rough(p, zs_flow_time));
	return (0.45 + 0.55 * air) * (0.6 + 0.9 * paw) * (1.0 - 0.6 * slick) * chop * patch;
}

vec3 zs_sea_receiver(vec2 uv, float depth, mat4 inv_projection, mat4 inv_view) {
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return (inv_view * vec4(view.xyz / view.w, 1.0)).xyz;
}

// The water's depth under `p` from the map (DEEP off it; `known` 0 there).
float zs_map_depth(vec2 p, out float known) {
	known = 0.0;
	if (depth_at.w <= 0.0) return DEEP;
	vec2 uv = (p - depth_at.xy) / depth_at.z;
	vec2 rim = min(uv, 1.0 - uv);
	known = smoothstep(0.0, 0.05, min(rim.x, rim.y));
	if (known <= 0.0) return DEEP;
	return sea_level - texture(depth_map, uv).r;
}

// How still the sea lies at `p` up a river's mouth (0 open sea, 1 calm).
float zs_river_calm(vec2 p) {
	if (depth_at.w <= 0.0 || river_calm <= 0.0) return 0.0;
	vec2 uv = (p - depth_at.xy) / depth_at.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
	return clamp(textureLod(depth_map, uv, 0.0).g, 0.0, 1.0) * river_calm;
}

// The plane's wake at `p`: its foam (returned), the stirred water round it
// (`stirred`, 0..1) and the slope its ripples add. Only the nearest point of
// the track counts, so the arms are one V and not a ring per point.
float zs_wake(vec2 p, out vec2 slope, out float stirred) {
	slope = vec2(0.0);
	stirred = 0.0;
	if (wake_count < 2 || wake <= 0.0) return 0.0;
	if (distance(p, wake_head.xy) > wake_head.w) return 0.0;
	float best = 1e9;
	vec2 best_across = vec2(0.0);
	float best_age = 0.0, best_strength = 0.0;
	for (int i = 0; i < WAKE_POINTS - 1; i++) {
		if (i + 1 >= wake_count) break;
		vec4 a = wake_points[i];
		vec4 b = wake_points[i + 1];
		if (a.w <= 0.0 && b.w <= 0.0) continue;
		vec2 ab = b.xy - a.xy;
		float len2 = max(dot(ab, ab), 1e-4);
		float t = clamp(dot(p - a.xy, ab) / len2, 0.0, 1.0);
		vec2 near = a.xy + ab * t;
		float d = distance(p, near);
		if (d < best) {
			best = d;
			best_across = (p - near) / max(d, 1e-3);
			best_age = max(wake_now - mix(a.z, b.z, t), 0.0);
			best_strength = mix(a.w, b.w, t);
		}
	}
	if (best >= 1e8) return 0.0;
	float d = best, age = best_age;
	float r = 0.6 + age * wake_spread;
	float gone = 1.0 - smoothstep(3.0, 4.6, age);
	// The prop wash: a narrow churned streak, widening and fading.
	float w0 = 0.6 + age * 0.5;
	float churn = (1.0 - smoothstep(0.0, w0, d)) * exp(-age / 0.6);
	// The arms: thin foam lines riding out from the track, the V.
	float wide = 0.4 + age * 0.3;
	float arm = exp(-pow((d - r) / wide, 2.0)) * exp(-age / 2.2) * smoothstep(0.0, 0.35, age);
	float foamed = max(churn * 0.6, arm * 0.8) * best_strength * gone;
	// The water between the arms, stirred (soft, no rim).
	float inside = d / (r + 1.0);
	stirred = exp(-inside * inside * 2.5) * exp(-age / 2.6) * best_strength * gone * wake;
	// Ripples inside the arms, sloping across the track.
	float ripple = sin((d - r) * 3.1) * (1.0 - smoothstep(r * 0.4, r + 0.3, d)) * smoothstep(0.0, 0.4, d) * exp(-age / 3.5);
	slope = best_across * ripple * 0.18 * best_strength * gone * wake;
	return clamp(foamed * wake, 0.0, 1.0);
}

// Broken foam: `cover` 0..1 turned into a soft, cellular pattern.
// (sea_motion 1: each octave evens out where finer than `footprint`, so
// far foam softens instead of flecking.)
float zs_foam_pattern(vec2 p, float t, float cover, float footprint) {
	vec3 hold = sea_motion > 0 ? vec3(1.0) - smoothstep(vec3(0.25, 0.08, 0.03), vec3(0.9, 0.3, 0.12), vec3(footprint)) : vec3(1.0);
	float n = mix(0.5, zs_noise(p * 0.55 + vec2(t * 0.05, 0.0)), hold.x) * 0.55 + mix(0.5, zs_noise(p * 1.7 - vec2(0.0, t * 0.08)), hold.y) * 0.3 + mix(0.5, zs_noise(p * 4.3 + vec2(t * 0.11)), hold.z) * 0.15;
	return smoothstep(1.0 - cover, 1.0 - cover + 0.22, n) * smoothstep(0.0, 0.1, cover);
}

float zs_foam_soft(vec2 p, float t, float cover, float footprint) {
	vec3 hold = vec3(1.0) - smoothstep(vec3(0.25, 0.08, 0.03), vec3(0.9, 0.3, 0.12), vec3(footprint));
	float n = mix(0.5, zs_noise(p * 0.7 + vec2(t * 0.05, 0.0)), hold.x) * 0.5 + mix(0.5, zs_noise(p * 2.1 - vec2(0.0, t * 0.08)), hold.y) * 0.32 + mix(0.5, zs_noise(p * 5.3 + vec2(t * 0.11)), hold.z) * 0.18;
	return smoothstep(1.0 - cover, 1.0 - cover + 0.4, n) * smoothstep(0.0, 0.15, cover);
}

// The lace (sea_foam 1): marbled veins, stretched downwind and bent.
// Foam of `density` (0..1) and `youth` (1 just laid .. 0 old) at `p`: a
// solid cap when young, opening into a net of veins that thin and break as
// it fades. Finer than the pixel, it evens out into its mean cover.
float zs_foam_lace(vec2 p, float density, float youth, float footprint) {
	if (density < 0.004) return 0.0;
	float cell = max(foam_lace.x, 0.2);
	vec2 hw = normalize(body_wind);
	vec2 q = p - foam_drift;
	q = vec2(dot(q, hw) / 1.7, dot(q, vec2(-hw.y, hw.x)));
	vec2 bent = vec2(zs_body_noise(q / (cell * 2.3)), zs_body_noise(q / (cell * 2.3) + vec2(7.3, 2.1))) - 0.5;
	bent += (vec2(zs_body_noise(q / (cell * 0.9) + vec2(3.3, 5.1)), zs_body_noise(q / (cell * 0.9) + vec2(8.1, 0.7))) - 0.5) * 0.45;
	q += bent * cell * 2.2 * foam_lace.z;
	float hold = 1.0 - smoothstep(cell * 0.06, cell * 0.3, footprint);
	float hold_fine = 1.0 - smoothstep(cell * 0.025, cell * 0.12, footprint);
	// Marbled veins: the ridges of a bent noise at two sizes.
	float big = 1.0 - abs(2.0 * zs_body_noise(q / cell) - 1.0);
	float small = 1.0 - abs(2.0 * zs_body_noise(q / (cell * 0.4) + vec2(3.1, 8.7)) - 1.0);
	vec2 turned = vec2(q.x * 0.6 - q.y * 0.8, q.x * 0.8 + q.y * 0.6);
	float mid = 1.0 - abs(2.0 * zs_body_noise(turned / (cell * 0.62) + vec2(6.2, 1.4)) - 1.0);
	big *= big; big *= big;
	small *= small; small *= small;
	mid *= mid; mid *= mid;
	float grain = zs_body_noise(q / (cell * 0.16) + vec2(1.9, 4.4));
	// Crossing ridges close into a net.
	float veins = max(max(big, mid * 0.92), small * 0.85 * hold_fine) * (0.85 + 0.15 * grain);
	float open = clamp(1.0 - youth, 0.0, 1.0);
	open = open * open * (3.0 - 2.0 * open);
	// Young foam fills in solid (a little grain at its edge); as it ages
	// only the veins stay, thinner as it fades.
	float net = mix(0.55 + 0.45 * grain, veins, open);
	float want = mix(0.85, 0.2 + 0.4 * foam_lace.y * density, open);
	want *= smoothstep(0.0, 0.6, density);
	float soft = mix(0.32, 0.2, open);
	float covered = smoothstep(1.0 - want - soft * 0.5, 1.0 - want + soft * 0.5, net);
	// Finer than the pixel: the share of it the lace would cover.
	float mean = want * mix(1.0, 0.45, open);
	covered = mix(mean, covered, hold * 0.75 + hold_fine * 0.25);
	// Between the veins a thin milky film, the foam spreading out.
	float film = density * open * (0.4 + 0.6 * grain) * 0.45 * foam_lace.y;
	covered = max(covered, film * smoothstep(0.0, 0.3, density));
	return covered * mix(0.45, 1.0, youth) * (0.45 + 0.55 * density) * smoothstep(0.0, 0.3, density);
}

// The square the shade map holds as the sea draws.
vec4 zs_sea_shade_at() {
	return shade_square.w > 0.0 && zs_cloud_shadow_at.w > 0.0 ? shade_square : zs_cloud_shadow_at;
}

// zs_cloud_volume_shade (shaders/cloud_volume_shadow.gdshaderinc) over the
// square as drawn this frame.
float zs_sea_cloud_shade(vec3 p) {
	vec4 at = zs_sea_shade_at();
	if (at.w <= 0.0) return 0.0;
	vec3 light = zs_cloud_shadow_light.xyz;
	if (light.y < 0.03) return 0.0;
	vec2 q = p.xz + light.xz / max(light.y, 0.12) * (zs_cloud_shadow_light.w - p.y);
	vec2 uv = (q - at.xy) / max(at.z, 1.0);
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
	vec3 s = texture(zs_cloud_shadow, uv).rgb;
	float over = smoothstep(s.b + 30.0, s.b - 15.0, p.y);
	float keep = mix(1.0, s.r, over) * mix(s.g, 1.0, smoothstep(ZS_CLOUD_SHADE_SPLIT - 30.0, ZS_CLOUD_SHADE_SPLIT, p.y));
	vec2 rim = min(uv, 1.0 - uv);
	return (1.0 - keep) * smoothstep(0.0, 0.06, min(rim.x, rim.y)) * at.w;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rest_xz = world.xz;
	float reach = max(abs(VERTEX.x), abs(VERTEX.z));
	if (lod_from_eye > 0) {
		// The sheet jumps 64 m under the eye (EndlessLook `step`); its own
		// reach jumped with it, and so did which waves it held and how far
		// it heaved, so the whole sea popped each time (a flicker of the
		// glitter and the swell every second or two in flight). Measured
		// from the eye they change smoothly. Past the sheet's middle by up
		// to SNAP_SLACK, never finer than the sheet's own cells.
		reach = length(world.xz - CAMERA_POSITION_WORLD.xz) + SNAP_SLACK;
	}
	float cell = max(2.0, reach / 28.0);
	float near = 1.0 - smoothstep(heave_reach.x, heave_reach.y, reach);
	vec3 shift;
	float crest, rough;
	if (sea_body > 0) {
		// The finer sheet (EndlessSea `sheet`): 1 m cells, doubling ring by
		// ring; a wave is held while its length spans a few cells.
		cell = max(1.0, reach / 32.0);
		near = 1.0 - smoothstep(body_reach.x, body_reach.y, reach);
		float jac, caps;
		vec2 trail;
		zs_swell_body(world.xz, zs_flow_time, cell * 0.6, false, 0.0, shift, jac, rough, caps, trail);
	} else {
		zs_swell(world.xz, zs_flow_time, cell, shift, crest, rough);
	}
	VERTEX += shift * near * (1.0 - zs_river_calm(world.xz));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	float distance_to = length(CAMERA_POSITION_WORLD - world_position);
	float footprint = max(length(dFdx(rest_xz)), length(dFdy(rest_xz)));
	float t = zs_flow_time;
	float paw;
	float air = zs_sea_air(rest_xz, paw);
	vec3 shift;
	float crest, swell_rough, chop_rough;
	float jac = 1.0, caps = 0.0;
	vec2 slope;
	// The foam buffer's reach (sea_foam 1): inside it the trail is read
	// from it, past it worked out per crest, cross-faded over its rim.
	vec2 trail = vec2(0.0);
	vec4 held = vec4(0.0);
	float in_buffer = 0.0;
	if (sea_foam > 0 && foam_at.w > 0.5) {
		vec2 rel = rest_xz - foam_at.xy;
		vec2 rim = min(rel, vec2(foam_at.z) - rel);
		in_buffer = smoothstep(6.0, 40.0, min(rim.x, rim.y)) * float(debug_view != 7);
		if (in_buffer > 0.0) held = foam_side == 0 ? textureLod(foam_buffer, rest_xz / foam_at.z, 0.0) : textureLod(foam_buffer_b, rest_xz / foam_at.z, 0.0);
	}
	if (sea_body > 0) {
		slope = zs_swell_body(rest_xz, t, footprint, true, 1.0 - in_buffer, shift, jac, swell_rough, caps, trail);
		crest = 0.0;
	} else {
		slope = zs_swell(rest_xz, t, footprint, shift, crest, swell_rough);
	}
	// Up a river's mouth the swell is stilled (the vertex's heave too).
	float still = zs_river_calm(rest_xz);
	slope *= 1.0 - still;
	shift *= 1.0 - still;
	crest *= 1.0 - still;
	vec2 detail = zs_chop(rest_xz, t, air, footprint, chop_rough);
	vec2 wake_slope;
	float stirred;
	float waked = zs_wake(rest_xz, wake_slope, stirred);
	vec3 normal = normalize(vec3(-(slope.x + detail.x + wake_slope.x), 1.0, -(slope.y + detail.y + wake_slope.y)));
	// A calmer normal for the sky's mirror, so the reflection reads as one
	// rippled image rather than noise.
	vec3 calm = normalize(vec3(-(slope.x + detail.x * calm_share), 1.0, -(slope.y + detail.y * calm_share)));
	float facing = max(dot(eye, normal), 0.0);
	float sigma = sqrt(swell_rough + chop_rough);
	float roughness = clamp(0.06 + sigma * 1.4 + footprint * 0.0015, 0.06, 0.5);
	float fresnel = fresnel_floor + (1.0 - fresnel_floor) * pow(1.0 - max(dot(eye, calm), 0.0), fresnel_power);
	fresnel *= 1.0 - 0.25 * paw * min(zs_wind_strength, 1.0);
	fresnel *= 1.0 - 0.2 * stirred;

	// The bed behind this pixel, nudged by the waves.
	vec2 uv = SCREEN_UV;
	float depth = texture(sea_depth, uv).r;
	vec3 receiver = zs_sea_receiver(uv, depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float bed_depth = depth > 0.0 ? world_position.y - receiver.y : DEEP;
	vec2 bent = uv + (VIEW_MATRIX * vec4(normal.x, 0.0, normal.z, 0.0)).xy * vec2(1.0, -1.0) * 0.03 * smoothstep(0.0, 2.0, bed_depth) / (1.0 + distance_to * 0.05);
	float bent_depth = texture(sea_depth, bent).r;
	vec3 bent_receiver = zs_sea_receiver(bent, bent_depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	if (bent_depth <= 0.0 || bent_receiver.y < world_position.y - 0.05) {
		uv = bent;
		depth = bent_depth;
		receiver = bent_receiver;
		bed_depth = depth > 0.0 ? world_position.y - receiver.y : DEEP;
	}
	bed_depth = max(bed_depth, 0.0);
	float through = depth > 0.0 ? length(receiver - world_position) : DEEP;

	// The water's depth here: the map's where it reaches, else the bed seen.
	float known;
	float mapped = zs_map_depth(rest_xz, known);
	// A mouth's channel is finer than the map: the bed seen gives its depth.
	known *= 1.0 - still;
	float waver = mix(0.8, 1.25, zs_noise(rest_xz * 0.03) * 0.7 + zs_noise(rest_xz * 0.11 + vec2(4.1, 7.3)) * 0.3);
	float fallback = max(bed_depth, through * 0.55);
	float water_depth = max(mix(fallback, mapped, known), 0.0) * waver;

	vec3 seen = exp(-absorb * through) * exp(-max(bed_depth, through * 0.4) / bed_fade);
	vec3 bed = textureLod(sea_screen, uv, 0.0).rgb;

	vec3 column = mix(tint_shallow, tint_mid, smoothstep(0.0, tint_depths.y, water_depth));
	column = mix(column, tint_deep, smoothstep(tint_depths.y * 0.6, tint_depths.z, water_depth));
	column = mix(column, tint_abyss, smoothstep(tint_depths.z, tint_depths.w, water_depth));
	column = mix(tint_shallow, column, smoothstep(0.0, tint_depths.x, water_depth) * 0.6 + 0.4);
	column *= zs_palette_water;
	vec3 ambient = zs_hemi_sky * zs_hemi_energy / PI;
	vec3 key = zs_key_irradiance * max(zs_key_direction.y, 0.0) / PI;
	vec3 light = (ambient + key * 0.8) * water_light;
	// The body: the water's light across the wave, darker in the troughs and
	// lighter, greener up the crests, and a touch darker where it is rough.
	float lift = 0.5;
	float rough_here = 0.0;
	if (sea_body > 0) {
		float scale = body_swell.x * 0.9 + body_swell.y * 0.3 + 0.05;
		lift = smoothstep(-1.0, 1.0, shift.y / scale);
		rough_here = zs_body_rough(rest_xz, t);
		vec3 up_tint = mix(column, sss_color * zs_palette_water * 0.55, 0.07);
		column = mix(column * body_value.x, up_tint * body_value.y, lift) * mix(1.0, 0.85, rough_here);
	}
	vec3 water = column * light * (vec3(1.0) - seen) + bed * seen;
	if (sea_motion > 0) water *= 1.0 + clamp(dot(normal.xz, normalize(zs_sun_direction.xz + vec2(1e-4))) * 2.0, -0.5, 0.5) * body_shade;
	// Stirred water behind the plane: lighter with the air churned into it.
	water = mix(water, mix(tint_mid, tint_deep, 0.5) * zs_palette_water * light, stirred * 0.18);

	// Light through the crests facing the sun.
	vec3 sun = zs_sun_direction;
	vec2 sun_flat = normalize(sun.xz + vec2(1e-4));
	float toward = pow(clamp(dot(-eye.xz / max(length(eye.xz), 1e-3), sun_flat), 0.0, 1.0), 3.0);
	float lifted = smoothstep(0.06, 0.2, crest) * (0.25 + 0.75 * toward) * smoothstep(-0.05, 0.2, sun.y);
	water += tint_mid * zs_palette_water * key * lifted * crest_glow * 0.5 * smoothstep(3.0, 12.0, water_depth);

	// Foam. The shore: a broken line where the water thins out, and bands
	// rolling in over the shelf.
	float near_bed = depth > 0.0 ? min(bed_depth, mix(bed_depth, mapped, known * 0.5)) : mapped;
	float lap = shore_foam * (0.75 + 0.25 * sin(t * 0.9 + zs_noise(rest_xz * 0.2) * 6.2832));
	float line = (1.0 - smoothstep(lap * 0.3, lap, near_bed)) * (1.0 - 0.8 * still);
	float band_phase = water_depth * 1.6 + t * 0.9 + zs_noise(rest_xz * 0.035) * 4.0;
	float bands = smoothstep(0.55, 0.95, sin(band_phase)) * (1.0 - smoothstep(wash_depth * 0.35, wash_depth, water_depth)) * smoothstep(lap * 0.5, lap * 1.5, near_bed) * (1.0 - still);
	float shore = max(line, bands * 0.75);
	// The crests: only the sharpest, and more where the wind works.
	float crested = smoothstep(0.12, 0.2, crest + detail.x * 0.15) * crest_foam * smoothstep(8.0, 20.0, water_depth) * (0.5 + 0.5 * paw) * min(zs_wind_strength * 1.3, 1.0);
	float cover = max(shore, crested * 0.55);
	// The whitecaps, out on the open sea.
	// sea_foam 1: the fresh cap and the trail it leaves, as lace.
	float lace_density = 0.0, lace_youth = 0.0, churned = 0.0, wake_laid = 0.0;
	if (sea_body > 0 && sea_foam > 0) {
		float open_sea = smoothstep(4.0, 12.0, water_depth);
		caps *= open_sea;
		vec2 left = mix(trail, held.rg, in_buffer) * open_sea;
		lace_density = max(left.x, caps);
		lace_youth = max(left.y, min(caps * 1.5, 1.0));
		churned = max(mix(left.x * 0.7, held.b, in_buffer) * open_sea, caps);
		wake_laid = held.a * in_buffer * wake;
		// The churned water round them, lighter and greener.
		water = mix(water, mix(tint_mid, sss_color, 0.25) * zs_palette_water * light * 1.15, smoothstep(0.02, 0.6, churned) * 0.12 * foam_lace.w);
	} else if (sea_body > 0) {
		float open_sea = smoothstep(4.0, 12.0, water_depth);
		caps *= open_sea;
		cover = max(cover, caps);
		// The aerated water round and under them, lighter and greener.
		water = mix(water, mix(tint_shallow, sss_color, 0.4) * zs_palette_water * light * 0.8, smoothstep(0.05, 0.6, caps) * 0.16);
	}
	float foamed = zs_foam_pattern(rest_xz, t, cover, footprint) * foam;
	// Whitecaps: the same breakup but softer-edged, so they read as foam and
	// not as cut paper.
	if (sea_body > 0 && sea_foam == 0 && caps > shore) foamed = mix(foamed, mix(zs_foam_soft(rest_xz, t, caps, footprint), caps * 0.75, smoothstep(0.1, 0.45, footprint)) * foam, smoothstep(0.0, 0.05, caps - shore));
	// The wake's foam: lines broken softly rather than into islands.
	float fleck = zs_noise(rest_xz * 0.9 + vec2(t * 0.3, 0.0)) * 0.6 + zs_noise(rest_xz * 2.6 - vec2(0.0, t * 0.4)) * 0.4;
	foamed = max(foamed, (smoothstep(0.2, 0.55, waked * (0.15 + 1.3 * fleck)) * 0.9 + smoothstep(0.4, 0.85, fleck) * stirred * 0.18) * foam);
	cover = max(cover, waked);
	// Far off the pattern is finer than a pixel: an even wash instead.
	foamed = mix(foamed, cover * 0.6 * foam, smoothstep(0.15, 0.8, footprint));
	if (sea_foam > 0) {
		// The wake's foam left in the buffer joins in as foam already old.
		float wake_youth = clamp(wake_laid * 1.2 - 0.4, 0.0, 0.6);
		float laced = zs_foam_lace(rest_xz, max(lace_density, wake_laid * 0.9), lace_density >= wake_laid * 0.9 ? lace_youth : wake_youth, footprint);
		foamed = max(foamed, laced * foam);
	}
	foamed = clamp(foamed, 0.0, 1.0) * float(depth > 0.0 || known > 0.0 || waked > 0.0);
	float lip = (1.0 - smoothstep(0.0, 0.15, bed_depth)) * float(depth > 0.0) * (1.0 - still);
	vec3 white = vec3(0.9, 0.96, 1.0) * (ambient * 1.1 + key * 0.8);
	// Fresh foam stands up a little: brighter, and lit by its own slope.
	if (sea_foam > 0) white *= 1.0 + 0.1 * lace_youth + 0.18 * clamp(dot(normal, zs_key_direction), -0.5, 1.0) * float(lace_density > 0.0);
	water = mix(water, white, foamed * 0.92);
	water += tint_shallow * (ambient + key) * lip * 0.4;

	// The mirror: the sky, the cloud field, and what stands on screen.
	vec3 reflected = reflect(-eye, calm);
	reflected.y = abs(reflected.y);
	vec3 sky = clamp(zsSkyGradient(reflected), vec3(0.0), vec3(0.98));
	vec4 shade_at = zs_sea_shade_at();
	if (cloud_mirror > 0.0 && shade_at.w > 0.0 && reflected.y > 0.02) {
		// Where the mirrored ray meets the cloud's height, the shade map's
		// spot under that cloud along the sun's line.
		vec3 c = world_position + reflected * ((cloud_mirror_y - world_position.y) / reflected.y);
		vec3 l = zs_cloud_shadow_light.xyz;
		vec2 q = c.xz - l.xz / max(l.y, 0.12) * (cloud_mirror_y - zs_cloud_shadow_light.w);
		vec2 cuv = (q - shade_at.xy) / max(shade_at.z, 1.0);
		if (all(greaterThan(cuv, vec2(0.0))) && all(lessThan(cuv, vec2(1.0)))) {
			// Four taps a texel and a half apart: the map is coarse, and a
			// mirror magnifies it.
			vec2 texel = 2.5 / vec2(textureSize(zs_cloud_shadow, 0));
			float thick = 0.0;
			for (int k = 0; k < 4; k++) {
				vec2 o = vec2(k % 2 == 0 ? -1.0 : 1.0, k < 2 ? -1.0 : 1.0) * texel;
				vec3 s = texture(zs_cloud_shadow, cuv + o).rgb;
				thick += 0.25 * (1.0 - s.g * s.r);
			}
			vec2 rim = min(cuv, 1.0 - cuv);
			float far = 1.0 - smoothstep(600.0, 2200.0, length(c.xz - world_position.xz));
			float cloud = smoothstep(0.0, 1.0, thick) * 0.8 * smoothstep(0.0, 0.08, min(rim.x, rim.y)) * far;
			vec3 lit_cloud = zs_scene_to_display((ambient * 1.6 + key * 0.9) * vec3(1.0, 0.99, 0.97));
			sky = mix(sky, lit_cloud, cloud * cloud_mirror);
		}
	}
	float mirrored = 0.0;
	vec3 mirror = vec3(0.0);
	if (mirror_steps > 0 && fresnel > 0.05) {
		vec3 ray = reflect(-eye, normalize(mix(vec3(0.0, 1.0, 0.0), normal, mirror_calm)));
		ray.y = abs(ray.y);
		mat4 to_clip = PROJECTION_MATRIX * VIEW_MATRIX;
		float step_length = mirror_march.x * (1.0 + distance_to * 0.01);
		float reach = step_length * (pow(mirror_march.y, float(mirror_steps)) - 1.0) / max(mirror_march.y - 1.0, 1e-3);
		float travelled = 0.0;
		float before = 0.0;
		for (int i = 0; i < 32; i++) {
			if (i >= mirror_steps) break;
			before = travelled;
			travelled += step_length;
			step_length *= mirror_march.y;
			vec3 q = world_position + ray * travelled;
			vec4 clip = to_clip * vec4(q, 1.0);
			if (clip.w <= 0.0) break;
			vec3 ndc = clip.xyz / clip.w;
			vec2 at = ndc.xy * 0.5 + 0.5;
			if (any(lessThan(at, vec2(0.0))) || any(greaterThan(at, vec2(1.0)))) break;
			float scene = texture(sea_depth, at).r;
			if (scene > ndc.z) {
				vec3 hit = zs_sea_receiver(at, scene, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
				float gap = length(hit - CAMERA_POSITION_WORLD) - length(q - CAMERA_POSITION_WORLD);
				if (gap > -(travelled - before) * 1.5 && hit.y > world_position.y - 0.2) {
					float lo = before, hi = travelled;
					for (int r = 0; r < 4; r++) {
						float mid = (lo + hi) * 0.5;
						vec4 cc = to_clip * vec4(world_position + ray * mid, 1.0);
						vec3 n = cc.xyz / cc.w;
						if (texture(sea_depth, n.xy * 0.5 + 0.5).r > n.z) hi = mid; else lo = mid;
					}
					vec4 cc = to_clip * vec4(world_position + ray * hi, 1.0);
					vec2 found = cc.xy / cc.w * 0.5 + 0.5;
					vec2 edge = smoothstep(vec2(0.0), vec2(0.06), found) * (1.0 - smoothstep(vec2(0.94), vec2(1.0), found));
					mirror = zs_scene_to_display(textureLod(sea_screen, found, 0.0).rgb);
					mirrored = edge.x * edge.y * (1.0 - smoothstep(0.2, 0.5, roughness));
					mirrored *= 1.0 - smoothstep(0.45, 1.0, hi / reach);
					vec3 surface = zs_sea_receiver(found, texture(sea_depth, found).r, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
					float behind = length(world_position + ray * hi - CAMERA_POSITION_WORLD) - length(surface - CAMERA_POSITION_WORLD);
					float thick = max(3.0, (travelled - before) * 0.125 + hi * 0.02);
					mirrored *= 1.0 - smoothstep(thick, thick * 2.0, behind);
					break;
				}
			}
		}
	}
	vec3 reflection = mix(sky, mirror, mirrored);

	// The sun: a soft path off the calm normal, and a crisp glitter off the
	// chop's own (hard-edged spots, fewer and finer far off).
	float shaded = cloud_shade > 0.0 ? zs_sea_cloud_shade(world_position) * cloud_shade : 0.0;
	vec3 smooth_n = normalize(vec3(-(slope.x + detail.x * path_share), 1.0, -(slope.y + detail.y * path_share)));
	vec4 path = zs_lake_glint(reflect(-eye, smooth_n), sun, zs_moon_direction, zs_celestial_clear, 0.0, glint_share);
	path.a *= 1.0 - shaded;
	float sunlight = smoothstep(-0.03, 0.12, sun.y);
	float spark_dot = dot(reflect(-eye, normal), sun);
	float spark;
	if (sea_motion > 0) {
		// The crisp glints hold their size; what the layers lost to the
		// pixel turns them into an even sheen (a lobe as wide as the slope
		// lost), so far water glows rather than sparkles.
		float spark_edge = 0.9993;
		float crisp = smoothstep(spark_edge, spark_edge + (1.0 - spark_edge) * 0.35, spark_dot);
		float lost = (swell_rough + chop_rough) * glitter_filter;
		const float SPOT = 0.0025;
		float keep = SPOT / (SPOT + lost);
		vec3 half_way = normalize(eye + sun);
		float tilt = max(1.0 - dot(half_way, normal), 0.0) * 2.0;
		// The same light spread over the wider lobe: dimmer as it widens.
		float sheen = exp(-tilt / (SPOT + lost)) * min(keep * 2.5, 0.45);
		spark = crisp * keep + sheen * (1.0 - keep);
	} else {
		float spark_edge = mix(0.9993, 0.99, smoothstep(0.5, 6.0, footprint));
		spark = smoothstep(spark_edge, spark_edge + (1.0 - spark_edge) * 0.35, spark_dot);
	}
	spark *= smoothstep(0.85, 0.97, dot(reflect(-eye, calm), sun));
	spark *= glitter * zs_celestial_clear * sunlight * (1.0 - shaded) * (1.0 - foamed);
	// The body: thin crests the sun shines through, glowing green-turquoise
	// when the eye looks toward it (strongest on the faces turned this way).
	float glow = 0.0;
	if (sea_body > 0) {
		vec3 view = -eye;
		float back = smoothstep(-0.1, 0.7, dot(view, sun)) * 0.6 + 0.4 * pow(clamp(dot(normalize(view.xz + vec2(1e-4)), sun_flat), 0.0, 1.0), 3.0);
		float thin = smoothstep(0.62, 0.95, lift) * (0.2 + 0.8 * smoothstep(0.95, 0.65, jac));
		float toward_eye = clamp(dot(normal.xz, eye.xz) * 4.0 + 0.35, 0.0, 1.0);
		glow = sss_strength * thin * back * toward_eye * smoothstep(-0.02, 0.15, sun.y) * (1.0 - shaded * 0.7) * smoothstep(3.0, 10.0, water_depth);
		water += sss_color * (key * 1.2 + ambient * 0.3) * glow;
		fresnel *= 1.0 - 0.15 * rough_here;
	}
	vec3 lit = water + zs_lake_direct(vec3(0.0), normal, eye, zs_key_direction, zs_key_irradiance, max(roughness, 0.3)) * glint_share * 0.06 * (1.0 - foamed);
	lit *= 1.0 - 0.4 * shaded;

	float mirror_weight = fresnel * (1.0 - foamed) * (1.0 - clamp(glow, 0.0, 0.6));
	vec3 display_color = mix(zs_scene_to_display(lit), reflection, mirror_weight);
	display_color = mix(display_color, path.rgb, path.a * (1.0 - foamed));
	vec3 warm = mix(vec3(1.0, 0.62, 0.35), vec3(1.0, 0.98, 0.9), smoothstep(0.02, 0.5, sun.y));
	display_color = mix(display_color, warm, clamp(spark, 0.0, 1.0));
	if (debug_view == 1) display_color = water_depth < 5.0 ? vec3(1.0, 0.0, 0.0) : (water_depth < 20.0 ? vec3(0.0, 1.0, 0.0) : (water_depth < 60.0 ? vec3(0.0, 0.0, 1.0) : vec3(1.0))) * (0.5 + 0.5 * known);
	if (debug_view == 3) display_color = zs_scene_to_display(lit);
	if (debug_view == 4) display_color = reflection * mirror_weight;
	if (debug_view == 5) display_color = vec3(glow, lift * 0.5, (1.0 - jac) * 2.0);
	if (debug_view == 2) display_color = vec3(cover, foamed, waked);
	if (debug_view == 6) display_color = vec3(lace_density, lace_youth, in_buffer * 0.5 + churned * 0.5);
	ALBEDO = scene_linear_for_display(clamp(display_color, vec3(0.0), vec3(1.0)));
	ALPHA = depth > 0.0 ? smoothstep(0.0, mix(0.05, river_calm_fade, still), bed_depth) : 1.0;
}
