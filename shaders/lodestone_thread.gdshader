shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;
// A thread of falling water off the miniature (scripts/lodestone_miniatures.gd:
// the aqueduct's snapped channel spilling): a thin strip turned to face the
// eye about its own fall, streaks of pale water running down it, thinning
// and fraying as it falls and fading into mist at its foot. Its mesh is a
// strip: UV.x 0..1 across, UV.y 0 at the lip to 1 at the foot; `fall` its
// length and `width` its width at the lip (m, its own frame).
#include "res://shaders/reference_globals.gdshaderinc"

uniform float fall = 0.1;
uniform float width = 0.004;
uniform float clock = 0.0;
uniform float hum = 0.0;
uniform vec3 colour : source_color = vec3(0.62, 0.84, 0.97);

varying float lt_down;

void vertex() {
	lt_down = UV.y;
	// Bowing out off the lip a little, then straight down.
	vec3 at = vec3(sqrt(UV.y) * fall * 0.04, -UV.y * fall, 0.0);
	vec3 world = (MODEL_MATRIX * vec4(at, 1.0)).xyz;
	vec3 down = normalize((MODEL_MATRIX * vec4(0.0, -1.0, 0.0, 0.0)).xyz);
	vec3 across = normalize(cross(down, CAMERA_POSITION_WORLD - world) + vec3(1e-5));
	float scale = length(MODEL_MATRIX[0].xyz);
	world += across * (UV.x - 0.5) * width * scale * mix(1.0, 1.8, UV.y);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

float lt_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float x = (UV.x - 0.5) * 2.0;
	// Streaks running down: thin lines across, each its own pace.
	float lane = floor((UV.x) * 7.0);
	float pace = mix(1.4, 2.2, lt_hash(vec2(lane, 3.0)));
	float streak = 0.5 + 0.5 * sin((UV.y * 9.0 - clock * pace) * 6.2831853 * 0.5 + lane * 1.7);
	float body = 1.0 - smoothstep(0.3, 1.0, abs(x));
	float fray = mix(1.0, 0.35 + 0.65 * streak, smoothstep(0.1, 0.8, lt_down));
	float fade = smoothstep(0.0, 0.04, lt_down) * (1.0 - smoothstep(0.55, 1.0, lt_down));
	vec3 sky = zs_hemi_sky * zs_hemi_energy / PI;
	ALBEDO = colour * (sky * 0.9 + vec3(0.5 + 0.3 * hum)) + vec3(0.25) * (1.0 - fray);
	ALPHA = clamp(body * fray * fade, 0.0, 1.0);
}
