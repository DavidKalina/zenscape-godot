extends RefCounted
## Seeded worlds assembled from the native inland genome and a correlated
## climate/color draw. No gallery landscape or gallery look is selected.
const Genome = preload("res://scripts/inland_genome.gd")
const Desert = preload("res://scripts/desert_landscape.gd")
const Beauty = preload("res://scripts/world_beauty.gd")
const CANDIDATES := 6
const PALETTE_DRAWS := 4
## Weather odds for a regrow. Mostly bright skies: overcast dims the sun and
## switches off god rays, so grey and wet worlds stay the occasional mood.
const WET_WEATHER := {"clear":30,"fair":34,"mist":14,"rain":9,"overcast":7,"snow":6}
const DRY_WEATHER := {"clear":45,"fair":45,"overcast":10}

static func sample(seed_value: int, previous: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var terrain_seed := rng.randi_range(0,999999)
	var g: Dictionary = Genome.sample(terrain_seed)
	while g.composition==previous.get("composition",previous.get("family","")) or terrain_seed==previous.get("seed",-1):
		terrain_seed = rng.randi_range(0,999999)
		g = Genome.sample(terrain_seed)
	var dry: bool = g.composition in Desert.KINDS
	var biome: String = g.habitat
	if biome=="woodland" and rng.randf()<0.28: biome = "redwood"
	var recipe := {"kind":"inland","version":Genome.VERSION,"seed":terrain_seed,"composition":g.composition,"archetype":g.archetype,"landform":g.landform,"biome":biome,"relief":rng.randf_range(0.65,1.3),"breadth":rng.randf_range(0.72,1.3)}
	# Draw several candidates within the chosen family and keep the one that
	# looks best from the overview camera (scripts/world_beauty.gd).
	var best_recipe := recipe.duplicate(true)
	var best_score := -1.0
	for attempt in range(CANDIDATES):
		if attempt>0:
			recipe.seed = rng.randi_range(0,999999)
			while recipe.seed==previous.get("seed",-1): recipe.seed = rng.randi_range(0,999999)
			recipe.relief = rng.randf_range(0.65,1.3)
			recipe.breadth = rng.randf_range(0.72,1.3)
		var field = preload("res://scripts/inland_world.gd").new(recipe).sampler
		var score: float = Beauty.score(field).total
		if score>best_score:
			best_score = score
			best_recipe = recipe.duplicate(true)
	recipe = best_recipe
	dry = recipe.composition in Desert.KINDS
	var hours := [Vector2(.27,.34),Vector2(.36,.57),Vector2(.62,.72),Vector2(.015,.08)]
	var hour: int = rng.randi_range(0,3)
	var phase := rng.randf_range(hours[hour].x,hours[hour].y)
	var weather := _pick_weather(rng,DRY_WEATHER if dry else WET_WEATHER)
	var snowy := weather=="snow"
	var rainy := weather=="rain"
	var autumn := not dry and not snowy and rng.randf()<0.28
	var foliage_hue := rng.randf_range(0.065,0.14) if autumn or dry else rng.randf_range(0.21,0.43)
	var stone_hue := rng.randf_range(0.045,0.12) if dry else rng.randf_range(0.06,0.16)
	var sky_hue := rng.randf_range(.56,.64) if hour==1 or hour==3 else rng.randf_range(.60,.77)
	var cloudy := weather in ["rain","snow","overcast"]
	var colors := {}
	var best_harmony := -1.0
	for attempt in range(PALETTE_DRAWS):
		var draw := {
			"sky":Color.from_hsv(sky_hue,rng.randf_range(.20,.38),rng.randf_range(.42,.58) if hour==3 else rng.randf_range(.62,.79)),
			"horizon":Color.from_hsv(sky_hue-.03,rng.randf_range(.12,.28),rng.randf_range(.45,.62) if hour==3 else rng.randf_range(.61,.78)),
			"glow":Color.from_hsv(rng.randf_range(.04,.12) if hour!=3 else .61,rng.randf_range(.13,.32),rng.randf_range(.76,.96)),
			"grass":Color.from_hsv(foliage_hue-.025,rng.randf_range(.20,.45),rng.randf_range(.52,.70)),
			"foliage":Color.from_hsv(foliage_hue,rng.randf_range(.27,.52),rng.randf_range(.40,.60)),
			"rock":Color.from_hsv(stone_hue,rng.randf_range(.22,.40) if dry else rng.randf_range(.08,.22),rng.randf_range(.53,.70)),
			"earth":Color.from_hsv(stone_hue-.02,rng.randf_range(.23,.43),rng.randf_range(.36,.53)),
			"water":Color.from_hsv(rng.randf_range(.46,.60),rng.randf_range(.22,.48),rng.randf_range(.48,.69)),
			"sun":Color.from_hsv(.60 if hour==3 else rng.randf_range(.07,.13),.13 if hour==3 else rng.randf_range(.12,.30),.98)
		}
		var harmony := Beauty.palette(draw,hour==3)
		if harmony>best_harmony:
			best_harmony = harmony
			colors = draw
	colors.ambient = colors.sky.lerp(Color("d3dce6"),.50)
	colors.bounce = colors.earth.darkened(.20)
	colors.rim = colors.sky.lerp(Color("d2dce7"),.50)
	colors.fog = colors.horizon.lerp(Color("eef2ed"),.60)
	var encoded := {}
	for key in colors: encoded[key] = colors[key].to_html(false)
	var mist := rng.randf_range(.45,.72) if weather=="mist" else rng.randf_range(.15,.35) if cloudy else rng.randf_range(.015,.09) if dry else rng.randf_range(.06,.26)
	var mood := {"colors":encoded,"phase":phase,"weather":weather,"wind":rng.randf_range(.15,.65) if not rainy else rng.randf_range(.55,1.15),"wind_direction":rng.randf_range(0,360),"clouds":rng.randf_range(.52,.78) if cloudy else rng.randf_range(.05,.32),"mist":mist,"haze":rng.randf_range(.10,.28),"rays":rng.randf_range(.25,.9),"summit_mist":rng.randf_range(.08,.40),"strength":rng.randf_range(.68,.88),"exposure":rng.randf_range(1.05,1.16),"ambient_energy":rng.randf_range(1.35,1.75),"sun_energy":rng.randf_range(.8,1.15),"night_fill":1.45,"cold":.92 if snowy else 0.0,"snow":rng.randf_range(.25,.65) if snowy else 0.0,"ice":rng.randf_range(.1,.35) if snowy else 0.0,"wet":rng.randf_range(.4,.7) if rainy else 0.0,"humidity":.8 if rainy or weather=="mist" else .3,"autumn":rng.randf_range(.4,.8) if autumn else 0.0,"aurora":rng.randf_range(.2,.7) if hour==3 and not cloudy else 0.0,"rainbow":0.0}
	# The cloud field thresholds coverage into real puffs. Values below .3
	# mostly produce empty sky, so fair/misty weather needs a broken deck.
	var coverage: Vector2 = {"clear":Vector2(.08,.22),"fair":Vector2(.42,.62),"mist":Vector2(.48,.66),"rain":Vector2(.72,.9),"snow":Vector2(.65,.85),"overcast":Vector2(.8,.95)}[weather]
	mood.clouds = rng.randf_range(coverage.x,coverage.y)
	var visuals := {
		"fog_density":rng.randf_range(.45,.8) if weather=="mist" else rng.randf_range(.18,.38) if rainy or snowy else rng.randf_range(.02,.08) if dry else rng.randf_range(.08,.22),
		"fog_height":rng.randf_range(4.0,7.0),
		"peak_density":rng.randf_range(.14,.3) if cloudy or weather=="mist" else rng.randf_range(.03,.10),
		"peak_altitude":rng.randf_range(4.0,7.0),
		"rock_style":1,"rock_detail":.65
	}
	return {"seed":seed_value,"terrain":recipe,"mood":mood,"visuals":visuals}

static func _pick_weather(rng: RandomNumberGenerator, odds: Dictionary) -> String:
	var total := 0.0
	for weight in odds.values(): total += weight
	var roll := rng.randf()*total
	for weather in odds:
		roll -= odds[weather]
		if roll<0.0: return weather
	return odds.keys()[-1]

## Candidate scoring is CPU work; keep it off the regrowth animation's thread.
static func sample_async(seed_value: int,previous: Dictionary,tree: SceneTree) -> Dictionary:
	var result: Array[Dictionary] = []
	var snapshot := previous.duplicate(true)
	var task := WorkerThreadPool.add_task(func(): result.append(sample(seed_value,snapshot)))
	while not WorkerThreadPool.is_task_completed(task): await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return result[0]

static func apply_mood(scene: Node3D, world: Dictionary) -> void:
	# The existing applicator resets all weather/season controls. Every color
	# and environmental choice is supplied by our generated recipe.
	SceneLookPresets.apply(scene,"golden_meadow",world.mood)
	var visuals: Dictionary = world.visuals.duplicate(true)
	# Carry wisps into the relief rather than leaving the same cloud altitude
	# across low meadows and tall mountains.
	visuals.peak_altitude = clampf(float(Array(scene._chunk_editor.data.heights).max())*.55+visuals.peak_altitude,2.0,24.0)
	scene._world_visuals.restore(visuals)
	scene._world_visuals.sync(scene)
