extends SceneTree
## Headless probe of quitting mid-glide with the sky islets streaming
## (scripts/sky_islets.gd): the cozy worlds scene is loaded, the wanderer
## walks off the plate's edge and glides on, islets build round it, and the
## game quits at once, workers and all. Run with --verbose to see what is
## left at exit (leaked instances, resources still in use).
##   godot --headless --verbose --fixed-fps 60 --path . -s res://tools/probe_islets_quit.gd -- --no-title
var scene: Node3D

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("islets quit probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-islets-quit-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	var eye: Node = scene.wanderer
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	eye._yaw = atan2(-1.0,0.0)+eye._turn()
	eye.motor.facing = eye._yaw-eye._turn()
	eye._polar = PI*0.5
	var press := InputEventKey.new()
	press.keycode = KEY_W
	press.physical_keycode = KEY_W
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	for i in range(120):
		await frames(1)
		if eye.flying: break
	# Glide on while the islets stream in; then, mid-build, quit.
	var islets: Node3D = eye.islands.islets
	for i in range(240):
		await frames(1)
		eye.glide.position += Vector3(2.0,0.0,1.0)
	print("islets built %d, being made %d, flying %s" % [islets.islet_count(),islets._making.size(),str(eye.flying)])
	# As the window's close does (cozy_worlds `_quit_safely`): save, leave
	# the world, quit.
	scene._quit_safely()
