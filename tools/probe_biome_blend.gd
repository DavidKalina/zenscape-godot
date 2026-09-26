extends SceneTree
## Headless probe: the biome mix each seed gets, its share of the land, the
## plan's cost, and a JSON save round trip of the recipe.
## godot --headless --path . -s res://tools/probe_biome_blend.gd -- [count | showcase]
const Generator = preload("res://scripts/cozy_world_generator.gd")
const Blend = preload("res://scripts/biome_blend.gd")
const World = preload("res://scripts/inland_world.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds: Array = []
	if args.size()>0 and args[0]=="showcase": seeds = preload("res://scripts/cozy_regrowth.gd").SHOWCASE
	else: seeds = range(int(args[0]) if args.size()>0 else 40)
	var sample_ms := 0.0
	var plan_ms := 0.0
	var counts := {}
	var failures := 0
	for seed_value in seeds:
		var t0 := Time.get_ticks_usec()
		var world := Generator.sample(seed_value)
		sample_ms += (Time.get_ticks_usec()-t0)/1000.0
		var recipe: Dictionary = world.terrain
		# Time the plan on its own and report shares from a fresh field.
		var built = World.new(recipe)
		var t1 := Time.get_ticks_usec()
		Blend.plan(recipe,built)
		plan_ms += (Time.get_ticks_usec()-t1)/1000.0
		var field = Blend.new(built.genome,built.sampler)
		field.apply(recipe.biome,recipe.get("blend",[]))
		var parts: Array = []
		for i in range(field.biomes.size()):
			var layer: Dictionary = recipe.blend[i-1] if i>0 else {}
			parts.append("%s %d%%%s" % [field.biomes[i],roundi(field.shares[i]*100.0),"" if i==0 else " (%s%s)" % [layer.by," %d°" % layer.turn if layer.by=="facing" else ""]])
		var key := Blend.title(recipe)
		counts[key] = counts.get(key,0)+1
		var saved: Variant = NativeTerrainRecipe.decode(JSON.parse_string(JSON.stringify(NativeTerrainRecipe.encode(recipe))))
		# JSON sorts the keys, so compare key by key.
		var round_trip: bool = saved != null and saved.size()==recipe.size()
		if round_trip:
			for entry in recipe: round_trip = round_trip and var_to_bytes(saved.get(str(entry)))==var_to_bytes(recipe[entry])
		if not round_trip or not NativeTerrainRecipe.valid(recipe): failures += 1
		print("seed %3d %-17s top %4.1f m  %s%s%s" % [seed_value,recipe.composition,field.top,", ".join(parts)," geology" if world.visuals.has("geology") else ""," SAVE-MISMATCH" if not round_trip else ""])
	var old := {"kind":"inland","version":5,"seed":7,"composition":"chasm","archetype":"ridgeback","landform":"original","biome":"meadow","relief":1.0,"breadth":1.0}
	print("old recipe valid: ",NativeTerrainRecipe.valid(old),", snowline ",Blend.snowline(old,99.0))
	for key in counts: print("%3d  %s" % [counts[key],key])
	print("sample %.0f ms per world, plan %.1f ms, save failures %d" % [sample_ms/seeds.size(),plan_ms/seeds.size(),failures])
	quit()
