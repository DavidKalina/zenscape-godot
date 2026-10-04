extends SceneTree
## Headless probe of breeze-ribbon sweeps (scripts/breeze_ribbons.gd) and the
## blades they kick up (scripts/wind_kicked_blades.gd) in the product scene:
## every second, how many ribbons there are, how many are sweeping, the kicks
## and the blades in the air, and whether the blades layer is shown. Nothing
## is rendered: the look is unverified.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_sweeps.gd -- [--sweeps=6] [--seconds=60]
var scene: Node3D

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var seconds := 60.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): seconds = float(arg.get_slice("=",1))
	create_timer(600).timeout.connect(func() -> void: push_error("Sweep probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-sweep-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	var ribbons: Node = scene._atmosphere.wind_trails
	var blades: Node = scene._kicked_blades
	print("ribbons script ",ribbons.get_script().resource_path," sweep_gain ",ribbons.get("sweep_gain"))
	var swept := 0
	var peak_blades := 0
	var sweeping_ids := {}
	for second in range(int(seconds)):
		var sweeping := 0
		var kicks := 0
		for f in range(60):
			await process_frame
			for r: Dictionary in ribbons.ribbons:
				if not (r.get("sweep",{}) as Dictionary).is_empty():
					sweeping_ids[r.id] = true
			kicks = maxi(kicks,ribbons.kicks().size())
			peak_blades = maxi(peak_blades,blades.blades.size())
		for r: Dictionary in ribbons.ribbons:
			if not (r.get("sweep",{}) as Dictionary).is_empty(): sweeping += 1
		print("t=%2d ribbons=%d sweeping=%d kicks=%d blades=%d shown=%s fronts_sent=%d" % [second+1,ribbons.ribbons.size(),sweeping,kicks,blades.blades.size(),blades.visible,scene._atmosphere.fronts.sent])
	swept = sweeping_ids.size()
	print("SWEEPS %d  PEAK BLADES %d" % [swept,peak_blades])
	quit(0)
