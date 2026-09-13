extends RefCounted
## Curated worlds pair editable composition and biome with an authored mood. All ground,
## planting and water use the ordinary editable, undoable garden records.
const Shape = preload("res://scripts/native_formation_shape.gd")
const PRESETS := {
	"redwood_grove":{"title":"Redwood Grove","family":"redwood_grove","biome":"redwood","palette":"Hollow","description":"Tall redwoods, fern-filled hollows and low drifting forest mist."},
	"valley":{"title":"Riverfold valley","family":"valley","biome":"meadow","palette":"Meadow","description":"A winding river between open, flowered slopes."},
	"plateau":{"title":"Skywater plateau","family":"plateau","biome":"woodland","palette":"Mountain","description":"A quiet summit lake above a wooded tableland."},
	"cone":{"title":"Sleeping volcano","family":"cone","biome":"alpine","palette":"Winter","description":"A sweeping cone, snowy crown and foothill lake."},
	"ridgeback":{"title":"Emerald ridgeback","family":"ridgeback","biome":"woodland","palette":"Hollow","description":"Rounded green ridges above a sheltered mere."},
	"horn":{"title":"Silverhorn tarn","family":"horn","biome":"alpine","palette":"Mountain","description":"A sharp alpine tooth above a glacial pool."},
	"canyon":{"title":"Sunstone canyon","family":"canyon","biome":"arid","palette":"Desert","description":"Stepped cliffs around a slender ribbon of water."},
	"terraced_pools":{"title":"Jade terraces","family":"terraced_pools","biome":"wetland","palette":"Meadow","description":"Three water gardens stepping through lush banks."}
}
# The same authored moods are used by gallery captures and player selection.
const MOODS := {
	"redwood_grove":"golden_meadow", "valley":"golden_meadow",
	"plateau":"alpine_morning", "cone":"rosewater_dusk",
	"ridgeback":"enchanted_forest", "horn":"alpine_morning",
	"canyon":"golden_meadow", "terraced_pools":"after_the_rain"
}
# Per-world atmosphere: preserve the successful redwood treatment, while each
# other composition gets its own light, weather and restrained fog profile.
const ATMOSPHERES := {
	"redwood_grove":{"mist":0.45,"rays":1.0},
	"valley":{"phase":0.34,"mist":0.22,"haze":0.10,"clouds":0.10,"wind":0.28,"rays":0.25,"summit_mist":0.10,
		"colors":{"sky":"82aaba","horizon":"a1afa3","glow":"f1d0a2","ambient":"a5c2d4"}},
	"plateau":{"phase":0.42,"mist":0.18,"haze":0.13,"clouds":0.20,"wind":0.48,"rays":0.40,"summit_mist":0.20,"ambient_energy":1.25,
		"colors":{"sky":"7faac5","horizon":"90b2bf","glow":"dbe3d6","water":"579fa7"}},
	"cone":{"phase":0.66,"mist":0.08,"haze":0.12,"clouds":0.12,"wind":0.22,"rays":0.15,"summit_mist":0.05,"ambient_energy":1.65,"exposure":1.10,
		"colors":{"sky":"8a83ad","horizon":"a28d9d","glow":"efb398","sun":"ffd1ac","rock":"a8949e","ambient":"a6b1d0"}},
	"ridgeback":{"phase":0.36,"weather":"fair","mist":0.40,"haze":0.13,"clouds":0.32,"wind":0.30,"rays":1.0,"summit_mist":0.35,"ambient_energy":1.55,"sun_energy":1.10,"exposure":1.10,
		"colors":{"sky":"83a6ae","horizon":"729893","glow":"ded8b4","sun":"f5ddb1","ambient":"a5c4bd","foliage":"598b66","grass":"7aa285"}},
	"horn":{"phase":0.315,"weather":"clear","mist":0.14,"haze":0.07,"clouds":0.06,"wind":0.12,"rays":0.30,"summit_mist":0.0,"ambient_energy":1.40,"exposure":1.08,
		"colors":{"sky":"869dbd","horizon":"a3afc0","glow":"efc6b3","sun":"ffdbc2","ambient":"9cbbda","rock":"9da6b4","water":"6a9fb5"}},
	"canyon":{"palette":"Desert","phase":0.63,"mist":0.03,"haze":0.17,"clouds":0.04,"wind":0.35,"rays":0.12,"summit_mist":0.0,"ambient_energy":1.40,"strength":0.80,
		"colors":{"sky":"998fa7","horizon":"b29b90","glow":"edb184","sun":"ffd2a1","ambient":"b6a6be","rock":"b68e70","earth":"ab785e","water":"639e9b","grass":"a69b57","foliage":"8b8750"}},
	"terraced_pools":{"phase":0.38,"mist":0.30,"haze":0.12,"clouds":0.34,"wind":0.22,"rays":0.65,"summit_mist":0.15,"wet":0.62,"humidity":0.65,"rainbow":0.0,"ambient_energy":1.40,"exposure":1.08,
		"colors":{"sky":"8aafb6","horizon":"8faaa0","glow":"e7dfc2","water":"61aaa0","foliage":"5b8e73","ambient":"b3c9c4"}}
}
static func apply_mood(scene: Node3D, id: String) -> void:
	preload("res://scripts/scene_look_presets.gd").apply(scene,MOODS[id],ATMOSPHERES[id])

static func recipe(id: String,biome := "",variation := 37,water := "connected") -> Dictionary:
	var p: Dictionary = PRESETS[id]
	return {"kind":"formation","water":water,"family":p.family,"biome":p.biome if biome.is_empty() else biome,"height":1.0,"width":1.0,"heading":0.0,"variation":variation}

static func form(data: NativeTerrainData,id: String,biome := "",tree: SceneTree = null,variation := 37,water := "connected") -> void:
	data.reset_flat()
	if not await data._set_recipe(recipe(id,biome,variation,water),tree): return
	data.heights = data._recipe_heights.duplicate()
	var shape: RefCounted = data._recipe.formation
	for pool: Dictionary in shape.pool_specs:
		var point := Vector2(pool.x,pool.z)
		data.ponds.append({"x":float(point.x),"z":float(point.y),"level":float(pool.level),"basin":pool.basin.duplicate()})
	data.streams.assign(shape.water.routes.duplicate(true))
	await dress(data,tree)

static func change_biome(data: NativeTerrainData,id: String,tree: SceneTree = null) -> void:
	if data._recipe_settings.get("kind") != "formation" or not Shape.BIOMES.has(id): return
	var settings: Dictionary = data._recipe_settings.duplicate(true)
	settings.biome = id
	if not await data._set_recipe(settings,tree): return
	# _set_recipe prepares samplers; it does not replace sculpted vertex heights.
	await dress(data,tree)

static func dress(data: NativeTerrainData,tree: SceneTree = null) -> void:
	var biome: String = data._recipe_settings.biome
	var b: Dictionary = Shape.BIOMES[biome]
	var budget = preload("res://scripts/frame_work_budget.gd").new(tree)
	data.objects = data.objects.filter(func(item: Dictionary) -> bool: return not item.get("landscape",false) or item.asset == "waterfall")
	data.objects_revision += 1
	data.grass.fill(b.grass)
	data.meadow.fill(0.0)
	data.blades.fill(0.0)
	if biome != "arid":
		for z in range(data.MEADOW_CELLS):
			if z%4 == 0: await budget.checkpoint()
			for x in range(data.MEADOW_CELLS):
				var p := data.meadow_position(x,z)+Vector2.ONE*0.25
				if maxf(absf(p.x),absf(p.y))>11.0 or _wet(data,p) or _slope(data,p)>0.65: continue
				if data.ground_height(p)>minf(b.treeline,b.snowline-1.0): continue
				if data._recipe.source.noise_at(p.x*0.4,p.y*0.4)>0.42:
					data.blades[z*data.MEADOW_CELLS+x] = 0.28
					if biome == "meadow": data.meadow[z*data.MEADOW_CELLS+x] = 0.17
	var rng := RandomNumberGenerator.new()
	rng.seed = 1709+int(data._recipe_settings.variation)
	var occupied: Array[Vector2] = []
	# Patches and clearings, not a uniform confetti scatter. The front stays open
	# enough to read the water and silhouette from the default viewing angle.
	for i in range(1500):
		if i%32 == 0: await budget.checkpoint()
		var p := Vector2(rng.randf_range(-11.2,11.2),rng.randf_range(-10.8,10.8))
		var h: float = data.ground_height(p)
		var slope := _slope(data,p)
		if h > b.treeline or slope > 1.0 or _wet(data,p): continue
		var patch: float = data._recipe.source.noise_at(p.x*0.32+17,p.y*0.32-9)
		if biome == "redwood":
			if patch<0.30 or absf(p.x-data._recipe.formation.channel_x(p.y))<1.65: continue
		else:
			if patch < 0.42 or (p.y > 3.0 and absf(p.x)<4.8): continue
		var close := false
		for other in occupied:
			if p.distance_squared_to(other)<(5.8 if biome == "redwood" else 1.8): close = true; break
		if close: continue
		var kind: String = "tree" if biome == "woodland" and rng.randf()<0.25 else b.tree
		var size := rng.randf_range(0.75,1.2) if kind == "tree" else rng.randf_range(1.1,1.7)
		if kind == "redwood": size = rng.randf_range(0.72,1.2)
		var color := Color("b1c2a5") if kind == "redwood" else Color("3e7a44") if kind == "tree" else Color("6f9c46")
		color = color.srgb_to_linear()*rng.randf_range(0.82,1.08)
		if data.place(kind,p,rng.randf()*TAU,size,{},NativeObjectPose.encode_tint(color)) < 0: break
		data.objects.back()["landscape"] = true
		occupied.append(p)
		if occupied.size() >= b.trees: break
	for i in range(340):
		if i%32 == 0: await budget.checkpoint()
		var p := Vector2(rng.randf_range(-11.5,11.5),rng.randf_range(-11.0,11.0))
		var h: float = data.ground_height(p)
		if h > b.snowline-0.7 or _slope(data,p)>1.2 or _wet(data,p): continue
		var kind := "grass_tuft"
		if i%13 == 0: kind = "boulder_"+str(1+i%4)
		elif biome == "arid":
			if i%3 != 0: continue
			kind = "shrub" if i%2 == 0 else "rock"
		elif biome == "wetland": kind = "reeds" if _near_water(data,p) else "bank_grass"
		elif biome == "meadow": kind = ["daisy_flower","button_flower","spike_flower","grass_tuft"][i%4]
		elif biome == "woodland" and i%7 == 0: kind = "shrub"
		elif biome == "redwood":
			if absf(p.x-data._recipe.formation.channel_x(p.y))<1.4: continue
			kind = "log" if i%29 == 0 else "mushroom" if i%11 == 0 else "fern" if i%3 != 0 else "grass_tuft"
		var size := rng.randf_range(0.35,0.7) if kind.begins_with("boulder") else rng.randf_range(0.65,1.1)
		if data.place(kind,p,rng.randf()*TAU,size) < 0: break
		data.objects.back()["landscape"] = true
	data.objects_revision += 1

static func _slope(data: NativeTerrainData,p: Vector2) -> float:
	var samples := []
	for offset in [Vector2(0.25,0),Vector2(-0.25,0),Vector2(0,0.25),Vector2(0,-0.25)]:
		var h: Variant = data.ground_height(p+offset)
		if h == null: return INF
		samples.append(h)
	return Vector2(samples[0]-samples[1],samples[2]-samples[3]).length()/0.5

static func _wet(data: NativeTerrainData,p: Vector2) -> bool:
	for pool: Dictionary in data.ponds:
		if data.ground_height(p)<pool.level+0.15 and p.distance_to(Vector2(pool.x,pool.z))<7.0: return true
	if data._recipe_settings.family in ["valley","canyon"]:
		return absf(p.x-data._recipe.formation.channel_x(p.y))<1.3
	return false

static func _near_water(data: NativeTerrainData,p: Vector2) -> bool:
	for pool: Dictionary in data.ponds:
		if p.distance_to(Vector2(pool.x,pool.z))<6.0 and data.ground_height(p)<pool.level+0.8: return true
	return false
