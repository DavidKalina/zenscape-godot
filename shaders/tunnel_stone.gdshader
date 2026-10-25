shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, fog_disabled;
// The ruins' stone (shaders/ruin_stone.gdshader) under a mountain: the
// tunnels' hall stretches (scripts/endless/land_tunnels.gd). The same
// stone, its sky fill and shelter bounce scaled by `dim_fill`, so the
// inside is dark and the torches' lights carry it; no haze (the day's
// fog would light the far stone).
#define ZS_FOLK_VERTEX_COLOR
#define ZS_SHELTER_BOUNCE
#define ZS_NIGHT_STONE
#define ZS_STONE_WEATHER
#define ZS_DIM_FILL
uniform float shelter_fill = 4.5;
uniform vec3 shelter_tint : source_color = vec3(1.0, 0.82, 0.6);
uniform float dim_fill : hint_range(0.0, 1.0) = 0.1;
#include "res://shaders/folk_surface.gdshaderinc"
