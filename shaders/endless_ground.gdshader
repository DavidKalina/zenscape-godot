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
#include "res://shaders/endless_patch.gdshaderinc"
#include "res://shaders/endless_rock.gdshaderinc"
// The grass's ring distance (scripts/endless/endless_grass.gd), for where
// its tufts and flowers give way to paint.
#include "res://shaders/endless_ring.gdshaderinc"
// The underside the wind flips into view, as the tufts show it.
#include "res://shaders/grass_silver.gdshaderinc"
#include "res://shaders/grass_react.gdshaderinc"
// The rivers' water (scripts/endless/land_field.gd `_river`): drawn as the
// sea is (its sky, display and glint helpers).
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_tonemap.gdshaderinc"
#include "res://shaders/reference_lake_glint.gdshaderinc"
global uniform vec3 zs_palette_water;

// Rock round: the painted rock (shaders/endless_rock.gdshaderinc); true is
// the earlier smooth banded rock.
uniform bool old_rock = false;
uniform float sea_y = -40.0;
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
// full), its normal's up past `turf_slope`, thinning out over `turf_high`.
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
uniform vec3 carpet_tone_top = vec3(1.0);
uniform vec3 carpet_tone_low = vec3(1.0);
uniform vec2 turf_beach = vec2(2.55, 2.9);
uniform vec2 turf_slope = vec2(0.905, 0.95);
uniform vec2 turf_high = vec2(36.0, 58.0);
// The carpet's grain painted past its tufts (their speckle and gaps, at
// their size, kept until a pixel is about that size), its strength.
uniform float carpet_grain : hint_range(0.0, 2.0) = 0.6;
uniform vec2 carpet_grain_sizes = vec2(0.75, 1.5);
// The share of the velvet sheen the carpet's turf gives up.
uniform float carpet_velvet_cut : hint_range(0.0, 1.0) = 0.6;
// The night's grade (studies/celestial.gd `night_grade`, which the isles'
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
// darker over `.y` m; the pale line at the water's edge (m wide).
uniform vec2 river_bank = vec2(3.5, 1.4);
uniform float river_edge = 0.55;
// The water's level over the sea under which the sea takes it (the mouth).
uniform float river_mouth = 0.35;
// The banks in the mirror: from reflected rays this high (.x) to this
// low (.y), this much of them.
uniform vec3 river_shore_mirror = vec3(0.28, 0.04, 0.7);
// The current's pale streaks down the flow (0 none).
uniform float river_streaks = 1.0;
// How much of the cloud field the water mirrors (the sea's cloud_mirror).
uniform float river_cloud_mirror = 0.8;
// The ripples' faces lit toward the sun (the sea's body_shade).
uniform float river_body_shade = 1.0;

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
// The river (land_stream's CUSTOM1) and its flow (CUSTOM0.zw, m/s).
varying vec3 river;
varying vec2 river_flow;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// The vertex colour is sRGB; its alpha the meadow.
	land_colour = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a);
	land_carve = CUSTOM0.xy;
	river = CUSTOM1.xyz;
	river_flow = (CUSTOM0.zw * 2.0 - 1.0) * 4.0;
	// The river's water drawn flat at its level: the grid's bed under it
	// lifted (the land's own heights, its colliders, keep the bed).
	if (river_on > 0.5 && CUSTOM1.y > 0.05 && abs(CUSTOM1.x) < CUSTOM1.y + 1.0 && CUSTOM1.z - sea_y > river_mouth) {
		float lift = CUSTOM1.z - world_position.y;
		if (lift > 0.0 && lift < 3.0) {
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

void fragment() {
	vec3 p = world_position;
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
	vec2 gxz = p.xz + shear * vec2(p.y * 0.8, p.y * 0.55);
	fp = max(fp, fp3 * shear);
	float over = p.y - sea_y;
	float meadow = clamp(land_colour.a, 0.0, 1.0);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - p);

	// --- The river: its water and banks, per pixel from the distance to its
	// line (crisp on any chunk), with a slightly ragged edge near the eye.
	float r_s = abs(river.x);
	float r_w = abs(river.y);
	float r_here = river_on * step(0.05, r_w);
	float r_aa = clamp(fwidth(river.x), 0.02, 40.0) * 0.6;
	float r_ragged = (zs_noise(p.xz / 3.3) - 0.5) * 0.9 * (1.0 - smoothstep(0.5, 2.0, fp));
	// How far outside the water's edge (m; negative in the water).
	float r_out = r_s - r_w + r_ragged;
	float wet = r_here * smoothstep(river_mouth, river_mouth + 0.3, river.z - sea_y) * (1.0 - smoothstep(-r_aa, r_aa, r_out));
	// The bank's width swings along the river: a wide bar of sand and stones
	// here, the turf down to a muddy lip there.
	// (endless_patch's noise, which the grass mirrors (EndlessPatch.river_bank),
	// so the tufts stop where the stones start.)
	float bank_w = river_bank.x * mix(0.2, 1.6, smoothstep(0.32, 0.68, ep_noise(p.xz / 70.0 + 11.0) * 0.75 + ep_noise(p.xz / 17.0 + 5.0) * 0.25));
	float banked = r_here * (1.0 - smoothstep(bank_w * 0.55, bank_w + r_aa, r_out + (zs_noise(p.xz / 6.1 + 3.0) - 0.5) * 2.0 * min(bank_w, 2.5) * (1.0 - smoothstep(1.0, 4.0, fp))));

	// --- The grass carpet ---------------------------------------------------
	// Patches over every scale: the broad drift (hue) across hundreds of
	// metres, then light and deep patches down to tufts a metre across.
	// The scales from 8 m up on the patch noise the tufts read too
	// (scripts/endless/endless_patch.gd mirrors this).
	float vast = ep_fade(gxz + vec2(311.0, 97.0), 900.0, fp);
	float broad = ep_fade(gxz + vec2(71.0, 13.0), 260.0, fp);
	float wide = ep_fade(gxz + vec2(5.0, 211.0), 70.0, fp);
	float mid = ep_fade(gxz + vec2(133.0, 41.0), 19.0, fp);
	float fine = zs_fade(gxz + vec2(17.0, 3.0), 5.5, fp);
	float tuft = zs_fade(gxz + vec2(9.0, 29.0), 1.4, fp);
	// Patches with an edge: clover and lush hollows among the lighter grass.
	float clump = ep_patch(gxz + vec2(57.0, 19.0), 34.0, fp) * 0.7 + ep_patch(gxz + vec2(3.0, 77.0), 8.0, fp) * 0.5;
	float sunny = clamp((broad * 1.3 + wide * 1.5 + mid * 0.9 + fine * 0.6 + tuft * 0.8 + clump * 0.9) * patch_strength, -1.0, 1.0);
	vec3 grass = mix(GREEN, sunny > 0.0 ? SUNLIT : DEEP * 0.82, abs(sunny));
	// The meadows lusher and brighter.
	grass = mix(grass, MEADOW * (1.0 + mid * 0.5), meadow * 0.75);
	// Warm and cool drift, mostly with the broad light.
	float warm = clamp(broad * 2.4 + vast * 1.8, -1.0, 1.0) * patch_strength;
	grass *= mix(vec3(1.0), warm > 0.0 ? vec3(1.32, 1.05, 0.62) : vec3(0.80, 0.97, 1.16), abs(warm) * 0.5);
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
	// High ground goes to a tundra's browner turf.
	float alpine = smoothstep(42.0, 78.0, over + broad * 30.0);
	grass = mix(grass, TUNDRA * (1.0 + mid * 0.6), alpine * 0.8);
	// Steep turf thins to a dry olive.
	float thin = smoothstep(thin_up, rock_up, n.y);
	grass = mix(grass, OLIVE * (1.0 + fine), thin * 0.7);
	// Slopes turned to the sun warmer and lighter, turned away deeper.
	vec2 to_sun = zs_sun_direction.xz / max(length(zs_sun_direction.xz), 0.001);
	float facing = clamp(dot(n.xz, to_sun) * 2.5, -1.0, 1.0) * smoothstep(-0.05, 0.2, zs_sun_direction.y);
	grass *= mix(vec3(1.0), facing > 0.0 ? vec3(1.10, 1.05, 0.86) : vec3(0.90, 0.95, 1.02), abs(facing) * 0.5);

	// The wind: two trains of crests rolling downwind on the air's travel
	// (grass_look's crest), the grass bowed there showing its paler side;
	// far off the crests fade to their mean, a faint sheen.
	float crest_near = zs_grass_crest(gxz, wave_lengths.x, ZS_GRASS_WAVE_SPEED, zs_grass_offset);
	float crest_far = zs_grass_crest(gxz * 0.97 + 50.0, wave_lengths.y, ZS_GRASS_WAVE_SPEED * 1.3, zs_grass_offset + 7.0);
	crest_near = mix(0.35, crest_near, 1.0 - smoothstep(wave_lengths.x * 0.08, wave_lengths.x * 0.3, fp));
	crest_far = mix(0.35, crest_far, 1.0 - smoothstep(wave_lengths.y * 0.08, wave_lengths.y * 0.3, fp));
	float air = clamp(zs_wind_strength, 0.0, 2.0);
	float crest = (crest_near * 0.35 + crest_far * 0.65) * air * wind_sheen;
	// Velvet: turf seen low catches the light along its blades.
	float grazing = pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 2.0);
	// (The carpet's tufts catch no velvet: past them its paint keeps less.)
	float carpet_turf = smoothstep(turf_slope.x, turf_slope.y, n.y) * (1.0 - smoothstep(turf_high.x, turf_high.y, over))
		* smoothstep(turf_beach.x, turf_beach.y, over);
	// No carpet on a river's bank or in its water.
	carpet_turf *= 1.0 - max(banked, wet);
	float sheen = crest * (0.35 + 0.65 * grazing) + velvet * grazing * 0.6 * (1.0 - carpet_velvet_cut * carpet_turf);
	vec3 sheen_colour = mix(grass, vec3(luma(grass)) * vec3(1.25, 1.22, 0.85), 0.55) * 1.55;
	grass = mix(grass, sheen_colour, clamp(sheen * 0.42, 0.0, 0.8) * (1.0 - thin * 0.6));
	// The carpet's tone past its tufts, and wherever none grow.
	float turf = carpet_turf;
	float beyond = carpet_reach.y > 0.0 ? clamp((endless_ring_d(CAMERA_POSITION_WORLD, p) - carpet_reach.x) / max(carpet_reach.y - carpet_reach.x, 1.0), 0.0, 1.0) : 1.0;
	float toned = mix(1.0, beyond, turf);
	grass *= mix(vec3(1.0), mix(carpet_tone_low, carpet_tone_top, smoothstep(0.12, 0.6, eye.y)), toned);
	float speck_a = smoothstep(0.3, 0.7, zs_noise(turned_speck(gxz, 0) / carpet_grain_sizes.x)) - 0.5;
	float speck_b = smoothstep(0.3, 0.7, zs_noise(turned_speck(gxz, 1) / carpet_grain_sizes.y)) - 0.5;
	float speck = speck_a * (1.0 - smoothstep(carpet_grain_sizes.x * 0.5, carpet_grain_sizes.x * 1.2, fp))
		+ speck_b * 0.7 * (1.0 - smoothstep(carpet_grain_sizes.y * 0.5, carpet_grain_sizes.y * 1.2, fp));
	// Only off where tufts would be pixels: near, the paint's own grain.
	grass *= 1.0 + speck * carpet_grain * turf * beyond * smoothstep(40.0, 110.0, length(CAMERA_POSITION_WORLD - p));

	// --- Rock, sand, snow -----------------------------------------------------
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
	// Its beds: bands by height, waved, hard pale ones among dark.
	float bed_y = p.y + sin(p.x * 0.013 + p.z * 0.008) * 6.0 + (zs_noise(gxz / 40.0) - 0.5) * 8.0;
	float bed = zs_noise(vec2(bed_y / 3.5, 0.5));
	float grain = zs_fade(gxz + p.y, 2.2, fp) + zs_fade(p.zx + p.y * 0.7, 11.0, fp);
	vec3 rock = mix(ROCK, ROCK_PALE, smoothstep(0.35, 0.75, bed) * 0.8) * (1.0 + grain * 0.5);
	rock *= mix(vec3(1.0), vec3(1.10, 1.0, 0.86), clamp(broad * 2.0 + 0.5, 0.0, 1.0) * 0.6);
	// Ledges lying back hold a little turf.
	rock = mix(rock, grass * 0.8, smoothstep(0.62, 0.74, n.y) * 0.35);
	vec3 lit_n = n;
	vec3 rock_glow = vec3(0.0);
	if (!old_rock && rocky > 0.002) {
		rock = er_rock(p, n, fp3, zs_sun_direction, grass * 0.85, land_carve, lit_n, rock_glow);
		lit_n = normalize(mix(n, lit_n, rocky));
	}

	// The beach: a strip at the water, wider in bays (the meadows' flats
	// stand MEADOW_ABOVE over the sea, and stay turf).
	float sand_edge = (zs_noise(gxz / 7.0) - 0.5) * 0.7 + wide * 0.8 + fine * 0.3;
	float sand_soft = 0.08 + min(fp * 0.2, 0.4);
	float sandy = 1.0 - smoothstep(beach * 0.7 - sand_soft, beach * 0.7 + sand_soft, over + sand_edge);
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
		damp = 1.0 - smoothstep(0.0, river_bank.y, r_out);
		bank_c = mix(bank_c, SAND_WET * 0.85, damp * 0.85);
	}

	float snow_edge = (zs_noise(gxz / 23.0) - 0.5) * 16.0 + mid * 10.0;
	float snowy = smoothstep(snow_line - 14.0, snow_line + 2.0, over + snow_edge)
		* smoothstep(0.55, 0.72, n.y + rock_edge);
	vec3 snow = SNOW * (1.0 + fine * 0.06);

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
		float under = carpet_turf * (1.0 - smoothstep(carpet_near.x, carpet_near.y, endless_ring_d(CAMERA_POSITION_WORLD, p)));
		if (under > 0.0) {
			float sunny_c = clamp((broad * 1.3 + wide * 1.5 + mid * 0.9 + clump * 0.9) * patch_strength, -1.0, 1.0);
			vec3 coarse = mix(GREEN, sunny_c > 0.0 ? SUNLIT : DEEP * 0.82, abs(sunny_c));
			coarse = mix(coarse, MEADOW * (1.0 + mid * 0.5), meadow * 0.75);
			coarse *= mix(vec3(1.0), warm > 0.0 ? vec3(1.32, 1.05, 0.62) : vec3(0.80, 0.97, 1.16), abs(warm) * 0.5);
			coarse *= region;
			coarse = mix(coarse, vc / max(luma(vc), 0.01) * luma(coarse), vertex_hue * 0.6);
			float dry_c = clamp(0.18 * 0.6 + dry_far * 0.55, 0.0, 1.0) * (1.0 - meadow * 0.6);
			coarse = mix(coarse, DRY, dry_c * 0.4);
			coarse = mix(coarse, TUNDRA * (1.0 + mid * 0.6), alpine * 0.8);
			coarse = mix(coarse, OLIVE, thin * 0.7);
			coarse *= 1.0 + (grain_near + fine * 0.6 + tuft * 0.8) * carpet_near_grain;
			grass = mix(grass, coarse, under);
		}
	}
	// The grass's silvery underside where the breeze bows it (grass_silver,
	// off by default): the tufts' own bands, carried on over the paint.
	if (grass_silver.x > 0.0) grass = zs_silver_paint(grass, zs_silver_drive(gxz, fp), 1.0 - thin * 0.6, 0.8);
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
			float past = smoothstep(bloom_fade.x, bloom_fade.y, d);
			float cut = 0.78 - 0.3 * bloom_w;
			float dot_a = smoothstep(cut, cut + 0.06, zs_noise(turned_speck(gxz, 0) / bloom_dots.x));
			float dot_b = smoothstep(cut, cut + 0.06, zs_noise(turned_speck(gxz + 7.3, 1) / bloom_dots.y));
			float dots = max(dot_a, dot_b);
			// Their mean as the pixel outgrows a head.
			dots = mix(dots, bloom_w * 0.42, smoothstep(bloom_dots.x * 0.4, bloom_dots.y * 1.2, fp));
			float wash = mix(bloom_wash.x * bloom_w, bloom_wash.y * dots, past);
			grass = mix(grass, ep_wash(int(bloom.y + 0.5)), clamp(wash, 0.0, 1.0));
		}
	}
	// Stirred by the wash, the walker or a gust (grass_react).
	grass = zs_react_paint(grass, p.xz, CAMERA_POSITION_WORLD.xz - p.xz, carpet_turf * (grass_silver.x > 0.0 ? ZS_SILVER_REACT_PALE : 1.0));
	vec3 albedo = mix(grass, rock, rocky);
	albedo = mix(albedo, sand, sandy * (1.0 - rocky * 0.5));
	albedo = mix(albedo, bank_c, banked * (1.0 - rocky * 0.7));
	albedo = mix(albedo, snow, snowy);
	albedo = mix(albedo, vec3(luma(albedo)) * night_grade.yzw, night_grade.x);
	// Under a cloud's shadow the sun's share goes (the albedo the sun
	// lights), the sky's fill (the emission below) stays.
	float shade = zs_cloud_volume_shade(p);
	float shaded = shade * cloud_shade;
	ALBEDO = albedo * (1.0 - shaded);
	float wet_sand = max(sandy * smoothstep(0.7, 0.0, over) * step(-0.5, over), damp * banked);
	ROUGHNESS = mix(mix(mix(0.92, 0.82, rocky), 0.6, snowy), 0.35, wet_sand);
	SPECULAR = mix(mix(0.25, 0.35, rocky), 0.5, max(snowy, wet_sand)) * (1.0 - shaded);
	NORMAL = normalize((VIEW_MATRIX * vec4(lit_n, 0.0)).xyz);
	// The hemisphere fill, as the isles' surfaces take it (environment
	// ambient is off under LandscapeLighting).
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float hollow = 0.85 + 0.15 * n.y;
	// A cloud overhead takes a little of the sky's fill too.
	EMISSION = albedo * hemi * hollow * (1.0 - 0.2 * shade) + rock_glow * rocky * (1.0 - snowy);
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
		float speed = max(spd, 0.12);
		vec2 slope = vec2(0.0);
		float rough = 0.0;
		float k0 = 1.0 - smoothstep(river_ripple_size.x * 0.04, river_ripple_size.x * 0.22, fp);
		float k1 = 1.0 - smoothstep(river_ripple_size.y * 0.04, river_ripple_size.y * 0.22, fp);
		float k2 = 1.0 - smoothstep(river_ripple_size.z * 0.04, river_ripple_size.z * 0.22, fp);
		if (k0 > 0.0) slope += zs_river_layer(river_detail_a, p.xz, dir, speed * 0.85, river_ripple_size.x, 0.0, t) * river_ripple_strength.x * k0;
		if (k1 > 0.0) slope += zs_river_layer(river_detail_b, p.xz, dir, speed, river_ripple_size.y, 0.37, t) * river_ripple_strength.y * k1;
		if (k2 > 0.0) slope += zs_river_layer(river_detail_a, p.xz + 17.0, dir, speed * 1.15, river_ripple_size.z, 0.71, t) * river_ripple_strength.z * k2;
		rough = river_ripple_strength.x * river_ripple_strength.x * (1.0 - k0) + river_ripple_strength.y * river_ripple_strength.y * (1.0 - k1)
			+ river_ripple_strength.z * river_ripple_strength.z * (1.0 - k2);
		vec3 wn = normalize(vec3(-slope.x, 1.0, -slope.y));
		vec3 calm = normalize(vec3(-slope.x * river_calm, 1.0, -slope.y * river_calm));
		float d_in = max(-r_out, 0.0);
		float depth = min(d_in * river_depth.x, river_depth.y);
		vec3 column = mix(river_tint_shallow, river_tint_mid, smoothstep(0.0, river_tint_depths.x, depth));
		column = mix(column, river_tint_deep, smoothstep(river_tint_depths.x * 0.5, river_tint_depths.y, depth));
		column *= zs_palette_water;
		vec3 ambient = zs_hemi_sky * zs_hemi_energy / PI;
		vec3 key = zs_key_irradiance * max(zs_key_direction.y, 0.0) / PI;
		vec3 light = (ambient + key * 0.8) * river_light;
		float through = depth / max(abs(eye.y), 0.15);
		vec3 seen = exp(-river_absorb * through) * exp(-depth / river_bed_fade);
		vec3 bed_c = mix(SAND * 0.75, ROCK_PALE, 0.35) * (ambient * 0.9 + key);
		vec3 water = column * light * (vec3(1.0) - seen) + bed_c * seen;
		// The current: faint pale streaks drawn out down the flow, drifting
		// with it (two copies cross-faded as the ripples), gone far off.
		float streak_keep = (1.0 - smoothstep(0.4, 2.5, fp)) * river_streaks;
		if (streak_keep > 0.0) {
			vec2 across_f = vec2(-dir.y, dir.x);
			float cyc = river_cycle * 2.0;
			float c0 = t / cyc, c1 = c0 + 0.5;
			float f0 = fract(c0), f1 = fract(c1);
			vec2 q0 = p.xz - dir * speed * cyc * f0 + vec2(floor(c0) * 7.3, 0.0);
			vec2 q1 = p.xz - dir * speed * cyc * f1 + vec2(0.0, floor(c1) * 5.1);
			// The chop's smooth noise (not the value noise, whose cells show
			// when drawn out this far).
			float n0 = texture(river_detail_b, vec2(dot(q0, dir) / 60.0, dot(q0, across_f) / 6.0)).x;
			float n1 = texture(river_detail_b, vec2(dot(q1, dir) / 60.0, dot(q1, across_f) / 6.0) + 0.37).x;
			float w0 = 1.0 - abs(2.0 * f0 - 1.0);
			float streak = mix(n1, n0, w0);
			float lines = smoothstep(0.58, 0.75, streak) * (0.4 + 0.6 * smoothstep(0.0, 3.0, d_in));
			water = mix(water, column * light * 1.45 + vec3(0.02), lines * 0.22 * streak_keep);
		}
		// The ripples' faces: lighter toward the sun, darker away (the
		// sea's body_shade), so the chop reads where the mirror is dim.
		water *= 1.0 + clamp(dot(slope, -normalize(zs_sun_direction.xz + vec2(1e-4))) * 2.5, -0.45, 0.45) * river_body_shade;
		water *= 1.0 - 0.4 * shaded;
		// The pale line at the edge, lapping, broken; far off a soft rim.
		float lap = river_edge * (0.6 + 0.4 * zs_noise(p.xz / 23.0)) * (0.85 + 0.15 * sin(t * 0.8 + zs_noise(p.xz * 0.15) * 6.2832)) + fp * 0.5;
		float line = (1.0 - smoothstep(0.0, lap, d_in)) * mix(0.25 + 0.3 * zs_noise(p.xz * 0.35 - dir * t * 0.3), 0.3, smoothstep(0.3, 1.5, fp));
		vec3 white = vec3(0.9, 0.96, 1.0) * (ambient * 1.1 + key * 0.8);
		water = mix(water, white, line * 0.7);
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
		vec3 disp = mix(zs_scene_to_display(water), sky, fres * (1.0 - line));
		vec4 path = zs_lake_glint(refl, zs_sun_direction, zs_moon_direction, zs_celestial_clear, 0.0, 1.0);
		disp = mix(disp, path.rgb, path.a * (1.0 - shaded) * (1.0 - line));
		float spark = smoothstep(0.9993, 0.99955, dot(reflect(-eye, wn), zs_sun_direction)) * (0.0025 / (0.0025 + rough));
		spark *= zs_celestial_clear * smoothstep(-0.03, 0.12, zs_sun_direction.y) * (1.0 - shaded) * (1.0 - line);
		vec3 warm_c = mix(vec3(1.0, 0.62, 0.35), vec3(1.0, 0.98, 0.9), smoothstep(0.02, 0.5, zs_sun_direction.y));
		disp = mix(disp, warm_c, clamp(spark, 0.0, 1.0));
		vec3 water_em = scene_linear_for_display(clamp(disp, vec3(0.0), vec3(1.0)));
		ALBEDO = mix(ALBEDO, vec3(0.0), wet);
		SPECULAR = mix(SPECULAR, 0.0, wet);
		EMISSION = mix(EMISSION, water_em, wet);
	}
}
