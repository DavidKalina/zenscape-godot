shader_type spatial;
render_mode diffuse_lambert;
// The pilot on foot (scripts/pilot_paint.gd, the model from art/blender/pilot/
// pilot_build.py): soft painted, not lacquered. The sun's light falls in a few
// soft bands (lit, half lit, shade) instead of a smooth gradient, a warm tint
// on the lit side; the shade takes the sky's hemisphere as the folk do
// (shaders/folk_surface.gdshaderinc: the world takes no ambient), cooled; a
// gentle sky rim on the edges; no gloss. Flat colours are broken up by a
// slow mottle and brush-like streaks laid in the body's REST position (its
// UV maps carry it, so the paint stays on the cloth as he moves), and a
// part's own number shifts its colour a touch, so neighbouring pieces of one
// colour read as painted separately; the band edges wander with the same
// noise, as a brush would leave them.
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;

uniform vec4 albedo : source_color = vec4(1.0);
// The shade's colour as a share of the lit (before the hemisphere's fill).
uniform float fill = 3.2;
// Warmth on the lit side, coolness in the shade.
uniform vec3 warm = vec3(1.06, 1.0, 0.9);
uniform vec3 cool = vec3(0.86, 0.92, 1.08);
// The bands: where the light turns to half and to full (in N.L), and how
// soft each step is.
uniform float half_at = -0.05;
uniform float full_at = 0.38;
uniform float soft = 0.09;
uniform float half_share = 0.55;
uniform float rim = 0.12;
// The sun's share (the bands' top), under 1 so the lit side doesn't burn out.
uniform float sun = 0.5;
// The paint: how strong the mottle and the streaks are, how big (per metre).
uniform float mottle = 0.1;
uniform float streaks = 0.07;
uniform float paint_scale = 9.0;
uniform float wobble = 0.08;
// Glass (the goggles' lenses): the sky and ground reflected, stronger at a
// glance (fresnel), a small catchlight from the bright sky above that slides
// over the lens as the view turns, and the sun's own glint. All of it is
// light the lens gives back, so it dims with the sky at night; it never
// glows of itself.
uniform float sheen = 0.0;

varying vec3 rest;
varying float own;

void vertex() {
	rest = vec3(UV.x, 1.0 - UV.y, UV2.x);
	own = UV2.y;
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

varying float paint;

void fragment() {
	vec3 p = rest * paint_scale;
	float m = noise3(p) * 0.6 + noise3(p * 2.3 + 7.1) * 0.4;
	// Streaks: noise stretched along a slanting stroke.
	float s = noise3(vec3(p.x * 5.0 + p.z * 3.0, p.y * 0.8 - p.x * 0.6, p.z * 5.0 - p.y)) - 0.5;
	paint = m;
	vec3 base = albedo.rgb;
	base *= 1.0 + (m - 0.5) * 2.0 * mottle + s * 2.0 * streaks;
	// A part's own shift, a little warmer or cooler.
	base *= mix(vec3(1.03, 1.0, 0.96), vec3(0.97, 1.0, 1.04), own) ;
	ALBEDO = clamp(base, 0.0, 1.0);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 hemi = mix(zs_hemi_ground, zs_hemi_sky, normal.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	float edge = smoothstep(0.6, 0.95, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	EMISSION = ALBEDO * cool * hemi * fill
		// The rim takes the sky's brightness, not its tint, so it doesn't
		// glare green or blue on the edges in the sun.
		+ mix(ALBEDO, vec3(1.0), 0.5) * dot(zs_hemi_sky, vec3(0.3333)) * zs_hemi_energy * edge * rim;
	if (sheen > 0.0) {
		vec3 view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
		vec3 r = reflect(-view, normal);
		float fresnel = 0.2 + 0.8 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		vec3 seen = mix(zs_hemi_ground * 0.6, zs_hemi_sky, smoothstep(-0.25, 0.5, r.y)) * zs_hemi_energy;
		float catchlight = smoothstep(0.93, 0.975, dot(r, normalize(vec3(0.3, 0.85, 0.4))));
		EMISSION += (seen * fresnel * 0.5 + zs_hemi_sky * zs_hemi_energy * catchlight * 1.2) * sheen;
	}
}

void light() {
	float nl = dot(NORMAL, LIGHT) + (paint - 0.5) * wobble * 2.0;
	float lit = mix(smoothstep(half_at - soft, half_at + soft, nl) * half_share, 1.0,
		smoothstep(full_at - soft, full_at + soft, nl));
	// Shadows step too, softly.
	float shadow = smoothstep(0.25, 0.65, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR * warm * lit * shadow * sun / PI;
	if (sheen > 0.0) {
		float glint = pow(max(dot(reflect(-LIGHT, NORMAL), VIEW), 0.0), 90.0);
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * glint * sheen * 0.4;
	}
}
