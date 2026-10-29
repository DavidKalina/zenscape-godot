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
// The ruins at night: the moon caught in the stone and the lanterns' bounce
// (shaders/folk_surface.gdshaderinc, scripts/kit_isle/kit_night_lights.gd).
#define ZS_NIGHT_STONE
// The weathered basalt, the Olmec's (shaders/kit_weather.gdshaderinc; off
// at `stone_weather` 0, the kit's old smooth stone: --kit-stone=smooth).
#define ZS_STONE_WEATHER
// The cut stone baked in Blender (shaders/stone_tile.gdshaderinc).
#define ZS_STONE_TILE
uniform float shelter_fill = 4.5;
uniform vec3 shelter_tint : source_color = vec3(1.0, 0.82, 0.6);
#include "res://shaders/folk_surface.gdshaderinc"
