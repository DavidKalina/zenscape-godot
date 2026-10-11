extends "res://studies/kit_isle.gd"
## The bell spires isle (docs/scenic/bell-spires.md): a hand-built sky
## isle motif in the aqueduct isle's world, smaller round but tall. A
## crescent of turf over hanging rock, and out of it and round it a stand
## of rock spires in beds of the isle's rock, the hero spire in the middle
## crowned by a ruined belfry with its bell still hanging (scripts/
## ruin_kit_belfry.gd). Four rope bridges (scripts/rope_bridge.gd, the
## spring-sim bridges) radiate from the hero at four heights, each on stone
## anchors, from the landings of a stair cut into the hero's rock that
## winds up it from the low stack's bridge to the summit; two spires stand
## free on keels of their own (the south stack, the needle with its turret),
## two as a split fin with a chimney between them. The art: studies/
## bell_spires_isle_art.gd.
##
## Everything else is the kit isles' (studies/kit_isle.gd, docs/scenic/
## kit-isle-shared.md): the pilot and his moves, the rope bridges underfoot,
## the game's look, its presets (L / Shift+L, --look=), its light, air and
## weather, the ground and rock, the grass and flowers, the life (its
## perches and tokens this isle's: studies/bell_spires_isle_life.gd), the
## sky round it (its plane tokens this isle's own), the plane (F), the
## lodestone (under the bell) and every opt-out flag.
##   ./run-bell-spires.command [--look=first_snow]
##   godot --path . res://studies/bell_spires_isle.tscn -- --no-title [--capture=out.png --at=x,y,z --look=x,y,z] [--place=x,y,z[,turn]]
## --no-flora, --no-life (--no-undergrowth, --no-butterflies, --no-fireflies,
## --no-birds, --no-wind-life, --no-tokens), --no-sky (--no-far-isles,
## --no-airships, --no-traffic, --no-sky-life, --no-motes, --no-sky-tokens),
## --fly, --no-lode, --carry, --stone-plane, --stone=<look>, as the
## aqueduct isle's. --no-bell keeps the bells still.
const Spires = preload("res://studies/bell_spires_isle_art.gd")
const Belfry = preload("res://scripts/ruin_kit_belfry.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const SpiresLife = preload("res://studies/bell_spires_isle_life.gd")
const SpiresSky = preload("res://studies/bell_spires_isle_sky.gd")
## The isle itself (its art, turf and bells), built here at the origin as
## the aqueduct isle's sky places it elsewhere (scripts/kit_isle/
## motif_bell_spires.gd).
const Motif = preload("res://scripts/kit_isle/motif_bell_spires.gd")

var motif := Motif.new()
var spire_nodes := {}
var belfry: Node3D
var bridges: Array[MeshInstance3D] = []
var bells: Array[Dictionary] = []
var _bell_grounded := true

func _ready() -> void:
	motif.still_bells = preload("res://scripts/launch_args.gd").user_args().has("--no-bell")
	super._ready()

## No pack: the isle is its own one station, its start by the low stack.
func _load_pack() -> void:
	var l := Spires.layout()
	start = l.start
	start_face = l.start_face
	lost = Spires.TOP-70.0
	_last_stood = start
	stations = [{"key":1,"name":"Bell spires","spawn":start,"face":start_face,"parts":[]}]

func isle_name() -> String:
	return motif.isle_name()

func isle_card() -> Dictionary:
	return motif.isle_card()

func isle_top() -> float:
	return motif.top()

func isle_summit() -> Vector3:
	return motif.summit()

func flora_site() -> KitFlora.Site:
	return motif.flora_site()

func sky_script() -> Script:
	return SpiresSky

func life_script() -> Script:
	return SpiresLife

func _build_room() -> void:
	_build_art()

func _build_art() -> void:
	var began := Time.get_ticks_msec()
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	motif.build(art)
	spire_nodes = motif.spire_nodes
	belfry = motif.belfry
	bridges = motif.bridges
	bells = motif.bells
	for land: Array in motif.lands: add_turf(land[0],land[1],land[2])
	print("bell spires: %d triangles, built in %d ms" % [triangles(art),Time.get_ticks_msec()-began])

## The walker's ground: the kit's (scripts/kit_isle/deck_ground.gd), the
## bridges' resting decks standing in the physics space as walk boxes, so
## a deck met at rest sags by the sim's drop under him.
func _build_pilot() -> void:
	super._build_pilot()
	(ground as DeckGround).rest_decks = true

## On foot (the kit's step: the bridges take his weight and landings): a
## landing in the belfry rings the bell a little.
func tick(delta: float) -> void:
	super.tick(delta)
	if lode_state == "inspecting" or flying: return
	var landed := motor.grounded and not _bell_grounded
	_bell_grounded = motor.grounded
	if landed: motif.landed(motor.feet)

func fly_step(delta: float, input: Dictionary) -> void:
	super.fly_step(delta,input)
	motif.plane_near(plane.position)

func _process(delta: float) -> void:
	super._process(delta)
	motif.frame(delta,self)

# --- The lodestone, the sky, the life, the grass -----------------------------------

## The lodestone hums on the belfry's floor, under the bell.
func lode_rest_at() -> Vector3:
	return belfry.global_transform*Vector3(0.0,Belfry.FLOOR+LODE_HOVER,0.0)

func lode_hint() -> String:
	return "A lodestone hums under the bell in the belfry: climb the hero spire to it"
