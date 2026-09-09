extends SceneTree
const Genome = preload("res://scripts/prototype_inland_genome.gd")
func _initialize() -> void:
	var samples := 0
	var legacy = preload("res://scripts/prototype_inland_genome_v1.gd")
	for seed_value in range(40):
		assert(var_to_bytes(Genome.sample(seed_value,{},1)) == var_to_bytes(legacy.sample(seed_value)))
	var types := {}
	for seed_value in range(200):
		var g: Dictionary = Genome.sample(seed_value)
		types[g.archetype] = true
	assert(types.size() == 4)

	for seed_value in range(40):
		for composition in Genome.COMPOSITIONS:
			var g: Dictionary = Genome.sample(seed_value,{"composition":composition})
			assert(var_to_bytes(g)==var_to_bytes(Genome.sample(seed_value,{"composition":composition})))
			var alternative: Dictionary = Genome.sample(seed_value,{"composition":composition,"habitat":"arid"})
			var n := FastNoiseLite.new()
			n.seed = g.noise_seed
			n.frequency = 0.13
			for x in range(-12,13,3):
				for z in range(-12,13,3):
					var h: float = Genome.height(g,Vector2(x,z),n)
					assert(is_finite(h) and h>=0.0 and h<40.0)
					assert(h==Genome.height(alternative,Vector2(x,z),n),"Habitat changed terrain")
			assert(g.water_phase==alternative.water_phase and g.river_width==alternative.river_width)
			assert(var_to_bytes(g.wetland)==var_to_bytes(alternative.wetland))
			samples += 1
	print("PASS ",samples," deterministic genomes; finite heights; habitat-independent terrain/water")
	quit()
