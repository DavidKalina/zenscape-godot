extends SceneTree
## Headless: the dressing digests of worlds without a meadow type, which the
## meadow types (scripts/meadow_types.gd) must leave byte-for-byte as they
## were. tests/test_meadow_types.gd holds the digests this printed on the
## commit before the meadow types. `-- types` also prints each type's counts.
##   godot --headless --path . -s res://tools/probe_meadow_digests.gd [-- types]
const CASES := [
	["generated",79],["generated",105],["generated",177],["generated",58],["generated",198],["generated",33],
	["single",79],["single",177],["plain_recipe",58],["isle",4021],
	["formation","valley"],["formation","terraced_pools"],["formation","redwood_grove"],
]

func _initialize() -> void: run.call_deferred()

static func recipe_for(case: Array) -> Dictionary:
	match case[0]:
		"generated": return preload("res://scripts/cozy_world_generator.gd").sample(int(case[1])).terrain
		"single":
			var r: Dictionary = preload("res://scripts/cozy_world_generator.gd").sample(int(case[1])).terrain
			r.erase("blend")
			return r
		"plain_recipe":
			var r: Dictionary = preload("res://scripts/cozy_world_generator.gd").sample(int(case[1])).terrain
			r.erase("blend")
			r.erase("variety")
			return r
		"isle":
			return {"kind":"inland","version":preload("res://scripts/inland_genome.gd").VERSION,"seed":int(case[1]),"composition":"marsh",
				"archetype":"range","landform":"original","biome":"wetland","relief":0.85,"breadth":1.15}
	return {}

static func digest(data: NativeTerrainData) -> String:
	return var_to_bytes([data.objects,data.grass,data.meadow,data.blades,data.tint]).hex_encode().sha256_text().substr(0,12)

static func dress(data: NativeTerrainData, case: Array) -> void:
	if case[0] == "formation":
		await preload("res://scripts/native_landscape_presets.gd").form(data,str(case[1]))
	else:
		await preload("res://scripts/inland_landscape.gd").new().form(data,recipe_for(case))

static func terrain() -> NativeTerrainData:
	var reference = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(reference.get_node("terrain").mesh)
	reference.free()
	return data

func run() -> void:
	var data := terrain()
	if "types" in OS.get_cmdline_user_args():
		await types(data)
		quit()
		return
	for case: Array in CASES:
		await dress(data,case)
		print("%s %s  %s" % [case[0],str(case[1]),digest(data)])
	quit()

## Each meadow type over a few seeds: dressing time, what it planted, the
## habitat mix and the record count the renderer instances.
func types(data: NativeTerrainData) -> void:
	const MeadowTypes = preload("res://scripts/meadow_types.gd")
	for type_id: String in MeadowTypes.ORDER:
		for seed_value in [11,2024,777]:
			var t := Time.get_ticks_usec()
			var r := MeadowTypes.recipe(type_id,seed_value)
			var planned := (Time.get_ticks_usec()-t)/1000.0
			t = Time.get_ticks_usec()
			await preload("res://scripts/inland_landscape.gd").new().form(data,r)
			var ms := (Time.get_ticks_usec()-t)/1000.0
			var kinds := {}
			for item in data.objects: kinds[item.asset] = kinds.get(item.asset,0)+1
			print("%s %d  plan %.0f ms dress %.0f ms  objects %d  %s  %s\n   %s" % [type_id,seed_value,planned,ms,data.objects.size(),preload("res://scripts/biome_blend.gd").title(r),r.composition,kinds])
