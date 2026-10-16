extends Node3D
## A powder keg: a greybox barrel
## lying on an isle. Touched, it is picked up and hovers along behind the
## pilot like a carried plane part (scripts/carried_follow.gd). It is fired
## from a cannon as a ranging shot: it flies the arc the pilot would at the
## same aim and power and leaves a marker where it lands (the field,
## scripts/cannon/cannon_field.gd, flies it). One kind: round 1's two sizes
## set the shot's power, which now has notches on the cannon.
## States: "laid", "carried", "flying", "spent" (landed or lost, gone).
const SIZE := 0.6
const COLOUR := Color(0.5,0.34,0.2)
const BAND := Color(0.96,0.55,0.16)

var state := "laid"
var home := Vector3.ZERO
## The keg's size (m, tall) as drawn, from the pilot's unit (set by the field).
var height := 0.6
## While flying: its velocity.
var velocity := Vector3.ZERO
var _body: Node3D

func setup(unit: float) -> void:
	height = unit*SIZE
	name = "Keg"

func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = height*0.38
	cyl.bottom_radius = height*0.38
	cyl.height = height
	cyl.radial_segments = 12
	mesh.mesh = cyl
	mesh.material_override = _paint(COLOUR)
	mesh.position.y = height*0.5
	_body.add_child(mesh)
	for y in [0.25,0.75]:
		var band := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = height*0.395
		ring.bottom_radius = height*0.395
		ring.height = height*0.08
		ring.radial_segments = 12
		band.mesh = ring
		band.material_override = _paint(BAND)
		band.position.y = height*y
		_body.add_child(band)

static func _paint(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

## Hovering at `share` of its size, or laid at full size.
func set_carried(on: bool, share: float) -> void:
	state = "carried" if on else "laid"
	_set_scale(share if on else 1.0)

func _set_scale(share: float) -> void:
	if _body == null: return
	_body.scale = Vector3.ONE*share
	_body.position.y = -height*0.5*share if share < 1.0 else 0.0

## Fired from `at` at `v`: flying at full size.
func launch(at: Vector3, v: Vector3) -> void:
	state = "flying"
	velocity = v
	visible = true
	global_position = at
	_set_scale(1.0)
	if _body != null: _body.position.y = -height*0.5

func spend() -> void:
	state = "spent"
	visible = false

func lay() -> void:
	state = "laid"
	visible = true
	position = home
	_set_scale(1.0)
