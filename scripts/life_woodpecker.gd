extends Node3D
## A woodpecker drumming on dead wood (docs/scenic/life.md). It is mostly a
## sound: in an old stand, where emergence has left snags standing, on a dry
## daytime a woodpecker now and then lands on a snag, and drums two to four
## rolls from it, each a dry rattle of knocks that carries from the snag.
## Between rolls it holds still and turns its head, then flits off.
##
## The rolls are synthesised once, on first use (`LifeSmallKit.drum_roll`), in
## three lengths, and played from the snag on the Genesis bus. The bird is one
## small code-built model: a body clinging to the trunk, tail braced, and a head
## that cocks back and strikes at drumming pace. Read from LandLife's survey
## (`snag_spots`); owned by LifeSmall.

const Kit = preload("res://scripts/life_small_kit.gd")
const Models = preload("res://scripts/life_models.gd")

## Seconds of a survey with snags before the first visit, then between visits
## (life clock), the check interval, and the chance each check starts one.
const FIRST := Vector2(35.0, 90.0)
const GAP := Vector2(140.0, 320.0)
const CHECK := 3.0
const CHANCE := 0.35
## Snags are old wood: winter has some, so the year is [spring, summer, autumn, winter].
const SEASON := [1.0, 0.9, 0.8, 0.45]
const SEASON_MIN := 0.3
const DAYLIGHT_MIN := 0.5
const RAIN_MAX := 0.2
## Rolls a visit drums, the seconds a roll lasts, knocks a second, and the
## pause between rolls.
const ROLLS := Vector2i(2, 4)
const ROLL_LENGTHS := [0.7, 0.95, 1.2]
const KNOCKS := 17.0
const PAUSE := Vector2(2.2, 5.0)
## Where on the snag it clings (share of its height), the trunk's half-width
## there at unit scale, and the bird's size.
const PERCH := Vector2(0.5, 0.75)
const TRUNK := 0.08
const SIZE := 2.2
## The head's swing when it strikes (radians) and the seconds to land and to leave.
const STRIKE := 0.42
const LAND := 0.35
const LEAVE := 0.55
const GAIN := 0.4

var life: Node3D
var last_usec := 0
var rolls_played := 0
var _bird: Node3D
var _head: MeshInstance3D
var _speaker: AudioStreamPlayer3D
var _rolls: Array[AudioStreamWAV] = []
var _rng := RandomNumberGenerator.new()
var _survey: RefCounted
var _clock := 0.0
var _check := 0.0
var _next := -1.0
var _visit := {}

func setup(owner: Node3D) -> void:
	life = owner
	name = "Woodpecker"
	_rng.seed = 7
	_bird = Node3D.new()
	_bird.visible = false
	add_child(_bird)
	_bird.add_child(_mesh(_body(life.material)))
	_head = _mesh(_head_model(life.material))
	_head.position = Vector3(0,0.075,0.03)
	_bird.add_child(_head)

func clear() -> void:
	_visit = {}
	_survey = null
	_next = -1.0
	if _bird != null: _bird.visible = false

static func _mesh(mesh: Mesh) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

## Head up, belly toward -Z (the trunk), tail braced below; about 0.24 m tall.
static func _body(material: Material) -> ArrayMesh:
	var b := Models.Build.new()
	var black := Models.hex("#1c1c20")
	var buff := Models.hex("#d8ccb0")
	var red := Models.hex("#c2281f")
	b.spindle(Vector3(0,-0.07,0.048),Vector3(0,0.07,0.05),0.034,black,6,0.45,0.03)
	b.spindle(Vector3(0,-0.06,0.014),Vector3(0,0.07,0.02),0.03,buff,6,0.45,0.02)
	b.spindle(Vector3(0,-0.055,0.06),Vector3(0,0.05,0.075),0.022,Models.hex("#eeeae0"),4,0.4,0.01)
	b.spindle(Vector3(0,-0.05,0.02),Vector3(0,-0.185,-0.01),0.02,black,4,0.4,0.006)
	b.icosahedron(Vector3(0,-0.075,0.03),0.016,red,0.8)
	return b.commit(material)

## The head and its beak, about the neck at the origin.
static func _head_model(material: Material) -> ArrayMesh:
	var b := Models.Build.new()
	b.icosahedron(Vector3(0,0.03,0),0.03,Models.hex("#1c1c20"),1.0)
	b.icosahedron(Vector3(0,0.024,0.02),0.017,Models.hex("#efeae0"),0.9)
	b.icosahedron(Vector3(0,0.028,0.03),0.016,Models.hex("#c2281f"),0.7)
	b.spindle(Vector3(0,0.03,-0.02),Vector3(0,0.028,-0.085),0.011,Models.hex("#5a5a60"),4,0.3,0.011)
	return b.commit(material)

## Is a visit on, for probes.
func showing() -> bool:
	return not _visit.is_empty()

func advance(step: float) -> void:
	var began := Time.get_ticks_usec()
	_clock += step
	if life.survey != _survey:
		_survey = life.survey
		# The first visit waits after snags first appear; a visit in progress goes on.
		if _next < 0.0 and _survey != null and not _survey.snag_spots.is_empty(): _next = _clock+_rng.randf_range(FIRST.x,FIRST.y)
	if _visit.is_empty():
		_check += step
		if _check >= CHECK:
			_check = 0.0
			if _next >= 0.0 and _clock >= _next and _fair() and _rng.randf() < CHANCE: start()
	else:
		_visit_step(step)
	last_usec = Time.get_ticks_usec()-began

func _fair() -> bool:
	if _survey == null or _survey.snag_spots.is_empty(): return false
	var season := WorldClock.season_factor(life._season(),SEASON)
	return season >= SEASON_MIN and life._daylight() >= DAYLIGHT_MIN and Kit.rain(life) < RAIN_MAX

## A visit now, skipping the wait, chance and hour but not the snag. False when
## there is none, or one is on. Probes call this.
func start() -> bool:
	if _survey == null or _survey.snag_spots.is_empty() or not _visit.is_empty(): return false
	if _rolls.is_empty(): _synthesise()
	var spot: Vector3 = _survey.snag_spots[_rng.randi_range(0,_survey.snag_spots.size()-1)]
	var ground: float = _survey.ground_at(Vector2(spot.x,spot.y))
	var base := (ground if not is_nan(ground) else 0.0)
	var camera := Kit.camera_local(life)
	var out := Vector3(camera.x-spot.x,0,camera.z-spot.y)
	out = out.normalized() if out.length() > 0.1 else Vector3.BACK
	var rise := lerpf(PERCH.x,PERCH.y,_rng.randf())*spot.z
	var perch := Vector3(spot.x,base+rise,spot.y)+out*(TRUNK*spot.z*SIZE*0.9+0.01)
	_visit = {"perch":perch,"out":out,"age":0.0,"rolls":_rng.randi_range(ROLLS.x,ROLLS.y),"roll":-1,"wait":LAND+0.4,"strike":0.0,"turn":0.0,"look":0.0,"gone":-1.0}
	_bird.visible = true
	_bird.position = perch
	_next = -1.0
	return true

func _synthesise() -> void:
	for i in range(ROLL_LENGTHS.size()): _rolls.append(Kit.drum_roll(ROLL_LENGTHS[i],KNOCKS,101+i))
	_speaker = Kit.speaker(self)

func _visit_step(step: float) -> void:
	var v := _visit
	v.age = float(v.age)+step
	var perch: Vector3 = v.perch
	var out: Vector3 = v.out
	var strike := 0.0
	var pop := 1.0
	var pos := perch
	if float(v.gone) >= 0.0:
		# Flits off: away from the trunk and up, shrinking into the sky.
		v.gone = float(v.gone)+step
		var u := float(v.gone)/LEAVE
		pos = perch+(out*1.2+Vector3(0,1.4,0))*u*u*3.0
		pop = 1.0-smoothstep(0.5,1.0,u)
		if u >= 1.0:
			_bird.visible = false
			_visit = {}
			_next = _clock+_rng.randf_range(GAP.x,GAP.y)
			return
	else:
		pop = smoothstep(0.0,LAND,float(v.age))
		v.wait = float(v.wait)-step
		if int(v.roll) >= 0 and float(v.strike) > 0.0:
			# Drumming: the head cocks back and strikes at the roll's pace.
			v.strike = float(v.strike)-step
			var beat := sin(TAU*KNOCKS*float(v.age))
			strike = STRIKE*(0.5+0.5*beat)*smoothstep(0.0,0.08,float(v.strike))
		elif float(v.wait) <= 0.0:
			if int(v.roll)+1 >= int(v.rolls):
				v.gone = 0.0
			else:
				_roll(v)
		# Between rolls it looks about: a slow turn of the whole bird a little.
		v.look = Kit.ease_to(float(v.look),sin(float(v.age)*0.9)*0.5*(0.0 if float(v.strike) > 0.0 else 1.0),3.0,step)
	# The bird's -Z faces the trunk; between rolls it turns a little side to side.
	_bird.transform = Transform3D(Basis(Vector3.UP,atan2(out.x,out.z)+float(v.look)*0.35)*Basis.from_scale(Vector3.ONE*SIZE*maxf(pop,0.0001)),pos)
	_head.rotation = Vector3(strike-0.05*float(v.look),0,0)

## The next roll: sound from the snag, and the head strikes for its length.
func _roll(v: Dictionary) -> void:
	v.roll = int(v.roll)+1
	var index := _rng.randi_range(0,_rolls.size()-1)
	var length: float = ROLL_LENGTHS[index]
	v.strike = length
	v.wait = length+_rng.randf_range(PAUSE.x,PAUSE.y)
	_speaker.position = v.perch
	_speaker.stream = _rolls[index]
	_speaker.volume_db = linear_to_db(GAIN)
	_speaker.pitch_scale = _rng.randf_range(0.94,1.06)
	_speaker.play()
	rolls_played += 1
