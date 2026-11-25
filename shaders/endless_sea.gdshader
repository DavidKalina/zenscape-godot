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
// - The FFT sea (sea_fft 1, on unless `--sea-fft=0`): the wind sea and its chop as
//   Tessendorf cascades (scripts/endless/sea_fft.gd) in place of Gerstner
//   waves 5..10, the noise layers and the wavelets.
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/weather_bow.gdshaderinc"
#include "res://shaders/reference_tonemap.gdshaderinc"
#include "res://shaders/reference_lake_lighting.gdshaderinc"
#include "res://shaders/reference_lake_glint.gdshaderinc"
#include "res://shaders/cloud_volume_shadow.gdshaderinc"
// The sun's glint turns with the sun's hue (light_leans).
#include "res://shaders/light_leans.gdshaderinc"
// Weather lane rain: rings and a beaten grey where it rains (zs_rain_pocks).
#include "res://shaders/weather_rain_water.gdshaderinc"
global uniform vec3 zs_palette_water;
uniform sampler2D sea_screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D sea_depth : hint_depth_texture, filter_nearest, repeat_disable;
// The sunk tunnels' ramps go under the level: no sea within dry_half m of
// these segments (xz from, xz to; scripts/endless/land_tunnels.gd `_cut_sea`).
uniform vec4 dry_cut[8];
uniform int dry_cuts = 0;
uniform float dry_half = 30.0;
// The eye in a sunk tunnel's corridor (land_tunnels.gd `_hush_sea`): the sea is a
// level sheet and a cave's vault can stand over it, so no sea where the baked
// land stands dry_over m over the level, or the sheet shows across the bore.
uniform float dry_under = 0.0;
uniform float dry_over = 3.0;

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
// The chop's share in that light (1 the old look; the water look, EndlessSea
// --water-look, lights only the swell's faces: lit fine ripples read as a
// lumpy solid, gel, where water shows its ripples in the mirror).
uniform float body_shade_fine = 1.0;
// The chop shown by the eye's side of it (the fragment; 0 the old).
uniform float view_shade = 0.0;
uniform vec2 view_fade = vec2(120.0, 450.0);

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
// ...fading to their middle between these distances from the eye (m): up
// close it shades a wave, but from above the crossing swell trains interfere
// into a regular lattice of crests and troughs, and it paints a checkerboard.
uniform vec2 body_value_fade = vec2(150.0, 500.0);
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

// The FFT sea (EndlessSea, on unless `--sea-fft=0`, scripts/endless/sea_fft.gd): the
// wind sea and its chop as Tessendorf cascades, tiles `fft_sizes` m, in
// `fft_maps` (layer c: the shove xyz and dDx/dz; layer 3 + c: the height's
// slope and the shove's stretch dDx/dx, dDz/dz; with mips). The Gerstner sum
// keeps only the swell trains (waves 0..4), and they alone are mirrored on
// the CPU. Each cascade at `fft_strength`, all scaled by the slicks and
// rough stretches (`fft_patch`: slick, rough), the finer two also by the
// wind's paws (`fft_air` of zs_sea_air's swing). The heave (cascades 0 and 1,
// `fft_heave` of it) reaches as far as the body's. Past the pixel each
// cascade's lost slope (`fft_slope_var` over its band, `fft_band_long` ..
// `fft_band_short` m) turns into roughness. Fresh caps stand where the fold
// (1 - the Jacobian of cascades 0 and 1) passes `fft_foam.x`, full by `.y`,
// times `.z`; the foam buffer lays its trail at the same folds; far off,
// where the folds are finer than the pixel, `fft_far_foam` (cover in the
// rough, in a slick) stands in.
uniform int sea_fft = 0;
uniform sampler2DArray fft_maps : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 fft_sizes = vec3(250.0, 37.0, 5.7);
uniform vec3 fft_strength = vec3(1.0, 0.85, 0.45);
uniform vec2 fft_patch = vec2(0.55, 1.25);
uniform float fft_air = 0.7;
uniform float fft_heave = 1.0;
uniform vec3 fft_slope_var = vec3(0.0);
uniform vec3 fft_band_long = vec3(250.0, 6.2, 0.95);
uniform vec3 fft_band_short = vec3(6.2, 0.95, 0.05);
uniform vec3 fft_foam = vec3(0.25, 0.55, 1.2);
uniform vec2 fft_far_foam = vec2(0.05, 0.01);

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
// Round 3 (water-artifacts-handoff.md), the hand-over at a mouth: in the calm
// (and the plume the depth map carries out past the mouth, EndlessSea
// PLUME, --river-plume) the water is coloured no deeper than `plume_depth` m
// by this share (0: round 2's sea), and keeps this share of the wind sea's
// chop, so it ripples as the river's water it meets does (0: glassy, round 2).
uniform float plume_tint = 1.0;
uniform float plume_depth = 1.5;
uniform float calm_chop = 0.7;
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
// The sun's path broken into facets (0 the old soft path; see the fragment).
uniform float path_break = 0.0;
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
// 1: the V ends at its oldest point (0: its arms close round it in a ring).
uniform float wake_tail = 1.0;
// How fast the V's arms ride out (m/s, from the plane's speed).
uniform float wake_spread = 6.0;
// A second track on the same terms, the burrower's (scripts/burrower/
// wake_sheet.gd): its points, how many, its head (xz, unused, reach m) and
// how much wider it lies than the plane's.
uniform vec4 other_points[40];
uniform int other_count = 0;
uniform vec4 other_head = vec4(0.0);
uniform float other_wide = 1.8;
// The water round a leaping fish (scripts/endless/wake_fish.gd): its marks (xz,
// the moment it breaks, size), how many, and that clock.
uniform vec4 leap_marks[6];
uniform int leap_count = 0;
uniform float leap_now = 0.0;
// The water over a swimming fish (scripts/endless/swim_fish.gd), one or two:
// where (xz of its middle, xz of its way) and its body (length, its middle's
// depth, how far its fin stands out, strength).
uniform vec4 swim_at0 = vec4(0.0);
uniform vec4 swim_body0 = vec4(0.0);
uniform vec4 swim_at1 = vec4(0.0);
uniform vec4 swim_body1 = vec4(0.0);
uniform int swim_count = 0;
// How much of a fish's body shows through the water at its back (bluer and
// greener than red), and the depth (m) it fades over below that.
uniform vec3 swim_see = vec3(0.65, 0.9, 0.95);
uniform float swim_clear = 1.0;
// 0: the swimmer has a body of its own under the water, drawn as any bed is (the
// whale, scripts/endless/whale.gd); its hump, slick and shade stay.
uniform float swim_body = 1.0;
// 1: the water's depth (red 0..10 m, green 10..60 m), 2: foam cover,
// 6 (sea_foam 1): the lace's density, youth, buffer reach and churn, 7: the
// foam worked out per crest everywhere (no buffer), 8: the water's depth as
// the colour reads it (red bands 2 m, green to 30 m, blue the map's share),
// 9: the calm (red), the map not wholly used (green), a mouth's water taking
// its depth from the map's blue (blue), 10: the bed's depth (red bands 0.25 m,
// green to 3 m, blue the calm), 11: the depth map's texel middles over the
// colour (where a bilinear read creased).
uniform int debug_view = 0;
// 12-19: round 2's probes (12 alpha and depth bands, 13 the mouth read, 14
// the sheet's height, 15 the view's depth, 16 waver off and a flat bed, 17
// the bed seen, 18 waver off, 19 the waver).
// The depth's waver read through an integer hash (zs_noise_exact, 1); 0 the
// sine hash, whose lattice broke into hard-edged squares and panes once its
// coordinates reached the tens (the shallows and mouths, the deep sea).
uniform int waver_exact = 1;
// The depth map read through a B-spline (1) or bilinear (0, the earlier
// sea: creased on every 8 m texel, the calm's edge a staircase).
uniform int depth_smooth = 1;
// A mouth's water: its depth from the map's blue (1) or the bed seen on
// screen (0, the earlier sea: the ground's grid in squares and wedges).
uniform float mouth_smooth = 1.0;

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

#include "res://shaders/endless_surge.gdshaderinc"

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
	// The FFT sea (sea_fft 1) keeps only the swell trains here.
	int count = sea_fft > 0 ? 5 : BODY;
	for (int i = 0; i < BODY; i++) {
		if (i >= count) break;
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
		if (i >= count) break;
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
	if (foamy && sea_fft == 0) {
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

// Where the wind gusts hardest (zs_swell_body's clumps of whitecaps).
float zs_body_gust(vec2 p, float t) {
	vec2 hw = normalize(body_wind);
	vec2 gp = (p - hw * t * 2.0) / 55.0;
	return smoothstep(0.45, 0.8, zs_body_noise(gp + vec2(9.1, 3.7)) * 0.7 + zs_body_noise(gp * 2.7 + vec2(1.3, 8.8)) * 0.3);
}

// The surge (shaders/endless_surge.gdshaderinc) as the sea alone shows it.
// `surge_light`: how far a face turned to the sun or from it moves the water's
// light, how much of the sky's mirror a trough loses to the wave beside it, how
// dark the trough's water goes. `surge_white`: how far the foam's light goes
// from the sun's colour toward plain white.
uniform vec3 surge_light = vec3(0.5, 0.6, 0.8);
uniform float surge_white = 0.75;
// Far off, the sky's mirror on a steep face is what draws a crest: seen low
// over kilometres every one mirrors the bright sky alike, and every trough the
// dark wave beside it, thin ruled lines. From `surge_mirror.x` m to `.y` from
// the eye the surge's slope in the mirror goes, but for patches where the wave
// is tall and the wind's roughness doesn't scatter it, which keep up to `.z` of
// it: a far row comes and goes. (Seen that low any slope draws a line, so the
// rest keeps none.) The trough's dark, the crest's glow and its lighter water
// go with it. A huge `.x` gives the old look back, for an A/B.
uniform vec3 surge_mirror = vec3(250.0, 1100.0, 0.7);

// How much of the surge's slope the mirror keeps at rest xz `p`, `far` m from
// the eye: 1 near, less on low and scattered stretches far off.
float zs_surge_mirror(vec2 p, float t, float far, vec3 crest) {
	float away = smoothstep(surge_mirror.x, surge_mirror.y, far);
	if (away <= 0.0) return 1.0;
	float tall = smoothstep(7.0, 15.0, length(crest.xy) + max(crest.z, 0.0) * 0.6);
	float clear = smoothstep(0.35, 0.7, zs_body_noise(p / 380.0 + vec2(t * 0.008, 5.6)) * 0.6 + zs_body_noise(p / 150.0 + vec2(2.2, t * 0.015)) * 0.4);
	return mix(1.0, surge_mirror.z * tall * clear, away);
}

// The walls between cells of a bent grid: 0 on a wall, about 0.7 at a cell's heart.
float zs_surge_cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	float near = 8.0, next = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 c = o + vec2(zs_body_hash(i + o), zs_body_hash(i + o + vec2(19.1, 7.3))) - f;
			float d = dot(c, c);
			if (d < near) {
				next = near;
				near = d;
			} else if (d < next) {
				next = d;
			}
		}
	}
	return sqrt(next) - sqrt(near);
}

// Foam of `density` 0..1 as a mat of bubbles eaten away: rounded cell walls, a
// blotchy noise and a grain add up to a height, and the foam covers what stands
// above the line `density` sets. Thin foam is that height's broken tops, soft
// edged and part clear, gathered in patches over a milky veil; thick foam is
// crisper and closes down to holes. No wall is drawn as a line: drawn ones read
// as cracked glass from a low eye. Finer than the pixel it evens out into its
// share. `inner`: how far down from the mat's top, the shade inside thick foam.
float zs_surge_lace(vec2 p, float density, float footprint, out float inner) {
	vec2 q = vec2(p.x, p.y * 0.8);
	q += (vec2(zs_body_noise(p / 2.7 + vec2(4.1, 1.3)), zs_body_noise(p / 2.7 + vec2(0.9, 6.7))) - 0.5) * 1.6;
	float gather = zs_body_noise(p / 11.0 + vec2(6.6, 2.4)) * 0.6 + zs_body_noise(p / 4.1 + vec2(1.2, 5.5)) * 0.4;
	float thin = density * (0.35 + 0.8 * smoothstep(0.32, 0.68, gather));
	vec2 cell = vec2(2.3, 0.9);
	float seen = 1.0 - smoothstep(0.15, 0.5, footprint / cell.x);
	float seen_fine = 1.0 - smoothstep(0.15, 0.5, footprint / cell.y);
	float top = 0.5;
	inner = 0.0;
	if (seen > 0.0) {
		float big = 1.0 - smoothstep(0.0, 0.6, zs_surge_cells(q / cell.x + vec2(2.3, 8.8)));
		inner = (1.0 - big) * seen;
		top = mix(0.5, big, seen);
	}
	float fine = 0.5;
	if (seen_fine > 0.0) {
		fine = zs_body_noise(q / cell.y + vec2(7.7, 3.1)) * 0.6 + zs_body_noise(q / (cell.y * 0.47) + vec2(2.1, 7.3)) * 0.4;
		fine = mix(0.5, clamp((fine - 0.5) * 2.2 + 0.5, 0.0, 1.0), seen_fine);
	}
	float grain = mix(0.5, zs_body_noise(p / 0.34 + vec2(3.7, 9.2)) * 0.65 + zs_body_noise(p / 0.13 + vec2(8.2, 1.6)) * 0.35, 1.0 - smoothstep(0.04, 0.16, footprint));
	float height = top * 0.44 + fine * 0.36 + clamp((grain - 0.5) * 1.6 + 0.5, 0.0, 1.0) * 0.2;
	float soft = mix(mix(0.42, 0.1, smoothstep(0.4, 1.0, thin)), 0.75, 1.0 - seen);
	float line = 1.0 - thin * 0.92;
	float cover = smoothstep(line - soft * 0.5, line + soft * 0.5, height);
	float veil = smoothstep(0.02, 0.7, thin) * (0.4 + 0.6 * grain) * 0.42;
	cover *= mix(0.6, 1.0, smoothstep(0.25, 0.7, thin)) * smoothstep(0.0, 0.14, thin);
	return 1.0 - (1.0 - cover) * (1.0 - veil);
}

// The surge's white water `along` the crest: `thick` the cap and fingers,
// `left` what it leaves on the back (zs_surge_foam).
void zs_surge_white(vec2 p, float t, float footprint, float breaks, float off, float along, float back, out float thick, out float left) {
	float speed = sqrt(GRAVITY * SURGE_CREST_LENGTH / TAU);
	// The white water's shape rides with the crest, sliding back over it a
	// little; down the face it reaches in fingers.
	vec2 riding = vec2(along, off + speed * t * 0.85);
	float keep = 1.0 - smoothstep(1.5, 7.0, footprint);
	float fingers = mix(0.5, zs_body_noise(riding / vec2(13.0, 26.0)) * 0.6 + zs_body_noise(riding / vec2(5.0, 11.0) + vec2(4.3, 1.1)) * 0.4, keep);
	float reach = (back < 0.0 ? 26.0 * (0.15 + 1.5 * fingers * fingers) : 3.0 + 7.0 * fingers) * smoothstep(0.0, 0.7, breaks);
	float torn = mix(0.5, zs_body_noise(riding / 3.3 + vec2(1.3, 6.2)) * 0.6 + zs_body_noise(riding / 1.2 + vec2(5.2, 3.8)) * 0.4, 1.0 - smoothstep(0.3, 1.5, footprint));
	thick = clamp((1.0 - abs(back) / max(reach, 0.5) + (torn - 0.5) * 0.95) * 2.2, 0.0, 1.0);
	// The back: thinning away from the crest, gathered into streaks the way
	// the wave ran, bent.
	left = back <= 0.0 ? 0.0 : breaks * pow(max(1.0 - back / 58.0, 0.0), 1.4);
	if (left > 0.004) {
		vec2 bend = vec2(zs_body_noise(p / 46.0 + vec2(2.2, 8.1)), zs_body_noise(p / 15.0 + vec2(6.4, 0.3))) - 0.5;
		vec2 down = vec2(along + bend.x * 24.0 + bend.y * 7.0, off);
		float streak = zs_body_noise(down / vec2(9.0, 30.0) + vec2(1.9, 4.4)) * 0.72 + zs_body_noise(down / vec2(3.4, 13.0) + vec2(8.8, 3.3)) * 0.28;
		left *= mix(0.55, 0.1 + 1.4 * smoothstep(0.26, 0.74, streak), keep);
	}
}

// The surge's breakers at rest xz `p`, from `crest` (zs_surge): only tall
// waves break, in sections along the crest that ride with it. `cap`: the white
// water at the crest, in fingers down the face, how much of `laid` is that,
// less the shade inside it.
// `laid`: all the foam, the cap and what it leaves on the back, streaks and
// lace fixed in the water as the wave runs out from under them. `aired`: the
// milky water round both.
void zs_surge_foam(vec2 p, float t, float footprint, vec3 crest, out float cap, out float laid, out float aired) {
	cap = 0.0;
	laid = 0.0;
	aired = 0.0;
	float off, along, back;
	float breaks = zs_surge_breaks(p, t, crest, off, along, back);
	if (breaks <= 0.0) return;
	aired = breaks * breaks * smoothstep(-34.0, -6.0, back) * (1.0 - smoothstep(12.0, 62.0, back));
	float thick, left;
	zs_surge_white(p, t, footprint, breaks, off, along, back, thick, left);
	// Across the seam where `along` wraps, blend in the read from its far side.
	float seam = zs_surge_seam(along);
	if (seam > 0.0) {
		float thick2, left2;
		zs_surge_white(p, t, footprint, breaks, off, zs_surge_across(along), back, thick2, left2);
		thick = mix(thick, thick2, seam);
		left = mix(left, left2, seam);
	}
	float density = max(thick, left);
	if (density <= 0.004) return;
	float inner;
	laid = zs_surge_lace(p, min(density, 1.0), footprint, inner);
	cap = thick - inner * 0.75;
	// A line of crest finer than the pixel keeps only its share of white.
	laid *= 1.0 / (1.0 + footprint * 0.04);
}

const float FFT_N = 256.0;

// Cascade `c`'s map coordinates at rest xz `p` (layer c; + 3 for slopes).
vec3 zs_fft_uv(vec2 p, int c) {
	return vec3(p / fft_sizes[c] + 0.5 / FFT_N, float(c));
}

// The FFT sea's heave at rest xz `p` on a sheet of `cell` m cells: cascades
// 0 and 1 (the finest is finer than any vertex), each at the mip its cells
// can hold, scaled by `scale`.
vec3 zs_fft_heave(vec2 p, float cell, float scale) {
	vec3 s = vec3(0.0);
	for (int c = 0; c < 2; c++) {
		float lod = log2(max(cell * 2.0 * FFT_N / fft_sizes[c], 1.0));
		s += textureLod(fft_maps, zs_fft_uv(p, c), lod).xyz * fft_strength[c];
	}
	return s * scale * fft_heave;
}

// The FFT sea's surface at rest xz `p`: the slope of its coarse cascade
// (`wave`, the wind sea) and of the finer two (returned, the chop), the
// Jacobian of all three (`jac`) and of the two the foam reads (`fold`), the
// height (`height`) and the slope variance the mips have smoothed away past
// the pixel (`lost`). `scale` the slicks' and rough stretches', `air` the
// wind's paws (zs_sea_air).
vec2 zs_fft_surface(vec2 p, float footprint, float scale, float air, out vec2 wave, out float jac, out float fold, out float height, out float lost) {
	float dxx = 0.0, dzz = 0.0, dxz = 0.0;
	float fxx = 0.0, fzz = 0.0, fxz = 0.0;
	vec2 dh = vec2(0.0);
	wave = vec2(0.0);
	height = 0.0;
	lost = 0.0;
	for (int c = 0; c < 3; c++) {
		float base = fft_strength[c] * scale;
		float sc = base * (c > 0 ? mix(1.0, air, fft_air) : 1.0);
		vec3 uv = zs_fft_uv(p, c);
		vec4 a = texture(fft_maps, uv);
		vec4 b = texture(fft_maps, vec3(uv.xy, float(c + 3)));
		if (c == 0) wave = b.xy * sc; else dh += b.xy * sc;
		dxx += b.z * sc;
		dzz += b.w * sc;
		dxz += a.w * sc;
		height += a.y * sc;
		if (c < 2) {
			fxx += b.z * base;
			fzz += b.w * base;
			fxz += a.w * base;
		}
		// The share of the band finer than the pixel (the slope's variance is
		// about even per octave of a wind sea's tail).
		float gone = clamp(log(max(2.0 * footprint / fft_band_short[c], 1.0)) / log(max(fft_band_long[c] / fft_band_short[c], 1.001)), 0.0, 1.0);
		lost += fft_slope_var[c] * sc * sc * gone;
	}
	jac = (1.0 + dxx) * (1.0 + dzz) - dxz * dxz;
	fold = (1.0 + fxx) * (1.0 + fzz) - fxz * fxz;
	// The slope of the shoved sheet: steeper where the shove bunches it.
	vec2 bunch = 1.0 / max(vec2(1.0 + dxx, 1.0 + dzz), vec2(0.3));
	wave *= bunch;
	return dh * bunch;
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

// The depth map read through a cubic B-spline (four bilinear taps), its
// texels `spread` apart: smooth across the texels, where the bilinear read
// creased at every texel's middle. The map's texels are 8 m and the tint runs
// shallow to mid within 7 m of depth, so a bilinear read drew the shallows
// (and the deep water's tint between 22 and 55 m) as a lattice of flat-toned
// 8 m squares.
vec4 zs_depth_map_smooth(vec2 uv, float spread) {
	vec2 size = vec2(textureSize(depth_map, 0)) / spread;
	vec2 st = uv * size - 0.5;
	vec2 i = floor(st);
	vec2 f = st - i;
	vec2 f2 = f * f, f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 g0 = w0 + w1, g1 = w2 + w3;
	vec2 h0 = (i - 0.5 + w1 / g0) / size;
	vec2 h1 = (i + 1.5 + w3 / g1) / size;
	return g0.y * (g0.x * textureLod(depth_map, h0, 0.0) + g1.x * textureLod(depth_map, vec2(h1.x, h0.y), 0.0))
		+ g1.y * (g0.x * textureLod(depth_map, vec2(h0.x, h1.y), 0.0) + g1.x * textureLod(depth_map, h1, 0.0));
}

// The water's depth under `p` from the map (DEEP off it; `known` 0 there).
float zs_map_depth(vec2 p, out float known) {
	known = 0.0;
	if (depth_at.w <= 0.0) return DEEP;
	vec2 uv = (p - depth_at.xy) / depth_at.z;
	vec2 rim = min(uv, 1.0 - uv);
	known = smoothstep(0.0, 0.05, min(rim.x, rim.y));
	if (known <= 0.0) return DEEP;
	if (depth_smooth > 0) return sea_level - zs_depth_map_smooth(uv, 1.0).r;
	return sea_level - texture(depth_map, uv).r;
}

// The river drawn under the sea at `p` (the map's blue over its alpha, both
// read smooth): x how far under the sea's level its water lies (m), y how
// much of `p` is on its water (0..1).
vec2 zs_map_mouth(vec2 p) {
	if (depth_at.w <= 0.0) return vec2(0.0);
	vec2 uv = (p - depth_at.xy) / depth_at.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return vec2(0.0);
	vec4 m = zs_depth_map_smooth(uv, 1.0);
	// (A river a texel or two wide reads under 1 through the B-spline.)
	return vec2(m.a > 0.01 ? max(m.b, 0.0) / m.a : 0.0, smoothstep(0.1, 0.55, m.a));
}

// How still the sea lies at `p` up a river's mouth (0 open sea, 1 calm).
float zs_river_calm(vec2 p) {
	if (depth_at.w <= 0.0 || river_calm <= 0.0) return 0.0;
	vec2 uv = (p - depth_at.xy) / depth_at.z;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) return 0.0;
	float calm = textureLod(depth_map, uv, 0.0).g;
	// (Bilinear, the calm's edge stood on the texels' grid, a staircase of 8 m
	// steps the sea's swell and colour changed on. The B-spline rounds it; a
	// river two texels wide keeps its full calm from the bilinear read.)
	if (depth_smooth > 0) calm = max(calm, zs_depth_map_smooth(uv, 1.0).g);
	return clamp(calm, 0.0, 1.0) * river_calm;
}

// What a fish does to the surface at `p`: the slope added. Before it breaks the
// water domes and turns over it; after, rings run out, a few crests to a packet
// slowing as they go, as the slope only, so the sky and the sun take them.
vec2 zs_leap_slope(vec2 p) {
	vec2 sum = vec2(0.0);
	for (int i = 0; i < leap_count; i++) {
		vec4 m = leap_marks[i];
		float age = leap_now - m.z;
		if (m.w <= 0.0 || age < -0.7 || age > 5.0) continue;
		vec2 d = p - m.xy;
		float r2 = dot(d, d);
		float size = m.w;
		float front = size * 0.35 + 2.2 * (1.0 - exp(-max(age, 0.0) / 1.8)) * 2.0;
		float reach = front + 2.0 * size + 0.5;
		if (r2 > reach * reach) continue;
		float r = sqrt(r2);
		vec2 out_way = d / max(r, 1e-3);
		if (age < 0.0) {
			float w = 0.55 * size;
			float grow = smoothstep(-0.65, -0.05, age);
			float dome = r / (w * w) * exp(-r2 / (2.0 * w * w)) * w;
			float a = atan(d.y, d.x);
			float turn = sin(a * 2.0 + r * 5.0 / size + age * 7.0) * exp(-r2 / (3.0 * w * w));
			sum += (out_way * dome * 0.9 + vec2(-out_way.y, out_way.x) * turn * 0.5) * grow;
		} else {
			float wave = 0.85 + 0.25 * age;
			float e = (r - front) / (0.55 + 0.45 * age + 0.4 * size);
			float packet = exp(-e * e);
			float fall = exp(-age / 1.6) / (1.0 + r * 0.25);
			sum += out_way * sin((r - front) * TAU / wave) * packet * fall * 0.75;
			// Where it went through: broken, for a moment, a boil of small slopes.
			float w = 0.5 * size + 0.25 * age;
			float boil = exp(-r2 / (w * w)) * exp(-age / 0.8);
			float a = atan(d.y, d.x);
			sum += vec2(sin(d.x * 19.0 + a * 3.0 + age * 6.0), sin(d.y * 23.0 - a * 2.0 - age * 5.0)) * boil * 0.7;
		}
	}
	return sum;
}

// What one swimming fish does to the water at `p`: the slope added (a low hump
// pushed ahead of its head and the hollow behind it, and where its fin cuts, a
// pair of short ripples), and how smooth it leaves the water over its back
// (`slick`), how dark its body shows (`shade`), the spray off its fin, and where
// it lies under the surface (`body_over`: the bed seen there is the fish, not a
// shallow, so no shore foam on its back). Those two are where the eye sees it,
// `look` m across per m down from `p`.
vec2 zs_swim_one(vec2 p, vec2 look, vec4 at, vec4 body, inout float slick, inout float shade, inout float spray, inout float body_over) {
	float l = body.x;
	if (l <= 0.0 || body.w <= 0.0) return vec2(0.0);
	vec2 d = p - at.xy;
	if (dot(d, d) > l * l * 6.0) return vec2(0.0);
	vec2 way = at.zw;
	vec2 side = vec2(-way.y, way.x);
	float u = dot(d, way);
	float v = dot(d, side);
	float near = (1.0 - smoothstep(0.6, 2.2, body.y)) * body.w;
	// The hump and the hollow, as heights (m) whose slope is taken.
	float a = 0.05 * l * near;
	vec2 grad = vec2(0.0);
	float su = 0.28 * l, sv = 0.17 * l;
	float x = u - 0.3 * l;
	float g = exp(-(x * x) / (su * su) - (v * v) / (sv * sv));
	grad += a * g * vec2(-2.0 * x / (su * su), -2.0 * v / (sv * sv));
	su = 0.36 * l;
	sv = 0.2 * l;
	x = u + 0.2 * l;
	g = exp(-(x * x) / (su * su) - (v * v) / (sv * sv));
	grad -= 0.5 * a * g * vec2(-2.0 * x / (su * su), -2.0 * v / (sv * sv));
	// Smoothed over its back and for a way behind, widening.
	float wide = 0.15 * l + 0.07 * max(-u, 0.0);
	slick = max(slick, (1.0 - smoothstep(0.2 * l, 0.48 * l, u)) * smoothstep(-2.0 * l, -0.5 * l, u) * exp(-(v * v) / (wide * wide)) * near * 0.55);
	// The body, darker, narrowing to the tail.
	vec2 seen_at = d + look * max(body.y, 0.0);
	float su2 = dot(seen_at, way);
	float sv2 = dot(seen_at, side);
	float e = (su2 + 0.02 * l) / (0.46 * l);
	float c = sv2 / (0.09 * l * (1.0 - 0.45 * clamp(-e, 0.0, 1.0)));
	shade = max(shade, exp(-(e * e + c * c) * 1.3) * (1.0 - smoothstep(0.5, 2.4, body.y)) * body.w);
	// Its back is nearer the top than its middle: seen there too.
	vec2 back_at = d + look * max(body.y - 0.09 * l, 0.0);
	for (int k = 0; k < 2; k++) {
		vec2 q = k == 0 ? seen_at : back_at;
		float ou = dot(q, way) / (0.62 * l);
		float ov = dot(q, side) / (0.26 * l);
		body_over = max(body_over, (1.0 - smoothstep(0.5, 1.0, ou * ou + ov * ov)) * body.w);
	}
	// The fin: where it stands out, a small bow wave pushed ahead of its edge, a
	// feather of spray off the edge widening behind, and a short V of ripples.
	// Its edge at the waterline is a little ahead of the body's middle
	// (scripts/endless/swim_fish.gd grows it, shaders/wake_fish.gdshader).
	if (body.z > 0.0) {
		float fin = smoothstep(0.03, 0.15, body.z) * body.w;
		float b = 0.02 * l - u;
		if (b > -0.9) {
			// The bow wave, as a height whose slope is taken.
			float bx = b + 0.2;
			float bow = 0.035 * fin * exp(-(bx * bx) / 0.1 - (v * v) / 0.06);
			grad += bow * vec2(2.0 * bx / 0.1, -2.0 * v / 0.06);
			float w = 0.05 + 0.2 * max(b, 0.0);
			float lead = smoothstep(-0.12, 0.04, b);
			spray = max(spray, exp(-(v * v) / (w * w)) * exp(-max(b, 0.0) / 0.8) * lead * fin);
			float off = abs(v) - 0.36 * max(b, 0.0);
			float arm = exp(-(off * off) / 0.03) * exp(-max(b, 0.0) / 1.6) * lead * fin * smoothstep(0.0, 0.3, b);
			grad.y += sin(off * TAU / 0.35) * arm * 0.22 * sign(v);
		}
	}
	return way * grad.x + side * grad.y;
}

// Whether the bed seen at `r` is a swimming fish's body, under the surface at
// `top`: inside its length and breadth and no deeper than its belly, where the
// lake's own bed lies metres down. Its back is no shallow: no shore foam, no
// clear edge, and the water over it its own.
vec2 zs_swim_hit(vec3 r, float top, vec4 at, vec4 body) {
	float l = body.x;
	if (l <= 0.0 || body.w <= 0.0) return vec2(0.0);
	vec2 d = r.xz - at.xy;
	float u = dot(d, at.zw) / (0.75 * l);
	float v = dot(d, vec2(-at.w, at.z)) / (0.4 * l);
	float below = top - r.y;
	float hit = float(u * u + v * v < 1.0 && below < body.y + 0.25 * l + 0.8) * body.w;
	return vec2(hit, hit * (1.0 - smoothstep(0.15, 0.85, u * u + v * v * 2.5)));
}

// A wake at `p` (track 0 the plane's, 1 the burrower's): its foam (returned), the stirred water round it
// (`stirred`, 0..1) and the slope its ripples add. Only the nearest point of
// the track counts, so the arms are one V and not a ring per point.
float zs_wake_track(vec2 p, int track, out vec2 slope, out float stirred) {
	slope = vec2(0.0);
	stirred = 0.0;
	if (wake <= 0.0) return 0.0;
	int count = track == 0 ? wake_count : other_count;
	vec4 at = track == 0 ? wake_head : other_head;
	if (count < 2 || distance(p, at.xy) > at.w) return 0.0;
	float best = 1e9;
	vec2 best_across = vec2(0.0);
	float best_age = 0.0, best_strength = 0.0;
	for (int i = 0; i < WAKE_POINTS - 1; i++) {
		if (i + 1 >= count) break;
		vec4 a = track == 0 ? wake_points[i] : other_points[i];
		vec4 b = track == 0 ? wake_points[i + 1] : other_points[i + 1];
		if (a.w <= 0.0 && b.w <= 0.0) continue;
		vec2 ab = b.xy - a.xy;
		float len2 = max(dot(ab, ab), 1e-4);
		float t_raw = dot(p - a.xy, ab) / len2;
		// Past the oldest point there is no track: the nearest point of it
		// would be that end, and its arm a ring round it.
		if (wake_tail > 0.5 && t_raw > 1.0 && i + 2 >= count) continue;
		float t = clamp(t_raw, 0.0, 1.0);
		vec2 near = a.xy + ab * t;
		float d = distance(p, near);
		if (track == 1) d /= other_wide;
		if (d < best) {
			best = d;
			best_across = (p - near) / max(distance(p, near), 1e-3);
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

// Both tracks: the plane's and the burrower's. Its stirred water is the lesser
// (it would pale a broad patch).
// `burrow` is the burrower's own track's foam (0 while none runs).
float zs_wake(vec2 p, out vec2 slope, out float stirred, out float burrow) {
	float own = zs_wake_track(p, 0, slope, stirred);
	vec2 other_slope;
	float other_stirred;
	float other = zs_wake_track(p, 1, other_slope, other_stirred);
	burrow = other;
	slope += other_slope;
	stirred = max(stirred, other_stirred * 0.4);
	return max(own, other);
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
// it fades. Finer than the pixel, it evens out into its mean cover. `shred`
// 1 opens even young foam into veins, with no solid islands (the surge).
float zs_foam_lace(vec2 p, float density, float youth, float footprint, float shred) {
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
	float open = clamp(1.0 - youth * (1.0 - shred), 0.0, 1.0);
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
		if (sea_fft > 0) shift += zs_fft_heave(world.xz, cell, mix(fft_patch.x, fft_patch.y, zs_body_rough(world.xz, zs_flow_time)));
	} else {
		zs_swell(world.xz, zs_flow_time, cell, shift, crest, rough);
	}
	VERTEX += shift * near * (1.0 - zs_river_calm(world.xz));
	if (sea_body > 0 && surge_edge.z > 0.0) {
		vec3 surge;
		float surge_jac, surge_lift, surge_share;
		vec3 surge_crest;
		zs_surge(world.xz, zs_flow_time, cell * 0.6, surge, surge_jac, surge_lift, surge_share, surge_crest);
		VERTEX += surge * (1.0 - smoothstep(surge_belt.z, surge_belt.w, reach));
	}
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	for (int i = 0; i < dry_cuts; i++) {
		vec2 from = dry_cut[i].xy;
		vec2 way = dry_cut[i].zw - from;
		vec2 off = world_position.xz - from;
		if (length(off - way * clamp(dot(off, way) / dot(way, way), 0.0, 1.0)) < dry_half) discard;
	}
	if (dry_under > 0.0 && depth_at.w > 0.0) {
		vec2 land_uv = (world_position.xz - depth_at.xy) / depth_at.z;
		if (land_uv == clamp(land_uv, vec2(0.0), vec2(1.0)) && textureLod(depth_map, land_uv, 0.0).r > sea_level + dry_over) discard;
	}
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
	// The surge: its slope joins the swell's; its height is kept apart, the
	// body's light scaled to waves a thousandth its size.
	float surge_jac = 1.0, surge_lift = 0.5, surge_share = 0.0;
	vec3 surge_crest = vec3(0.0);
	vec2 surge_slope = vec2(0.0);
	if (sea_body > 0 && surge_edge.z > 0.0) {
		vec3 surge;
		surge_slope = zs_surge(rest_xz, t, footprint, surge, surge_jac, surge_lift, surge_share, surge_crest);
		slope += surge_slope;
	}
	vec2 detail;
	// The FFT sea (sea_fft 1): the wind sea's slope joins the swell's, the
	// finer cascades are the chop, and the folds make the fresh caps.
	float fft_jac = 1.0;
	if (sea_fft > 0) {
		float rough_patch = zs_body_rough(rest_xz, t);
		vec2 wave;
		float fold, height;
		detail = zs_fft_surface(rest_xz, footprint, mix(fft_patch.x, fft_patch.y, rough_patch), air, wave, fft_jac, fold, height, chop_rough) * (1.0 - still * (1.0 - calm_chop));
		slope += wave * (1.0 - still);
		shift.y += height * (1.0 - still);
		jac *= mix(clamp(fft_jac, 0.0, 1.5), 1.0, still);
		float gust = zs_body_gust(rest_xz, t);
		// Ragged edges: the fold's outline wanders with a finer noise.
		float ragged = zs_body_noise(rest_xz / 1.7 + vec2(3.1, 0.4)) * 0.6 + zs_body_noise(rest_xz / 0.6 + vec2(7.7, 2.2)) * 0.4;
		ragged = mix(0.5, ragged, 1.0 - smoothstep(0.15, 0.6, footprint));
		float fresh = clamp(smoothstep(fft_foam.x, fft_foam.y, 1.0 - fold + (ragged - 0.5) * 0.3) * fft_foam.z, 0.0, 1.0) * (foam_caps.y + (1.0 - foam_caps.y) * gust) * (1.0 - still);
		// Far off the folds are finer than the pixel: their mean cover.
		float fine = 1.0 - smoothstep(fft_band_short.x, fft_band_long.x * 0.25, footprint * 4.0);
		float far = mix(fft_far_foam.y, fft_far_foam.x, rough_patch) * (0.5 + gust);
		caps = max(caps, mix(far * 0.5, fresh, fine));
		trail = vec2(mix(far, fresh * 0.9, fine), fresh * fine);
	} else {
		detail = zs_chop(rest_xz, t, air, footprint, chop_rough);
	}
	vec2 wake_slope;
	float stirred;
	float zs_burrow_foam;
	float waked = zs_wake(rest_xz, wake_slope, stirred, zs_burrow_foam);
	if (leap_count > 0) slope += zs_leap_slope(rest_xz);
	// A swimming fish: its hump, the chop stilled over its back.
	float swim_slick = 0.0, swim_shade = 0.0, swim_spray = 0.0, swim_over = 0.0;
	vec2 swim_slope = vec2(0.0);
	if (swim_count > 0) {
		// Where the water is now, not its rest: the swell's sideways sway put the
		// fin's spray a metre or two off the fin.
		vec2 look = -eye.xz / max(eye.y, 0.12);
		swim_slope = zs_swim_one(world_position.xz, look, swim_at0, swim_body0, swim_slick, swim_shade, swim_spray, swim_over);
		if (swim_count > 1) swim_slope += zs_swim_one(world_position.xz, look, swim_at1, swim_body1, swim_slick, swim_shade, swim_spray, swim_over);
		slope += swim_slope;
		detail *= 1.0 - swim_slick;
		wake_slope *= 1.0 - swim_slick * 0.6;
	}
	float rain_on = zs_rain_on_water(rest_xz); // weather lane rain
	slope += zs_rain_pocks(rest_xz, rain_on, footprint, t);
	vec3 normal = normalize(vec3(-(slope.x + detail.x + wake_slope.x), 1.0, -(slope.y + detail.y + wake_slope.y)));
	// A calmer normal for the sky's mirror, so the reflection reads as one
	// rippled image rather than noise.
	// Far off the surge keeps only part of its slope in it (zs_surge_mirror).
	// So does the dark of the wave beside a trough (`walled`, below): both
	// draw the far rows.
	float surge_kept = surge_share > 0.0 ? zs_surge_mirror(rest_xz, t, distance_to, surge_crest) : 1.0;
	vec2 calm_slope = slope - surge_slope * (1.0 - surge_kept);
	vec3 calm = normalize(vec3(-(calm_slope.x + detail.x * calm_share), 1.0, -(calm_slope.y + detail.y * calm_share)));
	float facing = max(dot(eye, normal), 0.0);
	float sigma = sqrt(swell_rough + chop_rough);
	float roughness = clamp(0.06 + sigma * 1.4 + footprint * 0.0015, 0.06, 0.5);
	float fresnel = fresnel_floor + (1.0 - fresnel_floor) * pow(1.0 - max(dot(eye, calm), 0.0), fresnel_power);
	fresnel *= 1.0 - 0.25 * paw * min(zs_wind_strength, 1.0);
	fresnel *= 1.0 - 0.2 * stirred;
	// Over a swimming fish less of the sky, so its body shows through.
	fresnel *= 1.0 - 0.35 * swim_shade;

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
	// Something behind standing higher than the water here is no bed: the wave
	// hides it whole. Nor, on the swell, is anything short of the deep under
	// it: seen level through a face, the far coast stands behind at the sea's
	// own height, kilometres off, and showed faint through the clear water as
	// a grey line at the eye's height (and the far land as grey shapes).
	float dbg_hid = 0.0;
	if (depth > 0.0 && (receiver.y > world_position.y + 0.05 || (surge_share > 0.0 && receiver.y > sea_level - 2.0))) {
		dbg_hid = receiver.y > world_position.y + 0.05 ? 0.5 : 1.0;
		depth = 0.0;
		bed_depth = DEEP;
	}
	bed_depth = max(bed_depth, 0.0);
	float through = depth > 0.0 ? length(receiver - world_position) : DEEP;
	// The water's depth from the map (DEEP off it).
	float known;
	float mapped = zs_map_depth(rest_xz, known);
	// Up a river's mouth the bed behind is the river's water, drawn flat under
	// the sea's on the ground's grid (endless_ground's vertex lift): read off
	// the screen it came in the grid's facets, squares and wedges of paler and
	// darker water, and the sea faded in over it by them. On the river's water
	// the sea takes that depth from the map's (`zs_map_mouth`: the drawn
	// water's depth under the sea's level, smooth), never under the map's bed
	// (a bar beside the channel), seen through as the ground sees its own.
	float on_mouth = 0.0;
	vec2 dbg_mouth = debug_view == 13 ? zs_map_mouth(rest_xz) : vec2(0.0);
	if (still > 0.0 && depth > 0.0 && mouth_smooth > 0.0) {
		vec2 mouth = zs_map_mouth(rest_xz);
		on_mouth = clamp(still * mouth.y * mouth_smooth, 0.0, 1.0);
		if (on_mouth > 0.0) {
			float sunk = max(min(mouth.x, mapped) + world_position.y - sea_level, 0.0);
			bed_depth = mix(bed_depth, sunk, on_mouth);
			through = mix(through, sunk / max(eye.y, 0.15), on_mouth);
		}
	}
	// A swimming fish seen here (its body, not the lake's bed): where, and how much,
	// thinning to its nose, tail and sides as water blurs an edge.
	vec2 swim_seen = vec2(0.0);
	if (swim_count > 0 && depth > 0.0) {
		swim_seen = zs_swim_hit(receiver, world_position.y, swim_at0, swim_body0);
		if (swim_count > 1) swim_seen = max(swim_seen, zs_swim_hit(receiver, world_position.y, swim_at1, swim_body1));
	}
	swim_seen *= swim_body;
	float swim_hit = swim_seen.x;

	// The water's depth here: the map's where it reaches, else the bed seen.
	// On a mouth's water the bed seen (the river drawn under the sea, its depth
	// smooth from the map's blue above): the channel is finer than the map's
	// red. Off it, by the channel, the map's as on any shore, so the colour's
	// rule does not change on the line where the calm stops.
	if (mouth_smooth > 0.0) known *= 1.0 - on_mouth;
	else known *= 1.0 - still;
	// (The exact hash: the sine one broke into 9 m squares; waver_exact 0 the
	// old.)
	float waver = waver_exact > 0
		? mix(0.8, 1.25, zs_noise_exact(rest_xz * 0.03) * 0.7 + zs_noise_exact(rest_xz * 0.11 + vec2(4.1, 7.3)) * 0.3)
		: mix(0.8, 1.25, zs_noise(rest_xz * 0.03) * 0.7 + zs_noise(rest_xz * 0.11 + vec2(4.1, 7.3)) * 0.3);
	if (debug_view == 18 || debug_view == 16) waver = 1.0;
	float fallback = max(bed_depth, through * 0.55);
	float water_depth = max(mix(fallback, mapped, known), 0.0) * waver;
	// The river's pale water carried out over the sea in its plume (the calm
	// the depth map bakes past the mouth): coloured no deeper than the
	// mouth's channel, so the pale channel fades into the sea's blue over the
	// plume instead of on the line where the river's water ends.
	if (plume_tint > 0.0) water_depth = mix(water_depth, min(water_depth, plume_depth * waver), still * plume_tint);

	vec3 seen = exp(-absorb * through) * exp(-max(bed_depth, through * 0.4) / bed_fade);
	// Over a fish the water is thicker than a clear shallow's: its back a dark
	// shape, its sides and belly going to the water's colour as they go down.
	seen = mix(seen, swim_see * exp(-bed_depth / swim_clear) * swim_seen.y, swim_hit);
	vec3 bed = textureLod(sea_screen, uv, 0.0).rgb;
	if (debug_view == 16) bed = vec3(0.1, 0.12, 0.1);

	vec3 column = mix(tint_shallow, tint_mid, smoothstep(0.0, tint_depths.y, water_depth));
	column = mix(column, tint_deep, smoothstep(tint_depths.y * 0.6, tint_depths.z, water_depth));
	column = mix(column, tint_abyss, smoothstep(tint_depths.z, tint_depths.w, water_depth));
	column = mix(tint_shallow, column, smoothstep(0.0, tint_depths.x, water_depth) * 0.6 + 0.4);
	column *= zs_palette_water;
	vec3 ambient = zs_hemi_sky * zs_hemi_energy / PI * zs_wx_water_fill(); // weather lane rain
	vec3 key = zs_key_irradiance * max(zs_key_direction.y, 0.0) / PI;
	vec3 light = (ambient + key * 0.8) * water_light;
	// The body: the water's light across the wave, darker in the troughs and
	// lighter, greener up the crests, and a touch darker where it is rough.
	float lift = 0.5;
	float rough_here = 0.0;
	if (sea_body > 0) {
		float scale = body_swell.x * 0.9 + body_swell.y * 0.3 + 0.05;
		lift = smoothstep(-1.0, 1.0, shift.y / scale);
		lift = mix(lift, 0.5, smoothstep(body_value_fade.x, body_value_fade.y, length(world_position - CAMERA_POSITION_WORLD)));
		// (Far off, the crest's lighter water too comes and goes with the mirror.)
		lift = mix(lift, mix(0.5, surge_lift, 0.6 + 0.4 * surge_kept), surge_share);
		jac = min(jac, surge_jac);
		rough_here = zs_body_rough(rest_xz, t);
		vec3 up_tint = mix(column, sss_color * zs_palette_water * 0.55, 0.07);
		column = mix(column * body_value.x, up_tint * body_value.y, lift) * mix(1.0, 0.85, rough_here);
	}
	vec3 water = column * light * (vec3(1.0) - seen) + bed * seen;
	// (Without the surge's own slope, which would pin this at its clamp and take
	// the chop's shading off the great faces.)
	if (sea_motion > 0) water *= 1.0 + clamp(dot(normal.xz + (surge_slope + detail * (1.0 - body_shade_fine)) * normal.y, normalize(zs_sun_direction.xz + vec2(1e-4))) * 2.0, -0.5, 0.5) * body_shade;
	// The water look's ripples (view_shade): lighter on the faces tilted away
	// from the eye, which see it glancing and mirror the paler low sky, darker
	// on those turned to it. Tied to the eye as a mirror's are, not to the sun
	// as a solid's: so they read as water.
	// Faded with range (view_fade, m), so far water goes to a calm mirror
	// rather than a field of strokes.
	if (view_shade > 0.0) water *= 1.0 + clamp(dot(normal.xz, -normalize(eye.xz + vec2(1e-4))) / max(normal.y, 0.2) * 2.5, -0.4, 0.4) * view_shade * (1.0 - smoothstep(view_fade.x, view_fade.y, distance_to));
	// The surge's mass: its faces lit or turned from the sun by the long waves'
	// own slope, the chop left out, and its troughs a deeper blue.
	if (surge_share > 0.0) {
		float turned = -dot(surge_slope, normalize(zs_sun_direction.xz + vec2(1e-4))) * 3.0;
		water *= 1.0 + clamp(turned, -1.0, 1.0) * surge_light.x * surge_share * smoothstep(-0.05, 0.25, zs_sun_direction.y);
		water *= mix(1.0, surge_light.z, smoothstep(0.5, 0.1, surge_lift) * surge_share);
		// The chop shows on the wave's great back seen from above, where the
		// sky's mirror is faint.
		water *= 1.0 + clamp(dot(detail, normalize(zs_sun_direction.xz + vec2(1e-4))) * 3.5, -0.4, 0.4) * surge_share;
	}
	// Stirred water behind the plane: lighter with the air churned into it.
	water = mix(water, mix(tint_mid, tint_deep, 0.5) * zs_palette_water * light, stirred * 0.18);
	// A swimming fish's dark back, under the water.
	water *= 1.0 - 0.5 * swim_shade;

	// Light through the crests facing the sun.
	vec3 sun = zs_sun_direction;
	vec2 sun_flat = normalize(sun.xz + vec2(1e-4));
	float toward = pow(clamp(dot(-eye.xz / max(length(eye.xz), 1e-3), sun_flat), 0.0, 1.0), 3.0);
	float lifted = smoothstep(0.06, 0.2, crest) * (0.25 + 0.75 * toward) * smoothstep(-0.05, 0.2, sun.y);
	water += tint_mid * zs_palette_water * key * lifted * crest_glow * 0.5 * smoothstep(3.0, 12.0, water_depth);

	// Foam. The shore: a broken line where the water thins out, and bands
	// rolling in over the shelf.
	float near_bed = depth > 0.0 ? min(bed_depth, mix(bed_depth, mapped, known * 0.5)) : mapped;
	near_bed = mix(near_bed, max(near_bed, mapped), swim_over);
	near_bed = mix(near_bed, max(near_bed, 4.0), swim_hit);
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
	float surge_cap = 0.0, surge_laid = 0.0, surge_aired = 0.0;
	if (sea_body > 0 && sea_foam > 0) {
		float open_sea = smoothstep(4.0, 12.0, water_depth);
		caps *= open_sea;
		vec2 left = mix(trail, held.rg, in_buffer) * open_sea;
		lace_density = max(left.x, caps);
		lace_youth = max(left.y, min(caps * 1.5, 1.0));
		churned = max(mix(left.x * 0.7, held.b, in_buffer) * open_sea, caps);
		// The sea's own small caps give the belt to the surge's breakers: they
		// keep to the high water, and thin out.
		if (surge_share > 0.0) {
			float kept = mix(1.0, smoothstep(0.5, 0.8, surge_lift) * 0.8, surge_share);
			lace_density *= kept;
			churned *= kept;
			zs_surge_foam(rest_xz, t, footprint, surge_crest, surge_cap, surge_laid, surge_aired);
		}
		wake_laid = held.a * in_buffer * wake;
		// The churned water round them, lighter and greener.
		water = mix(water, mix(tint_mid, sss_color, 0.25) * zs_palette_water * light * 1.15, smoothstep(0.02, 0.6, churned) * 0.12 * foam_lace.w);
		water = mix(water, mix(tint_shallow, sss_color, 0.3) * zs_palette_water * light * 0.8, surge_aired * 0.2);
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
	// The spray off a swimming fish's fin, fine and broken.
	// Its grain is finer than the wake's: droplets, not patches.
	if (swim_spray > 0.0) {
		float fine = zs_noise(rest_xz * 7.0 + vec2(t * 1.1, t * 0.7)) * 0.6 + zs_noise(rest_xz * 17.0 - vec2(t * 0.9, 0.0)) * 0.4;
		foamed = max(foamed, smoothstep(0.3, 0.75, swim_spray * (0.4 + 1.3 * fine)) * 0.85 * foam);
	}
	// Far off the pattern is finer than a pixel: an even wash instead.
	foamed = mix(foamed, cover * 0.6 * foam, smoothstep(0.15, 0.8, footprint));
	if (sea_foam > 0) {
		// The wake's foam left in the buffer joins in as foam already old.
		float wake_youth = clamp(wake_laid * 1.2 - 0.4, 0.0, 0.6);
		float laced = zs_foam_lace(rest_xz, max(lace_density, wake_laid * 0.9), lace_density >= wake_laid * 0.9 ? lace_youth : wake_youth, footprint, surge_share * 0.85);
		foamed = max(foamed, laced * foam);
		foamed = max(foamed, surge_laid * foam);
	}
	foamed = clamp(foamed, 0.0, 1.0) * float(depth > 0.0 || known > 0.0 || waked > 0.0);
	float lip = (1.0 - smoothstep(0.0, 0.15, bed_depth)) * float(depth > 0.0) * (1.0 - still) * (1.0 - max(swim_over, swim_hit));
	vec3 white = vec3(0.9, 0.96, 1.0) * (ambient * 1.1 + key * 0.8);
	// Fresh foam stands up a little: brighter, and lit by its own slope.
	if (sea_foam > 0) white *= 1.0 + 0.1 * lace_youth + 0.18 * clamp(dot(normal, zs_key_direction), -0.5, 1.0) * float(lace_density > 0.0);
	// The surge's foam: white, not the sun's colour, and thick where it is cap.
	if (surge_share > 0.0) {
		float value = dot(white, vec3(0.3, 0.6, 0.1));
		white = mix(white, vec3(0.97, 0.99, 1.0) * value * (1.3 + 0.35 * surge_cap), surge_white * surge_share);
	}
	water = mix(water, white, foamed * 0.92);
	// The burrower's wake: its foam as clear white, not the sand the dim lit foam let through.
	if (zs_burrow_foam > 0.0) {
		float bf = smoothstep(0.1, 0.5, zs_burrow_foam * (0.4 + 1.4 * fleck));
		water = mix(water, vec3(0.97, 0.99, 1.0) * max(light * 1.0, vec3(0.85)), bf * 0.9);
	}
	water += tint_shallow * (ambient + key) * lip * 0.4;

	// The mirror: the sky, the cloud field, and what stands on screen.
	vec3 reflected = reflect(-eye, calm);
	reflected.y = abs(reflected.y);
	// Held under 0.98 by its brightest channel, not each channel: a low sun's
	// hot orange band clipped channel by channel went yellow, and pale yellow
	// over the dark water read lime at dawn and dusk.
	vec3 sky = max(zsSkyGradient(reflected), vec3(0.0));
	sky *= min(1.0, 0.98 / max(max(sky.r, sky.g), max(sky.b, 1e-4)));
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
	sky *= zs_wx_mirror(); // weather lane rain
	float mirrored = 0.0;
	vec3 mirror = vec3(0.0);
	if (mirror_steps > 0 && fresnel > 0.05) {
			// The march's ray bends off the calmer normal, and straightens with range: the
			// full chop's slope made rays hit and miss pixel by pixel, which cut the far
			// shore and the cliffs' mirror into dark dashes and jagged blobs.
			float ray_detail = 0.2;
			float ray_share = mirror_calm * (1.0 - 0.8 * smoothstep(80.0, 500.0, distance_to));
			vec3 ray = reflect(-eye, normalize(mix(vec3(0.0, 1.0, 0.0), normalize(vec3(-(calm_slope.x + detail.x * ray_detail), 1.0, -(calm_slope.y + detail.y * ray_detail))), ray_share)));
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
				// (Over a swimming fish its back, just under, isn't a thing to mirror.)
				if (gap > -(travelled - before) * 1.5 && hit.y > world_position.y - 0.2 + 0.6 * swim_over) {
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
	// A trough seen low mirrors the wave beside it, not the sky: what walls it
	// in is that wave's dark face, so the sea doesn't read as one sheet of sky.
	if (surge_share > 0.0) {
		float walled = smoothstep(0.6, 0.15, surge_lift) * (1.0 - smoothstep(0.05, 0.45, eye.y)) * surge_share * surge_kept;
		reflection = mix(reflection, zs_scene_to_display(column * light * 0.8), walled * surge_light.y);
	}

	// The sun: a soft path off the calm normal, and a crisp glitter off the
	// chop's own (hard-edged spots, fewer and finer far off).
	float shaded = cloud_shade > 0.0 ? zs_sea_cloud_shade(world_position) * cloud_shade : 0.0;
	vec3 smooth_n = normalize(vec3(-(slope.x + detail.x * path_share), 1.0, -(slope.y + detail.y * path_share)));
	vec4 path = zs_lake_glint(reflect(-eye, smooth_n), sun, zs_moon_direction, zs_celestial_clear, 0.0, glint_share);
	path.a *= 1.0 - shaded;
	// The path broken into the facets that catch the sun (path_break, the
	// water look): its lobe off the full normal is wide enough to paint the
	// ripples as soft white blobs, a wet gel's sheen; water's path is the
	// envelope of many small bright facets.
	if (path_break > 0.0) path.a *= mix(1.0, smoothstep(0.99, 0.998, dot(reflect(-eye, normal), sun)) * 1.6, path_break);
	float sunlight = smoothstep(-0.03, 0.12, sun.y);
	// (Not off a swimming fish's hump: a slope that broad lights as one hard
	// white sheet.)
	vec3 spark_normal = swim_count > 0 ? normalize(normal / max(normal.y, 1e-3) + vec3(swim_slope.x, 0.0, swim_slope.y)) : normal;
	float spark_dot = dot(reflect(-eye, spark_normal), sun);
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
		float tilt = max(1.0 - dot(half_way, spark_normal), 0.0) * 2.0;
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
		// (Light comes through a crest seen edge on; the great back looked down
		// on is no thin sheet.)
		float edge_on = mix(1.0, 0.65 * (1.0 - 0.75 * smoothstep(0.2, 0.6, eye.y)), surge_share);
		// Far off a row glowing whole reads as a ruled line, as the mirror does:
		// it comes and goes with the mirror's patches (zs_surge_mirror).
		float far_glow = mix(1.0, 0.2 + 0.8 * surge_kept, surge_share);
		glow = sss_strength * thin * back * toward_eye * smoothstep(-0.02, 0.15, sun.y) * (1.0 - shaded * 0.7) * smoothstep(3.0, 10.0, water_depth) * edge_on * far_glow;
		water += sss_color * (key * 1.2 + ambient * 0.3) * glow;
		fresnel *= 1.0 - 0.15 * rough_here;
	}
	vec3 lit = water + zs_lake_direct(vec3(0.0), normal, eye, zs_key_direction, zs_key_irradiance, max(roughness, 0.3)) * glint_share * 0.06 * (1.0 - foamed);
	lit *= 1.0 - 0.4 * shaded;

	// (On the surge's great backs the mirror is the chop's only show: keep it.)
	float mirror_weight = fresnel * (1.0 - foamed) * (1.0 - clamp(glow, 0.0, 0.6) * mix(1.0, 0.3, surge_share));
	vec3 display_color = mix(zs_scene_to_display(lit), reflection, mirror_weight);
	display_color = mix(display_color, path.rgb, path.a * (1.0 - foamed));
	vec3 warm = zs_glint(mix(vec3(1.0, 0.62, 0.35), vec3(1.0, 0.98, 0.9), smoothstep(0.02, 0.5, sun.y)));
	display_color = mix(display_color, warm, clamp(spark, 0.0, 1.0));
	display_color = zs_rain_beaten(display_color, reflection * 0.5 + vec3(0.45), rest_xz, rain_on, footprint, t); // weather lane rain
	if (debug_view == 1) display_color = water_depth < 5.0 ? vec3(1.0, 0.0, 0.0) : (water_depth < 20.0 ? vec3(0.0, 1.0, 0.0) : (water_depth < 60.0 ? vec3(0.0, 0.0, 1.0) : vec3(1.0))) * (0.5 + 0.5 * known);
	if (debug_view == 3) display_color = zs_scene_to_display(lit);
	if (debug_view == 4) display_color = reflection * mirror_weight;
	if (debug_view == 5) display_color = vec3(glow, lift * 0.5, (1.0 - jac) * 2.0);
	if (debug_view == 2) display_color = vec3(cover, foamed, waked);
	if (debug_view == 6) display_color = vec3(lace_density, lace_youth, in_buffer * 0.5 + churned * 0.5);
	if (debug_view == 8) display_color = vec3(fract(water_depth / 2.0), clamp(water_depth / 30.0, 0.0, 1.0), known);
	if (debug_view == 9) display_color = vec3(still, known < 0.999 ? 1.0 : 0.0, on_mouth);
	if (debug_view == 10) display_color = vec3(fract(bed_depth * 4.0), clamp(bed_depth / 3.0, 0.0, 1.0), still);
	if (debug_view == 11) {
		vec2 tex_c = (rest_xz - depth_at.xy) / depth_at.z * vec2(textureSize(depth_map, 0));
		vec2 gl = abs(fract(tex_c) - 0.5) / fwidth(tex_c);
		display_color = mix(display_color, vec3(1.0, 0.0, 0.0), 1.0 - clamp(min(gl.x, gl.y), 0.0, 1.0));
	}
	ALBEDO = scene_linear_for_display(clamp(display_color, vec3(0.0), vec3(1.0)));
	// The rainbow in the rain before the far sea (shaders/weather_bow.gdshaderinc).
	ALBEDO += zs_bow_far(-eye, distance_to, clamp(display_color, vec3(0.0), vec3(1.0)));
	ALPHA = depth > 0.0 ? max(smoothstep(0.0, mix(0.05, river_calm_fade, still), bed_depth), swim_hit) : 1.0;
	if (debug_view == 17) { ALBEDO = bed; ALPHA = 1.0; }
	if (debug_view == 20) { ALBEDO = vec3(dbg_hid, known, clamp(water_depth / 30.0, 0.0, 1.0)); ALPHA = 1.0; }
	if (debug_view == 19) { float wv = (waver - 0.8) / 0.45; ALBEDO = vec3(wv, fract(wv * 8.0), fract(rest_xz.x / 8.0)); ALPHA = 1.0; }
	if (debug_view >= 12 && debug_view < 16) {
		if (debug_view == 12) ALBEDO = vec3(ALPHA, fract(water_depth / 0.5), seen.g);
		if (debug_view == 13) ALBEDO = vec3(fract(dbg_mouth.x / 0.25), fract(mapped / 0.25), dbg_mouth.y);
		if (debug_view == 14) ALBEDO = vec3(fract((world_position.y - sea_level) * 10.0), clamp((world_position.y - sea_level) * 2.0 + 0.5, 0.0, 1.0), fract(waver * 10.0));
		if (debug_view == 15) ALBEDO = vec3(fract(through / 1.0), fract(bed_depth / 0.25), eye.y);
		ALPHA = 1.0;
	}
}
