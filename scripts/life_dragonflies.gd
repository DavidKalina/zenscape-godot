extends Node3D
## Dragonflies over still ponds (docs/scenic/life.md). In summer daylight and
## dry weather a pond of some size gets one to three, which hover a hand
## over the water, then dart a metre or two to a new spot over the surface or
## the reeds along the bank and stop dead again.
##
## Read from LandLife's survey (its still-water bodies and their banks), never
## from the world. Each fly is two batches' instances: a body (tinted blue,
## green, red or amber) and two pairs of glassy wings beating in antiphase. The
## motion has three parts, as a real one does: a hover that drifts and jitters
## a little, a tilt back of the nose in the moment before it goes, and a dart
## that starts hard and brakes late. Owned by LifeSmall.

const Kit = preload("res://scripts/life_small_kit.gd")
const Models = preload("res://scripts/life_models.gd")
const Survey = preload("res://scripts/life_survey.gd")

const MAX := 9
## A pond needs this much water (m²) and one fly per FLY_AREA of it, up to PER_POND.
const POND_AREA := 2.5
const FLY_AREA := 5.0
const PER_POND := 3
## The year for dragonflies, [spring, summer, autumn, winter], and the least of
## it, daylight and the most rain they stay out in.
const SEASON := [0.3, 1.0, 0.3, 0.0]
const SEASON_MIN := 0.5
const DAYLIGHT_MIN := 0.5
const RAIN_MAX := 0.25
## Seconds after a pond qualifies before its first arrives, and the spread.
const ARRIVE := Vector2(6.0, 22.0)
## Seconds to fade in or out.
const FADE := 1.6
## Hover height over the water (m), the hover time, and the dart's reach,
## speed and the chance its goal is a bank cell rather than open water.
const HEIGHT := Vector2(0.22, 0.5)
const HOVER := Vector2(0.5, 2.6)
const REACH := Vector2(0.7, 2.8)
const SPEED := 3.4
const BANK_SHARE := 0.35
## Tilt of the nose up before a dart and down during it (radians), and the
## seconds of the tilt-back.
const RECOIL := 0.3
const RECOIL_TIME := 0.16
const DASH_PITCH := -0.22
## Wings: beats per second, sweep, and the glassy paint.
const BEAT := 26.0
const SWEEP := 0.5
const SCALE := 1.15
const TINTS := [Color(0.25,0.55,1.0), Color(0.3,0.8,0.42), Color(0.95,0.28,0.2), Color(0.95,0.7,0.25), Color(0.4,0.75,0.9)]

var life: Node3D
var flies: Array[Dictionary] = []
var last_usec := 0
var _survey: RefCounted
var _bodies: MultiMesh
var _wings: MultiMesh
var _since := {}
var _rng := RandomNumberGenerator.new()

func setup(owner: Node3D) -> void:
	life = owner
	name = "Dragonflies"
	_bodies = Kit.batch(self,"Bodies",_body(life.material),MAX)
	_wings = Kit.batch(self,"Wings",_wing(life.material),MAX*4)

func clear() -> void:
	flies.clear()
	_since.clear()
	_survey = null
	for i in range(MAX):
		_bodies.set_instance_transform(i,Kit.hidden())
		for k in range(4): _wings.set_instance_transform(i*4+k,Kit.hidden())

## How many are out over the survey's ponds now.
func showing() -> int:
	return flies.filter(func(fly: Dictionary) -> bool: return float(fly.fade) > 0.0).size()

## Slim abdomen ringed dark, a glassy-eyed head, one thorax; faces +Z.
static func _body(material: Material) -> ArrayMesh:
	var b := Models.Build.new()
	var light := Color(0.9,0.9,0.9)
	var dark := Color(0.22,0.24,0.28)
	b.icosahedron(Vector3(0,0.0,0.105),0.019,Color(0.55,0.75,0.45),0.9)
	b.spindle(Vector3(0,0,0.085),Vector3(0,0,-0.03),0.022,light,5,0.5)
	for i in range(5):
		var z0 := -0.03-i*0.05
		b.spindle(Vector3(0,0,z0),Vector3(0,0,z0-0.05),0.0105,light if i%2 == 0 else dark,4,0.5)
	return b.commit(material)

## One wing, fore and hind stacked by the instance, reaching along +X.
static func _wing(material: Material) -> ArrayMesh:
	var rim := [Vector3(0.0,0,0.035),Vector3(0.07,0.004,0.048),Vector3(0.15,0.0,0.038),Vector3(0.205,0,0.012),Vector3(0.16,0,-0.014),Vector3(0.07,0,-0.02),Vector3(0.0,0,-0.012)]
	return Kit.wing(material,rim,Color(0.78,0.86,0.9),Color(0.5,0.58,0.66))

func advance(step: float) -> void:
	var began := Time.get_ticks_usec()
	if life.survey != _survey: _sync()
	var fair := _fair()
	for fly: Dictionary in flies:
		_fly(fly,step,fair)
	last_usec = Time.get_ticks_usec()-began

func _fair() -> bool:
	var season := WorldClock.season_factor(life._season(),SEASON)
	return season >= SEASON_MIN and life._daylight() >= DAYLIGHT_MIN and Kit.rain(life) < RAIN_MAX

## Match the flies to the new survey's ponds: keep those whose pond stands,
## start the ponds that are new.
func _sync() -> void:
	_survey = life.survey
	if _survey == null: return
	var ponds := {}
	var ranked: Array = _survey.bodies.filter(func(record: Dictionary) -> bool: return record.area >= POND_AREA and not record.deep.is_empty())
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.area > b.area)
	for record: Dictionary in ranked:
		ponds[int(record.cells[0])] = record
	var kept: Array[Dictionary] = []
	var per := {}
	for fly: Dictionary in flies:
		var record: Variant = ponds.get(fly.key)
		if record == null or int(per.get(fly.key,0)) >= _count(record): continue
		per[fly.key] = int(per.get(fly.key,0))+1
		fly.record = record
		kept.append(fly)
	for key: int in ponds:
		var record: Dictionary = ponds[key]
		while int(per.get(key,0)) < _count(record) and kept.size() < MAX:
			kept.append(_born(key,record,int(per.get(key,0))))
			per[key] = int(per.get(key,0))+1
	# Retiring flies leave the batch tidy.
	for fly: Dictionary in flies:
		if not kept.has(fly): _hide(fly)
	flies = kept
	for i in range(flies.size()): flies[i].slot = i
	for i in range(flies.size(),MAX): _hide({"slot":i})

static func _count(record: Dictionary) -> int:
	return clampi(1+int(float(record.area)/FLY_AREA),1,PER_POND)

func _born(key: int, record: Dictionary, n: int) -> Dictionary:
	var h := Kit.unit([life.salt,key,n,71])
	var cell: int = record.deep[int(Kit.unit([life.salt,key,n,72])*record.deep.size())]
	var c := Survey.center(cell)
	var level := float(record.level)
	var fly := {"key":key,"record":record,"slot":-1,"fade":0.0,"wait":lerpf(ARRIVE.x,ARRIVE.y,h),"phase":h*TAU,
		"pos":Vector3(c.x,level+lerpf(HEIGHT.x,HEIGHT.y,h),c.y),"yaw":Kit.unit([life.salt,key,n,73])*TAU,
		"hold":lerpf(HOVER.x,HOVER.y,h),"dash":-1.0,"tint":TINTS[int(Kit.unit([life.salt,key,n,74])*TINTS.size())],
		"size":lerpf(0.9,1.15,Kit.unit([life.salt,key,n,75])),"time":0.0,"pitch":0.0}
	fly.from = fly.pos
	fly.to = fly.pos
	fly.length = 1.0
	return fly

func _hide(fly: Dictionary) -> void:
	var slot := int(fly.slot)
	if slot < 0: return
	_bodies.set_instance_transform(slot,Kit.hidden())
	for k in range(4): _wings.set_instance_transform(slot*4+k,Kit.hidden())

func _fly(fly: Dictionary, step: float, fair: bool) -> void:
	if fair:
		fly.wait = float(fly.wait)-step
		if float(fly.wait) <= 0.0: fly.fade = minf(float(fly.fade)+step/FADE,1.0)
	else:
		fly.fade = maxf(float(fly.fade)-step/FADE,0.0)
	if float(fly.fade) <= 0.0:
		_hide(fly)
		return
	fly.time = float(fly.time)+step
	var pos: Vector3 = fly.pos
	var dashing := float(fly.dash) >= 0.0
	var recoil := 0.0
	var goal := 0.0
	if dashing:
		fly.dash = float(fly.dash)+step
		var u := minf(float(fly.dash)/float(fly.length),1.0)
		# Starts hard and brakes late: mostly out-cubic, a little smoothstep.
		var e := lerpf(1.0-pow(1.0-u,3.0),smoothstep(0.0,1.0,u),0.3)
		pos = (fly.from as Vector3).lerp(fly.to,e)
		goal = DASH_PITCH*sin(u*PI)
		if u >= 1.0:
			fly.dash = -1.0
			fly.hold = _rng.randf_range(HOVER.x,HOVER.y)
			fly.pos = fly.to
	else:
		fly.hold = float(fly.hold)-step
		# The hover: a slow drift and a quick, small jitter.
		var t := float(fly.time)+float(fly.phase)
		pos = (fly.pos as Vector3)+Vector3(sin(t*1.3)*0.012+sin(t*7.1)*0.004,sin(t*2.1)*0.01+sin(t*9.0)*0.004,sin(t*1.7+1.0)*0.012)
		if float(fly.hold) < RECOIL_TIME: recoil = RECOIL*(1.0-float(fly.hold)/RECOIL_TIME)
		if float(fly.hold) <= 0.0: _dart(fly)
	fly.pitch = Kit.ease_to(float(fly.pitch),goal+recoil,14.0,step)
	if dashing: fly.yaw = lerp_angle(float(fly.yaw),atan2(float(fly.to.x-fly.from.x),float(fly.to.z-fly.from.z)),1.0-exp(-16.0*step))
	var scale := float(fly.size)*SCALE*smoothstep(0.0,1.0,float(fly.fade))
	var body := Transform3D(Basis(Vector3.UP,float(fly.yaw))*Basis(Vector3.RIGHT,-float(fly.pitch))*Basis.from_scale(Vector3.ONE*scale),pos)
	_bodies.set_instance_transform(fly.slot,body)
	_bodies.set_instance_color(fly.slot,fly.tint)
	# Fore and hind wings beat in antiphase; the dart holds them a little back.
	var beat := sin((float(fly.time)+float(fly.phase))*BEAT)*(0.6 if dashing else 1.0)
	var fore := Kit.wing_pair(body,Vector3(0.012,0.014,0.06),0.1+SWEEP*0.5*beat,-0.05)
	var hind := Kit.wing_pair(body,Vector3(0.012,0.014,0.02),0.1-SWEEP*0.5*beat,0.12)
	var slot := int(fly.slot)*4
	for k in range(2):
		_wings.set_instance_transform(slot+k,fore[k])
		_wings.set_instance_transform(slot+2+k,hind[k])
	for k in range(4): _wings.set_instance_color(slot+k,Color.WHITE)

## Choose the next spot over the pond (or a bank cell beside it) within reach.
func _dart(fly: Dictionary) -> void:
	var record: Dictionary = fly.record
	var here := Vector2((fly.pos as Vector3).x,(fly.pos as Vector3).z)
	var cells: PackedInt32Array = record.shore if _rng.randf() < BANK_SHARE and not record.shore.is_empty() else record.cells
	var best := Vector2.ZERO
	var best_score := INF
	var want := _rng.randf_range(REACH.x,REACH.y)
	for n in range(6):
		var c := Survey.center(cells[_rng.randi_range(0,cells.size()-1)])
		var score := absf(here.distance_to(c)-want)
		if score < best_score:
			best_score = score
			best = c
	best += Vector2(_rng.randf_range(-0.25,0.25),_rng.randf_range(-0.25,0.25))
	var ground: float = _survey.ground_at(best)
	var base := maxf(float(record.level),ground if not is_nan(ground) else -INF)
	var to := Vector3(best.x,base+_rng.randf_range(HEIGHT.x,HEIGHT.y),best.y)
	fly.from = fly.pos
	fly.to = to
	fly.dash = 0.0
	fly.length = maxf((to-(fly.from as Vector3)).length()/SPEED*1.6,0.25)
