extends SceneTree
## The plane's landing and takeoff (scripts/plane_landing.gd) and its strip
## (scripts/plane_strip.gd), as maths, headless:
##   - on real islands the strip is a long, flat, clear run; it keeps off
##     trees, water and the shore, lands into the wind, takes the flat way
##     along a ridge, and on a tiny or drowned island falls back to a short
##     hop on land, never refusing;
##   - the landing goes line-up, descent, flare, touchdown, rollout, beat,
##     hop-out, done, in 4 to 10 s, from ahead, beside, over the island,
##     far off and high up; it never goes into the ground, touches down on
##     the strip lined up with it, and stops on it, sat on its wheels;
##   - called off in the line-up, descent or flare it flies on and climbs
##     away, never into the ground; after the touch it can't be, but F skips
##     to the hop;
##   - parked, its wheels and tail skid stand on the ground, level or on a
##     slope;
##   - it takes off along its run, and off the shore.
const PlaneStrip = preload("res://scripts/plane_strip.gd")
const PlaneLanding = preload("res://scripts/plane_landing.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const Genesis = preload("res://scripts/genesis_canvas.gd")
const DT := 1.0/60.0
## The flat test island: a 24 m half square with its ground at GROUND,
## rock down to -10 m, at the origin.
const HALF := 24.0
const GROUND := 2.0
var failures := 0

func _initialize() -> void:
	_islands()
	_trees_and_water()
	_wind()
	_ridge()
	_tiny()
	_sequence()
	_cancel()
	_skip()
	_hop_landing()
	_rest()
	_takeoff()
	print("PASS: plane landing" if failures == 0 else "FAIL: plane landing (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

# --- Strips --------------------------------------------------------------------------

func plate() -> NativeTerrainData:
	var data := NativeTerrainData.new()
	data.setup(preload("res://scripts/plate_mesh.gd").build())
	return data

func land_map(data: NativeTerrainData, wet := Callable(), blockers := PackedVector3Array()) -> Dictionary:
	var height := func(p: Vector2) -> Variant: return data.ground_height(p) if data.has_land(p) else null
	var dry := wet if wet.is_valid() else func(_p: Vector2) -> bool: return false
	return PlaneStrip.survey(data.land_rect(),height,dry,blockers)

## Every cell between a strip's ends is clear, and the ground along it
## climbs no steeper than GRADE.
func clean(map: Dictionary, strip: Dictionary) -> bool:
	var a: Vector2 = strip.touch
	var b: Vector2 = strip.end
	var n := maxi(2,int(a.distance_to(b)/0.25))
	var last := NAN
	for i in range(n+1):
		var p := a.lerp(b,float(i)/n)
		if PlaneStrip.state_at(map,p) != PlaneStrip.CLEAR: return false
		var h := PlaneStrip.height_at(map,p)
		if not is_nan(last) and absf(h-last) > PlaneStrip.GRADE*0.5+0.02: return false
		last = h
	return true

func _islands() -> void:
	for chunk_seed in [77,5,1234,31337]:
		var data := plate()
		Genesis.shape(data,chunk_seed)
		var map := land_map(data)
		var began := Time.get_ticks_usec()
		var strip := PlaneStrip.pick(map)
		var ms := (Time.get_ticks_usec()-began)/1000.0
		check(not bool(strip.fallback) and float(strip.length) >= PlaneStrip.MIN_RUN-PlaneStrip.TOUCH_IN-PlaneStrip.END_IN,"Island %d: a strip %.1f m long (%.0f ms to pick)" % [chunk_seed,strip.length,ms])
		check(clean(map,strip),"Island %d: clear and gentle all along" % chunk_seed)
		check(data.has_land(strip.touch) and data.has_land(strip.end),"Island %d: both ends on the land" % chunk_seed)
		check(float(strip.bump) < 0.6,"Island %d: barely a bump (%.2f m)" % [chunk_seed,strip.bump])

## A flat square with a row of trees across its middle and a pond: the
## strip keeps its wings clear of both.
func _trees_and_water() -> void:
	var data := plate()
	data.set_outline(PackedByteArray())
	var trees := PackedVector3Array()
	for z in range(-12,13,3): trees.append(Vector3(0.0,z,1.0))
	var pond := func(p: Vector2) -> bool: return p.distance_to(Vector2(7.0,0.0)) < 4.0
	var map := land_map(data,pond,trees)
	var strip := PlaneStrip.pick(map)
	var nearest := INF
	var a: Vector2 = strip.touch
	var b: Vector2 = strip.end
	for i in range(41):
		var p := a.lerp(b,i/40.0)
		for t in trees: nearest = minf(nearest,p.distance_to(Vector2(t.x,t.y))-t.z)
	var wet := false
	for i in range(41):
		if pond.call(a.lerp(b,i/40.0)): wet = true
	check(nearest >= PlaneStrip.HALF_SPAN-0.3,"The wings pass the trees (%.2f m from the nearest trunk's edge)" % nearest)
	check(not wet,"No wheel in the pond")
	check(float(strip.length) > 10.0,"And there is still a long run (%.1f m)" % strip.length)

## A round flat island: the strip runs into the wind.
func _wind() -> void:
	var data := plate()
	data.set_outline(disc(data,Vector2.ZERO,16.0))
	var map := land_map(data)
	for wind: Vector2 in [Vector2(1.0,0.0),Vector2(0.0,-1.0),Vector2(-0.7,0.7)]:
		var strip := PlaneStrip.pick(map,wind)
		var into: float = (strip.dir as Vector2).dot(-wind.normalized())
		check(into > 0.9,"Wind %s: it lands into it (%.2f)" % [str(wind),into])

## A ridge across the island: along it is flat, across it too steep to
## roll down; the strip runs along.
func _ridge() -> void:
	var height := func(p: Vector2) -> Variant:
		if absf(p.x) > 20.0 or absf(p.y) > 20.0: return null
		return 3.0-0.3*absf(p.y)
	var map := PlaneStrip.survey(Rect2(-20,-20,40,40),height,func(_p: Vector2) -> bool: return false,PackedVector3Array())
	var strip := PlaneStrip.pick(map)
	check(absf((strip.dir as Vector2).x) > 0.9,"On a ridge it runs along the crest (dir %s)" % str(strip.dir))
	check(clean(map,strip),"And the run is gentle all along")

## A disc of `radius` m round `at` is land.
static func disc(data: NativeTerrainData, at: Vector2, radius: float) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(data._face_center.size())
	for f in range(mask.size()):
		mask[f] = 0 if (data._face_center[f] as Vector2).distance_to(at) <= radius else 1
	return mask

## A tiny island, and one drowned: a short hop on the land, never nothing.
func _tiny() -> void:
	var data := plate()
	data.set_outline(disc(data,Vector2(6.0,-4.0),2.6))
	var map := land_map(data)
	var strip := PlaneStrip.pick(map)
	check(bool(strip.hop),"A tiny island gets a short hop (%.1f m)" % strip.length)
	check(data.has_land(strip.touch) and data.has_land(strip.end),"On its land")
	var drowned := land_map(data,func(_p: Vector2) -> bool: return true)
	var wet := PlaneStrip.pick(drowned)
	check(not wet.is_empty() and bool(wet.fallback) and data.has_land((wet.touch as Vector2).lerp(wet.end,0.5)),"All water: it still comes down on the land")

# --- The landing --------------------------------------------------------------------

func top(p: Vector3) -> Variant:
	if absf(p.x) >= HALF or absf(p.z) >= HALF: return null
	return Vector2(GROUND,-10.0)

func ground(p: Vector2) -> float:
	if absf(p.x) >= HALF or absf(p.y) >= HALF: return NAN
	return GROUND

func flat_strip() -> Dictionary:
	var map := PlaneStrip.survey(Rect2(-HALF,-HALF,HALF*2.0,HALF*2.0),func(p: Vector2) -> Variant: return GROUND if absf(p.x) < HALF and absf(p.y) < HALF else null,func(_p: Vector2) -> bool: return false,PackedVector3Array([Vector3(0.0,0.0,3.0)]))
	var strip := PlaneStrip.pick(map,Vector2(0.0,1.0))
	return globalise(strip)

func globalise(strip: Dictionary) -> Dictionary:
	var out := strip.duplicate()
	var t: Vector2 = strip.touch
	var e: Vector2 = strip.end
	var d: Vector2 = strip.dir
	out.touch = Vector3(t.x,GROUND,t.y)
	out.end = Vector3(e.x,GROUND,e.y)
	out.dir = Vector3(d.x,0.0,d.y)
	return out

func flying_from(at: Vector3, heading: float) -> SkyPlane:
	var plane := SkyPlane.new()
	plane.launch(at,heading,14.0,false)
	return plane

## Runs a landing to the end: the phases in order, seconds, the lowest it
## came over the ground before the touch, where it touched and stopped.
func run(plane: SkyPlane, strip: Dictionary) -> Dictionary:
	var seq := PlaneLanding.new()
	seq.land(plane,strip,top,ground)
	var phases := [seq.phase]
	var lowest := INF
	var touch := Vector3.INF
	var touch_heading := 0.0
	var finite := true
	while not seq.done() and seq.elapsed < 40.0:
		seq.step(DT)
		if phases[-1] != seq.phase: phases.append(seq.phase)
		var p := plane.position
		finite = finite and is_finite(p.x) and is_finite(p.y) and is_finite(p.z)
		var under: Variant = top(p)
		if under != null and seq.phase in [PlaneLanding.LINE_UP,PlaneLanding.DESCENT,PlaneLanding.FLARE]:
			lowest = minf(lowest,p.y-(GROUND+PlaneStrip.contact(plane.pitch)))
		if seq.touched:
			touch = p
			touch_heading = plane.heading
	return {"seq":seq,"phases":phases,"lowest":lowest,"touch":touch,"heading":touch_heading,"finite":finite,"seconds":seq.elapsed,"planned":seq.planned_time()}

func _sequence() -> void:
	var strip := flat_strip()
	var touch: Vector3 = strip.touch
	var dir: Vector3 = strip.dir
	var line := atan2(-dir.x,-dir.z)
	var starts := {
		"ahead of the strip":[touch-dir*70.0+Vector3.UP*14.0,line],
		"beside it":[touch-dir*10.0+Vector3(dir.z,0.0,-dir.x)*60.0+Vector3.UP*12.0,line+PI*0.5],
		"over the island, going the wrong way":[Vector3(0.0,GROUND+8.0,0.0),line+PI],
		"far off":[Vector3(150.0,30.0,40.0),PI*0.5],
		"high up":[touch-dir*60.0+Vector3.UP*60.0,line+0.6],
		"low beside it":[touch+Vector3(dir.z,0.0,-dir.x)*80.0+Vector3.UP*-6.0,line-PI*0.5],
	}
	var order := [PlaneLanding.LINE_UP,PlaneLanding.DESCENT,PlaneLanding.FLARE,PlaneLanding.TOUCHDOWN,PlaneLanding.ROLLOUT,PlaneLanding.BEAT,PlaneLanding.HOP_OUT,PlaneLanding.DONE]
	for label: String in starts:
		var plane := flying_from(starts[label][0],starts[label][1])
		var out := run(plane,strip)
		var seq: RefCounted = out.seq
		var names := (out.phases as Array).map(func(p: int) -> String: return PlaneLanding.NAMES[p])
		check(out.phases == order,"From %s: %s" % [label," > ".join(names)])
		# From far off the way there takes its time, hurried as it is.
		var most := 12.0 if label == "far off" else 9.5
		check(out.seconds > 4.0 and out.seconds < most,"From %s: %.1f s from F to the hop out (%.1f s in the air)" % [label,out.seconds,out.planned])
		check(out.finite and out.lowest > -0.05,"From %s: never into the ground (lowest %.2f m over it)" % [label,out.lowest])
		var at: Vector3 = out.touch
		var off := Vector2(at.x-touch.x,at.z-touch.z)
		check(off.length() < 0.6 and absf(angle_difference(out.heading,line)) < 0.08,"From %s: it touches on the strip, lined up (%.2f m, %.3f rad off)" % [label,off.length(),absf(angle_difference(out.heading,line))])
		var along := Vector2(plane.position.x-touch.x,plane.position.z-touch.z).dot(Vector2(dir.x,dir.z))
		var rest: Vector4 = seq.rest()
		check(along > 1.0 and along <= float(strip.length)+0.05 and plane.speed == 0.0,"From %s: it stops on the strip (%.1f m along, of %.1f)" % [label,along,strip.length])
		check(absf(plane.position.y-rest.x) < 0.01 and absf(rest.w-GROUND) < 0.01,"From %s: sat on its wheels on the ground" % label)

func _cancel() -> void:
	var strip := flat_strip()
	var touch: Vector3 = strip.touch
	var dir: Vector3 = strip.dir
	for phase in [PlaneLanding.LINE_UP,PlaneLanding.DESCENT,PlaneLanding.FLARE]:
		var plane := flying_from(touch-dir*70.0+Vector3.UP*14.0,atan2(-dir.x,-dir.z))
		var seq := PlaneLanding.new()
		seq.land(plane,strip,top,ground)
		while seq.phase != phase and not seq.done(): seq.step(DT)
		seq.step(DT)
		var ok: bool = seq.cancel()
		check(ok and seq.done(),"Called off in the %s, it gives the plane back" % PlaneLanding.NAMES[phase])
		var lowest := INF
		var slowest := INF
		var start_y := plane.position.y
		for i in range(int(4.0/DT)):
			plane.step(DT,{},top)
			var under: Variant = top(plane.position)
			if under != null: lowest = minf(lowest,plane.position.y-GROUND)
			slowest = minf(slowest,plane.speed)
		check(lowest >= SkyPlane.SKIM-0.001,"And flies on, never into the ground (lowest %.2f m)" % lowest)
		check(slowest >= SkyPlane.SLOW-0.001 and plane.position.y > start_y,"Climbing away under power (%.1f m/s at least, %.1f m up)" % [slowest,plane.position.y-start_y])
	var plane := flying_from(touch-dir*70.0+Vector3.UP*14.0,atan2(-dir.x,-dir.z))
	var seq := PlaneLanding.new()
	seq.land(plane,strip,top,ground)
	while not seq.on_ground(): seq.step(DT)
	check(not seq.cancel() and not seq.done(),"Once the wheels touch it can't be called off")

func _skip() -> void:
	var strip := flat_strip()
	var touch: Vector3 = strip.touch
	var dir: Vector3 = strip.dir
	var plane := flying_from(touch-dir*70.0+Vector3.UP*14.0,atan2(-dir.x,-dir.z))
	var seq := PlaneLanding.new()
	seq.land(plane,strip,top,ground)
	while seq.phase != PlaneLanding.ROLLOUT: seq.step(DT)
	seq.skip()
	check(seq.phase == PlaneLanding.HOP_OUT and plane.speed == 0.0,"Rolling out, F hops out at once, stopped where it is")

## A short hop onto a tiny island: down and stopped on its land.
func _hop_landing() -> void:
	var small := func(p: Vector3) -> Variant: return Vector2(GROUND,-6.0) if Vector2(p.x,p.z).length() < 2.6 else null
	var floor_small := func(p: Vector2) -> float: return GROUND if p.length() < 2.6 else NAN
	var map := PlaneStrip.survey(Rect2(-3,-3,6,6),func(p: Vector2) -> Variant: return GROUND if p.length() < 2.6 else null,func(_p: Vector2) -> bool: return false,PackedVector3Array())
	var strip := globalise(PlaneStrip.pick(map))
	var plane := flying_from(Vector3(-60.0,12.0,10.0),-PI*0.5)
	var seq := PlaneLanding.new()
	seq.land(plane,strip,small,floor_small)
	while not seq.done() and seq.elapsed < 40.0: seq.step(DT)
	check(seq.done() and Vector2(plane.position.x,plane.position.z).length() < 2.6,"A short hop onto a tiny island stops on it (%.1f m from its middle, %.1f s)" % [Vector2(plane.position.x,plane.position.z).length(),seq.elapsed])

# --- Parked and taking off ---------------------------------------------------------

## The figure's wheel bottoms and tail skid, global, posed parked.
func contacts(figure: Node3D) -> Array:
	var t := figure.transform
	return [t*Vector3(-PlaneStrip.WHEEL_GAUGE,-PlaneStrip.WHEEL_DROP,-PlaneStrip.WHEEL),t*Vector3(PlaneStrip.WHEEL_GAUGE,-PlaneStrip.WHEEL_DROP,-PlaneStrip.WHEEL),t*Vector3(0.0,-0.12,PlaneStrip.TAIL)]

func _rest() -> void:
	var figure: Node3D = PlaneFigure.new()
	root.add_child(figure)
	for case: Array in [["level",func(_p: Vector2) -> float: return 2.0],["up a slope",func(p: Vector2) -> float: return 2.0-0.15*p.y],["across a slope",func(p: Vector2) -> float: return 2.0+0.1*p.x]]:
		var height: Callable = case[1]
		for heading in [0.0,1.1]:
			var at := Vector2(3.0,-2.0)
			var r := PlaneStrip.rest(height,at,heading)
			figure.park(PlaneFigure.pose(Vector3(at.x,r.x,at.y),heading,r.y,r.z))
			var worst := 0.0
			for c: Vector3 in contacts(figure): worst = maxf(worst,absf(c.y-float(height.call(Vector2(c.x,c.z)))))
			check(worst < 0.04,"Parked %s (heading %.1f), wheels and skid on the ground (%.3f m off at worst)" % [case[0],heading,worst])
	check(not figure._pilot[0].visible and not figure._blur.visible,"Parked, the pilot is out and the propeller still")
	figure.free()

func _takeoff() -> void:
	var map := PlaneStrip.survey(Rect2(-HALF,-HALF,HALF*2.0,HALF*2.0),func(p: Vector2) -> Variant: return GROUND if absf(p.x) < HALF and absf(p.y) < HALF else null,func(_p: Vector2) -> bool: return false,PackedVector3Array([Vector3(0.0,-6.0,2.0)]))
	for case: Array in [["on the land",Vector2(0.0,0.0),0.0],["by the shore",Vector2(HALF-3.0,0.0),PI*0.5]]:
		var at: Vector2 = case[1]
		var heading: float = case[2]
		var run := PlaneStrip.takeoff(map,at,Vector2(-sin(heading),-cos(heading)))
		var r := PlaneStrip.rest(func(_p: Vector2) -> float: return GROUND,at,heading)
		var plane := SkyPlane.new()
		plane.launch(Vector3(at.x,r.x,at.y),heading,0.0,false)
		plane.pitch = r.y
		var dir: Vector2 = run.dir
		var seq := PlaneLanding.new()
		seq.take_off(plane,{"dir":Vector3(dir.x,0.0,dir.y),"length":run.length,"edge":run.edge},ground)
		var phases := [seq.phase]
		var lowest := INF
		while not seq.done() and seq.elapsed < 20.0:
			seq.step(DT)
			if phases[-1] != seq.phase: phases.append(seq.phase)
			if not is_nan(ground(Vector2(plane.position.x,plane.position.z))): lowest = minf(lowest,plane.position.y-GROUND-PlaneStrip.contact(plane.pitch))
		var names := phases.map(func(p: int) -> String: return PlaneLanding.NAMES[p])
		check(seq.done() and phases[0] == PlaneLanding.BOARD and PlaneLanding.ROLL in phases,"Taking off %s: %s in %.1f s" % [case[0]," > ".join(names),seq.elapsed])
		check(lowest > -0.02,"Its wheels never sink into the ground (%.3f m)" % lowest)
		check(absf(angle_difference(plane.heading,atan2(-dir.x,-dir.y))) < 0.05,"It turned to its run first")
		var start_y := plane.position.y
		for i in range(int(3.0/DT)): plane.step(DT,{},top)
		check(plane.speed >= SkyPlane.SLOW and plane.position.y >= start_y-1.0 and (top(plane.position) == null or plane.position.y > GROUND+SkyPlane.SKIM),"And flies on (%.1f m/s, %.1f m from where it left the ground)" % [plane.speed,plane.position.y-start_y])
	var edge := PlaneStrip.takeoff(map,Vector2(HALF-3.0,10.0),Vector2(1.0,0.0))
	check(bool(edge.edge) or float(edge.length) >= PlaneStrip.LIFT_RUN,"By the shore a run off the edge will do (%s)" % str(edge))
