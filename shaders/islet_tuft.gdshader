shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// The islet unit's grass tufts (scripts/kit_isle/islet_unit.gd): blades
// dark at the root, the instance's straw or sage at the tip, swaying by
// height in a slow breeze. The normal leans up so the clump reads lit.
uniform float sway = 0.06;
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


void vertex() {
	float h = UV.y;
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = wp.x * 0.37 + wp.z * 0.21;
	VERTEX.x += sin(TIME * 1.4 + ph) * sway * h * h;
	VERTEX.z += cos(TIME * 1.1 + ph * 1.3) * sway * 0.7 * h * h;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.6));
}

void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * islet_hemi(vec3(0.0, 0.6, 0.0)) * 0.9;
	ROUGHNESS = 1.0;
	BACKLIGHT = COLOR.rgb * 0.35;
}
