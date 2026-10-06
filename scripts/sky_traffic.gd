extends Node
## Other planes in the sky (scripts/sky_islands.gd): a few little biplanes
## like the wanderer's own (scripts/plane_figure.gd), each in its own
## livery, touring the islands on the jet streams' loops (scripts/
## sky_currents.gd) so the sky is lived in before anyone has been helped.
##
## Each keeps to a lane over its loop's core, up by LANE_UP metres and a
## little to one side, weaving slowly about it, so the wanderer riding the
## core passes them rather than flying through them. Ahead of each, the
## ground (SkyIslands `ground`: islands, islets, peaks) is read, and the
## plane climbs to keep CLEAR metres over it, settling back once past. They cruise slower than a jet
## carries the wanderer (SPEED), so a ride down a stream overtakes them.
## They bank into the loop's turns and pitch with its rises, as the
## wanderer's plane is drawn. No collisions and no landing: ambience only.
##
## Each plane is a PlaneFigure driven by a `Flight` that answers what the
## figure asks of a glide. The loops are in the currents' frame; when the
## currents move (a claim's swap) the planes move with them, scarves too.
## Shown only while flying (SkyIslands `show_air`); --no-traffic leaves the
## sky empty.

const PlaneFigure = preload("res://scripts/plane_figure.gd")

## Planes per loop, spread evenly round it.
const PER_LOOP := 2
## Cruise speeds (m/s), lowest and highest: under the jets' 26.
const SPEED := Vector2(12.0,16.0)
## How far over the loop's core a lane runs (m), lowest and highest, and
## how far to the side; and how far and how slowly the weave strays.
const LANE_UP := Vector2(6.0,10.0)
const LANE := Vector2(1.0,5.0)
const WEAVE := 2.0
const WEAVE_RATE := 0.07
## Each loop is resampled every STEP metres and smoothed SMOOTHING times,
## so the lanes round its corners instead of kinking at them.
const STEP := 2.0
const SMOOTHING := 24
## The ground read ahead (m), the height kept over it (m), and how quickly
## a plane climbs to it and settles back (seconds).
const AHEAD := [0.0,20.0,40.0,65.0]
const CLEAR := 14.0
const CLIMB := 0.7
const SETTLE := 3.5
## Bank per radian a second of turn, the most it banks, and how quickly the
## bank and the pitch follow the path (seconds).
const BANK := 1.6
const BANK_MAX := 0.7
const EASE := 0.6
## Metres ahead and behind sampled for the heading.
const LOOK := 6.0
## The liveries, muted to sit with the land: never the wanderer's own
## brown, cream and terracotta.
const LIVERIES := [
	{"body":Color("5f7f96"),"dark":Color("3e4f5c"),"trim":Color("e8d9a8"),"wing":Color("eef0ea"),"scarf":Color("e2b84a")},
	{"body":Color("6f8a5b"),"dark":Color("44543a"),"trim":Color("d98e4a"),"wing":Color("f0ead8"),"scarf":Color("cf6b4a")},
	{"body":Color("c9a24a"),"dark":Color("6d5530"),"trim":Color("8a4f3a"),"wing":Color("f3ecd9"),"scarf":Color("6f8fa8")},
	{"body":Color("8a5f78"),"dark":Color("4f3746"),"trim":Color("e6c48f"),"wing":Color("efe8e0"),"scarf":Color("7fa08a")},
]

## What a PlaneFigure reads of a glide (scripts/sky_glide.gd, sky_plane.gd).
class Flight extends RefCounted:
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var heading := 0.0
	var pitch := 0.0
	var bank := 0.0
	var spin := 0.0
	var speed := 0.0
	var engine := 1.0
	func forward() -> Vector3:
		return Vector3(-sin(heading)*cos(pitch),sin(pitch),-cos(heading)*cos(pitch))

## The height under a global point, or null over open air (SkyIslands
## `ground`); unset, the lanes keep to the loops.
var ground := Callable()
## Each plane: {figure, flight, loop, at (m along), speed, lane, up, phase,
## lift (m climbed over the ground ahead)}.
var planes := []
## Each loop: {points, lengths (m along at each point), length}.
var _loops := []
var _currents: Node3D
var _origin := Vector3.ZERO
var _shown := false
var _clock := 0.0

static func enabled() -> bool:
	return not "--no-traffic" in OS.get_cmdline_user_args()

## Lays out the planes on the closed jets of `currents` (built), placed
## where they are now; hidden till `show`.
func build(currents: Node3D) -> void:
	name = "SkyTraffic"
	clear()
	_currents = currents
	_origin = _frame()
	for current: Dictionary in currents.currents:
		if current.kind != "jet" or not current.closed: continue
		_loops.append(_measure(_smooth(current.points)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7151
	var n := 0
	for l in range(_loops.size()):
		for k in range(PER_LOOP):
			var figure := PlaneFigure.new(LIVERIES[n%LIVERIES.size()])
			figure.name = "Traffic%d" % n
			figure.visible = _shown
			add_child(figure)
			var plane := {"figure":figure,"flight":Flight.new(),"loop":l,
				"at":_loops[l].length*(float(k)+rng.randf_range(0.0,0.4))/PER_LOOP,
				"speed":rng.randf_range(SPEED.x,SPEED.y),
				"lane":rng.randf_range(LANE.x,LANE.y)*(1.0 if rng.randf() < 0.5 else -1.0),
				"up":rng.randf_range(LANE_UP.x,LANE_UP.y),"phase":rng.randf()*TAU,"lift":0.0}
			planes.append(plane)
			_place(plane,0.0)
			figure.reset(plane.flight)
			n += 1

func clear() -> void:
	for plane: Dictionary in planes: plane.figure.queue_free()
	planes.clear()
	_loops.clear()

## Shows or hides every plane (while flying, or not).
func show(on: bool) -> void:
	_shown = on
	for plane: Dictionary in planes: plane.figure.visible = on

func _process(delta: float) -> void:
	if not _shown or planes.is_empty() or _currents == null: return
	# The currents moved (a claim's swap): the planes, scarves too, go with.
	var origin := _frame()
	if origin != _origin:
		var by := origin-_origin
		_origin = origin
		for plane: Dictionary in planes:
			plane.flight.position += by
			plane.figure.shift(by)
	_clock += delta
	for plane: Dictionary in planes: _place(plane,delta)

## Steps a plane `delta` seconds along its lane and draws it.
func _place(plane: Dictionary, delta: float) -> void:
	var loop: Dictionary = _loops[plane.loop]
	plane.at = fmod(float(plane.at)+float(plane.speed)*delta,loop.length)
	var flight: Flight = plane.flight
	var ahead := _lane(plane,float(plane.at)+LOOK)
	var behind := _lane(plane,float(plane.at)-LOOK)
	var dir := (ahead-behind).normalized()
	var heading := atan2(-dir.x,-dir.z)
	var pitch := asin(clampf(dir.y,-1.0,1.0))
	_climb(plane,delta)
	var at := _lane(plane,float(plane.at))
	if delta > 0.0:
		var k := 1.0-exp(-delta/EASE)
		var turn := angle_difference(flight.heading,heading)/delta
		flight.bank = lerpf(flight.bank,clampf(-turn*BANK,-BANK_MAX,BANK_MAX),k)
		flight.pitch = lerpf(flight.pitch,pitch,k)
		flight.velocity = (at-flight.position)/delta
	else:
		flight.pitch = pitch
		flight.velocity = dir*float(plane.speed)
	flight.heading = heading
	flight.position = at
	flight.speed = float(plane.speed)
	plane.figure.update(delta,flight,0.0,Callable(),false)

## Eases a plane's lift towards CLEAR over the highest ground ahead.
func _climb(plane: Dictionary, delta: float) -> void:
	if not ground.is_valid() or delta <= 0.0: return
	var need := 0.0
	var along := float(plane.at)
	for ahead: float in AHEAD:
		var p := _lane(plane,along+ahead,false)
		var under: Variant = ground.call(p)
		if under != null: need = maxf(need,float(under)+CLEAR-p.y)
	var lift := float(plane.lift)
	plane.lift = lerpf(lift,need,1.0-exp(-delta/(CLIMB if need > lift else SETTLE)))

## Where the currents' frame stands, global.
func _frame() -> Vector3:
	return _currents.global_position if _currents.is_inside_tree() else _currents.position

## A plane's lane at `along` metres round its loop, global: the core's
## point, up and out to its side, weaving slowly, and lifted over the ground.
func _lane(plane: Dictionary, along: float, lifted := true) -> Vector3:
	var loop: Dictionary = _loops[plane.loop]
	var core := _point(loop,along)
	var dir := _point(loop,along+LOOK)-_point(loop,along-LOOK)
	var side := Vector3(-dir.z,0.0,dir.x).normalized()
	var t := _clock*WEAVE_RATE*TAU+float(plane.phase)
	var out := float(plane.lane)+sin(t)*WEAVE
	var up := float(plane.up)+sin(t*1.3+1.1)*WEAVE*0.5
	if lifted: up += float(plane.lift)
	return _origin+core+side*out+Vector3.UP*up

## A loop's point `along` metres round it (wrapping), in the currents' frame.
static func _point(loop: Dictionary, along: float) -> Vector3:
	var length: float = loop.length
	along = fposmod(along,length)
	var lengths: PackedFloat32Array = loop.lengths
	var points: PackedVector3Array = loop.points
	var i := lengths.bsearch(along,true)-1
	i = clampi(i,0,points.size()-1)
	var span := (lengths[i+1] if i+1 < lengths.size() else length)-lengths[i]
	var f := (along-lengths[i])/span if span > 0.0 else 0.0
	return points[i].lerp(points[(i+1)%points.size()],f)

## The loop resampled every STEP metres and smoothed.
static func _smooth(points: PackedVector3Array) -> PackedVector3Array:
	var loop := _measure(points)
	var count := maxi(int(float(loop.length)/STEP),8)
	var even := PackedVector3Array()
	for i in range(count): even.append(_point(loop,float(loop.length)*i/count))
	for pass_ in range(SMOOTHING):
		var next := PackedVector3Array()
		next.resize(count)
		for i in range(count): next[i] = (even[(i-1+count)%count]+even[i]*2.0+even[(i+1)%count])*0.25
		even = next
	return even

static func _measure(points: PackedVector3Array) -> Dictionary:
	var lengths := PackedFloat32Array()
	var length := 0.0
	for i in range(points.size()):
		lengths.append(length)
		length += points[i].distance_to(points[(i+1)%points.size()])
	return {"points":points,"lengths":lengths,"length":length}
