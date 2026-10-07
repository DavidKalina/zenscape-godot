extends SceneTree
## Stills of the pilot running on the walk-test island (studies/
## walk_island.tscn), for judging the puffs (scripts/pilot_puffs.gd) and the
## run by eye: a run straight on (the puffs off the heels), thrown back into
## a skid (the spray), a chained jump's landings (the rings), then standing.
## Rendered only when asked for (needs a window):
##   Godot --windowed --fixed-fps 60 --path . -s res://tools/capture_pilot_run.gd -- --no-title [--out=DIR]
## Writes DIR/<moment>.png (default /tmp/pilot_run) and quits.

## Moments to save: the name and the frame after the island is ready.
const RUN_SHOTS := {"run_a":40,"run_b":52,"run_c":64}
const SKID_SHOTS := {"skid_a":4,"skid_b":9,"skid_c":15,"skid_turn":22}

var out := "/tmp/pilot_run"
var scene: Node3D

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(300.0).timeout.connect(func() -> void: push_error("pilot run capture timed out"); quit(2))
	scene = load("res://studies/walk_island.tscn").instantiate()
	scene.places_path = OS.get_temp_dir().path_join("pilot-run-capture-%d" % Time.get_ticks_usec()).path_join("places.json")
	root.size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	while not scene.walk_ready: await process_frame
	for i in range(90): await process_frame
	await _save("stand")
	# The run.
	Input.action_press(&"move_forward")
	for i in range(80):
		await process_frame
		if RUN_SHOTS.values().has(i): await _save(RUN_SHOTS.find_key(i))
	# Thrown back: the skid.
	Input.action_release(&"move_forward")
	Input.action_press(&"move_back")
	for i in range(30):
		await process_frame
		if SKID_SHOTS.values().has(i): await _save(SKID_SHOTS.find_key(i))
	Input.action_release(&"move_back")
	# Chained jumps at a run, saved as each lands.
	Input.action_press(&"move_forward")
	for i in range(30): await process_frame
	var eye: Node = scene.wanderer
	var landed := 0
	var was_grounded := true
	for i in range(240):
		var grounded: bool = eye.motor.grounded
		if grounded and not was_grounded:
			landed += 1
			for k in range(3): await process_frame
			await _save("land_%d" % landed)
			if landed == 3: break
			Input.action_press(&"walk_jump")
		elif grounded: Input.action_press(&"walk_jump")
		else:
			if eye.motor.velocity.y < 0.0:
				Input.action_release(&"walk_jump")
				if not FileAccess.file_exists(out.path_join("air_%d.png" % (landed+1))): await _save("air_%d" % (landed+1))
		was_grounded = grounded
		await process_frame
	Input.action_release(&"walk_jump")
	Input.action_release(&"move_forward")
	for i in range(60): await process_frame
	await _save("after")
	print("PILOT RUN captured ",out)
	quit(0)

func _save(moment: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(moment+".png"))
