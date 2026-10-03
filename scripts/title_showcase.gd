extends RefCounted
## Curated cinematic compositions; arbitrary flat biomes are deliberately excluded.
const WORLDS := [
	{"family":"massif","biome":"alpine","landform":"tall-massif","looks":["first_snow","rosewater_dusk","alpine_morning"]},
	{"family":"mountain","biome":"woodland","landform":"twin-summits","looks":["copper_autumn","rosewater_dusk","enchanted_forest"]},
	{"family":"valley","biome":"woodland","landform":"glacial-valley","looks":["copper_autumn","rosewater_dusk","enchanted_forest"]},
	{"family":"valley","biome":"woodland","landform":"buttressed-canyon","looks":["alpine_morning","first_snow"]},
	{"family":"monuments","biome":"arid","landform":"original","looks":["golden_meadow","rosewater_dusk"]},
	{"family":"salt-basin","biome":"arid","landform":"original","looks":["golden_meadow","rosewater_dusk"]},
	{"family":"desert-mountains","biome":"arid","landform":"original","looks":["golden_meadow","rosewater_dusk"]},
	{"family":"horn","biome":"woodland","looks":["alpine_morning","copper_autumn","rosewater_dusk","enchanted_forest","first_snow"]},
	{"family":"cone","biome":"alpine","looks":["first_snow","rosewater_dusk","alpine_morning"]},
	{"family":"ridgeback","biome":"woodland","looks":["enchanted_forest","copper_autumn","rosewater_dusk","golden_meadow"]},
	{"family":"valley","biome":"meadow","looks":["copper_autumn","enchanted_forest","rosewater_dusk","first_snow"]},
	{"family":"plateau","biome":"woodland","looks":["rosewater_dusk","copper_autumn","alpine_morning"]},
	{"family":"canyon","biome":"arid","looks":["golden_meadow","rosewater_dusk","alpine_morning"]}
]
const Desert = preload("res://scripts/desert_landscape.gd")
## The worlds the title may show: the arid ones only with desert on
## (scripts/desert_landscape.gd `on`).
static func worlds() -> Array:
	return WORLDS if Desert.on else WORLDS.filter(func(world: Dictionary) -> bool: return world.biome != "arid")
static func choose(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool := worlds()
	var world: Dictionary = pool[rng.randi_range(0,pool.size()-1)]
	var mood: String = world.looks[rng.randi_range(0,world.looks.size()-1)]
	var overrides := {"wind":0.9,"rays":1.0,"summit_mist":0.35}
	if mood == "enchanted_forest": overrides.merge({"phase":0.335,"mist":0.40,"clouds":0.26},true)
	if world.biome == "arid":
		overrides.merge({"palette":"Desert","mist":0.08,"haze":0.19,"summit_mist":0.08,"colors":{"rock":"b68e70","earth":"ab785e","grass":"a69b57","foliage":"8b8750"}},true)
	var result := {"family":world.family,"biome":world.biome,"look":mood,"variation":rng.randi_range(1,999),"overrides":overrides}
	if world.has("landform"):
		result.terrain_recipe = {"kind":"inland","version":3,"seed":rng.randi_range(0,999999),"composition":world.family,"archetype":"range","landform":world.landform,"biome":world.biome,"relief":rng.randf_range(0.9,1.25),"breadth":1.0}
	return result
