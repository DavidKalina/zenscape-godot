extends SceneTree
## The build view's default framing (studies/diorama.gd `_frame_diorama`):
## tilted up from the old 0.82 so the mountains round the sky world stand
## in the top of the frame, the plate still its clear focus: the island
## and its rock all on screen, filling most of it one way, aimed between
## the land and its rock; ranges in view. A view the player orbited is never
## reframed: a saved place's camera is put back as it was. The title keeps
## its own orbit (`_frame_title`), and world_beauty scores from the old
## framing, so generated worlds don't change. Headless: numbers only.
const SkyWorld = preload("res://scripts/sky_world.gd")
const WorldBeauty = preload("res://scripts/world_beauty.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print(("OK   " if ok else "FAIL ")+message)
	if not ok: failures += 1

func run() -> void:
	create_timer(600).timeout.connect(func() -> void: print("FAIL: overview framing timed out"); quit(2))
	var scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/overview-framing-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.size = Vector2i(1440,900)
	root.content_scale_size = Vector2i(1440,900)
	root.add_child(scene)
	current_scene = scene
	var waited := 0
	while not (scene.places_ready and scene.shell_ready) and waited < 3000:
		await process_frame
		waited += 1
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await process_frame
	scene._frame_diorama()
	await process_frame
	var camera: Camera3D = scene.camera
	check(scene.overview_polar > 0.82 and scene.overview_polar <= 1.2 and is_equal_approx(scene.polar,scene.overview_polar) and is_equal_approx(scene.yaw,0.35),"The overview tilts up a little from 0.82 to %.2f, the same way round" % scene.polar)
	# Straight out along the view, the frame's top no longer looks far
	# under the horizon (from 0.82 it looked 20 degrees under: no range).
	var forward := -camera.global_transform.basis.z
	var screen := Vector2(root.size)
	var top_ray := camera.project_ray_normal(Vector2(screen.x*0.5,0.0))
	check(rad_to_deg(asin(top_ray.y)) > -6.0 and forward.y < 0.0,"The frame's top looks %.1f degrees from the horizon, the view still down on the plate" % rad_to_deg(asin(top_ray.y)))
	# A range laid out near the plate, its top over the horizon, in view.
	var seen := 0
	var peaks: Node3D = scene.wanderer.islands.peaks
	for r: Dictionary in SkyWorld.layout().ranges:
		var at: Vector3 = peaks.global_transform*(Vector3(r.at.x,0.0,r.at.z)+Vector3.UP*(-40.0))
		if camera.is_position_behind(at): continue
		var p: Vector2 = camera.unproject_position(at)
		if Rect2(Vector2.ZERO,screen).has_point(p): seen += 1
	check(seen > 0,"Ranges of the sky world stand in the default view, their feet over the cloud sea in frame (%d)" % seen)
	# The plate the focus: all on screen, filling most of it one way.
	var editor: NativeChunkEditor = scene._chunk_editor
	var data := editor.data
	var outside := 0
	var spread := Rect2()
	var first := true
	for i in range(data.points.size()):
		if data.shore_distance[i] < 0.0: continue
		var q: Vector2 = data.points[i]
		var h: Variant = data.ground_height(q)
		var at: Vector2 = camera.unproject_position(editor.terrain.to_global(Vector3(q.x,float(h) if h != null else 0.0,q.y)))
		if not Rect2(Vector2.ZERO,screen).has_point(at): outside += 1
		spread = Rect2(at,Vector2.ZERO) if first else spread.expand(at)
		first = false
	var share := maxf(spread.size.x/screen.x,spread.size.y/screen.y)
	check(not first and outside == 0 and share > 0.5,"The island is all on screen and fills %.0f %% of it one way" % (share*100.0))
	# An orbited view is not reframed: a saved place's camera comes back.
	var store := preload("res://scripts/native_garden_store.gd")
	check(FileAccess.get_file_as_string("res://scripts/native_garden_store.gd").contains("polar") and FileAccess.get_file_as_string("res://scripts/cozy_regrowth.gd").contains("layout") ,"A saved place keeps its own camera (native_garden_store), framed afresh only when new")
	check(is_equal_approx(WorldBeauty.POLAR,0.82),"Generated worlds are scored from the old framing, so they stay the same")
	scene.queue_free()
	await process_frame
	print("PASS: overview framing" if failures == 0 else "FAIL: overview framing (%d)" % failures)
	quit(1 if failures else 0)
