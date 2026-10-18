extends "res://scripts/kit_isle/mechanics/mech_bob_slab.gd"
## The ring stair's slab (scripts/interactables/ring_route.gd `_slab` with
## RING_SLAB_PUMPS): a bob slab whose spring throws him 7 pumps high, up
## through `rings` air rings stacked over it as the ring route's stair
## (`stair`: the first RING_FIRST over the slab, each next RING_STEP higher
## and RING_OUT on along the arrow, sized by the wanderer).

func _init() -> void:
	super()
	trap_name = "ring_stair_slab"

func defaults() -> Dictionary:
	var d := super.defaults()
	var route: GDScript = load("res://scripts/interactables/ring_route.gd")
	d.spring_pumps = float(route.RING_SLAB_PUMPS)
	d.rings = 1
	return d

func lay(pieces: Node3D, frame: Transform3D) -> void:
	super.lay(pieces,frame)
	var route: GDScript = load("res://scripts/interactables/ring_route.gd")
	var s := WorldScale.wanderer
	var lift := float(knobs.lift)
	for i in range(maxi(int(knobs.get("rings",0)),0)):
		var p := Vector3(0.0,lift+(float(route.RING_FIRST)+float(route.RING_STEP)*i)*s,-float(route.RING_OUT)*s*i)
		pieces.air_ring(frame*p,int(knobs.seed)+1+i,yaw_of(frame),0.0)

func hint_path() -> PackedVector3Array:
	var out := super.hint_path()
	for r: Node3D in host.rings: out.append(r.middle())
	return out
