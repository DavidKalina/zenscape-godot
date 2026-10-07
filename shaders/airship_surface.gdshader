shader_type spatial;
render_mode diffuse_lambert_wrap;
// The airship (scripts/sky_airship.gd, scripts/airship_build.gd): faceted
// canvas, wood and brass coloured by its vertices, lit as the sky folk and
// their planes are (shaders/folk_surface.gdshaderinc), so it holds its
// colour in shade as they do instead of going black out of the sun.
#define ZS_FOLK_VERTEX_COLOR
#include "res://shaders/folk_surface.gdshaderinc"
