extends RefCounted
## A meadow type's world recipe (scripts/meadow_types.gd TYPES): the land a
## new meadow world forms from (scripts/world_lands.gd), planned with the
## inland generator (scripts/inland_world.gd). Kept apart from the meadow's
## dressing so the isles, which grow the meadow's grass and flowers, never
## reach the world generator.
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Genome = preload("res://scripts/inland_genome.gd")
const BiomeBlend = preload("res://scripts/biome_blend.gd")

## The inland recipe for a `type_id` meadow world from `seed_value`: the type's
## land and relief drawn from the seed, its neighbours planned over the built
## land (BiomeBlend layers), seeded variety, and the type itself.
static func recipe(type_id: String, seed_value: int) -> Dictionary:
	var t: Dictionary = MeadowTypes.TYPES[type_id]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["meadow",type_id,seed_value])
	var terrain: Dictionary = t.terrain
	var result := {"kind":"inland","version":Genome.VERSION,"seed":seed_value%1000000,"composition":terrain.composition,
		"archetype":terrain.archetype,"landform":terrain.landform,"biome":"meadow",
		"relief":snappedf(rng.randf_range(terrain.relief[0],terrain.relief[1]),0.001),
		"breadth":snappedf(rng.randf_range(terrain.breadth[0],terrain.breadth[1]),0.001)}
	var blend := plan(type_id,result,rng)
	if not blend.is_empty(): result["blend"] = blend
	result["variety"] = 1
	result["meadow"] = type_id
	return result

## The type's neighbours as BiomeBlend layers over the land the recipe builds:
## each claims its share of the land by its rule (scripts/biome_blend.gd
## `plan` does the same for generated worlds), and one with almost no ground,
## or a wet neighbour on dry land, is dropped.
static func plan(type_id: String, settings: Dictionary, rng: RandomNumberGenerator) -> Array:
	var world = preload("res://scripts/inland_world.gd").new(settings)
	var field = BiomeBlend.new(world.genome,world.sampler)
	var sun := int(rng.randf_range(-60.0,60.0)+360.0)%360
	var blend: Array = []
	for pick: Array in MeadowTypes.TYPES[type_id].blend:
		var rule: String = pick[1]
		if rule == "moist" and not field.has_water: continue
		var turn := 0
		if str(pick[3]) == "sun": turn = sun
		elif str(pick[3]) == "shade": turn = (sun+180)%360
		var at: float = field._quantile(rule,turn,1.0-float(pick[2]))
		if pick[0] == "alpine" and rule == "high": at = minf(at,field._altitude_of(BiomeBlend.WOOD_CEILING))
		blend.append({"biome":pick[0],"by":rule,"at":clampi(roundi(at*100.0),0,100),"soft":roundi(rng.randf_range(0.07,0.12)*100.0),"turn":turn})
	field.apply("meadow",blend)
	var kept: Array = []
	for layer: Dictionary in blend:
		if field.share(layer.biome) >= 0.04: kept.append(layer)
	return kept.slice(0,BiomeBlend.MAX_LAYERS)
