shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
// The cloud sea's underside, seen from the lower world (scripts/
// sky_below.gd): one plane at the sea's height kept over the eye, the
// overcast's own pearl (zsBelowAir) where it is looked at, in slow soft
// billows a little lighter and darker, so it reads as cloud overhead and
// melts into the sky at the horizon. Solid, so it hides the islands' world
// above it.
#include "res://shaders/reference_sky_common.gdshaderinc"
#include "res://shaders/reference_display.gdshaderinc"
// The islands' swaps added up (SkyIslands `origin`, xz), taken off.
uniform vec2 home = vec2(0.0);
// How much lighter and darker the billows run.
uniform float billow = 0.08;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ceiling_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 p = (world_position.xz - home) / 140.0 + vec2(zs_flow_time * 0.004, 0.0);
	float shade = ceiling_noise(p) * 0.6 + ceiling_noise(p * 2.7 + 17.0) * 0.4 - 0.5;
	vec3 view = normalize(world_position - CAMERA_POSITION_WORLD);
	float far = distance(world_position, CAMERA_POSITION_WORLD);
	shade *= 1.0 - smoothstep(600.0, 3000.0, far);
	vec3 air = zsBelowAir(view) * (1.0 + billow * shade * 2.0);
	ALBEDO = scene_linear_for_display(clamp(air, vec3(0.0), vec3(0.98)));
}
