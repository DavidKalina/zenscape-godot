extends SceneTree
## The dragon asleep on its roost, captured (docs/design/dragon-roost/
## round1.md): the game (studies/zenscape.tscn) straight in with
## --dragon-roost, the sky held, every motif isle stood at once, then fixed
## views saved one after another from one window: from the aqueduct isle
## looking out at the mountain (the landmark), the whole mountain, the head
## and the coil close. Flags after the out dir go to the game (--hour=23 for
## night).
##   Godot --windowed --path . --resolution 1440x900 -s res://tools/capture_dragon_roost.gd \
##     -- --out=captures/dragon_roost/day [--shots=isle,mountain,close] [--wait=3] [--hour=23]
## Saves <out>_<shot>.png for each shot.
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Roost = preload("res://scripts/kit_isle/motif_dragon_roost.gd")
const GAME := "res://studies/zenscape.tscn"
const SHOTS := ["isle","mountain","close"]

var game: Node3D
var camera: Camera3D

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var out := "captures/dragon_roost/shot"
	var wait := 3.0
	var shots: Array = SHOTS.duplicate()
	var passed := PackedStringArray(["--no-title","--day-length=0","--still-weather","--dragon-roost","--motifs-now"])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.get_slice("=",1)
		elif arg.begins_with("--wait="): wait = float(arg.get_slice("=",1))
		elif arg.begins_with("--shots="): shots = Array(arg.get_slice("=",1).split(","))
		elif arg not in passed: passed.append(arg)
	create_timer(600).timeout.connect(func() -> void: print("capture_dragon_roost: timed out"); quit(2))
	LaunchArgs.set_override(passed)
	change_scene_to_file(GAME)
	while current_scene == null or current_scene.scene_file_path != GAME: await process_frame
	game = current_scene
	while not game.isle_up: await process_frame
	var sky: Variant = game.get("sky")
	if sky != null and sky.has_method("flush"): sky.flush()
	await create_timer(4.0).timeout
	game.scripted = true
	camera = game.camera
	camera.far = maxf(camera.far,4000.0)
	for child in game.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer in [5,6]: (child as CanvasLayer).visible = false
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	for shot: String in shots:
		var aim := _aim(shot)
		if aim.is_empty():
			print("capture_dragon_roost: no %s" % shot)
			continue
		var until := Time.get_ticks_msec()+int(wait*1000.0)
		while Time.get_ticks_msec() < until:
			camera.look_at_from_position(aim.eye,aim.at)
			if aim.has("fov"): camera.fov = float(aim.fov)
			await process_frame
		# The snout's shot well into an out-breath, the haze showing.
		if shot == "snout":
			var roost: RefCounted = (game.get("roost_dragon") as Node3D).get("roost")
			while roost.breathing_out(): await process_frame
			while not roost.breathing_out(): await process_frame
			await create_timer(1.6).timeout
		await RenderingServer.frame_post_draw
		var path := "%s_%s.png" % [out,shot]
		root.get_texture().get_image().save_png(path)
		print("capture_dragon_roost: saved %s eye=%s at=%s" % [path,aim.eye,aim.at])
	print("capture_dragon_roost: done")
	quit(0)
	await create_timer(3.0).timeout
	OS.kill(OS.get_process_id())

## Where the eye stands and what it looks at for `shot`.
func _aim(shot: String) -> Dictionary:
	var dragon: Node3D = game.get("roost_dragon")
	if dragon == null: return {}
	var line: PackedVector3Array = dragon.roost.line_world
	var axis := Vector3(Roost.AXIS.x+Roost.AT.x,Roost.shelf_y()+Roost.AT.y,Roost.AXIS.y+Roost.AT.z)
	var head := line[int(line.size()*0.08)]
	var toward := Vector3(85.0,0.0,-20.0)-axis
	toward.y = 0.0
	toward = toward.normalized()
	var across := toward.cross(Vector3.UP)
	match shot:
		"isle":
			# Where the pilot stands on the aqueduct isle at the start (by
			# the plane), at eye height, the mountain 800 m off.
			var feet: Vector3 = game.motor.feet if game.get("motor") != null else Vector3(118.0,31.0,12.0)
			var eye := feet+Vector3(0.0,1.7,0.0)
			return {"eye":eye,"at":axis+Vector3(0.0,-20.0,0.0),"fov":55.0}
		"mountain":
			return {"eye":axis+toward*230.0+across*90.0+Vector3(0.0,-20.0,0.0),"at":axis+Vector3(0.0,-22.0,0.0),"fov":60.0}
		"close":
			var out := Vector3(head.x-axis.x,0.0,head.z-axis.z).normalized()
			return {"eye":head+out*38.0+across*8.0+Vector3(0.0,12.0,0.0),"at":head+Vector3(0.0,-2.0,0.0)-out*6.0,"fov":55.0}
		"snout":
			# Right at the nostrils (judging the breath's haze).
			var tip := line[0]
			var out := Vector3(tip.x-axis.x,0.0,tip.z-axis.z).normalized()
			return {"eye":tip+out*14.0+Vector3(0.0,5.0,0.0)+across*4.0,"at":tip,"fov":55.0}
		"side":
			# Out from the chest, level with it (judging the folded wings).
			var chest := line[int(line.size()*0.44)]
			var out := Vector3(chest.x-axis.x,0.0,chest.z-axis.z).normalized()
			return {"eye":chest+out*55.0+Vector3(0.0,8.0,0.0),"at":chest,"fov":55.0}
		"top":
			# Straight down on the shoulder (for judging the coil's lay).
			return {"eye":axis+Vector3(0.5,95.0,0.0),"at":axis,"fov":50.0}
		"night":
			return {"eye":axis+toward*150.0+across*60.0+Vector3(0.0,-5.0,0.0),"at":axis+Vector3(0.0,-8.0,0.0),"fov":60.0}
	return {}
