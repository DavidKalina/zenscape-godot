extends SceneTree
## Ravines fill: a gorge cut by the Ravine (scripts/clay_tools/wire.gd
## `cut_gorge`) is a hollow the watering can reads and fills level, to the
## water the player pours (half, then brimmed). A ravine run out through the
## plate's rim keeps a sill, a notch in the rim, so it holds water to the
## notch instead of draining to the open side (it held ~7 m3 before).
const Wire = preload("res://scripts/clay_tools/wire.gd")

var failures := 0

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

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func ravine(from: Vector2, to: Vector2) -> Array:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.reset_flat()
	var heights := data.heights.duplicate()
	var clay := FakeClay.new()
	clay.editor.data = data
	clay.base = heights.duplicate()
	var wire := Wire.new()
	wire.clay = clay
	var path := PackedVector2Array()
	for k in 33: path.append(from.lerp(to,k/32.0))
	wire.cut_gorge(heights,path)
	data.heights = heights
	var flow: RefCounted = preload("res://scripts/water_flow.gd").new(data)
	await flow.setup()
	flow.run(1)
	clay.free()
	return [data,flow]

## Pours `volume` m3 into the hollow at `at` through a lift and lets it settle.
func pour(flow: RefCounted, at: Vector2, volume: float) -> void:
	var seconds := 0.0
	flow.lifts["test"] = [at.x,at.y,volume/4.0]
	while seconds < 4.0 and not flow.brimmed.has("test"):
		flow.run(4)
		seconds += 4.0*flow.dt
	flow.lifts.erase("test")
	for i in 120: flow.run(4)

## Water surface (ground + depth) at `at`.
func level_at(flow: RefCounted, at: Vector2) -> float:
	return float(flow.grounds()[flow.cell_at(at)])+float(flow.depth_at(at))

func closed_ravine() -> void:
	var made: Array = await ravine(Vector2(-8,0),Vector2(8,0))
	var data: NativeTerrainData = made[0]
	var flow: RefCounted = made[1]
	var mid := Vector2.ZERO
	var ground: PackedFloat32Array = flow.grounds()
	var found: Dictionary = flow.hollow(mid,ground)
	check(not found.is_empty() and absf(float(found.sill)) < 0.1,"A ravine inside the plate is a hollow to the plain round it (%s)" % found.get("sill"))
	var room: float = flow.room(mid)
	check(room > 60.0,"It holds a lake (%.0f m3)" % room)
	# The can reads it as a hollow, anywhere along it.
	var can: Node = preload("res://scripts/watering_can.gd").new()
	can.flow = flow
	can.ground_at = func(point: Vector2) -> Variant: return data.ground_height(point)
	for x in [-6.0,0.0,6.0]: check(can._basin(Vector2(x,0)),"The can gushes in the ravine at x=%.0f" % x)
	can.free()
	# Half the room poured: water stands level between the bed and the rim.
	pour(flow,mid,room*0.5)
	var bed: float = data.ground_height(mid)
	var low := level_at(flow,Vector2(-5,0))
	var high := level_at(flow,Vector2(5,0))
	check(flow.depth_at(mid) > 0.5,"Water stands in the ravine (%.2f m)" % flow.depth_at(mid))
	check(low > bed and high < 0.0,"Half full stands between its bed and its rim (%.2f, %.2f)" % [low,high])
	check(absf(low-high) < 0.25,"The water lies level along the ravine (%.2f vs %.2f)" % [low,high])
	check(absf(flow.volume()-room*0.5) < room*0.1,"It holds what was poured (%.0f of %.0f m3)" % [flow.volume(),room*0.5])
	# Poured to the brim, it stands at the rim.
	pour(flow,mid,room*2.0)
	check(absf(level_at(flow,mid)) < 0.25,"Brimmed it stands at the rim (%.2f)" % level_at(flow,mid))

func open_ravine() -> void:
	var made: Array = await ravine(Vector2(-14.6,0),Vector2(14.6,0))
	var data: NativeTerrainData = made[0]
	var flow: RefCounted = made[1]
	var mid := Vector2.ZERO
	var ground: PackedFloat32Array = flow.grounds()
	var found: Dictionary = flow.hollow(mid,ground)
	var bed_end: float = data.ground_height(Vector2(13.0,0))
	check(not found.is_empty() and float(found.sill) > bed_end+1.0,"A ravine run out through the rim has a sill above its bed (%s)" % found.get("sill"))
	check(float(found.sill) < -0.3,"and the sill is a notch under the rim, not the rim (%s)" % found.get("sill"))
	var room: float = flow.room(mid)
	check(room > 60.0,"It holds a lake to the notch (%.0f m3; ~7 before the sill)" % room)
	pour(flow,mid,room*2.0)
	check(flow.depth_at(mid) > 1.2,"Poured full it stands deep (%.2f m)" % flow.depth_at(mid))
	var level := level_at(flow,mid)
	check(absf(level-float(found.sill)) < 0.3,"at the notch's level (%.2f, notch %.2f)" % [level,found.sill])
	check(absf(level_at(flow,Vector2(-8,0))-level) < 0.25,"level all along (%.2f)" % level_at(flow,Vector2(-8,0)))

func run() -> void:
	await closed_ravine()
	await open_ravine()
	print("Ravine fill: %d failures" % failures)
	quit(1 if failures > 0 else 0)
