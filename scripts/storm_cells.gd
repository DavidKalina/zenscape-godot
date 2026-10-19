extends Node3D
## A storm cell (a prototype; scripts/plane_weather.gd owns it): smaller
## than the front, a single dark tower with a rain shaft hanging under it,
## that wanders in on the wind from far off, passes over and goes on.
##
##   the tower  one of the sky's own towers (scripts/sky_towers.gd `fixed`),
##              the farthest from the eye, taken for the cell: held grown
##              (SkyTowers `held`), lifted LIFT m so its foot stands over
##              the isles, and carried with the cell (the cloud drift leaves
##              a held tower be: scripts/sky_drift.gd). It fades in where
##              the cell starts and is let go to the sky when it ends.
##   the dark   the cloud over and round it storm dark, the land under it
##              shaded, and the rain shaft, a column SHAFT m round from the
##              tower's foot into the heaps, in streaks: all drawn from the
##              zs_cell global (shaders/reference_globals.gdshaderinc
##              `zs_cell_*`; the cloud volume's composite draws the shaft
##              with its cloud, the land shader the shade).
##   the storm  `storm_at`: 1 in the shaft, easing out to nothing ROUGH
##              shafts' widths from its middle, under the tower's top; the
##              plane's rough air and rain follow it (plane_weather `step`).
##   lightning  while it is in, it strikes every BOLT_EVERY s or so (a
##              mean): bolts from its tower's foot down through the shaft
##              (onto an isle's turf when over one), and flashes inside its
##              tower (scripts/plane_lightning.gd `strike_over`).
## `send` starts one START m upwind of a point, coming at it at SPEED m/s;
## it ends PAST m downwind of it. One at a time. They come on their own
## (`due`, asked by plane_weather): the first FIRST s in, then EVERY s after
## the last one ends, aimed (`aim`) at the field or one of the far isles.
##   --cell-at=x,z    one already standing there (for stills), moving on
##   --cell-speed=N   how fast cells go (m/s; 0 holds one still)
##   --cell-every=N   one on its own every N s or so (0: none on their own)
##   --cell-first=N   the first on its own N s in
const SkyTowers = preload("res://scripts/sky_towers.gd")

const START := 1600.0
const SPEED := 14.0
const PAST := 1200.0
const SHAFT := 105.0
const ROUGH := 2.0
const LIFT := 265.0
## Its tower's top over the ground (m), past which the storm thins.
const TOP := 650.0
## How long it takes to come in (s), and over how many m at the end it goes.
const COME := 6.0
const GO := 300.0
## On their own: the first (s, a range), then the wait after one ends.
const FIRST := Vector2(35.0,70.0)
const EVERY := Vector2(140.0,260.0)
## How far off its aim it may pass (m, sideways).
const AIM_SPREAD := 160.0
## Its lightning: the mean wait (s), from how far in (strength), the share
## that are bolts (the rest flash inside its tower), and the tower's foot
## (SkyTower SEA -105 + LIFT) the bolts drop from.
const BOLT_EVERY := 6.0
const BOLT_FROM := 0.5
const BOLT_SHARE := 0.65
const FOOT := LIFT-105.0

var active := false
## Its middle (y 0), the way it goes (flat, unit), the point it was sent at,
## and how far in it has come (0 to 1).
var centre := Vector3.ZERO
var way := Vector3.FORWARD
var target := Vector3.ZERO
var strength := 0.0
var _scene: Node3D
var _towers: Node3D
var _slot := -1
var _age := 0.0
var speed := SPEED
## Its lightning's (scripts/plane_lightning.gd; set by plane_weather).
var lightning: Node3D
## Whether they come on their own, the wait for the next (s), its range.
var auto := true
var every := EVERY
var _wait := 0.0
var _bolt_wait := 2.0
var bolts := 0
var _rng := RandomNumberGenerator.new()

func setup(scene: Node3D) -> void:
	name = "StormCells"
	_scene = scene
	_rng.randomize()
	_wait = _rng.randf_range(FIRST.x,FIRST.y)
	for arg in preload("res://scripts/launch_args.gd").user_args():
		var a := str(arg)
		if a.begins_with("--cell-speed="): speed = maxf(0.0,float(a.get_slice("=",1)))
		elif a.begins_with("--cell-every="):
			var n := float(a.get_slice("=",1))
			auto = n > 0.0
			every = Vector2(n*0.8,n*1.2)
		elif a.begins_with("--cell-first="): _wait = float(a.get_slice("=",1))
	RenderingServer.global_shader_parameter_set("zs_cell",Vector4.ZERO)

## Sends one in on the wind (`toward`: the way the sky's wind blows, radians
## round x then z) at `at`.
func send(toward: float, at: Vector3) -> void:
	way = Vector3(cos(toward),0.0,sin(toward))
	target = Vector3(at.x,0.0,at.z)
	_start(target-way*START)

## One standing at `at` now, already in, going on along `toward`.
func stand(toward: float, at: Vector3) -> void:
	way = Vector3(cos(toward),0.0,sin(toward))
	target = Vector3(at.x,0.0,at.z)
	_start(target)
	_age = COME

func _start(from: Vector3) -> void:
	if active: end()
	centre = from
	_age = 0.0
	strength = 0.0
	active = true
	var host: Node = _scene.cloud_host()
	_towers = host.towers if host != null else null
	_slot = -1
	if _towers != null and not (_towers.fixed as Array).is_empty():
		# The sky's tower farthest from the eye: the least missed.
		var eye: Vector3 = _scene.camera.global_position if _scene.camera != null else Vector3.ZERO
		var far := -1.0
		for i in range((_towers.fixed as Array).size()):
			var spot: Vector3 = _towers.fixed[i]+_towers.position
			var d := Vector2(spot.x-eye.x,spot.z-eye.z).length()
			if d > far:
				far = d
				_slot = i
		_towers.held[Vector2i(_slot,0)] = SkyTowers.MATURE
		_place(true)
	_publish()

## Over: its tower given back to the sky where it stands.
func end() -> void:
	if not active: return
	active = false
	strength = 0.0
	if _towers != null and _slot >= 0:
		_towers.held.erase(Vector2i(_slot,0))
		var spot: Vector3 = _towers.fixed[_slot]
		_towers.fixed[_slot] = Vector3(spot.x,0.0,spot.z)
		var b: Variant = _towers.built.get(_towers._key(Vector2i(_slot,0)))
		if b != null:
			b.home = _towers.fixed[_slot]
			(b.node as Node3D).position = b.home
	_slot = -1
	_wait = _rng.randf_range(every.x,every.y)
	_publish()

## Whether one is due on its own now (counts down while none is out; the
## caller sends it, or not, and the wait starts again when it ends).
func due(delta: float) -> bool:
	if active or not auto: return false
	_wait -= delta
	return _wait <= 0.0

## Where one on its own is aimed: the field or a far isle (the scene's
## `isles`), a little to the side.
func aim(toward: float) -> Vector3:
	var spots: Array[Vector3] = [Vector3.ZERO]
	var isles: Variant = _scene.get("isles")
	if isles is Array:
		for isle: Dictionary in isles: spots.append(Vector3(isle.middle.x,0.0,isle.middle.z))
	var side := Vector3(-sin(toward),0.0,cos(toward))
	return spots[_rng.randi_range(0,spots.size()-1)]+side*_rng.randf_range(-AIM_SPREAD,AIM_SPREAD)

func step(delta: float) -> void:
	if not active: return
	_age += delta
	centre += way*speed*delta
	var beyond := (centre-target).dot(way)
	strength = smoothstep(0.0,COME,_age)*(1.0-smoothstep(PAST-GO,PAST,beyond))
	_place(false)
	_publish()
	_lightning(delta)
	if beyond > PAST: end()

func _lightning(delta: float) -> void:
	if lightning == null or strength < BOLT_FROM: return
	if lightning._strike_at >= 0:
		# Flagged (stills): one bolt at that frame with `--strike-kind=cell`.
		if lightning._kind == "cell" and lightning._frames == lightning._strike_at:
			lightning.strike_over(centre+way*SHAFT*0.3,"bolt",FOOT+20.0,_foot_at(centre))
		return
	_bolt_wait -= delta
	if _bolt_wait > 0.0: return
	_bolt_wait = maxf(-log(1.0-_rng.randf()*0.98)*BOLT_EVERY,0.8)
	if _rng.randf() < 0.25: _bolt_wait = _rng.randf_range(0.6,1.8)
	var spot := centre+Vector3(_rng.randf_range(-1.0,1.0),0.0,_rng.randf_range(-1.0,1.0))*SHAFT*0.7
	lightning.strike_over(spot,"bolt" if _rng.randf() < BOLT_SHARE else "inside",FOOT+_rng.randf_range(0.0,40.0),_foot_at(spot))
	bolts += 1

## Where a bolt at `p` ends: an isle's turf under it, else the cloud sea.
func _foot_at(p: Vector3) -> float:
	var isles: Variant = _scene.get("isles")
	if isles is Array:
		for isle: Dictionary in isles:
			if Vector2(p.x-isle.middle.x,p.z-isle.middle.z).length() < float(isle.radius)*0.6:
				return float(isle.top)
	return -105.0

## Its tower over its middle (the sky's towers stand in its home frame).
func _place(fresh: bool) -> void:
	if _towers == null or _slot < 0: return
	var spot := centre-_towers.position
	spot.y = LIFT
	_towers.fixed[_slot] = spot
	var b: Variant = _towers.built.get(_towers._key(Vector2i(_slot,0)))
	if b == null: return
	b.home = spot
	(b.node as Node3D).position = spot
	if fresh:
		b.age = 0.0
		(b.material as ShaderMaterial).set_shader_parameter("strength",0.0)

func _publish() -> void:
	RenderingServer.global_shader_parameter_set("zs_cell",Vector4(centre.x,centre.z,SHAFT,strength) if active else Vector4.ZERO)

## The storm the cell makes at `p` (0 to 1).
func storm_at(p: Vector3) -> float:
	if not active: return 0.0
	var d := Vector2(p.x-centre.x,p.z-centre.z).length()
	return strength*(1.0-smoothstep(SHAFT*0.9,SHAFT*ROUGH,d))*(1.0-smoothstep(TOP,TOP+150.0,p.y))

## How far its middle is from `p` along the ground (m).
func off(p: Vector3) -> float:
	return Vector2(p.x-centre.x,p.z-centre.z).length()
