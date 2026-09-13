extends SceneTree
func _initialize() -> void:
	var genome = preload("res://scripts/inland_genome.gd")
	var count := 0
	for kind in genome.COMPOSITIONS:
		for seed_value in [7,37,901]:
			var sampled: Dictionary = genome.sample(seed_value,{"composition":kind})
			var settings := {"kind":"inland","version":5 if kind == "chasm" else 3,"seed":seed_value,"composition":kind,"archetype":sampled.archetype,"landform":sampled.landform,"biome":sampled.habitat,"relief":1.8,"breadth":1.0}
			assert(NativeTerrainRecipe.valid(settings))
			var decoded: Variant = NativeTerrainRecipe.decode(JSON.parse_string(JSON.stringify(NativeTerrainRecipe.encode(settings))))
			assert(decoded == settings,"Recipe round trip")
			var a := NativeTerrainRecipe.new(settings)
			var b := NativeTerrainRecipe.new(decoded)
			for z in range(-13,14,2):
				for x in range(-13,14,2):
					var h := a.height(x,z)
					assert(is_finite(h) and h >= NativeTerrainData.MIN_HEIGHT and h <= NativeTerrainData.MAX_HEIGHT,"Saveable height: "+kind+" "+str(h))
					assert(h == b.height(x,z))
			count += 1
	var malformed := {"kind":"inland","version":99}
	assert(not NativeTerrainRecipe.valid(malformed))
	print("INLAND RECIPE: ",count," exact replay cases, all terrain families")
	quit()
