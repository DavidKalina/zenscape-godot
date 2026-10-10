extends RefCounted
## The plane and the pilot brushing the ruins' hanging growth
## (shaders/ruin_growth.gdshader `pusher_at` / `pusher_way`,
## docs/scenic/ruin-overgrowth.md). Whoever moves near the ruins calls
## `stir` once a frame with where it is; this keeps its last few places as a
## short trail and writes the strongest four points to the growth's one
## shared material: where it is now pushes the strands within its reach along
## its way and out from its path (held while it passes), the places it has
## just been swing back past rest and settle (the wind tool's damped swing),
## so a curtain flown through billows out and falls back. No per-strand CPU
## work: four vectors a frame. Pushers that stop stirring fade out over
## LIFE s, aged by the others' stirs (and by `settle`).
const RuinGrowth = preload("res://scripts/ruin_growth.gd")

const SLOTS := 4
## Seconds between trail points, and how long a point is kept.
const TRAIL_STEP := 0.18
const LIFE := 1.6
## The swing after a pusher has gone by (rad/s, 1/s): back past rest by about
## a third, settled in a second and a half.
const RING := 5.5
const DAMP := 2.2
## The pushers: their reach (m) and their push per m/s, at most MOST.
const KINDS := {&"plane":{"radius":5.5,"per":0.06,"most":1.6},&"pilot":{"radius":1.6,"per":0.16,"most":1.0}}
const MOST := 1.6

static var _clock := 0.0
## id -> {at, way, strength, last (clock), trail: [[at, way, strength, laid]]}
static var _pushers := {}

## `id` (&"plane" or &"pilot", or any key of KINDS) is at `at` (world) now,
## `delta` s after the last frame.
static func stir(id: StringName, at: Vector3, delta: float) -> void:
	_clock += maxf(delta,0.0)
	var kind: Dictionary = KINDS.get(id,KINDS[&"pilot"])
	var p: Dictionary = _pushers.get(id,{})
	if p.is_empty() or _clock-float(p.last) > 0.5:
		p = {"at":at,"way":Vector3.ZERO,"strength":0.0,"last":_clock,"trail":[],"laid":_clock}
		_pushers[id] = p
	var moved: Vector3 = at-(p.at as Vector3)
	var speed := moved.length()/maxf(delta,0.001)
	var way: Vector3 = moved.normalized() if moved.length() > 0.0001 else p.way
	p.at = at
	p.way = way
	p.strength = minf(speed*float(kind.per),float(kind.most))
	p.last = _clock
	p.radius = float(kind.radius)
	if _clock-float(p.laid) >= TRAIL_STEP:
		p.laid = _clock
		(p.trail as Array).push_front([at,way,float(p.strength),_clock])
	_publish()

## Ages the pushers with no stir (a frame with nobody near the ruins).
static func settle(delta: float) -> void:
	_clock += maxf(delta,0.0)
	_publish()

## The swing of a point `age` s after its pusher passed: 1 then back past rest.
static func swing(age: float) -> float:
	return exp(-DAMP*age)*cos(RING*age)

static func _publish() -> void:
	var points: Array = []
	for id in _pushers.keys():
		var p: Dictionary = _pushers[id]
		var idle := _clock-float(p.last)
		var fade := 1.0-smoothstep(0.1,0.6,idle)
		if fade > 0.0 and float(p.strength) > 0.01: points.append([p.at,p.way,float(p.strength)*fade,float(p.radius)])
		var trail: Array = p.trail
		while not trail.is_empty() and _clock-float(trail.back()[3]) > LIFE: trail.pop_back()
		for t: Array in trail:
			var age := _clock-float(t[3])
			if age < TRAIL_STEP*0.5: continue
			points.append([t[0],t[1],float(t[2])*swing(age),float(p.radius)])
		if trail.is_empty() and idle > LIFE: _pushers.erase(id)
	points.sort_custom(func(a: Array, b: Array) -> bool: return absf(float(a[2])) > absf(float(b[2])))
	var at := PackedVector4Array()
	var way := PackedVector4Array()
	for i in range(SLOTS):
		if i < points.size() and absf(float(points[i][2])) > 0.01:
			var q: Vector3 = points[i][0]
			var w: Vector3 = points[i][1]
			at.append(Vector4(q.x,q.y,q.z,float(points[i][3])))
			way.append(Vector4(w.x,w.y,w.z,clampf(float(points[i][2]),-MOST,MOST)))
		else:
			at.append(Vector4.ZERO)
			way.append(Vector4.ZERO)
	var m := RuinGrowth.material()
	m.set_shader_parameter("pusher_at",at)
	m.set_shader_parameter("pusher_way",way)
