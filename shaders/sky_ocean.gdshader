shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, unshaded, shadows_disabled;
// The lower world's ocean (scripts/sky_below.gd `ocean`): a sea seen mostly
// from a plane's height, so most of the screen when flying low. Its own
// shader, not the islands' pond water (shaders/reference_water_body
// .gdshaderinc), which is drawn for ponds seen from a few metres: every
// island pond, lake and the plate's water stay as they were.
//
// Smooth and glassy, never faceted. The surface's normal is worked out per
// pixel from the waves themselves, not from the sheet's facets, and every
// wave fades out where it is finer than a pixel can hold (`zs_sea_waves`),
// so the far sea never shimmers into a checker; what fades out of a wave
// roughens the sea's sheen instead, so the far water is a soft glitter and
// not a flat mirror. The sheet only heaves to the long swell, and only near
// the eye where its cells can hold it.
//
// Three scales of water: a long swell from afar, the wind's chop over it
// (fixed headings round the compass, each as strong as it lies downwind,
// so a turning wind reweights them and nothing slides), and fine ripples.
// The chop stands up where the air is hard: cat's paws, broad patches
// rolling downwind on the air's own travel (zs_gust_distance), dark and
// rough on a glassy sea, and smooth slicks drawn out along the wind.
//
// Colour comes from the water between the surface and the bed behind each
// pixel, read from the depth buffer: the bed shows through by the length of
// water the eye looks through (so a cliff plunging into the sea is seen
// through hundreds of metres of water, not as a dark band at its foot), and
// the water's own colour runs from luminous turquoise over a shelf to deep
// blue off it. Where the water meets the land it lightens to a bright lip,
// foams, and waves wash in over the shelf toward it.
//
// It mirrors the sky above at grazing angles (fresnel): the overcast's pearl
// with a share of the hour's colour, and what stands on screen (the
// islands, the ranges, the cloud's underside) by a short march through the
// depth buffer (`mirror_steps`), softened as the water roughens.
//
// It writes depth, so the display haze (studies/display_fog.gd) hazes the
// water by its own distance rather than by the bed behind it.
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_tonemap.gdshaderinc"
#include "res://shaders/reference_lake_lighting.gdshaderinc"
#include "res://shaders/reference_lake_glint.gdshaderinc"
global uniform vec3 zs_palette_water;
uniform sampler2D sea_screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D sea_depth : hint_depth_texture, filter_nearest, repeat_disable;

// The water's colour as seen from above by depth (m): luminous turquoise
// over a shelf, a clear teal by depths.x, deep blue by depths.y, and the
// abyss's dark blue by depths.z.
uniform vec3 tint_shallow : source_color = vec3(0.30, 0.86, 0.80);
uniform vec3 tint_mid : source_color = vec3(0.10, 0.56, 0.62);
uniform vec3 tint_deep : source_color = vec3(0.04, 0.26, 0.42);
uniform vec3 tint_abyss : source_color = vec3(0.03, 0.14, 0.25);
uniform vec3 tint_depths = vec3(1.6, 5.0, 9.5);
// How fast the water swallows the bed (per metre of water looked through,
// red, green, blue): red first, so a sandy shelf shows through turquoise.
uniform vec3 absorb = vec3(0.30, 0.075, 0.06);
// The swell's heading (world xz) and its strength, and the chop's.
uniform vec2 swell_heading = vec2(0.8, 0.6);
uniform float swell = 1.0;
uniform float chop = 1.0;
// The sheet heaves to the swell out to heave_reach.x (m from the eye) and
// lies flat by heave_reach.y, where its cells grow too coarse to hold it.
uniform vec2 heave_reach = vec2(90.0, 150.0);
// The cat's paws' scale (m along the wind, across it) and their strength.
uniform vec2 paw_size = vec2(90.0, 55.0);
uniform float paws = 1.0;
// The shore: the depth (m) the foam keeps to, the wash's reach out over
// the shelf (m deep) and how strong each is.
uniform float shore_foam = 0.18;
uniform float wash_depth = 1.4;
uniform float foam = 1.0;
// The mirror's march: steps along the reflected ray (0 off), the first
// step's length (m) and how much each grows.
uniform int mirror_steps = 12;
uniform vec2 mirror_march = vec2(2.5, 1.55);
// How much of the hour's colour the pearl overcast lends the mirror.
uniform float sky_warmth = 0.55;
// 1 under the cloud sea: the sky mirrored is the overcast (zsBelowAir).
uniform float below_sky = 1.0;
// How much of the sun's and moon's path shows through the overcast.
uniform float glint_share = 0.35;
// How bright the water's own colour is lit, over the sky's and key's light.
uniform float water_light = 2.6;
// The depth (m) over which the bed fades from sight, on top of the water
// looked through: an island's shelf (SkyArchipelago SHELF_DEPTH) is gone
// well before its foot.
uniform float bed_fade = 3.2;

varying vec3 world_position;
varying vec2 rest_xz;

const int SWELLS = 3;
const int CHOPS = 12;
const float GRAVITY = 9.81;

// The waves' slope at `p` (world xz, its gradient), summed over the swell
// and the chop, each wave faded out where it is finer than `footprint` (m a
// pixel, or a cell in the sheet); `rough` gathers the mean square slope the
// faded waves leave out, `height` the surface's rise. `air` is the chop's
// strength there (cat's paws and slicks in).
vec2 zs_sea_waves(vec2 p, float t, float footprint, float air, out float rough, out float height) {
	vec2 slope = vec2(0.0);
	rough = 0.0;
	height = 0.0;
	vec2 heading = normalize(swell_heading);
	vec2 wind = zs_wind_direction;
	// The swell: long, gentle, from afar.
	const float SWELL_LENGTH[3] = float[3](38.0, 23.0, 14.5);
	const float SWELL_TURN[3] = float[3](0.0, 0.42, -0.31);
	const float SWELL_STEEP[3] = float[3](0.05, 0.045, 0.04);
	for (int i = 0; i < SWELLS; i++) {
		float c = cos(SWELL_TURN[i]), s = sin(SWELL_TURN[i]);
		vec2 d = vec2(c * heading.x - s * heading.y, s * heading.x + c * heading.y);
		float k = TAU / SWELL_LENGTH[i];
		float steep = SWELL_STEEP[i] * swell * (0.6 + 0.4 * min(zs_wind_strength, 1.5));
		float held = 1.0 - smoothstep(SWELL_LENGTH[i] * 0.06, SWELL_LENGTH[i] * 0.18, footprint);
		float phase = dot(p, d) * k - sqrt(GRAVITY * k) * t + float(i) * 1.7;
		slope += d * steep * cos(phase) * held;
		height += steep / k * sin(phase) * held;
		rough += 0.5 * steep * steep * (1.0 - held * held);
	}
	// The chop: headings round the compass by the golden angle, each as
	// strong as it lies downwind; shorter waves are steeper.
	// Their crests are bent by two slow warps, the even waves by one and
	// the odd by the other, so none runs straight for long and no two keep
	// in step to beat into rings or a lattice.
	vec2 w0 = p + vec2(sin(p.y * 0.071 + t * 0.13), sin(p.x * 0.083 - t * 0.1)) * 3.4
		+ vec2(sin(p.y * 0.29 - p.x * 0.11 - t * 0.3), sin(p.x * 0.31 + p.y * 0.13 + t * 0.27)) * 1.1;
	vec2 w1 = p + vec2(sin(p.x * 0.067 - p.y * 0.03 - t * 0.11), sin(p.y * 0.077 + t * 0.12)) * 3.1
		+ vec2(sin(p.x * 0.33 + p.y * 0.17 + t * 0.25), sin(p.y * 0.27 - p.x * 0.09 - t * 0.31)) * 1.2;
	// And they come in short packets, not endless trains: two patchy fields
	// drifting downwind gate each wave, so a glint off them breaks into
	// glitter rather than stripes.
	float packet_a = zs_noise((p - wind * t * 0.6) * 0.45);
	float packet_b = zs_noise((p - wind * t * 0.8) * 0.33 + vec2(19.1, 7.3));
	const float CHOP_LENGTH[12] = float[12](7.4, 5.3, 4.6, 3.3, 2.75, 2.05, 1.7, 1.3, 1.08, 0.83, 0.69, 0.52);
	for (int i = 0; i < CHOPS; i++) {
		float len = CHOP_LENGTH[i];
		vec2 w = (i % 2 == 0) ? w0 : w1;
		float angle = float(i) * 2.39996 + sin(float(i) * 7.1) * 0.3;
		vec2 d = vec2(cos(angle), sin(angle));
		float downwind = smoothstep(-0.25, 0.85, dot(d, wind));
		float k = TAU / len;
		float packet = smoothstep(0.2, 0.8, mix(packet_a, packet_b, fract(float(i) * 0.618)));
		float steep = (0.05 + 0.05 * float(i) / float(CHOPS)) * downwind * air * mix(1.0, packet * 1.6, float(i) / float(CHOPS - 1));
		float held = 1.0 - smoothstep(len * 0.06, len * 0.18, footprint);
		float phase = dot(w, d) * k - sqrt(GRAVITY * k) * t + float(i) * 2.1;
		slope += d * steep * cos(phase) * held;
		rough += 0.5 * steep * steep * (1.0 - held * held);
	}
	return slope;
}

// How hard the wind works the sea at `p`, 0 glassy to about 2: the breeze,
// raised in cat's paws rolling downwind on the air's travel and calmed in
// slicks drawn out along it. `paw` is the paw's own share, 0 to 1.
float zs_sea_air(vec2 p, out float paw) {
	vec2 dir = zs_wind_direction;
	vec2 across = vec2(-dir.y, dir.x);
	vec2 q = p - dir * zs_gust_distance;
	vec2 a = vec2(dot(q, dir), dot(q, across));
	float big = zs_noise(a / paw_size + vec2(3.1, 7.7)) * 0.65 + zs_noise(a / (paw_size * 0.43) + vec2(11.3, 2.9)) * 0.35;
	paw = smoothstep(0.42, 0.78, big) * paws;
	// Slicks: long smooth lanes along the wind, where the chop lies down.
	float lane = zs_noise(vec2(dot(p, across) * 0.06, dot(p, dir) * 0.004 - zs_gust_distance * 0.002));
	float slick = smoothstep(0.62, 0.86, lane) * (1.0 - paw);
	float air = clamp(zs_wind_strength, 0.0, 2.5);
	return (0.18 + 0.55 * air) * (0.45 + 1.3 * paw) * (1.0 - 0.7 * slick) * chop;
}

// The world point behind screen point `uv` at depth-buffer value `depth`.
vec3 zs_sea_receiver(vec2 uv, float depth, mat4 inv_projection, mat4 inv_view) {
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return (inv_view * vec4(view.xyz / view.w, 1.0)).xyz;
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	rest_xz = world.xz;
	// Only the swell heaves the sheet, and only where its cells can hold it:
	// the cell (m) grows ring by ring from the eye (SkyBelow `_sheet`).
	float reach = max(abs(VERTEX.x), abs(VERTEX.z));
	float cell = max(2.0, reach / 28.0);
	float near = 1.0 - smoothstep(heave_reach.x, heave_reach.y, reach);
	float rough, height;
	zs_sea_waves(world.xz, zs_flow_time, cell, 0.0, rough, height);
	VERTEX.y += height * near;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Where nothing lies behind the water, its depth (m).
const float DEEP = 1.0e4;

void fragment() {
	vec3 eye = normalize(CAMERA_POSITION_WORLD - world_position);
	float distance_to = length(CAMERA_POSITION_WORLD - world_position);
	// A pixel's footprint on the water (m), the larger of its two sides.
	float footprint = max(length(dFdx(rest_xz)), length(dFdy(rest_xz)));
	float paw;
	float air = zs_sea_air(rest_xz, paw);
	float rough, height;
	vec2 slope = zs_sea_waves(rest_xz, zs_flow_time, footprint, air, rough, height);
	vec3 normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	float facing = max(dot(eye, normal), 0.0);
	// What the faded waves leave: a rougher sheen (GGX roughness), and a
	// little less mirror where the sea is rough and seen low.
	float sigma = sqrt(rough);
	float roughness = clamp(0.12 + sigma * 1.6, 0.12, 0.6);
	// A little more mirror than glass's own (a softer power), so the sea
	// carries the sky's and the hour's colour from a plane's height too.
	float fresnel = 0.04 + 0.96 * pow(1.0 - facing, 4.0);
	fresnel *= 1.0 - clamp(sigma * 1.5, 0.0, 0.25) * pow(1.0 - max(eye.y, 0.0), 4.0);
	// A cat's paw roughens the water: it mirrors less and blurs what it
	// mirrors, so the paws cross a glassy sea as dark patches.
	float worked = paw * (0.4 + 0.6 * min(zs_wind_strength, 1.0));
	fresnel *= 1.0 - 0.35 * worked;
	roughness = max(roughness, 0.12 + 0.35 * worked);

	// The bed behind this pixel, nudged by the waves (a little refraction)
	// unless the nudge lands on something standing out of the water.
	vec2 uv = SCREEN_UV;
	float depth = texture(sea_depth, uv).r;
	vec3 receiver = zs_sea_receiver(uv, depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float bed_depth = depth > 0.0 ? world_position.y - receiver.y : DEEP;
	vec2 bent = uv + (VIEW_MATRIX * vec4(normal.x, 0.0, normal.z, 0.0)).xy * vec2(1.0, -1.0) * 0.04 * smoothstep(0.0, 2.0, bed_depth) / (1.0 + distance_to * 0.05);
	float bent_depth = texture(sea_depth, bent).r;
	vec3 bent_receiver = zs_sea_receiver(bent, bent_depth, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	if (bent_depth <= 0.0 || bent_receiver.y < world_position.y - 0.05) {
		uv = bent;
		depth = bent_depth;
		receiver = bent_receiver;
		bed_depth = depth > 0.0 ? world_position.y - receiver.y : DEEP;
	}
	bed_depth = max(bed_depth, 0.0);

	// Deep water comes on gradually over the shelf, and not evenly: the
	// depth the colour and the bed's fading go by wavers round the island,
	// so the turquoise is widest in bays and narrowest off points.
	float waver = mix(0.75, 1.3, zs_noise(rest_xz * 0.045) * 0.7 + zs_noise(rest_xz * 0.13 + vec2(4.1, 7.3)) * 0.3);
	// Seen low, the eye looks through far more water than lies under the
	// surface (to a bed far off along the ray), and the water is as deep as
	// what it looks through: a shelf seen from a skim is blue, not a block
	// of turquoise standing in front of the island.
	float through = depth > 0.0 ? length(receiver - world_position) : DEEP;
	float soft_depth = max(bed_depth, through * 0.55) * waver;

	// The bed gone by the shelf's end (bed_fade m deep), so the shelf's foot
	// never shows as an edge.
	vec3 seen = exp(-absorb * through) * exp(-soft_depth / bed_fade);
	vec3 bed = textureLod(sea_screen, uv, 0.0).rgb;

	// The water's own colour by depth, lit by the sky and the key light.
	vec3 column = mix(tint_shallow, tint_mid, smoothstep(0.0, tint_depths.x, soft_depth));
	column = mix(column, tint_deep, smoothstep(tint_depths.x * 0.6, tint_depths.y, soft_depth));
	column = mix(column, tint_abyss, smoothstep(tint_depths.y, tint_depths.z, soft_depth));
	column *= zs_palette_water;
	vec3 ambient = zs_hemi_sky * zs_hemi_energy / PI;
	vec3 key = zs_key_irradiance * max(zs_key_direction.y, 0.0) / PI;
	vec3 light = (ambient + key * 0.8) * water_light;
	vec3 water = column * light * (vec3(1.0) - seen) + bed * seen;

	// The shore: a bright lip where the water thins to nothing, a foam line
	// lapping in and out, and waves washing in over the shelf to it.
	float detail = 1.0 - smoothstep(0.08, 0.6, fwidth(bed_depth));
	float lap = shore_foam * (0.75 + 0.25 * sin(zs_flow_time * 0.9 + zs_noise(rest_xz * 0.25) * 6.2832));
	float broken = zs_noise(rest_xz * 1.3 + vec2(zs_flow_time * 0.07, 0.0)) * 0.6 + zs_noise(rest_xz * 3.7 - vec2(0.0, zs_flow_time * 0.05)) * 0.4;
	float line = (1.0 - smoothstep(lap * 0.35, lap, bed_depth)) * mix(0.55, 1.0, smoothstep(0.3, 0.7, broken));
	float wave_phase = bed_depth * 4.2 + zs_flow_time * 1.1 + zs_noise(rest_xz * 0.08) * 3.0;
	float wash = smoothstep(0.82, 0.98, sin(wave_phase)) * (1.0 - smoothstep(wash_depth * 0.3, wash_depth, bed_depth)) * smoothstep(lap * 0.6, lap * 1.4, bed_depth);
	wash *= smoothstep(0.35, 0.65, broken) * detail;
	float foamed = clamp(max(line, wash * 0.7) * foam, 0.0, 1.0) * float(depth > 0.0);
	float lip = (1.0 - smoothstep(0.0, 0.12, bed_depth)) * float(depth > 0.0);
	vec3 white = vec3(0.93, 0.96, 0.97) * (ambient + key);
	water = mix(water, white, foamed * 0.9);
	water += tint_shallow * (ambient + key) * lip * 0.5;

	// The mirror: the sky above, and what stands on screen marched for.
	vec3 reflected = reflect(-eye, normal);
	reflected.y = abs(reflected.y);
	vec3 sky = zsSkyGradient(reflected);
	if (below_sky > 0.0) {
		vec3 pearl = zsBelowAir(reflected);
		vec3 hour = zsSkyBase(vec3(reflected.x, 0.05, reflected.z));
		float hour_lum = max(dot(hour, vec3(0.2126, 0.7152, 0.0722)), 0.02);
		vec3 warm = pearl * mix(vec3(1.0), clamp(hour / hour_lum, vec3(0.6), vec3(1.6)), sky_warmth);
		sky = mix(sky, warm, below_sky);
	}
	sky = clamp(sky, vec3(0.0), vec3(0.98));
	float mirrored = 0.0;
	vec3 mirror = vec3(0.0);
	if (mirror_steps > 0 && fresnel > 0.04) {
		mat4 to_clip = PROJECTION_MATRIX * VIEW_MATRIX;
		float step_length = mirror_march.x * (1.0 + distance_to * 0.01);
		float travelled = 0.0;
		float before = 0.0;
		for (int i = 0; i < 32; i++) {
			if (i >= mirror_steps) break;
			before = travelled;
			travelled += step_length;
			step_length *= mirror_march.y;
			vec3 q = world_position + reflected * travelled;
			vec4 clip = to_clip * vec4(q, 1.0);
			if (clip.w <= 0.0) break;
			vec3 ndc = clip.xyz / clip.w;
			vec2 at = ndc.xy * 0.5 + 0.5;
			if (any(lessThan(at, vec2(0.0))) || any(greaterThan(at, vec2(1.0)))) break;
			float scene = texture(sea_depth, at).r;
			// Reversed depth: the scene stands in front of the ray here.
			if (scene > ndc.z) {
				vec3 hit = zs_sea_receiver(at, scene, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
				// Only a surface the ray truly reached (not one far in front
				// of it), and never the bed under the water.
				float gap = length(hit - CAMERA_POSITION_WORLD) - length(q - CAMERA_POSITION_WORLD);
				if (gap > -(travelled - before) * 1.5 && hit.y > world_position.y - 0.2) {
					// Close in on the meeting between the last two steps.
					float lo = before, hi = travelled;
					for (int r = 0; r < 4; r++) {
						float mid = (lo + hi) * 0.5;
						vec4 c = to_clip * vec4(world_position + reflected * mid, 1.0);
						vec3 n = c.xyz / c.w;
						if (texture(sea_depth, n.xy * 0.5 + 0.5).r > n.z) hi = mid; else lo = mid;
					}
					vec4 c = to_clip * vec4(world_position + reflected * hi, 1.0);
					vec2 found = c.xy / c.w * 0.5 + 0.5;
					vec2 edge = smoothstep(vec2(0.0), vec2(0.06), found) * (1.0 - smoothstep(vec2(0.94), vec2(1.0), found));
					mirror = zs_scene_to_display(textureLod(sea_screen, found, 0.0).rgb);
					mirrored = edge.x * edge.y * (1.0 - smoothstep(0.15, 0.45, roughness));
					break;
				}
			}
		}
	}
	vec3 reflection = mix(sky, mirror, mirrored);

	// The sun's (or moon's) path, and its glitter on the chop.
	vec4 path = zs_lake_glint(reflect(-eye, normal), zs_sun_direction, zs_moon_direction, zs_celestial_clear, 0.0, glint_share);
	vec3 lit = water + zs_lake_direct(vec3(0.0), normal, eye, zs_key_direction, zs_key_irradiance, max(roughness, 0.25)) * glint_share * 0.18 * (1.0 - foamed);
	float mirror_weight = fresnel * (1.0 - foamed);
	vec3 display_color = mix(zs_scene_to_display(lit), reflection, mirror_weight);
	display_color = mix(display_color, path.rgb, path.a * (1.0 - foamed));
	ALBEDO = scene_linear_for_display(display_color);
	// The very edge lets the shore through, so the water has no hard rim.
	ALPHA = depth > 0.0 ? smoothstep(0.0, 0.05, bed_depth) : 1.0;
}
