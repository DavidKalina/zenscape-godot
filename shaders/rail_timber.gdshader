shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The railroad's timber trestles (scripts/endless/rail_span.gd): the ruins'
// stone lighting (shaders/ruin_stone.gdshader: the sky's hemisphere as
// emission, a plain Lambert terminator, the shelter bounce under the deck)
// without the cut stone's tile, with the craft's weathering (streaks down
// the upright faces, grime under) and the timber's grain along each member
// (shaders/rail_timber.gdshaderinc, from its UV).
#define ZS_FOLK_VERTEX_COLOR
#define ZS_SHELTER_BOUNCE
#define ZS_NIGHT_STONE
#define ZS_STONE_WEATHER
#define ZS_CRAFT_GRIME
#define ZS_TIMBER_GRAIN
uniform float shelter_fill = 4.5;
uniform vec3 shelter_tint : source_color = vec3(1.0, 0.82, 0.6);
#include "res://shaders/folk_surface.gdshaderinc"
