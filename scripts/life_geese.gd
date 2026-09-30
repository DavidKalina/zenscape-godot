extends Node3D
## Geese in a V (docs/scenic/life.md). In spring and autumn, now and then, on a
## day without rain, five to nine geese pass high over the diorama in a V, and
## now and again a faint honk drifts down from them.
##
## A flock holds its formation the way real ones do: each goose sits in its
## rank on one of the V's two arms, drifts a little about it (a slow wander in
## place, height and spacing, and a lean into it), and beats its wings on its own
## rhythm, a touch behind the goose ahead, with the odd glide. The whole V yaws
## a little as it goes. Two batches (bodies, and a wing pair each) keep it to
## three draws; the honks are synthesised once, on first use
## (`LifeSmallKit.honk`), and played from the flock's leader on the distant bus.
## Nothing here reads the world but the survey's peak. Owned by LifeSmall.

const Kit = preload("res://scripts/life_small_kit.gd")
const Models = preload("res://scripts/life_models.gd")

const MAX := 9
const GEESE := Vector2i(5, 9)
## The year for a flock, [spring, summer, autumn, winter]: passing seasons.
const SEASON := [1.0, 0.0, 1.0, 0.0]
const SEASON_MIN := 0.6
const DAYLIGHT_MIN := 0.3
const RAIN_MAX := 0.3
## Seconds (life clock) before the first flock, then between flocks.
const FIRST := Vector2(50.0, 130.0)
const GAP := Vector2(260.0, 620.0)
const CHECK := 4.0
const CHANCE := 0.5
## Flight: metres a second, the distance flown across the plate, and the height
## over the highest ground (m).
const SPEED := 3.6
const RUN := 68.0
const ABOVE := Vector2(9.0, 13.0)
## The V: metres behind and to the side per rank, and the geese's size.
const BACK := 1.9
const SIDE := 1.5
const SCALE := 1.4
## Wingbeats a second, their sweep (radians, down and up), the phase each rank
## trails the one ahead, and how long a glide lasts (s).
const BEAT := 2.1
const SWEEP := Vector2(-0.55, 0.6)
const RIPPLE := 0.4
const GLIDE := Vector2(0.6, 1.6)
## The drift about the rank (m), the V's yaw wobble (radians) and its rate.
const DRIFT := Vector3(0.14, 0.09, 0.18)
const YAW_WOBBLE := 0.05
## Honks: a gap (s) and a gain; each is one of a few pitches.
const HONK_GAP := Vector2(0.8, 2.6)
const HONK_GAIN := 0.07
const HONK_PITCHES := [360.0, 410.0, 330.0]

var life: Node3D
var last_usec := 0
var honks_played := 0
var _bodies: MultiMesh
var _wings: MultiMesh
var _speaker: AudioStreamPlayer3D
var _honks: Array[AudioStreamWAV] = []
var _rng := RandomNumberGenerator.new()
var _survey: RefCounted
var _clock := 0.0
var _check := 0.0
var _next := -1.0
var _flock := {}

func setup(owner: Node3D) -> void:
	life = owner
	name = "Geese"
	_rng.seed = 11
	_bodies = Kit.batch(self,"Bodies",_body(life.material),MAX)
	_wings = Kit.batch(self,"Wings",_wing(life.material),MAX*2)
	_next = _rng.randf_range(FIRST.x,FIRST.y)

func clear() -> void:
	_flock = {}
	_survey = null
	_next = _clock+_rng.randf_range(FIRST.x,FIRST.y)
	_hide()

func showing() -> bool:
	return not _flock.is_empty()

## Facing +Z: body, a long neck reaching ahead, head with a pale cheek, and a
## short tail; about 0.75 m long at unit scale.
static func _body(material: Material) -> ArrayMesh:
	var b := Models.Build.new()
	var grey := Models.hex("#7d7468")
	var black := Models.hex("#1d1c1e")
	b.spindle(Vector3(0,0,-0.27),Vector3(0,0.0,0.16),0.085,grey,6,0.5,0.07)
	b.spindle(Vector3(0,0.005,0.12),Vector3(0,0.03,0.4),0.032,black,5,0.4)
	b.icosahedron(Vector3(0,0.035,0.42),0.036,black,0.9)
	b.icosahedron(Vector3(0,0.03,0.415),0.02,Models.hex("#efece4"),0.7)
	b.spindle(Vector3(0,0.03,0.44),Vector3(0,0.025,0.5),0.014,Models.hex("#302e30"),4,0.3,0.01)
	b.spindle(Vector3(0,0,-0.24),Vector3(0,0.0,-0.36),0.05,Models.hex("#ece8e0"),4,0.5,0.01)
	return b.commit(material)

## One wing from the shoulder along +X, its tip dark.
static func _wing(material: Material) -> ArrayMesh:
	var rim := [Vector3(0,0,0.13),Vector3(0.22,0.02,0.16),Vector3(0.5,0.01,0.1),Vector3(0.7,-0.02,-0.03),Vector3(0.56,-0.01,-0.15),Vector3(0.3,0,-0.19),Vector3(0.0,0,-0.17)]
	return Kit.wing(material,rim,Models.hex("#8b8174"),Models.hex("#2a2826"))

func _hide() -> void:
	for i in range(MAX):
		_bodies.set_instance_transform(i,Kit.hidden())
		for k in range(2): _wings.set_instance_transform(i*2+k,Kit.hidden())

func advance(step: float) -> void:
	var began := Time.get_ticks_usec()
	_clock += step
	if life.survey != null: _survey = life.survey
	if _flock.is_empty():
		_check += step
		if _check >= CHECK:
			_check = 0.0
			if _clock >= _next and _survey != null and _fair() and _rng.randf() < CHANCE: start()
	else:
		_fly(step)
	last_usec = Time.get_ticks_usec()-began

func _fair() -> bool:
	var season := WorldClock.season_factor(life._season(),SEASON)
	return season >= SEASON_MIN and life._daylight() >= DAYLIGHT_MIN and Kit.rain(life) < RAIN_MAX

## A flock now, skipping the wait, chance and season. False when one is on.
func start() -> bool:
	if not _flock.is_empty(): return false
	if _honks.is_empty(): _synthesise()
	var peak := 0.0
	if _survey != null:
		for i in range(0,_survey.height.size(),3):
			if not is_nan(_survey.height[i]): peak = maxf(peak,_survey.height[i])
	var count := _rng.randi_range(GEESE.x,GEESE.y)
	var way := _rng.randf()*TAU
	var across := _rng.randf_range(-8.0,8.0)
	var heading := Vector3(sin(way),0,cos(way))
	var side := Vector3(heading.z,0,-heading.x)
	var geese := []
	for i in range(count):
		geese.append({"phase":_rng.randf()*TAU*0.25+ceil(i*0.5)*RIPPLE,"rate":BEAT*_rng.randf_range(0.94,1.06),"wander":Vector3(_rng.randf()*TAU,_rng.randf()*TAU,_rng.randf()*TAU),
			"glide":0.0,"next_glide":_rng.randf_range(2.0,7.0),"size":_rng.randf_range(0.92,1.08)})
	_flock = {"geese":geese,"age":0.0,"start":-heading*RUN*0.5+side*across,"heading":heading,"way":way,"height":peak+_rng.randf_range(ABOVE.x,ABOVE.y),
		"honk":_rng.randf_range(2.0,5.0),"yaw":_rng.randf()*TAU}
	return true

func _synthesise() -> void:
	for i in range(HONK_PITCHES.size()): _honks.append(Kit.honk(0.3+0.05*i,HONK_PITCHES[i],200+i))
	_speaker = Kit.speaker(self,true)

func _fly(step: float) -> void:
	var f := _flock
	f.age = float(f.age)+step
	var age := float(f.age)
	var distance := SPEED*age
	if distance >= RUN:
		_flock = {}
		_hide()
		_next = _clock+_rng.randf_range(GAP.x,GAP.y)
		return
	var heading: Vector3 = f.heading
	var yaw := float(f.way)+sin(age*0.35+float(f.yaw))*YAW_WOBBLE
	var forward := Vector3(sin(yaw),0,cos(yaw))
	var right := Vector3(forward.z,0,-forward.x)
	var origin: Vector3 = (f.start as Vector3)+heading*distance
	origin.y = float(f.height)+sin(age*0.4)*0.25
	var geese: Array = f.geese
	for i in range(geese.size()):
		var g: Dictionary = geese[i]
		var rank := ceili(i*0.5)
		var arm := 0.0 if i == 0 else (1.0 if i%2 == 1 else -1.0)
		var w: Vector3 = g.wander
		var drift := Vector3(sin(age*0.7+w.x)*DRIFT.x,sin(age*0.9+w.y)*DRIFT.y,sin(age*0.6+w.z)*DRIFT.z)
		var pos := origin+right*(arm*rank*SIDE+drift.x)-forward*(rank*BACK+drift.z)
		pos.y += drift.y
		# Wingbeats with the odd glide, the sweep eased in and out of it.
		g.next_glide = float(g.next_glide)-step
		if float(g.next_glide) <= 0.0:
			g.glide = _rng.randf_range(GLIDE.x,GLIDE.y)
			g.next_glide = float(g.glide)+_rng.randf_range(3.0,9.0)
		g.glide = maxf(float(g.glide)-step,0.0)
		var flap := 1.0-smoothstep(0.0,0.25,float(g.glide))
		var beat := sin(age*TAU*float(g.rate)+float(g.phase))
		var angle := lerpf(0.12,lerpf(SWEEP.x,SWEEP.y,0.5+0.5*beat),flap)
		# Leans into its drift, noses a little with each beat.
		var bank := cos(age*0.7+w.x)*0.14
		var pitch := 0.05*beat*flap-0.04
		var body := Transform3D(Basis(Vector3.UP,yaw)*Basis(Vector3(0,0,1),-bank)*Basis(Vector3.RIGHT,pitch)*Basis.from_scale(Vector3.ONE*SCALE*float(g.size)),pos)
		_bodies.set_instance_transform(i,body)
		var pair := Kit.wing_pair(body,Vector3(0.07,0.04,0.02),angle,0.0)
		for k in range(2): _wings.set_instance_transform(i*2+k,pair[k])
	for i in range(geese.size(),MAX):
		_bodies.set_instance_transform(i,Kit.hidden())
		for k in range(2): _wings.set_instance_transform(i*2+k,Kit.hidden())
	f.honk = float(f.honk)-step
	_speaker.position = origin
	if float(f.honk) <= 0.0:
		f.honk = _rng.randf_range(HONK_GAP.x,HONK_GAP.y)
		if not _speaker.playing:
			_speaker.stream = _honks[_rng.randi_range(0,_honks.size()-1)]
			_speaker.volume_db = linear_to_db(HONK_GAIN)
			_speaker.pitch_scale = _rng.randf_range(0.92,1.1)
			_speaker.play()
			honks_played += 1
