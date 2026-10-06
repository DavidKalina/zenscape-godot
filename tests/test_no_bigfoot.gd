extends SceneTree
## The product is a landscape diorama with no Bigfoot in it: nothing of his is
## built, no menu, palette or rail offers him or his tree, the life never calls
## him, and regrowth and saving go on without him.
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
	create_timer(180).timeout.connect(func() -> void: push_error("No-Bigfoot test timed out"); quit(2))
	root.size = Vector2i(1440,900)
	var path := "/private/tmp/zenscape-no-bigfoot-test-%d/places.json" % Time.get_ticks_usec()
	var world = load("res://studies/cozy_worlds.tscn").instantiate()
	world.set_meta("movie_capture",true)
	# Straight into a world, as before the worlds title.
	world.set_meta("no_title",true)
	world.places_path = path
	root.add_child(world)
	current_scene = world
	while not world.places_ready: await process_frame
	var flow: Node = world.places
	for field: String in ["creature","brain","routine","environment_life","_bigfoot","resident_enabled","scenery_mode"]:
		check(world.get(field) == null,"The scene has no "+field)
	for method: String in ["invite_bigfoot","_summon_bigfoot","_focus_bigfoot","open_crossing_glade"]:
		check(not world.has_method(method),"The scene has no "+method)
	world._process(0.01)
	# The old tree keeps its saved name ("bigfoot_tree"); nothing else of his is built.
	for node in world.find_children("*","",true,false):
		var script: Script = node.get_script()
		check(not (script != null and "bigfoot" in script.resource_path),"No node runs a Bigfoot script: "+str(node.get_path()))
		check(not (node.name.to_lower().contains("bigfoot") and not node.name.contains("bigfoot_tree")),"No node is Bigfoot's: "+str(node.get_path())+" ("+node.name+")")
	var popup: PopupMenu = world._world_menu.get_popup()
	for index in range(popup.item_count):
		check(popup.get_item_text(index) not in ["Bigfoot","His spot","See both stories","New crossing glade","New chasm glade"],"World menu omits resident item "+popup.get_item_text(index))
	var palette: NativeBuildPalette = world._build_palette
	check(not palette._entries.has("bigfoot") and not palette._entries.has("bigfoot_tree"),"Build palette omits Bigfoot and the old tree")
	for tool_rail in root.find_children("*","Control",true,false):
		if tool_rail.has_method("_family_tools"):
			check("bigfoot_tree" not in tool_rail._family_tools("Place"),"Tool rail omits the old tree")
	var life: Node = world.get("land_life")
	if life != null:
		for kind: String in life.SUMMONS: check(not kind.begins_with("bigfoot"),"The life never calls Bigfoot: "+kind)
		check(not life.summon("bigfoot").is_empty(),"Asking for Bigfoot calls nothing")
		check(life.moments.get("bigfoot") == null and life.moments.get("trail") == null,"Life's moments have no sighting and no trail")
	if world.fish != null and not world.fish.population.is_empty():
		var swimmer: Node3D = world.fish.population[0].node
		var before: Vector3 = swimmer.position
		for step in range(30): world._process(0.05)
		check(swimmer.position != before or not world.fish.visible,"Pond fish keep swimming where they show")
	var heights: PackedFloat32Array = world._chunk_editor.data.heights.duplicate()
	flow.regrow(11)
	check(flow.busy,"Regrow starts")
	while flow.busy: await process_frame
	check(flow.generation == 1,"One regeneration completes")
	check(world._chunk_editor.data.heights != heights,"Regrowth builds new terrain")
	check(not world._paused,"The new landscape is live")
	check(flow.save_places(),"The landscape saves")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var state: Dictionary = saved.slots[saved.active].state
	for key: String in ["diorama","bigfoot_habits","bigfoot_living","cave_system"]:
		check(not state.has(key),"The save records no "+key)
	# A save from before Bigfoot went, carrying his keys, still restores.
	state["diorama"] = {"resident":true,"resident_scale":1.0,"position":[0.0,0.0,0.0]}
	state["bigfoot_habits"] = {"version":1}
	check(NativeGardenStore.valid(world,state),"A save with Bigfoot's old keys is still valid")
	NativeGardenStore.restore(world,state)
	check(world.get("creature") == null,"Restoring it brings nobody back")
	print("No Bigfoot: %d checks, %d failures" % [checks,failures])
	world.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures>0 else 0)
