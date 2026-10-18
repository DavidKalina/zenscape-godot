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
const Knobs = preload("res://scripts/layout_knobs.gd")

## The bobbing slabs' short cut up the first flight, as knobs: how many,
## each one's rise over the last (m), their spacing along the flight (m),
## how far out past the stair's outer cheek they stand (m), and how far the
## last one bows further out (m; the ones between on a curve, 0 straight).
const SLAB_CUT := "stair_clouds/slab_cut"
const SLAB_KNOBS := [
	["count","slabs",4,1,12,1],
	["rise","rise (m)",0.9,0.0,2.4,0.05],
	["spacing","spacing (m)",3.6,2.4,7.0,0.1],
	["out","out from the cheek (m)",2.2,0.8,8.0,0.1],
	["curve","curve (m)",0.0,-6.0,6.0,0.25],
]

## The slab cut placed on `host` in the stair's frame `by` at knob values
## `k`: `stair_clouds/bob_slab_<n>` from the lawn up. Returns their names.
static func slab_cut(k: Dictionary, host: Node3D, by: Transform3D) -> Array:
	var was: String = host.naming
	host.name_under("stair_clouds")
	var names: Array = []
	var n := int(k.count)
	for i in range(n):
		var f := float(i)/float(maxi(n-1,1))
		var p := Stair.side_at(0,-4.5+float(k.spacing)*i,Stair.W+float(k.out)+float(k.curve)*f*f)
		host.call_next("bob_slab_%d" % (i+1))
		host.bob_slab(by*Vector3(p.x,Stair.TOP+1.0+float(k.rise)*i,p.y),Vector3(2.4,0.7,2.2),0.2*i,420+i)
		names.append("stair_clouds/bob_slab_%d" % (i+1))
	host.name_under(was)
	return names

static func build(study: Node3D, offset: Vector3) -> void:
	var host: Node3D = preload("res://scripts/interactables/aqueduct_foot_route.gd").host_of(study)
	var by := Transform3D(Basis.IDENTITY,offset)
	# Each by its name (`stair_clouds/balustrade_<n>`, `bob_slab_<n>`).
	host.name_under("stair_clouds")
	for s: int in RAIL_LEGS:
		host.balustrade(Balustrade.grand_stair_rail(by*Stair.leg_frame(s),-1.0),400+s,0.35,Balustrade.grand_stair_floor(by*Stair.leg_frame(s),-1.0))
	host.name_under("")
	# The slab cut, by its knobs (the world view's panel, scripts/
	# layout_knobs.gd): rebuilt alone when one changes.
	Knobs.register(SLAB_CUT,"stair to the clouds: slab cut",SLAB_KNOBS,slab_cut.bind(host,by))
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
