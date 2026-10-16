shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;
// The plane's paint, fittings and wood (scripts/plane_figure.gd `paints`):
// lit as the ruins' stone is (shaders/ruin_stone.gdshader, folk_surface.
// gdshaderinc: the sky's hemisphere as emission, a plain Lambert
// terminator, a satin sheen), weathered by the craft's grime (shaders/
// craft_grime.gdshaderinc) on top of the wear `set_wear` lays (`wear`), and
// swept by the mended gleam (`gleam`). The cockpit pilot keeps the painted
// shader (shaders/plane_paint.gdshader).
#define ZS_CRAFT_GRIME
#include "res://shaders/folk_surface.gdshaderinc"
