shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// A dandelion seed on the air (scripts/dandelion_seeds.gd,
// docs/scenic/dandelions.md): a camera-facing soft parachute, a little star
// of fine hairs round a bright heart over a dark speck of seed, drawn out a
// touch along the way it moves. Soft and glowing, as the style rule has
// everything that floats: lit by the scene's light, it shines when the sun is
// behind it. Instance colour is the hairs' colour, its alpha the opacity;
// custom data is its velocity (world m/s) and, in w, its turn.
#include "res://shaders/reference_globals.gdshaderinc"
varying float opacity;
varying vec3 tint;
varying float turn;
varying float backlit;

void vertex() {
	opacity = COLOR.a;
	tint = COLOR.rgb;
	turn = INSTANCE_CUSTOM.w;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 forward = INV_VIEW_MATRIX[2].xyz;
	vec3 moving = INSTANCE_CUSTOM.xyz;
	moving -= forward * dot(moving, forward);
	float speed = length(moving);
	vec3 along = speed > 0.001 ? moving / speed : right;
	vec3 across = normalize(cross(forward, along));
	float stretch = 1.0 + clamp(speed * 0.12, 0.0, 0.8);
	vec3 world = centre + (along * VERTEX.x * stretch + across * VERTEX.y / sqrt(stretch)) * size;
	// Toward the sun, the hairs light up.
	vec3 to_seed = normalize(world - INV_VIEW_MATRIX[3].xyz);
	backlit = pow(max(dot(to_seed, -zs_key_direction), 0.0), 4.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float a = atan(q.y, q.x) + turn;
	// The hairs: a soft tuft, only faintly rayed, so up close it reads as a
	// parachute and from afar as a mote of light.
	float rays = mix(0.55, 1.0, pow(abs(cos(a * 6.0)), 4.0)) * smoothstep(0.05, 0.3, d) * (1.0 - smoothstep(0.45, 0.95, d));
	float halo = exp(-d * d * 4.0) * 0.45 * (1.0 - smoothstep(0.75, 1.0, d));
	float heart = exp(-d * d * 40.0);
	// The seed itself, a dark speck just below the heart.
	vec2 s = q - vec2(0.0, -0.22);
	float seed = exp(-dot(s, s) * 160.0);
	vec3 light = zs_key_irradiance / PI * zs_celestial_clear * zs_daylight + zs_hemi_sky * zs_hemi_energy / PI;
	float bright = dot(light, vec3(0.2126, 0.7152, 0.0722));
	vec3 lit = tint * (light * 0.95 + vec3(0.22));
	vec3 glow = mix(tint, vec3(1.0, 0.96, 0.86), 0.5) * (1.0 + 1.4 * bright) * (1.0 + 1.8 * backlit * zs_daylight);
	vec3 hairs = mix(lit, glow, clamp(0.35 + backlit, 0.0, 1.0));
	ALBEDO = mix(mix(hairs, glow, heart), lit * 0.35, seed * 0.8);
	ALPHA = clamp(rays * 0.45 + halo + heart * 0.6 + seed * 0.5, 0.0, 1.0) * opacity;
}
