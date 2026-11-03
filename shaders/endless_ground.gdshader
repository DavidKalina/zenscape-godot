shader_type spatial;
// The endless land's ground (scripts/endless/endless_look.gd): a soft grass
// carpet with the wind's sheen rolling over it, rock on the slopes, sand on
// the beaches and the seabed, snow on the peaks, painted per pixel from
// the land's own height (world y over `sea_y`), slope (the normal) and
// meadow (the vertex colour's alpha, scripts/endless/land_field.gd), with
// the vertex colour's hue drifting through it.
//
// It reads at every distance with no pop: every pattern is world-space
// noise, and each scale fades to its own mean where it is finer than the
// pixel (`zs_fade`), so far ground is the near ground's average, never a
// different paint, and no chunk's level shows.
//
// The grass is the isles' calm field (shaders/ground_look.gdshaderinc, its
// greens and dry patches) and grass look (shaders/grass_look.gdshaderinc,
// the wind's crest), drawn over kilometres: patches from metres to hundreds
// of metres, a velvet sheen at grazing angles, the crests of the wind's
// waves rolling over it bright. Lit as the isles' surfaces are: the sun by
// Godot, the hemisphere fill (zs_hemi_*) as emission.
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/grass_look.gdshaderinc"
#include "res://shaders/cloud_volume_shadow.gdshaderinc"
#include "res://shaders/land_horizon.gdshaderinc"
#include "res://shaders/endless_patch.gdshaderinc"
#include "res://shaders/endless_rock.gdshaderinc"
// The grass's ring distance (scripts/endless/endless_grass.gd), for where
// its tufts and flowers give way to paint.
#include "res://shaders/endless_ring.gdshaderinc"
// The underside the wind flips into view, as the tufts show it.
#include "res://shaders/grass_silver.gdshaderinc"
#include "res://shaders/grass_sheen.gdshaderinc"
#include "res://shaders/far_lawn.gdshaderinc"
#include "res://shaders/smooth_wave_field.gdshaderinc"

// zs_silver_drive for the painted ground from high up: the same three trains,
// share, gust band and front, but with the sheen's lattice-free crest and band
// (zs_sheen_crest, zs_sheen_band). The tufts' zs_wave_crest_at bends its crests by
// lattice noise up to 3.6 rad and zs_gust_band_at thresholds lattice noise, and
// painted over the meadow from above their cell edges showed as small blocks
// (the sheen's seams, docs/design/endless-flight/sheen-seam-handoff.md).
// (zs_wave_crest_at's shape, two trains 24 degrees apart under one smoothstep,
// with its lattice-noise wander swapped for three plane waves as the sheen's.)
float zs_wave_crest_smooth(vec2 root, float crest_length, float crest_speed, vec2 offset, float travel) {
	vec2 dir = zs_wind_direction;
	float along = dot(root, dir);
	float side = dot(root, vec2(-dir.y, dir.x));
	vec2 q = vec2(side, along) * (TAU / crest_length);
	float wander = 1.2 * sin(dot(q, vec2(0.80, 0.60)) * 0.31 + offset.x * 5.1)
		+ 0.9 * sin(dot(q, vec2(-0.55, 0.84)) * 0.45 + offset.y * 3.7 + 1.3)
		+ 0.6 * sin(dot(q, vec2(0.30, -0.95)) * 0.22 + (offset.x + offset.y) * 2.3 + 4.0);
	wander += 1.8;
	float a = 0.5 + 0.5 * sin((along - travel * crest_speed) * TAU / crest_length + wander);
	vec2 skew = vec2(dir.x * 0.9135 - dir.y * 0.4067, dir.x * 0.4067 + dir.y * 0.9135);
	float b = 0.5 + 0.5 * sin((dot(root, skew) - travel * crest_speed * 0.92) * TAU / (crest_length * 1.7) + wander * 0.6 + 1.3);
	return smoothstep(0.25, 0.95, a * 0.68 + b * 0.32);
}

float zs_silver_drive_smooth(vec2 p, float fp) {
	float travel = zs_gust_distance;
	vec3 crest = vec3(
		zs_wave_crest_smooth(p, grass_silver_waves.x, ZS_BREEZE_WAVE_SPEED, zs_grass_offset, travel),
		zs_wave_crest_smooth(p, grass_silver_waves.y, ZS_BREEZE_WAVE_SPEED, zs_grass_offset, travel),
		zs_wave_crest_smooth(p * 0.97 + 50.0, grass_silver_waves.z, ZS_BREEZE_WAVE_SPEED * 1.3, zs_grass_offset + 7.0, travel));
	vec3 keep = vec3(1.0) - smoothstep(grass_silver_waves * 0.08, grass_silver_waves * 0.3, vec3(fp));
	crest = mix(vec3(0.4), crest, keep);
	float w = dot(crest, grass_silver_share) * zs_sheen_band(p, travel) * zs_breeze_air() / 0.53;
	w += zs_front_at(p, 0.0) * 1.5;
	return smoothstep(grass_silver.y, grass_silver.z, w);
}
#include "res://shaders/grass_react.gdshaderinc"
// A world of regions: its paint per spot.
#include "res://shaders/region_paint.gdshaderinc"
// The rivers' water (scripts/endless/land_field.gd `_river`): drawn as the
// sea is (its sky, display and glint helpers).
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_tonemap.gdshaderinc"
#include "res://shaders/reference_lake_glint.gdshaderinc"
// The light's leans: the paint's warm and cool tones turn with the light.
#include "res://shaders/light_leans.gdshaderinc"
global uniform vec3 zs_palette_water;

// Rock round: the painted rock (shaders/endless_rock.gdshaderinc); true is
// the earlier smooth banded rock.
uniform bool old_rock = false;
// The grass's paint skipped where none of it shows (all sand, bank or snow):
// 1 on, 0 painted everywhere as before (--land-skip=0), 2 the skipped pixels
// magenta (--land-skip=show).
uniform int grass_skip = 1;
// How far the grass's painted warm and cool tones (the drift, the slopes to
// and from the sun, the sheen, the paper light) follow the light's leans
// (shaders/light_leans.gdshaderinc; 0 fixed as before).
uniform float paint_follow : hint_range(0.0, 2.0) = 0.5;
uniform float sea_y = -40.0;
#include "res://shaders/endless_height_haze.gdshaderinc"
// The Peak's tarn: its water, ice and shore (scripts/endless/peak_tarn.gd).
#include "res://shaders/peak_tarn.gdshaderinc"
uniform float beach = 2.2;
uniform float snow_line = 95.0;
// The normal's up below which the grass gives way to rock (with a ragged
// edge), and where the turf starts to thin to dry olive.
uniform float rock_up = 0.80;
uniform float thin_up = 0.93;
// How much the patches swing, the velvet sheen at grazing angles and the
// wind's crests.
uniform float patch_strength : hint_range(0.0, 2.0) = 1.0;
uniform float velvet : hint_range(0.0, 1.0) = 0.45;
uniform float wind_sheen : hint_range(0.0, 2.0) = 1.0;
// The wind's two wave trains (m between crests).
uniform vec2 wave_lengths = vec2(22.0, 60.0);
// How much of the sun a cloud's shadow takes off the ground (scripts/
// endless/endless_clouds.gd; the sky's fill stays).
uniform float cloud_shade : hint_range(0.0, 1.0) = 0.85;
// How far the vertex colour's own hue shows through the field (0 none).
uniform float vertex_hue : hint_range(0.0, 1.0) = 0.2;
// The grass carpet's tufts (scripts/endless/endless_grass.gd) over the
// near turf: they thin out between `carpet_reach.x` and `.y` m from the eye
// (y 0: no carpet). Past it, and wherever no tuft grows, the grass takes
// the carpet's own tone as it reads from afar (`carpet_tone_top` seen from
// above, `_low` at a glance), so the tufts give way to paint with no ring.
// Where tufts grow: the turf over `turf_beach` m over the sea (none to
// full), its normal's up past `turf_slope`, thinning out over `turf_high`
// (or `turf_alpine`).
uniform vec2 carpet_reach = vec2(0.0);
// Under the near carpet (where its full tufts stand, thinning out from
// `carpet_near.x` to `.y` m from the eye; y 0: off) the turf is the tufts'
// own ground: the patches from 8 m up only (scripts/endless/endless_patch.gd
// `grass`, which the tufts' roots carry), with none of the paint's finer
// grain, dry flecks, sheen or velvet, so tuft and turf read as one surface.
uniform vec2 carpet_near = vec2(0.0);
// How much of the turf's own fine grain (the tuft-sized light and dark the
// paint draws near the eye) stays under the near carpet, between its tufts.
uniform float carpet_near_grain : hint_range(0.0, 1.0) = 0.6;
// A world's tone over the land's rock (its walls, ledges and crags; 1: none).
uniform vec3 rock_tint = vec3(1.0);
// A world's hue over the rock, taken at the rock's own light: its direction
// the hue, its luma how much of the rock's own hue gives way (0: none).
uniform vec3 rock_hue = vec3(0.0);
// The Peak's massif (scripts/endless/peak_massif.gd `paint()`; w 0: none):
// its frame (plateau centre xz, facing xz), its zone (the bounding circle's
// middle xz, radius, on), its snow line over the sea, and its approach
// valley along the axis: a where the icefall, the boulders, the glacier
// and the toe start (x..w), the floor's half-width (FLOOR_HALF) and the
// valley's bend (GL_BEND, GL_TURNS, from a, to a). Inside the zone the
// snow line rises to `peak_snow`, the rock turns granite grey above the
// land's own tops, the valley's floor is ice on the icefall and the
// glacier and scree on the boulder field.
uniform vec4 peak_frame = vec4(0.0);
uniform vec4 peak_zone = vec4(0.0);
uniform float peak_snow = 500.0;
// The rock gorge's floor (scripts/endless/peak_ice.gd `rock_uniforms`): x, z,
// half-width of each point, bare of snow and ice, and the line's box.
uniform int peak_rock_count = 0;
uniform vec3 peak_rock_line[24];
uniform vec4 peak_rock_box = vec4(0.0);
// The Peak's granite's darkest (the towers' copy of the paint takes its own).
uniform float peak_granite = 0.07;
// The upper mountain is the towers' own rock (scripts/endless/rocks/peak_towers.gd
// PAINT): from `PEAK_BASALT.x` m over the sea, ragged, whole by `.y`, the massif
// takes the towers' tint, granite and height haze. 0: off (--spire-rock=0; the
// towers' own copy, which has those numbers already).
uniform float peak_basalt = 0.0;
const vec2 PEAK_BASALT = vec2(60.0, 680.0);
const vec3 PEAK_BASALT_TINT = vec3(0.2, 0.2, 0.24);
const float PEAK_BASALT_GRANITE = 0.012;
// The towers' height haze, cut this far (.z) over a long climb (.x to .y m over
// the sea): over the land's short span it stood as a band round the massif.
const vec3 PEAK_BASALT_HAZE = vec3(120.0, 760.0, 0.86);
const float PEAK_BEDS = 3.0;
const float PEAK_SHEAR = 200.0;
const float PEAK_FLOOR_STONES = 0.7;
const float PEAK_FLOOR_PALE = 1.5;
const float PEAK_BOW_DARK = 0.3;
const vec3 PEAK_GULLY = vec3(0.34, 0.35, 0.43);
const float PEAK_RIB = 0.4;
const float PEAK_CAST_FILL = 2.2;
uniform vec4 peak_stretch = vec4(850.0, 1250.0, 2050.0, 4050.0);
uniform vec4 peak_half = vec4(200.0, 240.0, 260.0, 330.0);
uniform vec4 peak_bend = vec4(170.0, 2.2, 1250.0, 4500.0);
// The cirque on the plateau (PeakMassif CIRQUE_R, its lobes' phases; the
// lobes' shares and the rim's half-width in `s`; the strip's a, the rim's
// gap round it (from, to) and w 0: no cirque): `peak_rim`.
uniform vec4 peak_cirque = vec4(165.0, 0.0, 0.0, 0.0);
uniform vec4 peak_cirque_lobes = vec4(0.07, 0.09, 0.04, 0.16);
uniform vec4 peak_cirque_strip = vec4(80.0, 32.0, 62.0, 0.0);
uniform vec3 carpet_tone_top = vec3(1.0);
uniform vec3 carpet_tone_low = vec3(1.0);
// A world's tone over the turf's own colour wherever tufts stand (the carpet's tone takes over past them; 1: none).
uniform vec3 carpet_under_tone = vec3(1.0);
// A world's hue over the grass's paint (after its tones), at the paint's own
// light: its direction the hue, its luma how much of the paint's own hue
// gives way (0: none). Unlike a tone it can mute the paint, not only tint it.
uniform vec3 carpet_hue = vec3(0.0);
// Each region's carpet tones (region_paint.gdshaderinc), read where region_paint_on.
uniform vec3 carpet_tone_top_r[4];
uniform vec3 carpet_tone_low_r[4];
uniform vec3 carpet_under_tone_r[4];
uniform vec3 carpet_hue_r[4];
uniform vec2 turf_beach = vec2(2.55, 2.9);
uniform vec2 turf_slope = vec2(0.905, 0.95);
uniform vec2 turf_high = vec2(36.0, 58.0);
// (Set: thinning out as the paint turns to tundra, its `alpine` from x to y,
// in place of turf_high.)
uniform vec2 turf_alpine = vec2(0.0);
// The carpet's grain painted past its tufts (their speckle and gaps, at
// their size, kept until a pixel is about that size), its strength.
uniform float carpet_grain : hint_range(0.0, 2.0) = 0.6;
uniform vec2 carpet_grain_sizes = vec2(0.75, 1.5);
// From high up (the eye's height over the ground, m, from x to y) the turf is
// painted, not speckled: the carpet's grain gone, broad colour patches,
// soft streaks along the wind and darker hollows in the creases, by this much.
uniform float high_paint : hint_range(0.0, 2.0) = 1.0;
uniform vec2 high_paint_alt = vec2(20.0, 75.0);
// 1 (--high-paint=old, scripts/endless/grass_sheen.gd): the streaks and washes
// of lattice noise as they were, for A/B against the smooth plane-wave ones.
uniform float high_paint_old = 0.0;
// Watercolour meadow (docs/design/endless-flight/watercolour-meadow-handoff.md):
// from the same height up, the turf is a few big washes of colour that bleed
// into one another (domain-warped), darker pigment pooled on their edges and
// in hollows, pale paper-light on the crowns, the small patches, sheen and
// flower dots melted into them. `wc_paint` its strength (0: off), `wc_scale`
// the washes' size (m), `wc_edge` the wet edges', `wc_paper` the paper light.
uniform float wc_paint : hint_range(0.0, 2.0) = 1.0;
uniform float wc_scale = 170.0;
uniform float wc_edge : hint_range(0.0, 1.0) = 0.5;
uniform float wc_paper : hint_range(0.0, 1.0) = 0.5;
// The share of the velvet sheen the carpet's turf gives up.
uniform float carpet_velvet_cut : hint_range(0.0, 1.0) = 0.6;
// The night's grade (scripts/shared/celestial.gd `night_grade`, which the isles'
// look pass lays on the screen): x how far the colour gives way to a cool
// rod-lit grey, yzw that grey's hue.
uniform vec4 night_grade = vec4(0.0);
// Look round 5 (shaders/endless_patch.gdshaderinc, scripts/endless/
// endless_patch.gd): the grass's colour regions, how strongly (0: off), and
// the flower drifts, how many (0: none), their wash under the drawn
// flowers (x, out to `bloom_fade.x` m) and their painted heads' share past
// them (y, from `bloom_fade.y`), the land seed's offset both read at.
uniform float region_amount = 0.0;
uniform float bloom_amount = 0.0;
uniform vec2 bloom_wash = vec2(0.10, 0.9);
// The painted heads' sizes (m), on two lattices.
uniform vec2 bloom_dots = vec2(0.38, 0.62);
uniform vec2 bloom_fade = vec2(22.0, 55.0);
uniform vec2 region_offset = vec2(0.0);
// Rivers (docs/design/endless-flight/rivers-handoff.md): the land's river
// channel comes in CUSTOM1 (signed distance from its line, the water's
// half-width, negative on the skirt, and its level) and its flow in
// CUSTOM0.zw; the
// water is drawn here, flat at its level (the grid under it lifted), per
// pixel from the distance so it stays crisp on coarse chunks. `river_on` 0
// draws none (--no-rivers). The sea's chop maps and colours (EndlessLook).
uniform float river_on = 0.0;
uniform sampler2D river_detail_a : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D river_detail_b : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 river_tint_shallow : source_color = vec3(0.42, 0.90, 0.82);
uniform vec3 river_tint_mid : source_color = vec3(0.07, 0.52, 0.66);
uniform vec3 river_tint_deep : source_color = vec3(0.04, 0.27, 0.55);
// The depth faked from the way in from the bank: m of depth per m, the most.
uniform vec2 river_depth = vec2(0.8, 5.0);
// The colour's depths (m): shallow to mid, mid to deep; the light it holds
// (the sea's water_light), what it absorbs a metre and the bed's fade (m).
uniform vec2 river_tint_depths = vec2(2.5, 7.0);
uniform float river_light = 2.6;
uniform vec3 river_absorb = vec3(0.30, 0.075, 0.06);
uniform float river_bed_fade = 2.2;
// The ripples: tile sizes (m), strengths, how much the flow stretches them
// along itself, how long a copy lives (s) before it fades for a fresh one.
uniform vec3 river_ripple_size = vec3(9.0, 3.2, 1.1);
uniform vec3 river_ripple_strength = vec3(0.16, 0.14, 0.09);
uniform float river_streak = 2.2;
uniform float river_cycle = 2.4;
// The mirror: fresnel floor and power, how much of the ripple it sees.
uniform vec2 river_fresnel = vec2(0.08, 3.5);
uniform float river_calm = 0.85;
// The bank: sand and pebbles out to `river_bank` m past the water, wet
// darker over `.y` m. `river_edge` is retired: the bank foam
// (`river_bank_foam`) draws the water's edge now.
uniform vec2 river_bank = vec2(3.5, 1.4);
uniform float river_edge = 0.55;
// The water's level over the sea under which the sea takes it (the mouth,
// with --river-mouth=0; else the drawn water sinks under the sea instead).
uniform float river_mouth = 0.35;
// The mouth (river-mouths-handoff.md; EndlessLook sets these from LandField
// RIVER_MOUTH_*, and `river_mouth_blend` 0 with --river-mouth=0): over the
// last `river_mouth_rise` m of its fall the water takes the sea's colour for
// the channel's real depth (`river_mouth_deep`: the bed's depth at the
// middle, and how much more at the sea), so it runs into the sea, which
// lies still up the channel, with no seam; the banks' stones give way to
// sand. The sea's tint depths, bed fade and calm body light (EndlessLook).
// The drawn water doesn't stop on a step: over the last `river_mouth_sink.y`
// m of its level it sinks `.x` m, under the sea's still water, which fades
// in over it (endless_sea.gdshader `river_calm`), and the paint gives way to
// the bed as it goes under.
uniform float river_mouth_blend = 1.0;
uniform vec2 river_mouth_sink = vec2(4.2, 1.5);
// How much of the sea's look the water takes at the sea (the rest stays the
// river's own, carried out into the sea's still water).
uniform float river_mouth_tint = 0.8;
uniform float river_mouth_rise = 5.0;
uniform vec2 river_mouth_deep = vec2(0.6, 3.6);
uniform vec4 river_sea_tint_depths = vec4(1.5, 7.0, 22.0, 55.0);
uniform float river_sea_bed_fade = 5.0;
uniform float river_sea_body = 0.9;
// The banks in the mirror: from reflected rays this high (.x) to this
// low (.y), this much of them.
uniform vec3 river_shore_mirror = vec3(0.28, 0.04, 0.7);
// The current's pale streaks down the flow (0 none).
uniform float river_streaks = 1.0;
// Still water (a pond, land_ponds.gd; a river's still pool): lily pads in
// clusters through its shallow ring. x: how many (0 none), y: cell (m),
// z: pad radius share of the cell.
uniform vec3 river_pads = vec3(1.0, 1.15, 0.22);
uniform vec3 river_pad_colour : source_color = vec3(0.42, 0.56, 0.24);
// How much of the cloud field the water mirrors (the sea's cloud_mirror).
uniform float river_cloud_mirror = 0.8;
// The flow's look (rivers-flow-handoff.md). White water: from the current's
// speed .x (m/s) it breaks, by .y it is all white water, .z how much.
uniform vec3 river_rapids = vec3(1.0, 2.2, 1.0);
// Riffles: patches of broken water this big (m) down any running stretch,
// and how white they get on a slower one (0..1).
uniform vec2 river_riffle = vec2(48.0, 0.45);
// The drawn motion runs this many times the current (so it reads from the
// air), and never slower than .y m/s.
uniform vec2 river_flow_look = vec2(1.8, 0.45);
// The foam's grain: its streaks' width (m; drawn out ~4x down the flow), its
// fine break-up (m), how long a copy rides (s) before a fresh one.
uniform vec3 river_foam_size = vec3(1.0, 0.4, 2.0);
// Foam along both banks: its reach in (m) on calm water and on white water,
// and how much.
uniform vec3 river_bank_foam = vec3(0.6, 2.8, 1.0);
// A foam front where the river meets the sea (0 none).
uniform float river_mouth_foam = 1.0;
// White water churns: its ripples this much rougher at full white.
uniform float river_churn = 1.6;
// Slicks down running water: their width (m), how much they shade the body
// and the mirror.
uniform vec3 river_slick = vec3(4.5, 0.22, 0.7);
// The ripples' faces lit toward the sun (the sea's body_shade).
uniform float river_body_shade = 1.0;
// --- Rivers as moving water (`river_live` 1, unless --river-live=0; docs/design/
// endless-flight/river-live-handoff.md). The chunks then carry the channel's
// frame in CUSTOM2 (scripts/endless/land_stream.gd `_river_frame`): its
// direction down the flow, its curvature (positive: the side of positive
// distance is the bend's outside) and its width change per metre. At 0 none
// of this is read and the water is drawn as above.
uniform float river_live = 0.0;
// A noise height map (0..1, about 16 features a tile) and its normals
// (EndlessLook `_river_live`): riffles, foam, eddies' swirl and the bed.
uniform sampler2D river_live_height : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D river_live_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// The sea's FFT cascades (scripts/endless/sea_fft.gd; 1 unless --sea-fft=0, with
// a rendering device): cascades 1 and 2's slopes for the ripples, their
// tiles shrunk to `river_fft_use.x` and `.y` of the sea's, at strengths `.z`
// and `.w`. Without them the sea's noise maps (river_detail_a/b).
uniform int river_fft = 0;
uniform sampler2DArray river_fft_maps : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 river_fft_sizes = vec3(250.0, 37.0, 5.7);
uniform vec4 river_fft_use = vec4(0.25, 0.7, 0.30, 0.22);
// The shear: the current's share of the river's speed at the bank (x) and in
// the middle (y), the profile's power (z: 1 parabolic, less a flatter core),
// and how much faster the bend's outside runs (w, per curvature x distance).
uniform vec4 river_shear = vec4(0.12, 1.3, 0.6, 3.0);
// The flow map: how long a copy lives (s, scaled by the root of its size
// over 3 m) and the size of the noise that staggers the copies (m), so no
// stretch pulses over the whole river at once.
uniform vec2 river_live_cycle = vec2(0.65, 22.0);
// Riffles, standing waves held in place with the current running through
// them: the river's speed where they start and are full (m/s), their slope
// strength (z) and the white water on their crests (w).
uniform vec4 river_live_riffle = vec4(1.1, 2.6, 0.45, 1.0);
// Where else they stand: at a narrowing (x), round a bend (y), on gravel
// bars of this size (z, m; between bars they are a share of it), and a
// little everywhere the river runs (w).
uniform vec4 river_riffle_where = vec4(0.7, 0.5, 40.0, 0.3);
// Eddies by the banks (inside a bend, where the river widens, in patches):
// strength, how far the current turns back there (1 still, 2 back at full),
// the swirl's size (m) and strength.
uniform vec4 river_eddy = vec4(1.0, 1.4, 5.0, 0.3);
// Foam: flecks (x), their size (y, m), how much gathers at the banks, the
// bend's outside and in eddies (z), and the lines drawn out down the flow (w).
uniform vec4 river_foam = vec4(0.7, 0.35, 1.0, 1.0);
// The bed seen through the water: its pattern (x), how far the ripples bend
// it (y, m of shift per unit slope per m of depth), the sun's caustics on it
// (z) and their size (w, m).
uniform vec4 river_bed = vec4(1.0, 0.5, 1.0, 1.8);
// (Tuning: 1 the bend's outside (red) and inside (green), 2 the eddies, 3
// the riffles, 4 the current's speed, 5 the foam; 0 off.)
uniform int river_live_debug = 0;

// The field's greens (linear): the calm field's (ground_look), a meadow's
// lusher, brighter turf, the tundra over the high ground.
const vec3 GREEN = vec3(0.1296, 0.3563, 0.1597);
const vec3 SUNLIT = vec3(0.2012, 0.4365, 0.1964);
const vec3 DEEP = vec3(0.1004, 0.2565, 0.1318);
const vec3 DRY = vec3(0.2350, 0.3800, 0.1250);
const vec3 MEADOW = vec3(0.2050, 0.4500, 0.1300);
const vec3 TUNDRA = vec3(0.2050, 0.2300, 0.1300);
const vec3 OLIVE = vec3(0.2300, 0.2600, 0.1200);
const vec3 ROCK = vec3(0.180, 0.165, 0.150);
const vec3 ROCK_PALE = vec3(0.330, 0.310, 0.285);
const vec3 SAND = vec3(0.600, 0.500, 0.330);
const vec3 SAND_WET = vec3(0.310, 0.265, 0.190);
const vec3 SEABED = vec3(0.180, 0.200, 0.150);
const vec3 SNOW = vec3(0.860, 0.890, 0.950);

varying vec3 world_position;
varying vec3 world_normal;
varying vec4 land_colour;
// The land's carve (land_field.gd, via land_stream's CUSTOM0): x how deep
// in a groove or a ledge's inner corner, y a buttress crest or ledge lip.
varying vec2 land_carve;
// Dry land under the sea's level (a sunk cave's sinkhole: tunnel_sites.gd
// apply_chunk marks it with a river level of its own, DRY_LOW_RIVER, far under
// the sea - 100 of every riverless vertex): painted as land, not sea bed.
varying float dry_low;
const float DRY_LOW_OVER = 26.0;
// The river (land_stream's CUSTOM1) and its flow (CUSTOM0.zw, m/s).
varying vec3 river;
varying vec2 river_flow;
// The channel's frame (CUSTOM2, river_live only).
varying vec4 river_frame;
// The land's shape (land_stream _shape, CUSTOM3): how proud (over 0.5) or
// sunk each vertex stands at 4, 14 and 40 m; a 1 where it was made.
varying vec4 land_shape;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// The vertex colour is sRGB; its alpha the meadow.
	land_colour = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a);
	land_carve = CUSTOM0.xy;
	dry_low = 1.0 - smoothstep(sea_y - 300.0, sea_y - 200.0, CUSTOM1.z);
	river = CUSTOM1.xyz;
	river_flow = (CUSTOM0.zw * 2.0 - 1.0) * 4.0;
	river_frame = river_live > 0.5 ? CUSTOM2 : vec4(0.0);
	land_shape = CUSTOM3;
	// The river's water drawn flat at its level: the grid's bed under it
	// lifted (the land's own heights, its colliders, keep the bed).
	float r_over = CUSTOM1.z - sea_y;
	if (river_on > 0.5 && CUSTOM1.y > 0.05 && abs(CUSTOM1.x) < CUSTOM1.y + 1.0 && (r_over > river_mouth || river_mouth_blend > 0.0)) {
		// At a mouth the drawn water sinks under the sea's.
		float drawn = CUSTOM1.z - river_mouth_sink.x * river_mouth_blend * (1.0 - smoothstep(0.0, river_mouth_sink.y, r_over));
		float lift = drawn - world_position.y;
		if (lift > 0.0 && lift < 3.0 + river_mouth_deep.y * river_mouth_blend) {
			VERTEX.y += lift;
			world_position.y += lift;
		}
	}
}

// One ripple layer drifting along the flow: two copies, each living
// `river_cycle` s (scaled by sqrt size) and drifting `speed` m/s along
// `dir`, then jumping to a fresh spot, cross-faded half a cycle apart, so it
// never stretches (endless_sea's zs_flow_layer). Its tiles are drawn out
// along the flow by `river_streak`.
vec2 zs_river_layer(sampler2D tex, vec2 p, vec2 dir, float speed, float size, float offset, float t) {
	float cycle = max(river_cycle * sqrt(size / 3.0), 0.2);
	float c0 = t / cycle + offset;
	float c1 = c0 + 0.5;
	float f0 = fract(c0), f1 = fract(c1);
	vec2 j0 = fract(vec2(0.3183, 0.6180) * floor(c0) + offset);
	vec2 j1 = fract(vec2(0.7071, 0.2360) * floor(c1) + offset * 1.7);
	vec2 across = vec2(-dir.y, dir.x);
	vec2 q0 = p - dir * speed * cycle * f0;
	vec2 q1 = p - dir * speed * cycle * f1;
	vec2 l0 = vec2(dot(q0, dir) / river_streak, dot(q0, across));
	vec2 l1 = vec2(dot(q1, dir) / river_streak, dot(q1, across));
	vec2 s0 = texture(tex, l0 / size + j0).xy * 2.0 - 1.0;
	vec2 s1 = texture(tex, l1 / size + j1).xy * 2.0 - 1.0;
	float w0 = 1.0 - abs(2.0 * f0 - 1.0);
	float w1 = 1.0 - w0;
	vec2 s = (s0 * w0 + s1 * w1) * inversesqrt(w0 * w0 + w1 * w1);
	// Back from the flow's frame to the world's (the streak's squeeze too).
	return dir * s.x / river_streak + across * s.y;
}

// --- The live river (river_live 1) ----------------------------------------
// A flow map: the map `tex` (tiles `size` m) carried by the local current
// `vel` (m/s, varying from pixel to pixel, so the pattern shears and curls),
// two copies each living a cycle and cross-faded half a cycle apart; `phase`
// staggers the copies over the river. Its slopes (a normal map's xy).
vec2 zs_live_flow(sampler2D tex, vec2 p, vec2 vel, float size, float phase, float t, vec2 dx, vec2 dy) {
	float cycle = max(river_live_cycle.x * pow(size / 3.0, 0.3), 0.25);
	float c0 = t / cycle + phase;
	float c1 = c0 + 0.5;
	float f0 = fract(c0), f1 = fract(c1);
	vec2 j0 = fract(vec2(0.3183, 0.6180) * floor(c0));
	vec2 j1 = fract(vec2(0.7071, 0.2360) * floor(c1));
	vec2 q0 = p - vel * cycle * (f0 - 0.5);
	vec2 q1 = p - vel * cycle * (f1 - 0.5);
	vec2 s0 = textureGrad(tex, q0 / size + j0, dx / size, dy / size).xy * 2.0 - 1.0;
	vec2 s1 = textureGrad(tex, q1 / size + j1, dx / size, dy / size).xy * 2.0 - 1.0;
	float w0 = 1.0 - abs(2.0 * f0 - 1.0);
	float w1 = 1.0 - w0;
	return (s0 * w0 + s1 * w1) * inversesqrt(w0 * w0 + w1 * w1);
}

// The same through an FFT cascade's slopes (layer 3 + c), its tile shrunk
// to `share` of the sea's (the slopes steepen as it shrinks).
vec2 zs_live_fft(int c, vec2 p, vec2 vel, float share, float phase, float t, vec2 dx, vec2 dy) {
	float size = river_fft_sizes[c] * share;
	float cycle = max(river_live_cycle.x * pow(size / 3.0, 0.3), 0.25);
	float c0 = t / cycle + phase;
	float c1 = c0 + 0.5;
	float f0 = fract(c0), f1 = fract(c1);
	vec2 j0 = fract(vec2(0.3183, 0.6180) * floor(c0));
	vec2 j1 = fract(vec2(0.7071, 0.2360) * floor(c1));
	vec2 q0 = p - vel * cycle * (f0 - 0.5);
	vec2 q1 = p - vel * cycle * (f1 - 0.5);
	float layer = float(c + 3);
	vec2 s0 = textureGrad(river_fft_maps, vec3(q0 / size + j0, layer), dx / size, dy / size).xy;
	vec2 s1 = textureGrad(river_fft_maps, vec3(q1 / size + j1, layer), dx / size, dy / size).xy;
	float w0 = 1.0 - abs(2.0 * f0 - 1.0);
	float w1 = 1.0 - w0;
	return (s0 * w0 + s1 * w1) * inversesqrt(w0 * w0 + w1 * w1) / share;
}

// The height map (features `size` m) carried by the current as above, each
// copy cut to flecks above `cut`: foam drifting with the water, fading in
// and out with its copies.
float zs_live_flecks(vec2 p, vec2 vel, float size, float cut, float phase, float t, vec2 dx, vec2 dy) {
	float cycle = max(river_live_cycle.x * 1.6, 0.25);
	float c0 = t / cycle + phase;
	float c1 = c0 + 0.5;
	float f0 = fract(c0), f1 = fract(c1);
	vec2 j0 = fract(vec2(0.4142, 0.7320) * floor(c0));
	vec2 j1 = fract(vec2(0.1618, 0.5772) * floor(c1));
	float sc = 1.0 / (size * 16.0);
	vec2 q0 = p - vel * cycle * (f0 - 0.5);
	vec2 q1 = p - vel * cycle * (f1 - 0.5);
	float aa = clamp(length(dx) * sc * 8.0, 0.0, 0.3);
	// Fine flecks gathered into rafts five times their size, with holes.
	float h0 = textureGrad(river_live_height, q0 * sc + j0, dx * sc, dy * sc).r;
	float h1 = textureGrad(river_live_height, q1 * sc + j1, dx * sc, dy * sc).r;
	float b0 = textureGrad(river_live_height, q0 * sc * 0.2 + j0.yx, dx * sc * 0.2, dy * sc * 0.2).r;
	float b1 = textureGrad(river_live_height, q1 * sc * 0.2 + j1.yx, dx * sc * 0.2, dy * sc * 0.2).r;
	float w0 = 1.0 - abs(2.0 * f0 - 1.0);
	// A lace: the height's mid line (a net of thin curling lines), thicker
	// where the rafts gather, and solid in the rafts' hearts.
	float l0 = 1.0 - abs(2.0 * h0 - 1.0) + (b0 - 0.5) * 0.6;
	float l1 = 1.0 - abs(2.0 * h1 - 1.0) + (b1 - 0.5) * 0.6;
	float m0 = smoothstep(cut, cut + 0.1 + aa, l0);
	float m1 = smoothstep(cut, cut + 0.1 + aa, l1);
	return m0 * w0 + m1 * (1.0 - w0);
}

// Standing waves held in place: trains of crests across the flow `t`,
// `lam` m apart, in patches drawn out across it, their crests wavering.
// Each of the four nearest cells turns its frame to the flow about its own
// middle and the four are blended, so the frame follows the river's bends
// (turning the world about a far origin would swing it); their trains share
// the wavelength, so the blend only swells and dims them. Returns the
// slope (a crest's steepest about 1); `crest` its height (0..1, 0.5 mean).
vec2 zs_live_riffle(vec2 p, vec2 t, float lam, vec2 dx, vec2 dy, out float crest) {
	const float C = 18.0;
	const float WIDE = 3.0;
	vec2 a = vec2(-t.y, t.x);
	vec2 g = p / C - 0.5;
	vec2 base = floor(g);
	vec2 f = fract(g);
	f = f * f * (3.0 - 2.0 * f);
	vec2 s = vec2(0.0);
	float h = 0.0;
	float ww = 0.0;
	// The patches: about two crests along, WIDE times that across.
	vec2 sc = vec2(1.0 / (lam * 2.0), 1.0 / (lam * 2.0 * WIDE)) / 16.0;
	vec2 gx = vec2(dot(dx, t), dot(dx, a)) * sc;
	vec2 gy = vec2(dot(dy, t), dot(dy, a)) * sc;
	for (int k = 0; k < 4; k++) {
		vec2 o = vec2(float(k & 1), float(k >> 1));
		vec2 cell = base + o;
		float w = mix(1.0 - f.x, f.x, o.x) * mix(1.0 - f.y, f.y, o.y);
		vec2 d = p - (cell + 0.5) * C;
		vec2 jit = fract(sin(vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
		vec2 l = vec2(dot(d, t), dot(d, a));
		vec2 uv = l * sc + jit;
		float env = smoothstep(0.35, 0.8, textureGrad(river_live_height, uv, gx, gy).r);
		float warp = textureGrad(river_live_height, uv * 2.3 + 0.37, gx * 2.3, gy * 2.3).r;
		float ph = 6.2832 * (l.x / lam + warp * 0.8);
		s += t * (-sin(ph) * env * w);
		h += cos(ph) * env * w * 0.5;
		ww += w * w;
	}
	float norm = inversesqrt(max(ww, 1e-4));
	crest = 0.5 + h * norm;
	return s * norm;
}

// The current's grain at a point, drawn out down the flow by averaging the
// noise along it (no frame turned about the world's origin, so it holds
// round bends and far out): x the streaky field (0..1, mean 0.5), y it
// broken up finer, for foam.
vec2 zs_river_grain(vec2 q, vec2 dir) {
	// (The noise's lattice turned off the world's axes, so its cells don't
	// line up into blocks.)
	const mat2 TURN = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float s = river_foam_size.x;
	vec2 qa = TURN * q / s;
	vec2 da = TURN * dir;
	float a = 0.0;
	for (int k = 0; k < 6; k++) a += ep_noise(qa + da * (float(k) - 2.5));
	a = clamp(0.5 + (a / 6.0 - 0.5) * 2.1, 0.0, 1.0);
	vec2 qf = TURN * (q / river_foam_size.y);
	float f = ep_noise(qf + vec2(17.3, 4.1)) * 0.6 + ep_noise(qf * 2.7 + vec2(3.9, 8.2)) * 0.4;
	return vec2(a, a * 0.7 + f * 0.3);
}

// White water and streak lines riding down the flow: two copies of the
// grain, each drifting `vspd` m/s for `river_foam_size.z` s then jumping to
// a fresh spot, cross-faded half a cycle apart (as the ripples), so foam
// forms, rides down and breaks up. `th` is the grain over which it is foam
// (lower: more). Returns (foam 0..1, streak lines 0..1, slicks 0..1).
vec3 zs_river_foam(vec2 p, vec2 dir, float vspd, float t, float th, float fp) {
	float cyc = river_foam_size.z;
	float c0 = t / cyc, c1 = c0 + 0.5;
	float f0 = fract(c0), f1 = fract(c1);
	vec2 q0 = p - dir * vspd * cyc * f0 + vec2(13.7, 5.3) * floor(c0);
	vec2 q1 = p - dir * vspd * cyc * f1 + vec2(7.1, 11.9) * floor(c1) + 40.0;
	vec2 g0 = zs_river_grain(q0, dir);
	vec2 g1 = zs_river_grain(q1, dir);
	float w0 = 1.0 - abs(2.0 * f0 - 1.0);
	float soft = 0.08 + fp / river_foam_size.x * 0.3;
	// Thin at its edges, thick in its cores.
	float a0 = smoothstep(th - soft, th + soft, g0.y) * mix(0.45, 1.0, smoothstep(th, th + 0.18, g0.y));
	float a1 = smoothstep(th - soft, th + soft, g1.y) * mix(0.45, 1.0, smoothstep(th, th + 0.18, g1.y));
	float foam = mix(a1, a0, w0);
	float lw = 0.04;
	float lines = mix(1.0 - smoothstep(0.0, lw, abs(g1.x - 0.66)), 1.0 - smoothstep(0.0, lw, abs(g0.x - 0.66)), w0);
	lines *= 1.0 - smoothstep(0.12, 0.5, fp);
	// Far off, its share of the water as a soft whitening, no grain.
	float far = smoothstep(river_foam_size.x * 0.5, river_foam_size.x * 2.5, fp);
	foam = mix(foam, smoothstep(0.78, 0.3, th) * 0.75, far);
	// Slicks: broad bands down the current (river_slick m across, ~6x that
	// long), drifting on a slower cycle, which read from the air where the
	// grain is gone.
	const mat2 TURN = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6));
	float scyc = cyc * 3.0;
	float e0 = t / scyc, e1 = e0 + 0.5;
	float h0 = fract(e0), h1 = fract(e1);
	vec2 da = TURN * dir;
	vec2 r0 = TURN * (p - dir * vspd * scyc * h0 + vec2(29.3, 3.1) * floor(e0)) / river_slick.x;
	vec2 r1 = TURN * (p - dir * vspd * scyc * h1 + vec2(5.9, 23.7) * floor(e1) + 90.0) / river_slick.x;
	float s0 = 0.0, s1 = 0.0;
	for (int k = 0; k < 4; k++) {
		s0 += ep_noise(r0 + da * (float(k) - 1.5) * 1.6);
		s1 += ep_noise(r1 + da * (float(k) - 1.5) * 1.6);
	}
	float v0 = 1.0 - abs(2.0 * h0 - 1.0);
	float slick = clamp(0.5 + (mix(s1, s0, v0) * 0.25 - 0.5) * 2.4, 0.0, 1.0);
	slick = mix(slick, 0.5, smoothstep(river_slick.x * 0.25, river_slick.x * 0.8, fp));
	return vec3(foam, lines * (1.0 - far), slick);
}

// Noise at `scale` m round its mean (-0.5..0.5), faded to the mean where a
// pixel's footprint `fp` (m) grows past a share of the scale.
float zs_fade(vec2 p, float scale, float fp) {
	float keep = 1.0 - smoothstep(scale * 0.18, scale * 0.6, fp);
	if (keep <= 0.0) return 0.0;
	return (zs_noise(p / scale) - 0.5) * keep;
}

// The same as a patch with a defined edge (-0.5 or 0.5 either side), the
// edge widening to a blur as the pixel grows, faded to its mean far off.
float zs_patch(vec2 p, float scale, float fp) {
	float keep = 1.0 - smoothstep(scale * 0.18, scale * 0.6, fp);
	if (keep <= 0.0) return 0.0;
	float w = 0.07 + fp / scale * 1.2;
	return (smoothstep(0.5 - w, 0.5 + w, zs_noise(p / scale)) - 0.5) * keep;
}

// A point turned and shifted for the carpet grain's two lattices, so no
// grid lines up with the world's axes.
vec2 turned_speck(vec2 p, int k) {
	return k == 0 ? mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * p + vec2(13.1, 7.7)
		: mat2(vec2(0.28, -0.96), vec2(0.96, 0.28)) * p + vec2(3.3, 51.9);
}

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// `c` toward `hue`'s direction at its own light, by `hue`'s luma
// (carpet_hue, rock_hue; 0: `c` as it is).
vec3 hued(vec3 c, vec3 hue) {
	float amount = clamp(luma(hue), 0.0, 1.0);
	if (amount <= 0.0001) return c;
	return mix(c, hue / amount * luma(c), amount);
}

// The Peak's paint at `p`: x the zone (1 inside the bounding circle, easing
// to 0 over its last 600 m), y the valley floor's ice, z its scree, w how
// far across the floor (0 the middle, 1 its edge). All 0 with no Peak.
vec4 peak_paint(vec3 p) {
	if (peak_zone.w < 0.5) return vec4(0.0);
	float zone = 1.0 - smoothstep(peak_zone.z - 600.0, peak_zone.z, distance(p.xz, peak_zone.xy));
	if (zone <= 0.0) return vec4(0.0);
	vec2 rel = p.xz - peak_frame.xy;
	vec2 f = peak_frame.zw;
	float a = dot(rel, f);
	float v = dot(rel, vec2(-f.y, f.x));
	// The valley's middle and the floor's half-width (PeakMassif._valley).
	float t = clamp((a - peak_bend.z) / (peak_bend.w - peak_bend.z), 0.0, 1.0);
	float mid = peak_bend.x * sin(PI * peak_bend.y * t) * smoothstep(0.0, 0.25, t);
	float half_w = peak_half.x;
	if (a > peak_stretch.y && a < peak_stretch.z) {
		half_w = mix(peak_half.x, peak_half.y, smoothstep(0.0, 0.3, (a - peak_stretch.y) / (peak_stretch.z - peak_stretch.y)));
	} else if (a >= peak_stretch.z) {
		half_w = mix(peak_half.z, peak_half.w, clamp((a - peak_stretch.z) / (peak_stretch.w - peak_stretch.z), 0.0, 1.0));
	}
	float across = abs(v - mid) / half_w;
	// The floor, with a ragged edge up the valley's sides.
	float rag = (zs_noise(p.xz / 37.0) - 0.5) * 0.16 + (zs_noise(p.xz / 9.0) - 0.5) * 0.06;
	float floor_on = 1.0 - smoothstep(0.92, 1.06, across + rag);
	// The icefall and the glacier hold ice, down to the toe; the boulder
	// field between them is scree.
	float icefall = smoothstep(peak_stretch.x - 60.0, peak_stretch.x + 20.0, a) * (1.0 - smoothstep(peak_stretch.y - 20.0, peak_stretch.y + 60.0, a));
	float glacier = smoothstep(peak_stretch.z - 80.0, peak_stretch.z + 160.0, a) * (1.0 - smoothstep(peak_stretch.w - 200.0, peak_stretch.w + 60.0, a));
	// The rock gorge's floor is bare: scree by its line, with the same rag.
	float scree = 0.0;
	if (peak_rock_count > 1 && p.x > peak_rock_box.x && p.z > peak_rock_box.y && p.x < peak_rock_box.z && p.z < peak_rock_box.w) {
		float best = 1e9;
		for (int i = 0; i < peak_rock_count - 1; i++) {
			vec2 s0 = peak_rock_line[i].xy;
			vec2 e = peak_rock_line[i + 1].xy - s0;
			float h = clamp(dot(p.xz - s0, e) / max(dot(e, e), 0.001), 0.0, 1.0);
			float d = distance(p.xz, s0 + e * h) / mix(peak_rock_line[i].z, peak_rock_line[i + 1].z, h);
			best = min(best, d);
		}
		scree = 1.0 - smoothstep(0.95, 1.2, best + rag * 2.0);
	}
	return vec4(zone, (icefall + glacier) * floor_on * zone, scree * zone, across);
}

// How much of the cirque's rim (PeakMassif._cirq) stands at `p`: 1 on the
// rim's line, 0 past its half-width inside and past its crest outside, none on the head's side or in the gap
// the strip runs out through.
float peak_rim(vec3 p) {
	if (peak_zone.w < 0.5 || peak_cirque_strip.w < 0.5) return 0.0;
	vec2 rel = p.xz - peak_frame.xy;
	vec2 f = peak_frame.zw;
	float a = dot(rel, f);
	float v = dot(rel, vec2(-f.y, f.x));
	float rho = length(vec2(a, v));
	if (rho > peak_cirque.x * 1.6) return 0.0;
	float phi = atan(v, a);
	float rr = peak_cirque.x * (1.0 + peak_cirque_lobes.x * sin(2.0 * phi + peak_cirque.y)
		+ peak_cirque_lobes.y * sin(3.0 * phi + peak_cirque.z) + peak_cirque_lobes.z * sin(5.0 * phi + peak_cirque.w));
	float s = rho / rr;
	float hd = smoothstep(0.25, 0.75, a / max(rho, 1.0));
	float lane = 1.0 - smoothstep(peak_cirque_strip.y, peak_cirque_strip.z, abs(a - peak_cirque_strip.x));
	// Inside, out to the rim's foot; outside, only its crest (the cirque
	// blends out to the falls from 1.08, which keep the massif's paint).
	float bump = s < 1.0 ? max(1.0 - (1.0 - s) / (peak_cirque_lobes.w * 1.3), 0.0) : 1.0 - smoothstep(1.02, 1.09, s);
	return smoothstep(0.0, 0.5, bump) * (1.0 - hd) * (1.0 - lane);
}

#include "res://shaders/peak_ice.gdshaderinc"
#include "res://shaders/peak_snow.gdshaderinc"

// zs_fade on a noise whose cells agree at their borders (peak_noise).
float peak_fade(vec2 p, float scale, float fp) {
	float keep = 1.0 - smoothstep(scale * 0.18, scale * 0.6, fp);
	if (keep <= 0.0) return 0.0;
	return (peak_noise(p / scale) - 0.5) * keep;
}

void fragment() {
	vec3 p = world_position;
	// The paint's tones: this spot's regions' in a world of regions, else the material's.
	vec3 rp_tone_top = carpet_tone_top;
	vec3 rp_tone_low = carpet_tone_low;
	vec3 rp_under_tone = carpet_under_tone;
	vec3 rp_hue = carpet_hue;
	vec3 rp_silver = grass_silver_colour;
	vec3 rp_swell = grass_swell;
	if (zs_region_paints()) {
		vec4 rw = zs_region_at(p.xz);
		rp_tone_top = zs_region_mix3(rw, carpet_tone_top_r);
		rp_tone_low = zs_region_mix3(rw, carpet_tone_low_r);
		rp_under_tone = zs_region_mix3(rw, carpet_under_tone_r);
		rp_hue = zs_region_mix3(rw, carpet_hue_r);
		rp_silver = zs_region_mix3(rw, grass_silver_colour_r);
		rp_swell = zs_region_mix3(rw, grass_swell_r);
	}
	// The wind by place (wind_field): windy grass rolls, calm grass stands.
	if (rp_swell.x > 0.0) rp_swell.x *= zs_wind_swell_at(p.xz);
	vec3 n = normalize(world_normal);
	if (!FRONT_FACING) n = -n;
	// A pixel's footprint on the ground (m): between its short and long
	// sides, so ground seen low keeps some detail along the view rather
	// than smearing (the long side alone), without shimmering (the short).
	float fp_x = length(dFdx(p.xz));
	float fp_y = length(dFdy(p.xz));
	float fp = mix(min(fp_x, fp_y), max(fp_x, fp_y), 0.4);
	// Steep ground: the paint's xz noise would stretch down a wall, so it
	// samples a point sheared by height (gxz), and a pixel's size is its 3D one.
	float fp3 = er_footprint(p);
	float shear = old_rock ? 0.0 : smoothstep(0.93, 0.55, n.y);
	// Sheared by the height over the sea, not the world's y: where the slope
	// turns (a bank's lip) the shear changes across a triangle, and the point
	// moves by that change times the height, so at y -37 the noise raced past
	// in zigzag stripes along the triangles. The sea is the low land's level.
	float sheared_y = p.y - sea_y;
	// On the Peak that level is hundreds of metres down: ground lying back, its
	// normal turning by a hair, moved the paint's noise metres at a time, in
	// swirling contours. There the shear folds to a height in PEAK_SHEAR's reach.
	if (peak_zone.w > 0.5) {
		float pk_near = 1.0 - smoothstep(peak_zone.z - 600.0, peak_zone.z, distance(p.xz, peak_zone.xy));
		sheared_y = mix(sheared_y, abs(fract(sheared_y / PEAK_SHEAR) - 0.5) * PEAK_SHEAR, pk_near);
	}
	vec2 gxz = p.xz + shear * vec2(sheared_y * 0.8, sheared_y * 0.55);
	fp = max(fp, fp3 * shear);
	float over = max(p.y - sea_y, DRY_LOW_OVER * dry_low);
	float meadow = clamp(land_colour.a, 0.0, 1.0);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - p);
	// (The live river's map gradients, taken here in uniform control flow.)
	vec2 dpx = dFdx(p.xz);
	vec2 dpy = dFdy(p.xz);

	// --- The river: its water and banks, per pixel from the distance to its
	// line (crisp on any chunk), with a slightly ragged edge near the eye.
	float r_s = abs(river.x);
	float r_w = abs(river.y);
	float r_here = river_on * step(0.05, r_w);
	float r_aa = clamp(fwidth(river.x), 0.02, 40.0) * 0.6;
	// The water's own footprint: it lies flat, so not the bed's steep-ground
	// one (which jumps between chunks with the bed's normals).
	float r_fp = mix(min(fp_x, fp_y), max(fp_x, fp_y), 0.4);
	float r_ragged = (zs_noise(p.xz / 3.3) - 0.5) * 0.9 * (1.0 - smoothstep(0.5, 2.0, fp));
	// How far outside the water's edge (m; negative in the water).
	float r_out = r_s - r_w + r_ragged;
	// (At a mouth the paint goes on under the sea's still water, giving way
	// to the bed as it sinks.)
	float r_level = mix(smoothstep(river_mouth, river_mouth + 0.3, river.z - sea_y), smoothstep(-1.6, -0.3, over), river_mouth_blend);
	float wet = r_here * r_level * (1.0 - smoothstep(-r_aa, r_aa, r_out));
	// How far into its mouth (0 upstream, 1 at the sea's level).
	float r_mouth = r_here * river_mouth_blend * (1.0 - smoothstep(0.0, river_mouth_rise, river.z - sea_y));
	// It takes on the sea's look over twice that, so the colour turns slowly.
	float r_tint = r_here * river_mouth_blend * (1.0 - smoothstep(0.0, river_mouth_rise * 2.0, river.z - sea_y));
	// The bank's width swings along the river: a wide bar of sand and stones
	// here, the turf down to the water there; mostly at closer scales than the
	// river is wide, so its two sides seldom match (no kerb down both).
	// (endless_patch's noise, which the grass mirrors (EndlessPatch.river_bank),
	// so the tufts stop where the stones start.)
	float bank_w = river_bank.x * mix(0.0, 1.8, smoothstep(0.42, 0.62, ep_noise(p.xz / 55.0 + 11.0) * 0.45 + ep_noise(p.xz / 19.0 + 5.0) * 0.55));
	float banked = r_here * (1.0 - smoothstep(bank_w * 0.55, bank_w + r_aa, r_out + (zs_noise(p.xz / 6.1 + 3.0) - 0.5) * 2.0 * min(bank_w, 2.5) * (1.0 - smoothstep(1.0, 4.0, fp))));

	// --- The grass carpet ---------------------------------------------------
	// Patches over every scale: the broad drift (hue) across hundreds of
	// metres, then light and deep patches down to tufts a metre across.
	// The scales from 8 m up on the patch noise the tufts read too
	// (scripts/endless/endless_patch.gd mirrors this).
	float broad = ep_fade(gxz + vec2(71.0, 13.0), 260.0, fp);
	float wide = ep_fade(gxz + vec2(5.0, 211.0), 70.0, fp);
	float mid = ep_fade(gxz + vec2(133.0, 41.0), 19.0, fp);
	float fine = zs_fade(gxz + vec2(17.0, 3.0), 5.5, fp);
	// High ground goes to a tundra's browner turf.
	float alpine = smoothstep(42.0, 78.0, over + broad * 30.0);
	// Where the rock, the beach, a bank and snow lie (their paint below).
	float rock_edge = (zs_noise(gxz / 9.0) - 0.5) * 0.10 + mid * 0.08;
	float rocky = smoothstep(rock_up + 0.04, rock_up - 0.05, n.y + rock_edge);
	if (!old_rock) {
		// A crisp, ragged edge: tongues of turf and rock, not a long fade.
		float ragged = (er_vnoise(p / 7.0) - 0.5) * 0.10 + (er_vnoise(p / 31.0 + 4.0) - 0.5) * 0.16;
		float w = 0.012 + fp3 * 0.004;
		rocky = smoothstep(rock_up + w, rock_up - w, n.y + ragged + rock_edge * 0.4);
	}
	// More rock breaking through the high ground.
	rocky = max(rocky, smoothstep(0.88, 0.80, n.y + rock_edge) * alpine * (old_rock ? 1.0 : 0.6));
	// The beach: a strip at the water, wider in bays (the meadows' flats
	// stand MEADOW_ABOVE over the sea, and stay turf).
	float sand_edge = (zs_noise(gxz / 7.0) - 0.5) * 0.7 + wide * 0.8 + fine * 0.3;
	float sand_soft = 0.08 + min(fp * 0.2, 0.4);
	float sandy = 1.0 - smoothstep(beach * 0.7 - sand_soft, beach * 0.7 + sand_soft, over + sand_edge);
	float snow_edge = (zs_noise(gxz / 23.0) - 0.5) * 16.0 + mid * 10.0;
	float snowy = smoothstep(snow_line - 14.0, snow_line + 2.0, over + snow_edge)
		* smoothstep(0.55, 0.72, n.y + rock_edge);
	// The Peak: its own snow line, ragged over tens of metres (tongues down
	// the gullies, bare spurs up), the snow holding to steeper ground as it
	// climbs; its granite above the land's own tops; ice and scree on the
	// approach valley's floor (peak_paint).
	vec4 pk = peak_paint(p);
	// (Glacier ice, shaders/peak_ice.gdshaderinc: its mask on the ice's own line.)
	vec4 ice_frame = vec4(0.0);
	vec2 ice_flow = vec2(1.0, 0.0);
	vec2 ice_more = vec2(0.0);
	float ice_gate = 0.0;
	float ice_rubble = 0.0;
	// (The massif's ice carve in the carve marks, peak_ice_mask; none on a serac.)
	vec2 ice_carve = peak_ice_solid == 0.0 ? clamp(land_carve, 0.0, 1.0) : vec2(0.0);
	if (peak_ice_on > 0.5) {
		pk.y = peak_ice_mask(p, pk.x, n.y, ice_carve, ice_frame, ice_flow, ice_more);
		ice_rubble = peak_ice_margin(p, n.y, ice_frame, ice_more) * pk.x;
		pk.z = max(pk.z, ice_rubble);
		rocky *= (1.0 - pk.y) * (1.0 - ice_rubble);
		// (The ice's bump takes the screen slope of a height only its paint
		// writes, so all four pixels of a quad must paint or none: on the mask's
		// edge a pixel read its neighbour's unwritten height, and the NaN it got
		// lit black dashes along the edge. Fine derivatives twice, so a quad with
		// one pixel on the ice opens to its diagonal.)
		ice_gate = pk.y + fwidthFine(pk.y);
		ice_gate += fwidthFine(ice_gate);
	}
	float pk_rock = pk.x * smoothstep(170.0, 320.0, over);
	float pk_dark = 0.0;
	if (peak_basalt > 0.0 && pk.x > 0.0) pk_dark = peak_basalt * pk.x * smoothstep(PEAK_BASALT.x, PEAK_BASALT.y, over + (peak_noise(p.xz / 340.0) - 0.5) * 170.0 + (peak_noise(p.xz / 90.0) - 0.5) * 70.0);
	if (pk.x > 0.0) {
		float pk_edge = (zs_noise(gxz / 160.0) - 0.5) * 120.0 + (zs_noise(gxz / 41.0) - 0.5) * 50.0 + snow_edge;
		float pk_line = mix(snow_line, peak_snow, pk.x);
		float high = smoothstep(peak_snow, peak_snow + 500.0, over);
		float pk_snowy = smoothstep(pk_line - 20.0, pk_line + 4.0, over + pk_edge)
			* smoothstep(0.56, 0.70, n.y + rock_edge);
		if (psnow_on > 0.5) {
			float pk_bare;
			pk_snowy = psnow_mask(psnow_point(p, over), p.xz, over, n.y, pk_line, pk_bare);
			rocky = max(rocky, pk_bare * pk.x);
		}
		snowy = mix(snowy, pk_snowy, pk.x) * (1.0 - max(pk.y, pk.z));
		// The cirque's rim: granite on its slopes, snow on its flatter
		// tops and in its hollows, ragged.
		float rim = peak_rim(p);
		if (rim > 0.0) {
			float bare = rim * (1.0 - smoothstep(0.86, 0.95, n.y + rock_edge + (zs_noise(gxz / 13.0) - 0.5) * 0.14));
			rocky = max(rocky, bare);
			snowy *= 1.0 - bare;
			pk_rock = max(pk_rock, rim);
		}
	}
	// Bare rock lying flat on the Peak is scree: the walls' beds over a floor lie
	// as rings round every bump, like wood grain.
	float pk_scree = pk.x * rocky * smoothstep(0.64, 0.82, n.y + rock_edge);
	// None of the grass shows where sand, a bank or snow covers the ground
	// whole and no rock (whose ledges and moss take its colour), so its paint
	// is skipped there: the same pixels (grass_skip; --land-skip=0 paints it).
	bool skip_grass = grass_skip > 0 && (snowy >= 1.0 || pk.y >= 1.0 || (rocky <= 0.0 && (sandy >= 1.0 || banked >= 1.0)));
	vec3 grass = vec3(0.0);
	// The grass as the rock's ledges and moss take it (before the near grain).
	vec3 moss_grass = vec3(0.0);
	if (!skip_grass) {
		float vast = ep_fade(gxz + vec2(311.0, 97.0), 900.0, fp);
		float tuft = zs_fade(gxz + vec2(9.0, 29.0), 1.4, fp);
		// Patches with an edge: clover and lush hollows among the lighter grass.
		float clump = ep_patch(gxz + vec2(57.0, 19.0), 34.0, fp) * 0.7 + ep_patch(gxz + vec2(3.0, 77.0), 8.0, fp) * 0.5;
		float sunny = clamp((broad * 1.3 + wide * 1.5 + mid * 0.9 + fine * 0.6 + tuft * 0.8 + clump * 0.9) * patch_strength, -1.0, 1.0);
		grass = mix(GREEN, sunny > 0.0 ? SUNLIT : DEEP * 0.82, abs(sunny));
		// The meadows lusher and brighter.
		grass = mix(grass, MEADOW * (1.0 + mid * 0.5), meadow * 0.75);
		// Warm and cool drift, mostly with the broad light.
		float warm = clamp(broad * 2.4 + vast * 1.8, -1.0, 1.0) * patch_strength;
		grass *= mix(vec3(1.0), warm > 0.0 ? zs_warm(vec3(1.32, 1.05, 0.62), paint_follow) : zs_cool(vec3(0.80, 0.97, 1.16), paint_follow), abs(warm) * 0.5);
		// The broad regions' hue (endless_patch ep_region): lush, lime, sage,
		// straw, heather on high ground.
		vec3 region = ep_region(gxz, over, region_amount, region_offset);
		grass *= region;
		// The land's own tint (the vertex colour's hue at the grass's light).
		vec3 vc = land_colour.rgb;
		grass = mix(grass, vc / max(luma(vc), 0.01) * luma(grass), vertex_hue * 0.6);
		// The isles' dry patches (grass_look) and broader dry ground, fading to
		// their means far off (the noise mean is about 0.5, dry from 0.5).
		float dry_near = zs_grass_dry(gxz, ZS_GRASS_DRY_SCALE, zs_grass_offset);
		dry_near = mix(0.18, dry_near, 1.0 - smoothstep(1.0, 3.5, fp));
		float dry_far = smoothstep(0.05, 0.32, broad + wide * 0.6 + 0.1);
		float dry = clamp(dry_near * 0.6 + dry_far * 0.55, 0.0, 1.0) * (1.0 - meadow * 0.6);
		grass = mix(grass, DRY * (1.0 + fine * 0.4), dry * 0.4);
		grass = mix(grass, TUNDRA * (1.0 + mid * 0.6), alpine * 0.8);
		// Steep turf thins to a dry olive.
		float thin = smoothstep(thin_up, rock_up, n.y);
		grass = mix(grass, OLIVE * (1.0 + fine), thin * 0.7);
		// Slopes turned to the sun warmer and lighter, turned away deeper.
		vec2 to_sun = zs_sun_direction.xz / max(length(zs_sun_direction.xz), 0.001);
		float facing = clamp(dot(n.xz, to_sun) * 2.5, -1.0, 1.0) * smoothstep(-0.05, 0.2, zs_sun_direction.y);
		grass *= mix(vec3(1.0), facing > 0.0 ? zs_warm(vec3(1.10, 1.05, 0.86), paint_follow) : zs_cool(vec3(0.90, 0.95, 1.02), paint_follow), abs(facing) * 0.5);

		// The wind: two trains of crests rolling downwind on the air's travel
		// (grass_look's crest), the grass bowed there showing its paler side;
		// far off the crests fade to their mean, a faint sheen.
		float crest_near = zs_grass_crest(gxz, wave_lengths.x, ZS_GRASS_WAVE_SPEED, zs_grass_offset);
		float crest_far = zs_grass_crest(gxz * 0.97 + 50.0, wave_lengths.y, ZS_GRASS_WAVE_SPEED * 1.3, zs_grass_offset + 7.0);
		crest_near = mix(0.35, crest_near, 1.0 - smoothstep(wave_lengths.x * 0.08, wave_lengths.x * 0.3, fp));
		crest_far = mix(0.35, crest_far, 1.0 - smoothstep(wave_lengths.y * 0.08, wave_lengths.y * 0.3, fp));
		float air = clamp(zs_wind_local(gxz), 0.0, 2.0);
		// (Grass that blows as one keeps their mean: the swell carries the motion.)
		float crest = mix(crest_near * 0.35 + crest_far * 0.65, 0.35, rp_swell.x) * air * wind_sheen;
		// Velvet: turf seen low catches the light along its blades.
		float grazing = pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 2.0);
		// (The carpet's tufts catch no velvet: past them its paint keeps less.)
		float carpet_high = turf_alpine.y > 0.0 ? smoothstep(turf_alpine.x, turf_alpine.y, alpine) : smoothstep(turf_high.x, turf_high.y, over);
		float carpet_turf = smoothstep(turf_slope.x, turf_slope.y, n.y) * (1.0 - carpet_high)
			* smoothstep(turf_beach.x, turf_beach.y, over);
		// No carpet on a river's bank or in its water.
		carpet_turf *= 1.0 - max(banked, wet);
		float sheen = crest * (0.35 + 0.65 * grazing) + velvet * grazing * 0.6 * (1.0 - carpet_velvet_cut * carpet_turf);
		vec3 sheen_colour = mix(grass, vec3(luma(grass)) * zs_warm(vec3(1.25, 1.22, 0.85), paint_follow), 0.55) * 1.55;
		grass = mix(grass, sheen_colour, clamp(sheen * 0.42, 0.0, 0.8) * (1.0 - thin * 0.6));
		// The carpet's tone past its tufts, and wherever none grow.
		float turf = carpet_turf;
		float beyond = carpet_reach.y > 0.0 ? clamp((endless_ring_d(CAMERA_POSITION_WORLD, p) - carpet_reach.x) / max(carpet_reach.y - carpet_reach.x, 1.0), 0.0, 1.0) : 1.0;
		float toned = mix(1.0, beyond, turf);
		grass *= mix(vec3(1.0), mix(rp_tone_low, rp_tone_top, smoothstep(0.12, 0.6, eye.y)), toned);
		grass *= mix(vec3(1.0), rp_under_tone, turf * (1.0 - toned));
		float speck_a = smoothstep(0.3, 0.7, zs_noise(turned_speck(gxz, 0) / carpet_grain_sizes.x)) - 0.5;
		float speck_b = smoothstep(0.3, 0.7, zs_noise(turned_speck(gxz, 1) / carpet_grain_sizes.y)) - 0.5;
		float speck = speck_a * (1.0 - smoothstep(carpet_grain_sizes.x * 0.5, carpet_grain_sizes.x * 1.2, fp))
			+ speck_b * 0.7 * (1.0 - smoothstep(carpet_grain_sizes.y * 0.5, carpet_grain_sizes.y * 1.2, fp));
		// Only off where tufts would be pixels: near, the paint's own grain.
		float high_up = smoothstep(high_paint_alt.x, high_paint_alt.y, CAMERA_POSITION_WORLD.y - p.y) * high_paint;
		grass *= 1.0 + speck * carpet_grain * turf * beyond * smoothstep(40.0, 110.0, length(CAMERA_POSITION_WORLD - p)) * (1.0 - clamp(high_up, 0.0, 1.0));
		float wc_up = clamp(high_up, 0.0, 1.0) * wc_paint;
		if (high_up > 0.0) {
			// Broad patches of lighter and deeper, warmer and cooler meadow.
			float hp = turf * high_up * (1.0 - smoothstep(200.0, 900.0, fp));
			grass *= 1.0 + (broad * 0.30 + wide * 0.34 + mid * 0.16) * hp;
			grass *= mix(vec3(1.0), wide > 0.0 ? zs_warm(vec3(1.07, 1.03, 0.86), paint_follow) : zs_cool(vec3(0.88, 0.98, 1.06), paint_follow), clamp(abs(wide) * 0.6, 0.0, 1.0) * hp);
			// Soft streaks, long along the wind, as if combed.
			vec2 sdir = normalize(zs_sun_direction.xz + vec2(0.6, 0.3));
			vec2 sperp = vec2(-sdir.y, sdir.x);
			float streak;
			if (high_paint_old > 0.5) {
				streak = zs_noise(vec2(dot(gxz, sdir) / 190.0, dot(gxz, sperp) / 16.0) + 7.0) - 0.5;
				streak += (zs_noise(vec2(dot(gxz, sdir) / 90.0, dot(gxz, sperp) / 7.0) + 19.0) - 0.5) * 0.5;
			} else {
				// (smooth_wave_field.gdshaderinc: plane waves, long and a little
				// tilted along the wind, their lines bent by slow swings, so no
				// lattice cell shows as a block or a stripe.)
				float along = dot(gxz, sdir);
				float across = dot(gxz, sperp) + 7.0 * sin(along / 75.0 + 1.3) + 4.0 * sin(along / 41.0 + 4.1);
				streak = 0.12 * (sin(across * TAU / 16.0 + along * TAU / 260.0 + 0.7)
					+ sin(across * TAU / 12.5 - along * TAU / 310.0 + 2.9)
					+ sin(across * TAU / 21.0 + along * TAU / 180.0 + 5.1))
					+ 0.08 * (sin(across * TAU / 7.7 - along * TAU / 140.0 + 1.9)
					+ sin(across * TAU / 6.1 + along * TAU / 230.0 + 4.4));
			}
			grass *= 1.0 + streak * 0.30 * hp * (1.0 - smoothstep(3.0, 14.0, fp));
			// Hollows and creases darker, as shade settles in them.
			float hollow = max(-wide, 0.0) * 0.16 + max(-mid, 0.0) * 0.08 + smoothstep(0.97, 0.86, n.y) * 0.22;
			grass *= 1.0 - hollow * hp;
		}
		if (wc_up > 0.0) {
			float wk = turf * (1.0 - thin) * (1.0 - alpine) * wc_up * (1.0 - smoothstep(300.0, 1200.0, fp));
			// The small patches (tuft, fine, mid, clump) melted out: the same
			// colour from the broad scales alone.
			float sunny_w = clamp((broad * 1.3 + wide * 1.5) * patch_strength, -1.0, 1.0);
			vec3 gw = mix(GREEN, sunny_w > 0.0 ? SUNLIT : DEEP * 0.82, abs(sunny_w));
			gw = mix(gw, MEADOW, meadow * 0.75);
			gw *= mix(vec3(1.0), warm > 0.0 ? zs_warm(vec3(1.32, 1.05, 0.62), paint_follow) : zs_cool(vec3(0.80, 0.97, 1.16), paint_follow), abs(warm) * 0.5);
			gw *= region;
			gw = mix(gw, vc / max(luma(vc), 0.01) * luma(gw), vertex_hue * 0.6);
			gw *= mix(vec3(1.0), mix(rp_tone_low, rp_tone_top, smoothstep(0.12, 0.6, eye.y)), toned);
			gw *= mix(vec3(1.0), rp_under_tone, turf * (1.0 - toned));
			grass = mix(grass, gw, wk * 0.8);
			// Washes: warped fields, so their edges wander and bleed.
			vec2 wq = gxz / wc_scale;
			float f1;
			float f2;
			float wet_w = 0.05;
			if (high_paint_old > 0.5) {
				vec2 warp = vec2(zs_noise(wq * 0.8 + vec2(3.1, 8.7)), zs_noise(wq * 0.8 + vec2(9.4, 1.3))) - 0.5;
				wq += warp * 2.6 + (vec2(zs_noise(wq * 2.3 + vec2(14.0, 4.0)), zs_noise(wq * 2.3 + vec2(2.0, 27.0))) - 0.5) * 0.9;
				f1 = zs_noise(wq + vec2(21.0, 5.0)) * 0.72 + zs_noise(wq * 2.7 + vec2(4.0, 33.0)) * 0.28;
				f2 = zs_noise(wq * 1.7 + vec2(60.0, 17.0)) * 0.7 + zs_noise(wq * 4.1 + vec2(8.0, 2.0)) * 0.3;
			} else {
				// Smooth fields (plane waves, no lattice) under a gentle warp
				// that bends and never folds them, so the washes bleed into one
				// another with soft edges and no blocks.
				vec2 warp = vec2(zs_wave_field(wq * 0.7, 1.0, 0.3), zs_wave_field(wq * 0.7, 2.0, 1.7));
				wq += warp * 1.2;
				f1 = zs_wave_fbm(wq, 3.0, 0.2);
				f2 = zs_wave_fbm(wq * 1.7, 7.0, 1.1);
				wet_w = 0.09;
			}
			// Three pigments laid in washes: yellow-green, cool blue-green, olive.
			float wa = smoothstep(0.32, 0.68, f1);
			float wb = smoothstep(0.42, 0.78, f2);
			vec3 pig = mix(vec3(0.72, 0.96, 1.02), vec3(1.30, 1.14, 0.58), wa);
			pig = mix(pig, vec3(1.12, 0.92, 0.62), wb * 0.6);
			grass *= mix(vec3(1.0), pig, wk * 0.9);
			// Wet edges: pigment pools darker and a touch richer where two washes meet.
			float edge = exp(-pow((f1 - 0.51) / wet_w, 2.0)) * 0.7 + exp(-pow((f2 - 0.61) / (wet_w * 0.9), 2.0)) * 0.5;
			grass *= mix(vec3(1.0), vec3(0.66, 0.76, 0.70), clamp(edge, 0.0, 1.0) * wc_edge * wk);
			// Paper light: the pale crowns of the washes, where the water dried thin.
			float crown = smoothstep(0.52, 0.80, f2 * 0.6 + f1 * 0.4 + broad * 0.4 + max(facing, 0.0) * 0.1);
			vec3 paper = vec3(luma(grass)) * zs_warm(vec3(1.18, 1.16, 0.98), paint_follow) * 1.18;
			grass = mix(grass, paper, crown * 0.4 * wc_paper * wk);
			// Pooled pigment in the low washes: deeper and cooler.
			float pool = smoothstep(0.42, 0.22, f2 * 0.6 + f1 * 0.4 + wide * 0.3);
			grass *= mix(vec3(1.0), vec3(0.62, 0.80, 0.78), pool * 0.7 * wk);
			// A river's bank and the water's edge: pigment collected along it.
			grass *= 1.0 - 0.22 * r_here * (1.0 - smoothstep(2.0, 22.0, max(r_out, 0.0))) * wk;
		}
		grass = hued(grass, rp_hue);
		moss_grass = grass;

		// The turf's grain near the eye: tufts and blades too fine to draw,
		// as a speckle of light and dark that fades to nothing with the pixel.
		// Two lattices turned against each other, so no grid shows.
		vec2 turned = mat2(vec2(0.866, 0.5), vec2(-0.5, 0.866)) * gxz;
		vec2 turned2 = mat2(vec2(0.342, -0.94), vec2(0.94, 0.342)) * gxz;
		float grain_near = zs_fade(turned + vec2(3.3, 1.1), 0.3, fp) * 0.8 + zs_fade(turned2 + vec2(41.0, 7.0), 0.55, fp) * 0.7
			+ zs_fade(gxz + vec2(9.0, 2.0), 1.3, fp) * 0.5;
		grass *= 1.0 + grain_near * (1.0 - thin * 0.4);
		// Under the near carpet: the tufts' own ground (endless_patch.gd `grass`).
		if (carpet_near.y > 0.0) {
			float under = carpet_turf * (1.0 - smoothstep(carpet_near.x, carpet_near.y, endless_ring_d(CAMERA_POSITION_WORLD, p))) * (1.0 - wc_up);
			if (under > 0.0) {
				float sunny_c = clamp((broad * 1.3 + wide * 1.5 + mid * 0.9 + clump * 0.9) * patch_strength, -1.0, 1.0);
				vec3 coarse = mix(GREEN, sunny_c > 0.0 ? SUNLIT : DEEP * 0.82, abs(sunny_c));
				coarse = mix(coarse, MEADOW * (1.0 + mid * 0.5), meadow * 0.75);
				coarse *= mix(vec3(1.0), warm > 0.0 ? zs_warm(vec3(1.32, 1.05, 0.62), paint_follow) : zs_cool(vec3(0.80, 0.97, 1.16), paint_follow), abs(warm) * 0.5);
				coarse *= region;
				coarse = mix(coarse, vc / max(luma(vc), 0.01) * luma(coarse), vertex_hue * 0.6);
				float dry_c = clamp(0.18 * 0.6 + dry_far * 0.55, 0.0, 1.0) * (1.0 - meadow * 0.6);
				coarse = mix(coarse, DRY, dry_c * 0.4);
				coarse = mix(coarse, TUNDRA * (1.0 + mid * 0.6), alpine * 0.8);
				coarse = mix(coarse, OLIVE, thin * 0.7);
				coarse *= 1.0 + (grain_near + fine * 0.6 + tuft * 0.8) * carpet_near_grain;
				coarse *= rp_under_tone;
				coarse = hued(coarse, rp_hue);
				grass = mix(grass, coarse, under);
			}
		}
		// The grass's silvery underside where the breeze bows it (grass_silver,
		// off by default): the tufts' own bands, carried on over the paint.
		if (grass_silver.x > 0.0) {
			// (From high up the lattice-free drive; near, the tufts' own, so the two meet.)
			float silver_flip = zs_silver_drive(gxz, fp);
			if (high_paint_old < 0.5 && wc_up > 0.0) silver_flip = mix(silver_flip, zs_silver_drive_smooth(gxz, fp), wc_up);
			if (rp_swell.x > 0.0) silver_flip = mix(silver_flip, zs_swell_silver(zs_sheen_field(gxz, fp, rp_swell.x)), rp_swell.x);
			grass = zs_silver_paint_hue(grass, silver_flip, 1.0 - thin * 0.6, 0.8, rp_silver);
		}
		// The wind's sheen: light and dark swells rolling over the far meadow (grass_sheen).
		if (grass_sheen.x > 0.0) {
			float sheen_d = endless_ring_d(CAMERA_POSITION_WORLD, p);
			float sheen_on = carpet_turf * smoothstep(grass_sheen.y, grass_sheen.z, sheen_d) * (1.0 - thin * 0.6) * (1.0 - 0.85 * wc_up);
			float sheen_s = 0.0;
			if (sheen_on > 0.0 || grass_lawn.x > 0.0) sheen_s = zs_sheen_field(gxz, fp, rp_swell.x);
			if (sheen_on > 0.0) grass *= mix(vec3(1.0), zs_sheen_tone(sheen_s * rp_swell.z, gxz, CAMERA_POSITION_WORLD, sheen_d, zs_key_irradiance), sheen_on);
			// The far grass as a fine lawn (far_lawn.gdshaderinc), from past the tufts.
			if (grass_lawn.x > 0.0) {
				float lawn_on = carpet_turf * smoothstep(grass_lawn.y, grass_lawn.z, sheen_d) * (1.0 - thin * 0.6);
				if (lawn_on > 0.0) grass = zs_far_lawn(grass, gxz, normalize(p - CAMERA_POSITION_WORLD), fp, sheen_s, zs_key_irradiance, zs_cool(vec3(0.93, 0.90, 1.02), paint_follow), lawn_on);
			}
		}
		// The flower drifts past the drawn flowers: heads of their colour dotted
		// over the turf (two lattices, more of them at a drift's heart), which
		// average to a wash of it as a pixel grows past a head; a light wash
		// under the drawn flowers. On open turf only.
		// Gone where a pixel is wider than a small patch's share (the horizon),
		// so it doesn't shimmer.
		float bloom_on = carpet_turf * (1.0 - smoothstep(4.0, 12.0, fp));
		if (bloom_amount > 0.0 && bloom_on > 0.0) {
			vec2 bloom = ep_bloom(gxz, bloom_amount, region_offset);
			float bloom_w = bloom.x * bloom_on;
			if (bloom_w > 0.0) {
				float d = endless_ring_d(CAMERA_POSITION_WORLD, p);
				float past = mix(smoothstep(bloom_fade.x, bloom_fade.y, d), 1.0, wc_up);
				float cut = 0.78 - 0.3 * bloom_w;
				float dot_a = smoothstep(cut, cut + 0.06, zs_noise(turned_speck(gxz, 0) / bloom_dots.x));
				float dot_b = smoothstep(cut, cut + 0.06, zs_noise(turned_speck(gxz + 7.3, 1) / bloom_dots.y));
				float dots = max(dot_a, dot_b);
				// Their mean as the pixel outgrows a head.
				dots = mix(dots, bloom_w * 0.42, smoothstep(bloom_dots.x * 0.4, bloom_dots.y * 1.2, fp));
				// From high up the dots melt into soft blooms of colour.
				dots = mix(dots, bloom_w * smoothstep(0.30, 0.85, zs_noise(gxz / 38.0 + 3.0)) * 0.34, wc_up);
				float wash = mix(bloom_wash.x * bloom_w, bloom_wash.y * dots, past);
				grass = mix(grass, ep_wash(int(bloom.y + 0.5)), clamp(wash, 0.0, 1.0));
			}
		}
		// Stirred by the wash, the walker or a gust (grass_react).
		grass = zs_react_paint(grass, p.xz, CAMERA_POSITION_WORLD.xz - p.xz, carpet_turf * (grass_silver.x > 0.0 ? ZS_SILVER_REACT_PALE : 1.0));
	}

	// --- Rock, sand, snow -----------------------------------------------------
	// Its beds: bands by height, waved, hard pale ones among dark.
	float bed_y = p.y + sin(p.x * 0.013 + p.z * 0.008) * 6.0 + (zs_noise(gxz / 40.0) - 0.5) * 8.0;
	float bed = zs_noise(vec2(bed_y / 3.5, 0.5));
	float grain = zs_fade(gxz + p.y, 2.2, fp) + zs_fade(p.zx + p.y * 0.7, 11.0, fp);
	vec3 rock = mix(ROCK, ROCK_PALE, smoothstep(0.35, 0.75, bed) * 0.8) * (1.0 + grain * 0.5);
	rock *= mix(vec3(1.0), zs_warm(vec3(1.10, 1.0, 0.86), paint_follow), clamp(broad * 2.0 + 0.5, 0.0, 1.0) * 0.6);
	// Ledges lying back hold a little turf.
	rock = mix(rock, moss_grass * 0.8, smoothstep(0.62, 0.74, n.y) * 0.35);
	vec3 lit_n = n;
	vec3 rock_glow = vec3(0.0);
	if (!old_rock && rocky > 0.002) {
		// (The Peak's beds: the same paint on a coordinate stretched up and folded,
		// so a smooth face wears big tilted bands, not a stack of even plates.)
		vec3 bed_p = p;
		if (pk.x > 0.0) {
			float fold = 46.0 * sin(dot(p.xz, vec2(0.0041, 0.0029))) + 20.0 * sin(dot(p.xz, vec2(-0.011, 0.007)) + 1.3) + dot(p.xz, vec2(0.11, 0.14));
			bed_p.y = mix(p.y, (p.y + fold) / PEAK_BEDS, pk.x);
		}
		rock = er_rock_shaped(bed_p, n, fp3, zs_sun_direction, moss_grass * 0.85, land_carve, land_shape, lit_n, rock_glow);
		// Its bounce glow at the sky fill's strength (ER_REF_FILL its luma at
		// the reference light), so it eases with the fill.
		float fill_level = clamp(luma(zs_hemi_sky) * zs_hemi_energy / ER_REF_FILL, 0.25, 2.0);
		rock_glow *= mix(1.0, fill_level, clamp(rock_follow * zs_light_follow, 0.0, 1.0));
		lit_n = normalize(mix(n, lit_n, rocky * (1.0 - pk_scree)));
	}
	rock = hued(rock, rock_hue) * rock_tint * pow(PEAK_BASALT_TINT, vec3(pk_dark));

	vec3 sand = SAND * (1.0 + fine * 0.25 + mid * 0.2);
	sand = mix(sand, SAND_WET, smoothstep(0.7, -0.1, over));
	// The seabed: the sand darkening and greying with depth.
	sand = mix(sand, SEABED * (1.0 + wide), smoothstep(-0.5, -12.0, over));

	// A river's bank: sand with pebbles in it, wet and darker at the water.
	vec3 bank_c = vec3(0.0);
	float damp = 0.0;
	if (banked > 0.0) {
		float stones = smoothstep(0.6, 0.82, zs_noise(turned_speck(gxz, 0) / 0.3)) * (1.0 - smoothstep(0.06, 0.25, fp));
		float cobbles = smoothstep(0.62, 0.86, zs_noise(turned_speck(gxz + 5.1, 1) / 0.8)) * (1.0 - smoothstep(0.15, 0.6, fp));
		bank_c = mix(SAND * vec3(0.88, 0.92, 1.0), ROCK_PALE * 1.1, 0.45 + 0.35 * zs_noise(gxz / 9.0)) * (1.0 + fine * 0.3 + mid * 0.2);
		bank_c = mix(bank_c, ROCK_PALE * 1.2, stones * 0.6);
		bank_c = mix(bank_c, ROCK * 1.1, cobbles * 0.45);
		// Far off, the pebbles' mean.
		bank_c = mix(bank_c, mix(bank_c, ROCK_PALE, 0.15), smoothstep(0.1, 0.6, fp));
		// At a mouth the stones give way to the beach's sand.
		bank_c = mix(bank_c, SAND * (1.0 + fine * 0.25 + mid * 0.2), r_mouth * 0.85);
		damp = 1.0 - smoothstep(0.0, river_bank.y, r_out);
		bank_c = mix(bank_c, SAND_WET * 0.85, damp * 0.85);
	}

	vec3 snow = SNOW * (1.0 + fine * 0.06);
	// The Peak's granite: the rock's own light, grey and a little cool, its
	// pale beds softened; a colder snow, blue where it lies back from the sun.
	if (pk_rock > 0.0) {
		float l = luma(rock);
		vec3 granite = vec3(mix(peak_granite, PEAK_BASALT_GRANITE, pk_dark) + l * 0.42) * vec3(0.88, 0.95, 1.08) * (1.0 + peak_fade(gxz * 1.7 + p.y, 1.3, fp) * 0.35);
		rock = mix(rock, granite, pk_rock * 0.85);
		// The prow's bow, and the mouth's walls with it, darkest (peak_split.gd
		// BOW_A), off the gorges' floors.
		rock *= 1.0 - PEAK_BOW_DARK * pk_rock * smoothstep(1500.0, 1780.0, dot(p.xz - peak_frame.xy, peak_frame.zw)) * smoothstep(350.0, 430.0, over);
		snow = mix(snow, snow * mix(vec3(0.92, 0.96, 1.04), vec3(0.84, 0.90, 1.0), clamp((0.25 - dot(n, zs_sun_direction)) * 2.0, 0.0, 1.0)), pk.x);
	}
	// The Peak's relief in its paint (PeakRock, through the carve's marks): a wall
	// square to the sun has all its normals in one tone, so its ribs show here.
	if (pk.x > 0.0) {
		float pk_sun = 0.5 + 0.5 * smoothstep(0.0, 0.5, dot(n, zs_sun_direction));
		rock *= mix(vec3(1.0), PEAK_GULLY, clamp(land_carve.x, 0.0, 1.0) * pk.x * pk_sun);
		rock *= 1.0 + PEAK_RIB * clamp(land_carve.y, 0.0, 1.0) * pk.x * pk_sun;
	}
	// The Peak's snow has its own surface and light (peak_snow.gdshaderinc).
	float ps_on = psnow_on * pk.x * step(0.001, snowy);
	vec3 ps_n = n;
	vec3 ps_glit = vec3(0.0);
	if (ps_on > 0.0) snow = mix(snow, psnow_surface(p, psnow_point(p, over), n, eye, distance(p, CAMERA_POSITION_WORLD), 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y), snowy, ps_n, ps_glit), ps_on);

	vec3 albedo = mix(grass, rock, rocky);
	albedo = mix(albedo, sand, sandy * (1.0 - rocky * 0.5));
	albedo = mix(albedo, bank_c, banked * (1.0 - rocky * 0.7));
	// The Peak's valley floor: scree of granite on the boulder field; ice
	// down the icefall and the glacier, streaked along its flow and dirtied
	// toward its edges, its steep faces (crevasse walls, the icefall's
	// risers) a deep blue.
	if (max(pk.z, pk_scree) > 0.0) {
		// (On the ground's plan, not the sheared gxz: on a floor's ripples the shear
		// comes and goes, and it dragged this noise into rings.)
		vec2 sc = p.xz;
		float stones = peak_fade(sc + 3.1, 1.6, fp) + peak_fade(sc * 0.7 + 9.0, 6.0, fp);
		vec3 scree = mix(ROCK_PALE, ROCK, smoothstep(0.2, 0.8, peak_noise(sc / 13.0))) * vec3(0.95, 0.98, 1.02) * (1.05 + stones * 0.5);
		float sc_on = max(pk.z, pk_scree);
		albedo = mix(albedo, scree, max(pk.z * 0.9, pk_scree));
		if (ice_rubble > 0.0) albedo = mix(albedo, peak_ice_stones(sc, fp), ice_rubble);
		else albedo = mix(albedo, peak_ice_stones(sc, fp) * PEAK_FLOOR_PALE, sc_on * PEAK_FLOOR_STONES);
	}
	vec3 ice_glow = vec3(0.0);
	float ice_rough = 0.4;
	float ice_spec = 0.5;
	if (ice_gate > 0.0) {
		vec3 ice_col;
		vec3 ice_n = lit_n;
		bool ice_solid = peak_ice_solid > 0.5;
		// (max: under MSAA a pixel a triangle only clips reads its varyings past the
		// triangle, so a vertex colour of 0 runs negative, and pow of that is a NaN,
		// which the glow spread into a flare.)
		peak_ice_paint(p, n, eye, ice_frame, ice_flow, ice_more, fp, distance(p, CAMERA_POSITION_WORLD) * 0.0016, ice_solid ? pow(max(land_colour.r, 0.0), 0.45) : 0.5, ice_solid ? pow(max(land_colour.g, 0.0), 0.45) : 1.0, ice_solid ? land_colour.b : 0.0, ice_carve, ice_col, ice_n, ice_glow, ice_rough, ice_spec);
		albedo = mix(albedo, ice_col, pk.y);
		lit_n = normalize(mix(lit_n, ice_n, pk.y));
		ice_glow *= pk.y;
	} else if (pk.y > 0.0) {
		vec2 f = peak_frame.zw;
		vec2 flow = vec2(dot(p.xz, f), dot(p.xz, vec2(-f.y, f.x)));
		// (Each scale eases to its mean as the pixel outgrows it across the flow.)
		float streak = mix(zs_noise(vec2(flow.x / 140.0, flow.y / 11.0)), 0.5, smoothstep(3.0, 9.0, fp)) * 0.6
			+ mix(zs_noise(vec2(flow.x / 45.0, flow.y / 4.0)), 0.5, smoothstep(1.0, 3.5, fp)) * 0.4;
		vec3 ice = mix(vec3(0.36, 0.52, 0.62), vec3(0.58, 0.70, 0.78), smoothstep(0.3, 0.7, streak));
		ice = mix(ice, vec3(0.36, 0.35, 0.34), smoothstep(0.78, 1.0, pk.w) * 0.6 * (0.6 + 0.4 * zs_noise(gxz / 17.0)));
		ice = mix(ice, vec3(0.20, 0.38, 0.50), rocky);
		albedo = mix(albedo, ice, pk.y);
	}
	albedo = mix(albedo, snow, snowy);
	if (ps_on > 0.0) lit_n = normalize(mix(lit_n, ps_n, snowy * ps_on));
	vec2 pt_rw = vec2(0.0);
	if (peak_tarn.w > 0.5) albedo = peak_tarn_shore(albedo, p, fp, pt_rw);
	if (grass_skip == 2 && skip_grass) albedo = vec3(1.0, 0.0, 1.0);
	albedo = mix(albedo, vec3(luma(albedo)) * night_grade.yzw, night_grade.x);
	// Under a cloud's shadow the sun's share goes (the albedo the sun
	// lights), the sky's fill (the emission below) stays.
	float shade = zs_cloud_volume_shade(p);
	float shaded = shade * cloud_shade;
	// The land's own shade past the sun's map (land_horizon.gdshaderinc, off
	// unless --terrain-shadows): the sun's share, and the sky's fill below.
	vec2 horizon = zs_horizon_light(p, distance(p, CAMERA_POSITION_WORLD));
	ALBEDO = (albedo + ps_glit * snowy * ps_on) * (1.0 - shaded) * horizon.x;
	float wet_sand = max(sandy * smoothstep(0.7, 0.0, over) * step(-0.5, over), damp * banked);
	ROUGHNESS = mix(mix(mix(mix(0.92, 0.82, rocky), 0.6, snowy), 0.35, wet_sand), 0.4, pk.y);
	ROUGHNESS = mix(ROUGHNESS, pt_rw.x, pt_rw.y);
	SPECULAR = mix(mix(0.25, 0.35, rocky), 0.5, max(max(snowy, wet_sand), pk.y)) * (1.0 - shaded) * horizon.x;
	NORMAL = normalize((VIEW_MATRIX * vec4(lit_n, 0.0)).xyz);
	// The hemisphere fill, as the isles' surfaces take it (environment
	// ambient is off under LandscapeLighting).
	// (On the ground's ice by its own normal: its triangles' tilts aren't its shape,
	// and showed from the air as plates of grey and blue.)
	float fill_y = mix(n.y, lit_n.y, pk.y * peak_ice_on * (1.0 - step(0.5, abs(peak_ice_solid))));
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, fill_y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float hollow = 0.85 + 0.15 * fill_y;
	// A cloud overhead takes a little of the sky's fill too.
	EMISSION = albedo * hemi * hollow * horizon.y * (1.0 - 0.2 * shade) + rock_glow * rocky * (1.0 - snowy) * (1.0 - pk.y) * (1.0 - pk_rock * 0.6);
	// The rock's glow goes by its own face's turn from the sun, and knows nothing of
	// another wall's shadow: a Peak wall facing the sun in one fell to black.
	EMISSION += albedo * hemi * PEAK_CAST_FILL * rocky * pk_rock * (1.0 - snowy) * (1.0 - pk.y) * smoothstep(-0.05, 0.45, dot(lit_n, zs_sun_direction));
	if (ice_glow != vec3(0.0)) {
		ROUGHNESS = mix(ROUGHNESS, ice_rough, pk.y);
		SPECULAR = mix(SPECULAR, ice_spec * (1.0 - shaded) * horizon.x, pk.y);
		EMISSION += ice_glow * horizon.y * (1.0 - 0.2 * shade);
	}
	if (ps_on > 0.0) EMISSION = psnow_emission(EMISSION, snowy * ps_on);
	if (wet > 0.0) {
		// The river's water, as the sea draws it (endless_sea.gdshader): its
		// colour by the depth (faked from the way in from the bank), the bed
		// through the shallows, the sky mirrored by fresnel, the sun's path
		// and glitter, a pale line at the edge; ripples drifting down the
		// valley with the flow. Unlit, as the sea is: all in EMISSION.
		vec2 fl = river_flow;
		float spd = length(fl);
		vec2 dir = spd > 0.02 ? fl / spd : vec2(0.8, 0.6);
		float t = TIME;
		float speed = max(spd, 0.12) * river_flow_look.x;
		// How broken the water is (0 calm, 1 white water): by the current's
		// speed (the level's fall), more in riffle patches down any running
		// stretch, none in a still pool, and settling into the mouth.
		float rif = smoothstep(0.42, 0.66, ep_noise(p.xz / river_riffle.x) * 0.7 + ep_noise(p.xz / (river_riffle.x * 0.3) + 9.1) * 0.3);
		float running = smoothstep(0.45, 1.1, spd);
		float tb = smoothstep(river_rapids.x, river_rapids.y, spd) * (0.45 + 0.75 * rif) + rif * running * river_riffle.y;
		// (The mouth read from the drawn water's own height, not the level's
		// interpolation, which runs off to nothing toward a vertex out of
		// the river's reach.)
		float r_sea = river_mouth_blend * (1.0 - smoothstep(0.0, river_mouth_rise, over));
		tb = clamp(tb, 0.0, 1.0) * river_rapids.z * (1.0 - r_sea);
		vec2 slope = vec2(0.0);
		float rough = 0.0;
		float k0 = 1.0 - smoothstep(river_ripple_size.x * 0.04, river_ripple_size.x * 0.22, r_fp);
		float k1 = 1.0 - smoothstep(river_ripple_size.y * 0.04, river_ripple_size.y * 0.22, r_fp);
		float k2 = 1.0 - smoothstep(river_ripple_size.z * 0.04, river_ripple_size.z * 0.22, r_fp);
		// The live river's state, for the paint below (river_live 1).
		float live_foam = 0.0;
		float live_white = 0.0;
		float live_eddy = 0.0;
		vec2 live_vel = vec2(0.0);
		float live_phase = 0.0;
		vec3 live_dbg = vec3(-1.0);
		if (river_live > 0.5) {
			// The channel's own direction (it follows the meanders), turned
			// down the flow; across it, the bend's outside and the widening.
			vec2 tf = river_frame.xy;
			vec2 lt = dot(tf, tf) > 0.04 ? normalize(tf) : dir;
			float u = clamp(r_s / max(r_w, 0.01), 0.0, 1.0);
			float bend = river_frame.z;
			float widen = river_frame.w;
			float outside = bend * river.x;
			// Shear: fast in the middle, slow at the banks, faster round the
			// bend's outside (the river's speed already rises with its fall).
			float prof = mix(river_shear.x, river_shear.y, pow(max(1.0 - u * u, 0.0), river_shear.z));
			float v = spd * prof * (1.0 + clamp(outside * river_shear.w, -0.35, 0.35));
			// Eddies by the banks: inside a bend, where it widens, in patches;
			// the current there turns back and swirls (a stream function's curl).
			vec2 euv = p.xz / (river_eddy.z * 16.0) + vec2(0.31, 0.77);
			float eh = texture(river_live_height, euv).r;
			float eddy = smoothstep(0.55, 0.95, u) * clamp(smoothstep(0.0, 0.08, -outside) * 1.2 + smoothstep(0.55, 0.72, eh) * 0.7 + smoothstep(0.005, 0.04, widen) * 0.6, 0.0, 1.0);
			eddy *= smoothstep(0.12, 0.45, spd) * river_eddy.x;
			vec2 swirl = texture(river_live_normal, euv).xy * 2.0 - 1.0;
			live_vel = lt * v * (1.0 - eddy * river_eddy.y) + vec2(-swirl.y, swirl.x) * spd * eddy * river_eddy.w;
			live_eddy = eddy;
			float lv = length(live_vel);
			live_phase = texture(river_live_height, p.xz / (river_live_cycle.y * 16.0)).r;
			// The ripples ride the current: rougher where it runs fast, glassy
			// in the eddies and pools.
			float amp = mix(0.55, 1.35, smoothstep(0.15, 2.4, lv)) * (1.0 - 0.55 * eddy);
			if (river_fft > 0) {
				float s1 = river_fft_sizes.y * river_fft_use.x;
				float s2 = river_fft_sizes.z * river_fft_use.y;
				float kf1 = 1.0 - smoothstep(s1 * 0.03, s1 * 0.2, r_fp);
				float kf2 = 1.0 - smoothstep(s2 * 0.03, s2 * 0.2, r_fp);
				if (k0 > 0.0) slope += zs_live_flow(river_detail_a, p.xz, live_vel * 0.85, river_ripple_size.x, live_phase, t, dpx, dpy) * river_ripple_strength.x * 0.6 * k0 * amp;
				if (kf1 > 0.0) slope += zs_live_fft(1, p.xz, live_vel, river_fft_use.x, live_phase + 0.37, t, dpx, dpy) * river_fft_use.z * kf1 * amp;
				if (kf2 > 0.0) slope += zs_live_fft(2, p.xz + 7.0, live_vel * 1.1, river_fft_use.y, live_phase + 0.71, t, dpx, dpy) * river_fft_use.w * kf2 * amp;
				float a0 = river_ripple_strength.x * 0.6, a1 = river_fft_use.z * 0.35, a2 = river_fft_use.w * 0.35;
				rough = (a0 * a0 * (1.0 - k0) + a1 * a1 * (1.0 - kf1) + a2 * a2 * (1.0 - kf2)) * amp * amp;
			} else {
				if (k0 > 0.0) slope += zs_live_flow(river_detail_a, p.xz, live_vel * 0.85, river_ripple_size.x, live_phase, t, dpx, dpy) * river_ripple_strength.x * k0 * amp;
				if (k1 > 0.0) slope += zs_live_flow(river_detail_b, p.xz, live_vel, river_ripple_size.y, live_phase + 0.37, t, dpx, dpy) * river_ripple_strength.y * k1 * amp;
				if (k2 > 0.0) slope += zs_live_flow(river_detail_a, p.xz + 17.0, live_vel * 1.15, river_ripple_size.z, live_phase + 0.71, t, dpx, dpy) * river_ripple_strength.z * k2 * amp;
				rough = (river_ripple_strength.x * river_ripple_strength.x * (1.0 - k0) + river_ripple_strength.y * river_ripple_strength.y * (1.0 - k1)
					+ river_ripple_strength.z * river_ripple_strength.z * (1.0 - k2)) * amp * amp;
			}
			// Riffles: standing waves over a steep bed, at a narrowing, round a
			// bend, thicker on the gravel bars, with the ripples running through.
			float steep = smoothstep(river_live_riffle.x, river_live_riffle.y, spd);
			float bar = smoothstep(0.35, 0.75, texture(river_live_height, p.xz / (river_riffle_where.z * 16.0) + vec2(0.53, 0.11)).r);
			float riff = clamp(steep + smoothstep(0.01, 0.06, -widen) * river_riffle_where.x + smoothstep(0.004, 0.02, abs(bend)) * river_riffle_where.y
				+ river_riffle_where.w * smoothstep(0.4, 1.0, spd), 0.0, 1.4) * mix(0.2, 1.0, bar) * (1.0 - eddy) * (1.0 - 0.6 * pow(u, 4.0));
			// Their crests stand where the current's waves stand still (2 pi v^2 / g).
			float lam = clamp(6.2832 * spd * spd / 9.81, 0.7, 3.5);
			float kr = 1.0 - smoothstep(lam * 0.08, lam * 0.4, r_fp);
			float white_far = 0.12 * riff * steep;
			if (riff > 0.01 && kr > 0.0) {
				float crest;
				vec2 rs = zs_live_riffle(p.xz, lt, lam, dpx, dpy, crest);
				slope += rs * riff * river_live_riffle.z * kr;
				live_white = mix(white_far, smoothstep(0.78, 0.95, crest + riff * 0.08) * smoothstep(0.5, 1.1, riff) * steep, kr);
			} else {
				live_white = white_far;
			}
			live_white *= river_live_riffle.w;
			rough += riff * riff * river_live_riffle.z * river_live_riffle.z * 0.3 * (1.0 - kr);
			// Foam: flecks carried by the current, gathering at the banks, round
			// the bend's outside, in the eddies, below white water, and in
			// lines drawn out down the flow (held at a distance from the bank).
			float wob = texture(river_live_height, p.xz / 380.0).r;
			float lines = smoothstep(0.62, 0.74, texture(river_live_height, vec2(river.x / (max(r_w, 2.0) * 0.8 * 16.0) + wob * 0.2, 0.37)).r) * river_foam.w;
			float cover = clamp(smoothstep(0.65, 0.98, u) * river_foam.z * 0.8 + smoothstep(0.0, 0.1, outside) * 0.35 + eddy * river_foam.z * 0.7 + live_white * 1.6 + riff * 0.12 + lines * 0.6, 0.0, 1.0)
				* smoothstep(0.08, 0.35, spd);
			float fk = 1.0 - smoothstep(river_foam.y * 0.2, river_foam.y * 1.0, r_fp);
			float flecks = cover * 0.18;
			if (fk > 0.0 && cover > 0.02) {
				float cut = mix(1.02, 0.72, cover);
				flecks = mix(flecks, zs_live_flecks(p.xz, live_vel, river_foam.y, cut, live_phase * 0.7 + 0.2, t, dpx, dpy) * (0.5 + 0.5 * cover), fk);
			}
			// The white water: the crests' flecks thick, over a thin wash.
			live_foam = clamp(flecks * mix(river_foam.x, 1.0, live_white) + live_white * 0.3, 0.0, 1.0);
			if (river_live_debug == 1) live_dbg = vec3(max(outside * 10.0, 0.0), max(-outside * 10.0, 0.0), 0.0);
			else if (river_live_debug == 2) live_dbg = vec3(eddy);
			else if (river_live_debug == 3) live_dbg = vec3(riff, steep, bar);
			else if (river_live_debug == 4) live_dbg = vec3(length(live_vel) / 4.0, spd / 4.0, 0.0);
			else if (river_live_debug == 5) live_dbg = vec3(live_foam, cover, live_white);
		} else {
			if (k0 > 0.0) slope += zs_river_layer(river_detail_a, p.xz, dir, speed * 0.85, river_ripple_size.x, 0.0, t) * river_ripple_strength.x * k0;
			if (k1 > 0.0) slope += zs_river_layer(river_detail_b, p.xz, dir, speed, river_ripple_size.y, 0.37, t) * river_ripple_strength.y * k1;
			if (k2 > 0.0) slope += zs_river_layer(river_detail_a, p.xz + 17.0, dir, speed * 1.15, river_ripple_size.z, 0.71, t) * river_ripple_strength.z * k2;
			rough = river_ripple_strength.x * river_ripple_strength.x * (1.0 - k0) + river_ripple_strength.y * river_ripple_strength.y * (1.0 - k1)
				+ river_ripple_strength.z * river_ripple_strength.z * (1.0 - k2);
			// White water churns; and the surface leans down the fall (the level's
			// slope, from the speed as land_field's RIVER_FLOW makes it).
			float churn = 1.0 + tb * river_churn;
			slope *= churn;
			rough *= churn * churn;
			float fall = pow(max(spd - 0.35, 0.0) / 9.0, 2.0);
			slope -= dir * fall;
		}
		vec3 wn = normalize(vec3(-slope.x, 1.0, -slope.y));
		vec3 calm = normalize(vec3(-slope.x * river_calm, 1.0, -slope.y * river_calm));
		float d_in = max(-r_out, 0.0);
		// The depth swings down the river (bars and pools), shallower over a
		// riffle, so the shallows' band never runs even.
		float bars = mix(0.6, 1.45, ep_noise(p.xz / 37.0 + 3.7));
		float depth = min(d_in * river_depth.x * bars, river_depth.y) * (1.0 - 0.4 * rif * running);
		vec3 column = mix(river_tint_shallow, river_tint_mid, smoothstep(0.0, river_tint_depths.x, depth));
		column = mix(column, river_tint_deep, smoothstep(river_tint_depths.x * 0.5, river_tint_depths.y, depth));
		column *= zs_palette_water;
		vec3 ambient = zs_hemi_sky * zs_hemi_energy / PI;
		vec3 key = zs_key_irradiance * max(zs_key_direction.y, 0.0) / PI;
		vec3 light = (ambient + key * 0.8) * river_light;
		float through = depth / max(abs(eye.y), 0.15);
		vec3 seen = exp(-river_absorb * through) * exp(-depth / river_bed_fade);
		vec3 bed_c = mix(SAND * 0.75, ROCK_PALE, 0.35) * (ambient * 0.9 + key);
		if (river_live > 0.5) {
			// The live bed: sand and stones with dark weed, bent by the
			// ripples over it (more the deeper), the sun's caustics drifting
			// over it with the current; far off, its mean.
			vec2 bp = p.xz + slope * depth * river_bed.y;
			float keep_b = 1.0 - smoothstep(0.3, 2.5, fp);
			float stones = textureGrad(river_live_height, bp / (0.9 * 16.0) + vec2(0.17, 0.43), dpx / 14.4, dpy / 14.4).r;
			float weed = textureGrad(river_live_height, bp / (5.0 * 16.0) + vec2(0.71, 0.29), dpx / 80.0, dpy / 80.0).r;
			vec3 bed_t = mix(SAND * 0.75, ROCK_PALE, 0.35) * mix(1.0, 0.7 + 0.6 * stones, keep_b * river_bed.x);
			bed_t = mix(bed_t, vec3(0.09, 0.13, 0.07), smoothstep(0.58, 0.78, weed) * 0.55 * river_bed.x);
			float caus = 0.0;
			float kc = 1.0 - smoothstep(river_bed.w * 0.08, river_bed.w * 0.4, fp);
			if (kc > 0.0) {
				float sc = 1.0 / (river_bed.w * 16.0);
				vec2 drift = live_vel * 0.6;
				float c0 = t / 2.2 + live_phase;
				float f0 = fract(c0);
				float w0 = 1.0 - abs(2.0 * f0 - 1.0);
				float ca = textureGrad(river_live_height, (bp - drift * 2.2 * (f0 - 0.5) + vec2(t * 0.11, 0.0)) * sc + fract(floor(c0) * vec2(0.31, 0.67)), dpx * sc, dpy * sc).r;
				float cb = textureGrad(river_live_height, (bp - drift * 2.2 * (fract(c0 + 0.5) - 0.5) - vec2(0.0, t * 0.09)) * sc * 1.37 + fract(floor(c0 + 0.5) * vec2(0.53, 0.19)), dpx * sc * 1.37, dpy * sc * 1.37).r;
				float ra = pow(1.0 - abs(2.0 * ca - 1.0), 5.0);
				float rb = pow(1.0 - abs(2.0 * cb - 1.0), 5.0);
				caus = (ra * w0 + rb * (1.0 - w0)) * kc;
			}
			bed_c = bed_t * (ambient * 0.9 + key * (1.0 + caus * river_bed.z * 2.0));
		}
		vec3 water = column * light * (vec3(1.0) - seen) + bed_c * seen;
		if (r_tint > 0.0) {
			// Toward the sea: the sea's colour (endless_sea.gdshader) for the
			// channel's real depth (land_field `_river`'s bed, deeper and
			// flatter at a mouth), seen as the sea sees the bed up the channel.
			float u = clamp(r_s / max(r_w, 0.01), 0.0, 1.0);
			// (Up the river, before the bed deepens, the faked depth.)
			float real = (river_mouth_deep.x + river_mouth_deep.y * r_mouth) * (1.0 - pow(u, 2.0 + 2.0 * r_mouth));
			real = mix(depth, real, smoothstep(0.0, 0.6, r_mouth));
			float through_m = real / max(abs(eye.y), 0.15);
			float waver = mix(0.8, 1.25, zs_noise(p.xz * 0.03) * 0.7 + zs_noise(p.xz * 0.11 + vec2(4.1, 7.3)) * 0.3);
			float wd = max(real, through_m * 0.55) * waver;
			vec4 td = river_sea_tint_depths;
			vec3 sc = mix(river_tint_shallow, river_tint_mid, smoothstep(0.0, td.y, wd));
			sc = mix(sc, river_tint_deep, smoothstep(td.y * 0.6, td.z, wd));
			sc = mix(river_tint_shallow, sc, smoothstep(0.0, td.x, wd) * 0.6 + 0.4);
			sc *= zs_palette_water * river_sea_body;
			vec3 seen_m = exp(-river_absorb * through_m) * exp(-max(real, through_m * 0.4) / river_sea_bed_fade);
			vec3 bed_m = SAND_WET * 0.85 * (ambient + key);
			water = mix(water, sc * light * (vec3(1.0) - seen_m) + bed_m * seen_m, r_tint * river_mouth_tint);
		}
		// (Still water, a pond: no current to streak.)
		float still = 1.0 - smoothstep(0.05, 0.3, spd);
		vec3 white = vec3(0.9, 0.96, 1.0) * (ambient * 1.1 + key * 0.8);
		float line = 0.0;
		float sl = 0.0;
		if (river_live < 0.5) {
			// White water: the body aerated, paler and milkier.
			water = mix(water, white * 0.62 + column * light * 0.35, tb * 0.4);
			// Foam riding down the flow (zs_river_foam): over white water, in a
			// broken fringe along both banks (wider the rougher), and in a front
			// where the river meets the sea; on calm water only streak lines.
			float vspd = max(spd * river_flow_look.x, river_flow_look.y);
			float fringe = mix(river_bank_foam.x, river_bank_foam.y, tb) * (0.45 + 1.1 * ep_noise(p.xz / 9.0 + 2.3)) + r_fp * 0.5;
			float at_bank = (1.0 - smoothstep(0.0, fringe, d_in)) * river_bank_foam.z;
			float front = river_mouth_foam * smoothstep(0.45, 0.72, r_sea) * (1.0 - smoothstep(0.82, 0.97, r_sea));
			float th = mix(1.05, 0.55, tb);
			th = min(th, mix(1.05, mix(0.6, 0.4, tb), at_bank));
			th = min(th, mix(1.05, 0.5, front));
			vec3 fm = zs_river_foam(p.xz, dir, vspd, t, th, r_fp);
			line = fm.x;
			// Streak lines on the running water (paler threads drifting down).
			float streak = fm.y * river_streaks * smoothstep(0.15, 0.7, spd) * (1.0 - tb) * smoothstep(0.0, 2.0, d_in);
			water = mix(water, column * light * 1.5 + vec3(0.02), streak * 0.3);
			// The slicks: broad bands down the current, the body a shade lighter
			// or darker and the mirror glassier or duller.
			sl = (fm.z - 0.5) * 2.0 * (0.4 + 0.6 * running) * (1.0 - 0.7 * tb);
			water *= 1.0 + sl * river_slick.y;
		}
		// The ripples' faces: lighter toward the sun, darker away (the
		// sea's body_shade), so the chop reads where the mirror is dim.
		water *= 1.0 + clamp(dot(slope, -normalize(zs_sun_direction.xz + vec2(1e-4))) * 2.5, -0.45, 0.45) * river_body_shade;
		water *= 1.0 - 0.4 * shaded;
		// The live river's foam and white water.
		if (river_live > 0.5 && live_foam > 0.0) {
			vec3 froth = vec3(0.92, 0.96, 1.0) * (ambient * 1.15 + key * 0.85);
			water = mix(water, froth, live_foam * 0.8);
		}
		// Lily pads on still water: a pad in most cells of a cluster, through
		// the shallow ring; far off, the clusters' mean green.
		float pad = 0.0;
		if (still > 0.0 && river_pads.x > 0.0 && d_in > 0.5) {
			float cluster = smoothstep(0.52, 0.72, zs_noise(p.xz / 7.0 + 2.3)) * smoothstep(0.6, 1.8, d_in) * (1.0 - smoothstep(4.5, 7.5, d_in)) * still * river_pads.x;
			if (cluster > 0.0) {
				vec2 g = p.xz / river_pads.y;
				vec2 cell = floor(g);
				vec2 h = fract(sin(vec2(dot(cell, vec2(127.1, 311.7)), dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
				vec2 q = g - cell - (vec2(0.5) + (fract(h * 7.31 + 0.17) - 0.5) * 0.62);
				float rad = river_pads.z * mix(0.8, 1.35, h.y);
				float aa = max(fp / river_pads.y, 0.01);
				// The notch: a wedge cut to the middle.
				float ang = atan(q.y, q.x) - h.x * 6.2832;
				float notch = smoothstep(0.1, 0.22, abs(mod(ang + 3.14159, 6.2832) - 3.14159));
				float one = (1.0 - smoothstep(rad - aa, rad + aa, length(q))) * mix(notch, 1.0, smoothstep(0.02, 0.06, aa)) * step(h.x, 0.8);
				// Far off, the mean cover.
				pad = mix(one, 0.3, smoothstep(0.1, 0.4, aa)) * smoothstep(0.0, 0.2, cluster);
				vec3 pc = river_pad_colour * (0.75 + 0.45 * h.y) * (ambient + key * 0.9);
				// The odd flower in its middle.
				float bloom = (1.0 - smoothstep(rad * 0.28 - aa, rad * 0.28 + aa, length(q + vec2(0.0, rad * 0.15)))) * step(0.86, h.y) * (1.0 - smoothstep(0.03, 0.08, aa));
				pc = mix(pc, vec3(0.95, 0.78, 0.82) * (ambient + key), bloom);
				water = mix(water, pc, pad);
			}
		}
		float skin = line;
		if (river_live > 0.5) {
			// The pale line at the edge, lapping, broken; far off a soft rim.
			float lap = river_edge * (0.6 + 0.4 * zs_noise(p.xz / 23.0)) * (0.85 + 0.15 * sin(t * 0.8 + zs_noise(p.xz * 0.15) * 6.2832)) + r_fp * 0.5;
			line = (1.0 - smoothstep(0.0, lap, d_in)) * mix(0.25 + 0.3 * zs_noise(p.xz * 0.35 - dir * t * 0.3), 0.3, smoothstep(0.3, 1.5, r_fp));
			water = mix(water, white, line * 0.7);
			skin = max(line, live_foam);
		} else {
			water = mix(water, white * (1.0 - 0.4 * shaded), line * 0.9);
		}
		vec3 refl = reflect(-eye, calm);
		refl.y = abs(refl.y);
		vec3 sky = clamp(zsSkyGradient(refl), vec3(0.0), vec3(0.98));
		// Low in the mirror stand the banks and the valley's sides, not the
		// open sky (there is no screen march on the ground): a dim green-grey
		// band toward the horizon of the reflection.
		vec3 shore_tone = zs_scene_to_display((ambient * 0.9 + key * 0.35) * vec3(0.16, 0.22, 0.12));
		sky = mix(sky, shore_tone, smoothstep(river_shore_mirror.x, river_shore_mirror.y, refl.y) * river_shore_mirror.z);
		// The cloud field mirrored, as the sea has it (endless_sea.gdshader):
		// where the reflected ray meets the clouds' height, the shade map's
		// spot under that cloud along the sun's line.
		if (zs_cloud_shadow_at.w > 0.0 && refl.y > 0.02) {
			const float CLOUD_Y = 20.0;
			vec3 c = p + refl * ((CLOUD_Y - p.y) / refl.y);
			vec3 l = zs_cloud_shadow_light.xyz;
			vec2 q = c.xz - l.xz / max(l.y, 0.12) * (CLOUD_Y - zs_cloud_shadow_light.w);
			vec2 cuv = (q - zs_cloud_shadow_at.xy) / max(zs_cloud_shadow_at.z, 1.0);
			if (all(greaterThan(cuv, vec2(0.0))) && all(lessThan(cuv, vec2(1.0)))) {
				vec2 texel = 2.5 / vec2(textureSize(zs_cloud_shadow, 0));
				float thick = 0.0;
				for (int k = 0; k < 4; k++) {
					vec2 o = vec2(k % 2 == 0 ? -1.0 : 1.0, k < 2 ? -1.0 : 1.0) * texel;
					vec3 cs = texture(zs_cloud_shadow, cuv + o).rgb;
					thick += 0.25 * (1.0 - cs.g * cs.r);
				}
				vec2 rim = min(cuv, 1.0 - cuv);
				float far_c = 1.0 - smoothstep(600.0, 2200.0, length(c.xz - p.xz));
				float cloud = smoothstep(0.0, 1.0, thick) * 0.8 * smoothstep(0.0, 0.08, min(rim.x, rim.y)) * far_c;
				vec3 lit_cloud = zs_scene_to_display((ambient * 1.6 + key * 0.9) * vec3(1.0, 0.99, 0.97));
				sky = mix(sky, lit_cloud, cloud * river_cloud_mirror);
			}
		}
		float fres = river_fresnel.x + (1.0 - river_fresnel.x) * pow(1.0 - max(dot(eye, calm), 0.0), river_fresnel.y);
		fres = clamp(fres * (1.0 + sl * river_slick.z), 0.0, 1.0);
		vec3 disp = mix(zs_scene_to_display(water), sky, fres * (1.0 - skin) * (1.0 - pad));
		vec4 path = zs_lake_glint(refl, zs_sun_direction, zs_moon_direction, zs_celestial_clear, 0.0, 1.0);
		disp = mix(disp, path.rgb, path.a * (1.0 - shaded) * (1.0 - skin) * (1.0 - pad));
		float spark = smoothstep(0.9993, 0.99955, dot(reflect(-eye, wn), zs_sun_direction)) * (0.0025 / (0.0025 + rough));
		spark *= zs_celestial_clear * smoothstep(-0.03, 0.12, zs_sun_direction.y) * (1.0 - shaded) * (1.0 - skin) * (1.0 - pad);
		vec3 warm_c = zs_glint(mix(vec3(1.0, 0.62, 0.35), vec3(1.0, 0.98, 0.9), smoothstep(0.02, 0.5, zs_sun_direction.y)));
		disp = mix(disp, warm_c, clamp(spark, 0.0, 1.0));
		if (peak_tarn.w > 0.5) disp = mix(disp, peak_tarn_water(p, eye, r_fp, t, ambient, key, shaded), peak_tarn_in(p.xz));
		vec3 water_em = scene_linear_for_display(clamp(disp, vec3(0.0), vec3(1.0)));
		ALBEDO = mix(ALBEDO, vec3(0.0), wet);
		SPECULAR = mix(SPECULAR, 0.0, wet);
		EMISSION = mix(EMISSION, water_em, wet);
		if (live_dbg.x >= 0.0) EMISSION = mix(EMISSION, live_dbg, wet);
	}
	// The haze, with its height term (shaders/endless_height_haze.gdshaderinc).
	vec4 land_haze = zs_land_haze(VERTEX, world_position.y, INV_VIEW_MATRIX);
	// The basalt stands in the towers' own haze (their PAINT's haze_height).
	if (pk_dark > 0.0) {
		float land_up = smoothstep(haze_height.x, haze_height.x + haze_height.y, over + haze_height.w);
		float dark_up = smoothstep(PEAK_BASALT_HAZE.x, PEAK_BASALT_HAZE.y, over + haze_height.w);
		land_haze.a *= mix(1.0, (1.0 - dark_up * PEAK_BASALT_HAZE.z) / max(1.0 - land_up * haze_height.z, 0.01), pk_dark);
	}
	FOG = land_haze;
}
