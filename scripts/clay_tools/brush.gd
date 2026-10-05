extends "res://scripts/clay_tools/clay_tool.gd"
## The Brush, "Paint": colours the ground without moving it, the old Build
## palette's cover brushes (native_chunk_editor "grass" and "paint") brought to
## the tool roll. It paints from the press to the release, held still or
## dragged (the clay's paint, scripts/land_clay.gd State.PAINT); what it lays
## is its mode, picked on its fan or with Q and E:
##
## - **Grass:** the world's own grass (the palette's three greens, patched by
##   its noise), over anything, a cliff face included, and the cells' grass
##   cover with it.
## - **Rock:** the world's cliff rock (the palette's two), so flat ground can
##   read as a bare outcrop; the grass cover goes.
## - **Earth:** the strata's topsoil, bare turned ground; the grass cover goes.
## - **Colour:** any colour, over rock and grass alike, as the old "paint"
##   brush: one of SWATCHES on the strip under the fan, or the strip's last
##   cell's full picker (`colour`). The grass cover stays as it is.
## - **Wipe:** takes the paint back off, so the ground shows what the world
##   gives it again (slope rock, snow, shore sand).
##
## **Shift** wipes, whatever the mode. Each dab coats by how far the pointer
## travels (COAT_PER_METRE) and, held still, by the second (COAT_PER_SECOND),
## so a pass lays a wash and going over it deepens it. Painting writes the
## tint layer (scripts/native_terrain_tint.gd, saved and undone with the
## land) and the grass cover, both of which the light refresh redraws. Let go,
## the meadow and blades leave the cells laid as rock or earth, so no tufts
## stand on them, and the cells are claimed as hand-made.

const MODES := [{"id":"grass","kind":"paint"},{"id":"rock","kind":"paint"},{"id":"earth","kind":"paint"},{"id":"colour","kind":"paint"},{"id":"wipe","kind":"paint"}]
## The Colour mode's swatches (sRGB): terracotta (the old brush's default),
## ochre, rust, rose clay, sand, moss, slate and ash.
const SWATCHES := [Color("b06f4a"),Color("c99a3e"),Color("9a4a2e"),Color("c08a6a"),Color("d8c48e"),Color("6f7d3c"),Color("5d6a74"),Color("9a968e")]

## Brush radius (m), at the hand's middle size; coat (weight 0..1) per metre
## travelled and per second held, at the middle, easing to nothing at the rim.
const RADIUS := 2.0
const COAT_PER_METRE := 1.2
const COAT_PER_SECOND := 1.5
## A cell laid at least BARE weight of rock or earth loses its meadow and
## blades at release.
const BARE := 0.5

## The stand-in: a faceted flat brush, a wooden handle, a brass ferrule and a
## bristle head in the icon's tint (scripts/hud_icons.gd "brush").
const TINT := Color("b9a46a")
const WOOD := Color("b98a58")
const BRASS := Color("c2a35a")
const TILT := -20.0

var _last: Variant = null
## Cells this press painted, cell index -> true, for the release.
var _cells := {}

func id() -> String: return "brush"
func modes() -> Array: return MODES
func gesture(_verb: String) -> String: return "press"
func prop_tilt() -> float: return TILT
func dirt_share(_verb: String) -> float: return 0.0
func turns_lip(_verb: String) -> bool: return false
func stroke_radius() -> float: return RADIUS*clay.size_scale
func mark_size() -> Vector2: return Vector2.ONE*RADIUS
func paints() -> bool: return true
func swatches() -> Array: return SWATCHES if mode == "colour" else []

func _init() -> void:
	colour = SWATCHES[0]

func reset() -> void:
	lift = 0.0
	_last = null
	_cells = {}

func paint_begin(fine: bool) -> String:
	_last = null
	_cells = {}
	return "wipe" if fine else (mode if not mode.is_empty() else "grass")

func paint_dab(_heights: PackedFloat32Array, q: Vector2, work: float) -> float:
	var travelled: float = q.distance_to(_last) if _last != null else 0.0
	_last = q
	var coat := COAT_PER_METRE*travelled+COAT_PER_SECOND*work
	if coat <= 0.0: return 0.0
	var radius := stroke_radius()
	var data: NativeTerrainData = clay.editor.data
	var palette: NativeTerrainPalette = data._palette
	var side := NativeTerrainData.MEADOW_CELLS
	var step := NativeTerrainData.MEADOW_STEP
	var low := Vector2i(((q-Vector2.ONE*radius+Vector2.ONE*Plate.HALF)/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var high := Vector2i(((q+Vector2.ONE*radius+Vector2.ONE*Plate.HALF)/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var tint := data.tint
	var grass := data.grass
	var verb: String = clay.verb
	var own := colour.srgb_to_linear()
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var p := data.meadow_position(x,z)+Vector2.ONE*step*0.5
			var d := p.distance_to(q)
			if d >= radius: continue
			var cell := z*side+x
			var added := clampf(coat,0.0,1.0)*(1.0-smoothstep(0.0,radius,d))
			if added <= 0.0: continue
			_cells[cell] = true
			data.provenance[cell] = NativeTerrainData.SOURCE_HAND
			if verb == "wipe":
				_wipe(tint,cell,added)
				continue
			coat(tint,cell,own if verb == "colour" else surface_colour(verb,palette,p),added)
			if verb != "colour": grass[cell] = lerpf(grass[cell],1.0 if verb == "grass" else 0.0,added)
	data.tint = tint
	data.grass = grass
	clay.touch(q,radius)
	return 0.0

## Let go: tufts leave rock and bare earth.
func paint_end(_tapped: bool) -> void:
	var data: NativeTerrainData = clay.editor.data
	if clay.verb in ["rock","earth"]:
		for cell: int in _cells:
			if NativeTerrainTint.weight_at(data.tint,cell) < BARE: continue
			data.meadow[cell] = 0.0
			data.blades[cell] = 0.0
	_cells = {}
	_last = null

## The tint (linear) a surface `kind` lays at plate point `p`, without the
## shimmer (the mesh adds each face's own): "grass" the world's own grass,
## patched as its noise patches it; "rock" its cliff rock, the palette's two
## patched the same way; "sand" its shore sand; anything else bare earth, the
## strata's topsoil. The Brush's modes and the Paddle's Plane both lay these.
static func surface_colour(kind: String, palette: NativeTerrainPalette, p: Vector2) -> Color:
	match kind:
		"grass": return palette.grass[_grass_variant(palette,p)]
		"rock": return palette.rock[0 if palette.patch(p) > 0.5 else 1]
		"sand": return palette.sand
	return Color(preload("res://scripts/strata.gd").COLORS.topsoil).srgb_to_linear()

## The palette's grass patching (NativeTerrainPalette.grass_at_coordinates),
## without the shimmer: the mesh adds each face's own.
static func _grass_variant(palette: NativeTerrainPalette, p: Vector2) -> int:
	var n := palette.patch(p)
	return 1 if n > 0.55 else 2 if n < 0.42 else 0

## Coat `cell` with `added` of `color`: the colour moves that share of the
## way to it (all of it on an unpainted cell) and the weight that share of
## the way to full, so painting over another colour turns it as quickly as
## painting bare ground (NativeTerrainTint.paint's over-composite barely
## moves a full-weight cell). A coat of 1 replaces the cell outright: the
## colour, at full weight, whatever lay there (the Paddle's Plane).
static func coat(tint: PackedFloat32Array, cell: int, color: Color, added: float) -> void:
	var k := cell*NativeTerrainTint.STRIDE
	var before := tint[k+3]
	var share := 1.0 if before <= 0.0 else added
	tint[k] = lerpf(tint[k],color.r,share)
	tint[k+1] = lerpf(tint[k+1],color.g,share)
	tint[k+2] = lerpf(tint[k+2],color.b,share)
	tint[k+3] = minf(before+added*(1.0-before),1.0)

static func _wipe(tint: PackedFloat32Array, cell: int, added: float) -> void:
	var k := cell*NativeTerrainTint.STRIDE
	tint[k+3] = maxf(0.0,tint[k+3]-added)
	if tint[k+3] == 0.0:
		tint[k] = 0.0
		tint[k+1] = 0.0
		tint[k+2] = 0.0

## A faceted flat brush: wooden handle, brass ferrule, a bristle head.
func build_prop() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(_prism(8),WOOD,Vector3(0.0,0.0,0.0),Vector3(0.035,0.5,0.035)))
	root.add_child(part(BoxMesh.new(),BRASS,Vector3(0.0,-0.3,0.0),Vector3(0.12,0.1,0.04)))
	root.add_child(part(BoxMesh.new(),TINT,Vector3(0.0,-0.44,0.0),Vector3(0.13,0.18,0.035)))
	return root

static func _prism(sides: int) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh
