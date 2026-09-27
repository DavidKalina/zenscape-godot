## Headless trace of the regeneration rumble and fog pour (scripts/world_rumble.gd)
## over a Regenerate landscape and a New open plain. Prints the envelope every
## quarter second, when each phase starts, and how long the shake outlives it.
## Godot --headless --path . -s tools/probe_regen_envelope.gd
extends SceneTree
var scene: Node3D
var rumble: Node

func _initialize() -> void: run.call_deferred()

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	var folder := OS.get_temp_dir().path_join("zs-regen-envelope-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	scene.places_path = folder.path_join("places.json")
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	rumble = scene.world_rumble
	await create_timer(1).timeout
	await trace("regenerate",func() -> void: scene.places.regrow(184))
	await trace("new plain",func() -> void: scene.places.new_plain(7))
	cost()
	scene.queue_free()
	await process_frame
	quit(0)

func trace(label: String, start: Callable) -> void:
	var began := Time.get_ticks_msec()
	var phase := ""
	var next := 0.0
	var peak := 0.0
	var fog_peak := 0.0
	var busy_end := -1.0
	var rumble_end := -1.0
	var fog_end := -1.0
	start.call()
	while true:
		await process_frame
		var t := (Time.get_ticks_msec()-began)/1000.0
		if scene.places.phase != phase:
			phase = scene.places.phase
			print("  %6.2f s  phase %s" % [t,phase])
		peak = maxf(peak,rumble.strength)
		fog_peak = maxf(fog_peak,rumble.pour.x)
		if busy_end < 0.0 and not scene.places.busy: busy_end = t
		if busy_end >= 0.0 and rumble_end < 0.0 and rumble.level <= 0.0: rumble_end = t
		if busy_end >= 0.0 and fog_end < 0.0 and rumble.pour.x <= 0.0: fog_end = t
		if t >= next:
			next += 0.25
			var audio: Node = scene.genesis_audio
			print("  %6.2f s  level %.2f  rumble %.3f  trauma %.2f  audio %.2f  pour %.2f lid %.2f front %.2f  %s" % [t,rumble.level,rumble.strength,scene._tremor.trauma,audio._gain[0],rumble.pour.x,rumble.pour.y,rumble.pour.z,"busy" if scene.places.busy else ("tail" if rumble.holding else "")])
		if rumble_end >= 0.0 and fog_end >= 0.0: break
		if t > 90.0:
			print("  timed out")
			break
	print("REGEN ENVELOPE %s: busy %.1f s, rumble until %.1f s, fog until %.1f s, peak rumble %.3f, peak fog %.2f" % [label,busy_end,rumble_end,fog_end,peak,fog_peak])
	await create_timer(0.5).timeout

func cost() -> void:
	rumble.hold(&"probe",1.0)
	rumble.pour_fog()
	var began := Time.get_ticks_usec()
	for i in range(1000): rumble._process(1.0/60.0)
	var per := (Time.get_ticks_usec()-began)/1000.0
	rumble.release(&"probe")
	rumble.drain_fog()
	print("REGEN ENVELOPE cost: %.1f us per frame (1000 frames held and pouring)" % per)
