extends SceneTree
## Stills of the flight study's lines pack (scripts/flight_pack_lines.gd):
## each station from above with its three token lines (the flown line full
## size, the others small and faint), and from the chase camera behind the
## perfect bot at a few moments along a line. Needs a renderer (opens a
## window).
##   godot --path . --script tools/capture_flight_lines.gd -- --no-title [OUT_DIR]
const Course = preload("res://scripts/flight_course.gd")
const DT := 1.0/60.0
## [station id (with its line), seconds into the run] for the chase stills.
const MOMENTS := [["lines_bend",5.6],["lines_bend",7.8],["lines_bend@yellow",3.2],["lines_bend@red",6.6],
	["lines_stitch",2.0],["lines_stitch@yellow",6.6],["lines_stitch@red",3.4],
	["lines_crest",3.4],["lines_crest",5.6],["lines_crest@red",5.4],["lines_crest@yellow",5.0]]
var study: Node3D
var out := "/tmp/flight_lines"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args(): if not a.begins_with("--"): out = a
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out,name])
	print("CAPTURE ",name)

func run() -> void:
	study = load("res://studies/flight_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = "user://flight_runs_capture"
	root.add_child(study)
	current_scene = study
	while not study.flight_ready: await process_frame
	study._hud.visible = false
	study.pilot = "perfect"
	for s: Dictionary in Course.pack("lines"):
		study.start(s)
		var box := AABB(Course.origin(s),Vector3.ZERO)
		for solid: Dictionary in Course.solids(s): box = box.expand(solid.middle)
		var mid := box.get_center()
		var eye := mid+Vector3(-box.size.x*0.55-40.0,box.size.length()*0.55,box.size.z*0.2+30.0)
		study.camera.global_transform = Transform3D(Basis.looking_at(mid-eye,Vector3.UP),eye)
		await shot("%s_above" % s.id)
	for m: Array in MOMENTS:
		study.start(Course.station(str(m[0])))
		var frames := int(float(m[1])/DT)
		for i in range(frames): study.tick(DT)
		await shot("%s_%.1f" % [str(m[0]).replace("@","_"),float(m[1])])
	quit(0)
