extends SceneTree
## Headless probe: the tree species mix by stand (emergence.gd `_tree_kind`).
## Wishes a forest over most of the plate, lets it emerge, and prints the
## species counts by habitat and a letter map, so stands show as patches, then
## the deciduous stands' autumn characters (emergence.gd `_stand_autumn`):
## c turns early to copper, a stops at amber, g hangs on green and goes gold.
## Dead wood (snag n, log -, stump o) is counted by habitat and by old or
## young stand, with its share of the wood, and spruce dead tops by stand.
## godot --headless --path . -s res://tools/probe_tree_mix.gd -- [seed|-1] [salt]
const Emergence = preload("res://scripts/emergence.gd")
const LETTERS := {"broadleaf":"B","layered_tree":"L","tree":"S","redwood":"R","joshua":"J","cactus":"C","birch":"A","willow":"W","juniper":"P","snag":"n","log":"-","stump":"o"}
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
	var autumn := {}
	var trees := []
	# [living, dead, spruces, dead tops] by old and young stand.
	var by_age := {true:[0,0,0,0],false:[0,0,0,0]}
	var dead_kinds := {}
	for i in range(before,data.objects.size()):
		var item: Dictionary = data.objects[i]
		var dead: bool = item.asset in Emergence.DEAD_KINDS
		if item.get("source") != "emerged" or (item.asset not in Emergence.TREES and not dead): continue
		var p := Vector2(item.x,item.z)
		var habitat: String = emergence._blend.pick(p)
		var counts: Dictionary = by_habitat.get_or_add(habitat,{})
		counts[item.asset] = counts.get(item.asset,0)+1
		grid[Vector2i((p+Vector2(12,12)).floor())] = LETTERS.get(item.asset,"?")
		var age: Array = by_age[emergence.old_stand(emergence._stand(p))]
		age[1 if dead else 0] += 1
		if dead:
			dead_kinds[item.asset] = dead_kinds.get(item.asset,0)+1
			continue
		if item.asset == "tree":
			age[2] += 1
			if preload("res://scripts/hero_trees.gd").spruce_index(item) == 5: age[3] += 1
		trees.append([p,item.asset])
		if item.asset in ["broadleaf","layered_tree"]:
			autumn[Vector2i((p+Vector2(12,12)).floor())] = "c" if item.autumn > 0.65 else ("a" if item.autumn >= 0.2 else "g")
	print("seed %d salt %d" % [world_seed,salt])
	for habitat in by_habitat: print("  %s %s" % [habitat,by_habitat[habitat]])
	# Stand coherence: share of neighbour pairs (under 3 m) of one species,
	# against the share a well-stirred mix of the same counts would give.
	var pairs := 0
	var alike := 0
	var totals := {}
	for a in trees: totals[a[1]] = totals.get(a[1],0)+1
	for i in range(trees.size()):
		for j in range(i+1,trees.size()):
			if trees[i][0].distance_to(trees[j][0]) < 3.0:
				pairs += 1
				if trees[i][1] == trees[j][1]: alike += 1
	var mixed := 0.0
	for k in totals: mixed += pow(float(totals[k])/trees.size(),2.0)
	for old in [true,false]:
		var age: Array = by_age[old]
		print("  %s stands: %d trees, %d dead (%.1f%%), %d of %d spruces dead-topped" % ["old" if old else "young",age[0],age[1],100.0*age[1]/maxi(age[0]+age[1],1),age[3],age[2]])
	print("  dead wood %s" % dead_kinds)
	# Dead wood keeps its pose and tint through a save, and spruces their variant.
	var copy := NativeTerrainData.new()
	copy.setup(mesh)
	var loaded := copy.load_document(JSON.parse_string(JSON.stringify(data.to_document())))
	var same := loaded and copy.objects.size() == data.objects.size()
	for i in range(mini(copy.objects.size(),data.objects.size())):
		var x: Dictionary = data.objects[i]
		var y: Dictionary = copy.objects[i]
		if x.get("pose") != y.get("pose") or x.get("tint") != y.get("tint") or (x.asset == "tree" and preload("res://scripts/hero_trees.gd").spruce_index(x) != preload("res://scripts/hero_trees.gd").spruce_index(y)): same = false
	print("  save round trip keeps dead wood and spruce variants: %s" % same)
	print("  neighbours alike %.2f  (well-stirred %.2f, %d pairs)" % [float(alike)/maxi(pairs,1),mixed,pairs])
	for z in range(24):
		var row := "  "
		for x in range(24): row += grid.get(Vector2i(x,z),".")+" "
		row += "   "
		for x in range(24): row += autumn.get(Vector2i(x,z),".")+" "
		print(row)
	quit()
