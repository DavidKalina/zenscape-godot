extends RefCounted
## The plate's size, in one place. The land is a square grid of this extent
## in plate-local XZ, middle at the origin; an island's outline is cut from
## it. Everything that needs the land's reach derives it from here.
##
## Grids over the plate keep their cell size when the plate grows and take
## more cells, so detail never thins out: derive a count as SIZE / cell.

const HALF := 14.0
const SIZE := HALF * 2.0
## The ground and stream maps the shaders read reach this far each way.
const MAP_HALF := HALF + 2.0
## A point further out than this on either axis lies on the rim: the
## authored rim vertices sit at exactly HALF, give or take float noise.
const RIM := HALF - 0.0001
## The plate as a rect in plate-local XZ.
const RECT := Rect2(-HALF, -HALF, SIZE, SIZE)

## Cover cells (meadow, grass, provenance, life survey): COVER_STEP squares,
## COVER_CELLS a side.
const COVER_STEP := 0.5
const COVER_CELLS := roundi(SIZE / COVER_STEP)
## Fine cells (live water, flower coat): FINE_STEP squares, FINE_CELLS a side.
const FINE_STEP := 0.25
const FINE_CELLS := roundi(SIZE / FINE_STEP)
## Metre cells (biome blend, coarse tree sums), COARSE_CELLS a side.
const COARSE_CELLS := roundi(SIZE)
## Texels a side of the ground and stream maps: FINE_STEP over MAP_HALF.
const MAP_TEXELS := roundi(MAP_HALF * 2.0 / FINE_STEP)
## The recipe's water field: about 0.55 m cells, RECIPE_WATER_CELLS a side
## (the source project's round(28 / 0.55) on the 28 m plate).
const RECIPE_WATER_CELLS := roundi(SIZE / 0.55)
## Erosion's height grid: EROSION_STEP cells, EROSION_POINTS a side, from
## -HALF; the last point lands on or just past the far rim.
const EROSION_STEP := 0.7
const EROSION_POINTS := ceili(SIZE / EROSION_STEP - 0.001) + 1

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
