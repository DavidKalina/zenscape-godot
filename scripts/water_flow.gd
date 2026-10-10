extends RefCounted
## Live water on the plate (docs/scenic/water-flow.md): a shallow-water
## simulation on a regular grid, stepped at a fixed rate apart from the frame.
## Water runs downhill, fills grooves as channels, pools in hollows and spills
## over rims, and follows the land whenever it changes: the ground under every
## cell is read again from the terrain's heights at the start of each step, so
## a sculpt, an undo or a new world moves the water with nothing to hook.
##
## The numbers run in C++ (`ZenScapeWaterFlow`, native/terrain_kernels/
## water_flow.h) when the library is built; scripts/water_flow_reference.gd is
## the GDScript mirror, run on a coarser grid (`FALLBACK_CELL`).
##
## Sources: a water ball dropped on high or steep ground becomes a spring that
## keeps pouring (`springs`, saved and undoable), after the ball's own water
## wells out of it, and on open ground wears a rill and a pool at its foot
## (`spring_bed`); anywhere else it lets all its water go once, over
## BURST_SECONDS (`bursts`, neither saved nor undone). The watering can
## (scripts/watering_can.gd) pours while it is held (`taps`, transient) and,
## held still on high ground, plants a spring of its own (`plant_spring`).
## Rain and snowmelt pour where the land gathers them (`runoff`,
## scripts/rain_runoff.gd). The water ball takes its water back out of the
## ponds (`scoop`).
## The depth itself is saved with the place but is not part of undo: undoing a
## sculpt puts the land back and the water follows it.

const Plate = preload("res://scripts/plate.gd")

## Grid cell, metres. The native grid is (Plate.SIZE / CELL) a side, 112×112
## over a 28 m plate; the grid itself is sized from the terrain's points.
const CELL := 0.25
const FALLBACK_CELL := 0.5
## Fixed step, seconds, and the most steps one frame may run (a slow frame
## slows the water rather than piling work up).
const DT := 1.0/60.0
const FALLBACK_DT := 1.0/30.0
const MAX_TICKS := 4
## Physics (see the doc's tunables table).
const PARAMS := {
	"gravity":9.81,
	# 1/s: still water stops sloshing in a few seconds.
	"friction":0.6,
	# m/s: bed friction that grows as water thins (λ = friction + drag/depth),
	# so a thin sheet on a steep face runs at about 1.5 m/s, a deep channel faster.
	"drag":0.06,
	# m/s lost from every wet cell (0.4 mm/s): a 6 m³ pond lasts about 15 min.
	"evaporation":0.0004,
	# m/s lost from thin water, fading to nothing at soak_depth: fronts soak in.
	"soak":0.004,
	"soak_depth":0.03,
	# s: ground wet this long is saturated and soaks no more (it soaks less
	# as it wets), so a running stream carries its water on to the pond; dry
	# ground dries back at dry_rate of real time (a minute for a wet one).
	# Without it a spring's sheet down a hillside soaked away 60% of its
	# water over 150 m² and its pond never filled.
	"saturate":6.0,
	"dry_rate":0.1,
	# Saturated ground still soaks thin water (under soak_depth) at this share
	# of `soak`: a stream deeper than that carries on untouched, but a sheet
	# spilled over flat ground soaks in within a few tens of m² instead of
	# spreading until evaporation alone balances it (a 0.35 m³/s spring wet
	# 500 m² of the 784 m² plate).
	"soak_floor":0.3,
	"max_speed":4.0,
	# s: the time constant the water leaving each edge cell is smoothed with
	# (edge_outflow, spills; the edge falls read it).
	"edge_smooth":0.5,
	# Extra friction on still water (deeper than about calm_depth m, slower
	# than about calm_speed m/s, no wind on it), calm × √(g·depth) per second:
	# a pond's slosh is damped to about critical, so it settles without rocking
	# back, sooner in a deep pit (whose waves run faster) as in a shallow bowl;
	# streams and thin fronts run as before. More is not calmer: at 1.5 a
	# shallow pond creeps level over 8 s instead of 3 (tools/probe_water_calm.gd).
	"calm":0.5,
	"calm_speed":0.15,
	"calm_depth":0.05,
}
## The wind tool's gusts push the water: WIND_PUSH m/s² for each m/s of air
## (WindGust.wind_at, 8-22 m/s), sampled on a WIND_SAMPLES × WIND_SAMPLES grid
## over the plate while a gust blows (`wind`). Deep water piles up downwind and
## a sheet drifts with the air; let go, it sloshes back and settles.
const WIND_PUSH := 0.03
const WIND_SAMPLES := 15
## A ball is a spring when it lands SPRING_RISE m above the plate's low ground
## (its LOW_SHARE quantile), or on ground steeper than SPRING_SLOPE.
const SPRING_RISE := 1.2
const SPRING_SLOPE := 0.45
const LOW_SHARE := 0.2
## A spring pours SPRING_SHARE of its ball's volume each second, within
## SPRING_MIN..SPRING_MAX m³/s, over SPRING_RADIUS m, after letting the ball's
## own water go as a burst. A spring is a source that never runs dry: it fills
## the river and the pond below it to the brim and spills on. At the old
## 0.03..0.25 m³/s a small ball's spring lost its water to the soak on the
## thin sheet down the face (soak × tens of m²) and its pond never filled;
## SPRING_MIN outruns that on a long course.
const SPRING_SHARE := 0.03
const SPRING_MIN := 0.35
const SPRING_MAX := 0.7
const SPRING_RADIUS := 0.35
const MAX_SPRINGS := 8
## A ball carrying less than SPRING_BALL m³ lets its water go wherever it
## lands: a sip scooped from a puddle is no spring.
const SPRING_BALL := 1.0
## A burst lets its volume go over BURST_SECONDS across BURST_RADIUS m, on
## a smoothstep (`_poured`): it starts as a trickle, peaks at half time at 1.5×
## its mean rate, and tapers off. It used to pour at a flat rate over 1.2 s,
## so a ball's water landed as a wall that ran out over the plain at once.
const BURST_SECONDS := 3.5
const BURST_RADIUS := 0.8
## A spring's ball does not burst on the summit: its water wells out of the
## spring over SPRING_HEAD_SECONDS (a strong first run that reaches the foot
## in a few seconds), and the spring then keeps its steady rate. Dumped in
## 1.2 s on a peak, the ball's water sheeted down every flank at once and
## ended as a film a few centimetres deep over a hundred square metres of the
## plain, which soaked away.
const SPRING_HEAD_SECONDS := 10.0
## A new spring opens over SPRING_OPEN seconds (its rate eases in on a
## smoothstep), so with its ball's head welling out on the same curve the
## first run gathers rather than gushing out at full rate at once.
const SPRING_OPEN := 4.0
## A spring pours its full rate for SPRING_FILL s, enough to fill its stream
## and the pond below, then eases over SPRING_EASE s to SPRING_REST m³/s (or
## its rate, if less): a trickle the groove it runs in can carry, whose
## overflow runs on as a rivulet. At full rate for ever its water overtopped
## the groove and sheeted over the plain. A loaded spring pours its rest rate.
const SPRING_FILL := 20.0
const SPRING_EASE := 20.0
const SPRING_REST := 0.06
## The spring rises down its course from where the ball landed, so on a
## summit its water takes one flank instead of splitting over all: only as far
## as it takes for its footprint (SPRING_RADIUS) to lie on the one flank (the
## ground SPRING_RADIUS behind it, up its course, stands SPRING_BACK over it),
## at most SPRING_SET m. On a flank that is where it landed. It used to go a
## flat SPRING_SET m whatever the ground, which on a steep horn is metres down:
## a ball dropped on a 5.8 m pinch welled 2.2 m under the summit, and its fall
## hung from a third of the way down the mountain.
const SPRING_SET := 1.0
const SPRING_BACK := 0.03
## A spring's course (`descent`): steepest descent over the ground in
## COURSE_STEP m steps, ending at its foot once COURSE_FLAT_STEPS steps in a
## row fall less than COURSE_FLAT per metre, or COURSE_RIM m from the rim.
const COURSE_STEP := 0.5
const COURSE_FLAT := 0.08
const COURSE_FLAT_STEPS := 2
const COURSE_MAX_STEPS := 80
const COURSE_RIM := 2.0
## Where the course levels off on open ground, the spring's water wears a
## bed (`spring_bed`): a pool at the foot sized to hold the ball (a
## floored pond, BED_*: radius and depth from the volume, kept POOL_RIM m inside
## the rim) and a rill RILL_DEPTH deep, RILL_HALF_WIDTH to either side, down
## the course to it, so the water runs as one stream into a pond instead of
## sheeting over the face and spreading thin over the flat. A foot that
## already sits in a hollow at least POOL_HOLLOW deep keeps its ground, and
## so does a course that runs to the rim. `--no-spring-bed` turns it off.
const POOL_RIM := 1.5
const POOL_HOLLOW := 0.25
## The pool is a pond, not the water brush's dish: the brush's (1-t²)² hollow
## sized to the ball came out 7-8 m across and 0.5 m deep only at its middle,
## half its water under 15 cm, and the pond shader showed that as the grass
## under it inside a ring of shore foam. Radius BED_SIZE.x + BED_SIZE.y·√V
## (within BED_RADIUS), full depth inside BED_FLOOR of it and easing up to
## the ground on a smoothstep, deep enough to hold the ball with
## BED_FREEBOARD to spare (within BED_DEPTH).
const BED_SIZE := Vector2(1.2,0.55)
const BED_RADIUS := Vector2(1.8,3.4)
const BED_FLOOR := 0.45
const BED_DEPTH := Vector2(0.35,1.0)
const BED_FREEBOARD := 0.1
## The share of radius² × depth × π a BED_FLOOR profile holds.
const BED_FILL := 0.54
const RILL_DEPTH := 0.3
const RILL_HALF_WIDTH := 1.0
## Standing water deeper than POOL_DEPTH and slower than POOL_SPEED, over at
## least POOL_CELLS cells, is a pool (fish and shore life; `pools()`).
const POOL_DEPTH := 0.15
const POOL_SPEED := 0.12
const POOL_CELLS := 12

var data: NativeTerrainData
var kernel: RefCounted
var native := false
var cell := CELL
var dt := DT
var width := 0
var height := 0
var origin := Vector2.ZERO
## [{"x", "z", "rate", "radius", "age"}], saved and undoable. `age` (s) runs
## a new spring through `spring_rate` (open, fill, rest); a load drops it, and
## the spring pours its rest rate at once.
var springs: Array[Dictionary] = []
## [{"x", "z", "radius", "volume", "seconds", "age"}], each pouring `volume`
## over `seconds` on a smoothstep (`_poured`). Transient.
var bursts: Array[Dictionary] = []
## Sources held open from outside, by name: [x, z, radius, rate], poured
## every step until erased (the watering can's stream). Transient.
var taps: Dictionary = {}
## Water poured into a hollow from outside, by name: [x, z, rate] (the
## watering can's gush). Each step its volume is laid level over the water
## standing round the point, the hollow's lowest surface first (`fill_level`),
## so a crater fills as one lake rising rather than a heap under the spout,
## and stops at the lowest gap in its rim: what is poured past the brim is not
## poured. `brimmed` holds the names whose hollow stood full at the last step.
## Transient.
var lifts: Dictionary = {}
var brimmed: Dictionary = {}
## Each lift's hollow, kept HOLLOW_SECONDS s (finding one floods the plate,
## a few milliseconds): {"cell", "age", "hollow"}.
const HOLLOW_SECONDS := 2.0
var _hollows: Dictionary = {}
## What blows on the water: an object with `wind_at(point: Vector2) ->
## Vector2` (m/s, plate x, z; scripts/wind_gust.gd), set while a gust blows and
## null otherwise. The editor sets it every frame.
var wind: Object = null
var _wind_was := false
## The weather's water: set `runoff.rain`, `.snowing` and `.snow_phase`.
var runoff := preload("res://scripts/rain_runoff.gd").new()
## 1 per grid cell over the plate's ground, 0 outside it (off the plate, off
## the island's outline, or over the chasm).
var inside := PackedByteArray()
var ready := false
var paused := false
## Bumped every step, so a view can tell new water from old.
var revision := 0
var _clock := 0.0
var _topology := PackedInt32Array()
var _void := PackedByteArray()
## Microseconds of the last step and the worst seen, for probes.
var last_step_usec := 0
var worst_step_usec := 0

## Picks the native kernel unless `--gdscript-kernels` asks for the mirror (or
## the library is not built). Build the cell map with `map_cells` (or `setup`).
func _init(terrain: NativeTerrainData, prefer_native := true) -> void:
	data = terrain
	# A library built before the newest method (`set_wind`) is stale: use the mirror.
	if prefer_native and preload("res://scripts/native_terrain_kernels.gd").get_kernel() != null and ClassDB.class_exists("ZenScapeWaterFlow") and ClassDB.class_has_method("ZenScapeWaterFlow","set_wind"):
		kernel = ClassDB.instantiate("ZenScapeWaterFlow")
		native = true
	else:
		kernel = preload("res://scripts/water_flow_reference.gd").new()
		cell = FALLBACK_CELL
		dt = FALLBACK_DT
	kernel.set_params(PARAMS)
	data.history_captured.connect(func(state: Dictionary) -> void: state["water_springs"] = springs.duplicate(true))
	data.state_restored.connect(_restore)
	# A new outline (or chasm) is a new grid: the cells off the land are
	# outside, and the cells beside them the edge water leaves by.
	data.void_changed.connect(func() -> void: _void_changed())
	data.document_captured.connect(func(document: Dictionary) -> void:
		if ready and (not springs.is_empty() or volume() > 0.01): document["water_flow"] = encode())

## As a sky chunk becomes the plate (NativeTerrainData `adopt`, SkyIslands
## `claim`) the cells are mapped again on a worker (9 ms on the main thread,
## most of that frame); the water waits meanwhile, and the state restored
## meanwhile is taken once the cells are the land's (`_restore`).
func _void_changed() -> void:
	if not ready: return
	if not data._adopting:
		await setup()
		return
	ready = false
	_remapping = true
	await setup(Engine.get_main_loop() as SceneTree)

## True while `_void_changed` maps the cells again; a state restored
## meanwhile (`_pending`) is taken once they are mapped.
var _remapping := false
var _pending: Variant = null

## Maps every grid cell to the terrain triangle under its centre, synchronously
## or on a worker when `tree` is given. Call again if the mesh changes.
func setup(tree: SceneTree = null) -> void:
	var low := Vector2(INF,INF)
	var high := -low
	for point: Vector2 in data.points:
		low = low.min(point)
		high = high.max(point)
	origin = low
	width = ceili((high.x-low.x)/cell-0.001)
	height = ceili((high.y-low.y)/cell-0.001)
	var points := data.points
	var ids := data.vertex_ids
	var cut := data.void_faces.duplicate()
	var w := width
	var h := height
	var size := cell
	var start := origin
	var job = preload("res://scripts/background_work.gd").new()
	var mapped: Dictionary = await job.run(func() -> Dictionary: return map_cells(points,ids,size,start,w,h,cut),tree)
	kernel.configure(width,height,cell,origin,mapped.faces,mapped.weights)
	inside = mapped.inside
	_topology = data.vertex_ids
	_void = cut
	_shore_cells.clear()
	_hollows.clear()
	# The land changed while the cells were mapped (a fresh island's outline
	# is set while the first map runs on a worker, and `_void_changed` waits
	# for `ready`): map them again, or the water would run over the sky. The
	# grid is not ready until the map it holds is the land's.
	if data.void_faces != cut or data.vertex_ids != ids:
		await setup(tree)
		return
	ready = true
	_remapping = false
	if _pending != null:
		var state: Dictionary = _pending
		_pending = null
		_restore(state)

## For each cell centre of a `w`×`h` grid, the triangle under it: three vertex
## ids and barycentric (u, v) as NativeTerrainData.sample weighs them, or -1.
## Each triangle is rasterised over the cells its bounds cover. Faces `cut`
## marks (NativeTerrainData `void_faces`: off the island, or the chasm) are
## not ground, so the cells over them are outside, as the plate's own
## surroundings are; the kernel drains the cells beside them as its edge.
static func map_cells(points: PackedVector2Array, ids: PackedInt32Array, size: float, start: Vector2, w: int, h: int, cut := PackedByteArray()) -> Dictionary:
	var faces := PackedInt32Array()
	faces.resize(w*h*3)
	faces.fill(-1)
	var weights := PackedFloat32Array()
	weights.resize(w*h*2)
	for f in range(0,ids.size(),3):
		if not cut.is_empty() and cut[f/3] != 0: continue
		var a := points[ids[f]]
		var b := points[ids[f+1]]
		var c := points[ids[f+2]]
		var denominator := (b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
		if absf(denominator) < 0.000001: continue
		var lo := a.min(b).min(c)
		var hi := a.max(b).max(c)
		for j in range(maxi(0,floori((lo.y-start.y)/size-0.5)),mini(h-1,ceili((hi.y-start.y)/size-0.5))+1):
			var z := start.y+(j+0.5)*size
			for i in range(maxi(0,floori((lo.x-start.x)/size-0.5)),mini(w-1,ceili((hi.x-start.x)/size-0.5))+1):
				var at := j*w+i
				if faces[at*3] >= 0: continue
				var x := start.x+(i+0.5)*size
				var u := ((b.y-c.y)*(x-c.x)+(c.x-b.x)*(z-c.y))/denominator
				var v := ((c.y-a.y)*(x-c.x)+(a.x-c.x)*(z-c.y))/denominator
				if u >= -0.00001 and v >= -0.00001 and u+v <= 1.00001:
					faces[at*3] = ids[f]
					faces[at*3+1] = ids[f+1]
					faces[at*3+2] = ids[f+2]
					weights[at*2] = u
					weights[at*2+1] = v
	var inside := PackedByteArray()
	inside.resize(w*h)
	for c in range(w*h): inside[c] = 1 if faces[c*3] >= 0 else 0
	return {"faces":faces,"weights":weights,"inside":inside}

## Runs the fixed steps `delta` seconds owe. True when any ran.
func advance(delta: float) -> bool:
	if not ready or paused: return false
	runoff.advance(minf(delta,0.1),self)
	_clock += minf(delta,0.1)
	var ticks := mini(floori(_clock/dt),MAX_TICKS)
	if ticks <= 0: return false
	_clock = maxf(_clock-ticks*dt,0.0) if ticks < MAX_TICKS else 0.0
	run(ticks)
	return true

## Runs `ticks` fixed steps now.
func run(ticks: int) -> void:
	if not ready: return
	var sources := PackedFloat32Array()
	var seconds := ticks*dt
	for spring: Dictionary in springs:
		var age: float = spring.get("age",SPRING_FILL+SPRING_EASE)
		var mid := age+seconds*0.5
		if age < SPRING_FILL+SPRING_EASE: spring.age = age+seconds
		sources.append_array([spring.x,spring.z,spring.radius,spring_rate(spring.rate,mid)])
	var finished := false
	for burst: Dictionary in bursts:
		var age: float = burst.age
		var poured := _poured(burst,age+seconds)-_poured(burst,age)
		sources.append_array([burst.x,burst.z,burst.radius,poured/seconds])
		burst.age = age+seconds
		finished = finished or burst.age >= burst.seconds
	if finished: bursts = bursts.filter(func(burst: Dictionary) -> bool: return burst.age < burst.seconds)
	for tap: Array in taps.values(): sources.append_array(tap)
	brimmed.clear()
	for name: Variant in _hollows.keys():
		if not lifts.has(name): _hollows.erase(name)
	if not lifts.is_empty():
		var ground := grounds()
		var depth := depths()
		for name: Variant in lifts:
			var lift: Array = lifts[name]
			var at := Vector2(lift[0],lift[1])
			# The hollow is found again when the lift moves, and every
			# HOLLOW_SECONDS for the land changing under it.
			var known: Dictionary = _hollows.get(name,{})
			if known.is_empty() or known.cell != cell_at(at) or float(known.age) >= HOLLOW_SECONDS:
				known = {"cell":cell_at(at),"age":0.0,"hollow":hollow(at,ground)}
				_hollows[name] = known
			known.age = float(known.age)+seconds
			var filled := fill_level(known.hollow,float(lift[2])*seconds,ground,depth)
			if filled.is_empty(): continue
			if filled.full: brimmed[name] = true
			# One source a cell, smaller than the cell, so all of it lands there.
			var cells: PackedInt32Array = filled.cells
			var rise: PackedFloat32Array = filled.rise
			for k in cells.size():
				if rise[k] <= 0.0: continue
				var c := cells[k]
				depth[c] += rise[k]
				sources.append_array([origin.x+(c%width+0.5)*cell,origin.y+(c/width+0.5)*cell,cell*0.5,rise[k]*cell*cell/seconds])
	sources.append_array(runoff.sources())
	_blow()
	# Deep water steps in shorter steps: the pipes are stable only while a
	# step is shorter than a cell over twice the waves' speed, √(g·depth).
	var split := substeps()
	last_step_usec = kernel.step(data.heights,sources,ticks*split,dt/split)
	worst_step_usec = maxi(worst_step_usec,last_step_usec)
	revision += 1

## How many steps each fixed step is split into for the deepest water
## (read again every DEEP_SECONDS of steps): the virtual pipes are stable in
## two dimensions only while dt ≤ cell / (2·√(g·depth)), with STABLE of that
## for margin. On the 25 cm grid at 1/60 s that is 5.7 m: ponds are never
## near it, but a Crater lake brimmed 7 m deep stood level until a splash,
## then heaped 12 m deep on one side of its floor and 2 m on the other and
## never settled (tools/probe_deep_lake.gd). At most MAX_SPLIT.
const STABLE := 0.8
const DEEP_SECONDS := 0.25
const MAX_SPLIT := 6
var _deepest := 0.0
var _deep_age := INF
func substeps() -> int:
	_deep_age += dt
	if _deep_age >= DEEP_SECONDS:
		_deep_age = 0.0
		_deepest = 0.0
		for d: float in depths(): _deepest = maxf(_deepest,d)
	var longest: float = STABLE*cell/(2.0*sqrt(float(PARAMS.gravity)*maxf(_deepest,0.001)))
	return clampi(ceili(dt/longest),1,MAX_SPLIT)

## What a spring of `rate` m³/s pours `age` s after it rose: opening over
## SPRING_OPEN, full for SPRING_FILL, easing to SPRING_REST over SPRING_EASE.
static func spring_rate(rate: float, age: float) -> float:
	var rest := minf(rate,SPRING_REST)
	return lerpf(rate,rest,smoothstep(SPRING_FILL,SPRING_FILL+SPRING_EASE,age))*smoothstep(0.0,1.0,age/SPRING_OPEN)

## Hands the kernel the wind's push while a gust blows, and clears it once
## the gust is gone.
func _blow() -> void:
	if wind == null:
		if _wind_was: kernel.set_wind(PackedFloat32Array(),0,0)
		_wind_was = false
		return
	var values := PackedFloat32Array()
	values.resize(WIND_SAMPLES*WIND_SAMPLES*2)
	var span := Vector2(width,height)*cell
	for b in range(WIND_SAMPLES):
		for a in range(WIND_SAMPLES):
			var push: Vector2 = wind.wind_at(origin+span*Vector2(a,b)/float(WIND_SAMPLES-1))*WIND_PUSH
			values[(b*WIND_SAMPLES+a)*2] = push.x
			values[(b*WIND_SAMPLES+a)*2+1] = push.y
	kernel.set_wind(values,WIND_SAMPLES,WIND_SAMPLES)
	_wind_was = true

## What a burst has poured by `age` seconds: its volume on a smoothstep over
## its seconds, so it eases in and out and pours all of it.
static func _poured(burst: Dictionary, age: float) -> float:
	return float(burst.volume)*smoothstep(0.0,1.0,age/float(burst.seconds))

static func _burst(at: Vector2, radius: float, volume: float, seconds: float) -> Dictionary:
	return {"x":at.x,"z":at.y,"radius":radius,"volume":volume,"seconds":seconds,"age":0.0}

## What a ball of `volume` m³ landing at `point` becomes: "spring" or "burst".
func source_kind(point: Vector2) -> String:
	var ground: Variant = data.ground_height(point)
	if ground == null: return ""
	var slope := 0.0
	for direction: Vector2 in [Vector2(0.75,0),Vector2(0,0.75)]:
		var ahead: Variant = data.ground_height(point+direction)
		var behind: Variant = data.ground_height(point-direction)
		if ahead != null and behind != null: slope = maxf(slope,absf(float(ahead)-float(behind))/1.5)
	return "spring" if float(ground)-low_ground() >= SPRING_RISE or slope >= SPRING_SLOPE else "burst"

## The plate's low ground: the LOW_SHARE quantile of its heights.
func low_ground() -> float:
	var sorted := data.heights.duplicate()
	sorted.sort()
	return sorted[clampi(int(sorted.size()*LOW_SHARE),0,sorted.size()-1)] if not sorted.is_empty() else 0.0

## A water ball lands. Anywhere low its water goes as a burst. On high or
## steep ground a spring stays just down the slope (`spring_set`), the ball's water
## wells out of it over SPRING_HEAD_SECONDS, and where its course levels off
## on open ground the water wears a bed and a pool (`spring_bed`). The spring
## and its bed are one undo step; `last_bed` keeps the ground before and
## after, for the editor to show the change. Returns the kind.
func drop(point: Vector2, volume: float) -> String:
	var kind := source_kind(point)
	if kind == "spring" and volume < SPRING_BALL: kind = "burst"
	last_bed = {}
	if kind.is_empty() or not ready: return ""
	if kind == "burst":
		bursts.append(_burst(point,BURST_RADIUS,volume,BURST_SECONDS))
		return kind
	_spring(point,volume,true)
	return kind

## A spring planted by hand (the watering can held still on high ground):
## as a ball's spring, its course, bed and pool sized for `volume` m³ (what
## the can has poured there), but with no ball's water to well out first.
## False where a ball would not make a spring.
func plant_spring(point: Vector2, volume: float) -> bool:
	last_bed = {}
	if not ready or source_kind(point) != "spring": return false
	_spring(point,volume,false)
	return true

func _spring(point: Vector2, volume: float, head: bool) -> void:
	var course := descent(data,point)
	var points: PackedVector3Array = course.points
	var placed := spring_set(data,points)
	var at: Vector2 = placed.at
	var set: int = placed.index
	if head: bursts.append(_burst(at,SPRING_RADIUS,volume,SPRING_HEAD_SECONDS))
	data.begin_stroke()
	# The rill starts at the spring, not a step above it (the summit).
	var at_ground: Variant = data.ground_height(at)
	var from_spring := PackedVector3Array([Vector3(at.x,float(at_ground) if at_ground != null else points[maxi(set-1,0)].y,at.y)])
	from_spring.append_array(points.slice(set))
	var bed := {} if "--no-spring-bed" in preload("res://scripts/launch_args.gd").user_args() else spring_bed(data,{"points":from_spring,"end":course.end},1,volume)
	if not bed.is_empty():
		last_bed = {"from":data.heights.duplicate(),"heights":bed.heights.duplicate(),"rect":bed.rect,"pool":bed.pool,"radius":bed.radius}
		data.heights = bed.heights
	if springs.size() >= MAX_SPRINGS: springs.pop_front()
	springs.append({"x":at.x,"z":at.y,"rate":clampf(volume*SPRING_SHARE,SPRING_MIN,SPRING_MAX),"radius":SPRING_RADIUS,"age":0.0})
	data.end_stroke()

## Where on a `descent` course the spring wells (see SPRING_SET): {"at" (plate
## point), "index" (the course point just past it)}.
static func spring_set(terrain: NativeTerrainData, points: PackedVector3Array) -> Dictionary:
	if points.is_empty(): return {"at":Vector2.ZERO,"index":0}
	var out := 0.0
	for k in range(1,points.size()):
		var a := Vector2(points[k-1].x,points[k-1].z)
		var b := Vector2(points[k].x,points[k].z)
		var run := a.distance_to(b)
		if run < 0.0001: continue
		var heading := (b-a)/run
		var along := 0.0
		while along < run:
			var at := a+heading*along
			if out+along >= SPRING_SET: return {"at":at,"index":k}
			var here: Variant = terrain.ground_height(at)
			var back: Variant = terrain.ground_height(at-heading*SPRING_RADIUS)
			if here == null or back == null or float(back) >= float(here)+SPRING_BACK: return {"at":at,"index":k}
			along += 0.05
		out += run
	return {"at":Vector2(points[-1].x,points[-1].z),"index":points.size()-1}

## The last spring's bed: {"from", "heights" (the ground before and after),
## "rect", "pool", "radius"}, or {} when it wore none.
var last_bed := {}

## The way water runs from `point`: steepest descent over the ground, one
## COURSE_STEP a step: {"points" (x, ground, z), "end"}. "end" says how it
## ends: "foot" where COURSE_FLAT_STEPS steps in a row fall less than
## COURSE_FLAT per metre, "hollow" where no step goes lower, "rim" within
## COURSE_RIM m of the rim (or after COURSE_MAX_STEPS).
static func descent(terrain: NativeTerrainData, point: Vector2) -> Dictionary:
	var course := PackedVector3Array()
	var ground: Variant = terrain.ground_height(point)
	if ground == null: return {"points":course,"end":"rim"}
	var at := point
	var h := float(ground)
	course.append(Vector3(at.x,h,at.y))
	var flat := 0
	var end := "rim"
	for step in range(COURSE_MAX_STEPS):
		var best := at
		var lowest := h
		var blocked := false
		for k in range(16):
			var next := at+Vector2.from_angle(TAU*k/16.0)*COURSE_STEP
			var below: Variant = terrain.ground_height(next)
			if below == null or rim_gap(terrain,next) < COURSE_RIM:
				blocked = true
				continue
			if float(below) < lowest:
				lowest = float(below)
				best = next
		if best == at:
			end = "rim" if blocked else "hollow"
			break
		flat = flat+1 if h-lowest < COURSE_STEP*COURSE_FLAT else 0
		at = best
		h = lowest
		course.append(Vector3(at.x,h,at.y))
		if flat >= COURSE_FLAT_STEPS:
			end = "foot"
			break
	return {"points":course,"end":end}

## Metres from plate point `p` in to the land's rim: the square plate's edge,
## or an island's shore (NativeTerrainData `shore_distance`); negative off
## the island.
static func rim_gap(terrain: NativeTerrainData, p: Vector2) -> float:
	if terrain.shore_distance.is_empty(): return Plate.HALF-maxf(absf(p.x),absf(p.y))
	var inland: Variant = terrain.sample(p,terrain.shore_distance)
	return float(inland) if inland != null else -1.0

## The ground a spring's water wears on open ground: a rill down its
## `descent` from the `start`th point and a pool at its foot that holds
## `volume`, as {"heights", "rect", "pool", "radius"}. {} where the land
## already holds the water (the foot lies in a hollow POOL_HOLLOW deep) or
## lets it go (the course reaches the rim, or no pool fits inside it). Only
## lowers ground.
static func spring_bed(terrain: NativeTerrainData, descended: Dictionary, start: int, volume: float) -> Dictionary:
	var course: PackedVector3Array = descended.points
	if course.size() < 3 or descended.end == "rim": return {}
	var foot := Vector2(course[-1].x,course[-1].z)
	var radius := clampf(BED_SIZE.x+BED_SIZE.y*sqrt(volume),BED_RADIUS.x,BED_RADIUS.y)
	# Already a hollow: the water pools there by itself.
	var rim_low := INF
	for k in range(16):
		var ring: Variant = terrain.ground_height(foot+Vector2.from_angle(TAU*k/16.0)*radius)
		if ring != null: rim_low = minf(rim_low,float(ring))
	if rim_low-course[-1].y >= POOL_HOLLOW: return {}
	# The pool lies on past the foot, so it meets the slope rather than
	# cutting under it, and stays POOL_RIM inside the rim.
	var heading := (foot-Vector2(course[-2].x,course[-2].z)).normalized()
	var limit := Plate.HALF-POOL_RIM-radius
	if limit < 0.0:
		radius = Plate.HALF-POOL_RIM
		limit = 0.0
	if radius < BED_RADIUS.x: return {}
	var pool := (foot+heading*radius*0.5).clamp(Vector2(-limit,-limit),Vector2(limit,limit))
	# An island's shore is its rim: the pool shrinks to stay POOL_RIM inside
	# it, back toward the foot if it must, or wears none where none fits.
	if not terrain.shore_distance.is_empty():
		var room := rim_gap(terrain,pool)-POOL_RIM
		if room < BED_RADIUS.x:
			pool = foot
			room = rim_gap(terrain,pool)-POOL_RIM
		radius = minf(radius,room)
		if radius < BED_RADIUS.x: return {}
	var depth := clampf(volume/(PI*radius*radius*BED_FILL)+BED_FREEBOARD,BED_DEPTH.x,BED_DEPTH.y)
	var heights := terrain.heights.duplicate()
	var top := course[maxi(start-1,0)].y
	var rect := Rect2(pool-Vector2.ONE*radius,Vector2.ONE*radius*2.0)
	for i in range(terrain.points.size()):
		var p := terrain.points[i]
		var cut := 0.0
		var t := p.distance_to(pool)/radius
		if t < 1.0: cut = depth*(1.0-smoothstep(BED_FLOOR,1.0,t))
		# The rill follows the course from the spring down to the pool.
		var near := INF
		for k in range(maxi(start,1),course.size()):
			var a := Vector2(course[k-1].x,course[k-1].z)
			var run := Vector2(course[k].x,course[k].z)-a
			var along := clampf((p-a).dot(run)/maxf(run.length_squared(),0.000001),0.0,1.0)
			near = minf(near,p.distance_to(a+run*along))
		# Not above the spring: a spring just off a summit wore the peak down.
		if near < RILL_HALF_WIDTH and terrain.heights[i] < top:
			var u := near/RILL_HALF_WIDTH
			cut = maxf(cut,RILL_DEPTH*(1.0-u*u)*(1.0-u*u)*(1.0-smoothstep(top-RILL_DEPTH,top,terrain.heights[i])))
			rect = rect.expand(p)
		if cut > 0.0: heights[i] = maxf(NativeTerrainData.MIN_HEIGHT,heights[i]-cut)
	return {"heights":heights,"rect":rect.grow(1.0),"pool":pool,"radius":radius}

## Takes the water within `radius` of `point` and any spring there, as one
## undo step for the springs. Returns the m³ taken.
func drain(point: Vector2, radius: float) -> float:
	var kept := springs.filter(func(spring: Dictionary) -> bool: return Vector2(spring.x,spring.z).distance_to(point) > radius)
	if kept.size() != springs.size():
		data.begin_stroke()
		springs.assign(kept)
		data.end_stroke()
	bursts = bursts.filter(func(burst: Dictionary) -> bool: return Vector2(burst.x,burst.z).distance_to(point) > radius)
	return kernel.drain(point,radius) if ready else 0.0

## Takes up to `volume` m³ of the water within `radius` of `point` (the water
## ball scooping a pond): all of it is drained, and what is over is put back
## spread level over the same circle. Springs and bursts stay. Returns the
## m³ taken.
func scoop(point: Vector2, radius: float, volume: float) -> float:
	if not ready or volume <= 0.0: return 0.0
	var found: float = kernel.drain(point,radius)
	if found > volume: kernel.add_water(point,radius,found-volume)
	return minf(found,volume)

## Water standing on the plate, m³.
func volume() -> float:
	return float(kernel.stats().volume) if ready else 0.0

func stats() -> Dictionary:
	var found: Dictionary = kernel.stats() if ready else {}
	found.merge({"cell":cell,"width":width,"height":height,"springs":springs.size(),"bursts":bursts.size(),"last_step_usec":last_step_usec,"worst_step_usec":worst_step_usec},true)
	return found

## Depth over each cell (row-major, `width` per row) and ground under it.
func depths() -> PackedFloat32Array:
	return kernel.get_depth() if ready else PackedFloat32Array()

func grounds() -> PackedFloat32Array:
	return kernel.get_ground() if ready else PackedFloat32Array()

## Water depth at a plate point (the cell under it), 0 off the grid.
func depth_at(point: Vector2) -> float:
	var at := cell_at(point)
	return kernel.get_depth()[at] if at >= 0 else 0.0

func cell_at(point: Vector2) -> int:
	var i := floori((point.x-origin.x)/cell)
	var j := floori((point.y-origin.y)/cell)
	return j*width+i if i >= 0 and j >= 0 and i < width and j < height else -1

## Where water stands WET_DEPTH or deeper, for emergence: {"mask" (1 per
## wet cell), "origin", "cell", "width", "height"}. A new dictionary each
## call, so a planner on a worker can keep the one it was given.
const WET_DEPTH := 0.05
func wet_mask() -> Dictionary:
	if not ready: return {}
	return {"mask":kernel.wet_cells(WET_DEPTH),"origin":origin,"cell":cell,"width":width,"height":height}

## True when `mask` (from `wet_mask`) has water at `point`.
static func wet_in(mask: Dictionary, point: Vector2) -> bool:
	if mask.is_empty(): return false
	var i := floori((point.x-float(mask.origin.x))/float(mask.cell))
	var j := floori((point.y-float(mask.origin.y))/float(mask.cell))
	if i < 0 or j < 0 or i >= int(mask.width) or j >= int(mask.height): return false
	return (mask.mask as PackedByteArray)[j*int(mask.width)+i] != 0

func surface(params: Dictionary) -> Dictionary:
	return kernel.surface(params)

## The hollow round `at`, from the ground alone: the level water standing
## there rises to before it spills (its sill), and the cells under that level
## joined to it. The sill comes from a priority flood in from the plate's
## edge cells (where water leaves the plate), each cell taking the higher of
## its ground and the level of the cell it was reached from, which is the
## lowest rim water there must top to get out; bumps inside a crater's wall
## make no false rim. The hollow is found from the lowest ground within
## FILL_START m of `at`, as a pour lands on a wall and runs to the floor.
## {"cells", "sill"}, or {} off the plate. The water is left out: a live
## pour's surface is not level (it heaps under the spout and slopes down its
## sheet), and flooding over it found a sill a cell from the spout.
const FILL_START := 2.0
func hollow(at: Vector2, ground: PackedFloat32Array) -> Dictionary:
	var start := cell_at(at)
	if start < 0 or inside.is_empty() or inside[start] == 0 or ground.size() != width*height: return {}
	var reach := ceili(FILL_START/cell)
	var ci := start%width
	var cj := start/width
	for j in range(maxi(cj-reach,0),mini(cj+reach,height-1)+1):
		for i in range(maxi(ci-reach,0),mini(ci+reach,width-1)+1):
			var c := j*width+i
			if inside[c] == 0 or (i-ci)*(i-ci)+(j-cj)*(j-cj) > reach*reach: continue
			if ground[c] < ground[start]: start = c
	var spill := PackedFloat32Array()
	spill.resize(width*height)
	spill.fill(INF)
	# A binary heap of cells by spill level, seeded with the edge cells.
	var keys := PackedFloat32Array()
	var ids := PackedInt32Array()
	for c in width*height:
		if inside[c] == 0: continue
		var i := c%width
		var j := c/width
		if i == 0 or j == 0 or i == width-1 or j == height-1 or inside[c-1] == 0 or inside[c+1] == 0 or inside[c-width] == 0 or inside[c+width] == 0:
			spill[c] = ground[c]
			_heap_push(keys,ids,ground[c],c)
	while not keys.is_empty():
		var level := keys[0]
		var c := _heap_pop(keys,ids)
		if c == start: break
		for n: int in [c-1,c+1,c-width,c+width]:
			if n < 0 or n >= width*height or inside[n] == 0 or spill[n] != INF: continue
			spill[n] = maxf(ground[n],level)
			_heap_push(keys,ids,spill[n],n)
	var sill := spill[start]
	if sill == INF: return {}
	# The hollow: from the start, the cells under the sill.
	var cells := PackedInt32Array()
	var seen := PackedByteArray()
	seen.resize(width*height)
	var stack := PackedInt32Array([start])
	seen[start] = 1
	while not stack.is_empty():
		var c := stack[stack.size()-1]
		stack.resize(stack.size()-1)
		cells.append(c)
		for n: int in [c-1,c+1,c-width,c+width]:
			if n < 0 or n >= width*height or seen[n] != 0 or inside[n] == 0 or ground[n] >= sill: continue
			seen[n] = 1
			stack.append(n)
	return {"cells":cells,"sill":sill}

## Laying `volume` m³ level into `found` (a `hollow`): the water's surface
## (ground + depth) over its cells rises from the lowest up, to the level the
## volume reaches, at most its sill; there it is full, and the rest is not
## laid. With `volume` INF it measures what the hollow still holds.
## {"cells", "rise" (m each), "level", "full", "room" (m³ to the sill)}.
## `depth` is the grid (`depths`), read once by the caller.
func fill_level(found: Dictionary, volume: float, ground: PackedFloat32Array, depth: PackedFloat32Array) -> Dictionary:
	if found.is_empty(): return {}
	var cells: PackedInt32Array = found.cells
	var sill: float = found.sill
	var surface := PackedFloat32Array()
	surface.resize(cells.size())
	var room := 0.0
	for k in cells.size():
		surface[k] = ground[cells[k]]+depth[cells[k]]
		room += maxf(sill-surface[k],0.0)
	var area := cell*cell
	room *= area
	var level := sill
	var full := volume >= room
	if not full:
		# Water-filling: the level where the cells under it hold the volume.
		var sorted := surface.duplicate()
		sorted.sort()
		var budget := volume/area
		var total := 0.0
		level = sorted[sorted.size()-1] if not sorted.is_empty() else sill
		for k in sorted.size():
			total += sorted[k]
			var next := sorted[k+1] if k+1 < sorted.size() else sill
			if (k+1)*next-total >= budget:
				level = (budget+total)/(k+1)
				break
		level = minf(level,sill)
	var rise := PackedFloat32Array()
	rise.resize(cells.size())
	for k in cells.size(): rise[k] = maxf(level-surface[k],0.0)
	return {"cells":cells,"rise":rise,"level":level,"full":full,"room":room}

## M³ the hollow round `at` still holds before it spills.
func room(at: Vector2) -> float:
	if not ready: return 0.0
	var ground := grounds()
	var filled := fill_level(hollow(at,ground),INF,ground,depths())
	return float(filled.room) if not filled.is_empty() else 0.0

static func _heap_push(keys: PackedFloat32Array, ids: PackedInt32Array, key: float, id: int) -> void:
	keys.append(key)
	ids.append(id)
	var k := keys.size()-1
	while k > 0:
		var up := (k-1)/2
		if keys[up] <= key: break
		keys[k] = keys[up]
		ids[k] = ids[up]
		k = up
	keys[k] = key
	ids[k] = id

static func _heap_pop(keys: PackedFloat32Array, ids: PackedInt32Array) -> int:
	var top := ids[0]
	var last := keys.size()-1
	var key := keys[last]
	var id := ids[last]
	keys.resize(last)
	ids.resize(last)
	if last == 0: return top
	var k := 0
	while true:
		var child := k*2+1
		if child >= last: break
		if child+1 < last and keys[child+1] < keys[child]: child += 1
		if keys[child] >= key: break
		keys[k] = keys[child]
		ids[k] = ids[child]
		k = child
	keys[k] = key
	ids[k] = id
	return top

## Standing water: [{"x", "z", "cells", "area", "level", "depth", "rect"}].
func pools() -> Array:
	return kernel.pools(POOL_DEPTH,POOL_SPEED,POOL_CELLS) if ready else []

## Steep drops of moving water: flat x0, y0, z0, x1, y1, z1, flux per fall.
func falls(min_flux: float, min_drop: float, min_slope: float, reach: float) -> PackedFloat32Array:
	return kernel.falls(min_flux,min_drop,min_slope,reach) if ready else PackedFloat32Array()

## Waterfalls traced from the flow (ZenScapeWaterFlow::cascades): lip, plunge,
## flux and a course down the face, for scripts/flow_falls.gd.
func cascades(params: Dictionary) -> Array:
	return kernel.cascades(params) if ready else []

## The water leaving the plate over each edge cell, m³/s smoothed:
## {"sides": [-x, +x, -z, +z] (PackedFloat32Array along each), "total"}.
func edge_outflow() -> Dictionary:
	return kernel.edge_outflow() if ready else {"sides":[],"total":0.0}

## Runs of edge cells water leaves the plate over, for scripts/edge_falls.gd:
## each {"side", "normal" (Vector2, out of the land), "flux", "lip" (Vector3
## where it leaves), "floor", "half", "from", "to", "depth", "speed"}, the
## largest first (ZenScapeWaterFlow::spills has the meaning of each).
## The square plate's come from the kernel, along its four sides. An island
## with an outline leaves over its shore instead (`_shore_spills`), with
## `side` -1.
func spills(params: Dictionary) -> Array:
	if not ready: return []
	if data.outline.is_empty(): return kernel.spills(params)
	if kernel.has_method("edge_leaving"): return _shore_spills(params)
	# A library built before `edge_leaving` lays every lip on the square's
	# rim: keep only those where the land itself reaches it, so no fall
	# hangs in the air off a bay.
	return kernel.spills(params).filter(func(spill: Dictionary) -> bool:
		var lip: Vector3 = spill.lip
		var normal: Vector2 = spill.normal
		return data.ground_height(Vector2(lip.x,lip.z)-normal*0.3) != null)

## Metres from an edge cell's centre to the shore past which its water is
## not leaving over the shore (it drains into the chasm instead).
const SHORE_REACH := 2.0
## The least cosine between two edge cells' ways out for them to pour as one.
const SHORE_TURN := 0.5

## Spills over an island's shore. The edge cells leaving more than
## `cell_min` (ZenScapeWaterFlow::edge_leaving) are joined into runs where
## they lie within `gap` cells of each other on the grid and face the same
## way out (`SHORE_TURN`). Each cell leaves at the nearest point of the shore
## (`_shore_at`), out along the shore's normal there. A run carrying
## `min_flux` is a spill: its lip is the shore point nearest the
## flux-weighted middle of where its cells leave, its normal their
## flux-weighted way out, and its half width, brink depth, speed (out along
## that normal) and water top weighed as the kernel weighs a side's run.
func _shore_spills(params: Dictionary) -> Array:
	var cell_min: float = params.get("cell_min",0.0004)
	var min_flux: float = params.get("min_flux",0.003)
	var gap: int = params.get("gap",1)
	var most: int = params.get("max",8)
	if _shore_for != data.shore_edges:
		_shore_for = data.shore_edges
		_shore_cells.clear()
		_shore_normals.clear()
	var leaving: Dictionary = kernel.edge_leaving(cell_min)
	var cells: PackedInt32Array = leaving.cell
	var rate: PackedFloat32Array = leaving.rate
	var shore: Array[Dictionary] = []
	var at := {}
	for k in range(cells.size()):
		var near := _shore_at(cells[k])
		shore.append(near)
		if not near.is_empty(): at[cells[k]] = k
	# Runs: union the cells within reach of each other that face alike.
	var root := range(cells.size())
	var find := func(k: int) -> int:
		while root[k] != k: k = root[k]
		return k
	var reach := gap+1
	for k in range(cells.size()):
		if shore[k].is_empty(): continue
		var i := cells[k]%width
		var j := cells[k]/width
		for dj in range(0,reach+1):
			for di in range(-reach,reach+1):
				if dj == 0 and di <= 0: continue
				var m: Variant = at.get((j+dj)*width+i+di) if i+di >= 0 and i+di < width else null
				if m == null or (shore[k].normal as Vector2).dot(shore[m].normal) < SHORE_TURN: continue
				var a: int = find.call(k)
				var b: int = find.call(m)
				if a != b: root[maxi(a,b)] = mini(a,b)
	var runs := {}
	for k in range(cells.size()):
		if shore[k].is_empty(): continue
		var r: int = find.call(k)
		if not runs.has(r): runs[r] = []
		runs[r].append(k)
	var surface: PackedFloat32Array = leaving.surface
	var floor: PackedFloat32Array = leaving.floor
	var brink: PackedFloat32Array = leaving.brink
	var velocity: PackedVector2Array = leaving.velocity
	var found := []
	for members: Array in runs.values():
		var q := 0.0
		var point := Vector2.ZERO
		var normal := Vector2.ZERO
		var edges := {}
		for k in members:
			edges[shore[k].edge] = true
			q += rate[k]
			point += (shore[k].point as Vector2)*rate[k]
			normal += (shore[k].normal as Vector2)*rate[k]
		if q < min_flux: continue
		normal = normal.normalized()
		var lip_at: Dictionary = _shore_near(point/q,PackedInt32Array(edges.keys()))
		var across := Vector2(-normal.y,normal.x)
		var t := 0.0
		var tt := 0.0
		var low := INF
		var high := -INF
		var y := 0.0
		var fl := 0.0
		var dep := 0.0
		var sp := 0.0
		for k in members:
			var r := rate[k]
			var a := _cell_centre(cells[k]).dot(across)
			t += r*a
			tt += r*a*a
			low = minf(low,a)
			high = maxf(high,a)
			y += r*surface[k]
			fl += r*floor[k]
			dep += r*brink[k]
			sp += r*maxf(0.0,velocity[k].dot(normal))
		var mid := t/q
		var from := low-0.5*cell
		var to := high+0.5*cell
		var half := minf(0.5*(to-from),sqrt(3.0*maxf(0.0,tt/q-mid*mid))+0.5*cell)
		var lip: Vector2 = lip_at.point
		found.append({"side":-1,"normal":normal,"flux":q,"lip":Vector3(lip.x,y/q,lip.y),"floor":fl/q,"half":half,
			"from":from,"to":to,"depth":dep/q,"speed":sp/q})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.flux > b.flux)
	return found.slice(0,most)

func _cell_centre(c: int) -> Vector2:
	return origin+Vector2((c%width)+0.5,(c/width)+0.5)*cell

## Each edge cell's `_shore_at` and each shore point's summed edge normals,
## for the shore they were found on.
var _shore_cells := {}
var _shore_normals := {}
var _shore_for := PackedInt32Array()

## Where edge cell `c`'s water leaves the island: `_shore_near` its centre,
## or empty when the shore is further than SHORE_REACH (a chasm's bank).
func _shore_at(c: int) -> Dictionary:
	if _shore_cells.has(c): return _shore_cells[c]
	var near := _shore_near(_cell_centre(c))
	if near.is_empty() or (near.point as Vector2).distance_to(_cell_centre(c)) > SHORE_REACH: near = {}
	_shore_cells[c] = near
	return near

## The nearest point on the outline's shore to `p` (NativeTerrainData
## `shore_edges`; only those starting at `among` when given) and the way out
## there: {"point", "normal", "edge"}. Each shore point's way out is the mean
## of its edges' (away from the land face's third corner, as
## scripts/island_shore.gd stands its wall), blended along the edge so it
## turns smoothly round the shore. Empty without a shore.
func _shore_near(p: Vector2, among := PackedInt32Array()) -> Dictionary:
	var edges := data.shore_edges
	var points := data.points
	if _shore_normals.is_empty():
		for k in range(0,edges.size(),3):
			var a := points[edges[k]]
			var b := points[edges[k+1]]
			var out := (b-a).orthogonal().normalized()
			if out.dot(a-points[edges[k+2]]) < 0.0: out = -out
			for i in [edges[k],edges[k+1]]: _shore_normals[i] = _shore_normals.get(i,Vector2.ZERO)+out
	var best := INF
	var found := {}
	for k in (among if not among.is_empty() else range(0,edges.size(),3)):
		var a := points[edges[k]]
		var b := points[edges[k+1]]
		var ab := b-a
		var s := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.000001),0.0,1.0)
		var on := a+ab*s
		var d := on.distance_squared_to(p)
		if d < best:
			best = d
			var way := (_shore_normals[edges[k]] as Vector2).normalized().lerp((_shore_normals[edges[k+1]] as Vector2).normalized(),s)
			found = {"point":on,"normal":way.normalized(),"edge":k}
	return found

## The saved form: springs, and the depth grid deflated as float32, base64.
func encode() -> Dictionary:
	var values: PackedFloat32Array = kernel.get_depth()
	return {"cell":cell,"width":width,"height":height,"springs":springs.duplicate(true),
		"depth":Marshalls.raw_to_base64(values.to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE))}

## A saved form checked for shape, or null. The depth is kept only if it was
## saved on the grid this build runs; the springs always are.
static func decode(value: Variant) -> Variant:
	if not value is Dictionary or not value.get("springs") is Array or value.springs.size() > MAX_SPRINGS: return null
	var found := {"springs":[]}
	for spring: Variant in value.springs:
		if not spring is Dictionary: return null
		for key in ["x","z"]:
			if not GardenData._number(spring.get(key),-Plate.HALF,Plate.HALF): return null
		if not GardenData._number(spring.get("rate"),0.0,1.0) or not GardenData._number(spring.get("radius"),0.05,3.0): return null
		found.springs.append({"x":float(spring.x),"z":float(spring.z),"rate":float(spring.rate),"radius":float(spring.radius)})
	if GardenData._number(value.get("cell"),0.05,2.0) and GardenData._integer(value.get("width")) and GardenData._integer(value.get("height")) and value.get("depth") is String:
		var count := int(value.width)*int(value.height)
		if count > 0 and count <= 1048576:
			var raw := Marshalls.base64_to_raw(value.depth).decompress(count*4,FileAccess.COMPRESSION_DEFLATE)
			if raw.size() == count*4:
				var depths := raw.to_float32_array()
				var sane := true
				for d in depths:
					if not is_finite(d) or d < 0.0 or d > 80.0:
						sane = false
						break
				if sane: found.merge({"cell":float(value.cell),"width":int(value.width),"height":int(value.height),"depth":depths})
	return found

## Undo and redo bring back the springs; a load brings back the water too; a
## new world (no record at all) starts dry.
func _restore(state: Dictionary) -> void:
	bursts.clear()
	if state.has("water_springs"):
		springs.assign(state.water_springs.duplicate(true))
		return
	var saved: Variant = state.get("water_flow")
	springs.clear()
	runoff.reset()
	if not ready:
		if _remapping: _pending = state
		return
	if data.vertex_ids != _topology or data.void_faces != _void: await setup()
	if saved is Dictionary:
		springs.assign(saved.springs)
		if saved.has("depth") and is_equal_approx(float(saved.cell),cell) and int(saved.width) == width and int(saved.height) == height:
			kernel.set_depth(saved.depth)
			return
	var dry := PackedFloat32Array()
	dry.resize(width*height)
	kernel.set_depth(dry)
