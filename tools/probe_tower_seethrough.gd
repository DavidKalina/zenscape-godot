extends "res://tools/capture_sky_cumulus.gd"
## Does what stands behind the towering cumulus show through it? From a
## ring of spots round the home tower, four frames each: all drawn, the
## ranges hidden, the towers hidden, both hidden. Where the tower covers
## the sky (both-hidden against ranges-hidden), a pixel that changes when
## the ranges come back and is not the range standing in front (all against
## towers-hidden) is a range seen through the cloud. Prints the share of
## the tower's pixels that leak, per bearing. Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/probe_tower_seethrough.gd \
##     -- --no-title --out=/private/tmp/zs-seethrough [--bearings=12] [--reach=800] [--hold=40 frames]

func run() -> void:
	var bearings := 12
	var reach := 800.0
	var hold := 40
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--bearings="): bearings = int(argument.trim_prefix("--bearings="))
		elif argument.begins_with("--reach="): reach = float(argument.trim_prefix("--reach="))
		elif argument.begins_with("--hold="): hold = int(argument.trim_prefix("--hold="))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("see-through probe timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = out.path_join("places-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	scene.world_clock.running = false
	eye = scene.wanderer
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	await frames(5)
	eye._launch(6.0,false)
	eye.set_process(false)
	eye._layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var islands: Node3D = eye.islands
	for i in range(900):
		if not islands.lands.has(null): break
		await frames(1)
	islands.towers.advance(0.6,Vector3.ZERO)
	islands.towers.flush()
	var b: Dictionary = islands.towers.built["0,0"]
	var shape: RefCounted = b.shape
	var mid: Vector3 = islands.towers.global_of(b,Vector3(shape._axis(80.0).x,80.0,shape._axis(80.0).y))
	var worst := 0.0
	for k in range(bearings):
		var a := TAU*k/bearings
		var at := mid+Vector3(cos(a),0.0,sin(a))*reach+Vector3.DOWN*40.0
		var shot := {"label":"orbit","eye":at,"look":mid+Vector3.UP*40.0}
		await _hold(shot,noon,maxi(hold,90) if k == 0 else hold)
		var all := await _grab()
		var see_through := 0
		for g in islands.peaks.find_children("*","GeometryInstance3D",true,false):
			if (g as GeometryInstance3D).is_visible_in_tree() and (g as GeometryInstance3D).transparency > 0.0: see_through += 1
		print("SEETHROUGH bearing %3d deg: %d range meshes drawn see-through" % [roundi(rad_to_deg(a)),see_through])
		islands.peaks.visible = false
		await _hold(shot,noon,3)
		var bare := await _grab()
		islands.towers.visible = false
		await _hold(shot,noon,3)
		var neither := await _grab()
		islands.peaks.visible = true
		await _hold(shot,noon,3)
		var no_tower := await _grab()
		islands.towers.visible = true
		var tower := 0
		var leak := 0
		var leak_img := Image.create(all.get_width(),all.get_height(),false,Image.FORMAT_RGB8)
		for y in range(0,all.get_height(),2):
			for x in range(0,all.get_width(),2):
				var cb := bare.get_pixel(x,y)
				if _diff(cb,neither.get_pixel(x,y)) < 0.06: continue
				tower += 1
				var ca := all.get_pixel(x,y)
				if _diff(ca,cb) > 0.03 and _diff(ca,no_tower.get_pixel(x,y)) > 0.03:
					leak += 1
					leak_img.set_pixel(x,y,Color.RED)
				else: leak_img.set_pixel(x,y,ca)
		var share := float(leak)/maxf(tower,1)
		worst = maxf(worst,share)
		print("SEETHROUGH bearing %3d deg: tower %d px, leaking %d px (%.1f%%)" % [roundi(rad_to_deg(a)),tower,leak,share*100.0])
		all.save_png(out.path_join("orbit-%03d.png" % roundi(rad_to_deg(a))))
		leak_img.save_png(out.path_join("leak-%03d.png" % roundi(rad_to_deg(a))))
	print("SEETHROUGH worst %.1f%%" % (worst*100.0))
	quit(0)

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

static func _diff(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
