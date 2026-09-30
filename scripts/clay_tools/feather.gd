extends "res://scripts/clay_tools/clay_tool.gd"
## The Feather, "Gust" (docs/design/tools/PLAN.md "The Feather", design
## "ZenScape HUD 5 Air" section C): wind held in hand. It is not a clay tool:
## it shapes no land, so it has no verbs here. It rides the clay's seam only
## for what every tool in hand shares: `LandClay.set_tool("feather")` puts the
## quill in the ghost hand (`build_prop`, leaning `prop_tilt`), the hand grips
## it over the land, and Esc, the Hand's pocket or taking a material give the
## Hand back, as for any tool.
##
## Its gestures are the materials hand's (scripts/hand_materials.gd, "The
## Feather"), which takes a press on the land before the clay sees it and
## hands it to the wind tool (scripts/wind_gust.gd): a swipe sends a lane, a
## still hold of 400 ms bursts. So the clay never opens a stroke for it, and
## the Feather adds no undo step. The hooks below stay the base's no-ops in
## case a press ever reaches the clay with the Feather in hand (no tray).

## The stand-in quill, metres at the hand's own size: the icon's tint
## (scripts/hud_icons.gd "feather") on the vane, a pale shaft, a horn-coloured
## quill end above the grip. The vane hangs below the grip, its working end,
## and is asymmetric as a flight feather's is: the leading vane narrow, the
## trailing one broad.
const TINT := Color("cbb994")
const SHAFT := Color("ece2c8")
const QUILL := Color("a8936a")
const SHAFT_LENGTH := 1.35
const SHAFT_RADIUS := 0.018
## Where the vane starts under the grip and how long it runs (m), and its two
## halves' widths (m) and thickness.
const VANE_FROM := 0.18
const VANE_LENGTH := 1.1
const VANE_LEAD := 0.07
const VANE_TRAIL := 0.13
const VANE_THICK := 0.025
## The quill end standing over the grip (m).
const QUILL_LENGTH := 0.2
## The cursor sketch's lean (lowpoly.js GUST.cursorTilt).
const TILT := -18.0

func id() -> String: return "feather"
func prop_tilt() -> float: return TILT
## The Feather's lane is the wind brush's 3 m half-width at the middle pip.
func stroke_radius() -> float: return 3.0*clay.size_scale

## A faceted quill from primitives: a hexagonal shaft through the grip, a
## horn quill end over it, and two flattened seven-sided ellipsoids hanging
## either side of the shaft for the vane, thin across the way it pushes
## (local z, turned to face the drag by the clay). Replaced by a Blender glb
## later: only this function changes.
func build_prop() -> Node3D:
	var root := Node3D.new()
	root.add_child(part(_prism(6,0.6),SHAFT,Vector3(0.0,-SHAFT_LENGTH*0.5+QUILL_LENGTH*0.5,0.0),Vector3(SHAFT_RADIUS,SHAFT_LENGTH,SHAFT_RADIUS)))
	root.add_child(part(_prism(6,0.8),QUILL,Vector3(0.0,QUILL_LENGTH*0.5,0.0),Vector3(SHAFT_RADIUS*1.4,QUILL_LENGTH,SHAFT_RADIUS*1.4)))
	var middle := -VANE_FROM-VANE_LENGTH*0.5
	root.add_child(part(_ball(),TINT.lightened(0.08),Vector3(-VANE_LEAD*0.8,middle+0.04,0.0),Vector3(VANE_LEAD,VANE_LENGTH*0.46,VANE_THICK),Vector3(0.0,0.0,-0.05)))
	root.add_child(part(_ball(),TINT,Vector3(VANE_TRAIL*0.8,middle,0.0),Vector3(VANE_TRAIL,VANE_LENGTH*0.5,VANE_THICK),Vector3(0.0,0.0,0.06)))
	return root

## An upright n-sided prism, unit radius and height, tapering to `foot` of
## its radius at the bottom.
static func _prism(sides: int, foot := 1.0) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = foot
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh

static func _ball() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 7
	mesh.rings = 4
	return mesh
