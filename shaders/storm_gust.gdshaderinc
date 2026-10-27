// The storm's gust front on the land (docs/design/endless-flight/spec-storm-
// front.md, lane gust): the hard wind rolling ahead of the storm's cloud
// (zs_storm_gust) and the lesser, gustier wind under it (zs_storm_amount),
// as a lean in zs_blow_at's units along the wind, for the breeze's lean
// (reference_wind zs_breeze_lean_wave: the near tufts and the trees) and the
// far grass's sheen and silver (grass_sheen, grass_silver). Not a drawn
// band: its edge is ragged along the line, its strength patchy across it,
// and inside it squalls roll downwind faster than the front, so the grass
// goes down in waves. Included by reference_wind (after zs_noise); nothing
// when the storm is off (zs_storm_on, one uniform branch).
#ifndef ZS_STORM_GUST
#define ZS_STORM_GUST
#include "res://shaders/storm_front.gdshaderinc"

// The lean at the band's peak, and under the core (a share of the amount).
const float ZS_STORM_LEAN = 1.7;
const float ZS_STORM_UNDER = 0.55;
// The squalls: crests this far apart (m), rolling downwind at this speed
// (m/s, faster than the front's 15), each line this long across.
const float ZS_STORM_SQUALL_LENGTH = 70.0;
const float ZS_STORM_SQUALL_SPEED = 26.0;
const float ZS_STORM_SQUALL_ACROSS = 160.0;
// How far the edge's line wanders ahead and behind (m).
const float ZS_STORM_RAG = 140.0;

// 0..~1.2: the storm's steady wind at `p` (world xz): the band and the
// blow under the core, ragged along the line and patchy across it, before
// the squalls. `d` out: the ragged distance from the edge.
float zs_storm_base(vec2 p, out float d) {
	d = 1.0e6;
	if (!zs_storm_on()) return 0.0;
	float along = zs_storm_along(p);
	float ends = zs_storm_ends(p);
	if (ends <= 0.0) return 0.0;
	// The edge's line, ragged: long bulges and shorter teeth.
	float rag = (zs_noise(vec2(along * 0.0035, 3.7)) - 0.5) * 2.0 * ZS_STORM_RAG
		+ (zs_noise(vec2(along * 0.016, 9.1)) - 0.5) * 0.5 * ZS_STORM_RAG;
	d = zs_storm_d(p) + rag;
	float depth = zs_storm_shape.z;
	if (d > depth + 50.0) return 0.0;
	// The band: the outflow's first puffs far ahead, rising steeply to the
	// edge, dying under the shelf into the core's steadier blow.
	float ahead = zs_storm_ramp(depth, 0.0, d);
	float band = d > 0.0 ? ahead * ahead * (0.35 + 0.65 * ahead) : zs_storm_ramp(-ZS_STORM_GUST_BEHIND, 0.0, d);
	float under = ZS_STORM_UNDER * zs_storm_ramp(ZS_STORM_SHELF_AHEAD, ZS_STORM_CORE_FROM, d)
		* zs_storm_ramp(-zs_storm_shape.y - ZS_STORM_CLEAR, -zs_storm_shape.y, d);
	// Cells across the line: stretches where it blows harder, others where
	// it holds back.
	float cell = 0.5 + 0.7 * smoothstep(0.25, 0.75, zs_noise(vec2(along / ZS_STORM_SQUALL_ACROSS, d * 0.004 + 1.9)));
	return max(band, under) * ends * cell;
}

// 0..1 (mean about 0.4): the squalls at `p`, `lag` s behind the air there,
// a pixel `fp` m across: crests across the wind rolling down it faster than
// the front, their lines bent and broken by noise, each swelling and dying.
// Each train fades to its mean as the pixel outgrows it, the longest last,
// so far off the band still rolls in broad swells rather than shimmering.
float zs_storm_squall(vec2 p, float lag, float fp) {
	vec2 dir = zs_storm_line.zw;
	float along = zs_storm_along(p);
	float s = dot(p, dir) - ZS_STORM_SQUALL_SPEED * (zs_motion_time - lag);
	float bend = (zs_noise(vec2(along / 90.0, s / 400.0) + vec2(5.1, 0.7)) - 0.5) * 3.0;
	float l = ZS_STORM_SQUALL_LENGTH;
	vec3 crest = vec3(
		0.5 + 0.5 * sin(s * TAU / l + bend),
		0.5 + 0.5 * sin(s * TAU / (l * 3.1) + bend * 0.6 + 1.7),
		0.5 + 0.5 * sin(s * TAU / (l * 8.3) + bend * 0.3 + 4.1));
	vec3 lens = vec3(l, l * 3.1, l * 8.3);
	vec3 keep = vec3(1.0) - smoothstep(lens * 0.1, lens * 0.35, vec3(fp));
	crest = mix(vec3(0.5), crest, keep);
	float broken = mix(0.6, smoothstep(0.3, 0.7, zs_noise(vec2(along / 45.0, s / 60.0) + vec2(2.3, 8.8))), keep.x);
	float wide = zs_noise(vec2(along / 260.0, s / 300.0) + vec2(7.7, 1.1));
	float sq = smoothstep(0.3, 0.85, dot(crest, vec3(0.45, 0.35, 0.2)) + (wide - 0.5) * 0.4);
	return sq * (0.45 + 0.55 * broken);
}

// 0..~1.5: the storm's wind at `p` with its squalls (see zs_storm_squall).
float zs_storm_wind(vec2 p, float lag, float fp) {
	float d;
	float base = zs_storm_base(p, d);
	if (base <= 0.001) return 0.0;
	return base * (0.25 + 1.25 * zs_storm_squall(p, lag, fp));
}

// How much the storm's wind blows along the land's (zs_wind_direction).
float zs_storm_with_wind() {
	return max(dot(zs_storm_line.zw, zs_wind_direction), 0.0);
}

// The storm's lean at `p` along the land's wind, in zs_blow_at's units, for
// the breeze's lean (the tufts and the trees).
float zs_storm_lean(vec2 p, float lag, float fp) {
	if (!zs_storm_on()) return 0.0;
	return zs_storm_wind(p, lag, fp) * ZS_STORM_LEAN * zs_storm_with_wind();
}

// The far grass's sheen (grass_sheen zs_sheen_field's -1..1 lean): the
// squalls' crests laid bright, the troughs between them darker than the
// mean, so the band rolls in light and dark swells.
// A shader that draws the storm on its grass with zs_storm_ground (the
// painted ground) defines ZS_STORM_GROUND_OWN before reference_wind, and
// this and zs_storm_silver give nothing there (one storm field a pixel).
float zs_storm_sheen(vec2 p, float fp) {
#ifdef ZS_STORM_GROUND_OWN
	return 0.0;
#endif
	if (!zs_storm_on()) return 0.0;
	float d;
	float base = zs_storm_base(p, d);
	if (base <= 0.001) return 0.0;
	return base * (0.3 + 2.4 * (zs_storm_squall(p, 0.0, fp) - 0.4)) * zs_storm_with_wind();
}

// The grass's undersides (grass_silver zs_silver_drive's drive): turned up
// on the squalls' crests, less between them.
float zs_storm_silver(vec2 p, float fp) {
#ifdef ZS_STORM_GROUND_OWN
	return 0.0;
#endif
	if (!zs_storm_on()) return 0.0;
	float d;
	float base = zs_storm_base(p, d);
	if (base <= 0.001) return 0.0;
	return base * (0.05 + 1.5 * zs_storm_squall(p, 0.0, fp)) * zs_storm_with_wind();
}

// The painted ground's grass (endless_ground, past the tufts) under the
// storm's wind, `c` its colour (linear), a pixel `fp` m across: the flattened
// grass paler and greyer with its undersides up, the squalls rolling over it
// as bright swells with darker troughs between, so the band reads from far
// off where the watercolour has taken the sheen.
vec3 zs_storm_ground(vec3 c, vec2 p, float fp) {
	if (!zs_storm_on()) return c;
	float d;
	float base = zs_storm_base(p, d) * zs_storm_with_wind();
	if (base <= 0.001) return c;
	float swell = (zs_storm_squall(p, 0.0, fp) - 0.4) * 2.0 * min(base, 1.0);
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 under = mix(c, vec3(l) * vec3(0.92, 1.04, 1.0), 0.6) * 1.35;
	c = mix(c, under, clamp(min(base, 1.0) * 0.3 + max(swell, 0.0) * 0.45, 0.0, 0.8));
	return c * (1.0 + clamp(swell, -0.7, 1.0) * 0.2);
}
#endif
