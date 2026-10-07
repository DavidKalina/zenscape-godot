shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled, shadows_disabled;
// The pilot's puffs of dust and splashes (scripts/pilot_puffs.gd): soft
// balls coloured per instance, lit as the folk are (shaders/
// folk_surface.gdshaderinc), with a brighter sky rim so they read fluffy.
#define ZS_FOLK_VERTEX_COLOR
#include "res://shaders/folk_surface.gdshaderinc"
