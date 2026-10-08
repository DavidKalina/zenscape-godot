shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The gothic ruins' stone and growth (scripts/ruin_kit.gd): faceted blocks
// and ivy coloured by their vertices, lit as the sky folk and the airship
// are (shaders/folk_surface.gdshaderinc), so a face in shade takes the sky's
// hemisphere instead of going black; a plain Lambert terminator, not the
// folk's wrapped one, so each cut face reads as its own plane.
#define ZS_FOLK_VERTEX_COLOR
#include "res://shaders/folk_surface.gdshaderinc"
