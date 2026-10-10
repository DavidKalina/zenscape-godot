extends SceneTree
## Stills of the flight study's moments pack (studies/flight_study.tscn,
## scripts/flight_pack_moments.gd), for checking by eye that the
## collectibles read: free ones gold balls, the starter a magenta ring,
## challenge ones orange-red diamonds. For each station the sharp bot flies
## it in the study, and the chase camera is saved about LEAD s before the
## line passes each moment (scripts/flight_moments.gd `at_s`). Rendered only
## when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_flight_moments.gd -- --no-title [--out=DIR] [--only=moments_cave]
## Writes DIR/<station>_<n>_<role>_<kind>.png (default /tmp/flight_moments) and quits.
const Course = preload("res://scripts/flight_course.gd")
const Moments = preload("res://scripts/flight_moments.gd")

const LEAD := 1.0
var out := "/tmp/flight_moments"
var only := ""

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600.0).timeout.connect(func() -> void: push_error("flight moments capture timed out"); quit(2))
	var study: Node3D = load("res://studies/flight_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = OS.get_temp_dir().path_join("flight-moments-capture")
	root.size = Vector2i(1280,720)
	root.add_child(study)
	current_scene = study
	while not study.flight_ready: await process_frame
	study._hud.visible = false
	for s: Dictionary in Course.pack("moments"):
		if only != "" and s.id != only: continue
		var rows := Moments.measure(s,study._space)
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at_s) < float(b.at_s))
		study.pilot = "sharp"
		study.start(s)
		for r: Dictionary in rows:
			# The bot runs a little behind the line's own time.
			var when := maxf(0.2,float(r.at_s)-LEAD)
			while study.run.t < when and not study.run.done: study.tick(1.0/60.0)
			for i in range(3): await process_frame
			await _save("%s_%d_%s_%s" % [s.id,int(r.i),r.role,r.kind if str(r.kind) != "" else "start"])
	quit(0)

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join(name+".png")
	root.get_texture().get_image().save_png(path)
	print("saved %s" % path)
