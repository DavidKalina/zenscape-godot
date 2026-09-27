extends "res://scripts/creation_brush.gd"
## The meadow brush: drag to lay a soft meadow; Shift or a right drag lifts it
## again. A meadow here is ground colour, never standing blades: the faceted,
## painted look of the Fidelity scene (user choice, 2026-09-26). Each dab
## eases the cover up to full and paints a lighter, warmer green in soft
## patches. Flowers are faces of colour in drifts: a few cells in a drift take
## one of the world's three flower colours instead of green.
##
## The meadow is the player's own ground: its cells are marked hand, so
## emergence never thins them or plants in them, and a painted meadow inside
## a forest stays an open glade. It hands nothing to emergence.
## Seconds of brushing at strength 1 for a cell at the centre to settle.
const RATE := 1.6
## Weight of the meadow green, varied by a soft patch noise, and the palette
## shift that makes it (hue, saturation, lightness) from the lightest grass.
const GREEN_WEIGHT := Vector2(0.26,0.44)
const GREEN_SHIFT := Vector3(-0.022,0.02,0.045)
## Flowers: share of cells that bloom inside a full drift, the weight of a
## flower face, and the drift noise frequency (1/m).
const FLOWER_SHARE := 0.2
const FLOWER_WEIGHT := 0.62
const DRIFT_FREQUENCY := 0.32
## Soft flower colours (sRGB); each world blooms in three of them.
const FLOWERS := ["f3ecd2","ecd67a","b9a4d6","e9b4b8","f6f4ee","a9c6e8","e8c28f"]
## Cover the meadow eases toward.
const COVER := 1.0

var _green := Color()
var _flowers: Array[Color] = []
var _patch := FastNoiseLite.new()
var _drift := FastNoiseLite.new()

func _init() -> void:
	brush_id = "meadow"
	radius = 3.2
	radius_range = Vector2(1.0,9.0)

func _prepared(data: NativeTerrainData) -> void:
	_green = NativeTerrainPalette.shift_hsl(data._palette.grass[1],GREEN_SHIFT.x,GREEN_SHIFT.y,GREEN_SHIFT.z)
	_patch.seed = seed_value+211
	_patch.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_patch.frequency = 0.22
	_drift.seed = seed_value+223
	_drift.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_drift.frequency = DRIFT_FREQUENCY
	var picks := range(FLOWERS.size())
	picks.sort_custom(func(a: int, b: int) -> bool: return Variety.unit([seed_value,5,a]) < Variety.unit([seed_value,5,b]))
	_flowers.clear()
	for i in range(3): _flowers.append(Color(FLOWERS[picks[i]]).srgb_to_linear())

## The colour and weight a cell settles on: its own green patch, or a flower.
func _target(data: NativeTerrainData, cell: int) -> Array:
	var p := data.meadow_position(cell%data.MEADOW_CELLS,cell/data.MEADOW_CELLS)+Vector2.ONE*data.MEADOW_STEP*0.5
	var drift := smoothstep(0.05,0.55,_drift.get_noise_2d(p.x,p.y))
	var roll := Variety.unit([seed_value,7,cell])
	if roll < FLOWER_SHARE*drift:
		return [_flowers[Variety.weighted([1.0,0.7,0.45],Variety.unit([seed_value,9,cell]))],FLOWER_WEIGHT]
	var patch := _patch.get_noise_2d(p.x,p.y)*0.5+0.5
	return [_green,lerpf(GREEN_WEIGHT.x,GREEN_WEIGHT.y,patch)]

func dab(data: NativeTerrainData, center: Vector2, reach: float, amount: float, lower: bool) -> void:
	if reach <= 0.0 or amount <= 0.0: return
	_grow_bounds(center,reach)
	var tint := data.tint
	var grass := data.grass
	var provenance := data.provenance
	for found: Vector2 in _cells_near(data,center,reach):
		var cell := int(found.x)
		var t := found.y/reach
		var step := amount*RATE*(1.0-smoothstep(0.35,1.0,t))
		if step <= 0.0: continue
		provenance[cell] = NativeTerrainData.SOURCE_HAND
		if lower:
			_tint_toward(tint,cell,Color(),0.0,step)
			continue
		var target := _target(data,cell)
		_tint_toward(tint,cell,target[0],target[1],step*target[1])
		grass[cell] = move_toward(grass[cell],COVER,step)
	data.tint = tint
	data.grass = grass
	data.provenance = provenance

func finish(_data: NativeTerrainData) -> Rect2:
	has_bounds = false
	return Rect2()
