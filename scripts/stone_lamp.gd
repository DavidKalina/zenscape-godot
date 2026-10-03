extends RefCounted
## The stone lamp (docs/scenic/stone-lamps.md): a small faceted lantern of
## stone set on the land from the tray's "lamp" compartment. A hexagonal foot
## and post, a square shelf, four corner pillars round an open fire box, a
## low four-sided roof and a knob on top. Solid and faceted, like the river
## stone (scripts/garden_view.gd "rock") and the tools' props; its light is
## not here but in scripts/stone_lamp_lights.gd, which sets a soft warm core
## in the fire box, a halo round it and, for the nearest few, a real light.
##
## The mesh is drawn by GardenView as asset "stone_lamp" on the stone
## material (vertex colours, flat faces), one batch for every lamp.
##
## Not to be confused with the lantern_*.gd scripts, which are the classic
## UI shell.

## Every size below is times UNIT (m at record scale 1): about a metre tall.
const UNIT := 1.3
## Stone, the roof a shade darker, the fire box's floor darker still.
const STONE := Color("9a958a")
const ROOF := Color("6e6a62")
const SOOT := Color("4a4540")
## The fire box: the warm core sits at GLOW_HEIGHT (record space, m) and is
## GLOW_RADIUS across; the pillars stand at BOX_HALF from the middle.
const BOX_HALF := 0.085
const BOX_LOW := 0.405
const BOX_HIGH := 0.565
const GLOW_HEIGHT := (BOX_LOW+BOX_HIGH)*0.5*UNIT
const GLOW_RADIUS := 0.06*UNIT

static var _mesh: ArrayMesh

## The lamp, built once and shared.
static func mesh() -> ArrayMesh:
	if _mesh != null: return _mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Foot, post, shelf.
	_prism(surface,6,0.17,0.15,0.0,0.06,STONE,0.0)
	_prism(surface,6,0.065,0.052,0.06,0.36,STONE,PI/6.0)
	_prism(surface,4,0.15,0.16,0.36,0.405,STONE,PI*0.25)
	# The fire box: a dark floor and four pillars at its corners.
	_prism(surface,4,0.11,0.11,0.405,0.415,SOOT,PI*0.25)
	for k in range(4):
		var corner := Vector2(BOX_HALF,0.0).rotated(PI*0.25+PI*0.5*k)*sqrt(2.0)
		_prism(surface,4,0.03,0.03,BOX_LOW,BOX_HIGH,STONE,PI*0.25,corner)
	# Its lid, then the roof, a little wider than the shelf, and its knob.
	_prism(surface,4,0.15,0.15,BOX_HIGH,0.59,STONE,PI*0.25)
	_prism(surface,4,0.25,0.035,0.59,0.72,ROOF,PI*0.25)
	_prism(surface,6,0.03,0.045,0.72,0.75,ROOF,0.0)
	_prism(surface,6,0.012,0.04,0.75,0.8,ROOF,0.0)
	surface.generate_normals()
	_mesh = surface.commit()
	return _mesh

## An upright n-sided prism from `low` to `high` (m, times UNIT), `bottom`
## and `top` its corner radii, turned `turn` about the up axis and stood at
## `at` (x, z).
static func _prism(surface: SurfaceTool, sides: int, bottom: float, top: float, low: float, high: float, colour: Color, turn: float, at := Vector2.ZERO) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom*UNIT
	cylinder.top_radius = top*UNIT
	cylinder.height = (high-low)*UNIT
	cylinder.radial_segments = sides
	cylinder.rings = 0
	var pose := Transform3D(Basis(Vector3.UP,turn),Vector3(at.x*UNIT,(low+high)*0.5*UNIT,at.y*UNIT))
	var linear := colour.srgb_to_linear()
	for vertex in cylinder.get_faces():
		surface.set_color(linear)
		surface.add_vertex(pose*vertex)
