extends RefCounted
## The on-foot pieces placed on the Stair to the Clouds (scripts/kit_isle/
## motif_stair_clouds.gd, studies/stair_clouds_isle_art.gd; docs/design/
## foot-interactables.md), in its own frame moved by `offset` (its own
## scene: none; in the aqueduct isle's sky: SKY_OFFSET, scripts/kit_isle/
## motif_sky.gd's place for it):
##   - a balustrade down the outer cheek of each of the top four flights
##     (legs 5 to 8, counted from 1), over the drop: slide one, flung off
##     its foot onto the landing, turn and jump onto the next down (a chain
##     of four);
##   - four bobbing slabs off the first flight's outer side, climbing from
##     the lawn to its head's landing: a short cut up the first flight.
## --foot-at=stair (on its scene, or the aqueduct isle's) starts on the
## summit's landing at the top rail; --foot-at=stair_slabs on the lawn by
## the slabs.
const Stair = preload("res://studies/stair_clouds_isle_art.gd")
const Balustrade = preload("res://scripts/interactables/balustrade.gd")

## Where the aqueduct isle's sky stands it (motif_sky.gd PLACES).
const SKY_OFFSET := Vector3(440.0,14.0,-254.6)
## The legs with a balustrade down their outer cheek.
const RAIL_LEGS := [4,5,6,7]

static func build(study: Node3D, offset: Vector3) -> void:
	var host: Node3D = preload("res://scripts/interactables/aqueduct_foot_route.gd").host_of(study)
	var by := Transform3D(Basis.IDENTITY,offset)
	for s: int in RAIL_LEGS:
		host.balustrade(Balustrade.grand_stair_rail(by*Stair.leg_frame(s),-1.0),400+s,0.35)
	for i in range(4):
		var p := Stair.side_at(0,-4.5+3.6*i,Stair.W+2.2)
		host.bob_slab(by*Vector3(p.x,Stair.TOP+1.0+0.9*i,p.y),Vector3(2.4,0.7,2.2),0.2*i,420+i)
	# On its own scene its spots are the only ones (the aqueduct isle's
	# route adds them to its own).
	if offset == Vector3.ZERO: preload("res://scripts/interactables/aqueduct_foot_route.gd").start_at(study,spots(offset))

## Where --foot-at= starts him on it: [feet, the way faced (x, z)].
static func spots(offset: Vector3) -> Dictionary:
	var top := Stair.leg_frame(7)
	var head_feet := top*Vector3(-1.2,Stair.STEP,-5.8)
	var down := -(top.basis*Vector3.FORWARD)
	var lawn := Stair.side_at(0,-8.0,Stair.W-0.8)
	var along := Stair.tangent_of(0)
	return {
		"stair":[head_feet+offset,Vector2(down.x,down.z).normalized()],
		"stair_slabs":[Vector3(lawn.x,Stair.TOP,lawn.y)+offset,along],
	}
