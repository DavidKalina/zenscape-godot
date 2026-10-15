extends RefCounted
## The wanderer's noises (docs/design/roguelike/noise-stealth-round1.md),
## made on the layer's NoiseBus (scripts/noise/noise_bus.gd) from what his
## motor and body did this frame, and his ring of dust on the loud ones
## (scripts/noise/noise_ripples.gd). One per wanderer: the source of each
## noise is his figure, so a co-op second wanderer is a second one of these.
## Stepped by the character study after its motor and body (`step`).
##
## Loudness, m (at wanderer size 1; times his size):
##   footfall  by his flat pace over his run (`FOOT`): a sneak (under
##             SNEAK of his run: the sneak key, or the stick eased) 1.5,
##             a walk about 4, a run 14, carried past the run (a slide hop's
##             landing, a long jump's) up to 24
##   landing   LAND_BASE + LAND_PER_M a metre fallen (a hop about 8, a
##             pump 12, a 6 m drop 41), most LAND_MOST; landed crouched,
##             x SOFT
##   slam      SLAM + SLAM_POWER x its power (30-50)
##   grab      a ledge caught 6, a climb over 5, a wall kick 8, a wall
##             slide's touch 4
##   slide     its start 10, then a scrape every SCRAPE s at its pace's
##             footfall; a skid's start 9
##   water     a splash into it 11, a hop out 6
##   jump      the takeoff: his footfall's, +2

const PassiveNoise = preload("res://scripts/roguelike/passive_noise.gd")  # [items_passive]
const Ripples = preload("res://scripts/noise/noise_ripples.gd")

## A footfall's loudness (m) by his pace as a share of his run.
const FOOT := [[0.0,1.0],[0.45,1.5],[0.55,4.0],[1.0,14.0],[2.0,24.0]]
## Under this share of his run he sneaks (the quiet footfall).
const SNEAK := 0.45
const LAND_BASE := 5.0
const LAND_PER_M := 6.0
const LAND_MOST := 48.0
## A landing with crouch held: the knees take it.
const SOFT := 0.6
const SLAM := 30.0
const SLAM_POWER := 20.0
const GRAB := 6.0
const CLIMB := 5.0
const WALL_KICK := 8.0
const WALL_TOUCH := 4.0
const SLIDE := 10.0
const SKID := 9.0
const SPLASH := 11.0
const HOP_OUT := 6.0
const SCRAPE := 0.35

var ripples: Node3D = null
## The last noise he made, and how many (for checks and the HUD).
var last: Object = null
var count := 0
var _scrape := 0.0
var _skid_was := false
## The highest his feet were since he last stood (m).
var _top := -INF

## A footfall's loudness (m, at size 1) at `share` of his run.
static func footfall(share: float) -> float:
	for i in range(1,FOOT.size()):
		var a: Array = FOOT[i-1]
		var b: Array = FOOT[i]
		if share <= float(b[0]): return lerpf(float(a[1]),float(b[1]),inverse_lerp(float(a[0]),float(b[0]),share))
	return float(FOOT[-1][1])

## One frame: the study's motor stepped (`events`), its body drawn (`drawn`).
func step(study: Node3D, events: Dictionary, drawn: Dictionary, delta: float) -> void:
	var motor: RefCounted = study.motor
	var figure: Node3D = study.figure
	if figure == null or not figure.is_inside_tree(): return
	if ripples == null or not is_instance_valid(ripples):
		ripples = Ripples.new()
		study.add_child(ripples)
	var size: float = motor.size
	ripples.size = size
	var feet: Vector3 = motor.feet
	var share: float = motor.speed()/maxf(float(motor.run),0.01)
	var foot := footfall(share)*size
	if drawn.has("footfall") and motor.wade < 0.04: _make(figure,feet,foot,&"step")
	elif drawn.has("footfall"): _make(figure,feet,maxf(foot,HOP_OUT*0.5*size),&"splash")
	if events.has("jumped"):
		_make(figure,feet,(WALL_KICK*size if events.has("wall_jump") else foot+2.0*size),&"grab" if events.has("wall_jump") else &"step")
	if events.has("landed"):
		var v := float(events.landed)
		var g: float = float(motor.gravity)*float(motor.fall)
		# Its height: the fall's own (past his terminal pace the touch's
		# speed says no more), the speed's under a sail or a slowed fall.
		var drop := v*v/(2.0*maxf(g,0.01))
		if _top > -INF and v >= float(motor.terminal)*0.9: drop = maxf(drop,_top-feet.y)
		var loud := minf(LAND_BASE*size+LAND_PER_M*drop,LAND_MOST*size)
		if motor.crouch: loud *= SOFT
		if events.has("slammed") or events.has("slam"):
			var power := float((events.slam as Dictionary).get("power",0.5)) if events.has("slam") and events.slam is Dictionary else 0.5
			loud = maxf(loud,(SLAM+SLAM_POWER*power)*size)
			_make(figure,feet,loud,&"slam")
		else: _make(figure,feet,loud,&"land")
	if events.has("grabbed"): _make(figure,feet,GRAB*size,&"grab")
	if events.has("climbed"): _make(figure,feet,CLIMB*size,&"grab")
	if events.get("wall",false): _make(figure,feet,WALL_TOUCH*size,&"grab")
	if events.has("swam"): _make(figure,feet,SPLASH*size,&"splash")
	if events.has("hopped"): _make(figure,feet,HOP_OUT*size,&"splash")
	# The slide: its start, then its scrape at its pace.
	if events.get("slide",false):
		_make(figure,feet,SLIDE*size,&"slide")
		_scrape = SCRAPE
	if motor.move == "slide" and motor.grounded:
		_scrape -= delta
		if _scrape <= 0.0:
			_scrape = SCRAPE
			_make(figure,feet,foot,&"slide")
	if motor.skidding and not _skid_was and motor.grounded: _make(figure,feet,SKID*size,&"slide")
	_skid_was = motor.skidding
	_top = feet.y if motor.grounded else maxf(_top,feet.y)

func _make(figure: Node3D, at: Vector3, loudness: float, kind: StringName) -> void:
	loudness *= PassiveNoise.mul(kind)  # [items_passive]
	var n := NoiseBus.make(figure,at,loudness,kind)
	if n == null: return
	last = n
	count += 1
	if ripples != null: ripples.ring(at,loudness)
