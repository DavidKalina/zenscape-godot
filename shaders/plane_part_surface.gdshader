shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// A found plane part's paint (scripts/plane_parts.gd): the plane's own
// (shaders/plane_surface.gdshader), with the close-up detail a piece in
// the hand shows (craft_grime.gdshaderinc `craft_detail`: hammered dents,
// a brushed grain, bright scratches, bump-lit).
#define ZS_CRAFT_GRIME
#define ZS_CRAFT_DETAIL
#include "res://shaders/folk_surface.gdshaderinc"
