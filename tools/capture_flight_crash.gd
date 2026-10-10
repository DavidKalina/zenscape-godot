extends SceneTree
## Stills of a crash in the flight study (scripts/flight_crash.gd), for
## checking by eye that it reads: a bot flies a moments station with
## crashing on and, for its first crashes, the chase view is saved at
## STILLS s after the impact (flash, jolt and debris, tumble, the dim
## before the cut) and just after the cut. Rendered only when asked for
## (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_flight_crash.gd -- --no-title [--out=DIR] [--station=moments_hall] [--bot=sloppy] [--crashes=2]
## Writes DIR/<station>_crash<n>_<ms>.png (default /tmp/flight_crash) and quits.
const Course = preload("res://scripts/flight_course.gd")

const STILLS := [0.03,0.15,0.35,0.6]
const DT := 1.0/60.0
var out := "/tmp/flight_crash"
var station := "moments_hall"
var bot := "sloppy"
var crashes := 2

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--station="): station = arg.trim_prefix("--station=")
		if arg.begins_with("--bot="): bot = arg.trim_prefix("--bot=")
		if arg.begins_with("--crashes="): crashes = int(arg.trim_prefix("--crashes="))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(300.0).timeout.connect(func() -> void: push_error("flight crash capture timed out"); quit(2))
	var study: Node3D = load("res://studies/flight_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = OS.get_temp_dir().path_join("flight-crash-capture")
	root.size = Vector2i(1280,720)
	root.add_child(study)
	current_scene = study
	while not study.flight_ready: await process_frame
	study.crash_given = {"mode":"hard","restart":"checkpoint"}
	study.pilot = bot
	study.start(Course.station(station))
	var n := 0
	while n < crashes and not study.run.done:
		study.tick(DT)
		if study._crash_t < 0.0: continue
		n += 1
		# One frame before the impact's own is gone: save through the crash.
		for at: float in STILLS:
			while study._crash_t >= 0.0 and study._crash_t < at: study.tick(DT)
			for i in range(2): await process_frame
			await _save("%s_crash%d_%03d" % [station,n,roundi(at*1000.0)])
		while study._crash_t >= 0.0: study.tick(DT)
		for i in range(3): study.tick(DT)
		for i in range(2): await process_frame
		await _save("%s_crash%d_after" % [station,n])
	quit(0)

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join(name+".png")
	root.get_texture().get_image().save_png(path)
	print("saved %s" % path)
