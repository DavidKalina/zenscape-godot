extends Node
## The heist's storm (a prototype; docs/design/heist-level/storm-handoff.md):
## on some runs, not all, one storm cell rolls in while he is flying and
## comes at the plane: its dark tower, rain shaft and lightning (scripts/
## storm_cells.gd), a whiteout in its core (scripts/storm_whiteout.gd), the
## dragon heard and seen in its lightning (scripts/dragon_sightings.gd), all
## through the sky weather study's elements (scripts/plane_weather.gd).
## Atmosphere only: its gusts push the plane about (`air`) and the whiteout
## takes the landmarks and cues away; nothing strikes, nothing is lost (the
## sightings' `sighted` is left unheard).
##
##   the draw   once a run, off the hunt's seed (studies/heist_home.gd
##              `hunt_seed`, or --hunt-seed= under --no-home), so a seed
##              replays it: a storm with CHANCE, at a flight time drawn from
##              WHEN (s spent flying, counted only in the air).
##   the cell   sent AHEAD m in front of the plane, a little aside, coming
##              back along its line; it bends toward the plane (TURN rad/s)
##              until it is over it, then goes on and past.
##   its core   the first time the plane is in the core (the cell's
##              storm_at past CORE) a whiteout drops; once the murk is thick
##              the dragon is called if it has not shown yet this storm. The
##              sightings come on their own only while a storm is on.
##   the haze   home's depth fog (HeistHome `apply_haze`) follows the storm:
##              its colour to the storm's slate horizon, and in a whiteout
##              in toward the murk's colour and reach, so the land fades into
##              the murk, not through it (`fold_haze`).
## Flags: --storm=always|never, --storm-chance=<0..1>, --storm-at=<s> (the
## flight time it comes at). Debug keys (studies/heist_level.gd, in flight):
## C a cell toward the plane, M a whiteout, K / Shift+K the dragon far/close.
const PlaneWeather = preload("res://scripts/plane_weather.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const GreedMeter = preload("res://scripts/greed/greed_meter.gd")

const CHANCE := 1.0/3.0
const WHEN := Vector2(20.0,140.0)
const AHEAD := 800.0
const ASIDE := 60.0
const TURN := 0.15
const CORE := 0.85
## The sightings' mean wait while a storm is on (dragon_sightings EVERY).
const SIGHT_EVERY := 60.0
## The share of called sightings that are close.
const CLOSE_SHARE := 0.6
## The haze in a whiteout: its range (m) at full murk, and how far toward
## the murk's colour.
const MURK_HAZE := Vector2(30.0,240.0)
const MURK_COLOUR := Color(0.29,0.335,0.4)

var host: Node3D
var mode := "chance"
var chance := CHANCE
var seed_ := 0
var roll := 0.0
## Whether this run gets one, and the flight time (s) it comes at.
var coming := false
var at := 0.0
var flown := 0.0
var sent := false
## The weather (null till it is needed: a storm run, or a debug key).
var elements: Node3D = null
## A storm under way (the cell out), and its beats.
var on := false
var _reached := false
var _whited := false
var _called := false
var _rain_hidden := false
var _rng := RandomNumberGenerator.new()
var _haze_from := Vector2.ZERO
## What happened, for logs and drivers.
var stats := {"sent_at":-1.0,"over_at":-1.0,"whiteouts":0,"murk_most":0.0,"sightings":0,"gust_most":0.0,"wind_most":0.0}

func _init() -> void:
	name = "HeistStorm"

## The draw, off the flags and the hunt's seed (`hunt_seed`; 0 draws one).
func setup(h: Node3D, hunt_seed: int) -> void:
	host = h
	var pinned_at := NAN
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--storm="):
			var v := a.get_slice("=",1)
			if v in ["always","never"]: mode = v
		elif a.begins_with("--storm-chance="): chance = clampf(float(a.get_slice("=",1)),0.0,1.0)
		elif a.begins_with("--storm-at="): pinned_at = maxf(float(a.get_slice("=",1)),0.0)
		elif a.begins_with("--hunt-seed=") and hunt_seed == 0: hunt_seed = int(a.get_slice("=",1))
	if hunt_seed == 0:
		var r := RandomNumberGenerator.new()
		r.randomize()
		hunt_seed = r.randi_range(1,99999)
	seed_ = hunt_seed
	_rng.seed = hash(["storm",hunt_seed])
	roll = _rng.randf()
	at = _rng.randf_range(WHEN.x,WHEN.y)
	if not is_nan(pinned_at): at = pinned_at
	coming = mode == "always" or (mode != "never" and roll < chance)
	if coming: print("heist: storm yes at %d s of flight (seed %d, %s)" % [roundi(at),seed_,"always" if mode == "always" else "roll %.2f < %.2f" % [roll,chance]])
	else: print("heist: storm no (seed %d, %s)" % [seed_,"never" if mode == "never" else "roll %.2f >= %.2f" % [roll,chance]])

## Builds the weather now (a storm run, once walkable; or a debug key).
func ensure() -> bool:
	if elements != null: return true
	if host == null or host.get("_precipitation") == null or not bool(host.get("walk_ready")): return false
	var began := Time.get_ticks_msec()
	elements = PlaneWeather.new()
	elements.jets = false
	elements.grade_frame = false
	host.add_child(elements)
	elements.setup(host)
	elements.cells.auto = false
	elements.sightings.every = 0.0
	elements.sightings.log_on = true
	elements.sightings.sighted.connect(func(_e: Dictionary) -> void: stats.sightings += 1)
	# The sky's own rain stays (plane_weather hides it): hidden only while
	# this one falls (`after_sky`).
	_sky_rain(true)
	var prior: Callable = host.get("plane_air")
	if not prior.is_valid(): host.set("plane_air",air)
	print("heist storm: the weather built in %d ms" % (Time.get_ticks_msec()-began))
	return true

func _sky_rain(shown: bool) -> void:
	var sky: Node3D = host.get("_precipitation")
	if sky == null: return
	for old in ["Rain","RainCrowns"]:
		var node: Node3D = sky.get_node_or_null(old)
		if node != null: node.visible = shown
	_rain_hidden = not shown

## Before the scene's own frame (the study's order): the draw's clock, the
## cell sent and steered, the weather stepped, the core's beats.
func step(delta: float) -> void:
	if delta <= 0.0: return
	if coming and elements == null: ensure()
	if elements == null: return
	var plane: RefCounted = host.get("plane")
	var flying := bool(host.get("flying")) and plane != null
	if flying: flown += delta
	if coming and not sent and flying and flown >= at: send()
	elements.step(delta)
	var cells: Node3D = elements.cells
	if on and not cells.active: _over()
	if not on: return
	var p: Vector3 = elements.probe()
	# Bent toward the plane until it is over it.
	if not _reached and flying:
		var to := Vector3(p.x-cells.centre.x,0.0,p.z-cells.centre.z)
		if to.length() < float(cells.SHAFT):
			_reached = true
			stats.over_at = flown
			print("heist storm: the cell is over the plane at %s (%d s of flight)" % [p.round(),roundi(flown)])
		else:
			var want := atan2(to.z,to.x)
			var now := atan2(cells.way.z,cells.way.x)
			var a := now+clampf(angle_difference(now,want),-TURN*delta,TURN*delta)
			cells.way = Vector3(cos(a),0.0,sin(a))
			cells.target = Vector3(p.x,0.0,p.z)
	var core: float = cells.storm_at(p)
	if not _whited and core > CORE:
		_whited = true
		elements.whiteout.drop()
		print("heist storm: a whiteout drops in the core (storm %.2f)" % core)
	var murk: float = elements.murk
	stats.murk_most = maxf(float(stats.murk_most),murk)
	if murk > 0.6 and not _called and elements.sightings.now.is_empty():
		_called = true
		var near := "close" if _rng.randf() < CLOSE_SHARE else "far"
		if elements.sightings.call_now(near): print("heist storm: the dragon, %s, in the murk" % near)
	if flying:
		var here: Dictionary = air(p)
		var w: Vector3 = here.get("wind",Vector3.ZERO)
		stats.gust_most = maxf(float(stats.gust_most),float(here.get("gust",0.0)))
		stats.wind_most = maxf(float(stats.wind_most),Vector2(w.x,w.z).length())

## The cell now, AHEAD m in front of the plane (or the eye), coming at it.
func send() -> void:
	if not ensure(): return
	sent = true
	var p: Vector3 = elements.probe()
	var plane: RefCounted = host.get("plane")
	var fwd := Vector3.FORWARD
	if bool(host.get("flying")) and plane != null and Vector2(plane.velocity.x,plane.velocity.z).length() > 1.0:
		fwd = Vector3(plane.velocity.x,0.0,plane.velocity.z).normalized()
	elif host.get("camera") != null:
		var b: Vector3 = -(host.camera as Camera3D).global_basis.z
		if Vector2(b.x,b.z).length() > 0.01: fwd = Vector3(b.x,0.0,b.z).normalized()
	var side := fwd.cross(Vector3.UP)*_rng.randf_range(-ASIDE,ASIDE)
	var from := Vector3(p.x,0.0,p.z)+fwd*AHEAD+side
	var cells: Node3D = elements.cells
	cells.way = -fwd
	cells.target = Vector3(p.x,0.0,p.z)
	cells._start(from)
	on = true
	_reached = false
	_whited = false
	_called = false
	elements.sightings.every = SIGHT_EVERY
	stats.sent_at = flown
	print("heist storm: a storm cell rolls in %d m ahead of the plane at %s, coming at it (%d s of flight)" % [roundi(AHEAD),p.round(),roundi(flown)])

func _over() -> void:
	on = false
	elements.sightings.every = 0.0
	print("heist storm: the cell has passed (whiteouts %d, murk most %.2f, sightings %d, gust most %.2f)" % [elements.whiteout.count,float(stats.murk_most),int(stats.sightings),float(stats.gust_most)])

## After the sky has set its own frame: the storm's grade (folded with the
## greed meter's), its rain.
func after_sky() -> void:
	if elements == null: return
	elements.grade()
	_grade_frame()
	var plane: RefCounted = host.get("plane")
	var cam: Camera3D = host.get("camera")
	if cam != null: elements.rain(cam.global_position,plane.velocity if bool(host.get("flying")) and plane != null else Vector3.ZERO)
	var raining := maxf(smoothstep(PlaneWeather.RAIN_FROM,1.0,float(elements.storm)),float(elements.murk)) > 0.0
	if raining == not _rain_hidden: _sky_rain(not raining)

## The frame's grade: the storm's (PlaneWeather `frame_grade`) times the
## greed meter's (its GRADE by `shown`), which it would otherwise undo.
func _grade_frame() -> void:
	var env: Environment = host.get("_environment")
	if env == null: return
	var g: Vector3 = elements.frame_grade()
	var greed: Node = host.get("greed")
	var shown := float(greed.get("shown")) if greed != null else 0.0
	if shown > 0.001:
		var gg: Vector3 = GreedMeter.GRADE
		g *= Vector3(lerpf(1.0,gg.y,shown),lerpf(1.0,gg.x,shown),lerpf(1.0,gg.z,shown))
	env.adjustment_enabled = not g.is_equal_approx(Vector3.ONE)
	if not env.adjustment_enabled: return
	env.adjustment_brightness = g.x
	env.adjustment_saturation = g.y
	env.adjustment_contrast = g.z

## Home's haze under the storm (after HeistHome `tint_haze` set its own):
## toward the storm's slate horizon by the storm, in toward the murk's
## colour and reach by the murk.
func fold_haze(env: Environment, home: Node) -> void:
	if elements == null or env == null or home == null or not bool(home.get("haze_on")): return
	var haze: Vector2 = home.get("haze")
	var k := clampf(float(elements.storm),0.0,1.0)
	var m := clampf(float(elements.murk),0.0,1.0)
	if k <= 0.0 and m <= 0.0:
		env.fog_depth_begin = haze.x
		env.fog_depth_end = haze.y
		return
	var sky: RefCounted = host.get("_celestial")
	var day := 1.0
	if sky != null:
		var sun: Vector3 = sky.state.get("zs_sun_direction",Vector3.UP)
		day = lerpf(PlaneWeather.SLATE_NIGHT,1.0,smoothstep(-0.08,0.3,sun.y))
	var slate: Vector3 = PlaneWeather.SLATE_DOWN*day
	var c := env.fog_light_color.lerp(Color(slate.x,slate.y,slate.z),k)
	env.fog_light_color = c.lerp(MURK_COLOUR*lerpf(1.0,0.6,1.0-day),smoothstep(0.0,0.6,m))
	var mm := smoothstep(0.0,0.5,m)
	env.fog_depth_begin = lerpf(haze.x,MURK_HAZE.x,mm)
	env.fog_depth_end = lerpf(haze.y,MURK_HAZE.y,mm)

## The plane's air: the storm's (PlaneWeather `air_at`) near the cell or in
## the murk, still air else (the field's calm gusts are not the heist's).
func air(p: Vector3) -> Dictionary:
	if elements == null: return {}
	var plane: RefCounted = host.get("plane")
	var here: Dictionary = elements.air_at(p,plane.forward() if plane != null else Vector3.FORWARD)
	var k := clampf(maxf(float(elements.cells.storm_at(p))*1.5,float(elements.murk)),0.0,1.0)
	if k <= 0.0: return {}
	if k >= 1.0: return here
	var out := here.duplicate()
	out["wind"] = (here.wind as Vector3)*k
	out["shove"] = (here.shove as Vector3)*k
	out["gust"] = float(here.gust)*k
	return out

# --- Debug keys (studies/heist_level.gd `_unhandled_input`) ---------------------

## C: a cell toward the plane now.
func key_cell() -> String:
	if not ensure(): return "No weather yet"
	send()
	return "A storm cell is coming"

## M: a whiteout now.
func key_whiteout() -> String:
	if not ensure(): return "No weather yet"
	elements.whiteout.drop()
	return "Whiteout"

## K / Shift+K: the dragon far / close now.
func key_dragon(close: bool) -> String:
	if not ensure(): return "No weather yet"
	return ("The dragon, %s" % ("close" if close else "far")) if elements.sightings.call_now("close" if close else "far") else "The dragon is already out"
