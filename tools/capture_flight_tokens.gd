extends SceneTree
## Stills of the flight study's token-placement pack (studies/flight_study.tscn,
## scripts/flight_pack_tokens.gd), for checking by eye that a layout reads:
## each station seen from a fixed eye over it, its tokens (gold), guides
## (not drawn) and bonus tokens (blue) in place, and one from the chase
## camera as the sharp bot flies it. Rendered only when asked for (needs a
## window):
##   Godot --windowed --path . -s res://tools/capture_flight_tokens.gd -- --no-title [--out=DIR]
## Writes DIR/<station>_<view>.png (default /tmp/flight_tokens) and quits.
const Course = preload("res://scripts/flight_course.gd")

## Per station: [eye, look] in station metres, and seconds of the sharp
## bot's flight before the chase-camera still (or -1 for none).
const SHOTS := {
	"tokens_hall_hidden":[Vector3(-30.0,26.0,-20.0),Vector3(12.0,0.0,-60.0),3.3],
	"tokens_hall_detours":[Vector3(45.0,20.0,-95.0),Vector3(20.0,-5.0,-128.0),10.2],
	"tokens_hall_outback":[Vector3(-28.0,22.0,-45.0),Vector3(-2.0,0.0,-70.0),4.9],
	"tokens_swoop_skim":[Vector3(10.0,40.0,30.0),Vector3(8.0,-6.0,-65.0),2.4],
}
var out := "/tmp/flight_tokens"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(300.0).timeout.connect(func() -> void: push_error("flight tokens capture timed out"); quit(2))
	var study: Node3D = load("res://studies/flight_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = OS.get_temp_dir().path_join("flight-tokens-capture")
	root.size = Vector2i(1440,900)
	root.add_child(study)
	current_scene = study
	while not study.flight_ready: await process_frame
	study._hud.visible = false
	for id: String in SHOTS:
		var shot: Array = SHOTS[id]
		var s := Course.station(id)
		var at := Course.origin(s)
		study.pilot = "sharp"
		study.start(s)
		var eye: Vector3 = at+(shot[0] as Vector3)
		study.camera.global_transform = Transform3D(Basis.looking_at(at+(shot[1] as Vector3)-eye,Vector3.UP),eye)
		study.camera.fov = 60.0
		for i in range(8): await process_frame
		await _save("%s_over" % id)
		if float(shot[2]) > 0.0:
			while study.run.t < float(shot[2]) and not study.run.done: study.tick(1.0/60.0)
			for i in range(4): await process_frame
			await _save("%s_chase" % id)
	quit(0)

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out.path_join(name+".png")
	root.get_texture().get_image().save_png(path)
	print("saved %s" % path)
