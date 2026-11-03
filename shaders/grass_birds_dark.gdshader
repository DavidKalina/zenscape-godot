shader_type spatial;
// The grass flocks' dark bird (scripts/endless/dark_bird_body.gd). Near black,
// with a glossy feather that takes the sun and the sky close to the eye, and
// goes dull with distance till only the outline is left.
render_mode skip_vertex_transform, cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://shaders/grass_birds.gdshaderinc"

// The feather's colour, the two tints of its sheen, and the distances (m)
// the sheen is whole and gone by.
uniform vec3 feather = vec3(0.014,0.015,0.02);
uniform vec3 sheen_a = vec3(0.1,0.16,0.13);
uniform vec3 sheen_b = vec3(0.17,0.09,0.2);
uniform vec2 sheen_at = vec2(22.0,85.0);

void fragment() {
	float near = 1.0-smoothstep(sheen_at.x,sheen_at.y,length(VERTEX));
	// The tint turns with the feather against the eye.
	float turn = 0.5+0.5*sin(dot(NORMAL,VIEW)*5.0+NORMAL.y*3.0);
	ALBEDO = mix(feather,mix(sheen_a,sheen_b,turn),near*0.5);
	METALLIC = near*0.55;
	ROUGHNESS = mix(0.85,0.42,near);
	SPECULAR = mix(0.12,0.4,near);
	// The sky's mirror held back, or it paints the wing blue; the sun's glint stays.
	AO = 0.3;
	AO_LIGHT_AFFECT = 0.0;
}
