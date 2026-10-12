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
// Wet from wading or a swim (scripts/pilot_figure.gd `soak`): up to
// `wet_line` (m, in the rest position's height, so it rides the body) the
// cloth is darkened by `wet_dark`, `wet` 1 soaked drying back to 0.
uniform float wet = 0.0;
uniform float wet_line = 0.0;
uniform float wet_dark = 0.32;
// Lit of itself (the bracelets' stripes): emission as this share of the
// colour, clean over the paint.
uniform float glow = 0.0;
// Gone (the hat, flown off overhead as the pocket sail): not drawn.
uniform float gone = 0.0;
// The face (scripts/pilot_figure.gd drives these): two glowing pill eyes
// painted on the dark head, placed in the rest position (Blender metres:
// x right, y forward, z up; art/blender/pilot/pilot_build.py prints
// PILOT_EYES): the point between them on the head's front, each one's
// middle `eye_apart` out from it, `eye_half` its half height. The
// expressions, 0 to 1 each, morph the pills: `blink` shuts them to a line,
// `happy` bends them into ^ ^ arcs, `surprise` opens them wider and rounder,
// `squint` flattens them under lids slanting down to the middle.
uniform float eyes = 0.0;
uniform vec3 eye_at = vec3(0.0, 0.1898, 0.8627);
uniform float eye_apart = 0.0658;
uniform float eye_half = 0.0455;
uniform vec4 eye_colour : source_color = vec4(0.373, 0.902, 0.902, 1.0);
uniform float eye_glow = 2.4;
uniform float blink = 0.0;
uniform float happy = 0.0;
uniform float surprise = 0.0;
uniform float squint = 0.0;

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

// One eye's distance field (negative inside), in its half heights about
// its middle, x out from the face's middle.
float eye_field(vec2 q) {
	float hh = mix(mix(1.0, 0.6, squint) * (1.0 + 0.14 * surprise), 0.13, blink);
	vec2 b = vec2(0.4 + 0.14 * surprise + 0.08 * blink, hh);
	float r = min(b.x, b.y);
	vec2 d = abs(q) - b + r;
	float pill = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
	// The squint's lid, slanting down to the inner corner.
	float lid = q.y - (0.12 + 0.55 * q.x);
	pill = mix(pill, max(pill, lid), squint);
	// A ^ arc, rounded at its ends.
	vec2 c = q - vec2(0.0, -0.4);
	float arc = c.y > 0.0 ? abs(length(c) - 0.72) - 0.19 : length(vec2(abs(c.x) - 0.72, c.y)) - 0.19;
	return mix(pill, arc, happy);
}

void fragment() {
	if (gone > 0.5) discard;
	vec3 p = rest * paint_scale;
	float m = noise3(p) * 0.6 + noise3(p * 2.3 + 7.1) * 0.4;
	// Streaks: noise stretched along a slanting stroke.
	float s = noise3(vec3(p.x * 5.0 + p.z * 3.0, p.y * 0.8 - p.x * 0.6, p.z * 5.0 - p.y)) - 0.5;
	paint = m;
	vec3 base = albedo.rgb;
	base *= 1.0 + (m - 0.5) * 2.0 * mottle + s * 2.0 * streaks;
	// A part's own shift, a little warmer or cooler.
	base *= mix(vec3(1.03, 1.0, 0.96), vec3(0.97, 1.0, 1.04), own) ;
	base *= 1.0 - wet_dark * wet * (1.0 - smoothstep(wet_line - 0.03 + (m - 0.5) * 0.04, wet_line + 0.02, rest.z));
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
	if (glow > 0.0) {
		ALBEDO = albedo.rgb;
		EMISSION += albedo.rgb * glow;
	}
	if (eyes > 0.0) {
		vec2 e = vec2(abs(rest.x - eye_at.x) - eye_apart, rest.z - eye_at.z) / eye_half;
		float front = smoothstep(eye_at.y - 0.09, eye_at.y - 0.05, rest.y) * eyes;
		float d = eye_field(e);
		float aa = max(fwidth(d), 0.03);
		float lit = (1.0 - smoothstep(-aa, aa, d)) * front;
		float halo = exp(-max(d, 0.0) * 3.5) * front * 0.22;
		ALBEDO = mix(ALBEDO, eye_colour.rgb * 0.6, lit);
		EMISSION = mix(EMISSION, vec3(0.0), lit) + eye_colour.rgb * (lit * eye_glow + halo);
	}
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
