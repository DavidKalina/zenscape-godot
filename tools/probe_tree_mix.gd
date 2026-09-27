extends SceneTree
## Headless probe: the tree species mix by stand (emergence.gd `_tree_kind`).
## Wishes a forest over most of the plate, lets it emerge, and prints the
## species counts by habitat and a letter map, so stands show as patches.
## godot --headless --path . -s res://tools/probe_tree_mix.gd -- [seed|-1] [salt]
const Emergence = preload("res://scripts/emergence.gd")
const LETTERS := {"broadleaf":"B","layered_tree":"L","tree":"S","redwood":"R","joshua":"J","cactus":"C","birch":"A","willow":"W","juniper":"P"}
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var world_seed := int(args[0]) if not args.is_empty() and args[0].lstrip("-").is_valid_int() else -1
	var salt := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 7
	var reference = load("res://assets/zen_reference/geometry.scn").instantiate()
	var mesh: ArrayMesh = reference.get_node("terrain").mesh
	reference.free()
	var data := NativeTerrainData.new()
	data.setup(mesh)
	if world_seed < 0:
		data.reset_flat()
	else:
		var recipe: Dictionary = preload("res://scripts/cozy_world_generator.gd").sample(world_seed).terrain
		await preload("res://scripts/inland_landscape.gd").new().form(data,recipe)
	var emergence = Emergence.new(data,salt)
	for z in range(data.MEADOW_CELLS):
		for x in range(data.MEADOW_CELLS):
			if data.meadow_position(x,z).length() < 11.0:
				emergence.intent.forest[z*data.MEADOW_CELLS+x] = 1.0
	emergence.intent.revision += 1
	var before := data.objects.size()
	emergence.on_region_changed(Rect2(-12,-12,24,24))
	for n in range(400): emergence.advance(0.25)
	var by_habitat := {}
	var grid := {}
	var trees := []
	for i in range(before,data.objects.size()):
		var item: Dictionary = data.objects[i]
		if item.get("source") != "emerged" or item.asset not in Emergence.TREES: continue
		var p := Vector2(item.x,item.z)
		var habitat: String = emergence._blend.pick(p)
		var counts: Dictionary = by_habitat.get_or_add(habitat,{})
		counts[item.asset] = counts.get(item.asset,0)+1
		grid[Vector2i((p+Vector2(12,12)).floor())] = LETTERS.get(item.asset,"?")
		trees.append([p,item.asset])
	print("seed %d salt %d" % [world_seed,salt])
	for habitat in by_habitat: print("  %s %s" % [habitat,by_habitat[habitat]])
	# Stand coherence: share of neighbour pairs (under 3 m) of one species,
	# against the share a well-stirred mix of the same counts would give.
	var pairs := 0
	var same := 0
	var totals := {}
	for a in trees: totals[a[1]] = totals.get(a[1],0)+1
	for i in range(trees.size()):
		for j in range(i+1,trees.size()):
			if trees[i][0].distance_to(trees[j][0]) < 3.0:
				pairs += 1
				if trees[i][1] == trees[j][1]: same += 1
	var mixed := 0.0
	for k in totals: mixed += pow(float(totals[k])/trees.size(),2.0)
	print("  neighbours alike %.2f  (well-stirred %.2f, %d pairs)" % [float(same)/maxi(pairs,1),mixed,pairs])
	for z in range(24):
		var row := "  "
		for x in range(24): row += grid.get(Vector2i(x,z),".")+" "
		print(row)
	quit()
