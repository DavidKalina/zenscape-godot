#ifndef ZS_TREE_WIND
#define ZS_TREE_WIND
#include "res://shaders/reference_globals.gdshaderinc"
// The grass's own stirring (zs_react_map): the eddies' swept bands, the
// gusts landing and the prop's wash, so the woods bow with the meadows.
#include "res://shaders/grass_react.gdshaderinc"
// The woods alive (scripts/endless/land_trees.gd, --tree-alive=X): gust waves
// rolling through the woods and the boughs moving on their own, at every
// distance the spruces draw. 0 is the woods as before (each tree swaying as
// one shape, the sprites still), 1 the default, more for a windier look.
// Shared by the near and far crowns (reference_surface, conifer_wind), the
// sprites (endless_spruce_sprite) and the canopy painted past them
// (endless_forest_floor), so a wave runs on across every hand-over.
global uniform float zs_tree_alive;

// The waves: crests TREE_WAVE_LENGTH m apart, rolling downwind at
// TREE_WAVE_PACE times the air's own travel (about 6 m/s in the default
// breeze), bent and broken into patches by noise TREE_WAVE_PATCH m across.
const float ZS_TREE_WAVE_LENGTH = 90.0;
const float ZS_TREE_WAVE_PACE = 2.5;
const float ZS_TREE_WAVE_PATCH = 160.0;
// What a full crest adds to a tree's lean (zs_breeze_lean_at's units) and to
// its crown's light as the boughs lift and show their paler undersides.
const float ZS_TREE_WAVE_LEAN = 0.22;
const float ZS_TREE_SHEEN = 0.28;
// The boughs: tip bob (model units, at a bough's tip, calm and at a crest;
// the spruces stand about 3 to 4.5 times their model) and their beat (rad/s,
// about 0.35 Hz). The beat stays the same in a wave: only the bob grows (a
// pace that changed with the wave swept the phase by the clock's whole run,
// a jitter that grew the longer the game ran). ZS_BOUGH_REACH: a crown's
// reach in model units.
const vec2 ZS_BOUGH_BOB = vec2(0.05, 0.14);
const float ZS_BOUGH_REACH = 0.65;
const float ZS_BOUGH_PACE = 2.2;
// More sway in the breeze than the woods had before: their lean times
// ZS_TREE_SWAY_LEAN, their swing round it ZS_TREE_SWAY_SWING of the lean
// (zs_breeze's ZS_BREEZE_SWING is 0.4).
const float ZS_TREE_SWAY_LEAN = 1.4;
const float ZS_TREE_SWAY_SWING = 0.7;
// The share of the grass's push (zs_react_at, about 1 a full lean) a tree
// takes, in zs_breeze_lean_at's units: a full eddy band bends a 15 m top
// about 2 m, springing back as the grass does.
const float ZS_TREE_REACT = 0.4;
// The fast shake of a crown stirred full (a share of the model's height).
const float ZS_TREE_SHIVER = 0.03;
// How much further a crown goes for a hard shove (a push over about 1).
const float ZS_TREE_HARD = 0.9;

float zs_tree_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float zs_tree_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(zs_tree_hash(i), zs_tree_hash(i + vec2(1.0, 0.0)), f.x),
		mix(zs_tree_hash(i + vec2(0.0, 1.0)), zs_tree_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// How much of the wind the woods take now: 0 off, about 1 in the default breeze.
float zs_tree_air() {
	return zs_tree_alive * clamp(zs_breeze / 0.53, 0.0, 2.0);
}

// 0..1 (times zs_tree_air): how hard a gust wave is on the tree standing at
// `root` (world x, z), `lag` s behind the air there (a tall tree's top lags).
float zs_tree_wave(vec2 root, float lag) {
	float air = zs_tree_air();
	if (air <= 0.0) return 0.0;
	vec2 dir = zs_wind_direction;
	float travel = (zs_gust_distance - zs_gust_speed * lag) * ZS_TREE_WAVE_PACE;
	float along = dot(root, dir) - travel;
	float across = dot(root, vec2(-dir.y, dir.x));
	vec2 p = vec2(across, along) / ZS_TREE_WAVE_PATCH;
	float wander = zs_tree_noise(p * vec2(1.6, 0.8)) * 5.0;
	float crest = smoothstep(0.35, 0.95, 0.5 + 0.5 * sin(along * TAU / ZS_TREE_WAVE_LENGTH + wander));
	// Stretches of each front blow harder, others hardly at all.
	float patch = smoothstep(0.2, 0.6, zs_tree_noise(p * 1.2 + vec2(11.3, 4.7)));
	return crest * patch * air;
}

// The grass's push at a tree's foot (world x, z, in lean units), and `stir`
// 0..1, how hard it is stirred (for the boughs and the sheen).
vec2 zs_tree_react(vec2 root, out float stir) {
	stir = 0.0;
	float alive = min(zs_tree_alive, 2.0);
	if (alive <= 0.0 || !zs_react_live()) return vec2(0.0);
	vec3 r = zs_react_at(root);
	stir = clamp(length(r.xy) * 0.8 + max(r.z, 0.0) * 0.4, 0.0, 1.0) * min(alive, 1.0);
	// Shoved hard (more than the wind's bands do) it goes over further.
	float hard = 1.0 + ZS_TREE_HARD * smoothstep(0.7, 1.2, length(r.xy));
	return r.xy * ZS_TREE_REACT * alive * hard;
}

// A bough's own motion, as an offset in the tree's model space: each bough
// bobs on its own beat (its phase from its turn about the trunk and its
// height), most at its tip, further when a wave is on it. `phase` is the
// tree's own; `wave` zs_tree_wave there.
// `lift` out: -1..1, the bough's bob now (up shows its underside).
vec3 zs_tree_bough(vec3 vertex, float phase, float wave, out float lift) {
	lift = 0.0;
	float air = zs_tree_air();
	float r = length(vertex.xz);
	float reach = r / ZS_BOUGH_REACH;
	float tip = smoothstep(0.15, 1.0, reach) * reach;
	if (air <= 0.0 || tip <= 0.0) return vec3(0.0);
	// A whole number of turns, so the beat is continuous across atan's seam.
	float turn = atan(vertex.z, vertex.x);
	float own = turn * 3.0 + vertex.y * 2.5 + phase;
	float t = zs_motion_time;
	float pace = ZS_BOUGH_PACE;
	lift = sin(t * pace + own) * 0.8 + sin(t * pace * 1.53 + own * 1.9) * 0.2;
	float bob = mix(ZS_BOUGH_BOB.x, ZS_BOUGH_BOB.y, wave) * min(air, 1.5);
	// Up and down at the tip, swinging in and out a little with it.
	vec2 out_dir = vertex.xz / max(r, 1e-3);
	float dy = tip * (bob * lift + wave * 0.04);
	vec2 dxz = out_dir * tip * bob * 0.35 * sin(t * pace * 0.83 + own * 1.3);
	return vec3(dxz.x, dy, dxz.y);
}

// The crown's light where a wave lifts its boughs: a little paler and cooler,
// the needles' undersides. `sheen` 0..1 (how hard the crest is on it).
vec3 zs_tree_sheen(vec3 albedo, float sheen) {
	vec3 under = albedo * (1.0 + ZS_TREE_SHEEN * vec3(0.9, 1.2, 1.5)) + vec3(0.006, 0.01, 0.012) * ZS_TREE_SHEEN * 5.0;
	return mix(albedo, under, clamp(sheen, 0.0, 1.5));
}
#endif
