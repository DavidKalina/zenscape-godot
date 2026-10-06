shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx, cull_disabled, shadows_disabled;
// The pilot's scarf: a two-sided ribbon coloured by its vertices, lit as the
// folk are (shaders/folk_surface.gdshaderinc).
#define ZS_FOLK_VERTEX_COLOR
#include "res://shaders/folk_surface.gdshaderinc"
