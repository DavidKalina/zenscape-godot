shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// A speck of pollen (scripts/pollen_cloud.gd): a camera-facing soft dot that
// draws out into a short wisp along the way it moves. Instance colour is the
// pollen's colour, its alpha the speck's opacity; custom data is its velocity
// (world m/s). Lit by the scene's light as the haze is, so it dims at night.
#include "res://shaders/reference_globals.gdshaderinc"
varying float opacity;
varying vec3 tint;

void vertex() {
	opacity = COLOR.a;
	tint = COLOR.rgb;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 forward = INV_VIEW_MATRIX[2].xyz;
	// The wisp: stretched along its velocity as the camera sees it, thinner
	// the longer it draws out.
	vec3 moving = INSTANCE_CUSTOM.xyz;
	moving -= forward * dot(moving, forward);
	float speed = length(moving);
	vec3 along = speed > 0.001 ? moving / speed : right;
	vec3 across = normalize(cross(forward, along));
	float stretch = 1.0 + clamp(speed * 0.35, 0.0, 3.0);
	vec3 world = centre + (along * VERTEX.x * stretch + across * VERTEX.y / sqrt(stretch)) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float soft = exp(-d * d * 4.0) * (1.0 - smoothstep(0.7, 1.0, d));
	float core = exp(-d * d * 22.0);
	vec3 light = zs_key_irradiance / PI * zs_celestial_clear * zs_daylight + zs_hemi_sky * zs_hemi_energy / PI;
	// Lit fluff with a glint at its heart: the grain catches the sun and
	// shines past white, so the cloud reads as motes of light rather than a
	// grey smudge. A little light of its own keeps it golden at dusk.
	float bright = dot(light, vec3(0.2126, 0.7152, 0.0722));
	vec3 lit = tint * (light * 0.9 + vec3(0.3));
	vec3 glint = mix(tint, vec3(1.0, 0.97, 0.88), 0.55) * (1.3 + 1.6 * bright);
	ALBEDO = mix(lit, glint, core);
	ALPHA = clamp(soft * 0.85 + core * 0.4, 0.0, 1.0) * opacity;
}
