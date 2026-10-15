extends Node3D
## The title's backdrop (docs/design/roguelike/game-v1-launcher.md): the
## city kit's grand stair, its causeway and drum well, stood in the
## underground look and seen from above by a slow camera that sweeps round
## it. Fire bowls along the stone are the supporting light; far pillar-isles,
## a temple pyramid and lit beacon towers stand in the haze beyond.
## A few hundred ms of building: no generated layer.
const Underground = preload("res://scripts/underground/underground.gd")
const Fires = preload("res://scripts/city_kit_fires.gd")
const CityKit = preload("res://scripts/city_kit.gd")
const CityStone = preload("res://scripts/city_kit_stone.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")

## Pillar C (the stair's), the stair on it (foot at +z) and the causeway on
## from its summit (the city kit gallery's arrangement, studies/city_kit_gallery.gd).
const SEED := 4207
const WEATHERED := 0.45
const C_APOTHEM := 44.0
const STAIR_AT := Vector3(0.0,0.0,24.0)
## The orbit: the eye sits RADIUS out from TARGET (over the stair) and
## HEIGHT above it, looking down at the stair's far end, swung SWEEP rad
## either side of the stair's foot by sin(t*RATE): its fastest turn is
## SWEEP*RATE rad/s, under the old title's SPEED (front_door.gd, 0.0230).
const TARGET := Vector3(0.0,6.0,-4.0)
const AIM := Vector3(0.0,4.0,-26.0)
const RADIUS := 62.0
const HEIGHT := 36.0
const SWEEP := 0.8
const RATE := 0.0280
const FOV := 55.0

var camera: Camera3D
var under: Node3D
var built_ms := 0
## Read by the underground look (its study's environment).
var _environment: Environment
var _t := 0.0
## Seconds into the sweep to start at (a still can ask: --orbit-t=).
var start_t := 0.0

func _ready() -> void:
	var began := Time.get_ticks_msec()
	CityStone.warm()
	_build_light()
	_build_city()
	under = (Underground as GDScript).new()
	under.name = "Underground"
	add_child(under)
	under.setup(self)
	under.set_preset("haze")
	# The grass graded to the dim umber look whatever the launch flags are, a
	# little less light in the air than the haze preset so the bowls read, and
	# a thicker haze so the far isles fall back into it.
	under.ground = "grass"
	under.knobs.merge({"ambient":0.62,"exposure":0.95,"fog":0.0032},true)
	# The wanderer's torch has no wanderer here: the bowls are the light.
	under.torch.visible = false
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--orbit-t="): start_t = float(a.get_slice("=",1))
	_t = start_t
	_orbit()
	built_ms = Time.get_ticks_msec()-began
	print("game title scene: built in %d ms" % built_ms)

func _build_light() -> void:
	_environment = Environment.new()
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.1
	camera.far = 900.0
	add_child(camera)
	camera.current = true

func _build_city() -> void:
	var art := Node3D.new()
	art.name = "City"
	add_child(art)
	var c := CityKit.pillar(SEED+1,WEATHERED,{"apothem":C_APOTHEM,"crown":"flat","climb":-1,"courses":3,"depth":120.0})
	art.add_child(c)
	var stair := CityKit.stair(SEED+2,WEATHERED,{})
	stair.position = STAIR_AT
	art.add_child(stair)
	var length := CityKit.STAIR_FLIGHTS*CityKit.STAIR_STEPS*CityKit.TREAD+CityKit.STAIR_FLIGHTS*CityKit.LANDING
	var summit := STAIR_AT+Vector3(0.0,CityKit.STAIR_FLIGHTS*CityKit.COURSE,-length)
	var causeway := CityKit.causeway(SEED+3,WEATHERED,{"drop":60.0})
	causeway.position = summit
	art.add_child(causeway)
	var a_apothem := CityKit.DRUM_RADIUS+CityKit.LANDING
	var a_at := summit+Vector3(0.0,0.0,-CityKit.SPANS*CityKit.SPAN-a_apothem)
	var a := CityKit.pillar(SEED+4,WEATHERED,{"apothem":a_apothem,"well":CityKit.DRUM_RADIUS,"climb":-1})
	a.position = a_at
	art.add_child(a)
	var drum := CityKit.drum_stair(SEED+5,WEATHERED,{"rim":false})
	drum.position = a_at
	art.add_child(drum)
	# The fire bowls along them: supporting light on the stone.
	var n := 0
	for piece: Node3D in [stair,causeway,drum,a]:
		for at: Vector3 in (piece.get_meta("mounts") as Dictionary).cresset:
			if piece == causeway and n%2 == 1:
				n += 1
				continue
			Fires.cresset(art,Transform3D(Basis.IDENTITY,piece.to_global(at)),{"size":"cresset","lit":true,"seed":n,"name":"Bowl%d" % n})
			n += 1
	# The grass on C's crown.
	var k := 0
	for w: Dictionary in c.get_meta("walk_areas",[]):
		GroundCover.cover(c,w.poly,"grass",float(w.y),SEED+k,{"tufts":1.6,"under":1.0})
		k += 1
	# The far layers, in the haze: [x, y, z, apothem, courses].
	var far := [[-150.0,-6.0,-60.0,26.0,3],[130.0,-26.0,-150.0,30.0,3],[-90.0,18.0,-250.0,32.0,2],[210.0,6.0,-20.0,22.0,3],[-250.0,-20.0,-160.0,36.0,2],[40.0,40.0,-380.0,40.0,2],[-230.0,10.0,40.0,28.0,3],[260.0,-14.0,-250.0,32.0,2]]
	k = 0
	for f: Array in far:
		_pillar(art,Vector3(float(f[0]),float(f[1]),float(f[2])),float(f[3]),int(f[4]),50+k)
		k += 1
	var pyr := CityKit.piece("city_pyramid",61,0.5)
	if pyr != null:
		pyr.position = Vector3(40.0,40.0,-380.0)
		art.add_child(pyr)

func _pillar(art: Node3D, at: Vector3, apothem: float, courses: int, seed_value: int) -> void:
	var p := CityKit.pillar(seed_value,0.5,{"apothem":apothem,"courses":courses,"climb":-1,"depth":140.0,"crown":"paved"})
	p.position = at
	art.add_child(p)
	var t := Fires.tower(art,Transform3D(Basis(Vector3.UP,float(seed_value)*0.7),at),{"tiers":3,"base":9.0,"steps":false,"lit":true,"seed":seed_value,"beam":3.0})
	t.crown.beacon.draw = 0.0

func _process(delta: float) -> void:
	_t += delta
	_orbit()

## The eye now: round the stair, sweeping SWEEP either side of its foot.
func _orbit() -> void:
	var yaw := SWEEP*sin(_t*RATE)
	camera.global_position = TARGET+Vector3(sin(yaw)*RADIUS,HEIGHT,cos(yaw)*RADIUS)
	camera.look_at(AIM,Vector3.UP)
