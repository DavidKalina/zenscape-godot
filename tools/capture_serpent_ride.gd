extends SceneTree
## Stills of the serpent ride (studies/serpent_ride.tscn), the pilot driven
## by scripted input: from his camera running along its back through the
## slalom (run), surfing down it in the dive (dive), on the tower as it
## comes (tower), and a wide shot from off its side with him small on its
## back (wide). Needs a renderer (opens a window). The ride's flags
## (--girth=, --ride-roll=) go after the out dir.
##   godot --path . --script tools/capture_serpent_ride.gd -- --no-title [OUT_DIR] [--girth=2]
const DT := 1.0/60.0
var study: Node3D
var out := "/tmp/sr"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args(): if not a.begins_with("--"): out = a
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func tick(want: Vector2, jump := false, crouch := false) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	study.tick(DT)

func shot(name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out,name])
	print("CAPTURE ",name)

## The serpent's head at route arc `at`, him on its back at arc `a`.
func set_on(at: float, a: float) -> void:
	var serpent: Node3D = study.serpent
	serpent.place(fposmod(at,serpent.route_length))
	study.back.reset()
	study.set_on_back(a)

func ahead() -> Vector2:
	return study.back.ahead(study.anchor.x)

func run() -> void:
	study = load("res://studies/serpent_ride.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	var marks: Dictionary = study.serpent.marks()
	# Running toward its head through the slalom.
	set_on(float(marks["pillars"])+150.0,60.0)
	for i in range(150): tick(ahead())
	await shot("run")
	# Surfing down its back in the dive.
	set_on(float(marks["dive"])+95.0,60.0)
	for i in range(90): tick(Vector2.ZERO,false,true)
	await shot("dive")
	# On the tower, it coming.
	study.go_to(4)
	for i in range(170): tick(Vector2.ZERO)
	await shot("tower")
	# Wide: from off its side and a little over it, him small mid-back.
	set_on(float(marks["north"])-40.0,40.0)
	for i in range(60): tick(ahead()*0.5)
	var feet: Vector3 = study.motor.feet
	var x: Vector3 = study.back.frame(study.anchor.x).basis.x.normalized()
	var z: Vector3 = study.back.frame(study.anchor.x).basis.z.normalized()
	study.camera.global_position = feet+x*34.0+z*6.0+Vector3.UP*10.0
	study.camera.look_at(feet+z*4.0,Vector3.UP)
	await shot("wide")
	quit(0)
