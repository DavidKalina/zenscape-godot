extends SceneTree
## The pocket sail study, rendered (studies/pocket_sail_study.tscn): thrown
## by the hurl pad, the sail popped out at the top of the throw, coasting
## and turning back, with a gust front and the rising air in view. Rendered
## only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_pocket_sail.gd \
##     -- --no-title --out=/private/tmp/zs-pocket-sail
const DT := 1.0/60.0
var study: Node3D
var out := "/private/tmp/zs-pocket-sail"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	run.call_deferred()

func still(label: String) -> void:
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(out)
	var path := "%s/%s.png" % [out,label]
	root.get_texture().get_image().save_png(path)
	print("POCKET SAIL still %s" % path)

## Ticks of the study, drawn: `frames` of them at `want`, the jump `jump`.
func play(frames: int, want := Vector2.ZERO, jump := false) -> void:
	study.script_want = want
	study.script_jump = jump
	for i in range(frames):
		study.tick(DT)
		await process_frame

func run() -> void:
	study = load("res://studies/pocket_sail_study.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	study._hud.visible = false
	study.send_gust()
	study.fronts[-1].born = study.air_clock-(study.GUST_FROM-40.0)/study.GUST_SPEED
	study.place(Vector3(6.0,study.TOP,-7.0),Vector2(1.0,0.0))
	await play(30)
	await still("01-on-top")
	while study.last_throw.is_empty(): await play(1,Vector2(1.0,0.0))
	await play(10)
	await still("02-thrown")
	while study.motor.velocity.y > 0.0: await play(1)
	await play(1,Vector2.ZERO,true)
	await play(12)
	await still("03-sail-out")
	await play(50,Vector2(0.0,-1.0))
	await still("04-turning")
	await play(60,Vector2(-1.0,0.0))
	await still("05-coming-back")
	print("POCKET SAIL done")
	quit(0)
