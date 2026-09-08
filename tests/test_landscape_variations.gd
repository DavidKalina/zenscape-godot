extends SceneTree
const Presets = preload("res://scripts/native_landscape_presets.gd")
const Recipe = preload("res://scripts/native_terrain_recipe.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok: failures += 1; push_error(message)
func run() -> void:
	for family: String in Presets.PRESETS:
		var shapes := []
		for seed in [37,174,311,722]:
			var recipe = Recipe.new(Presets.recipe(family,"",seed))
			var signature: Array = []
			for x in range(-8,9,4):
				for z in range(-8,9,4): signature.append(recipe.height(x,z))
			check(signature not in shapes,"Variation changes composition: "+family)
			shapes.append(signature)
			for route: Dictionary in recipe.formation.water.routes:
				check(preload("res://scripts/native_stream_record.gd").valid(route),"Varied route remains downhill: "+family)
				for p: Dictionary in route.pts:
					check(recipe.height(p.x,p.z)<p.h-route.depth+route.surface*0.065-0.03,"Varied terrain fits its water: "+family)
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	var editor = scene._chunk_editor
	await editor.form_landscape("terraced_pools","woodland",false,174)
	var first: Dictionary = editor.data._snapshot()
	var look: Dictionary = scene._celestial.look.document()
	await editor.another_landscape(false)
	check(editor.data.heights != first.heights,"Another like this creates a new composition")
	check(editor.data._recipe_settings.family == "terraced_pools" and editor.data._recipe_settings.biome == "woodland","Another like this keeps family and biome")
	check(scene._celestial.look.document()==look,"Another like this keeps palette")
	editor.undo()
	check(editor.data._snapshot()==first,"One undo restores previous variation")
	await editor.form_landscape("terraced_pools","woodland",false,174)
	check(editor.data._snapshot()==first,"A pinned variation reproduces terrain, water and planting")
	await editor.change_landscape_water("quiet",false)
	check(editor.data.streams.is_empty() and editor.data.ponds.size()==3,"Quiet treatment retains three still pools")
	check(scene._celestial.look.document()==look,"Water treatment keeps palette")
	editor.undo()
	check(editor.data._snapshot()==first,"Water treatment undo restores complete previous landscape")
	scene.queue_free()
	await process_frame
	print("LANDSCAPE VARIATIONS failures=",failures)
	quit(1 if failures else 0)
