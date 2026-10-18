extends "res://scripts/kit_isle/motif_greybox.gd"
## The coin track bench's place (studies/coin_track_bench.gd stands it in
## the motif yard; not in the registry, not a level): two flat KitLand
## discs 8 m apart and one short loop of the coin track kit
## (scripts/kit_isle/coin_track.gd) over them. Each disc carries a
## straight, a launch lip with its side rail, an arc round its middle and,
## on the far side, the cradle the other disc's flight lands in: the loop
## runs out over the gap one way and back over it the other. One gate on
## the west disc's north straight opens onto a little field (its rim kerb
## and a chicane); two coins lap. Plan frame: x east, z south, y up.

const CoinTrack = preload("res://scripts/kit_isle/coin_track.gd")

const TURF_SEED := 6300
## The discs: centre (x, z), radius, top, keel depth, ripple.
const DISCS := [
	{"name":"WestDisc","at":Vector2(-18.0,0.0),"r":14.0,"top":0.0,"depth":7.0,"wobble":0.02,"seed":0},
	{"name":"EastDisc","at":Vector2(18.0,0.0),"r":14.0,"top":0.0,"depth":7.0,"wobble":0.02,"seed":1},
]
## Coins on the lap, half a lap apart.
const COINS := 2

## Where each flight's lip edge and catch are (x, z on the lanes z -5 / +5),
## the lip's rise, the cradle's sink, the kick's up speed (as the Coin
## Circuit's 15 m flights: kick_for gives their 17.9 along).
const LANE := 5.0
const LIP_EDGE := 5.92
const CATCH := 9.08
const LIP_UP := 0.5
const BOWL := -0.35
const KICK_UP := 15.3

## The bench's track description (scripts/kit_isle/coin_track.gd's header).
static func track_data() -> Dictionary:
	var z := LANE
	var lip_e := Vector3(-LIP_EDGE,LIP_UP,-z)
	var catch_e := Vector3(CATCH,BOWL,-z)
	var lip_w := Vector3(LIP_EDGE,LIP_UP,z)
	var catch_w := Vector3(-CATCH,BOWL,z)
	return {
		"lap_speed":5.04,
		"clear":2.3,"kerb":Vector2(0.5,0.7),"cradle_kerb":1.0,"bed":0.25,
		"lap":[
			# The west disc's north straight, east, through the gate.
			{"k":"roll","a":Vector3(-18.0,0.0,-z),"b":Vector3(-LIP_EDGE-3.0,0.0,-z)},
			{"k":"lip","name":"east","a":Vector3(-LIP_EDGE-3.0,0.0,-z),"b":lip_e,"kick":CoinTrack.kick_for(lip_e,catch_e,KICK_UP),"rail":1.0},
			{"k":"fly","name":"east","a":lip_e,"b":catch_e},
			# Caught on the east disc, up out of the bowl, round its middle.
			{"k":"roll","a":catch_e,"b":catch_e+Vector3(1.0,0.0,0.0)},
			{"k":"roll","a":catch_e+Vector3(1.0,0.0,0.0),"b":Vector3(CATCH+3.3,0.0,-z)},
			{"k":"roll","a":Vector3(CATCH+3.3,0.0,-z),"b":Vector3(18.0,0.0,-z)},
			{"k":"arc","c":Vector3(18.0,0.0,0.0),"r":z,"from":-90.0,"to":90.0,"y":Vector2(0.0,0.0)},
			# Back west the same way.
			{"k":"roll","a":Vector3(18.0,0.0,z),"b":Vector3(LIP_EDGE+3.0,0.0,z)},
			{"k":"lip","name":"west","a":Vector3(LIP_EDGE+3.0,0.0,z),"b":lip_w,"kick":CoinTrack.kick_for(lip_w,catch_w,KICK_UP),"rail":1.0},
			{"k":"fly","name":"west","a":lip_w,"b":catch_w},
			{"k":"roll","a":catch_w,"b":catch_w+Vector3(-1.0,0.0,0.0)},
			{"k":"roll","a":catch_w+Vector3(-1.0,0.0,0.0),"b":Vector3(-CATCH-3.3,0.0,z)},
			{"k":"roll","a":Vector3(-CATCH-3.3,0.0,z),"b":Vector3(-18.0,0.0,z)},
			{"k":"arc","c":Vector3(-18.0,0.0,0.0),"r":z,"from":90.0,"to":270.0,"y":Vector2(0.0,0.0)},
		],
		"cradles":[
			{"name":"east","rim":catch_e-Vector3(3.0,0.0,0.0),"catch":catch_e,"len":6.0,"bowl":BOWL},
			{"name":"west","rim":catch_w+Vector3(3.0,0.0,0.0),"catch":catch_w,"len":6.0,"bowl":BOWL},
		],
		"gates":[
			{"name":"north","field":"north","on":Vector3(-13.0,0.0,-z),"at":Vector3(-13.0,0.0,-z-1.65),"out":Vector3(0.0,0.0,-1.0)},
		],
		"gate_gap":3.0,
		"rim_kerbs":[{"name":"north","c":Vector3(-18.0,0.0,0.0),"r":12.5,"from":235.0,"to":305.0}],
		"chicane":{"c":Vector3(-18.0,0.0,0.0),"r":9.5,"from":255.0,"to":285.0},
		"hunt":flagged("--hunt"),"hunt_cap":1,
		"hub":{"at":Vector2(-18.0,0.0),"r":13.0},
	}

static var _track: RefCounted = null
static func track() -> RefCounted:
	if _track == null: _track = CoinTrack.new(track_data())
	return _track

func slug() -> String:
	return "coin_track_bench"

func isle_name() -> String:
	return "Coin Track Bench"

func epithet() -> String:
	return "Two discs, one loop, two coins."

func brief() -> String:
	return "The coin track kit on a bench: a straight, a lip, a flight over the gap, a cradle, an arc, and back.\n--hunt lets a coin leave through the north gate after you."

## West of the west disc's arc, facing the loop.
func start() -> Vector3:
	return Vector3(-28.0,0.0,0.0)

func rims() -> Array:
	return [{"name":"west","at":Vector3(-30.5,0.0,0.0),"face":Vector3(-1.0,0.0,0.0),"run_up":6.0,"lip":1.5}]

func summit() -> Vector3:
	return Vector3(0.0,1.0,0.0)

# --- The land (the turfed greybox pass) ------------------------------------------------

func turf_seed() -> int:
	return TURF_SEED

## A disc's outline: its circle, rippled by two low waves, 64 points.
static func outline_of(d: Dictionary) -> Array:
	var out: Array = []
	var c: Vector2 = d.at
	var r := float(d.r)
	var w := float(d.wobble)
	var s := float(d.seed)*1.7
	for k in 64:
		var a := TAU*k/64.0
		out.append(c+Vector2(cos(a),sin(a))*r*(1.0+w*(0.6*sin(3.0*a+s)+0.4*sin(5.0*a+s*2.3))))
	return out

## Each disc, its turf cut under the track's beds through the kit's hook.
func turf_islands() -> Array:
	var out: Array = []
	for d: Dictionary in DISCS:
		out.append({"name":d.name,"outline":outline_of(d),"seed":TURF_SEED+int(d.seed),
			"ground":track().ground(float(d.top)),"cell":CoinTrack.CELL,
			"top":float(d.top),"depth":float(d.depth),"resample":[60.0,200,64]})
	return out

## The track worn bare (nothing grows on it).
static func wear(p: Vector2) -> float:
	return 0.6 if track().bare(p) else 0.0

func turf_tone() -> Callable:
	return KitLook.turf(TURF_SEED,func(_p: Vector2) -> float: return 0.0)

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top(),func(p: Vector2) -> float: return wear(p))

func turf_cost() -> int:
	return 300

func warm_turf() -> void:
	super.warm_turf()
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	track().warm()

## The discs' keels and the track's stone.
func _solids() -> Array:
	return super._solids()+track().solids()

## The track's stone.
func dress(root: Node3D) -> void:
	track().build(root)

# --- What moves ------------------------------------------------------------------------

## The kit's circuit and its coins, half a lap apart (the field's reset
## mints them again; the circuit mints a lost one back into a cradle).
func live(g: Node) -> void:
	var t := track()
	var circuit: Node3D = t.circuit(g.offset)
	g.add_child(circuit)
	for i in COINS:
		circuit.mint(g.stage.enemies,t.lap_length()*float(i)/float(COINS))
