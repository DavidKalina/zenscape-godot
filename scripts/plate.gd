extends RefCounted
## The plate's size, in one place. The land is a square grid of this extent
## in plate-local XZ, middle at the origin; an island's outline is cut from
## it. Everything that needs the land's reach derives it from here.

const HALF := 14.0
const SIZE := HALF * 2.0
## The ground and stream maps the shaders read reach this far each way.
const MAP_HALF := HALF + 2.0
## The maps sample the land at this many metres a texel, so each is MAP_SIZE
## texels a side over MAP_SPAN metres; the shade map (zs_ground_shade) is
## half as fine. The shaders read the same extent from the globals below.
const MAP_TEXEL := 0.25
const MAP_SPAN := MAP_HALF * 2.0
const MAP_SIZE := int(MAP_SPAN / MAP_TEXEL)
const SHADE_TEXEL := 0.5
const SHADE_SIZE := int(MAP_SPAN / SHADE_TEXEL)

## Hands the extent to the shaders (project.godot [shader_globals] holds the
## values they start with, which are this file's at HALF 14).
static func publish_shader_globals() -> void:
	RenderingServer.global_shader_parameter_set(&"zs_plate_half",HALF)
	RenderingServer.global_shader_parameter_set(&"zs_map_half",MAP_HALF)
