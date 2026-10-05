extends RefCounted
## The plate's size, in one place. The land is a square grid of this extent
## in plate-local XZ, middle at the origin; an island's outline is cut from
## it. Everything that needs the land's reach derives it from here.
##
## Grids over the plate keep their cell size when the plate grows and take
## more cells, so detail never thins out: derive a count as SIZE / cell.

const HALF := 24.0
const SIZE := HALF * 2.0
## The plate worlds were made on before it grew (until document version 12):
## a 28 m square, LEGACY_HALF each way. A world saved then keeps that square
## in the middle of this one (scripts/plate_migration.gd), and an island with
## no outline of its own is that square (`square` in scripts/island_outline.gd).
const LEGACY_HALF := 14.0
## The ground and stream maps the shaders read reach this far each way.
const MAP_HALF := HALF + 2.0
## A point further out than this on either axis lies on the rim: the
## rim vertices sit at exactly HALF, give or take float noise.
const RIM := HALF - 0.0001
## The plate as a rect in plate-local XZ.
const RECT := Rect2(-HALF, -HALF, SIZE, SIZE)

## The terrain's points (scripts/plate_mesh.gd): a grid POINT_STEP apart,
## POINT_CELLS squares a side, each square two faces. The step puts grid
## lines on ±LEGACY_HALF as well as on the rim, so the old square's edge runs
## straight along the faces' edges.
const POINT_STEP := 2.0 / 3.0
const POINT_CELLS := roundi(SIZE / POINT_STEP)

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
## over ±RECIPE_WATER_HALF (the source project's round(28 / 0.55)). Recipe
## landscapes always stand on the old square (NativeTerrainData.reset_flat),
## so their water keeps the source's grid there exactly.
const RECIPE_WATER_HALF := LEGACY_HALF
const RECIPE_WATER_CELLS := roundi(RECIPE_WATER_HALF * 2.0 / 0.55)
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
## values they start with, which are this file's).
static func publish_shader_globals() -> void:
	RenderingServer.global_shader_parameter_set(&"zs_plate_half",HALF)
	RenderingServer.global_shader_parameter_set(&"zs_map_half",MAP_HALF)
