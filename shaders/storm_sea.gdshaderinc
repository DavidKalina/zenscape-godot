// The storm's gust front on the sea (docs/design/endless-flight/spec-storm-
// front.md, lane gust): in and behind the gust band the water roughens and
// darkens, breaks into whitecaps and wind-streaks of foam, and spray blows
// off the crests as a low pale veil. The squalls that flatten the grass
// (storm_gust zs_storm_wind) run over the water too, as dark rough bands.
// Shader only: the sea's heave (and so the swell the plane skims) is left
// alone. Include after reference_wind (storm_gust); nothing when the storm
// is off.
#ifndef ZS_STORM_SEA
#define ZS_STORM_SEA

// How much rougher the chop gets at full storm (a factor on zs_sea_air).
const float ZS_STORM_SEA_CHOP = 1.8;
// How dark and grey the water goes at full storm.
const float ZS_STORM_SEA_DARK = 0.5;
const float ZS_STORM_SEA_GREY = 0.7;

// 0..1: how hard the storm works the sea at `p`, a pixel `footprint` m across.
float zs_storm_sea(vec2 p, float footprint) {
	if (!zs_storm_on()) return 0.0;
	float d;
	float base = zs_storm_base(p, d);
	if (base <= 0.001) return 0.0;
	// Over water the squalls land as dark blotches of rougher water (cat's
	// paws) racing downwind, not lines.
	vec2 dir = zs_storm_line.zw;
	vec2 q = vec2(dot(p, dir) - ZS_STORM_SQUALL_SPEED * zs_motion_time, zs_storm_along(p));
	float paw = zs_noise(q / vec2(70.0, 110.0) + vec2(3.3, 7.1)) * 0.65 + zs_noise(q / vec2(26.0, 38.0) + vec2(9.2, 0.4)) * 0.35;
	paw = mix(0.5, paw, 1.0 - smoothstep(6.0, 30.0, footprint));
	return clamp(base * (0.55 + 0.9 * smoothstep(0.35, 0.75, paw)), 0.0, 1.0);
}

// The water's own colour (scene-linear) darkened and greyed by the storm.
vec3 zs_storm_sea_tone(vec3 water, float w) {
	if (w <= 0.0) return water;
	float l = dot(water, vec3(0.2126, 0.7152, 0.0722));
	vec3 grey = vec3(l) * vec3(0.92, 1.0, 0.98);
	return mix(water, grey, ZS_STORM_SEA_GREY * w) * (1.0 - ZS_STORM_SEA_DARK * w);
}

// 0..1: the storm's foam at `p`: breaking caps riding downwind and, near,
// wind-streaks (thin lanes of old foam drawn out along the wind), more as
// `w` rises, fading to their mean cover as the pixel (`footprint` m)
// outgrows them. `lift` -1..1 how high on the swell (caps break on crests).
float zs_storm_caps(vec2 p, float t, float w, float footprint, float lift) {
	if (w <= 0.02) return 0.0;
	vec2 dir = zs_storm_line.zw;
	vec2 side = vec2(-dir.y, dir.x);
	float along = dot(p, dir);
	float across = dot(p, side);
	// The caps: spots a few metres across where two drifting layers meet,
	// so each one breaks, spreads and fades as they slide apart.
	float a = zs_noise(vec2(along - t * 6.0, across) / vec2(4.5, 3.0) + vec2(1.7, 4.2));
	float b = zs_noise(vec2(along - t * 3.5, across) / vec2(2.6, 2.2) + vec2(8.3, 0.6));
	float c = zs_noise(vec2(along - t * 9.0, across) / vec2(22.0, 14.0) + vec2(4.4, 2.2));
	float spot = a * b * (0.55 + 0.9 * c) + lift * 0.06;
	float edge = mix(0.62, 0.36, w);
	float caps = smoothstep(edge, edge + 0.08, spot);
	// The streaks: lanes of old foam drawn out along the wind, near only.
	float lane = zs_noise(vec2(across / 1.6, along / 40.0 - t * 0.05) + vec2(3.3, 9.9));
	float streak = smoothstep(0.66, 0.8, lane) * smoothstep(0.4, 0.9, w)
		* smoothstep(0.35, 0.75, zs_noise(vec2(along - t * 5.0, across) / vec2(18.0, 6.0) + vec2(0.4, 5.5)))
		* (1.0 - smoothstep(0.12, 0.35, footprint));
	float near = max(caps, streak * 0.5);
	// Far off: their mean cover, an even pale speckle.
	float mean = 0.04 + 0.22 * w * w;
	return mix(near, mean, smoothstep(0.6, 3.0, footprint)) * w;
}

// The spray blown off the crests: pale rags just downwind of the caps, and
// far off a faint low sheen of it over the rough water, thicker seen low
// along it. On the final colour (display space); `light` the scene light.
vec3 zs_storm_spray(vec3 display_color, vec2 p, float t, float w, float footprint, vec3 eye, vec3 light) {
	if (w <= 0.05) return display_color;
	vec2 dir = zs_storm_line.zw;
	vec2 side = vec2(-dir.y, dir.x);
	// The caps' own field slid downwind and stretched: the spray off them.
	float along = dot(p, dir);
	float across = dot(p, side);
	float a = zs_noise(vec2(along - t * 6.0 - 2.5, across) / vec2(9.0, 3.4) + vec2(1.7, 4.2));
	float b = zs_noise(vec2(along - t * 14.0, across) / vec2(5.0, 2.5) + vec2(2.9, 6.1));
	float rag = smoothstep(0.45, 0.85, a * (0.6 + 0.6 * b)) * (1.0 - smoothstep(0.3, 1.5, footprint));
	float graze = 1.0 - clamp(eye.y * 2.5, 0.0, 1.0);
	float sheen = w * w * 0.12 * graze * smoothstep(0.3, 2.0, footprint);
	float veil = max(rag * w * w * 0.3, sheen);
	return mix(display_color, zs_scene_to_display(light * vec3(0.85, 0.9, 0.92)), clamp(veil, 0.0, 0.4));
}
#endif
