extends SceneTree
## The flight study's sky pack (scripts/flight_pack_sky.gd), rendered: for
## each of its stations, one wide still from behind and above the entry,
## then the perfect bot flies it through the study's own tick and the chase
## camera is grabbed every `--every` seconds, to check the greybox reads as
## floating islands round the line. No run is saved (it stops before the
## end). Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_flight_sky.gd \
##     -- --no-title [--out=/private/tmp/zs-flight-sky] [--only=sky_spire] [--every=3]
const Course = preload("res://scripts/flight_course.gd")
const DT := 1.0/60.0
var out := "/private/tmp/zs-flight-sky"
var only := ""
var every := 3.0

func _initialize() -> void:
	run.call_deferred()

func still(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path := out.path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	print("SKY still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = argument.trim_prefix("--only=")
		elif argument.begins_with("--every="): every = float(argument.trim_prefix("--every="))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("sky capture timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	var study: Node3D = load("res://studies/flight_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = "user://flight_runs_capture"
	root.add_child(study)
	current_scene = study
	while not study.flight_ready: await process_frame
	study._hint.visible = false
	for s: Dictionary in Course.pack(Course.SkyPack.PACK):
		if only != "" and s.id != only: continue
		study.pilot = "perfect"
		study.start(s)
		# Wide: behind and above the entry, looking at the tokens' middle.
		var middle := Vector3.ZERO
		for p in Course.tokens(s): middle += p
		middle /= float(s.tokens.size())
		var at := Course.origin(s)
		var eye := at+Vector3(-55.0,48.0,45.0)
		study.camera.global_transform = Transform3D(Basis.looking_at(middle-eye,Vector3.UP),eye)
		study.camera.fov = 60.0
		await still("%s_wide" % s.id)
		var next := every
		while not study.run.done and study.run.t < 38.0:
			study.tick(DT)
			if study.run.t >= next:
				await still("%s_%02d" % [s.id,roundi(next)])
				next += every
			# The last token: stop before the run ends and saves.
			if study.run.next_token() == s.tokens.size()-1: break
	quit(0)
