shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The railroad's stone (scripts/endless/rail_span.gd): the ruins' stone
// (shaders/ruin_stone.gdshader, the cut-stone tile and the basalt's
// weathering) with the railroad's own weathering on top
// (shaders/rail_wear.gdshaderinc): tone by pier and tier, rain streaks, soot
// under the arches, the tide, wet and moss at the foot.
#define ZS_FOLK_VERTEX_COLOR
#define ZS_SHELTER_BOUNCE
#define ZS_NIGHT_STONE
#define ZS_STONE_WEATHER
#define ZS_STONE_TILE
#define ZS_RAIL_WEAR
#define ZS_RAIL_STONE
uniform float shelter_fill = 4.5;
uniform vec3 shelter_tint : source_color = vec3(1.0, 0.82, 0.6);
#include "res://shaders/folk_surface.gdshaderinc"
