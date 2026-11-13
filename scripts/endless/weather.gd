class_name Weather
extends RefCounted
## Weather (docs/design/endless-flight/spec-weather.md): the whole sky turning
## over minutes round the plane, never a place with an edge. Mostly fair; now
## and then a shower, rarely a storm; each builds, holds and clears.
##
## THE CONTRACT (the lanes build on this; keep it stable)
##
## Made by studies/endless_flight.gd (`weather`, null with --weather=off) and
## handed to the look (`look.weather`). `step()` runs once a frame before the
## look's, so everything read after it in a frame is this frame's.
##
## State: `state` is FAIR, BUILDING, SHOWER, STORM or CLEARING; `kind` the
## spell's (SHOWER or STORM; FAIR when none is near). Eased scalars, 0..1
## unless said:
##   build()      how far the sky has turned (0 fair, 1 the spell held)
##   severity()   0 fair, SHOWER_SEVERITY (0.5) a shower, 1 a storm; x build
##   cover()      the cloud cover's lift (a shower COVER_SHOWER, a storm 1)
##   wind()       a multiplier on the look's wind (1 fair, up to 1+WIND_STORM)
##   clear_sky()  1 - cover(): how open the sky is (rainbow, aurora)
##   rain_level() the rain's base level over the whole sky (0 until the
##                sky has half turned)
##   rain_at(p)   the rain at xz `p`: rain_level() x the drifting cells
##   rain_here()  rain_at the eye (as of the last step)
##   rain_ahead(dir) the mean rain 1.5, 3 and 5 km from the eye along xz `dir`
##   wet()        the land's wetness: follows rain in over WET_IN s, dries
##                over DRY s (the paced clock)
##   next_change() seconds (real, at the pace) to the next change of state;
##                INF when held
##   note()       --weather-debug's line
##
## The rain cells: value noise (lattice CELL m, two octaves) drifting with the
## look's wind_direction at CELL_SPEED m/s, so the soft blobs are 2-4 km with
## kilometre feathers: n = 0.65 vnoise(q) + 0.35 vnoise(2 q'), q = (p + drift)
## / CELL, q' = (p + drift/2) / CELL; cell = smoothstep(CELL_EDGE.x, .y, n);
## rain = level x mix(floor, 1, cell). The second octave drifts at half speed
## so the cells change shape as they go. The hash is a 32-bit integer one on
## lattice points taken mod PERIOD, so the GPU's copy matches (drift wraps at
## PERIOD x CELL). The GPU's copy: shaders/weather.gdshaderinc zs_rain_at();
## the march's GLSL takes the same body (keep the numbers equal).
##
## Shader globals (project.godot; their defaults are "no weather", so
## --weather=off leaves them as they are):
##   zs_weather      vec4 (build, severity, rain here, wet)
##   zs_weather_sky  vec4 (cover, wind, clear_sky, rain_level)
##   zs_rain_field   vec4 (drift.x, drift.y, rain_level, floor)
##   zs_lightning    vec4 (latest flash x, z, seconds since, strength):
##                   written by the lightning lane only; (0, 0, 1e6, 0) none
##
## The light: grade() sets celestial.cloud (CLOUD_GRADE x cover) and
## celestial.storm (STORM_GRADE x severity, at most STORM_CAP) before the look
## advances the sky, and greys its dome (celestial weather_grey, weather_dim:
## its own cloud and storm targets turn this sky near black); sun_shade() dims the sun after (SUN_LEFT under a storm,
## CELL_SUN more under a cell). A storm stays a heavy overcast afternoon,
## never night. Fair weather writes cloud 0 and storm 0, the look's own.
##
## Flags: --weather=cycle (default) | fair | shower | storm (held, built up
## from the start) | off (nothing built); --weather-pace=X (the clock x X);
## --weather-debug (a line at the bottom left). --weather-seed=N the cycle's
## own seed (the flight's seed by default).
##
## It never touches the plane: nothing here is read by the flight, and it
## draws no random numbers but its own.

const LaunchArgs = preload("res://scripts/launch_args.gd")

enum { FAIR, BUILDING, SHOWER, STORM, CLEARING }
const NAMES := ["fair","building","shower","storm","clearing"]

## The cycle (s of flight at pace 1): fair spells between FAIR_GAP.x and .y,
## the first never shorter than FIRST_GAP (a flight never starts in rain);
## STORM_SHARE of the spells are storms. Each spell builds over BUILD,
## holds (SHOWER_HOLD, STORM_HOLD) and clears over CLEAR.
const FAIR_GAP := Vector2(360.0,720.0)
const FIRST_GAP := 360.0
const STORM_SHARE := 0.25
const BUILD := Vector2(150.0,240.0)
const SHOWER_HOLD := Vector2(120.0,240.0)
const STORM_HOLD := Vector2(240.0,420.0)
const CLEAR := Vector2(150.0,240.0)

const SHOWER_SEVERITY := 0.5
const COVER_SHOWER := 0.65
const WIND_SHOWER := 0.35
const WIND_STORM := 0.9
## The rain's level (a shower's, a storm's), come in as build goes RAIN_IN.x
## to .y; between the cells it keeps FLOOR_* of it.
const RAIN_SHOWER := 0.6
const RAIN_STORM := 1.0
const RAIN_IN := Vector2(0.45,0.9)
const FLOOR_SHOWER := 0.0
const FLOOR_STORM := 0.45

## The cells (see above). Keep equal in shaders/weather.gdshaderinc.
const CELL := 2600.0
const CELL_SPEED := 9.0
const CELL_EDGE := Vector2(0.42,0.72)
const PERIOD := 256

const WET_IN := 90.0
const DRY := 300.0

## The light. Celestial's `cloud` is its grey overcast (the sky's dome greyed,
## the fill brighter and flatter, the sun's key down to 0.44 at 1): CLOUD_GRADE
## of cover(). Its `storm` darkens the dome toward near black, so only a little
## of it, STORM_GRADE of severity(), at most STORM_CAP. On top the sun keeps
## SUN_LEFT under a storm (SHOWER_SEVERITY's share of that in a shower), and
## CELL_SUN more under a cell's heaviest rain.
const CLOUD_GRADE := 0.85
## The dome: celestial's own cloud/storm targets turn this sky near black, so
## the dome is greyed instead (celestial weather_grey = cover()) to a grey as
## bright as the clear sky's by its hour, times DOME_STORM under a storm.
const DOME_STORM := 0.88
## The grey is lifted this much over the clear sky's luma first: a blue sky's
## luma is low (blue weighs 0.07), so an overcast as bright as it read as a
## slate dusk with white clouds in front (a shower's gaps).
const DOME_LIFT := 1.6
## The land's sky fill lifted this much at a whole cover (celestial
## weather_fill): with the sun cut, an overcast still lights the land from its
## whole dome, so a storm's land stays readable (a heavy overcast afternoon).
const FILL_OVERCAST := 2.2
const STORM_GRADE := 0.25
const STORM_CAP := 0.12
const SUN_LEFT := 0.8
const CELL_SUN := 0.85

var state := FAIR
var kind := FAIR
## The weather's own clock (s, paced): it waits while the menu holds.
var time := 0.0
var pace := 1.0
## FAIR, SHOWER or STORM held by a flag; -1 cycling.
var held := -1
## With a held shower or storm, the build it holds (--weather-build=F, for
## judging a part-built sky; 1 by default).
var held_build := 1.0
var debug := false
var drift := Vector2.ZERO

var _build := 0.0
var _kind_severity := 0.0
var _rain_here := 0.0
var _wet := 0.0
var _eye := Vector2.ZERO
var _next := INF
var _rng := RandomNumberGenerator.new()
## The spells laid so far: [start, kind, build, hold, clear] each.
var _spells: Array = []

## The weather the flags ask for, or null with --weather=off.
static func from_args(flight_seed: int) -> Weather:
	var w := Weather.new()
	var s := flight_seed
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--weather="):
			match a.get_slice("=",1):
				"off": return null
				"fair": w.held = FAIR
				"shower": w.held = SHOWER
				"storm": w.held = STORM
				_: w.held = -1
		elif a.begins_with("--weather-pace="): w.pace = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--weather-seed="): s = a.get_slice("=",1).to_int()
		elif a == "--weather-debug": w.debug = true
		elif a.begins_with("--weather-build="): w.held_build = clampf(a.get_slice("=",1).to_float(),0.0,1.0)
	w._rng.seed = hash(s)^0x57ea7e
	w._settle()
	return w

func _settle() -> void:
	if held >= 0:
		kind = held
		state = held
		_build = 0.0 if held == FAIR else held_build
		_kind_severity = _severity_of(kind)
	_rain_here = rain_at(_eye)
	_wet = _rain_here
	_publish()
	RenderingServer.global_shader_parameter_set("zs_lightning",Vector4(0.0,0.0,1e6,0.0))

static func _severity_of(k: int) -> float:
	return 1.0 if k == STORM else (SHOWER_SEVERITY if k == SHOWER else 0.0)

## One frame: `eye` the camera's position, `wind_dir` the look's
## wind_direction (unit xz), `holding` true while the menu holds the flight.
func step(delta: float, eye: Vector3, wind_dir: Vector2, holding := false) -> void:
	_eye = Vector2(eye.x,eye.z)
	var dt := 0.0 if holding else delta*pace
	time += dt
	var wrap := CELL*PERIOD
	drift -= wind_dir*CELL_SPEED*dt
	drift = Vector2(fposmod(drift.x,wrap),fposmod(drift.y,wrap))
	if held < 0: _cycle()
	_rain_here = rain_at(_eye)
	if _rain_here > _wet: _wet += (_rain_here-_wet)*(1.0-exp(-dt/WET_IN))
	else: _wet = maxf(_rain_here,_wet-dt/DRY)
	_publish()

func _cycle() -> void:
	while _spells.is_empty() or time >= _end_of(_spells.back()):
		_lay()
	# The spell now or next: the first whose end is ahead.
	var s: Array = _spells[0]
	for each: Array in _spells:
		if time < _end_of(each):
			s = each
			break
	var t := time-float(s[0])
	var b := float(s[2])
	var h := float(s[3])
	var c := float(s[4])
	kind = int(s[1])
	_kind_severity = _severity_of(kind)
	if t < 0.0:
		state = FAIR
		_build = 0.0
		_next = -t
	elif t < b:
		state = BUILDING
		_build = smoothstep(0.0,1.0,t/b)
		_next = b-t
	elif t < b+h:
		state = kind
		_build = 1.0
		_next = b+h-t
	else:
		state = CLEARING
		_build = 1.0-smoothstep(0.0,1.0,(t-b-h)/c)
		_next = b+h+c-t
	if state == FAIR: kind = FAIR
	_next /= maxf(pace,1e-3)

static func _end_of(s: Array) -> float:
	return float(s[0])+float(s[2])+float(s[3])+float(s[4])

func _lay() -> void:
	var from := 0.0 if _spells.is_empty() else _end_of(_spells.back())
	var gap := _rng.randf_range(FAIR_GAP.x,FAIR_GAP.y)
	if _spells.is_empty(): gap = maxf(gap,FIRST_GAP)
	var k := STORM if _rng.randf() < STORM_SHARE else SHOWER
	var hold := _rng.randf_range(STORM_HOLD.x,STORM_HOLD.y) if k == STORM else _rng.randf_range(SHOWER_HOLD.x,SHOWER_HOLD.y)
	_spells.append([from+gap,k,_rng.randf_range(BUILD.x,BUILD.y),hold,_rng.randf_range(CLEAR.x,CLEAR.y)])
	# Only the spell now and the next are kept.
	while _spells.size() > 2 and time >= _end_of(_spells[0]): _spells.pop_front()

func build() -> float: return _build
func severity() -> float: return _kind_severity*_build
func cover() -> float: return _build*lerpf(COVER_SHOWER,1.0,clampf((_kind_severity-SHOWER_SEVERITY)/(1.0-SHOWER_SEVERITY),0.0,1.0)) if _kind_severity > 0.0 else 0.0
func wind() -> float: return 1.0+_build*(WIND_STORM if kind == STORM else (WIND_SHOWER if kind == SHOWER else 0.0))
func clear_sky() -> float: return 1.0-cover()
func rain_level() -> float:
	var top := RAIN_STORM if kind == STORM else (RAIN_SHOWER if kind == SHOWER else 0.0)
	return top*smoothstep(RAIN_IN.x,RAIN_IN.y,_build)
func rain_floor() -> float: return FLOOR_STORM if kind == STORM else FLOOR_SHOWER
func rain_here() -> float: return _rain_here
func wet() -> float: return _wet
func next_change() -> float: return INF if held >= 0 else _next

func rain_at(p: Vector2) -> float:
	var level := rain_level()
	if level <= 0.0: return 0.0
	return level*lerpf(rain_floor(),1.0,cell_at(p))

## The cells alone at xz `p` (0..1), whatever the state.
func cell_at(p: Vector2) -> float:
	var q := (p+drift)/CELL
	var q2 := (p+drift*0.5)/CELL*2.0
	var n := 0.65*_vnoise(q)+0.35*_vnoise(q2)
	return smoothstep(CELL_EDGE.x,CELL_EDGE.y,n)

func rain_ahead(dir: Vector2) -> float:
	var d := dir.normalized()
	return (rain_at(_eye+d*1500.0)+rain_at(_eye+d*3000.0)+rain_at(_eye+d*5000.0))/3.0

static func _hash(ix: int, iy: int) -> float:
	var x := posmod(ix,PERIOD)
	var y := posmod(iy,PERIOD)
	var h := (x*374761393+y*668265263) & 0xffffffff
	h = ((h^(h >> 13))*1274126177) & 0xffffffff
	h = h^(h >> 16)
	return float(h & 0xffffff)/16777215.0

static func _vnoise(q: Vector2) -> float:
	var i := q.floor()
	var f := q-i
	var u := f*f*(Vector2(3.0,3.0)-2.0*f)
	var ix := int(i.x)
	var iy := int(i.y)
	var a := _hash(ix,iy)
	var b := _hash(ix+1,iy)
	var c := _hash(ix,iy+1)
	var d := _hash(ix+1,iy+1)
	return lerpf(lerpf(a,b,u.x),lerpf(c,d,u.x),u.y)

func _publish() -> void:
	RenderingServer.global_shader_parameter_set("zs_weather",Vector4(_build,severity(),_rain_here,_wet))
	RenderingServer.global_shader_parameter_set("zs_weather_sky",Vector4(cover(),wind(),clear_sky(),rain_level()))
	RenderingServer.global_shader_parameter_set("zs_rain_field",Vector4(drift.x,drift.y,rain_level(),rain_floor()))

## The light's grade on the look's Celestial (each frame, before it advances).
func grade(celestial: RefCounted) -> void:
	celestial.cloud = CLOUD_GRADE*cover()
	celestial.weather_grey = cover()
	celestial.weather_dim = DOME_LIFT*lerpf(1.0,DOME_STORM,severity())
	celestial.weather_fill = lerpf(1.0,FILL_OVERCAST,cover())
	celestial.storm = minf(STORM_GRADE*severity(),STORM_CAP)

## The sun's share left (each frame, times its energy after the look set it).
func sun_shade() -> float:
	return lerpf(1.0,SUN_LEFT,severity())*lerpf(1.0,CELL_SUN,_rain_here)

func note() -> String:
	var nxt := next_change()
	return "weather %s%s  ·  build %.2f  ·  severity %.2f  ·  cover %.2f  ·  rain here %.2f  ·  wet %.2f  ·  wind x%.2f  ·  next %s  ·  pace %.1f" % [
		NAMES[state]," (%s)" % NAMES[kind] if state == BUILDING or state == CLEARING else "",
		_build,severity(),cover(),_rain_here,_wet,wind(),"held" if is_inf(nxt) else "%.0f s" % nxt,pace]
