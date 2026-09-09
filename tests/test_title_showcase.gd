extends SceneTree
func _initialize() -> void:
	var showcase = preload("res://scripts/title_showcase.gd")
	var seen := {}
	for seed_value in range(500):
		var choice: Dictionary = showcase.choose(seed_value)
		assert(choice == showcase.choose(seed_value),"Seeded showcase must replay")
		var recipe: Dictionary = choice.terrain_recipe if choice.has("terrain_recipe") else preload("res://scripts/native_landscape_presets.gd").recipe(choice.family,choice.biome,choice.variation)
		assert(NativeTerrainRecipe.valid(recipe),"Every random cover must build")
		assert(SceneLookPresets.PRESETS.has(choice.look))
		seen[choice.family] = true
	assert(seen.size() == 11,"All cinematic families must be reachable")
	print("TITLE SHOWCASE: 500 valid, deterministic selections across eleven families")
	quit()
