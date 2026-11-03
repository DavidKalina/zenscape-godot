## The Peak's ruined stair (docs/design/endless-flight/spec-crown.md):
## flights of the ruin kit's stair (RuinKit `_flight`) up the rock gorge to the
## saddle, the gorge's visible tell from its mouth and inside it.
##
## The path follows the gorge's line (PeakMassif `gorge`) off its middle by
## `_off`, on its floor, so the middle of the gorge and the lift's core
## (PeakRoutes) stay clear of stone.
## It is cut into flights of RUN m along the ground; each one a kit flight
## laid on the chord from its foot to its head, its steps fitted to the
## ground's rise there (about STEP m each), scaled SCALE times, its steps
## and cheeks reaching down past the ground under it. Ruined: now and then
## a flight is gone (never two running), each weathered.
##
## Each flight is placed by its handle `peak/stair/<n>` (LayoutOverrides),
## built one a frame after setup (a flight is tens of ms in GDScript), and
## raises the plane's ground over its footprint (`ground`, as the arches'
## and rocks' do in the main scene's `plane_ground`).
extends Node3D

const RuinKit = preload("res://scripts/ruin_kit.gd")
const Split = preload("res://scripts/endless/peak_split.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")

## The kit's stair this many times its walker size: a flight 2 m wide in
## the kit is 16 m here, its cheek courses 3.4 m, so it reads from the
## glacier.
const SCALE := 8.0
## A flight's width in the kit's metres.
const WIDTH := 2.0
## Each flight's run along the ground (m), the gap left between flights
## (a landing's worth), and the rise of a step it aims for.
const RUN := 26.0
const GAP := 5.0
const STEP := 1.7
const MOST_STEPS := 32
## How far each flight's steps reach under the lowest ground under it (m).
const SINK := 1.5
## A flight lower than this (m of rise) is not laid: level ground.
const LEAST_RISE := 2.0
## Where it starts up the gorge (share of the way from nose to saddle), which
## side of the floor it keeps (of the line's normal), and how far inside the
## floor's edge it stays (m).
const FROM_SHARE := 0.24
const SIDE := -1.0
const WALL_KEEP := 9.0
## A flight gone, one in this many (never two running).
const GONE := 4
const WEATHERED := 0.65

## The flights: {name, xf (kit frame -> world, scaled), inv, half, front,
## run, riser, tread, steps, built}.
var flights: Array = []
var _next := 0
var stats := {"flights":0, "built":0, "build_ms":0.0, "slowest_ms":0.0}

## Lays out the stair from the placed massif and the land's height
## (`ground`: world y at (x, z)); the flights are built over the next frames.
func setup(peak: RefCounted, ground: Callable, seed_value: int) -> void:
	name = "PeakStair"
	var path := _path(peak,ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"peak/stair"])
	var walked := 0.0
	var i := 0
	var n := 0
	var gone_last := false
	# Walk the path: each flight RUN m of it, GAP m between.
	var lens := PackedFloat32Array([0.0])
	for k in range(1,path.size()):
		lens.append(lens[k-1]+Vector2(path[k].x-path[k-1].x,path[k].z-path[k-1].z).length())
	var total := lens[lens.size()-1]
	while walked+RUN*0.4 <= total:
		var foot := _at(path,lens,walked)
		var head := _at(path,lens,minf(walked+RUN,total))
		var last := walked+RUN+GAP+RUN*0.4 > total
		walked += RUN+GAP
		# The last flight (up to the notch) always stands.
		var gone := not gone_last and not last and rng.randi()%GONE == 0 and n > 0
		gone_last = gone
		var spec := _flight_spec(foot,head,ground)
		if spec.is_empty(): continue
		n += 1
		if gone: continue
		spec.name = "peak/stair/%d" % i
		spec.seed = rng.randi()
		i += 1
		flights.append(spec)
	stats.flights = flights.size()

## The stair's path on the ground: world points, about 2 m apart.
func _path(peak: RefCounted, ground: Callable) -> Array:
	var g: Dictionary = peak.gorge(Split.ROCK)
	var line: Array = g.line
	var half: PackedFloat32Array = g.half
	var normal: Array = g.side
	var last: int = g.saddle
	var out: Array = []
	var stair_half := WIDTH*0.5*SCALE+RuinKit.CHEEK.x*SCALE
	for k in range(int(FROM_SHARE*last),last):
		var p0 := _off(line[k],normal[k],half[k],stair_half)
		var p1 := _off(line[k+1],normal[k+1],half[k+1],stair_half)
		var steps := int(ceil(p0.distance_to(p1)/2.0))
		for q in steps:
			var w := p0.lerp(p1,float(q)/steps)
			out.append(Vector3(w.x,float(ground.call(w.x,w.y)),w.y))
	return out

## The gorge's point `p` moved off its middle: to SIDE, short of the wall's foot.
func _off(p: Vector3, normal: Vector2, half: float, stair_half: float) -> Vector2:
	return Vector2(p.x,p.z)+normal*SIDE*maxf(0.0,half-WALL_KEEP-stair_half)

## The path's point `d` m along it.
static func _at(path: Array, lens: PackedFloat32Array, d: float) -> Vector3:
	var k := lens.bsearch(d)
	if k <= 0: return path[0]
	if k >= path.size(): return path[path.size()-1]
	var t := (d-lens[k-1])/maxf(lens[k]-lens[k-1],0.001)
	return (path[k-1] as Vector3).lerp(path[k],t)

## One flight on the chord from `foot` to `head` (world, on the ground):
## its frame, steps fitted to the rise, how far it reaches down. Empty on
## level ground.
func _flight_spec(foot: Vector3, head: Vector3, ground: Callable) -> Dictionary:
	var rise := head.y-foot.y
	if rise < LEAST_RISE: return {}
	var flat := Vector2(head.x-foot.x,head.z-foot.z)
	var run := flat.length()
	var steps := clampi(int(round(rise/STEP)),3,MOST_STEPS)
	var tread := run/steps/SCALE
	var riser := rise/steps/SCALE
	# Its frame: the kit's flight climbs toward -Z from its foot at +Z, its
	# run centred on the pose; the pose at the foot's height.
	var back := Vector3(-flat.x,0.0,-flat.y).normalized()
	var basis := Basis(Vector3.UP.cross(back).normalized(),Vector3.UP,back).scaled_local(Vector3.ONE*SCALE)
	var mid := Vector3((foot.x+head.x)*0.5,foot.y,(foot.z+head.z)*0.5)
	var xf := Transform3D(basis,mid)
	# How far its steps and cheeks reach under the pose (every step and
	# cheek stands from there): past the lowest ground under the flight's
	# width along it.
	var half := WIDTH*0.5+RuinKit.CHEEK.x
	var low := 0.0
	for k in 9:
		var z := (run*0.5-run*k/8.0)/SCALE
		for x: float in [-half,0.0,half]:
			var w := xf*Vector3(x,0.0,z)
			low = minf(low,float(ground.call(w.x,w.z))-foot.y)
	var foot_kit := (-low+SINK)/SCALE
	return {"xf":xf,"inv":xf.affine_inverse(),"half":half,"front":run*0.5/SCALE,"run":run/SCALE,
		"riser":riser,"tread":tread,"steps":steps,"foot":foot_kit,"built":false}

func _process(_delta: float) -> void:
	if _next >= flights.size():
		set_process(false)
		return
	var t0 := Time.get_ticks_usec()
	_build(flights[_next])
	_next += 1
	var ms := (Time.get_ticks_usec()-t0)/1000.0
	stats.build_ms = float(stats.build_ms)+ms
	stats.slowest_ms = maxf(float(stats.slowest_ms),ms)

## Builds a flight's stone: the kit's flight and rubble, placed by its handle.
func _build(f: Dictionary) -> void:
	var b := RuinKit.Build.new(int(f.seed),WEATHERED,"Flight")
	RuinKit._flight(b,Transform3D.IDENTITY,int(f.steps),WIDTH,float(f.tread),float(f.foot),float(f.riser),float(f.tread))
	RuinKit._rubble(b,WIDTH*0.5+1.0,int(round(WEATHERED*b.rng.randf_range(2.0,5.0))))
	var node := b.finish()
	var coded: Transform3D = f.xf
	var xf := LayoutOverrides.xform(String(f.name),coded)
	node.name = String(f.name).replace("/","_")
	node.transform = xf
	for body in node.find_children("*","StaticBody3D",true,false):
		(body as StaticBody3D).collision_layer = 1
		(body as StaticBody3D).collision_mask = 0
	add_child(node)
	LayoutOverrides.track(String(f.name),node,"piece",coded)
	if not xf.is_equal_approx(coded):
		f.xf = xf
		f.inv = xf.affine_inverse()
	f.built = true
	GroundNative.bump(GroundNative.PART_STAIR)
	stats.built = int(stats.built)+1

## The plane's ground at `p` with the stair standing on `h` (world y): over a
## flight's footprint, grown by `pad` m, no lower than its cheeks' coping
## (the ramp over its steps, level by the landing). A span's underside (a
## Vector2 `h`) is passed on.
func ground(p: Vector3, h: Variant, pad := 0.0) -> Variant:
	if not h is float: return h
	var out: float = h
	for f: Dictionary in flights:
		if not bool(f.built): continue
		var l: Vector3 = (f.inv as Transform3D)*p
		var pk := pad/SCALE
		if absf(l.x) > float(f.half)+pk: continue
		var front: float = f.front
		var run: float = f.run
		if l.z > front+pk or l.z < front-run-pk: continue
		var riser: float = f.riser
		var tread: float = f.tread
		var steps: int = f.steps
		var head_z := front-(steps-1)*tread
		var top := (riser+RuinKit.CHEEK.y+maxf(0.0,front-l.z)*riser/tread) if l.z > head_z else steps*riser+RuinKit.CHEEK.y
		top = minf(top,steps*riser+RuinKit.CHEEK.y)
		var y := (f.xf as Transform3D).origin.y+top*SCALE
		if y > out: out = y
	return out
