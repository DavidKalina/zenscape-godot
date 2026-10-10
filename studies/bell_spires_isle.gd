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
const BELFRY_SEED := 61
const BRIDGE_SEED := 70
## The bells: how they swing (rad, a pendulum's s), how hard a landing in
## the belfry or a plane passing close (within BELL_NEAR m) pushes them.
const BELL_PERIOD := 2.6
const BELL_DAMP := 0.35
const BELL_LAND := 0.18
const BELL_PLANE := 0.22
const BELL_NEAR := 22.0

var spire_nodes := {}
var belfry: Node3D
var bridges: Array[MeshInstance3D] = []
var bells: Array[Dictionary] = []
var _bell_grounded := true
var _bell_fall := 0.0
var _still_bells := false

func _ready() -> void:
	_still_bells = preload("res://scripts/launch_args.gd").user_args().has("--no-bell")
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
	return "bell spires"

func isle_top() -> float:
	return Spires.TOP

func isle_summit() -> Vector3:
	return Vector3(Spires.HERO.x,Spires.TOP,Spires.HERO.y)

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(Spires.TOP,func(p: Vector2) -> float: return Spires.path_wear(p))

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
	var l := Spires.layout()
	var lands: Array = []
	var isle := Spires.island(11)
	art.add_child(isle)
	lands.append(isle)
	for name: String in l.spires:
		var s: Dictionary = l.spires[name]
		var rock := Spires.spire_rock(s)
		art.add_child(rock)
		var top := Spires.top_turf(s)
		art.add_child(top)
		lands.append(top)
		spire_nodes[name] = rock
	var k := 0
	for name: String in l.stairs:
		art.add_child(Spires.stair_node(l.stairs[name],80+k))
		k += 1
	art.add_child(Spires.floating_stones(91))
	art.add_child(Spires.chockstone(92))
	_crowns(l)
	_bridges(l)
	for land: Node3D in lands: add_turf(land)
	print("bell spires: %d triangles, built in %d ms" % [triangles(art),Time.get_ticks_msec()-began])

## What crowns each spire: the belfry on the hero (its front to the stair's
## arrival), the needle's turret (its door to its bridge), a bell gable on
## the south stack, a broken arch the low stack's bridge goes out through,
## a broken pier on the fin's high stack, a broken pier on its low one.
func _crowns(l: Dictionary) -> void:
	var hero: Dictionary = l.spires.hero
	var arrive: Dictionary = l.stairs.hero.landings[l.stairs.hero.landings.size()-1]
	belfry = Belfry.belfry(BELFRY_SEED,0.45)
	belfry.transform = Transform3D(_facing(Vector2.from_angle(float(arrive.mid))),Vector3(Spires.HERO.x,float(hero.top)+0.3,Spires.HERO.y))
	art.add_child(belfry)
	_add_bell(belfry.get_node("Bell"),1.0)
	var needle: Dictionary = l.spires.needle
	var turret: Node3D = RuinKit.turret(62,0.45)
	turret.transform = Transform3D(_facing(Spires.HERO-(needle.c as Vector2)),Vector3(needle.c.x,Spires.top_height(needle,needle.c)-0.1,needle.c.y))
	art.add_child(turret)
	var south: Dictionary = l.spires.gable
	var gable: Node3D = RuinKit.arch(63,0.35)
	gable.transform = Transform3D(_facing(Spires.HERO-(south.c as Vector2)),Vector3(south.c.x,Spires.top_height(south,south.c)-0.1,south.c.y))
	art.add_child(gable)
	var small := Belfry.bell(64)
	small.position = Vector3(0.0,RuinKit.SPRING+0.55,0.0)
	small.scale = Vector3.ONE*0.62
	gable.add_child(small)
	_add_bell(small,0.62)
	var low: Dictionary = l.spires.low
	var arch: Node3D = RuinKit.arch(65,0.55)
	var out := (Spires.HERO-(low.c as Vector2)).normalized()
	var at: Vector2 = (low.c as Vector2)+out*1.2
	arch.transform = Transform3D(_facing(out),Vector3(at.x,Spires.top_height(low,at)-0.1,at.y))
	art.add_child(arch)
	var fh: Dictionary = l.spires.fin_high
	var stub: Node3D = RuinKit.piece("pier",66,0.7)
	var away: Vector2 = ((fh.c as Vector2)-Spires.HERO).normalized()
	var sp: Vector2 = (fh.c as Vector2)+away*2.0
	stub.transform = Transform3D(_facing(-away),Vector3(sp.x,Spires.top_height(fh,sp)-0.1,sp.y))
	art.add_child(stub)
	var fl: Dictionary = l.spires.fin_low
	var pier: Node3D = RuinKit.piece("fallen_pier",67,0.6)
	pier.transform = Transform3D(_facing(Vector2(1.0,0.3)),Vector3(fl.c.x,Spires.top_height(fl,fl.c)-0.05,fl.c.y))
	art.add_child(pier)

## A basis turning a piece's front (+Z) toward `way` (x, z).
static func _facing(way: Vector2) -> Basis:
	return Basis(Vector3.UP,atan2(way.x,way.y))

## The rope bridges: the footbridge's live rope bridge (its sag, bounce,
## sway and shudder) between the stone anchors at each end, its deck
## walked on clean boxes along its resting curve (the walker's ground adds
## its drop: `BridgeGround`).
func _bridges(l: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Bridges"
	art.add_child(holder)
	var k := 0
	for br: Dictionary in l.bridges:
		var a: Vector3 = br.a
		var b: Vector3 = br.b
		var seed_value := BRIDGE_SEED+k
		var mesh := Footbridge.build_mesh(a,b,seed_value)
		var live: MeshInstance3D = Footbridge.live(mesh,a,b,seed_value)
		live.name = "Bridge_"+str(br.name)
		holder.add_child(live)
		bridges.append(live)
		var body := StaticBody3D.new()
		body.name = "Deck_"+str(br.name)
		var span := Vector2(b.x-a.x,b.z-a.z).length()
		var pieces := maxi(8,int(ceil(span/0.5)))
		for i in range(pieces):
			var p0 := _deck(a,b,span,float(i)/pieces)
			var p1 := _deck(a,b,span,float(i+1)/pieces)
			var along := p1-p0
			var box := BoxShape3D.new()
			box.size = Vector3(Footbridge.WIDTH+0.06,0.16,along.length()+0.04)
			var shape := CollisionShape3D.new()
			shape.shape = box
			var basis := Basis.looking_at(along.normalized(),Vector3.UP)
			shape.transform = Transform3D(basis,(p0+p1)*0.5-basis.y*0.08)
			body.add_child(shape)
		holder.add_child(body)
		for end: Array in [[a,b],[b,a]]:
			# The kit's anchor, the bridge going out toward -Z: its sill on a
			# coursed plinth out of the lip.
			var anchor := RuinKit.bridge_anchor(seed_value*3+int(end[0] == b),0.45,Footbridge.WIDTH,
				{"post_x":Footbridge.WIDTH*0.5+0.33,"post_z":0.0,"sill":Vector3(0.75,0.11,0.55),"sill_at":Vector3(0.0,-0.11,0.15),
				"plinth":Vector3(1.15,1.4,0.375),"plinth_z":0.2})
			var way: Vector3 = (end[1] as Vector3)-(end[0] as Vector3)
			way.y = 0.0
			anchor.transform = Transform3D(Basis.looking_at(way.normalized(),Vector3.UP),end[0])
			holder.add_child(anchor)
		k += 1

## The deck's resting top at `t` along the bridge from `a` to `b`.
static func _deck(a: Vector3, b: Vector3, span: float, t: float) -> Vector3:
	return a.lerp(b,t)+Vector3.UP*Footbridge.lift(span,t)

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
	if landed and belfry != null and not bells.is_empty():
		var local := belfry.global_transform.affine_inverse()*motor.feet
		if absf(local.x) < 1.4 and absf(local.z) < 1.4 and local.y > Belfry.FLOOR-0.3: _ring(bells[0],BELL_LAND)

func fly_step(delta: float, input: Dictionary) -> void:
	super.fly_step(delta,input)
	for bell: Dictionary in bells:
		var d: float = (bell.node as Node3D).global_position.distance_to(plane.position)
		if d < BELL_NEAR and float(bell.pushed) <= 0.0:
			_ring(bell,BELL_PLANE*(1.0-d/BELL_NEAR))
			bell.pushed = 1.5

# --- The bells ---------------------------------------------------------------------

func _add_bell(node: Node3D, size: float) -> void:
	bells.append({"node":node,"angle":0.0,"speed":0.0,"size":size,"pushed":0.0,"salt":float(bells.size())*1.7})

func _ring(bell: Dictionary, push: float) -> void:
	bell.speed = float(bell.speed)+push*TAU/BELL_PERIOD

## The bells swing as pendulums: the breeze leans on them (the atmosphere's
## gusts), a landing or a plane pushes them.
func _swing(delta: float) -> void:
	if _still_bells or delta <= 0.0: return
	var w := TAU/BELL_PERIOD
	var air := 0.0
	if _atmosphere != null and _atmosphere.get("_air_strength") != null:
		air = maxf(float(_atmosphere._air_strength)+float(_atmosphere.swell),0.0)*float(_atmosphere.gust_at(float(_atmosphere._wind_time)))
	for bell: Dictionary in bells:
		var size: float = bell.size
		var lean := air*0.04*(1.0+0.5*sin(_motion_time*0.7+float(bell.salt)))/size
		var accel := -w*w*(float(bell.angle)-lean)-BELL_DAMP*float(bell.speed)
		bell.speed = float(bell.speed)+accel*delta
		bell.angle = clampf(float(bell.angle)+float(bell.speed)*delta,-0.7,0.7)
		bell.pushed = maxf(float(bell.pushed)-delta,0.0)
		(bell.node as Node3D).rotation = Vector3(float(bell.angle),0.0,0.0)

func _process(delta: float) -> void:
	super._process(delta)
	_swing(delta)

# --- The lodestone, the sky, the life, the grass -----------------------------------

## The lodestone hums on the belfry's floor, under the bell.
func lode_rest_at() -> Vector3:
	return belfry.global_transform*Vector3(0.0,Belfry.FLOOR+LODE_HOVER,0.0)

func lode_hint() -> String:
	return "A lodestone hums under the bell in the belfry: climb the hero spire to it"
