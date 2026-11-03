// The wind over the land by place and hour, for the shaders: the same field as
// scripts/endless/wind_field.gd `wind_at` (docs/design/endless-flight/
// spec-wild-wind.md), from the baked exposure (a texture over the world's
// square), the drifting patches' five blobs and the global factor now, all
// published by EndlessLook `_publish`. Stands on reference_globals alone, so
// the trees' tree_wind can include it too. A world with no field (w 0) reads
// zs_wind_strength and zs_breeze everywhere, as before.
#ifndef ZS_WIND_FIELD
#define ZS_WIND_FIELD
#include "res://shaders/reference_globals.gdshaderinc"

// x the field's factor now (WindField PEAK x now), y how far its baked
// exposure has come in (0..1; 0.5 everywhere before), z a fixed strength
// everywhere (--wind=X; under 0 none), w 1 when the world blows a field.
global uniform vec4 zs_wind_field;
// The exposure's texture: x, z of its corner (m), its side (m), and the bake's
// half side (the centre to its outermost cells, m).
global uniform vec4 zs_wind_rect;
global uniform sampler2D zs_wind_exposure : filter_linear, repeat_disable;
// The windy patches: x, z (m), radius (m), amount 0..1.
global uniform vec4 zs_wind_patch_0;
global uniform vec4 zs_wind_patch_1;
global uniform vec4 zs_wind_patch_2;
global uniform vec4 zs_wind_patch_3;
global uniform vec4 zs_wind_patch_4;

// WindField SHELTER, PATCH_ADD, REACH_FADE.
const float ZS_WIND_SHELTER = 0.12;
const float ZS_WIND_PATCH_ADD = 0.55;
const float ZS_WIND_REACH_FADE = 3000.0;

// The eye's breeze (reference_wind zs_breeze_air).
float zs_wind_eye_breeze() {
	return clamp(zs_breeze, 0.0, 2.5);
}

bool zs_wind_on() {
	return zs_wind_field.w > 0.5;
}

// How far `p` is inside the bake's land (1) rather than past it (0): there
// the world's own wind holds (WindField.reach).
float zs_wind_reach(vec2 p) {
	if (zs_wind_field.z >= 0.0) return 1.0;
	vec2 c = zs_wind_rect.xy + vec2(zs_wind_rect.z * 0.5);
	float d = max(abs(p.x - c.x), abs(p.y - c.y)) - zs_wind_rect.w;
	return 1.0 - smoothstep(0.0, ZS_WIND_REACH_FADE, d);
}

float zs_wind_blob(vec2 p, vec4 b) {
	vec2 d = p - b.xy;
	return b.w * exp(-dot(d, d) / max(b.z * b.z, 1.0));
}

// The field's strength at `p` (zs_wind_strength's 0..2 scale), WindField.wind_at.
float zs_wind_field_at(vec2 p) {
	if (zs_wind_field.z >= 0.0) return zs_wind_field.z;
	vec2 uv = (p - zs_wind_rect.xy) / max(zs_wind_rect.z, 1.0);
	float e = mix(0.5, textureLod(zs_wind_exposure, uv, 0.0).r, zs_wind_field.y);
	float spots = zs_wind_blob(p, zs_wind_patch_0) + zs_wind_blob(p, zs_wind_patch_1) + zs_wind_blob(p, zs_wind_patch_2)
		+ zs_wind_blob(p, zs_wind_patch_3) + zs_wind_blob(p, zs_wind_patch_4);
	return zs_wind_field.x * (mix(ZS_WIND_SHELTER, 1.0, e) + ZS_WIND_PATCH_ADD * min(spots, 1.0));
}

// The breeze plants lean in (zs_breeze's scale) for wind strength `w`
// (WindField.breeze_of).
float zs_wind_breeze_of(float w) {
	return clamp(0.06 + 0.7 * w, 0.06, 1.8);
}

// How far grass blows as one (grass_swell.x's share) for wind strength `w`
// (WindField.swell_of): calm grass stands, windy grass rolls in swells.
float zs_wind_swell_of(float w) {
	return smoothstep(0.25, 0.95, w);
}

// The wind's strength at `p`: the field's in its land, the world's own past it.
float zs_wind_local(vec2 p) {
	if (!zs_wind_on()) return zs_wind_strength;
	return mix(zs_wind_strength, zs_wind_field_at(p), zs_wind_reach(p));
}

// The breeze at `p` (zs_breeze_air's scale).
float zs_wind_breeze_at(vec2 p) {
	if (!zs_wind_on()) return zs_wind_eye_breeze();
	return mix(zs_wind_eye_breeze(), zs_wind_breeze_of(zs_wind_field_at(p)), zs_wind_reach(p));
}

// The share of a world's grass_swell that blows at `p` (1 with no field, and
// past its land).
float zs_wind_swell_at(vec2 p) {
	if (!zs_wind_on()) return 1.0;
	return mix(1.0, zs_wind_swell_of(zs_wind_field_at(p)), zs_wind_reach(p));
}

// The swell's undersides (grass_silver) are the Amberlands' straw: the field's
// grass keeps its own colours, so only this share of the swell's silver shows
// on its crests (the motion and sheen stay whole). 1 with no field and past
// its land, so the Amberlands keep all of theirs.
const float ZS_WIND_SILVER = 0.25;

// From high up the ground's paint mutes the sheen to 15% (endless_ground
// wc_up); in the field's land the swells keep this share of it where the
// grass rolls (`swell` the local grass_swell.x), so a windy slope reads from
// cruise height. 0 with no field and past its land.
const float ZS_WIND_UP_SHEEN = 0.8;
float zs_wind_up_sheen(vec2 p, float swell) {
	if (!zs_wind_on()) return 0.0;
	return ZS_WIND_UP_SHEEN * clamp(swell, 0.0, 1.0) * zs_wind_reach(p);
}
float zs_wind_silver_at(vec2 p) {
	if (!zs_wind_on()) return 1.0;
	return mix(1.0, ZS_WIND_SILVER, zs_wind_reach(p));
}
#endif
