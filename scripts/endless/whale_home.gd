extends Node
## The whale's home water (prototype; docs/design/whale/handoff-reveal-whale.md):
## the deep bay north-east of the start, north of the stacks. Out at sea the
## whale stays the rare moment whale.gd stages; here it can be met.
##
## A plane within SEE m of the bay wakes it: a dark shape lies under the water
## at one of SPOTS and blows every BLOW_EVERY s (the tell, seen from flying
## height). A plane coming within `rise_reach()` of it, under HIGH m, brings it
## up: the whale's own clip (whale.gd `_stage`), swimming away from the plane.
## Left alone it comes up on its own after WAIT s (counted while the plane is
## over HOLD m off). Then it rests REST s and lies at another spot.
##
## The find: its back up with the plane within NEAR m (under HIGH), it lets out the ring
## where it rose (`finds.anchor(ANCHOR, ...)`, the row `whale-ring`); the ring
## stays there for the flight. Come up with the plane far, nothing: the find
## waits for the next time. A close pass of the tail (whale.gd's near miss)
## while it is up fires EVENT_TAIL (the row `whale-tail`).
##
## Flags: `--whale-home=0` none; `--whale-home-wait=S`, `--whale-home-rest=S`.

const Field = preload("res://scripts/endless/land_field.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WhaleBody = preload("res://scripts/endless/whale_body.gd")

## Where it lies (x, z): deep water clear of shores out to 450 m (whale.gd
## `_site_refusal`, the map in the handoff). The middle, for SEE.
const SPOTS: Array[Vector2] = [Vector2(2250.0,-1750.0),Vector2(2500.0,-1750.0),Vector2(2000.0,-2000.0),
	Vector2(2500.0,-2000.0),Vector2(2750.0,-1500.0),Vector2(2250.0,-2000.0),Vector2(2750.0,-1750.0)]
const MIDDLE := Vector2(2400.0,-1800.0)
const SEE := 2400.0
## It comes up for a plane this many seconds of its speed away (m, clamped).
const RISE_S := 13.0
const RISE := Vector2(220.0,480.0)
const HIGH := 220.0
const NEAR := 450.0
const WAIT := 90.0
## WAIT runs only while the plane is farther than this (m).
const HOLD := 1300.0
const REST := 75.0
const BLOW_EVERY := Vector2(5.0,8.0)
## The tell's blow (made for a plane far off): a burst of mist thrown up (m/s,
## min and max) as a narrow jet that opens into a plume, sheared downwind, thinning
## from the bottom up over COLUMN_LIFE s; scaled by the plane's distance over
## COLUMN_FAR, held between COLUMN_K (so it is faint far off, not a wall near).
const COLUMN := 130
const COLUMN_LIFE := 7.5
const COLUMN_UP := Vector2(14.0,66.0)
const COLUMN_FAR := 450.0
const COLUMN_K := Vector2(0.3,2.2)
## The shape under the water: depth in the sea shader's units (whole 0.6, gone
## 2.4), strength, drift (m/s).
const SHAPE_DEEP := 1.1
const SHAPE_K := 0.75
const DRIFT := 1.5
## The clip's frame (measured): the root at t 0 lies this far astern of the
## clip's origin, the first blow this far.
const ROOT_ASTERN := 49.7
const BLOW_ASTERN := 31.0
const ANCHOR := "whale/home"
const EVENT_TAIL := "whale/tail"

enum {ASLEEP, TELL, UP, RESTING}

## Read by drivers: the phase, where the shape lies, how many times it came up
## here, with the plane near, the ring let out (and where), the tell's blows.
var phase := ASLEEP
var shape := Vector3.INF
var heading := Vector3.FORWARD
var shown := 0
var shown_near := 0
var revealed := false
var ring_at := Vector3.INF
var blows := 0
var near_now := false

var _whale: Node3D
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _blow_in := 0.0
var _passes := 0
var _wait := WAIT
var _rest := REST
var _shape_on := false
var _last := -1
var _column: GPUParticles3D

static func wanted() -> bool:
	return not ("--whale-home=0" in LaunchArgs.user_args())

func setup(whale: Node3D, land_seed: int) -> void:
	name = "WhaleHome"
	_whale = whale
	_rng.seed = hash([land_seed,"whale-home",Time.get_ticks_usec()])
	_wait = whale._knob("home-wait",WAIT)
	_rest = whale._knob("home-rest",REST)

## True while the home holds the whale (the open sea's roll waits).
func step(delta: float, game: Node3D) -> bool:
	var p: Vector3 = game.plane.position
	var d := Vector2(p.x,p.z).distance_to(MIDDLE)
	if phase != UP and bool(_whale.staged): return false
	match phase:
		ASLEEP:
			_t -= delta
			if d > SEE: return false
			if _t <= 0.0 and not _lie(game): _t = 2.0
			return true
		TELL:
			if d > SEE*1.15:
				_shape_off(game)
				phase = ASLEEP
				return false
			var to := Vector2(shape.x-p.x,shape.z-p.z)
			# Not on its own while a plane is on its way in.
			if to.length() > HOLD: _t -= delta
			shape += heading*DRIFT*delta
			_shape_show(game)
			_blow_in -= delta
			if _blow_in <= 0.0:
				_blow_in = _rng.randf_range(BLOW_EVERY.x,BLOW_EVERY.y)
				_tell_blow(game)
			if (to.length() < rise_reach(game) and p.y-Field.SEA_Y < HIGH) or _t <= 0.0: _rise(game,p)
			return true
		UP:
			_up(game,p)
			return true
		RESTING:
			_t -= delta
			if _t <= 0.0: phase = ASLEEP
			return d < SEE
	return false

func rise_reach(game: Node3D) -> float:
	return clampf(float(game.plane.speed)*RISE_S,RISE.x,RISE.y)

## Lie at a spot fit now; false if none is.
func _lie(game: Node3D) -> bool:
	var order: Array = range(SPOTS.size())
	order.shuffle()
	for i: int in order:
		if i == _last and SPOTS.size() > 1: continue
		var at := Vector3(SPOTS[i].x,Field.SEA_Y,SPOTS[i].y)
		var h := Vector3.FORWARD.rotated(Vector3.UP,_rng.randf_range(-PI,PI))
		if str(_whale._site_refusal(game,at,h,at)) != "": continue
		_last = i
		shape = at
		heading = h
		phase = TELL
		_t = _wait
		_blow_in = 1.5
		return true
	return false

## The water over the shape: the sea's swimmer slot, with its own drawn body.
func _shape_show(game: Node3D) -> void:
	var sea = game.look.water if game.look != null else null
	if sea == null: return
	if not _shape_on: sea.material.set_shader_parameter("swim_body",1.0)
	_shape_on = true
	var k := SHAPE_K*clampf((_wait-_t)/3.0,0.0,1.0)
	sea.swimmers(Vector4(shape.x,shape.z,heading.x,heading.z),Vector4(WhaleBody.LONG,SHAPE_DEEP,0.0,k),Vector4.ZERO,Vector4.ZERO,1)

func _shape_off(game: Node3D) -> void:
	if not _shape_on: return
	_shape_on = false
	var sea = game.look.water if game.look != null else null
	if sea != null: sea.swimmers(Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,Vector4.ZERO,0)

## A blow off the shape's head, and the water whitened round it.
func _tell_blow(game: Node3D) -> void:
	blows += 1
	var head := shape-heading*WhaleBody.LONG*0.32
	var level := Field.SEA_Y+float(game.sea_height(head))
	_column_blow(game,Vector3(head.x,level+0.3,head.z),level)
	_whale.voice(game,"whale-blow",_whale.BLOW_GAIN,_whale.BLOW_PITCH,Vector3(head.x,level+0.3,head.z))
	if game.water != null:
		game.water.mark(Vector3(head.x,level,head.z),false,0.5,6.0,16.0,6.0)
		game.water.mark(Vector3(head.x,level,head.z),true,0.35,5.0,26.0,5.0)

## The tell's spout: a column of soft mist flung up fast, leaning and thinning
## with the wind. Its size and height go with the plane's distance (nearer is
## smaller), so it shows from far off and is not a wall close to.
func _column_blow(game: Node3D, at: Vector3, level: float) -> void:
	if _column == null: _column = _column_make()
	var p: Vector3 = game.plane.position
	var k := clampf(Vector2(p.x-at.x,p.z-at.z).length()/COLUMN_FAR,COLUMN_K.x,COLUMN_K.y)
	var wind: Vector2 = game.look.wind_direction if game.look != null else Vector2.RIGHT
	var way := Vector3(wind.x,0.0,wind.y).normalized()
	_column.global_position = at
	var m := _column.process_material as ShaderMaterial
	var values := {"rate":1.0,"ahead":way,"right":way.cross(Vector3.UP),"up_speed":COLUMN_UP*pow(k,0.75),
		"side_speed":3.0*k,"size_range":Vector2(4.0,13.0)*k,"growth":3.0,"drag":0.4,"gravity":0.4,
		"shear":1.6,"shear_over":90.0*k,"water_y":level-6.0}
	for key: String in values: m.set_shader_parameter(key,values[key])
	_column.restart()
	_column.emitting = true

func _column_make() -> GPUParticles3D:
	var e := GPUParticles3D.new()
	e.amount = COLUMN
	e.lifetime = COLUMN_LIFE
	e.one_shot = true
	e.explosiveness = 0.85
	e.randomness = 0.3
	e.local_coords = false
	e.fixed_fps = 0
	e.interpolate = false
	e.emitting = false
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.visibility_aabb = AABB(Vector3(-500,-30,-500),Vector3(1000,600,1000))
	var process := ShaderMaterial.new()
	process.shader = preload("res://shaders/whale_blow_process.gdshader")
	e.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var draw := ShaderMaterial.new()
	draw.shader = preload("res://shaders/water_spray.gdshader")
	draw.set_shader_parameter("kind",1)
	draw.set_shader_parameter("tint",Color(0.86,0.9,0.95))
	draw.set_shader_parameter("opacity",0.7)
	draw.set_shader_parameter("near_fade",Vector2(20.0,90.0))
	draw.set_shader_parameter("glow",0.3)
	draw.set_shader_parameter("backlight",0.4)
	quad.material = draw
	e.draw_pass_1 = quad
	add_child(e)
	return e

## Up: swimming away from a plane that brought it, else its own way; its root
## starts where the shape lay.
func _rise(game: Node3D, p: Vector3) -> void:
	var to := Vector3(shape.x-p.x,0.0,shape.z-p.z)
	if _t > 0.0 and to.length() > 1.0: heading = to.normalized()
	_shape_off(game)
	var origin := shape+heading*ROOT_ASTERN
	origin.y = Field.SEA_Y
	_whale._stage(game,origin,heading)
	_passes = int(_whale.passes)
	phase = UP
	shown += 1
	near_now = false
	print("whale home: up at %s (%s), plane %.0f m off" % [str(shape.snapped(Vector3.ONE)),"brought" if _t > 0.0 else "on its own",Vector2(to.x,to.z).length()])

func _up(game: Node3D, p: Vector3) -> void:
	if not bool(_whale.staged):
		phase = RESTING
		_t = _rest
		return
	var t: float = _whale.body.time()
	var mid: Vector3 = _whale.body.socket(&"root")
	var near := Vector2(p.x-mid.x,p.z-mid.z).length() < NEAR and p.y-Field.SEA_Y < HIGH and bool(game.hand_landing.flying())
	if near and t >= float(WhaleBody.BEATS["back.show"]) and t <= float(WhaleBody.BEATS.gone):
		if not near_now:
			near_now = true
			shown_near += 1
		_reveal(game)
	if int(_whale.passes) > _passes:
		_passes = int(_whale.passes)
		if game.finds != null: game.finds.fire(EVENT_TAIL)

## The ring where it rose, once a flight.
func _reveal(game: Node3D) -> void:
	if revealed or game.finds == null: return
	revealed = true
	var origin: Vector3 = _whale.spot
	ring_at = origin-heading*BLOW_ASTERN
	ring_at.y = Field.SEA_Y
	# Watched from abeam, its back along the view behind the ring.
	game.finds.anchor(ANCHOR,ring_at,Vector3.UP.cross(heading).normalized())
	print("whale home: the ring let out at %s" % str(ring_at.snapped(Vector3.ONE)))
