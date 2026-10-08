shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The gothic ruins' stone and growth (scripts/ruin_kit.gd): faceted blocks
// and ivy coloured by their vertices, lit as the sky folk and the airship
// are (shaders/folk_surface.gdshaderinc), so a face in shade takes the sky's
// hemisphere instead of going black; a plain Lambert terminator, not the
// folk's wrapped one, so each cut face reads as its own plane.
#define ZS_FOLK_VERTEX_COLOR
// The halls' sheltered stone (scripts/ruin_kit_hall.gd sets each face's
// shelter in its vertex alpha): the light from outside bouncing round under
// the roof, so the inside is dim but its stone reads.
#define ZS_SHELTER_BOUNCE
uniform float shelter_fill = 2.2;
uniform vec3 shelter_tint : source_color = vec3(1.0, 0.86, 0.68);
#include "res://shaders/folk_surface.gdshaderinc"
