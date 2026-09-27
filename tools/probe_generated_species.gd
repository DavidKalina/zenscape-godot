extends SceneTree
## Headless probe: the tree species a generated world plants (inland_landscape.gd,
## by stand through tree_stands.gd). Per seed: the habitat, species counts by
## habitat, how many distinct crown tints and stand autumns the trees carry,
## and the share of neighbour pairs (under 3 m) of one species.
## godot --headless --path . -s res://tools/probe_generated_species.gd -- 79,2,9,165
const Emergence = preload("res://scripts/emergence.gd")
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds: Array[int] = []
	for s in (args[0] if not args.is_empty() else "79,2,9,165").split(","): seeds.append(int(s))
	var reference = load("res://assets/zen_reference/geometry.scn").instantiate()
	var mesh: ArrayMesh = reference.get_node("terrain").mesh
	reference.free()
	for world_seed in seeds:
		var data := NativeTerrainData.new()
		data.setup(mesh)
		var recipe: Dictionary = preload("res://scripts/cozy_world_generator.gd").sample(world_seed).terrain
		var landscape = preload("res://scripts/inland_landscape.gd").new()
		await landscape.form(data,recipe)
		var blend: RefCounted = landscape.blend
		var by_habitat := {}
		var totals := {}
		var tints := {}
		var autumns := {}
		var trees := []
		for item: Dictionary in data.objects:
			if item.asset not in Emergence.TREES: continue
			var p := Vector2(item.x,item.z)
			var habitat: String = recipe.biome if blend == null else blend.pick(p)
			var counts: Dictionary = by_habitat.get_or_add(habitat,{})
			counts[item.asset] = counts.get(item.asset,0)+1
			totals[item.asset] = totals.get(item.asset,0)+1
			tints[item.get("tint","")] = true
			if item.has("autumn"): autumns[item.autumn] = true
			trees.append([p,item.asset])
		var pairs := 0
		var alike := 0
		for i in range(trees.size()):
			for j in range(i+1,trees.size()):
				if trees[i][0].distance_to(trees[j][0]) < 3.0:
					pairs += 1
					if trees[i][1] == trees[j][1]: alike += 1
		print("seed %d %s/%s  %d trees %s" % [world_seed,recipe.biome,recipe.composition,trees.size(),totals])
		for habitat in by_habitat: print("  %s %s" % [habitat,by_habitat[habitat]])
		print("  tints %d  stand autumns %d  neighbours alike %.2f (%d pairs)" % [tints.size(),autumns.size(),float(alike)/maxi(pairs,1),pairs])
	quit()
