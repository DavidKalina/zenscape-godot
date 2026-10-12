extends SceneTree
## The walker's chase view on the aqueduct isle (studies/aqueduct_isle.tscn),
## rendered: set down at a few fixed spots, left standing until the camera
## has settled behind him, a still of each (saved at 1440 x 900 whatever
## the window's pixel ratio), for before/after comparisons of how much of
## him reads under the hat. Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1440x900 -s res://tools/capture_chase.gd \
##     -- --no-title --out=captures/look-round4/chase/after
const SPOTS := {
	"ledge": [Vector3(57.3,38.7,16.1),13.0],
	"ramp": [Vector3(49.6,36.6,-13.6),230.0],
	"turf": [Vector3(92.0,28.84,4.0),90.0],
}
var out := "captures/look-round4/chase"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	run.call_deferred()

func frames(n: int) -> void:
	for i in range(n): await process_frame

func run() -> void:
	var study: Node3D = load("res://studies/aqueduct_isle.tscn").instantiate()
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	while not study.get("flora_ready"): await process_frame
	Engine.max_fps = 60
	await frames(30)
	DirAccess.make_dir_recursive_absolute(out)
	for key: String in SPOTS:
		var spot: Array = SPOTS[key]
		var turn := deg_to_rad(float(spot[1]))
		study.place(spot[0],Vector2(sin(turn),-cos(turn)))
		await frames(150)
		var image := root.get_texture().get_image()
		image.resize(1440,900,Image.INTERPOLATE_LANCZOS)
		var path := "%s/%s.png" % [out,key]
		image.save_png(path)
		print("CHASE still %s at %s" % [path,study.motor.feet])
	quit(0)
