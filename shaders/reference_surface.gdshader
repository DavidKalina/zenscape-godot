shader_type spatial;
#include "res://shaders/world_play_bend.gdshaderinc"
#include "res://shaders/scene_palette.gdshaderinc"
#include "res://shaders/reference_wind.gdshaderinc"
#include "res://shaders/grass_look.gdshaderinc"
#include "res://shaders/meadow_flower.gdshaderinc"
#include "res://shaders/conifer_wind.gdshaderinc"
#include "res://shaders/foliage_tread.gdshaderinc"
#include "res://shaders/reference_autumn.gdshaderinc"
#include "res://shaders/reference_season.gdshaderinc"
#include "res://shaders/shaping_reveal.gdshaderinc"
#include "res://shaders/reference_char.gdshaderinc"
#include "res://shaders/reference_cloud_field.gdshaderinc"
#include "res://shaders/reference_alpenglow.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/reference_inversion.gdshaderinc"
#include "res://shaders/sky_season.gdshaderinc"
#include "res://shaders/sky_peak_look.gdshaderinc"
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform bool brush_visible = false;
uniform vec2 brush_center = vec2(0.0);
uniform float brush_radius = 1.0;
uniform vec4 brush_color : source_color = vec4(1.0, 0.91, 0.61, 1.0);

uniform vec4 base_color : source_color = vec4(1.0);
uniform vec3 emissive_color = vec3(0.0);
uniform float roughness_value = 1.0;
// Per-resident moisture; independent of ground wetness and weather changes.
uniform float coat_wetness : hint_range(0.0, 1.0) = 0.0;
uniform float metalness_value = 0.0;
uniform bool sway_enabled = false;
uniform bool conifer_sway = false;
// A trunk that does not sway still bends with its swaying crown under the
// wind tool (zs_blow_bend), over the crown's `blow_shape` (bend from,
// height); scripts/garden_view.gd pairs them.
uniform bool blow_enabled = false;
uniform vec2 blow_shape = vec2(0.4, 2.4);
uniform bool tree_tread = false;
uniform float tree_tread_height = 4.26;
// A stiff plant that does not sway (a mushroom cluster) still tips in the
// pilot's wake: metres at `tread_wobble_height` (model units) per unit of
// lean (zs_tread_wobble); 0 holds it still.
uniform float tread_wobble = 0.0;
uniform float tread_wobble_height = 0.2;
uniform vec4 sway_shape = vec4(0.0, 1.0, 0.0, 0.0);
uniform vec4 sway_frequency = vec4(1.0, 2.0, 1.0, 0.5);
uniform vec3 sway_phase = vec3(0.9, 0.7, 1.3);
uniform bool flat_faces = false;
uniform bool wet_ground = false;
uniform float wet_droop = 0.0;
uniform bool terrain_growth = false;
uniform bool plant_growth = false;
// Opt-in for the single-chunk cozy regeneration prototype.
uniform bool cozy_prop_growth = false;
// Opt-in for thin foliage; trunks and other shared surfaces stay opaque.
#define ZS_FOLIAGE_TRANSMISSION
uniform float foliage_transmission : hint_range(0.0, 1.0) = 0.0;
uniform bool bird_wings = false;
// The pond fish's tail beat (scripts/land_life.gd, after the source's
// fish.js): a travelling wave down the body, rigid from the nose to x and
// swinging fully by y (model z), z metres across at the tail, w radians of
// wave per metre of body.
uniform bool fish_swim = false;
uniform vec4 fish_wave = vec4(0.07, -0.21, 0.042, 11.0);
// The painterly grass tuft (scripts/grass_tuft_mesh.gd): UV.y runs root to
// tip. Mass normals, the rolling wind wave, straw patches and tip glow from
// shaders/grass_look.gdshaderinc, as the dense meadow has them. How round a
// tuft lights, how much of it goes to straw, and how its tips glow.
uniform bool grass_blades = false;
uniform float grass_round = 0.55;
uniform float grass_dry = 0.25;
uniform float grass_tip_glow = 0.55;
// The tuft mesh's own root and tip colours (GrassTuft.dress, linear): the
// vertex colour over these keeps each blade's jitter and any instance tint,
// while the colour itself is the family's living green (grass_look).
uniform vec3 grass_source_root = vec3(0.0396, 0.1329, 0.0423);
uniform vec3 grass_source_tip = vec3(0.2917, 0.5271, 0.1145);
// How far the family's grass leans to living green, and each tuft's
// brightness jitter either way.
uniform float grass_living = 0.4;
uniform float grass_variation = 0.12;
// How much of the contact darkening the tufts keep; their root shade
// already darkens the base.
uniform float grass_contact = 0.4;
// The meadow flower kit (scripts/meadow_flower_mesh.gd): mass normals baked
// in the mesh, stems and leaves in the family's living green, petals in
// their own colour, glowing when backlit. Motion: stems bend most toward
// the head on the grass's rolling wave (`flower_motion.x` is the share they
// take), heads lag the wave by `.y` metres and nod by `.z` radians at full
// breeze, and petals flutter by `.w` metres.
uniform bool flower_heads = false;
uniform vec4 flower_motion = vec4(0.8, 0.7, 0.3, 0.004);
uniform float flower_bend = 1.6;
uniform float flower_glow = 0.0;
uniform float flower_roughness = 1.0;
uniform float flower_contact = 0.5;
uniform float flower_stem_shade = 0.8;
uniform float flower_palette_pull = 0.12;
// Petal colour variants the material picks per plant (linear), over the
// petal colour the mesh was authored in.
uniform int flower_variant_count = 0;
uniform vec3 flower_variants[4];
uniform vec3 flower_petal_ref = vec3(1.0);
// Distance thinning (docs/scenic/flowers.md, Cost), measured from the main
// camera (zs_camera_position) so every pass thins alike: from `.x` to `.y`
// metres a flower kind keeps down to `.z` of its plants, shrinking the
// dropped ones into the ground, and the kept heads grow by keep^-`.w` so the
// carpet keeps its cover. `.z` 1 turns it off.
uniform vec4 flower_far = vec4(12.0, 30.0, 1.0, 0.4);
// The plant's detail (leaves, bracts and buds: UV2.y's fraction,
// MeadowFlowerMesh DETAIL) shrinks away from `.x` to `.y` metres, so far
// flowers are stems and heads. `.x` 0 keeps it at every distance.
uniform vec2 flower_lod = vec2(0.0, 1.0);
// The dandelion's round (scripts/dandelion_seeds.gd, docs/scenic/dandelions.md),
// on the seed clock's material only. The instance alpha is the clock's state:
// 1 whole; 1 + f with the share f of its seeds blown away; 4 + t when it went
// bare at t on Emergence's clock. From t it stands bare `.x` s, blooms gold
// for `.y` s, closes over `.z` s and fluffs out again over `.w` s. CUSTOM0.w
// names each head vertex's part in it (MeadowFlowerMesh ROLE_*): 2 + its
// parachute's rank (seeds of rank under f are gone), 4 + r the gold head,
// 6 + r the core, 8 + r the bracts.
uniform bool flower_cycle = false;
uniform vec4 flower_cycle_times = vec4(30.0, 50.0, 2.0, 5.0);
// A crop that ripens and is cut (MeadowFlowerMesh RIPEN_KINDS: wheat,
// docs/scenic/wheat.md), read against the `zs_season` global: its straw keeps
// the mesh's own gold rather than the living green, greens with the spring
// bloom (and as it comes back once the dormancy eases), deepens toward amber
// through autumn, and through the winter's dormancy its ears fold onto their
// necks and every straw is held under `flower_stubble` metres (mesh space),
// pale straw stubble.
uniform bool flower_ripen = false;
uniform float flower_stubble = 0.14;
// Its spring green, times its own luminance: the ears' (lighter, yellower)
// and the straw's (deeper), MeadowFlowerMesh RIPEN_GREEN_*.
uniform vec3 flower_ripen_green_ear = vec3(0.62, 0.78, 0.22);
uniform vec3 flower_ripen_green_straw = vec3(0.30, 0.62, 0.12);
// The root's colour: the ground's under it times x, giving way to the
// tuft's own green by y of the way up.
uniform vec2 grass_root_blend = vec2(0.92, 0.6);
// How far the tuft's living green leans to the ground's colour under it.
uniform float grass_ground_pull = 0.4;
uniform bool source_bird_flight = false;
// How this part follows the seasons (scripts/scene_look.gd leaf_season): x
// autumn gold and spring freshness, y winter leaf fall, z spring blossom
// share, w winter die-back. The default keeps the source's autumn only.
uniform vec4 leaf_season = vec4(1.0, 0.0, 0.0, 0.0);
// Birch and aspen turn clear yellow where the source's autumn goes orange;
// 1 lifts the turned green up to the red (scripts/hero_trees.gd SPECIES).
uniform float autumn_yellow = 0.0;
varying vec3 leaf_local;
varying vec2 plant_root;
varying float foliage_gust;
varying float grass_along;
// Soft light from under a mushroom cap (scripts/mushroom_mesh.gd): the gills
// carry their share in UV2.x and glow warmly in their own colour, faintly.
// The share rides in grass_along, which caps (no blades, no flowers) leave
// free: Metal allows 31 varyings and this shader sits at the limit.
uniform float underglow = 0.0;
varying float grass_bow;
varying float inversion_transmit;
// Fire, written per instance by GardenView.set_object_fire: (char, burn).
uniform bool instance_fire_enabled = false;
// Emerged births, written per instance by GardenView into INSTANCE_CUSTOM.ba.
uniform bool instance_birth_enabled = false;
// An emerged tree's stand autumn (zs_instance_autumn), -1 for everything else.
varying flat float stand_autumn;
uniform vec2 object_fire = vec2(0.0);
// A sky peak's rock (scripts/sky_peaks.gd): nothing is drawn under the cloud
// sea's top (`sea_cut`, world metres), the line it is cut at wandering
// `sea_fray.x` metres up and down over a few tens of metres, and over the
// `sea_fray.y` metres above it the rock goes into the cloud's own glowing
// light, wholly so at the line, so a mountain's foot is in the cloud, never
// standing on it and never a ragged hem. Far below anything else, so it
// touches nothing else.
uniform float sea_cut = -1.0e9;
uniform vec2 sea_fray = vec2(10.0, 40.0);
// A sky peak's rock reads the plate's look (the field's patches, the rock's
// world-space strata, terrain_geology) this many times larger, so a range
// a few hundred metres high is the plate's mountain grown, not pinstriped.
uniform float look_scale = 1.0;
// A sky peak's rock is lit this far toward its mesh's own (broader) normal
// from each small face's, so its facets read as big planes, not the grid.
uniform float facet_soft : hint_range(0.0, 1.0) = 0.0;
// A sky peak's bare rock (scripts/sky_peaks.gd `_ground`): its own basalt
// (scripts/sky_peak.gd `_tone`), never the plate's ground painted over it:
// no grass field pulled onto a face that reads green, and no plate geology
// (terrain_geology's grey rock above its height, its damp green stains).
uniform bool peak_rock = false;
// A sky peak's snow (shaders/sky_season.gdshaderinc): the world's snow
// (linear, scripts/sky_peaks.gd `_snow`), laid on each face whose line the
// season has brought down far enough (UV.x, m; its shade packed in UV2.x).
uniform vec3 peak_snow = vec3(0.905, 0.930, 0.956);
const vec3 SEA_MIST_ALBEDO = vec3(0.56, 0.57, 0.6);
// The sun's colour the cloud sea holds at any hour (as the puffs do,
// shaders/sky_cloud_puff.gdshader), glowing in the foot's mist.
const float SEA_MIST_SUN = 0.15;
// How much of its light the foot keeps seen level across the sea.
const float SEA_MIST_LEVEL = 0.62;
varying vec2 char_state;
varying flat float char_clump;
varying float char_seed;
varying vec3 world_normal;
varying vec3 world_position;
// Height above the object's own origin: props and plants sit on theirs, so
// low parts are nearer the ground and see less of the sky.
varying float contact_height;
// The plate's earth sides (scripts/scene_look.gd source_roles): a slice cut
// through the ground, painted in soft strata that follow the rim down from
// the land's edge instead of the source's near-black vertex colours. UV.x is
// each vertex's rim top in the mesh's own space, written by
// NativeChunkEditor.skirt_mesh_for and ChunkAtlasView.lift_skirt, with UV.y
// 1 when written; an unwritten mesh uses `earth_sides_top`. Local space, so
// the flip's copy of the sides paints the same.
uniform bool earth_sides = false;
uniform float earth_sides_top = 2.6;
uniform float earth_sides_base = -2.8;
// The earth sides' depth below the rim, the rim's rise, height above the
// base and position along the side, packed in one varying: the shader is at
// the 31-varying limit (Metal), and four floats would take four. The grass
// ground (zs_is_ground) has no sides and reuses it: x is how near water it
// lies, y whether it lies in a hollow or on a crest, z the trees' shade
// (shaders/ground_look.gdshaderinc).
varying vec4 earth_side;
// The precipitation height map: 128 texels over the 32 m plate, alpha the
// water surface height (-1000 where dry). Read for wet banks only.
global uniform sampler2D zs_water_map;
// The shade trees lay on the ground: 64 texels over the plate, red the
// shade (scripts/ground_shade.gd).
global uniform sampler2D zs_ground_shade;
// A sky chunk's far version (scripts/sky_islands.gd): drawn hundreds of
// metres off, it reads the look the plate would give it. `look_shift` is
// where it stands from the plate's spot, taken off every world-placed look
// (the field's patches, the land's form, the seasons' paint, a plant's
// root), so it shows the very colours it will once claimed; and its ground
// reads its own land's maps (`own_maps`: its height and water map and its
// trees' shade, made as the plate's are), never the plate's.
uniform vec3 look_shift = vec3(0.0);
uniform bool own_maps = false;
uniform sampler2D own_water_map : filter_nearest, repeat_disable;
uniform sampler2D own_ground_shade : filter_nearest, repeat_disable;
vec4 zs_water_texel(ivec2 t) {
	if (own_maps) return texelFetch(own_water_map, t, 0);
	return texelFetch(zs_water_map, t, 0);
}
vec4 zs_shade_texel(ivec2 t) {
	if (own_maps) return texelFetch(own_ground_shade, t, 0);
	return texelFetch(zs_ground_shade, t, 0);
}

#include "res://shaders/terrain_geology.gdshaderinc"
#include "res://shaders/ground_look.gdshaderinc"

// The plate's ground: the terrain mesh, painted by the calm grass field
// (ground_look) and lit partly by its smoothed normal.
bool zs_is_ground() {
	return terrain_growth && palette_role == 1 && !earth_sides;
}

// Chunk atlas: borders that meet a neighbour (n, e, s, w as 1) stay at their
// pinned height while the live chunk folds down or grows back, so a seam never
// opens mid-regeneration (the source's SEAM_HOLD).
uniform vec4 atlas_hold = vec4(0.0);
uniform float atlas_hold_width = 3.2;
float zs_atlas_hold_at(vec2 p) {
	float d = 1.0e3;
	if (atlas_hold.x > 0.5) d = min(d, p.y + zs_plate_half);
	if (atlas_hold.y > 0.5) d = min(d, zs_plate_half - p.x);
	if (atlas_hold.z > 0.5) d = min(d, zs_plate_half - p.y);
	if (atlas_hold.w > 0.5) d = min(d, p.x + zs_plate_half);
	return 1.0 - smoothstep(0.0, atlas_hold_width, d);
}

// The earth sides' strata (scripts/strata.gd is the one definition; its
// `apply` sets these): flat bands by plate height, warped a little per world,
// and a granite core under columns that stand tall. `strata_offset` takes the
// sides' own space to plate space.
uniform vec3 strata_offset = vec3(0.0, -2.0, 0.0);
uniform vec4 strata_floors = vec4(-0.4, -1.8, -3.2, -4.4);
// Core from, core base, core bed, shale bed.
uniform vec4 strata_core = vec4(2.5, 0.0, 0.6, 0.3);
uniform vec4 strata_wave_a = vec4(0.33, 0.0, 0.0, 0.25);
uniform vec4 strata_wave_b = vec4(0.0, 0.52, 0.0, 0.0);
uniform vec2 strata_skin = vec2(0.22, 0.55);
uniform vec3 strata_topsoil = vec3(0.195, 0.122, 0.071);
uniform vec3 strata_clay = vec3(0.392, 0.188, 0.072);
uniform vec3 strata_sand = vec3(0.624, 0.510, 0.305);
uniform vec3 strata_shale = vec3(0.159, 0.141, 0.127);
uniform vec3 strata_shale_dark = vec3(0.098, 0.084, 0.076);
uniform vec3 strata_bedrock = vec3(0.212, 0.209, 0.195);
uniform vec3 strata_core_a = vec3(0.392, 0.371, 0.332);
uniform vec3 strata_core_b = vec3(0.491, 0.462, 0.413);
uniform vec3 strata_core_c = vec3(0.305, 0.288, 0.255);

// The strata's colour at plate point `p` under a column topped at `surface`
// (strata.gd `color_at`), each band edge eased over a pixel. Linear.
vec3 zs_strata(vec3 p, float surface) {
	float warp = strata_wave_a.w * (0.6 * sin(dot(p.xz, strata_wave_a.xy) + strata_wave_a.z)
		+ 0.4 * sin(dot(p.xz, strata_wave_b.xy) + strata_wave_b.z));
	float h = p.y + warp;
	float e = max(fwidth(h), 0.02);
	float beds = mod(floor((h - strata_floors.w) / strata_core.w), 2.0);
	vec3 c = strata_bedrock;
	c = mix(c, beds > 0.5 ? strata_shale_dark : strata_shale, smoothstep(strata_floors.w - e, strata_floors.w + e, h));
	c = mix(c, strata_sand, smoothstep(strata_floors.z - e, strata_floors.z + e, h));
	c = mix(c, strata_clay, smoothstep(strata_floors.y - e, strata_floors.y + e, h));
	c = mix(c, strata_topsoil, smoothstep(strata_floors.x - e, strata_floors.x + e, h));
	float bed = mod(floor(p.y / strata_core.z), 3.0);
	vec3 core = bed < 0.5 ? strata_core_a : bed < 1.5 ? strata_core_b : strata_core_c;
	float ep = max(fwidth(p.y), 0.02);
	c = mix(c, core, step(strata_core.x, surface) * smoothstep(strata_core.y - ep, strata_core.y + ep, p.y));
	// The grass's root mat under the rim.
	return mix(c, strata_topsoil * strata_skin.y, 1.0 - smoothstep(strata_skin.x - 0.03, strata_skin.x + 0.03, surface - p.y));
}

void vertex() {
	// A flower's head offset from its neck (CUSTOM0.xyz), as the distance
	// thinning grows it; a dropped plant collapses to its root and skips the rest.
	vec3 flower_offset = CUSTOM0.xyz;
	bool flower_gone = false;
	if (flower_heads && (flower_far.z < 1.0 || flower_lod.x > 0.0)) {
		float far_d = distance(zs_camera_position, MODEL_MATRIX[3].xyz);
		float far_t = smoothstep(flower_far.x, flower_far.y, far_d);
		float keep = mix(1.0, flower_far.z, far_t);
		float rank = fract(sin(dot(MODEL_MATRIX[3].xz - look_shift.xz, vec2(27.17, 63.41))) * 43758.5453);
		float fade = smoothstep(keep * 1.08, keep * 1.08 - 0.08, rank);
		if (flower_lod.x > 0.0 && fract(UV2.y) > 0.125) fade *= 1.0 - smoothstep(flower_lod.x, flower_lod.y, far_d);
		if (UV2.y > 0.5) {
			vec3 grown = flower_offset * (pow(1.0 / keep, flower_far.w) - 1.0);
			VERTEX += grown;
			flower_offset += grown;
		}
		VERTEX *= fade;
		flower_offset *= fade;
		// A dropped plant is one point: no motion, light or colour to work out
		// (a vertex function cannot return early, so the rest is skipped).
		flower_gone = fade <= 0.0;
	}
	if (flower_cycle && !flower_gone && CUSTOM0.w >= 2.0) {
		float cycle_state = COLOR.a;
		float cycle_lost = cycle_state >= 1.0 && cycle_state < 2.0 ? cycle_state - 1.0 : 0.0;
		float cycle_gold = 0.0;
		float cycle_back = 0.0;
		if (cycle_state >= 3.0) {
			float cycle_age = zs_emergence_time - (cycle_state - 4.0);
			float cycle_closes = flower_cycle_times.x + flower_cycle_times.y;
			float cycle_shut = cycle_closes + flower_cycle_times.z;
			// The gold head pops open (an easeOutBack, as a birth rises) and
			// folds away as the clock comes back.
			float cycle_open = clamp((cycle_age - flower_cycle_times.x) / 1.2, 0.0, 1.0) - 1.0;
			cycle_gold = (1.0 + 2.70158 * cycle_open * cycle_open * cycle_open + 1.70158 * cycle_open * cycle_open)
				* (1.0 - smoothstep(cycle_closes, cycle_shut, cycle_age));
			cycle_back = clamp((cycle_age - cycle_shut + 0.5 * flower_cycle_times.z) / max(flower_cycle_times.w, 0.1), 0.0, 1.0);
			cycle_lost = 1.0;
		}
		float cycle_role = CUSTOM0.w < 4.0 ? 2.0 : CUSTOM0.w < 6.0 ? 4.0 : CUSTOM0.w < 8.0 ? 6.0 : 8.0;
		float cycle_value = CUSTOM0.w - cycle_role;
		float cycle_show = 1.0;
		// A seed stays until the air takes its rank, and comes back in the
		// same order, each one growing out over a share of the fluffing.
		if (cycle_role < 3.0) cycle_show = cycle_value >= cycle_lost ? 1.0 : smoothstep(cycle_value * 0.7, cycle_value * 0.7 + 0.3, cycle_back);
		else if (cycle_role < 5.0) cycle_show = cycle_gold;
		// The bracts fold away under the gold.
		else if (cycle_role > 7.0) cycle_show = 1.0 - clamp(cycle_gold, 0.0, 1.0);
		// The core: bare, it shrinks to the head's small tan nub, tucked away
		// under the gold, and swells back as the seeds return.
		else {
			// (A thinning clock's core shrinks with what it has lost.)
			float cycle_bare = cycle_lost >= 1.0 ? 1.0 - cycle_back : cycle_lost * cycle_lost * 0.7;
			cycle_show = mix(1.0, 0.42, cycle_bare) * (1.0 - clamp(cycle_gold, 0.0, 1.0));
			COLOR.rgb *= mix(vec3(1.0), vec3(0.74, 0.68, 0.48), cycle_bare);
		}
		VERTEX -= flower_offset * (1.0 - cycle_show);
		flower_offset *= cycle_show;
		flower_gone = cycle_show <= 0.0;
	}
	if (flower_ripen && !flower_gone && zs_season.z > 0.004) {
		// Cut for the winter: ears fold onto their necks, straws stand as
		// stubble, and the bend (UV.y, along a 1 m plant) is the stubble's.
		float ripen_cut = zs_season.z;
		VERTEX -= flower_offset * ripen_cut;
		flower_offset *= 1.0 - ripen_cut;
		VERTEX.y = mix(VERTEX.y, min(VERTEX.y, flower_stubble), ripen_cut);
		UV.y = mix(UV.y, min(UV.y, flower_stubble), ripen_cut);
	}
	if (!flower_gone) {
		leaf_local = VERTEX;
		if (earth_sides) {
			float rim_top = UV.y > 0.5 ? UV.x : earth_sides_top;
			earth_side = vec4(rim_top - VERTEX.y, rim_top - earth_sides_top, VERTEX.y - earth_sides_base, VERTEX.x + VERTEX.z);
		}
		plant_root = MODEL_MATRIX[3].xz - look_shift.xz;
		if (leaf_season.w > 0.0) VERTEX *= zs_season_dieback(leaf_season.w);
		foliage_gust = 0.0;
		grass_along = grass_blades ? clamp(UV.y, 0.0, 1.0) : 0.0;
		if (underglow > 0.0 && !grass_blades && !flower_heads) grass_along = clamp(UV2.x, 0.0, 1.0);
		if (flower_heads) {
			// Flowers carry their glow share in grass_along (no spare varyings).
			grass_along = zs_flower_glow_share(UV2.x);
			// A placed colour (MeadowFlowerMesh.instance_color): GardenView sends a
			// white instance colour whose alpha names the variant, (k + 0.5) / 8,
			// so a meadow's drift keeps one colour; full alpha picks per plant.
			int flower_chosen = COLOR.a < 0.5 ? clamp(int(COLOR.a * 8.0), 0, 3) : -1;
			COLOR.a = 1.0;
			if (flower_ripen) {
				// Wheat keeps its authored gold, straw and ears alike, and follows
				// the year: green with the spring bloom and as it comes back from
				// the stubble (no autumn left, the dormancy easing), amber through
				// autumn, pale straw while cut.
				float ripen_lum = dot(COLOR.rgb, vec3(0.30, 0.55, 0.15));
				float ripen_green = max(zs_season.x, (1.0 - zs_season.w) * (1.0 - smoothstep(0.5, 1.0, zs_season.z)) * smoothstep(0.0, 0.2, zs_season.z));
				COLOR.rgb = mix(COLOR.rgb, (UV2.x < 1.5 ? flower_ripen_green_straw : flower_ripen_green_ear) * ripen_lum, 0.85 * ripen_green);
				COLOR.rgb *= mix(vec3(1.0), vec3(1.0, 0.86, 0.64), 0.6 * zs_season.w);
				COLOR.rgb = mix(COLOR.rgb, vec3(1.12, 1.0, 0.76) * ripen_lum, 0.7 * zs_season.z);
				if (UV2.x < 1.5) COLOR.rgb *= mix(1.0, UV.x, 0.5);
				COLOR.rgb = zs_flower_palette(COLOR.rgb, zs_palette_grass / ZS_GRASS_SOURCE, flower_palette_pull);
			} else if (UV2.x < 1.5) {
				vec3 flower_living = zs_grass_living(zs_palette_grass * ZS_GRASS_SOURCE, grass_living, ZS_GRASS_LIVING_SATURATION);
				COLOR.rgb = flower_living * flower_stem_shade * UV.x;
			} else {
				if (UV2.x > 2.5 && UV2.x < 3.5 && flower_variant_count > 0) {
					int flower_pick = flower_chosen >= 0 ? min(flower_chosen, flower_variant_count - 1) : min(int(fract(sin(dot(MODEL_MATRIX[3].xz - look_shift.xz, vec2(41.3, 17.9))) * 43758.5453) * float(flower_variant_count)), flower_variant_count - 1);
					vec3 flower_variant = flower_variants[0];
					if (flower_pick == 1) flower_variant = flower_variants[1];
					else if (flower_pick == 2) flower_variant = flower_variants[2];
					else if (flower_pick == 3) flower_variant = flower_variants[3];
					COLOR.rgb = flower_variant * COLOR.rgb / max(flower_petal_ref, vec3(0.002));
				}
				COLOR.rgb = zs_flower_palette(COLOR.rgb, zs_palette_grass / ZS_GRASS_SOURCE, flower_palette_pull);
			}
		}
		grass_bow = 0.0;
		vec2 grass_tilt = vec2(0.0);
		char_state = instance_fire_enabled ? INSTANCE_CUSTOM.rg : object_fire;
		char_clump = zs_char_clump(VERTEX);
		char_seed = zs_char_seed(MODEL_MATRIX[3].xz);
		if (terrain_growth) {
			float grown = max(max(smoothstep(UV.x, UV.x + 0.3, zs_growth_now().x), UV.y), zs_atlas_hold_at(VERTEX.xz));
			VERTEX.y = mix(0.6, UV2.y, grown);
			vec3 living = mix(CUSTOM0.rgb, COLOR.rgb, smoothstep(0.6, 1.0, grown));
			vec3 dirt = vec3(0.1441, 0.0976, 0.0630) * (0.88 + 0.24 * UV2.x);
			COLOR.rgb = mix(dirt, living, smoothstep(0.02, 0.42, grown));
		}
		if (bird_wings && source_bird_flight) {
			float span = abs(VERTEX.x);
			float lever = smoothstep(0.07, 1.12, span);
			float angle = sin(INSTANCE_CUSTOM.g) * INSTANCE_CUSTOM.r * lever * lever;
			float ca = cos(angle), sa = sin(angle);
			float side = sign(VERTEX.x);
			vec2 rotated = vec2(span * ca - VERTEX.y * sa, span * sa + VERTEX.y * ca);
			VERTEX.x = rotated.x * side;
			VERTEX.y = rotated.y;
		} else if (bird_wings) {
			float wing = smoothstep(0.09, 0.65, abs(VERTEX.x));
			float phase = float(INSTANCE_ID) * 1.7;
			float flap = smoothstep(0.45, 0.85, sin(zs_motion_time * 0.65 + phase));
			float angle = sin(zs_motion_time * 7.5 + phase) * 0.40 * flap * wing;
			VERTEX.y += abs(VERTEX.x) * sin(angle);
			VERTEX.x *= cos(angle);
		}
		if (fish_swim) {
			float phase = MODEL_MATRIX[3].x * 2.3 + MODEL_MATRIX[3].z * 1.7;
			float whip = smoothstep(fish_wave.x, fish_wave.y, VERTEX.z);
			VERTEX.x += sin(zs_motion_time * 9.0 + phase + VERTEX.z * fish_wave.w) * whip * fish_wave.z;
		}
		if (conifer_sway) {
			VERTEX += zs_conifer_offset(VERTEX, MODEL_MATRIX);
		}
		if (blow_enabled && !sway_enabled && !conifer_sway) {
			// A trunk under a swaying crown takes the crown's breeze too, over
			// the same shape, so the two never part (no flutter: wood is stiff).
			float trunk_gust;
			float trunk_bow;
			VERTEX += zs_breeze_bend(VERTEX, MODEL_MATRIX, blow_shape.x, blow_shape.y, 1.0, 0.0, trunk_gust, trunk_bow);
			float blow_shiver;
			VERTEX += zs_blow_bend(VERTEX, MODEL_MATRIX, blow_shape.x, blow_shape.y, blow_shiver);
		}
		if (sway_enabled && !conifer_sway) {
			vec2 root = MODEL_MATRIX[3].xz;
			float phase = dot(root, sway_phase.xy);
			// Flowers bend most toward the head (UV.y is the bend fraction; every
			// vertex of a head takes its neck's), other plants by height.
			float bend = flower_heads ? pow(clamp(UV.y, 0.0, 1.0), flower_bend) : smoothstep(sway_shape.x, sway_shape.y, VERTEX.y);
			// A flower's head rides its neck whole (CUSTOM0.xyz is the offset from
			// it): the breeze bends the stem, the nod below turns the head.
			vec3 sway_at = flower_heads && UV2.y > 0.5 ? VERTEX - flower_offset : VERTEX;
			// The ambient breeze (reference_wind, docs/scenic/breeze.md): stiff
			// at the root, the tip lagging, swaying and fluttering; low plants
			// roll with the meadow's waves. World-space, so asset yaw never
			// rotates the air. Stiff species (a small sway_shape.z) take less.
			float breeze_gust;
			float breeze_bow;
			vec2 motion;
			float flower_late = 0.0;
			if (flower_heads) {
				// A heavy head lags: it answers the breeze that was
				// `flower_motion.y` m upwind (the gust or crest that passed its
				// root a beat ago). The stem reads the same air, so the lean is
				// read once a vertex (docs/scenic/flowers.md, Cost).
				float flower_wave = 1.0 - smoothstep(0.7, 1.8, sway_shape.y * length(MODEL_MATRIX[1].xyz));
				flower_late = zs_breeze_lean_at(root, flower_motion.y / max(zs_gust_speed, 0.5), flower_wave, breeze_bow);
				motion = zs_breeze_offset_lean(sway_at, MODEL_MATRIX, sway_shape.x, sway_shape.y,
					zs_breeze_flex(sway_shape.z), zs_breeze_flutter(sway_shape.z), flower_late, breeze_gust);
			} else {
				motion = zs_breeze_offset(sway_at, MODEL_MATRIX, sway_shape.x, sway_shape.y,
					zs_breeze_flex(sway_shape.z), zs_breeze_flutter(sway_shape.z), breeze_gust, breeze_bow);
			}
			if (flower_heads) {
				// The meadow flower kit on top of the breeze (docs/scenic/flowers.md):
				// stems take `flower_motion.x` of its bend (a sunflower stalk less).
				motion *= mix(0.5, 1.0, clamp(flower_motion.x, 0.0, 1.0));
				float flower_air = min(zs_breeze_air(), 1.5);
				vec3 flower_down = inverse(mat3(MODEL_MATRIX)) * vec3(zs_wind_direction.x, 0.0, zs_wind_direction.y);
				if (UV2.y > 0.5 && dot(flower_down.xz, flower_down.xz) > 1.0e-8) {
					// The head nods downwind about its neck on the lagging lean
					// read above, with a slow bob of its own.
					vec3 flower_axis = normalize(cross(vec3(0.0, 1.0, 0.0), normalize(vec3(flower_down.x, 0.0, flower_down.z))));
					float flower_nod = flower_motion.z * (0.3 * flower_air + clamp(flower_late / 0.6, 0.0, 1.5)
						+ 0.25 * flower_air * sin(zs_motion_time * sway_frequency.x * 0.55 + phase * 1.3));
					flower_nod = clamp(flower_nod, -0.5, 0.9);
					VERTEX += zs_flower_turn(flower_offset, flower_axis, flower_nod) - flower_offset;
					NORMAL = zs_flower_turn(NORMAL, flower_axis, flower_nod);
					// Petals flutter a little, most at their tips, harder in a gust.
					if (UV2.x > 2.5 && UV2.x < 3.5) VERTEX += NORMAL * sin(zs_motion_time * 13.0 + phase * 3.1 + CUSTOM0.w * 5.0) * flower_motion.w * CUSTOM0.w * flower_air * (0.4 + breeze_gust);
				}
			}
			float instance_scale = length(MODEL_MATRIX[1].xyz);
			if (grass_blades) {
				// Bowed blades pale and tip their soft-mass normal downwind (grass_look).
				grass_bow = breeze_bow;
				grass_tilt = motion / max(sway_shape.y * instance_scale, 0.1) * 0.6;
			}
			VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(motion.x, 0.0, motion.y);
			float arm = max(sway_at.y - sway_shape.x, 0.05) * instance_scale;
			VERTEX.y -= min(dot(motion, motion) / (2.0 * arm), arm * 0.7) / max(instance_scale, 0.001);
			// Plants bowed by a wave or gust pale a little (the plant_growth tint
			// below), so the classic tufts show the rolling bands too.
			foliage_gust = clamp(max(breeze_gust * 0.5, breeze_bow * 0.7) * bend, 0.0, 1.0);
			// The pilot's wake (shaders/foliage_tread.gdshaderinc): stems by his
			// path lean out from it and lie over, then spring back past rest
			// and settle, and whatever is under him is pressed down.
			// World-space like the wind above.
			if (zs_tread_live() && !tree_tread) {
				float press = 0.0;
				vec2 shove = zs_tread_push(root, press) * (arm * ZS_TREAD_REACH * bend);
				if (dot(shove, shove) > 0.0 || press != 0.0) {
					VERTEX += inverse(mat3(MODEL_MATRIX)) * vec3(shove.x, 0.0, shove.y) * instance_scale;
					float lean_sq = min(dot(shove, shove), arm * arm * 0.96);
					VERTEX.y -= (arm - sqrt(arm * arm - lean_sq)) + arm * bend * press * ZS_TREAD_FLATTEN;
				}
			}
			VERTEX.y -= zs_foliage_wet * bend * wet_droop;
			// Local gusts have a true world direction, even for rotated/scaled assets.
			// Anchored roots stay fixed; flexible crowns bend with bounded amplitude.
			vec3 air = zs_local_wind((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
			float speed = length(air);
			if (speed > 0.001) {
				float response = speed / (speed + 10.0);
				float flutter = 0.90 + 0.10 * sin(zs_motion_time * 12.0 + phase);
				float flexibility = max(sway_shape.z, sway_shape.w);
				vec3 displacement = air / speed * response * flexibility * 3.0 * bend * flutter;
				VERTEX += inverse(mat3(MODEL_MATRIX)) * displacement;
				foliage_gust = max(foliage_gust, response * bend);
			}
			// The wind tool (scripts/wind_gust.gd): its gusts, bursts and the
			// blowing hand bend the plant its own way, with spring-back and
			// sway after (zs_blow_bend).
			float blow_shiver;
			VERTEX += zs_blow_bend(VERTEX, MODEL_MATRIX, sway_shape.x, sway_shape.y, blow_shiver);
			foliage_gust = max(foliage_gust, blow_shiver * bend);
			if (grass_blades) grass_bow = max(grass_bow, blow_shiver * 0.8);

		}
		if (tree_tread && zs_tread_0.w > 0.0) VERTEX += zs_tree_tread(VERTEX, MODEL_MATRIX, tree_tread_height);
		// Stiff low things (mushrooms) tip and wobble as he brushes past.
		if (tread_wobble > 0.0 && !sway_enabled && zs_tread_live()) VERTEX += zs_tread_wobble(VERTEX, MODEL_MATRIX, tread_wobble, tread_wobble_height);
		if (cozy_prop_growth && !plant_growth) VERTEX *= smoothstep(0.70, 0.98, zs_growth_now().x);
		// An emerged instance also pops in at its own birth, INSTANCE_CUSTOM.ba =
		// (born, seconds, with the stand's autumn packed above); instances without
		// one stay at 1 (scripts/emergence.gd).
		stand_autumn = instance_birth_enabled && !bird_wings ? zs_instance_autumn(INSTANCE_CUSTOM.a) : -1.0;
		float birth = instance_birth_enabled && !bird_wings ? zs_birth_growth(INSTANCE_CUSTOM.b, zs_instance_rise(INSTANCE_CUSTOM.a)) : 1.0;
		if (plant_growth || birth < 1.0) {
			float t = birth;
			if (plant_growth) {
				float seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
				t = min(t, clamp((min(zs_growth_now().y, zs_growth_wave_at(MODEL_MATRIX[3].xz)) - seed * 0.72) / 0.28, 0.0, 1.0));
			}
			float b = t - 1.0;
			VERTEX *= 1.0 + 2.70158 * b * b * b + 1.70158 * b * b;
		}
		// Trunks, deadwood and stone char but never curl or thin.
		zs_char_curl(VERTEX, char_state.x, char_clump, palette_role != 3 && palette_role != 4);
		play_deform(VERTEX, NORMAL);
		world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
		if (zs_is_ground()) {
			// The smoothed ground normal rides world_normal (the fragment takes
			// the face's own from derivatives), and the nearness of water rides
			// the unused earth_side: no new varyings (Metal's 31, 4b6508e).
			world_normal = normalize(MODEL_NORMAL_MATRIX * zs_ground_smooth_normal(VERTEX, NORMAL));
			earth_side = vec4(zs_ground_lush_at(VERTEX), zs_ground_form_at(VERTEX), 0.0);
		}
		if (grass_blades) {
			// Light the tuft as part of the field's soft mass: the ground's
			// normal from the height map, domed outward toward the tips.
			ivec2 texel = clamp(ivec2(floor((plant_root + zs_map_half) * 4.0)), ivec2(0), ivec2(ZS_MAP_TEXELS - 2));
			float h00 = zs_water_texel(texel).g;
			float h10 = zs_water_texel(texel + ivec2(1, 0)).g;
			float h01 = zs_water_texel(texel + ivec2(0, 1)).g;
			vec2 slope = min(h00, min(h10, h01)) > -100.0 ? vec2(h10 - h00, h01 - h00) * 4.0 : vec2(0.0);
			vec3 ground_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
			vec2 out_dir = (mat3(MODEL_MATRIX) * vec3(leaf_local.x, 0.0, leaf_local.z)).xz;
			world_normal = normalize(mix(world_normal, zs_grass_mass_normal(ground_normal, out_dir, grass_along, grass_round, grass_tilt), 0.9));
		}
		contact_height = (terrain_growth || bird_wings) ? 1000.0 : world_position.y - MODEL_MATRIX[3].y;
	}
}

void fragment() {
	float sea_mist = 0.0;
	// A sky peak's point in its range's own frame (sky_peak_look).
	vec3 peak_rel = vec3(0.0);
	if (sea_cut > -1.0e8) {
		float wander = zs_noise(world_position.xz * 0.021) * 0.7 + zs_noise(world_position.xz * 0.057 + 31.0) * 0.3;
		float above = world_position.y - sea_cut - wander * sea_fray.x;
		if (above < 0.0) discard;
		sea_mist = 1.0 - smoothstep(0.0, sea_fray.y, above);
		sea_mist *= sea_mist * (3.0 - 2.0 * sea_mist);
		// Higher up, the low air and a drifting band of mist take the rock
		// part of the way into the same light (sky_peak_look).
		peak_rel = world_position - MODEL_MATRIX[3].xyz;
		sea_mist = max(sea_mist, zs_peak_low_air(above, peak_rel, zs_motion_time));
	}
	if (leaf_season.y > 0.0 && zs_leaf_fallen(leaf_local, plant_root, leaf_season.y)) discard;
	// Trees thin round a shaping tool at work (shaders/shaping_reveal.gdshaderinc).
	if (tree_tread && zs_revealed(leaf_local, plant_root, tree_tread_height, FRAGCOORD.xy)) discard;
	vec3 face_normal = world_normal;
	// The normal the light sees: the face's own, except on grass ground,
	// which leans `ground_soft` of the way to the smoothed ground.
	vec3 light_normal = world_normal;
	bool ground = zs_is_ground();
	float ground_grass = 0.0;
	if (ground) {
		vec3 facet = normalize(cross(dFdx(world_position), dFdy(world_position)));
		if (dot(facet, world_normal) < 0.0) facet = -facet;
		ground_grass = peak_rock ? 0.0 : zs_ground_grassness(base_color.rgb * COLOR.rgb);
		face_normal = facet;
		light_normal = normalize(mix(facet, normalize(world_normal), max(ground_soft * ground_grass, facet_soft)));
		NORMAL = normalize((VIEW_MATRIX * vec4(light_normal, 0.0)).xyz);
	}
	if (grass_blades || flower_heads) {
		face_normal = normalize(face_normal);
		NORMAL = normalize((VIEW_MATRIX * vec4(face_normal, 0.0)).xyz);
	}
	if (flat_faces && !grass_blades) {
		face_normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
		// Three.js flat DoubleSide surfaces shade the face toward the viewer.
		if (dot(face_normal, zs_camera_position - world_position) < 0.0) face_normal = -face_normal;
		NORMAL = normalize((VIEW_MATRIX * vec4(face_normal, 0.0)).xyz);
	}
	if (!ground) light_normal = face_normal;
	else if (facet_soft > 0.0) NORMAL = normalize((VIEW_MATRIX * vec4(light_normal, 0.0)).xyz);
	if (sea_mist > 0.0) {
		// A sky peak's foot is lit as the cloud sea's level top is, so it
		// takes the sea's light at every hour and no facet stands out dark.
		light_normal = normalize(mix(light_normal, vec3(0.0, 1.0, 0.0), sea_mist));
		NORMAL = normalize((VIEW_MATRIX * vec4(light_normal, 0.0)).xyz);
	}
	// The ground's colour is made in one place (ground_look zs_ground_color).
	// Where the look is read: the world point, less a far chunk's shift.
	vec3 look_world = world_position - look_shift;
	vec3 look_position = look_world / look_scale;
	vec3 surface = COLOR.rgb;
	if (sea_cut > -1.0e8) {
		// A sky peak: its basalt's fine grain, and its snow line following
		// the season down to its floor (sky_season): the fall and the floor
		// are the world's metres, the face's need (UV.x) and height (UV2.y)
		// the range's own; the line ragged, softened and fluted across the
		// faces (sky_peak_look).
		float peak_scale = max(length(MODEL_MATRIX[1].xyz), 1e-3);
		float px = length(fwidth(peak_rel));
		vec3 lie = normalize(world_normal);
		if (peak_rock) surface = zs_peak_rock_grain(surface, peak_rel, lie, px);
		float margin = zs_sky_peak_margin(UV.x, UV2.y, peak_scale, sea_cut) * peak_scale;
		float cover = zs_peak_snow_cover(margin, peak_rel, lie, px);
		if (cover > 0.0) surface = mix(surface, zs_peak_snow_grain(zs_sky_snow_colour(peak_snow, UV2.x), peak_rel, px), cover);
	}
	vec3 tint = ground ? zs_ground_color(base_color.rgb * surface, look_position, earth_side.x, ground_grass)
		: scene_palette(base_color.rgb * surface);
	// Slopes to the sun a little warmer, away from it a little deeper (the
	// smoothed ground normal rides world_normal on the ground).
	if (ground) tint = zs_ground_sun_warm(tint, normalize(world_normal), zs_sun_direction, ground_grass);
	// The land's own colour: hollows lusher, crests drier, steep grass thin
	// (ground_look zs_ground_form); the trees' shade comes after the seasons.
	if (ground) tint = zs_ground_form(tint, look_world, earth_side.xyz, normalize(world_normal), ground_grass);
	// The earth sides: strata, each facet a shade apart like the ground's,
	// dimming toward the base where the void's mist takes over (EMISSION).
	float side_mist = 0.0;
	if (earth_sides) {
		vec3 facet = floor(abs(face_normal) * 40.0);
		float jitter = fract(sin(dot(facet, vec3(12.9898, 78.233, 37.719))) * 43758.5453) - 0.5;
		side_mist = 1.0 - smoothstep(0.0, 1.6, earth_side.z);
		// The same strata and ground palette as cut ground (scripts/strata.gd).
		vec3 plate = (inverse(MODEL_MATRIX) * vec4(world_position, 1.0)).xyz + strata_offset;
		tint = scene_palette_ground(base_color.rgb * zs_strata(plate, plate.y + earth_side.x)
			* (1.0 + 0.14 * jitter) * mix(1.0, 0.5, side_mist));
	}
	if (grass_blades) {
		// The family's grass leaned to living green, dark at the root and
		// sunlit at the tip like the dense meadow, with straw patches as
		// accents and the paling of blades a passing wave bows. The vertex
		// colour over the mesh's own gradient keeps blade jitter and tints.
		vec3 grass_src = max(mix(grass_source_root, grass_source_tip, grass_along), vec3(0.002));
		vec3 own = clamp(COLOR.rgb / grass_src, vec3(0.0), vec3(3.0));
		vec3 living = zs_grass_living(zs_palette_grass * ZS_GRASS_SOURCE, grass_living, ZS_GRASS_LIVING_SATURATION);
		// The tuft is the field's grass standing up: its green leans toward
		// the ground's under it (ground_look), so it sits in the field.
		vec3 ground_under = zs_ground_color(ZS_GROUND_GREEN, vec3(plant_root.x, 0.0, plant_root.y), 0.0, 1.0);
		living = mix(living, ground_under, grass_ground_pull);
		float tuft_shade = 1.0 + (fract(sin(dot(plant_root, vec2(37.1, 91.7))) * 43758.5453) - 0.5) * 2.0 * grass_variation;
		float dry = zs_grass_dry(plant_root, ZS_GRASS_DRY_SCALE, zs_grass_offset) * grass_dry;
		tint = zs_grass_paint(living * base_color.rgb * own, grass_along, dry, ZS_GRASS_STRAW, ZS_GRASS_ROOT_SHADE, ZS_GRASS_TIP_LIFT, ZS_GRASS_TIP_CURVE) * tuft_shade;
		// The root grows out of the ground's own colour (ground_look) and
		// only the upper blade is the tuft's, so no dark base rings it.
		tint = mix(ground_under * grass_root_blend.x, tint, smoothstep(0.0, grass_root_blend.y, grass_along));
		tint *= 1.0 + ZS_GRASS_WAVE_SHEEN * grass_bow * grass_along;
	}
	if (terrain_growth && !peak_rock && (rock_treatment > 0 || inland_rock_amount > 0.0 || desert_enabled)) tint = terrain_geology(tint,look_position,face_normal);
	vec3 before_autumn = tint;
	if (stand_autumn >= 0.0) zs_autumn_stand_paint(tint, plant_root, zs_autumn * leaf_season.x, stand_autumn);
	else zs_autumn_paint(tint, look_position, zs_autumn * leaf_season.x);
	if (autumn_yellow > 0.0) {
		float turned = clamp(length(tint - before_autumn) * 4.0, 0.0, 1.0);
		tint.g = mix(tint.g, max(tint.g, tint.r * 0.8), turned * autumn_yellow);
	}
	if (palette_role == 2) zs_season_leaves(tint, leaf_local, plant_root, face_normal, leaf_season.x, leaf_season.z);
	else if (palette_role == 1 || palette_role == 5) zs_season_grass(tint, leaf_season.x);
	// A sky peak's grass dries a little through the summer (sky_season).
	if (sea_cut > -1.0e8) zs_sky_summer_grass(tint);
	// The floor under trees, after the season's paint so autumn ground
	// darkens warm there instead of failing to turn (ground_look); tufts
	// share it.
	if (ground) tint = zs_ground_shaded(tint, earth_side.z, ground_grass);
	else if (grass_blades) tint = zs_ground_shaded(tint, zs_ground_shade_at(plant_root), 1.0);
	if (plant_growth) tint *= mix(1.0, 0.62, zs_foliage_wet) * (1.0 + 0.16 * foliage_gust);
	// Order is palette -> autumn -> season -> char -> wet -> snow: rain still darkens a
	// charred crown and snow still settles on it.
	float char_scorch = 0.0;
	vec3 char_ember = vec3(0.0);
	if (char_state.x > 0.004 || char_state.y > 0.004) {
		bool char_foliage = palette_role != 3 && palette_role != 4;
		if (zs_char_gone(char_state.x, char_clump, char_foliage)) discard;
		zs_char_paint(tint, char_scorch, char_ember, world_position, face_normal, char_state.x, char_state.y, char_seed, TIME);
	}
	float surface_wet = 0.0;
	float mineral = 0.0;
	if (wet_ground && zs_ground_wet > 0.001) {
		float exposure = smoothstep(-0.3, 0.0, face_normal.y) * mix(0.6, 1.0, smoothstep(0.0, 0.6, face_normal.y));
		float patch = zs_noise(look_world.xz * 0.65 + look_world.y * 0.17);
		surface_wet = smoothstep(patch * 0.28, 0.72 + patch * 0.28, zs_ground_wet) * exposure;
		float green = max(0.0, tint.g - max(tint.r, tint.b));
		mineral = 1.0 - smoothstep(0.015, 0.10, green);
		surface_wet *= 1.0 - smoothstep(0.55, 0.8, min(tint.r, min(tint.g, tint.b)));
		tint *= 1.0 - surface_wet * mix(0.20, 0.40, mineral);
	}
	if (wet_ground && zs_look_shore > 0.0) {
		// Look pass: ground just above a pond or stream reads damp. The nearest
		// water within half a metre sets the line; a little noise breaks it.
		float water = -1000.0;
		for (int i = 0; i < 5; i++) {
			vec2 offset = i == 0 ? vec2(0.0) : vec2(cos(float(i) * 1.5708), sin(float(i) * 1.5708)) * 0.45;
			ivec2 texel = ivec2(floor((look_world.xz + offset + zs_map_half) * 4.0));
			if (all(greaterThanEqual(texel, ivec2(0))) && all(lessThan(texel, ivec2(ZS_MAP_TEXELS))))
				water = max(water, zs_water_texel(texel).a);
		}
		float above = look_world.y - water;
		float line = 0.16 + 0.10 * zs_noise(look_world.xz * 1.7);
		float bank = water > -100.0 ? (1.0 - smoothstep(line * 0.4, line, above)) * step(-0.3, above) : 0.0;
		bank *= smoothstep(-0.2, 0.3, face_normal.y) * zs_look_shore * (1.0 - zs_ice);
		surface_wet = max(surface_wet, bank);
		tint *= 1.0 - bank * 0.32;
	}
	// A sky peak's snow is its season's line instead (vertex, sky_season).
	if (!bird_wings && zs_snow > 0.004 && sea_cut <= -1.0e8) {
		float noise = zs_noise(look_world.xz * 0.85);
		float line = mix(zs_summit.y + 2.0, 0.15 - 2.5, pow(zs_snow, 0.7));
		float cover = smoothstep(line - 0.6, line + 2.4, look_world.y + (noise - 0.5) * 3.0)
			* smoothstep(0.35, 0.72, face_normal.y) * smoothstep(0.0, 0.1, zs_snow);
		// Crowns catch some of the snow: the floor under trees lies thinner.
		if (ground) cover *= 1.0 - ZS_GROUND_SNOW_SHELTER * earth_side.z;
		tint = mix(tint, vec3(0.88, 0.91, 0.95) * (0.90 + 0.18 * noise), cover);
		surface_wet *= 1.0 - cover;
	}
	float cloud_shade = cloudShadeAt(vec3(world_position.x, 0.6, world_position.z), zs_cloud_direction);
	tint *= mix(1.0, 0.42 + 0.58 * cloud_shade, min(1.0, zs_cloud.x * 1.35) * 0.85);
	if (brush_visible) {
		float distance_to_brush = length(world_position.xz - brush_center);
		float aa = max(fwidth(distance_to_brush), 0.025);
		float ring = 1.0 - smoothstep(0.025, 0.025 + aa, abs(distance_to_brush - brush_radius));
		float fill = (1.0 - smoothstep(0.0, brush_radius, distance_to_brush)) * 0.13;
		tint = mix(tint, brush_color.rgb, max(ring * 0.9, fill));
	}
	tint *= mix(1.0, 0.56, coat_wetness);
	// A sky peak's foot goes into the cloud: the cloud's own white.
	// Seen level across the sea, as from far off, the sea reads deeper
	// than seen from over it, and so does the foot.
	float sea_level_view = 1.0;
	if (sea_mist > 0.0) {
		sea_level_view = mix(SEA_MIST_LEVEL, 1.0, smoothstep(0.02, 0.35, normalize(zs_camera_position - world_position).y));
		tint = mix(tint, zs_sky_season_grade(SEA_MIST_ALBEDO, 1.0) * sea_level_view, sea_mist);
	}
	ALBEDO = tint;
	ROUGHNESS = mix(roughness_value, mix(0.58, 0.20, mineral), surface_wet);
	ROUGHNESS = mix(ROUGHNESS, 0.48, coat_wetness);
	ROUGHNESS = mix(ROUGHNESS, 1.0, char_scorch);
	// Glossy petals (buttercups) take a sheen; grass_along is 0.9 on petals.
	if (flower_heads && grass_along > 0.85) ROUGHNESS = mix(flower_roughness, ROUGHNESS, char_scorch);
	METALLIC = metalness_value;
	// The source scene has no environment map; sky reflection would lift and
	// desaturate every shaded facet.
	SPECULAR = 0.35 * coat_wetness;
	// Three.js RE_IndirectDiffuse_Physical applies BRDF_Lambert (albedo / PI)
	// to hemisphere irradiance. Emission bypasses Godot's BRDF, so include it here.
	// Look pass: ambient-only contact occlusion. Emission bypasses Godot's SSAO,
	// so the hemisphere term is where grounding has to happen.
	float contact = mix(1.0, 0.42 + 0.58 * smoothstep(0.0, 0.85, contact_height), zs_look_ao);
	// Tufts keep a little of it up the blade; the root matches the ground.
	if (grass_blades) contact = mix(1.0, contact, grass_contact * smoothstep(0.0, grass_root_blend.y, grass_along));
	if (flower_heads) contact = mix(1.0, contact, flower_contact);
	// The sides hang below their origin; the contact term would halve them.
	if (earth_sides) contact = 1.0;
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, light_normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	EMISSION = emissive_color + tint * hemi * contact;
	if (underglow > 0.0 && !grass_blades && !flower_heads) EMISSION += tint * vec3(1.0, 0.88, 0.62) * underglow * grass_along * (0.6 + 0.4 * zs_hemi_energy / PI);
	// A seed clock holds light through itself: a soft sky glow of its own.
	if (flower_heads && grass_along > 0.95) EMISSION += tint * mix(zs_hemi_sky, vec3(1.0), 0.5) * zs_hemi_energy / PI * ZS_FLOWER_PUFF_LIGHT;
	// Toward the base the sides take on the sky's cool mist, never black.
	if (earth_sides) EMISSION += zs_hemi_sky * zs_hemi_energy / PI * 0.07 * side_mist;
	if (zs_look_rim > 0.0) {
		// Sky sheen on silhouettes, stronger against the sun; ground-facing
		// and flat-lying faces stay out so meadows do not glaze over.
		vec3 view_dir = normalize(zs_camera_position - world_position);
		float edge = pow(1.0 - abs(dot(light_normal, view_dir)), 4.0);
		float backlit = 0.5 + 0.5 * max(dot(-view_dir, zs_sun_direction), 0.0);
		float upright = 1.0 - smoothstep(0.6, 0.9, light_normal.y);
		EMISSION += mix(tint, vec3(0.5), 0.35) * zs_hemi_sky * zs_hemi_energy * edge * backlit * upright * contact * zs_look_rim;
	}
	vec3 alpen_normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
	if (dot(alpen_normal, face_normal) < 0.0) alpen_normal = -alpen_normal;
	EMISSION += zs_afterglow(world_position, alpen_normal, tint) + char_ember;
	if (sea_mist > 0.0) EMISSION += zs_cloud_sun * SEA_MIST_SUN * sea_level_view * sea_mist;
	inversion_transmit = zs_inversion_paint(world_position, EMISSION);
}

#define ZS_GRASS_TRANSLUCENCY
#define ZS_GRASS_ALONG grass_along
#define ZS_GRASS_GLOW (grass_blades ? grass_tip_glow : 0.0)
#define ZS_FLOWER_TRANSLUCENCY
#define ZS_FLOWER_SHARE grass_along
#define ZS_FLOWER_GLOW (flower_heads ? flower_glow : 0.0)
#include "res://shaders/reference_direct_light.gdshaderinc"
