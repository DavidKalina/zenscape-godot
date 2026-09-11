extends SceneTree
## Where on a grown island could a tent stand? Prints a map of the island's
## local XZ, one character per metre, with why each spot is refused, so the
## twin-chunk study's camp search can be tuned against a real landscape.
##   ' ' no ground   '~' water   '^' too steep   'T' a trunk/boulder too near   '.' fine
## how to run
##   Godot --path . --rendering-method forward_plus --script res://tools/probe_island_camp.gd -- --island=valley:11
const SOFT := ["flower", "fern", "leaf_bed", "bank_grass", "button_flower", "spike_flower", "umbel_flower", "daisy_flower", "grass_tuft", "mushroom", "reeds"]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var settings := {"preset": "valley", "seed": 11}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--island="):
			var parts := argument.trim_prefix("--island=").split(":")
			settings = {"preset": parts[0], "seed": int(parts[1]) if parts.size() > 1 else 11}
	var host := Node3D.new()
	root.add_child(host)
	var island: Node3D = await IslandBuilder.build(host, settings)
	root.add_child(island)
	var data: NativeTerrainData = island.data
	var tally := {}
	for item in data.objects:
		tally[item.asset] = int(tally.get(item.asset, 0)) + 1
	print("ISLAND %s: %d records %s" % [island.describe(), data.objects.size(), tally])
	print("ISLAND ponds %d streams %d" % [data.ponds.size(), data.streams.size()])
	print("--- min ground spread over four door headings, in dm (9 = 0.9 m or more), x -6..6")
	for z in range(-13, 14):
		var row := "%+3d " % z
		for x in range(-6, 7):
			var spread := _spread(island, Vector2(x, z))
			row += " " if spread == INF else str(mini(9, int(spread * 10.0)))
		print(row)
	print("--- distance to nearest trunk/boulder edge, in m (9 = 9 m or more), x -6..6")
	for z in range(-13, 14):
		var row := "%+3d " % z
		for x in range(-6, 7):
			row += str(mini(9, int(_clearance(data, Vector2(x, z)))))
		print(row)
	for flatness in [0.4, 0.6, 0.8]:
		print("--- flatness %.1f, clearance 2.6 (columns x -13..13, rows z -13..13)" % flatness)
		var fine := 0
		for z in range(-13, 14):
			var row := "%+3d " % z
			for x in range(-13, 14):
				var point := Vector2(x, z)
				var mark := _mark(island, point, flatness, 2.6)
				if mark == ".": fine += 1
				row += mark
			print(row)
		print("fine spots: %d" % fine)
	quit()

## Ground spread over the pegs plus the door and first stride, best of four headings.
func _spread(island: Node3D, point: Vector2) -> float:
	var data: NativeTerrainData = island.data
	var best := INF
	for heading: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
		var door := Vector2(sin(heading), cos(heading))
		var low := INF
		var high := -INF
		var bad := false
		for offset: Vector2 in [Vector2.ZERO, Vector2(1.15, 1.18), Vector2(-1.15, 1.18), Vector2(1.15, -1.18), Vector2(-1.15, -1.18), door * 2.3, door * 3.3]:
			var at := point + offset
			var height: Variant = data.ground_height(at)
			if height == null or island.flooded_at(at):
				bad = true
				break
			low = minf(low, float(height))
			high = maxf(high, float(height))
		if not bad: best = minf(best, high - low)
	return best

func _clearance(data: NativeTerrainData, point: Vector2) -> float:
	var nearest := INF
	for item: Dictionary in data.objects:
		if item.asset in SOFT: continue
		nearest = minf(nearest, Vector2(float(item.x), float(item.z)).distance_to(point) - 0.5 * float(item.scale))
	return maxf(0.0, nearest)

func _mark(island: Node3D, point: Vector2, flatness: float, clearance: float) -> String:
	var data: NativeTerrainData = island.data
	var low := INF
	var high := -INF
	for offset: Vector2 in [Vector2.ZERO, Vector2(1.3, 1.3), Vector2(-1.3, 1.3), Vector2(1.3, -1.3), Vector2(-1.3, -1.3), Vector2(2.3, 0.0), Vector2(3.3, 0.0)]:
		var at := point + offset
		var height: Variant = data.ground_height(at)
		if height == null: return " "
		if island.flooded_at(at): return "~"
		low = minf(low, float(height))
		high = maxf(high, float(height))
	if high - low > flatness: return "^"
	for item: Dictionary in data.objects:
		if item.asset in SOFT: continue
		if Vector2(float(item.x), float(item.z)).distance_to(point) < clearance + 0.5 * float(item.scale): return "T"
	return "."
