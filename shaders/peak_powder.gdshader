shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// A puff of powder thrown off the Peak's snow (scripts/endless/peak_snow.gd): a
// camera-facing soft lump that rises, slows, swells and thins. Nothing moves
// it on the CPU: each instance holds where and how it was thrown and the
// vertex shader works out where it is from its age, so a puff costs one
// write when thrown and none after, on the GDScript and the native path
// alike. Per instance:
//   transform origin  where it was thrown (world)
//   transform x       the throw (m/s, world)
//   transform y       x the ground's y there, y a seed 0..1
//   COLOR             born s, life s, size at first (m), size at last (m)
//   CUSTOM            opacity, drag (1/s), rise it keeps (m/s), -
#include "res://shaders/reference_globals.gdshaderinc"

uniform float now = 0.0;
// The air it drifts off on (m/s, xz).
uniform vec2 air = vec2(0.0);

varying float opacity;
varying float seed;
varying float spin;

void vertex() {
	vec3 from = MODEL_MATRIX[3].xyz;
	vec3 throw = MODEL_MATRIX[0].xyz;
	float ground = MODEL_MATRIX[1].x;
	seed = MODEL_MATRIX[1].y;
	float age = now - COLOR.x;
	float life = COLOR.y;
	float u = age / max(life, 0.01);
	if (age < 0.0 || u >= 1.0) {
		// Spent: nothing drawn.
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
		opacity = 0.0;
	} else {
		float drag = INSTANCE_CUSTOM.y;
		float slow = (1.0 - exp(-drag * age)) / drag;
		vec3 w = vec3(air.x, 0.0, air.y);
		vec3 at = from + (throw - w) * slow + w * age;
		at.y += INSTANCE_CUSTOM.z * age;
		at.y = max(at.y, ground + 0.4);
		float size = mix(COLOR.z, COLOR.w, 1.0 - exp(-1.6 * age));
		// A slow turn, so a lump's shape doesn't stay put.
		spin = seed * 6.2831853 + (seed - 0.5) * age * 1.4;
		float c = cos(spin);
		float s = sin(spin);
		vec2 v = vec2(VERTEX.x * c - VERTEX.y * s, VERTEX.x * s + VERTEX.y * c);
		vec3 world = at + (INV_VIEW_MATRIX[0].xyz * v.x + INV_VIEW_MATRIX[1].xyz * v.y) * size;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
		float eye = distance(world, INV_VIEW_MATRIX[3].xyz);
		opacity = INSTANCE_CUSTOM.x * smoothstep(0.0, 0.1, u) * pow(1.0 - u, 1.4) * smoothstep(1.5, 9.0, eye);
	}
	// (spatial wants VERTEX untouched for its own passes; POSITION rules here.)
}

float lump(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	if (d >= 1.0 || opacity <= 0.0) discard;
	// Billows in the edge, so a puff isn't a disc.
	vec2 s = q * 2.1 + seed * 53.0;
	float billow = lump(s) * 0.62 + lump(s * 2.3 + 7.0) * 0.38;
	float body = smoothstep(1.0, 0.25, d + (billow - 0.5) * 0.85);
	// The sun's share falls off away from it across the puff, the sky's stays.
	vec2 to_sun = vec2(dot(zs_sun_direction, INV_VIEW_MATRIX[0].xyz), dot(zs_sun_direction, INV_VIEW_MATRIX[1].xyz));
	float side = clamp(0.62 + dot(vec2(q.x, -q.y), to_sun) * 0.42 + (billow - 0.5) * 0.3, 0.0, 1.0);
	// Unshaded: this is the light it ends up with. The sky's fill as snow takes it
	// (PSNOW_FILL), and the sun's as white with a warm edge, not the sun's colour.
	vec3 sun = zs_key_irradiance / PI * zs_celestial_clear * zs_daylight * 0.52;
	sun = mix(sun, vec3(dot(sun, vec3(0.2126, 0.7152, 0.0722))) * vec3(1.02, 1.0, 0.96), 0.85);
	vec3 sky = zs_hemi_sky * zs_hemi_energy / PI * vec3(5.2, 5.0, 4.6);
	ALBEDO = sky + sun * side;
	ALPHA = clamp(body * opacity, 0.0, 1.0);
}
