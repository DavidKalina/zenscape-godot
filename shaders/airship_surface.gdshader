shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The airship (scripts/sky_airship.gd, scripts/airship_build.gd): faceted
// canvas, wood and brass coloured by its vertices, lit as the ruins' stone is
// (shaders/ruin_stone.gdshader, folk_surface.gdshaderinc: the sky's
// hemisphere as emission, a plain Lambert terminator), weathered by the
// craft's grime (shaders/craft_grime.gdshaderinc): streaked canvas, sooty
// undersides, dirty patches.
#define ZS_FOLK_VERTEX_COLOR
#define ZS_CRAFT_GRIME
#include "res://shaders/folk_surface.gdshaderinc"
