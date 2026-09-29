extends RefCounted
## The wind in the sky (docs/scenic/modeless.md "Wind"): a drag through the
## empty sky round the diorama moves the air. A click there is still the snap
## (scripts/hand_reach.gd `_void_release`).
##
## - **A quick swipe** (let go within SWIPE_SECONDS of the press) sends a
##   passing gust across the land along the swipe, as strong as it was fast
##   (NativeChunkEditor `gust_from_sky`, scripts/wind_gust.gd). The weather is
##   left as it was.
## - **A held sweep** (still held after SWIPE_SECONDS) takes the prevailing
##   wind in hand: it blows the way the pointer lies from the press, as seen
##   on screen laid onto the ground, and harder the further the pointer is
##   pulled (PULL, shares of the view's height, for STRENGTH). The world's air
##   swings round to it while held (STEER), and it stays when let go: the
##   atmosphere's own `direction_angle` and `strength` are set, which it eases
##   toward, the weather's drift moves by, and the garden saves.
##
## Owned by the hand's reach; it reads the atmosphere and the camera from the
## scene.

## Seconds a press may last and still be a swipe.
const SWIPE_SECONDS := 0.3
## Seconds of pointer history a swipe's speed is read over, and the swipe
## speeds (px/s, shares of the view's height a second) of the weakest and a
## full gust.
const SWIPE_WINDOW := 0.12
const SWIPE_SPEED := Vector2(0.4,3.0)
const GUST_POWER := Vector2(0.25,1.0)
## A held sweep: the pull (shares of the view's height from the press) for
## the gentlest and the strongest wind, and those strengths (the atmosphere's
## `strength`, which the weather keeps within 0.12 to 1.4).
const PULL := Vector2(0.04,0.4)
const STRENGTH := Vector2(0.15,1.3)
## How fast (1/s) the world's air swings to a held wind.
const STEER := 4.0
## Pixels under which a pull holds the wind as it was (the sweep's first
## moment, before it has a heading).
const DEAD_PIXELS := 12.0

var scene: Node
## "", "swipe" (undecided or a swipe) or "steer" while pressed.
var state := ""
var held := 0.0
## For probes: the gusts sent and the sweeps let go.
var gusts := 0
var sweeps := 0
## For probes: drags that took the wind tool to the land.
var handed := 0
var _press := Vector2.ZERO
var _pointer := Vector2.ZERO
var _samples: Array[Vector3] = []
## The prevailing wind's targets at the press, put back when the drag takes
## the tool to the land.
var _was_angle := 0.0
var _was_strength := 0.0

func _init(owner_scene: Node) -> void:
	scene = owner_scene

func press(point: Vector2) -> void:
	state = "swipe"
	held = 0.0
	_press = point
	_pointer = point
	_samples = [Vector3(point.x,point.y,0.0)]
	var air: Node = scene.get("_atmosphere")
	if air != null:
		_was_angle = float(air.direction_angle)
		_was_strength = float(air.strength)

func drag(point: Vector2) -> void:
	if state.is_empty(): return
	_pointer = point
	_samples.append(Vector3(point.x,point.y,held))

## Each frame while pressed: a swipe held long enough becomes a sweep, and a
## sweep steers the air.
func step(delta: float) -> void:
	if state.is_empty(): return
	held += delta
	while _samples.size() > 2 and _samples[0].z < held-SWIPE_WINDOW: _samples.pop_front()
	if state == "swipe" and held > SWIPE_SECONDS: state = "steer"
	if state == "steer": _steer(delta)

## Let go: a swipe's gust goes; a sweep's wind stays. Returns what it was:
## "gust", "wind" or "" (a swipe too slow or short to blow, or no land).
func release(point: Vector2) -> String:
	drag(point)
	var was := state
	state = ""
	if was == "steer":
		sweeps += 1
		return "wind"
	var flick := _flick()
	var editor: Node = scene.get("_chunk_editor")
	if flick.is_empty() or editor == null or not editor.has_method("gust_from_sky"): return ""
	if not editor.gust_from_sky(flick[0],flick[1]): return ""
	gusts += 1
	return "gust"

## The drag has come over the land at `point`: the wind tool is taken in hand
## there, carrying the flick. True when it was, and the sky lets go.
func to_land(point: Vector2) -> bool:
	if state.is_empty(): return false
	drag(point)
	var flick := _flick()
	var editor: Node = scene.get("_chunk_editor")
	if flick.is_empty() or editor == null or not editor.has_method("gust_in_hand"): return false
	if not editor.gust_in_hand(point,flick[0],flick[1]): return false
	# A held wind turned on the way in goes back to what it was; the air
	# eases back at the weather's pace.
	var air: Node = scene.get("_atmosphere")
	if state == "steer" and air != null:
		air.direction_angle = _was_angle
		air.strength = _was_strength
	state = ""
	handed += 1
	return true

## The flick so far: [heading (plate x, z), gust power], or [] with no way.
func _flick() -> Array:
	var first: Vector3 = _samples[0]
	var last: Vector3 = _samples.back()
	var shift := Vector2(last.x-first.x,last.y-first.y)
	var span := maxf(last.z-first.z,1.0/60.0)
	if shift.length() < DEAD_PIXELS: shift = _pointer-_press
	var speed := shift.length()/span/_view_height()
	var heading := _ground_way(shift)
	var editor: Node = scene.get("_chunk_editor")
	if heading == Vector3.ZERO or editor == null: return []
	var share := clampf(inverse_lerp(SWIPE_SPEED.x,SWIPE_SPEED.y,speed),0.0,1.0)
	var terrain: Node3D = editor.terrain
	var plate := terrain.global_basis.inverse()*heading
	return [Vector2(plate.x,plate.z),lerpf(GUST_POWER.x,GUST_POWER.y,share)]

## The held wind: its heading and strength from the pull, set on the
## atmosphere, and its air swung round toward them now rather than at the
## weather's easy pace.
func _steer(delta: float) -> void:
	var air: Node = scene.get("_atmosphere")
	var pull := _pointer-_press
	if air == null or pull.length() < DEAD_PIXELS: return
	var way := _ground_way(pull)
	if way == Vector3.ZERO: return
	var share := clampf(inverse_lerp(PULL.x,PULL.y,pull.length()/_view_height()),0.0,1.0)
	var angle := atan2(way.z,way.x)
	air.direction_angle = rad_to_deg(angle)
	air.strength = lerpf(STRENGTH.x,STRENGTH.y,share)
	var follow := 1.0-exp(-STEER*delta)
	air._air_angle = lerp_angle(float(air._air_angle),angle,follow)
	air._air_strength = lerpf(float(air._air_strength),float(air.strength),follow)

## A screen direction laid onto the ground (world x, z; y 0), as the camera
## sees it: right is the camera's right, up the screen is away from it.
func _ground_way(screen: Vector2) -> Vector3:
	var camera: Camera3D = scene.get("camera")
	if camera == null or screen.length_squared() < 0.0001: return Vector3.ZERO
	var right := camera.global_basis.x
	right.y = 0.0
	var away := -camera.global_basis.z
	away.y = 0.0
	# Looking straight down, the camera's up is the way away.
	if away.length_squared() < 0.0001: away = camera.global_basis.y*Vector3(1,0,1)
	var way := right.normalized()*screen.x-away.normalized()*screen.y
	return way.normalized() if way.length_squared() > 0.000001 else Vector3.ZERO

func _view_height() -> float:
	var viewport: Viewport = scene.get_viewport() if scene is Node else null
	return maxf(viewport.get_visible_rect().size.y if viewport != null else 720.0,1.0)
