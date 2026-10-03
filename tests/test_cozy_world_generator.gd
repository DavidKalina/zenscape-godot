extends SceneTree
const Generator = preload("res://scripts/cozy_world_generator.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void:
	var compositions := {}
	var weathers := {}
	var palettes := {}
	var shapes := {}
	var heights := {}
	var previous := {}
	for i in range(100):
		var world := Generator.sample(i*7919,previous)
		check(world==Generator.sample(i*7919,previous),"A world seed reproduces all terrain and climate choices")
		check(NativeTerrainRecipe.valid(world.terrain),"Procedural recipes validate for save/reopen")
		check(world.terrain.composition!=previous.get("composition", ""),"New compositions differ from the current world")
		var look := SceneLookPresets.look_document("golden_meadow",world.mood)
		check(SceneLook.valid(look),"Generated custom colors remain valid")
		check(preload("res://scripts/world_visuals.gd").valid(world.visuals),"Generated fog and cloud banks remain valid for save/reopen")
		compositions[world.terrain.composition] = true
		weathers[world.mood.weather] = true
		palettes[var_to_bytes(look)] = true
		shapes[world.terrain.landform] = true
		heights[world.terrain.relief] = true
		previous = world.terrain
	# Without desert (scripts/desert_landscape.gd) its seven compositions are re-rolled.
	var desert: bool = preload("res://scripts/desert_landscape.gd").on
	check(desert or not compositions.keys().any(func(kind: String) -> bool: return kind in preload("res://scripts/desert_landscape.gd").KINDS),"No desert composition while the desert is held back")
	check(compositions.size()>=(12 if desert else 8) and shapes.size()>=6,"Sample spans broad native geometry families and crest shapes")
	check(weathers.size()==6,"Sample includes sun, fair skies, overcast, mist, rain and snow")
	check(palettes.size()==100 and heights.size()>95,"Palette and relief are continuous draws, not gallery presets")
	print("Procedural world sampling: ",failures," failures; ",compositions.size()," compositions, ",shapes.size()," landforms, ",weathers.size()," weather types, ",palettes.size()," distinct palettes")
	quit(1 if failures else 0)
