extends RefCounted
## Rain on the live water (docs/scenic/water-flow.md, "Rain"): the sky's rain
## runs off the land into the flow simulation (scripts/water_flow.gd), so a
## storm runs rills down the slopes, swells the ponds and can turn a dry basin
## into a pond.
##
## Rain spread evenly over the plate would be a film far thinner than the
## ground soaks, so it gathers first, as rain does: every CELL m of ground
## sends its rain down its steepest way, and the water reaches the simulation
## wherever LUMP m² of catchment has gathered, or where the way ends in a
## hollow (`route`, on a worker every ROUTE_SECONDS while it rains). Those
## drops pour as sources, and the simulation carries them on from there.
## While it rains the ground saturates: soak and evaporation ease off
## (SATURATED_SOAK, WET_EVAPORATION) and come back as it dries, so in dry
## weather the ponds shrink again.
##
## Snow adds no water. It lies as a pack (`snowpack`, m³ of water, weighted to
## high ground) and runs off as melt over MELT_SECONDS once the cold lifts.
## Nothing here is saved; `--no-rain-runoff` turns it off.

## Catchment cell, metres.
const CELL := 1.0
## Runoff at full rain (the weather profiles' 1.0, a storm), m/s over the
## catchment: about 0.16 m³/s over the plate, a light rain (0.6) 0.1 m³/s.
const RUNOFF := 0.0002
## Catchment gathered before it pours, m². Smaller drops soak in before they
## run anywhere.
const LUMP := 14.0
## A hollow or a run off the rim with less catchment than this, m², keeps
## its rain as a puddle that soaks in (the ground's wet shading shows it), so
## a plain's many tiny hollows cost nothing.
const PUDDLE := 5.0
## Radius each drop pours over, metres.
const RADIUS := 0.7
## Rain below this (0..1) adds nothing.
const MIN_RAIN := 0.05
## Seconds between routes of the catchment while water is coming.
const ROUTE_SECONDS := 3.0
## Standing water, m³, above which rain adds nothing, easing off over the
## CAP_EASE m³ below it, so a sky that never stops raining cannot flood the plate.
const VOLUME_CAP := 45.0
const CAP_EASE := 15.0
## Ground saturation: rises with rain over SATURATE_SECONDS, dries over
## DRY_SECONDS. Saturated ground soaks SATURATED_SOAK of the dry rate and
## evaporates WET_EVAPORATION of it.
const SATURATE_SECONDS := 40.0
const DRY_SECONDS := 90.0
const SATURATED_SOAK := 0.3
const WET_EVAPORATION := 0.2
## Params change only when saturation moves this much.
const PARAM_STEP := 0.05
## Snow: the pack holds at most SNOW_PACK m³, melts once the snow phase is
## below MELT_PHASE, over MELT_SECONDS (at least MELT_MIN m³/s while any is
## left). High ground holds it: a cell's share of the pack eases in from the
## MELT_LOW to the MELT_HIGH quantile of the plate's heights.
const SNOW_PACK := 15.0
const MELT_PHASE := 0.15
const MELT_SECONDS := 150.0
const MELT_MIN := 0.01
const MELT_LOW := 0.5
const MELT_HIGH := 0.9
## Melt of this many m³/s saturates the ground as full rain does.
const MELT_WET := 0.05

var enabled := "--no-rain-runoff" not in preload("res://scripts/launch_args.gd").user_args()
## Set every frame by the scene: liquid rain and falling snow, 0..1.
var rain := 0.0
var snowing := 0.0
## The weather's snow phase (0 rain .. 1 snow), for the melt.
var snow_phase := 0.0
## m³ of water lying as snow.
var snowpack := 0.0
var saturation := 0.0
## Runoff now, m/s over each drop's catchment, and melt now, m³/s.
var rain_rate := 0.0
var melt_rate := 0.0
## Flat x, z, catchment m², melt share per drop.
var drops := PackedFloat32Array()
var _since_route := INF
var _job: RefCounted
var _applied := -1.0
var _volume := 0.0

## Eases saturation, lays and melts snow, and routes the catchment again when
## due. `flow` is the scripts/water_flow.gd that owns this.
func advance(delta: float, flow: RefCounted) -> void:
	if not enabled: return
	var wet := rain if rain >= MIN_RAIN else 0.0
	# Melting snow soaks the ground as rain does.
	var soaked := maxf(wet,minf(1.0,melt_rate/MELT_WET))
	saturation = move_toward(saturation,1.0,delta*soaked/SATURATE_SECONDS) if soaked > saturation else move_toward(saturation,soaked,delta/DRY_SECONDS)
	if absf(saturation-_applied) >= PARAM_STEP or (saturation == 0.0 and _applied != 0.0):
		_applied = saturation
		var params: Dictionary = flow.PARAMS.duplicate()
		params.soak = float(params.soak)*lerpf(1.0,SATURATED_SOAK,saturation)
		params.evaporation = float(params.evaporation)*lerpf(1.0,WET_EVAPORATION,saturation)
		flow.kernel.set_params(params)
	if snowing >= MIN_RAIN: snowpack = minf(SNOW_PACK,snowpack+snowing*RUNOFF*flow.width*flow.height*flow.cell*flow.cell*delta)
	melt_rate = 0.0
	if snowpack > 0.0 and snow_phase < MELT_PHASE and snowing < MIN_RAIN:
		melt_rate = minf(snowpack/maxf(delta,0.001),maxf(snowpack/MELT_SECONDS,MELT_MIN))
		snowpack = maxf(0.0,snowpack-melt_rate*delta)
	_since_route += delta
	if _job != null and _job.completed():
		drops = _job.finish()
		_job = null
		_volume = flow.volume()
	var coming := wet > 0.0 or melt_rate > 0.0
	if coming and _job == null and _since_route >= ROUTE_SECONDS:
		_since_route = 0.0
		var ground: PackedFloat32Array = flow.kernel.get_ground()
		var inside: PackedByteArray = flow.inside
		var w: int = flow.width
		var h: int = flow.height
		var size: float = flow.cell
		var start: Vector2 = flow.origin
		_job = preload("res://scripts/background_work.gd").new()
		_job.start(func() -> PackedFloat32Array: return route(ground,inside,w,h,size,start))
	var cap := clampf((VOLUME_CAP-_volume)/CAP_EASE,0.0,1.0)
	rain_rate = wet*RUNOFF*cap
	melt_rate *= cap

## The drops' sources for this step (x, z, radius, m³/s each, as
## ZenScapeWaterFlow.step takes them), or empty when nothing is coming.
func sources() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if not enabled or drops.is_empty() or (rain_rate <= 0.0 and melt_rate <= 0.0): return out
	for d in range(0,drops.size(),4):
		var rate := drops[d+2]*rain_rate+drops[d+3]*melt_rate
		if rate > 0.0: out.append_array([drops[d],drops[d+1],RADIUS,rate])
	return out

## Forget the weather's water: a new world starts dry.
func reset() -> void:
	snowpack = 0.0
	saturation = 0.0
	drops = PackedFloat32Array()
	_since_route = INF

## Where the rain on a `w`×`h` flow grid gathers: flat x, z, catchment m²,
## melt share (summing to 1) per drop. Each CELL block is its lowest inside
## cell; it drains to its steepest lower neighbour, and what it carries pours
## wherever LUMP m² has gathered or the way ends in a hollow. Blocks at the
## plate's rim drop theirs off the edge.
static func route(ground: PackedFloat32Array, inside: PackedByteArray, w: int, h: int, size: float, start: Vector2) -> PackedFloat32Array:
	var k := maxi(1,roundi(CELL/size))
	var cw := w/k
	var ch := h/k
	var n := cw*ch
	var out := PackedFloat32Array()
	if n == 0 or ground.size() != w*h or inside.size() != w*h: return out
	var low := PackedFloat32Array()
	low.resize(n)
	low.fill(INF)
	var at := PackedVector2Array()
	at.resize(n)
	# 0 outside, 1 inside, 2 on the rim (touches outside).
	var kind := PackedByteArray()
	kind.resize(n)
	for cj in range(ch):
		for ci in range(cw):
			var c := cj*cw+ci
			var some := false
			var all := true
			for j in range(cj*k,cj*k+k):
				for i in range(ci*k,ci*k+k):
					var f := j*w+i
					if inside[f] == 0:
						all = false
						continue
					some = true
					if ground[f] < low[c]:
						low[c] = ground[f]
						at[c] = start+Vector2(i+0.5,j+0.5)*size
			kind[c] = 0 if not some else (1 if all else 2)
	var heights := PackedFloat32Array()
	for c in range(n):
		if kind[c] == 0: continue
		if kind[c] == 1 and (c%cw == 0 or c%cw == cw-1 or c/cw == 0 or c/cw == ch-1): kind[c] = 2
		heights.append(low[c])
	if heights.is_empty(): return out
	heights.sort()
	var melt_low := heights[int((heights.size()-1)*MELT_LOW)]
	var melt_high := heights[int((heights.size()-1)*MELT_HIGH)]
	# Steepest lower neighbour; the rim's neighbours outside make it a rim.
	var down := PackedInt32Array()
	down.resize(n)
	down.fill(-1)
	var order := PackedVector2Array()
	for cj in range(ch):
		for ci in range(cw):
			var c := cj*cw+ci
			if kind[c] == 0: continue
			order.append(Vector2(-low[c],c))
			if kind[c] == 2: continue
			var best := 0.0
			for dj in [-1,0,1]:
				for di in [-1,0,1]:
					if di == 0 and dj == 0: continue
					var m: int = c+dj*cw+di
					if kind[m] == 0:
						kind[c] = 2
						continue
					var fall: float = (low[c]-low[m])/(1.4142 if di != 0 and dj != 0 else 1.0)
					if fall > best:
						best = fall
						down[c] = m
			if kind[c] == 2: down[c] = -1
	order.sort()
	var area := float(k*k)*size*size
	var carried := PackedFloat32Array()
	carried.resize(n)
	var melt := PackedFloat32Array()
	melt.resize(n)
	var melt_total := 0.0
	for entry: Vector2 in order:
		var c := int(entry.y)
		if kind[c] == 2: continue
		carried[c] += area
		var share := smoothstep(melt_low,melt_high+0.001,low[c])
		melt[c] += share
		melt_total += share
		if carried[c] >= LUMP:
			out.append_array([at[c].x,at[c].y,carried[c],melt[c]])
		elif down[c] >= 0 and kind[down[c]] != 2:
			carried[down[c]] += carried[c]
			melt[down[c]] += melt[c]
		elif carried[c] >= PUDDLE:
			# A hollow, or one step from the rim (it runs off the edge).
			out.append_array([at[c].x,at[c].y,carried[c],melt[c]])
	# Melt shares: of the pack's high ground, or of the rain where none is high.
	var total := 0.0
	melt_total = 0.0
	for d in range(0,out.size(),4):
		total += out[d+2]
		melt_total += out[d+3]
	for d in range(0,out.size(),4):
		out[d+3] = out[d+3]/melt_total if melt_total > 0.0 else out[d+2]/total
	return out
