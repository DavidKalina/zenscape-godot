extends SceneTree
## suite: slow
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(120).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	# Straight into a world, as before the worlds title.
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/cozy-atmosphere-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	scene.places.regrow(110)
	while scene.places.busy: await process_frame
	await process_frame
	check(scene.places.generated_world.mood.weather=="mist","Reproduction selects the misty forest climate")
	check(scene._world_visuals.fog_density>0.2 and scene._world_visuals._fog.visible,"Misty regeneration retains visible drifting fog banks after formation")
	check(scene._world_visuals.peak_density>0 and scene._world_visuals._peaks.visible,"Generated forest retains wisps around its canopy")
	var clock: float = scene._world_visuals._fog.material.get_shader_parameter("bank_clock")
	await create_timer(.15).timeout
	check(scene._world_visuals._fog.material.get_shader_parameter("bank_clock")>clock,"Atmosphere keeps moving after regrowth finishes")
	var visuals: Dictionary = scene._world_visuals.document()
	var saved: Dictionary = NativeGardenStore.capture(scene)
	scene._world_visuals.restore()
	NativeGardenStore.restore(scene,saved)
	check(scene._world_visuals.document()==visuals,"Full atmosphere survives save/restore")
	print("Cozy atmosphere: ",failures," failures")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
