extends SceneTree
const Presets = preload("res://scripts/native_landscape_presets.gd")
const Shape = preload("res://scripts/native_formation_shape.gd")
const Recipe = preload("res://scripts/native_terrain_recipe.gd")
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("Landscape tests timed out"); quit(2))
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	var editor = scene._chunk_editor
	var data: NativeTerrainData = editor.data
	var look: Dictionary = scene._celestial.look.document()
	var camera: Transform3D = scene.camera.transform
	var signatures := []
	for id: String in Presets.PRESETS:
		var settings := Presets.recipe(id)
		check(Recipe.valid(settings),"Valid authored recipe: "+id)
		check(Recipe.decode(JSON.parse_string(JSON.stringify(Recipe.encode(settings)))) == settings,"Exact recipe JSON roundtrip: "+id)
		var before: Dictionary = data._snapshot()
		await editor.form_landscape(id,"",false)
		check(not editor.forming,"Formation transaction unlocks: "+id)
		check(data.blank and data._recipe_settings == settings,"Formation applied: "+id)
		check(data.objects.size()>25,"Biome has planting and detail: "+id)
		check(data.ponds.size() == (0 if id == "redwood_grove" else 3 if id == "terraced_pools" else 2 if id == "plateau" else 1),"Authored lakes are present: "+id)
		for pool: Dictionary in data.ponds:
			var surface := data.pond_surface(pool)
			check(surface.size()>30,"Pool has actual water geometry: "+id)
			var contained := true
			for point: Vector3 in surface:
				if maxf(absf(point.x),absf(point.z))>11.25: contained = false; break
			check(contained,"Pool is contained by its own shore: "+id)
		check(data.streams.size() == (0 if id == "redwood_grove" else 2 if id in ["valley","canyon","terraced_pools"] else 1),"Each formation has its connected water treatment: "+id)
		var generated: Dictionary = data._snapshot()
		var signature: int = hash(data.heights)
		check(signature not in signatures,"Distinct family silhouette: "+id)
		signatures.append(signature)
		check(data.undo() and data._snapshot() == before,"One undo restores previous complete landscape: "+id)
		check(data.redo() and data._snapshot() == generated,"Redo restores complete landscape: "+id)
		var document: Dictionary = data.to_document()
		check(data.load_document(JSON.parse_string(JSON.stringify(document,"",true,true))),"Landscape saves and loads: "+id)
		check(data.heights == generated.heights and data._recipe_settings == settings,"Save retains formation exactly: "+id)
		check(scene._celestial.look.document() == look and scene.camera.transform == camera,"Formation leaves palette and camera alone: "+id)
		print("Checked ",id)
	# The shape must remain independent of both biome and color, including edits.
	data.begin_stroke()
	data.brush(Vector2(-7,8),2.0,0.6,"raise",0.0)
	var own_id := data.place("rock",Vector2(-9,7))
	data.end_stroke()
	var sculpted: PackedFloat32Array = data.heights.duplicate()
	var water: Array = data.ponds.duplicate(true)
	for biome: String in Shape.BIOMES:
		var before: Dictionary = data._snapshot()
		await editor.change_landscape_biome(biome,false)
		check(data.heights == sculpted and data.ponds == water,"Biome preserves sculpt and water: "+biome)
		check(not data.object_by_id(own_id).is_empty(),"Biome retains hand-placed objects: "+biome)
		check(scene._celestial.look.document() == look,"Biome leaves colors alone: "+biome)
		check(data._recipe_settings.biome == biome,"Biome metadata follows selection: "+biome)
		check(data.undo() and data._snapshot() == before,"Biome has complete undo: "+biome)
		data.redo()
	var terrain := data._snapshot()
	scene._celestial.look.choose("Desert")
	check(data._snapshot() == terrain,"Palette swap does not regenerate the landscape")
	# The full family × biome matrix remains valid without changing geometry.
	for family: String in Presets.PRESETS:
		var reference = Recipe.new(Presets.recipe(family))
		for biome: String in Shape.BIOMES:
			var variant = Recipe.new(Presets.recipe(family,biome))
			check(Recipe.valid(variant.settings),"Supported family / biome pairing")
			for point in [Vector2.ZERO,Vector2(-4,-5),Vector2(7,8),Vector2(14,0)]:
				check(is_equal_approx(reference.height(point.x,point.y),variant.height(point.x,point.y)),"Biome does not alter family profile")
	# Exercise the actual yielding UI path and block competing writes mid-build.
	var live_frames := [0]
	var on_frame := func() -> void:
		if not editor.forming: return
		live_frames[0] += 1
		var in_progress: PackedFloat32Array = data.heights.duplicate()
		editor.undo()
		editor.start_flat()
		check(data.heights == in_progress,"Partial formation blocks other terrain writes")
	process_frame.connect(on_frame)
	await editor.form_landscape("valley")
	process_frame.disconnect(on_frame)
	check(live_frames[0]>3 and not editor.forming,"Live formation yields frames and completes")
	var bad := Presets.recipe("horn")
	bad.family = "unknown"
	check(not Recipe.valid(bad),"Unknown family rejected")
	bad = Presets.recipe("horn")
	bad.biome = "unknown"
	check(not Recipe.valid(bad),"Unknown biome rejected")
	scene.edit_landscape_presets()
	var panel = scene._landscape_editor
	check(panel.cards.size() == Presets.PRESETS.size(),"Gallery exposes every requested family")
	for id in panel.cards:
		check(panel.cards[id].get_child(0).texture != null,"Actual rendered preview: "+id)
	root.content_scale_factor = 2.0
	root.size = Vector2i(960,640)
	await process_frame
	panel._layout()
	await process_frame
	check(root.get_visible_rect().encloses(panel.get_global_rect()) and panel.scroll.size.y>140,"Gallery fits small Retina window")
	panel.scroll.scroll_vertical = 10000
	await process_frame
	check(panel.scroll.get_global_rect().intersects(panel.cards.terraced_pools.get_global_rect()),"Last formation reachable by scrolling")
	scene.edit_scene_look()
	check(not panel.visible and scene._look_editor.visible,"Palette editor replaces landscape panel")
	scene.queue_free()
	await process_frame
	print("LANDSCAPE PRESETS: failures=",failures)
	quit(1 if failures else 0)
