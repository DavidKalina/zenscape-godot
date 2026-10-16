extends RefCounted
## One approach in the landing study (studies/landing_study.gd,
## tools/landing_bench.gd): the plane (scripts/sky_plane.gd) set off at the
## station's start, flown by a person's input or the CPU's
## (scripts/landing_bot.gd) through the manual landing's rules
## (scripts/manual_landing.gd), every tick and event kept, and the numbers
## when it ends: once the plane has stopped on the land, or after
## TIME_LIMIT s without.
##
## The numbers (`metrics`): stopped or not; time to stop (s from the
## start); the first touch's and the good touch's speed (m/s along the
## ground) and sink (m/s); bounces (and why); go-arounds; the rollout (m
## from the good touch to the stop); touch-and-gos; rolls off the edge;
## Exit asked before the stop; and where it stopped (m along the field from
## its near edge, and off its middle line). Round 2's: the approach, the
## grade of the touch it stopped from (a greaser or not), metres slid, the
## peak slip (radians), power-slides, the stop's margin to the edge (m on
## the way it was going) and whether it stopped on the first approach
## (`first_try`: no go-around, nothing off the edge, no touch-and-go).

const SkyPlane = preload("res://scripts/sky_plane.gd")
const ManualLanding = preload("res://scripts/manual_landing.gd")
const Course = preload("res://scripts/landing_course.gd")

const TIME_LIMIT := 120.0
## Ticks are kept every TICK_EVERY s (the overlay's sink trace, the file).
const TICK_EVERY := 0.1
const FORMAT := 2

var station := {}
## The approach it started on (Course APPROACHES).
var approach := "normal"
var pilot := "human"
var params := {}
var plane := SkyPlane.new()
var ml := ManualLanding.new()
## Seconds flown, whether it has ended and how ("stopped", "timeout",
## "abandoned").
var t := 0.0
var done := false
var ended := ""
var started := ""
## [{t, kind, ...}] and the ticks as columns.
var events: Array[Dictionary] = []
var ticks := {"t":[],"x":[],"y":[],"z":[],"speed":[],"sink":[],"over":[],"phase":[],"slip":[],"grit":[]}
## The last tick's events (ManualLanding `step`'s), for the bot and the scene.
var last := {}
var _tick_clock := 0.0

func _init(on: Dictionary, who := "human", skill := {}, start := "normal") -> void:
	station = on
	pilot = who
	params = skill
	approach = start
	started = Time.get_datetime_string_from_system(true)+"Z"
	plane.launch(Course.start_at(on,start),0.0,Course.start_speed(start),false)
	plane.set_pace(Course.start_speed(start))
	ml.begin(plane)

## Goes on from `flying` (a SkyPlane in the air: after a takeoff or a
## pickup) rather than the station's start: the next approach, its own run.
func adopt(flying: RefCounted) -> void:
	plane = flying
	ml.begin(plane)

## The air at a point now (Course `air_at`).
func air(point: Vector3) -> Dictionary:
	return Course.air_at(point,t)

## One tick with `input` (ManualLanding `step`'s). Recorded until the run
## ends; after that the plane goes on (the exit, a takeoff) unrecorded.
func tick(delta: float, input: Dictionary) -> Dictionary:
	t += delta
	last = ml.step(delta,input,Callable(Course,"ground"),Callable(Course,"floor_at"),air)
	if done: return last
	for kind: String in ["touch","bounce","settled","thump","greaser","slide","caught","stopped","lifted","off_edge","go_around","not_yet","hit"]:
		if last.has(kind):
			var e := {"t":t,"kind":kind}
			if last[kind] is Dictionary: e.merge(last[kind])
			events.append(e)
	_tick_clock += delta
	if _tick_clock >= TICK_EVERY:
		_tick_clock = 0.0
		var land := Course.floor_at(Vector2(plane.position.x,plane.position.z))
		ticks.t.append(t)
		ticks.x.append(plane.position.x)
		ticks.y.append(plane.position.y)
		ticks.z.append(plane.position.z)
		ticks.speed.append(plane.speed)
		ticks.sink.append(-plane.velocity.y)
		ticks.over.append(null if is_nan(land) else plane.position.y-land-SkyPlane.SKIM)
		ticks.phase.append(ml.phase)
		ticks.slip.append(ml.slip)
		ticks.grit.append(ml.grit)
	if last.has("stopped"): _end("stopped")
	elif t >= TIME_LIMIT: _end("timeout")
	return last

func _end(how: String) -> void:
	done = true
	ended = how

func abandon() -> void:
	if not done: _end("abandoned")

## The live numbers, for the overlay.
func live() -> Dictionary:
	var land := Course.floor_at(Vector2(plane.position.x,plane.position.z))
	var s: Dictionary = ml.stats
	return {"t":t,"phase":ManualLanding.NAMES[ml.phase],"speed":plane.speed if ml.flying() else ml.roll_speed(),
		"sink":-float(plane.velocity.y),"over":NAN if is_nan(land) else plane.position.y-land-SkyPlane.SKIM,
		"bank":float(plane.bank),"pitch":float(plane.pitch),"bounces":int(s.bounces),"go_arounds":int(s.go_arounds),
		"last_touch":ml.last_touch,"touch_now":ml.grade_now(Callable(Course,"floor_at")),
		"touches":(s.touches as Array).size(),"slip":ml.slip,"sliding":ml.sliding,"power":ml.power,"grit":ml.grit,
		"edge":ManualLanding.edge_margin(Callable(Course,"floor_at"),Vector2(plane.position.x,plane.position.z),going())}

## The way the plane goes over the ground, or points if it is still
## (global XZ).
func going() -> Vector2:
	var v := Vector2(plane.velocity.x,plane.velocity.z)
	if v.length() > 0.3: return v.normalized()
	var h := float(plane.heading)
	return Vector2(-sin(h),-cos(h))

## The run's numbers (see the header).
func metrics() -> Dictionary:
	var s: Dictionary = ml.stats
	var touches: Array = s.touches
	var first: Dictionary = touches[0] if not touches.is_empty() else {}
	# The touch it stopped from: the last that stuck.
	var good := {}
	for touch: Dictionary in touches:
		if ManualLanding.sticks(str(touch.grade)): good = touch
	var o := Course.origin(station)
	var along := o.z-plane.position.z
	var off := plane.position.x-o.x
	return {
		"stopped":bool(s.stopped),"time_to_stop":s.time_to_stop if bool(s.stopped) else null,
		"first_touch_speed":first.get("speed"),"first_touch_sink":first.get("sink"),
		"touch_speed":good.get("speed"),"touch_sink":good.get("sink"),
		"touches":touches.size(),"bounces":int(s.bounces),"bounce_reasons":s.bounce_reasons,
		"go_arounds":int(s.go_arounds),"rollout":s.rollout if bool(s.stopped) else null,
		"touch_and_gos":int(s.touch_and_gos),"off_edge":int(s.off_edge),"early_exits":int(s.early_exits),
		"stop_along":along if bool(s.stopped) else null,"stop_off":off if bool(s.stopped) else null,
		"duration":t,"approach":approach,"grade":good.get("grade"),"greaser":good.get("grade") == "greaser",
		"greasers":int(s.greasers),"slide_distance":float(s.slide_distance),"peak_slip":float(s.peak_slip),
		"power_slides":int(s.power_slides),"stop_margin":s.stop_margin if bool(s.stopped) else null,
		"first_try":bool(s.stopped) and int(s.go_arounds) == 0 and int(s.off_edge) == 0 and int(s.touch_and_gos) == 0,
	}

## The whole run as saved (scripts/flight_log.gd `save`).
func finish() -> Dictionary:
	var m := metrics()
	for key: String in m.keys():
		if m[key] is float and is_nan(float(m[key])): m[key] = null
	var out := {"format":FORMAT,"kind":"landing","station":station.id,"station_name":station.name,"pilot":pilot,"skill":params,
		"started":started,"ended":ended,"events":events,"ticks":ticks,"metrics":m}
	return out
