shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// The cloud sea seen from beneath (scripts/sky_below.gd): one plane just
// over the swap, kept over the eye, solid so it hides the islands' world
// above. Near, the cloud volume (scripts/cloud_volume.gd) draws the heaps'
// own undersides in front of it, and this is the light over them, bright
// where it shows through their gaps. Further out, past where the volume
// hands over (`volume_reach`, 0 with no volume), it paints the undersides
// itself: round billows in rows, their hearts thick and grey-blue in the
// overcast's own pearl (zsBelowAir), their rims lit where the cloud thins,
// and here and there a rift where the sunlit cloud shows through, all
// drifting slowly as the heaps do, and melting into the haze at the horizon.
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
// The islands' swaps added up (SkyIslands `origin`, xz), taken off, so the
// billows stay put in the world on a swap.
uniform vec2 home = vec2(0.0);
// The billows' cell (m), how dark their hearts and how bright their rims.
uniform float cell = 150.0;
uniform float heart = 0.7;
uniform float rim = 1.08;
// Rifts of sunlit cloud: their scale (m) and how much of the sky they open.
uniform float rift_scale = 900.0;
uniform float rifts = 0.32;
// The heaps' drift (m/s, as the cloud volume's DRIFT).
uniform vec2 drift = vec2(0.72, 0.42);
// How far out the cloud volume draws the heaps' undersides (m); past it,
// these painted ones take over.
uniform float volume_reach = 0.0;
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

void fragment() {
	vec2 p = world_position.xz - home - drift * zs_motion_time;
	vec3 view = normalize(world_position - CAMERA_POSITION_WORLD);
	float far = distance(world_position.xz, CAMERA_POSITION_WORLD.xz);
	vec3 air = zsBelowAir(view);
	// The light over the cloud, as it shows through a gap: the sunlit
	// cloud's own white, warmed by the sun's colour.
	vec3 lit = min(zs_cloud_sky * 0.95 + zs_cloud_sun * 0.55, vec3(1.0));
	lit = max(lit, air * 1.12);
	// The billows, two sizes, the small ones riding on the large.
	vec2 big = billows(p / cell);
	vec2 small = billows(p / (cell * 0.43) + 7.1);
	float body = smoothstep(1.05, 0.0, big.x) * 0.65 + smoothstep(1.05, 0.0, small.x) * 0.35;
	float crease = 1.0 - smoothstep(0.0, 0.18, big.y - big.x);
	vec3 under = air * mix(rim, heart, body);
	under = mix(under, air * heart * 0.92, crease * 0.5);
	// Rifts: where the cloud thins, broad patches of the light above.
	float field = ceiling_noise(p / rift_scale) * 0.65 + ceiling_noise(p / (rift_scale * 0.37) + 3.7) * 0.35;
	float rift = smoothstep(1.0 - rifts, 1.0 - rifts + 0.12, field) * (1.0 - body * 0.6);
	under = mix(under, lit, rift);
	// Near, the volume draws the heaps' undersides: here only the light
	// over them, which shows through their gaps.
	float painted = volume_reach > 0.0 ? smoothstep(volume_reach * 0.55, volume_reach * 0.95, far) : 1.0;
	vec3 col = mix(lit, under, painted);
	// The billows soften and melt into the overcast's haze far out.
	col = mix(col, air, smoothstep(2500.0, 8000.0, far));
	ALBEDO = scene_linear_for_display(clamp(col, vec3(0.0), vec3(0.98)));
}
