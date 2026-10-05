shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// The glide's clouds (scripts/sky_clouds.gd): heaps of soft puffs drifting
// in the open air between the islands. Each puff faces the eye, is soft and
// a little ragged at its edge, and takes the clouds' own light: the sky's
// colour all over, the sun's on the side and tops that face it, a cool
// shade underneath. Up close a puff thins away, so flying into a cloud is a
// soft white-out (the vapour, scripts/sky_flight.gd), never a flat card.
// Instance custom data: xyz the puff's offset from its cloud's middle as a
// share of the cloud's size (y up), w a seed. The instance transform's
// origin is the puff's centre, its basis x's length the puff's radius and
// y's the cloud's size. Clouds drift and wrap round the field (`field`),
// a whole cloud at a time.
#include "res://shaders/reference_globals.gdshaderinc"
#include "res://shaders/glide_haze.gdshaderinc"

uniform float strength = 1.0;
// Metres a second the clouds drift on the breeze.
uniform vec2 drift = vec2(0.6, 0.3);
// The field's corner and size in the plate plane, in metres before `shift`.
uniform vec4 field = vec4(-1000.0, -1000.0, 2000.0, 2000.0);
// How far the islands' swaps have moved the world (SkyIslands `arrive`).
// The node itself stays at the origin, so the wrap can work in one frame.
uniform vec3 shift = vec3(0.0);
// How far onto a landform's gentler haze (glide_haze.gdshaderinc
// zs_glide_fog_far): 1 for the cloud wrapped round a sky peak's foot
// (scripts/sky_peaks.gd), so it fades with the rock it hugs.
uniform float haze_far = 0.0;
// Within this many metres of the scene behind it, a puff thins away, so
// where it meets rock it is soft, never a cut card. 0 leaves it as it was.
uniform float soft_depth = 0.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// The towering cumulus near the eye (scripts/sky_towers.gd `screens`),
// drawn before these: each a column, global x, z, radius (0 none), and its
// span of heights. A puff seen through one fades by how much of it stands
// between, so it never shows through the tower, nor through the fog round
// an eye inside one.
uniform vec4 towers[4];
uniform vec2 tower_spans[4];
// How deep the eye itself is in a tower's fog (0 to 1): the puffs beyond
// it go dim behind the fog round the eye.
uniform float veiled = 0.0;

varying vec2 across;
varying float opacity;
varying vec3 shade;
varying float seed;

float puff_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float puff_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(puff_hash(i), puff_hash(i + vec2(1.0, 0.0)), f.x),
		mix(puff_hash(i + vec2(0.0, 1.0)), puff_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	vec4 data = INSTANCE_CUSTOM;
	seed = data.w;
	float radius = length(MODEL_MATRIX[0].xyz);
	float size = length(MODEL_MATRIX[1].xyz);
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 home = origin - data.xyz * size;
	vec2 moved = home.xz + drift * zs_motion_time;
	vec2 wrapped = field.xy + mod(moved - field.xy, field.zw);
	vec3 centre = vec3(wrapped.x, home.y, wrapped.y) + data.xyz * size + shift;
	// A slow swell, each puff on its own beat.
	radius *= 1.0 + 0.06 * sin(zs_motion_time * 0.11 + seed * 31.0);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * radius * 2.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	across = VERTEX.xy * 2.0;
	float away = distance(CAMERA_POSITION_WORLD, centre);
	// Thinned away close up; gone in the far haze.
	opacity = smoothstep(radius * 0.35, radius * 1.4, away) * (1.0 - smoothstep(2600.0, 3000.0, away)) * strength;
	// Into the glide's haze with distance (glide_haze.gdshaderinc): drawn
	// over the open sky, which the display haze leaves be, a far cloud melts
	// away into the sky behind it rather than standing out sharp.
	opacity *= 1.0 - zs_glide_fog_far(away, centre.y, haze_far) * zs_glide_haze.x;
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 ray = (centre - eye) / max(away, 1e-3);
	for (int i = 0; i < 4; i++) {
		if (towers[i].z <= 0.0) continue;
		vec2 o = eye.xz - towers[i].xy;
		float a = max(dot(ray.xz, ray.xz), 1e-6);
		float b = dot(o, ray.xz);
		float disc = b * b - a * (dot(o, o) - towers[i].z * towers[i].z);
		if (disc <= 0.0) continue;
		float t0 = max((-b - sqrt(disc)) / a, 0.0);
		float t1 = min((-b + sqrt(disc)) / a, away);
		float ta = (tower_spans[i].x - eye.y) / (abs(ray.y) > 1e-5 ? ray.y : 1e-5);
		float tb = (tower_spans[i].y - eye.y) / (abs(ray.y) > 1e-5 ? ray.y : 1e-5);
		t0 = max(t0, min(ta, tb));
		t1 = min(t1, max(ta, tb));
		opacity *= 1.0 - smoothstep(0.0, 50.0, t1 - t0);
	}
	opacity *= 1.0 - veiled * smoothstep(4.0, 30.0, away);
	// Light: the sky's colour all round, the sun's on the side and top
	// facing it, a cool shade at the base.
	vec3 offset = normalize(data.xyz + vec3(0.0, 0.25, 0.0));
	float sunward = clamp(dot(offset, normalize(zs_sun_direction + vec3(0.0, 1e-4, 0.0))) * 0.5 + 0.5, 0.0, 1.0);
	float height = clamp(data.y * 1.4 + 0.5, 0.0, 1.0);
	vec3 sky = zs_cloud_sky * mix(0.72, 1.0, height);
	shade = sky * vec3(0.93, 0.95, 1.02) + zs_cloud_sun * (0.25 + 0.75 * sunward) * mix(0.45, 1.0, height) * 0.85;
}

void fragment() {
	// Soft, with a ragged rim that turns over slowly.
	float r = length(across);
	float rag = puff_noise(across * 2.2 + vec2(seed * 17.0, zs_motion_time * 0.05)) * 0.6 + puff_noise(across * 5.1 + seed * 9.0) * 0.4;
	float edge = 1.0 - smoothstep(0.45, 1.0, r + (rag - 0.5) * 0.45);
	// Thicker in the middle, so heaped puffs read as round.
	float body = edge * (0.55 + 0.45 * (1.0 - r * r));
	ALBEDO = shade * (0.92 + 0.12 * (1.0 - r));
	ALPHA = clamp(body, 0.0, 1.0) * 0.85 * opacity;
	if (soft_depth > 0.0) {
		float scene = texture(depth_texture, SCREEN_UV).r;
		vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
		float gap = -VERTEX.z + behind.z / behind.w;
		ALPHA *= clamp(-gap / soft_depth, 0.0, 1.0);
	}
}
