extends "res://scripts/clay_tools/clay_tool.gd"
## The watering can, "Pour": water held in hand, under the Feather in the tool
## roll. Like the Feather it is not a clay tool: it shapes no land. It rides
## the clay's seam for what every tool in hand shares (`LandClay.set_tool("can")`
## puts the can in hand as the cursor over the land), and its gestures are the
## materials hand's (scripts/hand_materials.gd CAN), which takes a press on the
## land before the clay sees it and hands it to the can's stream
## (scripts/watering_can.gd): hold to pour where the rose hangs, drag to run
## the water along a groove, Shift to sprinkle through the rose; held still on
## high ground the pour becomes a spring that keeps running.
##
## The can tips forward while it pours (`pour`, set by the stream, 0..1),
## turning about its rose so the stream stays where it is.

## The stand-in can, metres at the hand's own size before GROW: a pale
## galvanised body, a deep slate spout and handle, a bright brass rose. Paler
## and darker than the icon's tint (scripts/hud_icons.gd "can") so it stands
## out over grass and water alike. Its origin is the rose: the stream falls
## from there.
const TINT := Color("c9d9d7")
const DARK := Color("34494e")
const ROSE := Color("e0aa3e")
## The whole can grown about its rose, so it reads at a glance over the land.
const GROW := 1.6
const BODY_RADIUS := 0.2
const BODY_HEIGHT := 0.34
## The body's centre behind and below the rose, and where the spout leaves it.
const BODY_AT := Vector3(0.0,-0.28,-0.72)
const SPOUT_FROM := Vector3(0.0,-0.3,-0.45)
const SPOUT_RADIUS := Vector2(0.032,0.022)
const ROSE_RADIUS := 0.07
## Degrees tipped forward at rest and at a full pour, about the rose.
const REST_TIP := 6.0
const POUR_TIP := 52.0
## How fast it tips toward the pour and back (1/s).
const TIP_RATE := 9.0
## The rose held over the land a little higher than a tool's working end
## (m), so the water has a fall to make.
const LIFT := 0.25
## The cursor sketch's lean.
const TILT := -6.0

## How much it pours, 0..1 (the stream sets it).
var pour := 0.0
var _tip := REST_TIP
var _pivot: Node3D

func id() -> String: return "can"
func prop_tilt() -> float: return TILT
func prop_lift() -> float: return LIFT
## It hovers over the water, not the lake bed, so a pour never drowns it.
func rides_water() -> bool: return true
## The stream's reach: its splash at the middle pip.
func stroke_radius() -> float: return 0.8*clay.size_scale

## The rose, in the prop's own space, and the way water leaves it there.
func rose() -> Vector3: return Vector3.ZERO
func spout_way() -> Vector3:
	var way := (rose()-SPOUT_FROM).normalized()
	return _pivot.basis*way if _pivot != null else way

## Tips the can toward its pour.
func frame(delta: float) -> void:
	if _pivot == null or not is_instance_valid(_pivot): return
	_tip = lerpf(_tip,lerpf(REST_TIP,POUR_TIP,clampf(pour,0.0,1.0)),1.0-exp(-TIP_RATE*delta))
	_pivot.basis = Basis(Vector3.RIGHT,deg_to_rad(_tip))

## A faceted can from primitives, grown GROW and turning about its rose
## (`_pivot`): an
## eight-sided body, a tapered spout up to a brass rose, and a loop handle
## standing over the body. Replaced by a Blender glb later: only this function
## changes.
func build_prop() -> Node3D:
	var root := Node3D.new()
	var grown := Node3D.new()
	grown.name = "Grow"
	grown.scale = Vector3.ONE*GROW
	root.add_child(grown)
	_pivot = Node3D.new()
	_pivot.name = "Tip"
	_pivot.basis = Basis(Vector3.RIGHT,deg_to_rad(_tip))
	grown.add_child(_pivot)
	_pivot.add_child(part(_prism(8),TINT,BODY_AT,Vector3(BODY_RADIUS,BODY_HEIGHT,BODY_RADIUS)))
	# A rolled rim round the body's mouth.
	_pivot.add_child(part(_prism(8),DARK.lightened(0.15),BODY_AT+Vector3.UP*BODY_HEIGHT*0.5,Vector3(BODY_RADIUS*1.06,0.025,BODY_RADIUS*1.06)))
	var spout := rose()-SPOUT_FROM
	var angle := atan2(spout.z,spout.y)
	_pivot.add_child(part(_prism(6,SPOUT_RADIUS.x/SPOUT_RADIUS.y),DARK,(SPOUT_FROM+rose())*0.5,Vector3(SPOUT_RADIUS.y,spout.length(),SPOUT_RADIUS.y),Vector3(angle,0.0,0.0)))
	_pivot.add_child(part(_prism(8),ROSE,rose()-spout.normalized()*0.02,Vector3(ROSE_RADIUS,0.045,ROSE_RADIUS),Vector3(angle,0.0,0.0)))
	var handle := TorusMesh.new()
	handle.inner_radius = 0.82
	handle.outer_radius = 1.0
	handle.rings = 10
	handle.ring_segments = 5
	_pivot.add_child(part(handle,DARK,BODY_AT+Vector3(0.0,BODY_HEIGHT*0.5+0.04,-0.06),Vector3.ONE*0.17,Vector3(0.0,0.0,PI*0.5)))
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
