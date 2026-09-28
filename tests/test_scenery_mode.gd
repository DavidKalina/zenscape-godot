extends SceneTree
## The product opens as a landscape diorama: Bigfoot stays built but hidden,
## his tools are absent, and regrowth replays the land without a carry.
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("Scenery mode test timed out"); quit(2))
	root.size = Vector2i(1440,900)
	var path := "/private/tmp/zenscape-scenery-test-%d/places.json" % Time.get_ticks_usec()
	var world = load("res://studies/cozy_worlds.tscn").instantiate()
	world.set_meta("movie_capture",true)
	world.places_path = path
	root.add_child(world)
	current_scene = world
	while not world.places_ready: await process_frame
	var flow: Node = world.places
	check(world.scenery_mode,"The product defaults to scenery mode")
	check(not world.resident_enabled,"Startup leaves Bigfoot out")
	world._process(0.01)
	check(not world.creature.visible,"The hidden resident is not drawn")
	check(not world.invite_bigfoot(Vector3(0,0,5)),"Invitations are declined in scenery mode")
	check(not world.resident_enabled,"A declined invitation keeps him away")
	var popup: PopupMenu = world._world_menu.get_popup()
	for index in range(popup.item_count):
		check(popup.get_item_text(index) not in ["Bigfoot","His spot","See both stories","New crossing glade","New chasm glade"],"World menu omits resident item "+popup.get_item_text(index))
	var palette: NativeBuildPalette = world._build_palette
	check(not palette._entries.has("bigfoot") and not palette._entries.has("bigfoot_tree"),"Build palette omits Bigfoot and his tree")
	for tool_rail in root.find_children("*","Control",true,false):
		if tool_rail.has_method("_family_tools"):
			check("bigfoot_tree" not in tool_rail._family_tools("Place"),"Tool rail omits the Bigfoot tree")
	if world.fish != null and not world.fish.population.is_empty():
		var swimmer: Node3D = world.fish.population[0].node
		var before: Vector3 = swimmer.position
		for step in range(30): world._process(0.05)
		check(swimmer.position != before,"Pond fish keep swimming without the resident")
	var heights: PackedFloat32Array = world._chunk_editor.data.heights.duplicate()
	flow.regrow(11)
	check(flow.busy and not flow.holding,"Regrow starts without carrying anyone")
	while flow.busy: await process_frame
	check(flow.generation == 1 and not flow.holding,"One regeneration completes")
	check(world._chunk_editor.data.heights != heights,"Regrowth builds new terrain")
	check(not world.resident_enabled and not world._paused,"The new landscape is live and still unpopulated")
	check(flow.save_places(),"Scenery landscape saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(not saved.slots[saved.active].state.diorama.resident,"The save records no resident")
	world._chunk_editor.undo()
	check(not world.resident_enabled,"Undo does not bring Bigfoot back")
	print("Scenery mode: %d checks, %d failures" % [checks,failures])
	world.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures>0 else 0)
