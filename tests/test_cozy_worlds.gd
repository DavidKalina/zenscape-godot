extends SceneTree
## NEEDS REWRITE (2026-10-02): written for the old cozy opening, with a cozy
## resident, a populated world and carry-drag of the resident. The game now
## opens on a bare Genesis plain with Bigfoot hidden, so this test fails and
## times out on expectations that no longer hold. Rewrite it for the
## bare-plain opening; kept rather than deleted because it is the main
## scene's integration test.
## Regrowth, real dispatched carry input, native editor undo and persistence.
var failures := 0
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func same_numbers(a: Dictionary, b: Dictionary) -> bool:
	if a.size()!=b.size(): return false
	for key in a:
		if not b.has(key) or absf(float(a[key])-float(b[key]))>1e-12: return false
	return true
func same_saved_look(a: Dictionary, b: Dictionary) -> bool:
	# JSON decimal parsing can move a double by one ULP. Colors round back
	# into native float32 exactly; exposure/energy remain float64 settings.
	return a.version==b.version and a.palette==b.palette and a.colors==b.colors and same_numbers(a.settings,b.settings)
func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform()*point
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func button(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform()*point
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func grab(walk: Node) -> void:
	var at: Vector2 = walk.scene.camera.unproject_position(walk.scene.creature.global_position+Vector3.UP*1.5)
	button(at,true)
	motion(at+Vector2(12,0))
	check(walk.holding and not walk.scene._resident_play.carrying,"Real drag reaches the shared cozy input handler")
func open_world(path: String) -> Node3D:
	var world = load("res://studies/cozy_worlds.tscn").instantiate()
	world.set_meta("movie_capture",true)
	# Straight into a world, as before the worlds title.
	world.set_meta("no_title",true)
	world.places_path = path
	root.add_child(world)
	current_scene = world
	while not world.places_ready: await process_frame
	return world
func run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("Regrowth test timed out"); quit(2))
	root.size = Vector2i(1440,900)
	var path := "/private/tmp/cozy-regrowth-test-%d/places.json" % Time.get_ticks_usec()
	var primary := await open_world(path)
	var flow: Node = primary.places
	primary._process(0.01)
	check(primary.foliage_tread.records()[0].w>0.0,"The cozy resident publishes the restored foliage wake")
	check(primary._chunk_editor.content._materials.trunk.get_shader_parameter("tree_tread") and primary._chunk_editor.content._materials.canopy.get_shader_parameter("tree_tread"),"Native trunks and crowns both respond to the wake")
	check(primary._chunk_editor.data.objects.size()>100,"Full native landscape is ready")
	check(root.find_children("*","Node3D",false,false).size()==1,"Only one full world is loaded")
	var data: NativeTerrainData = primary._chunk_editor.data
	var initial: Dictionary = data._recipe_settings.duplicate(true)
	var heights: PackedFloat32Array = data.heights.duplicate()
	var eye: Transform3D = primary.camera.global_transform
	var resting_shroud: float = primary._atmosphere.shroud
	var resting_loosen: float = primary._atmosphere.loosen
	var wind_time: float = primary._atmosphere._wind_time
	var sky: Dictionary = primary._celestial.look.document()
	grab(flow)
	check(primary.foliage_tread.records()[0] == Vector4.ZERO,"Picking Bigfoot up clears the old wake")
	var size: Vector2 = root.get_visible_rect().size
	motion(size*Vector2(.97,.5))
	while not flow.busy: await process_frame
	check(flow.holding and flow.phase=="reversing","Holding at an edge starts degrowth")
	flow.regrow()
	check(flow.generation==0,"Duplicate regeneration is ignored")
	while primary._growth.terrain>=0.995: await process_frame
	check(primary._growth.foliage==0 and primary._growth.water==0,"Plants and water retreat before terrain lowers")
	check(primary._atmosphere.shroud==resting_shroud and primary._atmosphere.loosen==resting_loosen,"Degrowth preserves the landscape atmosphere without adding a fog blanket")
	button(size*Vector2(.5,.6),false)
	check(flow.pending_drop and flow.holding,"Release during regeneration waits for safe terrain")
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
	check(shook and moving_camera,"Rising terrain produces actual camera tremor while Bigfoot is held")
	check(reverse_shook,"Degrowth also produces terrain tremor")
	check(not added_shroud,"Rebuild and growth never add a transition fog blanket")
	check(primary.navigation.last_worker_executed and primary.navigation.last_worker_count==2,"Regrowth prepares walkable ground on two workers before landing")
	check(primary._atmosphere._wind_time>wind_time,"Normal atmosphere keeps moving during held-world pause")
	check(primary._atmosphere.shroud==0 and primary._atmosphere.loosen==0.5,"Completion retains the new landscape atmosphere")
	check(flow.generation==1 and not flow.holding,"One regeneration finishes and releases Bigfoot")
	check(primary.environment_life.arrival_pending,"Regrowth landing queues an introduction to the new place")
	check(data._recipe_settings.kind=="inland" and data.heights!=heights,"Regeneration builds a genuinely new native terrain variation")
	check(data._recipe_settings.composition!=initial.family,"Regeneration chooses a different landscape family")
	check(primary._growth.terrain==1 and primary._growth.water==1 and primary._growth.foliage==1,"Forward growth restores exact finished channels")
	check(primary.navigation.is_safe(primary.creature._safe_position),"Bigfoot lands on safe new terrain")
	check(primary._tremor.trauma==0 and is_equal_approx(primary.distance,flow.next_distance),"Camera settles into the framing for the new landscape")
	check(primary._celestial.look.document()!=sky,"Regeneration reveals a newly generated color palette")
	var generated: Dictionary = data._recipe_settings.duplicate(true)
	var new_look: Dictionary = primary._celestial.look.document()
	var new_visuals: Dictionary = primary._world_visuals.document()
	var weather: int = primary._precipitation.preset_index
	check(weather==primary._precipitation.PRESET_NAMES.find(flow.generated_world.mood.weather),"Generated weather is applied")
	primary._chunk_editor.undo()
	check(data.heights==heights and data._recipe_settings==initial,"Undo restores the entire previous terrain recipe")
	check(primary._celestial.look.document()==sky and primary._growth.terrain==1 and primary.resident_enabled,"Undo restores the old full-grown world, palette and Bigfoot")
	primary._chunk_editor.redo()
	check(data._recipe_settings==generated and primary._celestial.look.document()==new_look,"Redo restores generated terrain and its palette")
	check(flow.save_places(),"Regenerated landscape saves")
	primary.queue_free()
	await process_frame
	await process_frame
	primary = await open_world(path)
	flow = primary.places
	check(primary._chunk_editor.data._recipe_settings==generated and same_saved_look(primary._celestial.look.document(),new_look) and primary._precipitation.preset_index==weather,"Reopening restores the generated terrain, colors and weather")
	check(same_numbers(primary._world_visuals.document(),new_visuals),"Reopening restores the generated fog banks and wisps")
	grab(flow)
	flow.cancel_carry()
	check(not flow.holding and primary.navigation.is_safe(primary.creature._safe_position),"Normal carry cancellation restores a safe position")
	print("Cozy regrowth: %d checks, %d failures" % [checks,failures])
	primary.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
