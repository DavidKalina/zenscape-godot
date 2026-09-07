shader_type spatial;
// Original lake receives light, but only the underlying bed receives shadows.
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_lambert, shadows_disabled;
#include "res://shaders/reference_water_body.gdshaderinc"
