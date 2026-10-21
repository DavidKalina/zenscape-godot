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

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// The vertex colour is sRGB; its alpha the meadow.
	land_colour = vec4(pow(COLOR.rgb, vec3(2.2)), COLOR.a);
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
	float over = p.y - sea_y;
	float meadow = clamp(land_colour.a, 0.0, 1.0);
	vec3 eye = normalize(CAMERA_POSITION_WORLD - p);

	// --- The grass carpet ---------------------------------------------------
	// Patches over every scale: the broad drift (hue) across hundreds of
	// metres, then light and deep patches down to tufts a metre across.
	// The scales from 8 m up on the patch noise the tufts read too
	// (scripts/endless/endless_patch.gd mirrors this).
	float vast = ep_fade(p.xz + vec2(311.0, 97.0), 900.0, fp);
	float broad = ep_fade(p.xz + vec2(71.0, 13.0), 260.0, fp);
	float wide = ep_fade(p.xz + vec2(5.0, 211.0), 70.0, fp);
	float mid = ep_fade(p.xz + vec2(133.0, 41.0), 19.0, fp);
	float fine = zs_fade(p.xz + vec2(17.0, 3.0), 5.5, fp);
	float tuft = zs_fade(p.xz + vec2(9.0, 29.0), 1.4, fp);
	// Patches with an edge: clover and lush hollows among the lighter grass.
	float clump = ep_patch(p.xz + vec2(57.0, 19.0), 34.0, fp) * 0.7 + ep_patch(p.xz + vec2(3.0, 77.0), 8.0, fp) * 0.5;
	float sunny = clamp((broad * 1.3 + wide * 1.5 + mid * 0.9 + fine * 0.6 + tuft * 0.8 + clump * 0.9) * patch_strength, -1.0, 1.0);
	vec3 grass = mix(GREEN, sunny > 0.0 ? SUNLIT : DEEP * 0.82, abs(sunny));
	// The meadows lusher and brighter.
	grass = mix(grass, MEADOW * (1.0 + mid * 0.5), meadow * 0.75);
	// Warm and cool drift, mostly with the broad light.
	float warm = clamp(broad * 2.4 + vast * 1.8, -1.0, 1.0) * patch_strength;
	grass *= mix(vec3(1.0), warm > 0.0 ? vec3(1.32, 1.05, 0.62) : vec3(0.80, 0.97, 1.16), abs(warm) * 0.5);
	// The broad regions' hue (endless_patch ep_region): lush, lime, sage,
	// straw, heather on high ground.
	vec3 region = ep_region(p.xz, over, region_amount, region_offset);
	grass *= region;
	// The land's own tint (the vertex colour's hue at the grass's light).
	vec3 vc = land_colour.rgb;
	grass = mix(grass, vc / max(luma(vc), 0.01) * luma(grass), vertex_hue * 0.6);
	// The isles' dry patches (grass_look) and broader dry ground, fading to
	// their means far off (the noise mean is about 0.5, dry from 0.5).
	float dry_near = zs_grass_dry(p.xz, ZS_GRASS_DRY_SCALE, zs_grass_offset);
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
	float crest_near = zs_grass_crest(p.xz, wave_lengths.x, ZS_GRASS_WAVE_SPEED, zs_grass_offset);
	float crest_far = zs_grass_crest(p.xz * 0.97 + 50.0, wave_lengths.y, ZS_GRASS_WAVE_SPEED * 1.3, zs_grass_offset + 7.0);
	crest_near = mix(0.35, crest_near, 1.0 - smoothstep(wave_lengths.x * 0.08, wave_lengths.x * 0.3, fp));
	crest_far = mix(0.35, crest_far, 1.0 - smoothstep(wave_lengths.y * 0.08, wave_lengths.y * 0.3, fp));
	float air = clamp(zs_wind_strength, 0.0, 2.0);
	float crest = (crest_near * 0.35 + crest_far * 0.65) * air * wind_sheen;
	// Velvet: turf seen low catches the light along its blades.
	float grazing = pow(1.0 - clamp(dot(n, eye), 0.0, 1.0), 2.0);
	// (The carpet's tufts catch no velvet: past them its paint keeps less.)
	float carpet_turf = smoothstep(turf_slope.x, turf_slope.y, n.y) * (1.0 - smoothstep(turf_high.x, turf_high.y, over))
		* smoothstep(turf_beach.x, turf_beach.y, over);
	float sheen = crest * (0.35 + 0.65 * grazing) + velvet * grazing * 0.6 * (1.0 - carpet_velvet_cut * carpet_turf);
	vec3 sheen_colour = mix(grass, vec3(luma(grass)) * vec3(1.25, 1.22, 0.85), 0.55) * 1.55;
	grass = mix(grass, sheen_colour, clamp(sheen * 0.42, 0.0, 0.8) * (1.0 - thin * 0.6));
	// The carpet's tone past its tufts, and wherever none grow.
	float turf = carpet_turf;
	float beyond = carpet_reach.y > 0.0 ? clamp((length(CAMERA_POSITION_WORLD - p) - carpet_reach.x) / max(carpet_reach.y - carpet_reach.x, 1.0), 0.0, 1.0) : 1.0;
	float toned = mix(1.0, beyond, turf);
	grass *= mix(vec3(1.0), mix(carpet_tone_low, carpet_tone_top, smoothstep(0.12, 0.6, eye.y)), toned);
	float speck_a = smoothstep(0.3, 0.7, zs_noise(turned_speck(p.xz, 0) / carpet_grain_sizes.x)) - 0.5;
	float speck_b = smoothstep(0.3, 0.7, zs_noise(turned_speck(p.xz, 1) / carpet_grain_sizes.y)) - 0.5;
	float speck = speck_a * (1.0 - smoothstep(carpet_grain_sizes.x * 0.5, carpet_grain_sizes.x * 1.2, fp))
		+ speck_b * 0.7 * (1.0 - smoothstep(carpet_grain_sizes.y * 0.5, carpet_grain_sizes.y * 1.2, fp));
	// Only off where tufts would be pixels: near, the paint's own grain.
	grass *= 1.0 + speck * carpet_grain * turf * beyond * smoothstep(40.0, 110.0, length(CAMERA_POSITION_WORLD - p));

	// --- Rock, sand, snow -----------------------------------------------------
	float rock_edge = (zs_noise(p.xz / 9.0) - 0.5) * 0.10 + mid * 0.08;
	float rocky = smoothstep(rock_up + 0.04, rock_up - 0.05, n.y + rock_edge);
	// More rock breaking through the high ground.
	rocky = max(rocky, smoothstep(0.88, 0.80, n.y + rock_edge) * alpine);
	// Its beds: bands by height, waved, hard pale ones among dark.
	float bed_y = p.y + sin(p.x * 0.013 + p.z * 0.008) * 6.0 + (zs_noise(p.xz / 40.0) - 0.5) * 8.0;
	float bed = zs_noise(vec2(bed_y / 3.5, 0.5));
	float grain = zs_fade(p.xz + p.y, 2.2, fp) + zs_fade(p.zx + p.y * 0.7, 11.0, fp);
	vec3 rock = mix(ROCK, ROCK_PALE, smoothstep(0.35, 0.75, bed) * 0.8) * (1.0 + grain * 0.5);
	rock *= mix(vec3(1.0), vec3(1.10, 1.0, 0.86), clamp(broad * 2.0 + 0.5, 0.0, 1.0) * 0.6);
	// Ledges lying back hold a little turf.
	rock = mix(rock, grass * 0.8, smoothstep(0.62, 0.74, n.y) * 0.35);

	// The beach: a strip at the water, wider in bays (the meadows' flats
	// stand MEADOW_ABOVE over the sea, and stay turf).
	float sand_edge = (zs_noise(p.xz / 7.0) - 0.5) * 0.7 + wide * 0.8 + fine * 0.3;
	float sand_soft = 0.08 + min(fp * 0.2, 0.4);
	float sandy = 1.0 - smoothstep(beach * 0.7 - sand_soft, beach * 0.7 + sand_soft, over + sand_edge);
	vec3 sand = SAND * (1.0 + fine * 0.25 + mid * 0.2);
	sand = mix(sand, SAND_WET, smoothstep(0.7, -0.1, over));
	// The seabed: the sand darkening and greying with depth.
	sand = mix(sand, SEABED * (1.0 + wide), smoothstep(-0.5, -12.0, over));

	float snow_edge = (zs_noise(p.xz / 23.0) - 0.5) * 16.0 + mid * 10.0;
	float snowy = smoothstep(snow_line - 14.0, snow_line + 2.0, over + snow_edge)
		* smoothstep(0.55, 0.72, n.y + rock_edge);
	vec3 snow = SNOW * (1.0 + fine * 0.06);

	// The turf's grain near the eye: tufts and blades too fine to draw,
	// as a speckle of light and dark that fades to nothing with the pixel.
	// Two lattices turned against each other, so no grid shows.
	vec2 turned = mat2(vec2(0.866, 0.5), vec2(-0.5, 0.866)) * p.xz;
	vec2 turned2 = mat2(vec2(0.342, -0.94), vec2(0.94, 0.342)) * p.xz;
	float grain_near = zs_fade(turned + vec2(3.3, 1.1), 0.3, fp) * 0.8 + zs_fade(turned2 + vec2(41.0, 7.0), 0.55, fp) * 0.7
		+ zs_fade(p.xz + vec2(9.0, 2.0), 1.3, fp) * 0.5;
	grass *= 1.0 + grain_near * (1.0 - thin * 0.4);
	// Under the near carpet: the tufts' own ground (endless_patch.gd `grass`).
	if (carpet_near.y > 0.0) {
		float under = carpet_turf * (1.0 - smoothstep(carpet_near.x, carpet_near.y, length(CAMERA_POSITION_WORLD - p)));
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
	// The flower drifts past the drawn flowers: heads of their colour dotted
	// over the turf (two lattices, more of them at a drift's heart), which
	// average to a wash of it as a pixel grows past a head; a light wash
	// under the drawn flowers. On open turf only.
	// Gone where a pixel is wider than a small patch's share (the horizon),
	// so it doesn't shimmer.
	float bloom_on = carpet_turf * (1.0 - smoothstep(4.0, 12.0, fp));
	if (bloom_amount > 0.0 && bloom_on > 0.0) {
		vec2 bloom = ep_bloom(p.xz, bloom_amount, region_offset);
		float bloom_w = bloom.x * bloom_on;
		if (bloom_w > 0.0) {
			float d = length(CAMERA_POSITION_WORLD - p);
			float past = smoothstep(bloom_fade.x, bloom_fade.y, d);
			float cut = 0.78 - 0.3 * bloom_w;
			float dot_a = smoothstep(cut, cut + 0.06, zs_noise(turned_speck(p.xz, 0) / bloom_dots.x));
			float dot_b = smoothstep(cut, cut + 0.06, zs_noise(turned_speck(p.xz + 7.3, 1) / bloom_dots.y));
			float dots = max(dot_a, dot_b);
			// Their mean as the pixel outgrows a head.
			dots = mix(dots, bloom_w * 0.42, smoothstep(bloom_dots.x * 0.4, bloom_dots.y * 1.2, fp));
			float wash = mix(bloom_wash.x * bloom_w, bloom_wash.y * dots, past);
			grass = mix(grass, ep_wash(int(bloom.y + 0.5)), clamp(wash, 0.0, 1.0));
		}
	}
	vec3 albedo = mix(grass, rock, rocky);
	albedo = mix(albedo, sand, sandy * (1.0 - rocky * 0.5));
	albedo = mix(albedo, snow, snowy);
	albedo = mix(albedo, vec3(luma(albedo)) * night_grade.yzw, night_grade.x);
	// Under a cloud's shadow the sun's share goes (the albedo the sun
	// lights), the sky's fill (the emission below) stays.
	float shade = zs_cloud_volume_shade(p);
	float shaded = shade * cloud_shade;
	ALBEDO = albedo * (1.0 - shaded);
	float wet = sandy * smoothstep(0.7, 0.0, over) * step(-0.5, over);
	ROUGHNESS = mix(mix(mix(0.92, 0.82, rocky), 0.6, snowy), 0.35, wet);
	SPECULAR = mix(mix(0.25, 0.35, rocky), 0.5, max(snowy, wet)) * (1.0 - shaded);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// The hemisphere fill, as the isles' surfaces take it (environment
	// ambient is off under LandscapeLighting).
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, n.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float hollow = 0.85 + 0.15 * n.y;
	// A cloud overhead takes a little of the sky's fill too.
	EMISSION = albedo * hemi * hollow * (1.0 - 0.2 * shade);
}
