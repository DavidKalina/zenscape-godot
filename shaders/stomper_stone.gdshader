shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The stomper's stone: the ruins' (shaders/ruin_stone.gdshader) with the shade
// lit for its size. The ruins' shade fill is the sky's hemisphere and the cloud
// sea's bounce, blue and grey and next to nothing under a low sun: on a 250 m body
// a shaded limb goes black up close and its underside grey. Here the shade takes
// the sunlit land's bounce instead (ZS_LAND_BOUNCE, shaders/folk_surface.gdshaderinc).
#define ZS_FOLK_VERTEX_COLOR
#define ZS_SHELTER_BOUNCE
#define ZS_NIGHT_STONE
#define ZS_STONE_WEATHER
#define ZS_STONE_TILE
#define ZS_TILE_NEAR_FADE
#define ZS_LAND_BOUNCE
// The weathering reads metres, and the model is 7 m tall drawn at 250: its grain
// came out in blocks a few metres wide, square, off the noise's lattice.
#define ZS_WEATHER_SCALE
uniform float weather_scale = 1.0;
uniform float shelter_fill = 4.5;
uniform vec3 shelter_tint : source_color = vec3(1.0, 0.82, 0.6);
// The land's colour in the bounce, and how much of the sun comes back off it.
uniform vec3 land_tint : source_color = vec3(0.72, 0.68, 0.6);
uniform float land_bounce = 1.0;
#include "res://shaders/folk_surface.gdshaderinc"
