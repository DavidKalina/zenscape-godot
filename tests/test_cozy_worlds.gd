extends SceneTree
## The main scene's integration test (studies/cozy_worlds.tscn): a world opens
## straight past the title on its default land with the resident away; Regrow
## folds it down and grows a new wilderness in place, holding every gesture
## while it works; native undo and redo swap the whole worlds; the place saves
## and opens again with its terrain, colours, weather and fog.
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
	print(("OK   " if ok else "FAIL ")+message)
func same_numbers(a: Dictionary, b: Dictionary) -> bool:
	if a.size()!=b.size(): return false
	for key in a:
		if not b.has(key) or absf(float(a[key])-float(b[key]))>1e-12: return false
	return true
func same_saved_look(a: Dictionary, b: Dictionary) -> bool:
	# JSON decimal parsing can move a double by one ULP. Colors round back
	# into native float32 exactly; exposure/energy remain float64 settings.
	return a.version==b.version and a.palette==b.palette and a.colors==b.colors and same_numbers(a.settings,b.settings)
func open_world(path: String) -> Node3D:
	var world = load("res://studies/cozy_worlds.tscn").instantiate()
	world.set_meta("movie_capture",true)
	# Straight into a world, past the worlds title.
	world.set_meta("no_title",true)
	world.places_path = path
	root.add_child(world)
	current_scene = world
	while not world.places_ready: await process_frame
	return world
func run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("Cozy worlds test timed out"); quit(2))
	root.size = Vector2i(1440,900)
	var path := "/private/tmp/cozy-worlds-test-%d/places.json" % Time.get_ticks_usec()
	var primary := await open_world(path)
	var flow: Node = primary.places
	primary._process(0.01)
	check(flow.initialized and not flow.busy,"The place is ready to play")
	check(root.find_children("*","Node3D",false,false).size()==1,"Only one full world is loaded")
	check(not primary.resident_enabled and not primary.creature.visible,"The resident stays away from the landscape")
	var data: NativeTerrainData = primary._chunk_editor.data
	var initial: Dictionary = data._recipe_settings.duplicate(true)
	var heights: PackedFloat32Array = data.heights.duplicate()
	var eye: Transform3D = primary.camera.global_transform
	var resting_shroud: float = primary._atmosphere.shroud
	var wind_time: float = primary._atmosphere._wind_time
	var sky: Dictionary = primary._celestial.look.document()
	flow.regrow()
	check(flow.busy and flow.phase=="reversing","Regrow starts by folding the landscape down")
	flow.regrow()
	check(flow.generation==0,"Duplicate regeneration is ignored")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	check(flow.handle(press) and not primary.save_current(),"While it regrows, gestures and saving wait")
	while primary._growth.terrain>=0.995: await process_frame
	check(primary._growth.foliage==0 and primary._growth.water==0,"Plants and water retreat before terrain lowers")
	var shook := false
	var reverse_shook := false
	var added_shroud := false
	var moving_camera := false
	while flow.busy:
		await process_frame
		added_shroud = added_shroud or primary._atmosphere.shroud>resting_shroud
		if flow.phase=="reversing": reverse_shook = reverse_shook or primary._tremor.trauma>0.1
		if flow.phase=="growing":
			shook = shook or primary._tremor.trauma>0.1
			moving_camera = moving_camera or not primary.camera.global_transform.is_equal_approx(eye)
	check(shook and moving_camera,"Rising terrain shakes the camera")
	check(reverse_shook,"Degrowth also produces terrain tremor")
	check(not added_shroud,"Rebuild and growth never add a transition fog blanket")
	check(primary._atmosphere._wind_time>wind_time,"The atmosphere keeps moving while the world is paused")
	check(flow.generation==1 and not flow.handle(press),"One regeneration finishes and hands gestures back")
	check(not primary.resident_enabled and not primary.creature.visible,"The resident stays away after a regrow")
	check(data._recipe_settings.kind=="inland" and data.heights!=heights,"Regeneration builds a genuinely new native terrain")
	check(primary._growth.terrain==1 and primary._growth.water==1 and primary._growth.foliage==1,"Forward growth restores exact finished channels")
	check(primary._tremor.trauma==0 and is_equal_approx(primary.distance,flow.next_distance),"Camera settles into the framing for the new landscape")
	check(primary._celestial.look.document()!=sky,"Regeneration reveals a newly generated color palette")
	var generated: Dictionary = data._recipe_settings.duplicate(true)
	var new_look: Dictionary = primary._celestial.look.document()
	var new_visuals: Dictionary = primary._world_visuals.document()
	var weather: int = primary._precipitation.preset_index
	check(weather==primary._precipitation.PRESET_NAMES.find(flow.generated_world.mood.weather),"Generated weather is applied")
	primary._chunk_editor.undo()
	check(data.heights==heights and data._recipe_settings==initial,"Undo restores the entire previous terrain")
	check(primary._celestial.look.document()==sky and primary._growth.terrain==1,"Undo restores the old full-grown world and its palette")
	primary._chunk_editor.redo()
	check(data._recipe_settings==generated and primary._celestial.look.document()==new_look,"Redo restores generated terrain and its palette")
	check(primary.save_current(),"The regenerated landscape saves")
	primary.queue_free()
	await process_frame
	await process_frame
	# A world past the title opens on a new plain; the saved place is opened
	# into it as the world session does (scripts/world_session.gd).
	primary = await open_world(path.get_basename()+"-other.json")
	check(await primary.places.open_place(path),"The saved place opens")
	check(primary._chunk_editor.data._recipe_settings==generated and same_saved_look(primary._celestial.look.document(),new_look) and primary._precipitation.preset_index==weather,"Reopening restores the generated terrain, colors and weather")
	check(same_numbers(primary._world_visuals.document(),new_visuals),"Reopening restores the generated fog banks and wisps")
	check(not primary.resident_enabled,"Reopening keeps the resident away")
	print("Cozy worlds: %d checks, %d failures" % [checks,failures])
	primary.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
