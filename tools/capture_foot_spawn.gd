extends SceneTree
## A still from where `--foot-at=` starts him (docs/design/foot-interactables.md):
## the scene opened as the game opens it, the camera left as it is, a few
## seconds in. Prints where he stands and faces. Rendered for the still;
## headless it only prints.
##   godot --path . --script tools/capture_foot_spawn.gd -- --no-title --foot-at=ropes [--scene=res://studies/zenscape.tscn] [OUT_DIR]
var out := "/tmp/foot_spawn"
var scene := "res://studies/zenscape.tscn"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="): scene = a.get_slice("=",1)
		elif not a.begins_with("--"): out = a
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

func run() -> void:
	var study: Node3D = load(scene).instantiate()
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	for i in range(150): await process_frame
	var m = study.motor
	print("SPAWN feet=%s facing=%s forward=%s camera=%s looking=%s" % [m.feet,m.facing,m.forward(m.facing),study.camera.global_position,-study.camera.global_basis.z])
	var pieces = study.get("foot_pieces")
	if pieces != null:
		for r in pieces.ropes: print("ROPE anchor=%s end=%s dist=%.1f" % [r.anchor,r.hands,r.anchor.distance_to(m.feet)])
	var tag := "spawn"
	for a in OS.get_cmdline_user_args(): if a.begins_with("--foot-at="): tag = a.get_slice("=",1)
	if DisplayServer.get_name() != "headless":
		root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out,tag])
		print("CAPTURE ",out,"/",tag,".png")
		if pieces != null and not pieces.ropes.is_empty():
			# From off to the side and back, at about eye height over him.
			var r: Node3D = pieces.ropes[0]
			study.set_process(false)
			study.camera.look_at_from_position(r.anchor+Vector3(16.0,-2.5,14.0),r.anchor+Vector3(0.0,-3.0,-4.0))
			for i in range(4): await process_frame
			root.get_viewport().get_texture().get_image().save_png("%s/%s_far.png" % [out,tag])
			print("CAPTURE ",out,"/",tag,"_far.png")
	quit()
