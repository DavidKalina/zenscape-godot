extends "res://scripts/traps/trap_seesaw.gd"
## Seesaw, slam to launch (docs/design/roguelike/traps-round2-seesaw.md): a
## heavy stone block sits on the far end, which its weight holds down; the
## near end stands up one jump. The pilot climbs onto the near end and
## SLAMS (the motor's "slammed" pace drives `impact`): the block is flung up
## and along the route, farther the harder the slam (a plain landing barely
## moves it). It is a real RigidBody3D: it lands on things, knocks things,
## falls off. The tell: the block glows as the up end stands primed.
##
## Knobs (over the seesaw's): `block_mass` (kg; the pilot is `pilot_mass`),
## `block` (m a side), `block_arm` (share of half length from the pivot).
const BLOCK := Color(0.36,0.35,0.34)

var block: RigidBody3D

func _init() -> void:
	super()
	trap_name = "seesaw_slam"

func defaults() -> Dictionary:
	var d := super()
	d.merge({"block_mass":240.0,"block":pilot().jumps[0]*1.1,"block_arm":0.5},true)
	return d

func build() -> void:
	super()
	block = make_block(float(knob("block_mass")),float(knob("block")),BLOCK)
	add_child(block)
	loads.append(block)
	_set_block()

func _set_block() -> void:
	tilt = -float(knob("max_tilt"))
	spin = 0.0
	teleport()
	var z := pivot_z()-length()*0.5*float(knob("block_arm"))
	block.linear_velocity = Vector3.ZERO
	block.angular_velocity = Vector3.ZERO
	# Sat square on the tilted deck.
	block.transform = body.transform*Transform3D(Basis.IDENTITY,Vector3(0.0,float(knob("block"))*0.5+0.01,z))

func reset() -> void:
	super()
	if block != null: _set_block()
