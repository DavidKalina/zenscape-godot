shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// The islet unit's turf, lip and drape (scripts/kit_isle/islet_unit.gd):
// dry straw and faded sage in drifts, darker hollows; the lip's earth face
// (vertex alpha 1) muted umber with pale root threads. Vertex rgb is a
// shade (the roll over the crest, the hem, the black under-face). `drape`:
// torn grass hanging under the hem, its tips straw, cut ragged.
uniform vec3 straw : source_color = vec3(0.82, 0.76, 0.58);
uniform vec3 sage : source_color = vec3(0.63, 0.67, 0.55);
uniform vec3 dry_dark : source_color = vec3(0.52, 0.47, 0.37);
uniform vec3 earth : source_color = vec3(0.33, 0.27, 0.21);
uniform vec3 earth_dark : source_color = vec3(0.17, 0.14, 0.12);
uniform float dry = 0.5;
uniform bool drape = false;
uniform vec3 seed_off = vec3(0.0);
// The game's sky light into the shade (the look rig's globals; the scene's
// own ambient is off): the hemisphere by the face's world normal, and the
// look pass's bounce off the cloud sea onto what faces down.
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
global uniform vec3 zs_cloud_sun;
#include "res://shaders/look_fill.gdshaderinc"
vec3 islet_hemi(vec3 wn) {
	return mix(zs_hemi_ground, zs_hemi_sky, wn.y * 0.5 + 0.5) * zs_hemi_energy / PI;
}


varying vec3 v_pos;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
				   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
				   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	v_pos = VERTEX + seed_off;
}

void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	float foot = length(fwidth(v_pos));
	float fine = 1.0 - smoothstep(0.03, 0.2, foot);
	float n1 = vnoise(v_pos * 0.18);
	float n2 = vnoise(v_pos * 0.8 + 7.0);
	float n3 = mix(0.5, vnoise(v_pos * 5.0 + 13.0), fine);
	// Drifts of sage in the straw; the driest patches darker and warmer.
	vec3 turf = mix(sage, straw, smoothstep(0.25, 0.75, n1 * 0.7 + n2 * 0.3 + (dry - 0.5) * 0.6));
	turf = mix(turf, dry_dark, smoothstep(0.65, 0.9, n2 * 0.6 + n1 * 0.4) * 0.5);
	// Mid-scale: darker sage hollows, paler bleached patches, bare dirt.
	float n4 = vnoise(v_pos * 0.45 + 31.0);
	turf = mix(turf, sage * 0.72, smoothstep(0.6, 0.85, n4) * 0.6);
	turf = mix(turf, straw * 1.12, smoothstep(0.62, 0.9, vnoise(v_pos * 0.33 + 57.0)) * 0.5);
	float dirt = smoothstep(0.74, 0.86, vnoise(v_pos * 0.7 + 91.0));
	turf = mix(turf, earth * 1.5, dirt * 0.55);
	turf *= 0.8 + 0.4 * n3;
	// The earth face: umber, banded, pale threads of root.
	float band = vnoise(vec3(v_pos.x * 2.0, v_pos.y * 9.0, v_pos.z * 2.0));
	vec3 e = mix(earth_dark, earth, band);
	float thread = smoothstep(0.82, 0.9, vnoise(vec3(v_pos.x * 11.0, v_pos.y * 1.5, v_pos.z * 11.0))) * fine;
	e = mix(e, vec3(0.55, 0.5, 0.43), thread * 0.6);
	vec3 c = mix(turf, e, COLOR.a);
	c *= COLOR.rgb;
	if (drape) {
		// Root (alpha 1) dark sod to straw tips; a ragged cut.
		c = mix(mix(straw, sage, n1) * (0.7 + 0.3 * n2), earth * 0.7, COLOR.a) * COLOR.rgb * 1.3;
		ALPHA_SCISSOR_THRESHOLD = 0.5;
		ALPHA = 0.8 + (vnoise(v_pos * vec3(18.0, 6.0, 18.0)) - 0.5) * 0.5 + COLOR.a * 0.4;
		BACKLIGHT = vec3(0.25, 0.22, 0.12);
	}
	ALBEDO = c;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	EMISSION = c * (islet_hemi(wn) + zs_look_bounce_light(wn));
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
