extends SceneTree
## Headless probe: the real Ravine cut (scripts/clay_tools/wire.gd `cut_gorge`)
## on flat or sloped land: what does WaterFlow make of it, and does the
## watering can read it as a hollow?
##   Godot --headless --path . --script res://tools/probe_ravine_fill.gd -- --slope=0.15 --from=-8,0 --to=8,0 --pips=1
const Wire = preload("res://scripts/clay_tools/wire.gd")
const PlateFixture := preload("res://tests/fixtures/plate.gd")

class FakeEditor:
	var data: NativeTerrainData
class FakeClay extends Node:
	var base := PackedFloat32Array()
	var editor := FakeEditor.new()
	var size_scale := 1.0
	var near := PackedInt32Array()
	func gather(at: Vector2, radius: float) -> void:
		near = PackedInt32Array()
		var points := editor.data.points
		for i in points.size():
			if points[i].distance_to(at) < radius: near.append(i)

func _initialize() -> void: run.call_deferred()
func run() -> void:
	var slope := 0.0
	var from := Vector2(-8,0)
	var to := Vector2(8,0)
	var scale := 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--slope="): slope = float(arg.trim_prefix("--slope="))
		if arg.begins_with("--pips="): scale = float(arg.trim_prefix("--pips="))
		if arg.begins_with("--start="): from = Vector2(float(arg.get_slice("=",1).get_slice(",",0)),float(arg.get_slice(",",1)))
		if arg.begins_with("--finish="): to = Vector2(float(arg.get_slice("=",1).get_slice(",",0)),float(arg.get_slice(",",1)))
	var data := NativeTerrainData.new()
	data.setup(PlateFixture.mesh())
	data.reset_flat()
	var heights := data.heights.duplicate()
	for i in heights.size(): heights[i] += slope*(data.points[i] as Vector2).x
	var clay := FakeClay.new()
	clay.editor.data = data
	clay.base = heights.duplicate()
	clay.size_scale = scale
	var wire := Wire.new()
	wire.clay = clay
	var path := PackedVector2Array()
	for k in 33: path.append(from.lerp(to,k/32.0))
	wire.cut_gorge(heights,path)
	data.heights = heights
	var flow: RefCounted = preload("res://scripts/water_flow.gd").new(data)
	await flow.setup()
	flow.run(1)
	var ground: PackedFloat32Array = flow.grounds()
	var can: Node = preload("res://scripts/watering_can.gd").new()
	can.flow = flow
	can.ground_at = func(p: Vector2) -> Variant: return data.ground_height(p)
	for k in 5:
		var at := from.lerp(to,(k+0.5)/5.0)
		var found: Dictionary = flow.hollow(at,ground)
		print(at," sill ",found.get("sill")," cells ",(found.get("cells",PackedInt32Array()) as PackedInt32Array).size()," room ",flow.room(at)," ground ",data.ground_height(at)," basin ",can._basin(at))
	quit(0)
