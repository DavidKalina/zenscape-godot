extends RefCounted
## How close the glide (scripts/sky_glide.gd) is passing to something big:
## an island, an islet, the plate's trees, anything the glide's `ground`
## solid holds. Flying fast past it, the air thickens into vapour that
## peels off the wingtips (scripts/plane_figure.gd) and the streaks and the
## wind's hiss rise (scripts/glide_air.gd), so a pass along a cliff feels
## like a rush without anything going faster.
##
## It feels round the flight path with a ring of probes a little ahead of
## the plane: out to each side, below, above and the four diagonals,
## each tried at a few reaches. A probe inside the solid counts as close,
## the nearer the reach the closer. The ring is cheap: each step tries only
## SPREAD of its directions and keeps the rest from before, so the whole
## ring is fresh every few frames and a step costs a handful of lookups.
##
## `near` (0 to 1) swells quickly and lets go slowly, so a pass leaves a
## breath of vapour behind rather than a flicker. `side` says which wing is
## nearer the rock (-1 left, 1 right). Plain state and maths, so tests can
## step it.

## The reaches each direction is tried at (metres, nearest first) and how
## close each counts.
const REACH := [1.6,3.4,6.0]
const CLOSE := [1.0,0.65,0.3]
## How far ahead along the path the ring sits (seconds of velocity).
const LEAD := 0.12
## Directions tried each step.
const SPREAD := 3
## Speeds (m/s) where the vapour begins and where it is full.
const SPEED := Vector2(6.0,20.0)
## How fast `near` swells and lets go (seconds).
const SWELL := 0.12
const FADE := 0.7
## The ring round the path, in the glider's frame: x right, y up.
const RING := [Vector2(1.0,0.0),Vector2(-1.0,0.0),Vector2(0.0,-1.0),Vector2(0.0,1.0),
	Vector2(0.7,-0.7),Vector2(-0.7,-0.7),Vector2(0.7,0.7),Vector2(-0.7,0.7)]

## The vapour now (0 open air, 1 skimming fast along rock), and the nearer
## wing (-1 left to 1 right).
var near := 0.0
var side := 0.0
## How close each ring direction found the solid when last tried.
var _close := PackedFloat32Array()
var _next := 0

func _init() -> void:
	_close.resize(RING.size())

## Back to open air.
func reset() -> void:
	near = 0.0
	side = 0.0
	_close.fill(0.0)
	_next = 0

## One step along `glide`. `ground` is the glide's own solids query: a
## Callable(Vector3) -> Variant giving Vector2(top, underside), a plain
## height, or null over open air.
func step(delta: float, glide: RefCounted, ground: Callable) -> void:
	if not ground.is_valid() or delta <= 0.0: return
	var velocity: Vector3 = glide.velocity
	var ahead: Vector3 = glide.forward()
	var right := ahead.cross(Vector3.UP)
	if right.length_squared() < 0.0001: right = Vector3(cos(float(glide.heading)),0.0,-sin(float(glide.heading)))
	right = right.normalized()
	var up := right.cross(ahead).normalized()
	var at: Vector3 = glide.position+velocity*LEAD
	for _n in range(SPREAD):
		var i := _next
		_next = (_next+1)%RING.size()
		var dir: Vector2 = RING[i]
		var out := right*dir.x+up*dir.y
		_close[i] = 0.0
		for r in range(REACH.size()):
			if _inside(ground,at+out*float(REACH[r])):
				_close[i] = CLOSE[r]
				break
	var most := 0.0
	var lean := 0.0
	for i in range(RING.size()):
		most = maxf(most,_close[i])
		lean += _close[i]*(RING[i] as Vector2).x
	var fast := smoothstep(SPEED.x,SPEED.y,velocity.length())
	var want := most*fast
	near = lerpf(near,want,1.0-exp(-delta/(SWELL if want > near else FADE)))
	side = lerpf(side,clampf(lean,-1.0,1.0),1.0-exp(-delta/0.3))

func _inside(ground: Callable, point: Vector3) -> bool:
	var under: Variant = ground.call(point)
	if under == null: return false
	if under is Vector2: return point.y < (under as Vector2).x and point.y > (under as Vector2).y
	return point.y < float(under)
