extends SceneTree
## Lakes: a hollow is found from the ground to its sill, water laid into it
## rises level and stops there (WaterFlow `hollow`, `fill_level`, `lifts`),
## and a lake steeps to tea in what grows round it (scripts/lake_tea.gd).
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

const CENTER := Vector2(1.0,-2.0)
const RADIUS := 6.0
## Deeper than the 5.7 m the pipes were stable to at the old fixed step.
const DEPTH := 7.0

func run() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.reset_flat()
	# A crater with a low ring of bumps inside its wall, which must not read
	# as its rim.
	var heights := data.heights.duplicate()
	for i in heights.size():
		var d := (data.points[i] as Vector2).distance_to(CENTER)
		heights[i] -= DEPTH*(1.0-smoothstep(RADIUS*0.4,RADIUS,d))
		if absf(d-RADIUS*0.6) < 0.4: heights[i] += 0.15
	data.heights = heights
	var flow: RefCounted = preload("res://scripts/water_flow.gd").new(data)
	await flow.setup()
	flow.run(1)
	var ground: PackedFloat32Array = flow.grounds()
	var found: Dictionary = flow.hollow(CENTER+Vector2(RADIUS*0.7,0.0),ground)
	check(not found.is_empty(),"A crater is a hollow")
	check(absf(float(found.sill)) < 0.1,"Its sill is the plain round it, not the bumps in its wall (%s)" % found.get("sill"))
	var floor_y := INF
	for c: int in (found.cells as PackedInt32Array): floor_y = minf(floor_y,ground[c])
	check(floor_y < -DEPTH*0.9,"A press on its wall finds the floor")
	var room: float = flow.room(CENTER)
	check(room > 100.0,"The crater holds a lake (%.0f m³)" % room)
	var half: Dictionary = flow.fill_level(found,room*0.5,ground,flow.depths())
	var laid := 0.0
	for r: float in (half.rise as PackedFloat32Array): laid += r*flow.cell*flow.cell
	check(not half.full and absf(laid-room*0.5) < room*0.01,"Half the room is laid, all of it, and not full")
	check(float(half.level) > floor_y and float(half.level) < float(found.sill),"Half full stands between floor and sill")
	var over: Dictionary = flow.fill_level(found,room*2.0,ground,flow.depths())
	check(over.full and is_equal_approx(float(over.level),float(found.sill)),"More than the room stops at the sill")
	# Poured through a lift at 40 m³/s, the crater fills level to its brim.
	flow.lifts["test"] = [CENTER.x,CENTER.y,40.0]
	var seconds := 0.0
	while not flow.brimmed.has("test") and seconds < 60.0:
		flow.run(4)
		seconds += 4.0*flow.dt
	flow.lifts.erase("test")
	check(flow.brimmed.has("test"),"The lift brims (%.1f s)" % seconds)
	check(seconds < room/40.0*1.3,"It brims about when the room is poured (%.1f s for %.0f m³)" % [seconds,room])
	check(flow.volume() > room*0.9,"The lake holds its room (%.0f of %.0f m³)" % [flow.volume(),room])
	for i in 60: flow.run(4)
	var settled: float = flow.depth_at(CENTER)
	check(settled > DEPTH*0.9,"The lake stands deep in the middle (%.2f m)" % settled)
	# A splash on deep water ripples and is gone: it blew the lake up when its
	# steps were longer than the waves allow (WaterFlow `substeps`).
	check(flow.substeps() > 1,"Water this deep steps in shorter steps")
	flow.kernel.add_water(CENTER,0.5,1.0)
	var worst := 0.0
	for i in 45:
		flow.run(4)
		worst = maxf(worst,absf(flow.depth_at(CENTER)-settled))
	check(worst < 0.3,"A splash on the deep lake does not blow it up (%.2f m at most)" % worst)
	# Tea: a bare crater is clear; ringed with reeds and pines, it steeps.
	var pools: Array = flow.pools()
	check(not pools.is_empty(),"The lake is a pool")
	var lake: Dictionary = pools[0]
	var tea := preload("res://scripts/lake_tea.gd").new()
	check(tea.target(lake,[]) == 0.0,"A bare crater lake is clear")
	var shore: Array = []
	for k in 24:
		var at := CENTER+Vector2.from_angle(k*TAU/24.0)*(RADIUS+0.5)
		shore.append({"asset":"reeds" if k%2 == 0 else "redwood","x":at.x,"z":at.y})
	shore.append({"asset":"rock","x":CENTER.x,"z":CENTER.y})
	var aim: float = tea.target(lake,shore)
	check(aim > 0.4,"Ringed with reeds and redwoods it steeps (%.2f)" % aim)
	var far := [{"asset":"reeds","x":13.0,"z":13.0}]
	check(tea.target(lake,far) == 0.0,"Reeds far from the shore do not steep it")
	tea.steep(pools,shore,flow,1.0)
	check(tea.tea_at(CENTER) > 0.0 and tea.tea_at(CENTER) < aim*0.1,"It steeps over time, not at once")
	var wandered := lake.duplicate()
	wandered.x = float(lake.x)+4.0
	var before: float = tea.tea_at(CENTER)
	tea.steep([wandered],shore,flow,1.0)
	check(tea.tea_at(CENTER) > before,"A lake whose deepest cell wanders keeps steeping (%.3f after %.3f)" % [tea.tea_at(CENTER),before])
	tea.steep(pools,shore,flow,1.0,true)
	check(is_equal_approx(tea.tea_at(CENTER),aim),"A load takes the target at once")
	var middle: int = flow.cell_at(CENTER)
	check(tea.grid[middle] > 0,"The tea map is painted over the lake")
	check(tea.grid[flow.cell_at(Vector2(-13.0,13.0))] == 0,"and nowhere else")
	print("Lake fill: %d failures" % failures)
	quit(1 if failures > 0 else 0)
