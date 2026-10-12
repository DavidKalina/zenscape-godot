extends Node3D
## A powder keg (docs/design/roguelike/cannon-round1.md): greybox barrel
## lying on an isle. Touched, it is picked up and hovers along behind the
## pilot like a carried plane part (scripts/carried_follow.gd); a cannon
## takes it from the hover. Two kinds: "small" (a hop) and "big" (a long
## arc), the kind setting the shot's power (scripts/cannon/cannon.gd).
## States: "laid", "carried", "spent" (loaded and fired, gone).
const SIZES := {"small":0.5,"big":0.8}
const COLOURS := {"small":Color(0.5,0.34,0.2),"big":Color(0.36,0.22,0.14)}
const BAND := Color(0.96,0.55,0.16)

var kind := "small"
var state := "laid"
var home := Vector3.ZERO
## The keg's size (m, tall) as drawn, from the pilot's unit (set by the field).
var height := 0.6
var _body: Node3D

func setup(keg_kind: String, unit: float) -> void:
	kind = keg_kind
	height = unit*float(SIZES[kind])
	name = "Keg_"+kind

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
	mesh.material_override = _paint(COLOURS[kind])
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
		band.material_override = _paint(BAND if kind == "big" else Color(0.3,0.3,0.32))
		band.position.y = height*y
		_body.add_child(band)

static func _paint(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

## Hovering at `share` of its size, or laid at full size.
func set_carried(on: bool, share: float) -> void:
	state = "carried" if on else "laid"
	if _body == null: return
	_body.scale = Vector3.ONE*(share if on else 1.0)
	_body.position.y = -height*0.5*share if on else 0.0

func spend() -> void:
	state = "spent"
	visible = false

func lay() -> void:
	state = "laid"
	visible = true
	position = home
	if _body != null:
		_body.scale = Vector3.ONE
		_body.position.y = 0.0
