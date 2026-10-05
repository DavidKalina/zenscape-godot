extends SceneTree
## Headless probe: does a deep lake stand still? A crater DEPTH m deep is
## filled level to its brim through a lift (WaterFlow `lifts`), the lift is
## stopped, a small burst lands in the middle, and the lake is stepped on.
## Prints the middle's depth, the deepest and shallowest water over the
## crater's floor and the volume each second.
##   Godot --headless --path . --script res://tools/probe_deep_lake.gd -- --depth=7

const CENTER := Vector2.ZERO
const PlateFixture := preload("res://tests/fixtures/plate.gd")
var RADIUS := 8.0
var DEPTH := 7.0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--depth="): DEPTH = float(arg.trim_prefix("--depth="))
		if arg.begins_with("--radius="): RADIUS = float(arg.trim_prefix("--radius="))
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	data.reset_flat()
	var heights := data.heights.duplicate()
	for i in heights.size():
		var d := (data.points[i] as Vector2).distance_to(CENTER)
		heights[i] = maxf(heights[i]-DEPTH*(1.0-smoothstep(RADIUS*0.45,RADIUS*0.95,d)),NativeTerrainData.MIN_HEIGHT)
	data.heights = heights
	var flow: RefCounted = preload("res://scripts/water_flow.gd").new(data)
	await flow.setup()
	flow.run(1)
	var room: float = flow.room(CENTER)
	flow.lifts["probe"] = [CENTER.x,CENTER.y,room/4.0]
	var t := 0.0
	while not flow.brimmed.has("probe") and t < 30.0:
		flow.run(1)
		t += flow.dt
	flow.lifts.erase("probe")
	print(JSON.stringify({"native":flow.native,"room_m3":snappedf(room,1.0),"brimmed_s":snappedf(t,0.1)}))
	var floor_cells := PackedInt32Array()
	var ground: PackedFloat32Array = flow.grounds()
	for c in ground.size():
		if ground[c] < -DEPTH*0.8: floor_cells.append(c)
	for second in 20:
		if second == 2: flow.add_burst(CENTER,1.0) if flow.has_method("add_burst") else flow.kernel.add_water(CENTER,0.5,1.0)
		for k in 60: flow.run(1)
		var depth: PackedFloat32Array = flow.depths()
		var low := INF
		var high := -INF
		for c in floor_cells:
			low = minf(low,depth[c])
			high = maxf(high,depth[c])
		print(JSON.stringify({"s":second+1,"middle":snappedf(flow.depth_at(CENTER),0.01),"floor_min":snappedf(low,0.01),"floor_max":snappedf(high,0.01),"volume":snappedf(flow.volume(),1.0)}))
	quit(0)
