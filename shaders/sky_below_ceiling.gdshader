shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// The cloud sea seen from beneath (scripts/sky_below.gd): one plane just
// over the swap, kept over the eye, solid so it hides the islands' world
// above. Near, the cloud volume (scripts/cloud_volume.gd) draws the heaps'
// own undersides in front of it, and this is what shows through their
// gaps: the open sky over the cloud sea, its blue and the sun's glow, veiled
// here and there by thin sunlit cloud (zsBelowOpen). Further out, past
// where the volume hands over (`volume_reach`, 0 with no volume), it paints
// the undersides itself: round billows in rows, their hearts the deck's own
// shade (zsBelowDeck) and their rims lit, warm toward a low sun, and here
// and there a rift onto the same open sky, its edges silvered; all drifting
// slowly as the heaps do and settling far out to the deck's mean, which the
// volume's far heaps settle to as well, so the handover never shows, and
// on into the air at the horizon. At night the rifts open on the night sky
// and its stars, their rims faintly aglow.
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
// The islands' swaps added up (SkyIslands `origin`, xz), taken off, so the
// billows stay put in the world on a swap.
uniform vec2 home = vec2(0.0);
// The billows' cell (m), how dark their hearts and how bright their rims.
uniform float cell = 150.0;
uniform float heart = 0.58;
uniform float rim = 1.14;
// Rifts onto the open sky: their scale (m) and how much of the deck they open.
uniform float rift_scale = 900.0;
uniform float rifts = 0.3;
// The heaps' drift (m/s, as the cloud volume's DRIFT).
uniform vec2 drift = vec2(0.72, 0.42);
// How far out the cloud volume draws the heaps' undersides (m); past it,
// these painted ones take over.
uniform float volume_reach = 0.0;
// Where the billows have settled to the deck's mean, and where the deck has
// gone into the air (m).
const vec2 SETTLE = vec2(1800.0, 5200.0);
const vec2 AIR = vec2(3500.0, 8800.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ceiling_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ceiling_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ceiling_hash(i), ceiling_hash(i + vec2(1.0, 0.0)), f.x),
		mix(ceiling_hash(i + vec2(0.0, 1.0)), ceiling_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// The nearest billow's middle distance (0 at its heart, about 1 at its
// rim) over a jittered lattice, and the next nearest, for the creases.
vec2 billows(vec2 p) {
	vec2 g = floor(p);
	float a = 9.0;
	float b = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = g + vec2(float(x), float(y));
			vec2 middle = c + 0.2 + 0.6 * vec2(ceiling_hash(c), ceiling_hash(c + 17.3));
			float size = mix(0.6, 1.0, ceiling_hash(c + 5.1));
			float d = length(p - middle) / size;
			if (d < a) { b = a; a = d; } else if (d < b) { b = d; }
		}
	}
	return vec2(a, b);
}

// The night sky's stars through a rift: fixed to the view, soft points a
// pixel or two across, few and faint.
float stars(vec3 view) {
	vec2 sp = view.xz / max(view.y, 0.05) * 90.0;
	vec2 c = floor(sp);
	float h = ceiling_hash(c);
	vec2 at = c + 0.25 + 0.5 * vec2(ceiling_hash(c + 3.1), ceiling_hash(c + 9.7));
	float size = max(length(fwidth(sp)) * 0.9, 0.04);
	return step(0.93, h) * exp(-dot(sp - at, sp - at) / (size * size)) * mix(0.4, 1.0, ceiling_hash(c + 1.3));
}

void fragment() {
	vec2 p = world_position.xz - home - drift * zs_motion_time;
	vec3 view = normalize(world_position - CAMERA_POSITION_WORLD);
	float far = distance(world_position.xz, CAMERA_POSITION_WORLD.xz);
	float deep = zs_night * zs_celestial_clear;
	float golden = zsBelowGolden();
	float toward = zsBelowToSun(view);
	vec3 sun_hue = zsBelowSunHue();
	// Thin high cloud over the open sky, sunlit: more of it near the rifts'
	// edges, some drifting across their middles.
	float veil = ceiling_noise(p / 420.0 + 11.0) * 0.6 + ceiling_noise(p / 160.0 + 2.3) * 0.4;
	vec3 night_sky = vec3(stars(view)) * vec3(0.85, 0.9, 1.0) * deep * 0.9;
	// Near, the volume draws the heaps' undersides: here only what shows
	// through their gaps, the brighter cloud over them, lit through from
	// above (it is a sea, not a layer), and the open sky only where a rift
	// goes right through.
	// Overhead the thin cloud parts here and there onto the sky's own blue,
	// luminous pools between the heaps rather than a blank white; seen low,
	// toward the horizon, it stays the sunlit cloud.
	float pools = smoothstep(0.45, 0.85, view.y) * (1.0 - smoothstep(0.32, 0.72, veil));
	vec3 open = zsBelowOpen(view, 1.0 - 0.7 * pools) * mix(0.9, 1.06, veil);
	// The billows, two sizes, the small ones riding on the large.
	vec2 big = billows(p / cell);
	vec2 small = billows(p / (cell * 0.43) + 7.1);
	float body = smoothstep(1.05, 0.0, big.x) * 0.65 + smoothstep(1.05, 0.0, small.x) * 0.35;
	float crease = 1.0 - smoothstep(0.0, 0.4, big.y - big.x);
	vec3 deck = zsBelowDeck(view);
	// The rims catch the light coming through the thin cloud: whiter, and
	// warm toward a low sun, which lights the deck from under its edge.
	vec3 rim_col = deck * rim * mix(vec3(1.0), mix(vec3(1.0), sun_hue, 0.65) * 1.08, (0.2 + 0.6 * golden) * toward * (1.0 - deep));
	float hearts = mix(heart, 0.72, deep);
	vec3 under = mix(rim_col, deck * hearts * vec3(0.95, 0.96, 1.03), body * 0.85);
	under = mix(under, deck * hearts, crease * 0.2);
	// Rifts: where the cloud thins, broad openings onto the sky over it,
	// silvered at their edges by the sunlit cloud round them, their rims
	// faintly aglow at night (lavender to teal, slowly turning).
	float field = ceiling_noise(p / rift_scale) * 0.65 + ceiling_noise(p / (rift_scale * 0.37) + 3.7) * 0.35;
	float edge = 1.0 - rifts;
	float rift = smoothstep(edge, edge + 0.1, field) * (1.0 - body * 0.5);
	float core = smoothstep(edge + 0.06, edge + 0.2, field);
	vec3 gap = zsBelowOpen(view, 1.0 - core * 0.8) + night_sky * core;
	float rift_rim = smoothstep(edge - 0.06, edge, field) * (1.0 - smoothstep(edge, edge + 0.08, field));
	vec3 glow = mix(vec3(0.62, 0.52, 0.95), vec3(0.42, 0.85, 0.82), 0.5 + 0.5 * sin(p.x * 0.0011 + p.y * 0.0007 + zs_motion_time * 0.05));
	under += glow * rift_rim * deep * 0.06;
	under += deck * rift_rim * 0.22 * (1.0 - deep);
	under = mix(under, gap, rift);
	open = mix(open, gap, core);
	float painted = volume_reach > 0.0 ? smoothstep(volume_reach * 0.55, volume_reach * 0.95, far) : 1.0;
	vec3 col = mix(open, under, painted);
	// The billows settle to the deck's mean far out, a little lighter for
	// the rifts among them, and the deck goes on into the air at the horizon.
	col = mix(col, deck * mix(1.0, 1.08, rifts), smoothstep(SETTLE.x, SETTLE.y, far) * painted);
	col = mix(col, zsBelowAir(view), smoothstep(AIR.x, AIR.y, far));
	ALBEDO = scene_linear_for_display(clamp(col, vec3(0.0), vec3(0.98)));
}
