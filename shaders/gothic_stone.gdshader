shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The amberlands' gothic set pieces' stone (scripts/ruin_kit_gothic.gd,
// scripts/gothic_growth.gd `stone`): the ruins' stone (shaders/ruin_stone.gdshader,
// the same defines) with the moss and ivy grown over it painted in
// (shaders/stone_moss.gdshaderinc, ZS_STONE_MOSS), and its shade lifted.
#define ZS_FOLK_VERTEX_COLOR
#define ZS_SHELTER_BOUNCE
#define ZS_NIGHT_STONE
#define ZS_STONE_WEATHER
#define ZS_STONE_MOSS
uniform float shelter_fill = 4.5;
uniform vec3 shelter_tint : source_color = vec3(1.0, 0.82, 0.6);
#include "res://shaders/folk_surface.gdshaderinc"
