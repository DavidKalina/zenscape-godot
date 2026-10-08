shader_type spatial;
render_mode unshaded, blend_premul_alpha, cull_disabled, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// The lower world's air (scripts/sky_below.gd `air`): a sheet over the whole
// screen, drawn while under the cloud sea after the see-through pass's
// water and cloud, that lays on what the air does down there. The far
// islands and ranges stand in layers, each a step paler into the air
// (zsBelowAir); rock going up into the cloud fades into the deck's
// underside (zsBelowDeck) before it reaches it; and the sun comes down in
// shafts through the gaps in the heaps, gathered along the view from the
// cloud volume's shade map (shaders/cloud_volume_shadow.gdshaderinc), so
// each shaft stands under a gap the heaps really have. The deck keeps its
// own air (shaders/sky_below_ceiling.gdshader) and the cloud volume its
// own (shaders/cloud_volume_composite.gdshader `from_below`); the shafts
// lie over them both, being nearer.
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
#include "res://shaders/cloud_volume_shadow.gdshaderinc"

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
// The ocean's height and the deck's (scripts/sky_below.gd OCEAN, CEILING).
uniform float ocean = -300.0;
uniform float ceiling = -100.0;

// The air perspective: its reach (m) and how much of a thing it takes at
// most, so even the farthest range keeps a trace of itself.
const float REACH = 3000.0;
const float MOST = 0.72;
// Rock fades into the deck's underside over these heights (m).
const vec2 INTO_CLOUD = vec2(-205.0, -118.0);
// The shafts: how far out along the view they are gathered (m), how many
// taps, the distance over which the near ones outweigh the far (m), and
// how bright they stand.
const float SHAFT_REACH = 1200.0;
const int SHAFT_TAPS = 20;
const float SHAFT_NEAR = 380.0;
const float SHAFT_LIGHT = 0.5;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// The shafts along the view from `eye` for `len` metres: the light let
// through where the heaps leave a gap, weighted to the near ones (0 to 1).
float shafts(vec3 eye, vec3 rd, float len, vec2 fragcoord) {
	if (zs_cloud_shadow_at.w <= 0.0 || zs_cloud_shadow_light.y < 0.03) return 0.0;
	float reach = min(len, SHAFT_REACH);
	float jitter = fract(52.9829189 * fract(dot(fragcoord, vec2(0.06711056, 0.00583715))));
	float lit = 0.0;
	float weight = 0.0;
	for (int i = 0; i < SHAFT_TAPS; i++) {
		float t = (float(i) + jitter) / float(SHAFT_TAPS) * reach;
		vec3 p = eye + rd * t;
		float w = exp(-t / SHAFT_NEAR);
		weight += w;
		if (p.y > zs_cloud_shadow_light.w) continue;
		lit += smoothstep(0.5, 0.1, zs_cloud_volume_shade(p)) * w;
	}
	return lit / max(weight, 1e-4) * sqrt(reach / SHAFT_REACH);
}

void fragment() {
	vec3 eye = CAMERA_POSITION_WORLD;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 rd = normalize(mat3(INV_VIEW_MATRIX) * (view.xyz / view.w));
	float depth = texture(depth_texture, SCREEN_UV).r;
	float t = 1e9;
	if (depth > 0.0) {
		vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		t = length(behind.xyz / behind.w);
	}
	// The water is drawn after the depth is taken: stop at its face.
	if (rd.y < 0.0) t = min(t, (ocean - eye.y) / rd.y);
	vec3 point = eye + rd * t;
	bool open = t > 1e8 || point.y > ceiling - 1.5;
	float layered = open ? 0.0 : (1.0 - exp(-t / REACH)) * MOST;
	// Rock standing over the deck's height is the world above, seen past
	// the deck's far edge (the ring's ranges): the deck would hide it, so
	// the air does.
	if (t < 1e8 && point.y > ceiling + 3.0) layered = 1.0;
	float into = open ? 0.0 : smoothstep(INTO_CLOUD.x, INTO_CLOUD.y, point.y) * 0.9;
	vec3 air = scene_linear_for_display(clamp(zsBelowAir(rd), vec3(0.0), vec3(0.98)));
	vec3 deck = scene_linear_for_display(clamp(zsBelowDeck(rd), vec3(0.0), vec3(0.98)));
	// The sun's light down the shafts, brighter looking toward it.
	float day = 1.0 - zs_night * zs_celestial_clear;
	vec3 sun = zsBelowSunHue() * clamp(dot(zs_cloud_sun, vec3(0.2126, 0.7152, 0.0722)), 0.0, 1.5);
	float facing = 0.6 + 0.9 * pow(max(dot(rd, zs_cloud_shadow_light.xyz), 0.0), 4.0);
	vec3 light = scene_linear_for_display(sun * SHAFT_LIGHT * facing * day) * shafts(eye, rd, t, FRAGCOORD.xy);
	// mix(mix(scene, air, layered), deck, into), plus the shafts.
	float alpha = 1.0 - (1.0 - layered) * (1.0 - into);
	ALBEDO = air * layered * (1.0 - into) + deck * into + light;
	ALPHA = alpha;
}
