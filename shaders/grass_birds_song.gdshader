shader_type spatial;
// The grass flocks in the songbird's body (--bird-look=song): its meshes
// (scripts/songbird_body.gd) merged, its look as in shaders/endless_birds.gdshader.
render_mode skip_vertex_transform, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/grass_birds.gdshaderinc"

uniform float bird_roughness = 0.92;
uniform float backlight = 0.45;
uniform float fill = 0.18;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = bird_roughness;
	BACKLIGHT = COLOR.rgb*backlight;
	EMISSION = COLOR.rgb*fill*0.25;
}
