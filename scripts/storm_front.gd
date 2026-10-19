extends Node3D
## A storm front (a prototype; scripts/plane_weather.gd owns it): a line of
## towering cloud that comes in on the wind from far off, with a wall of
## rain hanging along its leading edge, passes over the field and goes on.
##
##   the line   COUNT towers (SkyTowers, scripts/sky_towers.gd), SPACING m
##              apart across the wind, standing in for the sky's own while
##              the front is out (the cloud volume marches four at most):
##              the sky's tower spots are put by and its towers held grown
##              (`pinned`), and given back when it has gone (`end`). Each
##              frame the spots and the built towers move on.
##   the rain   a wall LEAD m ahead of the towers' line, from the cloud sea
##              up into the cloud, in shafts, fading as the eye comes up to
##              it (the plane's own rain takes over there). The cloud volume
##              draws it with its cloud, so each stands before or behind the
##              other (the zs_front global, shaders/reference_globals
##              .gdshaderinc `zs_front_wall`), which also darkens the cloud
##              at and behind the edge (`zs_front_dark`).
##   the storm  `storm_at`: 0 far ahead, building over RAMP m to 1 at the
##              leading edge, held DEPTH m in behind it, gone over TAIL m
##              more; fading past the line's ends over SIDE m.
## It starts START m upwind of `home` (`send`) and runs SPEED m/s; it ends
## once its tail is FORGET m past `home`.
const SkyTowers = preload("res://scripts/sky_towers.gd")

const COUNT := 4
const SPACING := 190.0
const START := 2300.0
const SPEED := 16.0
const LEAD := 170.0
const RAMP := 1600.0
const DEPTH := 700.0
const TAIL := 500.0
const SIDE := 450.0
const FORGET := 900.0

var active := false
## The way it travels (flat, unit), across it, and its line's middle (y 0).
var way := Vector3.FORWARD
var across := Vector3.RIGHT
var centre := Vector3.ZERO
var home := Vector3.ZERO
var _scene: Node3D
var _towers: Node3D
var _kept_spots: Array = []
var _kept_pinned := -1.0

func setup(scene: Node3D) -> void:
	name = "StormFront"
	_scene = scene

## Sends one in on the wind (`toward`: the way the sky's wind blows, radians
## round x then z) at `home`.
func send(toward: float, at: Vector3) -> void:
	if active: end()
	var host: Node = _scene.cloud_host()
	_towers = host.towers if host != null else null
	home = Vector3(at.x,0.0,at.z)
	way = Vector3(cos(toward),0.0,sin(toward))
	across = Vector3(-way.z,0.0,way.x)
	centre = home-way*START
	if _towers != null:
		_kept_spots = _towers.fixed.duplicate()
		_kept_pinned = _towers.pinned
		_towers.fixed = _spots()
		_towers.pinned = SkyTowers.MATURE
		_towers.clear()
	active = true
	_place()

## Its towers' spots now: the line across the wind, each a little ahead or
## behind.
func _spots() -> Array:
	var out := []
	for i in range(COUNT):
		var stagger := 60.0*sin(i*2.3)
		out.append(centre+across*(i-(COUNT-1)*0.5)*SPACING+way*stagger)
	return out

## Gives the sky its own towers back.
func end() -> void:
	if not active: return
	active = false
	RenderingServer.global_shader_parameter_set("zs_front",Vector4.ZERO)
	if _towers != null:
		_towers.fixed = _kept_spots
		_towers.pinned = _kept_pinned
		_towers.clear()

func step(delta: float) -> void:
	if not active: return
	centre += way*SPEED*delta
	_place()
	# Gone on past home: over.
	if (home-centre).dot(way) < -(DEPTH+TAIL+FORGET): end()

func _place() -> void:
	if _towers != null:
		var spots := _spots()
		_towers.fixed = spots
		for i in range(COUNT):
			var key: String = _towers._key(Vector2i(i,0))
			if _towers.built.has(key):
				var b: Dictionary = _towers.built[key]
				(b.node as Node3D).position = spots[i]
				b.home = spots[i]
	var lead := centre+way*LEAD
	RenderingServer.global_shader_parameter_set("zs_front",Vector4(lead.x,lead.z,atan2(way.z,way.x),COUNT*SPACING*0.5))

## How far ahead of its leading edge a point is (m; below 0 inside).
func ahead_of(p: Vector3) -> float:
	return (p-centre).dot(way)-LEAD

## The storm the front makes at `p` (0 to 1).
func storm_at(p: Vector3) -> float:
	if not active: return 0.0
	var d := ahead_of(p)
	var s := 1.0-smoothstep(0.0,RAMP,d) if d > 0.0 else 1.0-smoothstep(DEPTH,DEPTH+TAIL,-d)
	var side := absf((p-centre).dot(across))-COUNT*SPACING*0.5
	return s*(1.0-smoothstep(0.0,SIDE,side))
