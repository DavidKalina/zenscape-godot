extends SceneTree
## Headless probe of the water's feel (docs/scenic/water-flow.md "Calm,
## wind and the first surge"), on small test grids for the native kernel (when
## built) and the mirror:
##   1. a burst pours all its volume on a smoothstep: a trickle at first, the
##      most at half time (WaterFlow._poured);
##   2. a tilted pond in a shallow bowl and in a deep pit settles: how long
##      until its surface lies within 4 mm, without and with `calm`;
##   3. a stream down a slope runs as fast with `calm` as without;
##   4. the wind piles a pond up downwind, and once it drops the pond settles
##      again, with nothing lost.
##   godot --headless --path . -s res://tools/probe_water_calm.gd
var failures := []
const Mirror := preload("res://scripts/water_flow_reference.gd")
const WaterFlow := preload("res://scripts/water_flow.gd")
const N := 32
const CELL := 0.25
const DT := 1.0/60.0

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

## A kernel whose cell c stands on heights[c] (each cell its own "face").
func grid(kernel: RefCounted, params: Dictionary) -> RefCounted:
	var faces := PackedInt32Array()
	var weights := PackedFloat32Array()
	for c in range(N*N):
		faces.append_array([c,c,c])
		weights.append_array([1.0,0.0])
	kernel.configure(N,N,CELL,Vector2(-N*CELL*0.5,-N*CELL*0.5),faces,weights)
	var p := WaterFlow.PARAMS.duplicate()
	p.merge(params,true)
	kernel.set_params(p)
	return kernel

static func centre(c: int) -> Vector2:
	return Vector2(-N*CELL*0.5+(c%N+0.5)*CELL,-N*CELL*0.5+(c/N+0.5)*CELL)

static func bowl() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for c in range(N*N): out.append(0.6*centre(c).length_squared()/(3.2*3.2))
	return out

## The pond's surface over its cells deeper than 5 cm: [lowest, highest, mean
## downwind (+x) minus mean upwind].
static func surface(kernel: RefCounted, heights: PackedFloat32Array) -> Vector3:
	var depth: PackedFloat32Array = kernel.get_depth()
	var low := INF
	var high := -INF
	var sums := Vector4.ZERO
	for c in range(N*N):
		if depth[c] < 0.05: continue
		var top := heights[c]+depth[c]
		low = minf(low,top)
		high = maxf(high,top)
		if centre(c).x > 0.0: sums += Vector4(top,1,0,0)
		else: sums += Vector4(0,0,top,1)
	return Vector3(low,high,sums.x/maxf(sums.y,1.0)-sums.z/maxf(sums.w,1.0))

## A tilted pond at level 0.4 in the bowl.
func tilted(kernel: RefCounted, heights: PackedFloat32Array) -> void:
	var depth := PackedFloat32Array()
	for c in range(N*N): depth.append(maxf(0.0,0.4+0.04*centre(c).x/2.6-heights[c]))
	kernel.set_depth(depth)

## Seconds of fixed steps until the pond's surface stays within 4 mm (or the
## limit). Steps a second at a time and needs it within 4 mm at every one of the
## second's quarter points after.
func settle(kernel: RefCounted, heights: PackedFloat32Array, limit: float) -> float:
	var calm_since := -1.0
	var t := 0.0
	while t < limit:
		kernel.step(heights,PackedFloat32Array(),15,DT)
		t += 15*DT
		var s := surface(kernel,heights)
		if s.y-s.x < 0.004:
			if calm_since < 0.0: calm_since = t
			if t-calm_since >= 1.0: return calm_since
		else: calm_since = -1.0
	return INF

func probe(name: String, make: Callable) -> void:
	print("-- ",name)
	var heights := bowl()
	# 2. Slosh.
	var raw: RefCounted = grid(make.call(),{"calm":0.0})
	tilted(raw,heights)
	var raw_settle := settle(raw,heights,40.0)
	var calm: RefCounted = grid(make.call(),{})
	tilted(calm,heights)
	var calm_settle := settle(calm,heights,40.0)
	check(name+": a tilted shallow pond settles within 4 mm sooner with calm",calm_settle < raw_settle*0.85,"%.1f s with calm, %.1f s without" % [calm_settle,raw_settle])
	var pit := PackedFloat32Array()
	for c in range(N*N):
		var r := centre(c).length()
		pit.append(1.2 if r > 1.6 else 1.2*smoothstep(1.1,1.6,r))
	var settled := []
	for setting in [0.0,float(WaterFlow.PARAMS.calm)]:
		var k: RefCounted = grid(make.call(),{"calm":setting})
		var depth := PackedFloat32Array()
		for c in range(N*N): depth.append(maxf(0.0,1.0+0.04*centre(c).x/1.6-pit[c]))
		k.set_depth(depth)
		settled.append(settle(k,pit,40.0))
	check(name+": a tilted deep pit settles in half the time with calm",settled[1] < settled[0]*0.5,"%.1f s with calm, %.1f s without" % [settled[1],settled[0]])
	# 3. Stream down a slope.
	var slope := PackedFloat32Array()
	for c in range(N*N): slope.append(0.8-0.1*(centre(c).x+N*CELL*0.5))
	var drained := []
	for setting in [0.0,float(WaterFlow.PARAMS.calm)]:
		var k: RefCounted = grid(make.call(),{"calm":setting,"saturate":0.0,"soak":0.0,"evaporation":0.0})
		var source := PackedFloat32Array([-N*CELL*0.5+1.0,0.0,0.4,0.3])
		for i in range(120): k.step(slope,source,15,DT)
		drained.append(float(k.stats().drained))
	check(name+": a stream down a slope drains as fast with calm",absf(drained[1]-drained[0]) <= 0.05*drained[0] and drained[0] > 0.1,"%.3f m³ without, %.3f with" % drained)
	# 4. Wind.
	var pond: RefCounted = grid(make.call(),{"evaporation":0.0})
	var level := PackedFloat32Array()
	for c in range(N*N): level.append(maxf(0.0,0.4-heights[c]))
	pond.set_depth(level)
	var before: float = pond.stats().volume
	var wind := PackedFloat32Array()
	for i in range(4): wind.append_array([10.0*WaterFlow.WIND_PUSH,0.0])
	pond.set_wind(wind,2,2)
	for i in range(16): pond.step(heights,PackedFloat32Array(),15,DT)
	var blown := surface(pond,heights)
	check(name+": a 10 m/s gust piles the pond up downwind",blown.z > 0.03,"downwind %.3f m over upwind" % blown.z)
	pond.set_wind(PackedFloat32Array(),0,0)
	var after := settle(pond,heights,40.0)
	check(name+": once it drops the pond settles again",after < 6.0,"%.1f s" % after)
	check(name+": and no water is lost",absf(float(pond.stats().volume)-before) < 0.02*before,[before,pond.stats().volume])

func run() -> void:
	# 1. The burst's curve.
	var burst := WaterFlow._burst(Vector2.ZERO,0.8,6.0,WaterFlow.BURST_SECONDS)
	var first := WaterFlow._poured(burst,0.25)
	var middle := WaterFlow._poured(burst,WaterFlow.BURST_SECONDS*0.5+0.125)-WaterFlow._poured(burst,WaterFlow.BURST_SECONDS*0.5-0.125)
	# The old burst poured 6 m³ flat over 1.2 s: 1.25 m³ in its first quarter second.
	check("a burst starts as a trickle",first < 0.1*6.0*0.25/1.2 and first < 0.2*middle,"%.3f m³ in its first quarter second (was 1.25), %.3f at its height" % [first,middle])
	check("and pours all of it",is_equal_approx(WaterFlow._poured(burst,WaterFlow.BURST_SECONDS),6.0))
	if ClassDB.class_exists("ZenScapeWaterFlow") and ClassDB.class_has_method("ZenScapeWaterFlow","set_wind"): probe("native",func() -> RefCounted: return ClassDB.instantiate("ZenScapeWaterFlow"))
	else: check("native kernel is built with set_wind",false)
	probe("mirror",func() -> RefCounted: return Mirror.new())
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
