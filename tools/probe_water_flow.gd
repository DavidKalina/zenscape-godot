extends SceneTree
## Headless probe of the live water (scripts/water_flow.gd,
## docs/scenic/water-flow.md). Opens the cozy worlds scene for its real
## terrain mesh, then shapes the heights directly (nothing is rendered or
## refreshed) and runs the simulation in fixed steps:
##   1. peak, groove, basin: a 4 m peak, a groove 1 m deep and 2.5 m wide from
##      high on its flank down to a pressed basin; a ball dropped at the
##      groove's head becomes a spring, and the water must end up in the basin;
##   2. the land changes under standing water: a trench is cut from the full
##      basin to a second, lower basin, and the water must move into it;
##   3. a ball dropped on low flat ground lets its water go once (no spring);
##   4. a spring runs for five minutes and its water must level off;
##   5. save and load keep the spring and the water; undo removes the spring;
##   6. ms per step, native against the GDScript mirror.
##   godot --headless --path . -s res://tools/probe_water_flow.gd -- --plain-seed 7 [--gdscript-kernels]
var scene: Node3D
var data: NativeTerrainData
var failures := []
const WaterFlow := preload("res://scripts/water_flow.gd")

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

## Sets heights from a function of plate position.
func shape(height: Callable) -> void:
	for i in range(data.points.size()): data.heights[i] = height.call(data.points[i])

static func bump(p: Vector2, center: Vector2, radius: float, rise: float) -> float:
	var t := p.distance_squared_to(center)/(radius*radius)
	return rise*(1.0-t)*(1.0-t) if t < 1.0 else 0.0

## Distance from `p` to the segment a-b, and the share along it.
static func along(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b-a
	var t := clampf((p-a).dot(ab)/ab.length_squared(),0.0,1.0)
	return Vector2(p.distance_to(a+ab*t),t)

## The test land: a plain at 0, a 4 m peak, a groove from high on the peak's
## flank down to a pressed basin, and (with `trench`) a trench from that basin
## on to a second, lower basin.
const PEAK := Vector2(-6.0,-1.0)
const HEAD := Vector2(-4.6,-1.0)
const BASIN := Vector2(3.0,-1.0)
const BASIN_TWO := Vector2(3.0,6.5)
static func land(p: Vector2, trench := false) -> float:
	var h := bump(p,PEAK,6.0,4.0)
	# The groove: its bed falls steadily from 0.9 m under the flank at its head
	# to the basin's floor, (1 - t²)² across 1.25 m either side.
	var g := along(p,HEAD,BASIN)
	if g.x < 1.25:
		var head_ground := bump(HEAD,PEAK,6.0,4.0)
		var bed := lerpf(head_ground-0.9,-0.9,g.y)
		var s := g.x/1.25
		h = minf(h,lerpf(bed,h,1.0-(1.0-s*s)*(1.0-s*s)))
	# The palm-pressed basin, 1.2 m deep over 3 m.
	h = minf(h,-bump(p,BASIN,3.0,1.2)) if p.distance_to(BASIN) < 3.0 else h
	if trench:
		var t := along(p,BASIN+Vector2(0,1.5),BASIN_TWO)
		if t.x < 1.0:
			var s := t.x
			h = minf(h,lerpf(lerpf(-0.9,-1.3,t.y),h,1.0-(1.0-s*s)*(1.0-s*s)))
		h = minf(h,-bump(p,BASIN_TWO,3.0,1.45)) if p.distance_to(BASIN_TWO) < 3.0 else h
	return h

## m³ of water within `radius` of `center`.
func water_near(flow: RefCounted, center: Vector2, radius: float) -> float:
	var depths: PackedFloat32Array = flow.depths()
	var total := 0.0
	for j in range(flow.height):
		for i in range(flow.width):
			var p: Vector2 = flow.origin+Vector2(i+0.5,j+0.5)*flow.cell
			if p.distance_to(center) < radius: total += depths[j*flow.width+i]
	return total*flow.cell*flow.cell

## m³ inside the groove's footprint, basin excluded.
func water_in_groove(flow: RefCounted) -> float:
	var depths: PackedFloat32Array = flow.depths()
	var total := 0.0
	for j in range(flow.height):
		for i in range(flow.width):
			var p: Vector2 = flow.origin+Vector2(i+0.5,j+0.5)*flow.cell
			if along(p,HEAD,BASIN).x < 1.4 and p.distance_to(BASIN) >= 3.0: total += depths[j*flow.width+i]
	return total*flow.cell*flow.cell

func simulate(flow: RefCounted, seconds: float) -> void:
	flow.run(roundi(seconds/flow.dt))

func level(flow: RefCounted, p: Vector2) -> float:
	var at: int = flow.cell_at(p)
	return flow.grounds()[at]+flow.depths()[at]

func run() -> void:
	create_timer(170).timeout.connect(func() -> void: push_error("Water flow probe timed out"); quit(2))
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-flow-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_process(false)
	data = editor.data
	var prefer_native := "--gdscript-kernels" not in OS.get_cmdline_user_args()
	var began := Time.get_ticks_usec()
	var flow: RefCounted = WaterFlow.new(data,prefer_native)
	await flow.setup()
	print("SETUP ",JSON.stringify({"native":flow.native,"cell":flow.cell,"grid":[flow.width,flow.height],"origin":str(flow.origin),"points":data.points.size(),"faces":data.vertex_ids.size()/3,"map_ms":snappedf((Time.get_ticks_usec()-began)/1000.0,0.1)}))
	if prefer_native: check("the native kernel is taken",flow.native)

	# 1. Peak, groove, basin.
	shape(func(p: Vector2) -> float: return land(p))
	data.begin_stroke()
	data.end_stroke()
	var undo_depth := data._undo.size()
	var kind: String = flow.drop(HEAD,6.0)
	check("a ball at the groove's head on the flank is a spring",kind == "spring",kind)
	check("the spring is its own undo step",data._undo.size() == undo_depth+1)
	var spring_rate: float = flow.springs[0].rate if not flow.springs.is_empty() else 0.0
	var elapsed := 0.0
	for t in [5.0,15.0,30.0,60.0]:
		simulate(flow,t-elapsed)
		elapsed = t
		var s: Dictionary = flow.stats()
		print("PEAK t=%ds " % t,JSON.stringify({"basin_m3":snappedf(water_near(flow,BASIN,3.0),0.01),"groove_m3":snappedf(water_in_groove(flow),0.01),"total_m3":snappedf(s.volume,0.01),"poured":snappedf(s.poured,0.01),"drained":snappedf(s.drained,0.01),"soaked":snappedf(s.soaked,0.01),"basin_level":snappedf(level(flow,BASIN),0.01),"step_us":s.last_step_usec}))
	var basin: float = water_near(flow,BASIN,3.0)
	var total: float = flow.volume()
	var elsewhere: float = total-basin-water_in_groove(flow)
	check("water ends up in the basin",basin > 0.6*total and basin > 3.0,"basin %.2f of %.2f m³, spring %.3f m³/s" % [basin,total,spring_rate])
	check("little water strays outside the groove and basin",elsewhere < 0.1*total,"%.2f m³" % elsewhere)
	check("the basin holds a pond",level(flow,BASIN)-flow.grounds()[flow.cell_at(BASIN)] > 0.3)
	var pools: Array = flow.pools()
	check("the basin reads as a pool",pools.any(func(pool: Dictionary) -> bool: return Vector2(pool.x,pool.z).distance_to(BASIN) < 3.0),str(pools.map(func(pool: Dictionary) -> String: return "(%.1f, %.1f) %.1f m²" % [pool.x,pool.z,pool.area])))
	var falls: PackedFloat32Array = flow.falls(0.02,0.6,0.7,1.5)
	# Moving water carries its velocity in CUSTOM1.yz for the stream shader's
	# flow map, pointing downhill along the groove (towards the basin, +x).
	var moving: Dictionary = flow.surface({}).flow
	var custom1: PackedFloat32Array = moving.custom1
	var downhill := 0
	var carried := 0
	for v in range(custom1.size()/4):
		var velocity := Vector2(custom1[v*4+1],custom1[v*4+2])
		if velocity.length() < 0.05: continue
		carried += 1
		if velocity.x > 0.0: downhill += 1
	check("moving water carries its velocity, mostly downhill",carried > 20 and downhill > 0.7*carried,"%d of %d vertices downhill" % [downhill,carried])
	print("FALLS ",falls.size()/7," ",Array(falls).map(func(v: float) -> float: return snappedf(v,0.01)))

	# 2. The land changes under the standing water: a trench to a lower basin.
	var before_one: float = water_near(flow,BASIN,3.0)
	flow.springs.clear()
	simulate(flow,4.0)
	before_one = water_near(flow,BASIN,3.0)
	var level_one: float = level(flow,BASIN)
	shape(func(p: Vector2) -> float: return land(p,true))
	simulate(flow,30.0)
	var after_one: float = water_near(flow,BASIN,3.0)
	var after_two: float = water_near(flow,BASIN_TWO,3.0)
	print("TRENCH ",JSON.stringify({"basin_before":snappedf(before_one,0.01),"level_before":snappedf(level_one,0.01),"basin_after":snappedf(after_one,0.01),"level_after":snappedf(level(flow,BASIN),0.01),"second_basin":snappedf(after_two,0.01)}))
	check("cutting a trench drains the pond into the new basin",after_two > 1.0 and after_one < before_one-1.0,"%.2f → %.2f, second %.2f" % [before_one,after_one,after_two])

	# 3. A ball on low flat ground lets its water go once.
	var flat := Vector2(-8.0,8.0)
	var springs_before: int = flow.springs.size()
	kind = flow.drop(flat,4.0)
	check("a ball on low flat ground is a burst, not a spring",kind == "burst" and flow.springs.size() == springs_before,kind)
	simulate(flow,2.0)
	check("the burst has let all its water go",flow.bursts.is_empty())
	var spread: float = water_near(flow,flat,4.0)
	simulate(flow,60.0)
	print("BURST ",JSON.stringify({"after_2s":snappedf(spread,0.01),"after_62s":snappedf(water_near(flow,flat,4.0),0.01)}))
	check("water on flat ground soaks away rather than staying",water_near(flow,flat,4.0) < spread)

	# 4. A steady spring levels off.
	shape(func(p: Vector2) -> float: return land(p))
	flow.drain(Vector2.ZERO,40.0)
	flow.drop(HEAD,6.0)
	var volumes := []
	for minute in range(5):
		simulate(flow,60.0)
		volumes.append(snappedf(flow.volume(),0.01))
	var s: Dictionary = flow.stats()
	print("STEADY ",JSON.stringify({"volume_by_minute":volumes,"poured":snappedf(s.poured,0.1),"drained":snappedf(s.drained,0.1),"soaked":snappedf(s.soaked,0.1),"wet_cells":s.wet_cells}))
	check("a steady spring reaches equilibrium",absf(volumes[4]-volumes[3]) < 0.05*volumes[4]+0.2,str(volumes))
	check("it does not flood the plate",int(s.wet_cells)*flow.cell*flow.cell < 0.4*28.0*28.0,"%.0f m² wet" % (int(s.wet_cells)*flow.cell*flow.cell))

	# 5. Save, load and undo.
	var document := data.to_document()
	check("the place saves its water",document.has("water_flow"))
	var saved_volume: float = flow.volume()
	flow.drain(Vector2.ZERO,40.0)
	check("a drain takes the spring",flow.springs.is_empty())
	check("load brings back the spring and the water",data.load_document(JSON.parse_string(JSON.stringify(document))) and flow.springs.size() == 1 and absf(flow.volume()-saved_volume) < 0.01,"%.2f vs %.2f" % [flow.volume(),saved_volume])
	data.begin_stroke()
	data.end_stroke()
	flow.drop(PEAK,3.0)
	check("a second spring",flow.springs.size() == 2)
	data.undo()
	check("undo removes the spring",flow.springs.size() == 1)
	data.redo()
	check("redo brings it back",flow.springs.size() == 2)

	# 6. Cost per step.
	var samples: Array[int] = []
	for i in range(120):
		flow.run(1)
		samples.append(flow.last_step_usec)
	samples.sort()
	var surface_began := Time.get_ticks_usec()
	var arrays: Dictionary = flow.surface({})
	var surface_usec := Time.get_ticks_usec()-surface_began
	print("COST ",JSON.stringify({"native":flow.native,"cells":flow.width*flow.height,"step_us_median":samples[60],"step_us_p95":samples[113],"surface_us":surface_usec,"still_vertices":arrays.still.vertices.size(),"flow_vertices":arrays.flow.vertices.size()}))
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
