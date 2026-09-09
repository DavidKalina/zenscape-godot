extends RefCounted
## Curated cinematic compositions; arbitrary flat biomes are deliberately excluded.
const WORLDS := [
	{"family":"horn","biome":"woodland","looks":["alpine_morning","copper_autumn","rosewater_dusk","enchanted_forest","first_snow"]},
	{"family":"cone","biome":"alpine","looks":["first_snow","rosewater_dusk","alpine_morning"]},
	{"family":"ridgeback","biome":"woodland","looks":["enchanted_forest","copper_autumn","rosewater_dusk","golden_meadow"]},
	{"family":"valley","biome":"meadow","looks":["copper_autumn","enchanted_forest","rosewater_dusk","first_snow"]},
	{"family":"plateau","biome":"woodland","looks":["rosewater_dusk","copper_autumn","alpine_morning"]},
	{"family":"canyon","biome":"arid","looks":["golden_meadow","rosewater_dusk","alpine_morning"]}
]
static func choose(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var world: Dictionary = WORLDS[rng.randi_range(0,WORLDS.size()-1)]
	var mood: String = world.looks[rng.randi_range(0,world.looks.size()-1)]
	var overrides := {"wind":0.9,"rays":1.0,"summit_mist":0.35}
	if mood == "enchanted_forest": overrides.merge({"phase":0.335,"mist":0.40,"clouds":0.26},true)
	if world.family == "canyon":
		overrides.merge({"palette":"Desert","mist":0.08,"haze":0.19,"summit_mist":0.08,"colors":{"rock":"b68e70","earth":"ab785e","grass":"a69b57","foliage":"8b8750"}},true)
	return {"family":world.family,"biome":world.biome,"look":mood,"variation":rng.randi_range(1,999),"overrides":overrides}
