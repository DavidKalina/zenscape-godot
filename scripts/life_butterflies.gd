extends Node3D
## Butterflies over flowering meadow (docs/scenic/life.md). Where the survey
## finds a stand of flowering shrubs (daisy, button, spike and umbel flowers,
## which emergence gives meadows), spring and summer days without rain bring a
## few butterflies that drift from flower to flower, settle with their wings
## slowly opening and closing, and drift on.
##
## The flight is irregular on purpose: a heading that wanders on a few beating
## sines, a pull toward the next flower, a speed that surges with each wingbeat
## and a height that bobs, so the arcs are never the same twice. No path is
## planned. Read from LandLife's survey (`flower_spots`); owned by LifeSmall.

const Kit = preload("res://scripts/life_small_kit.gd")
const Models = preload("res://scripts/life_models.gd")

const MAX := 10
## One butterfly per FLOWERS_EACH flowering shrubs, when there are at least FLOWERS_MIN.
const FLOWERS_EACH := 5
const FLOWERS_MIN := 4
## The year for butterflies, [spring, summer, autumn, winter], and the least
## of it, daylight and the most rain they stay out in.
const SEASON := [0.9, 1.0, 0.25, 0.0]
const SEASON_MIN := 0.4
const DAYLIGHT_MIN := 0.45
const RAIN_MAX := 0.12
## Seconds after flowers stand before the first arrives, and the spread.
const ARRIVE := Vector2(8.0, 40.0)
const FADE := 1.4
## Flight speed (m/s, surging with each beat), wingbeats a second, and how far
## its heading wanders (radians a second) and how hard it steers to its flower.
const SPEED := Vector2(0.55, 1.1)
const BEAT := Vector2(6.0, 8.5)
const WANDER := 3.2
const STEER := 1.7
## Flight height over the ground (m), how much it bobs, and a flower's height.
const HEIGHT := Vector2(0.3, 0.85)
const BOB := 0.14
const BLOOM := 0.2
## Seconds settled on a flower, and how far off its next flower may be (m).
const REST := Vector2(1.6, 5.5)
const NEXT := Vector2(0.9, 5.0)
const SCALE := 1.5
const TINTS := [Color(1.0,0.55,0.15), Color(1.0,0.9,0.3), Color(0.55,0.75,1.0), Color(1.0,0.97,0.9), Color(0.95,0.5,0.7)]

var life: Node3D
var flies: Array[Dictionary] = []
var last_usec := 0
var _survey: RefCounted
var _bodies: MultiMesh
var _wings: MultiMesh
var _since := 0.0
var _rng := RandomNumberGenerator.new()

func setup(owner: Node3D) -> void:
	life = owner
	name = "Butterflies"
	_bodies = Kit.batch(self,"Bodies",_body(life.material),MAX)
	_wings = Kit.batch(self,"Wings",_wing(life.material),MAX*2)

func clear() -> void:
	flies.clear()
	_survey = null
	_since = 0.0
	for i in range(MAX):
		_bodies.set_instance_transform(i,Kit.hidden())
		for k in range(2): _wings.set_instance_transform(i*2+k,Kit.hidden())

func showing() -> int:
	return flies.filter(func(fly: Dictionary) -> bool: return float(fly.fade) > 0.0).size()

static func _body(material: Material) -> ArrayMesh:
	var b := Models.Build.new()
	var dark := Color(0.06,0.05,0.05)
	b.spindle(Vector3(0,0,0.035),Vector3(0,0,-0.055),0.008,dark,4,0.4)
	b.icosahedron(Vector3(0,0,0.045),0.0085,dark,1.0)
	return b.commit(material)

## Fore and hind wing in one piece, a pale field with a dark rim and a light spot.
static func _wing(material: Material) -> ArrayMesh:
	var rim := [Vector3(0.0,0,0.015),Vector3(0.03,0.002,0.06),Vector3(0.08,0.0,0.075),Vector3(0.115,0,0.03),Vector3(0.1,0,-0.02),Vector3(0.095,0,-0.075),Vector3(0.05,0,-0.105),Vector3(0.012,0,-0.055),Vector3(0.0,0,-0.02)]
	return Kit.wing(material,rim,Color(0.95,0.95,0.95),Color(0.32,0.3,0.3),Vector3(0.012,0,0.0))

func advance(step: float) -> void:
	var began := Time.get_ticks_usec()
	if life.survey != _survey: _sync()
	var fair := _fair()
	if _survey != null and _survey.flower_spots.size() >= FLOWERS_MIN: _since += step
	else: _since = 0.0
	for fly: Dictionary in flies: _fly(fly,step,fair)
	last_usec = Time.get_ticks_usec()-began

func _fair() -> bool:
	var season := WorldClock.season_factor(life._season(),SEASON)
	return season >= SEASON_MIN and life._daylight() >= DAYLIGHT_MIN and Kit.rain(life) < RAIN_MAX

func _sync() -> void:
	_survey = life.survey
	if _survey == null: return
	var spots: PackedVector2Array = _survey.flower_spots
	var want := clampi(spots.size()/FLOWERS_EACH,0,MAX) if spots.size() >= FLOWERS_MIN else 0
	# Gone flowers send their butterflies off; new ones join in their own time.
	while flies.size() > want:
		_hide(flies.pop_back())
	for fly: Dictionary in flies:
		if not spots.has(fly.flower): _flower(fly)
	while flies.size() < want: flies.append(_born(flies.size()))

func _born(n: int) -> Dictionary:
	var spots: PackedVector2Array = _survey.flower_spots
	var h := Kit.unit([life.salt,n,81])
	var flower := spots[int(Kit.unit([life.salt,n,82])*spots.size())]
	var fly := {"slot":n,"fade":0.0,"wait":lerpf(ARRIVE.x,ARRIVE.y,h),"flower":flower,"phase":h*TAU,"time":0.0,"rest":lerpf(REST.x,REST.y,h),"resting":true,
		"heading":Kit.unit([life.salt,n,83])*TAU,"turn":0.0,"beat":lerpf(BEAT.x,BEAT.y,Kit.unit([life.salt,n,84])),"lift":lerpf(HEIGHT.x,HEIGHT.y,h),
		"tint":TINTS[int(Kit.unit([life.salt,n,85])*TINTS.size())],"size":lerpf(0.85,1.15,Kit.unit([life.salt,n,86])),"wings":0.0,"bank":0.0}
	fly.pos = _perch(flower)
	return fly

func _hide(fly: Dictionary) -> void:
	var slot := int(fly.slot)
	_bodies.set_instance_transform(slot,Kit.hidden())
	for k in range(2): _wings.set_instance_transform(slot*2+k,Kit.hidden())

func _ground(p: Vector2) -> float:
	var g: float = _survey.ground_at(p)
	return g if not is_nan(g) else 0.0

## Where a butterfly sits on the flower at `p`.
func _perch(p: Vector2) -> Vector3:
	return Vector3(p.x,_ground(p)+BLOOM,p.y)

## Pick the flower after this one: one of a few at random, the first that lies
## between NEXT.x and NEXT.y away, else any.
func _flower(fly: Dictionary) -> void:
	var spots: PackedVector2Array = _survey.flower_spots
	var here := Vector2((fly.pos as Vector3).x,(fly.pos as Vector3).z)
	var pick := spots[_rng.randi_range(0,spots.size()-1)]
	for n in range(8):
		var candidate := spots[_rng.randi_range(0,spots.size()-1)]
		var d := here.distance_to(candidate)
		if d >= NEXT.x and d <= NEXT.y:
			pick = candidate
			break
	fly.flower = pick
	fly.lift = _rng.randf_range(HEIGHT.x,HEIGHT.y)

func _fly(fly: Dictionary, step: float, fair: bool) -> void:
	if fair and _since >= float(fly.wait): fly.fade = minf(float(fly.fade)+step/FADE,1.0)
	elif not fair: fly.fade = maxf(float(fly.fade)-step/FADE,0.0)
	if float(fly.fade) <= 0.0:
		_hide(fly)
		return
	fly.time = float(fly.time)+step
	var t := float(fly.time)+float(fly.phase)
	var pos: Vector3 = fly.pos
	var flapping := 0.0
	if bool(fly.resting):
		fly.rest = float(fly.rest)-step
		pos = pos.lerp(_perch(fly.flower),1.0-exp(-8.0*step))
		# Wings held up, opening and closing slowly.
		fly.wings = Kit.ease_to(float(fly.wings),1.15+0.3*sin(t*2.4)+0.15*sin(t*0.9),6.0,step)
		if float(fly.rest) <= 0.0:
			fly.resting = false
			_flower(fly)
	else:
		# Heading wanders on a few sines and is drawn to the flower.
		var target: Vector2 = fly.flower
		var to := target-Vector2(pos.x,pos.z)
		var want := atan2(to.x,to.y)
		var wander := sin(t*1.9)*0.6+sin(t*3.7+1.3)*0.4+sin(t*0.7+2.0)*0.5
		var pull := clampf(angle_difference(float(fly.heading),want),-1.0,1.0)*STEER
		fly.turn = Kit.ease_to(float(fly.turn),wander*WANDER*0.5+pull,6.0,step)
		fly.heading = float(fly.heading)+float(fly.turn)*step
		var beat := t*float(fly.beat)
		var surge := 0.55+0.45*maxf(0.0,sin(beat-0.6))
		var speed := lerpf(SPEED.x,SPEED.y,0.5+0.5*sin(t*0.8))*surge
		var near := clampf(to.length()/0.8,0.25,1.0)
		var heading := float(fly.heading)
		pos += Vector3(sin(heading),0,cos(heading))*speed*near*step
		# Height: toward the flight height, then down to the bloom as it nears.
		var ground := _ground(Vector2(pos.x,pos.z))
		var aim := ground+lerpf(BLOOM,float(fly.lift),clampf(to.length()/1.2,0.0,1.0))
		aim += sin(t*2.3)*BOB+sin(beat)*BOB*0.35
		pos.y = Kit.ease_to(pos.y,aim,3.0,step)
		flapping = 1.0
		fly.wings = Kit.ease_to(float(fly.wings),0.5+0.75*sin(beat),30.0,step)
		if to.length() < 0.12:
			fly.resting = true
			fly.rest = _rng.randf_range(REST.x,REST.y)
	fly.pos = pos
	fly.bank = Kit.ease_to(float(fly.bank),clampf(float(fly.turn)*0.12,-0.5,0.5)*flapping,5.0,step)
	var scale := float(fly.size)*SCALE*smoothstep(0.0,1.0,float(fly.fade))
	var body := Transform3D(Basis(Vector3.UP,float(fly.heading))*Basis(Vector3(0,0,1),-float(fly.bank))*Basis(Vector3.RIGHT,-0.25*flapping)*Basis.from_scale(Vector3.ONE*scale),pos)
	var slot := int(fly.slot)
	_bodies.set_instance_transform(slot,body)
	_bodies.set_instance_color(slot,fly.tint)
	var pair := Kit.wing_pair(body,Vector3(0.006,0.004,0.0),float(fly.wings),0.0)
	for k in range(2):
		_wings.set_instance_transform(slot*2+k,pair[k])
		_wings.set_instance_color(slot*2+k,fly.tint)
