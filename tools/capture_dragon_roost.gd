extends SceneTree
## The dragon asleep on its roost, captured (docs/design/dragon-roost/
## round2.md): the game (studies/zenscape.tscn) straight in with
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
const SHOTS := ["isle","isle_zoom","mountain","nest","summit"]

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
	var span: float = Roost.SPAN
	var t2 := Roost.own(Roost.TOWER_C)
	var axis := Vector3(t2.x+Roost.AT.x,Roost.TOP+Roost.LEDGE_H*span+Roost.AT.y,t2.y+Roost.AT.z)
	var l2 := Roost.own(Roost.LEDGE_C)
	var ledge := Vector3(l2.x+Roost.AT.x,axis.y,l2.y+Roost.AT.z)
	var toward := Vector3(Roost.V.x,0.0,Roost.V.y)
	var across := Vector3(Roost.U.x,0.0,Roost.U.y)
	var head := line[int(line.size()*0.08)]
	match shot:
		"isle":
			# Where the pilot stands on the aqueduct isle at the start (by
			# the plane), at eye height, the mountain 800 m off.
			var feet: Vector3 = game.motor.feet if game.get("motor") != null else Vector3(118.0,31.0,12.0)
			var eye := feet+Vector3(0.0,1.7,0.0)
			return {"eye":eye,"at":axis+Vector3(0.0,-10.0,0.0),"fov":55.0}
		"isle_zoom":
			# The same line of sight, narrowed (what the eye picks out).
			var feet: Vector3 = game.motor.feet if game.get("motor") != null else Vector3(118.0,31.0,12.0)
			var eye := feet+Vector3(0.0,1.7,0.0)
			return {"eye":eye,"at":axis+Vector3(0.0,-10.0,0.0),"fov":14.0}
		"mountain":
			return {"eye":axis+toward*330.0*span+across*40.0*span+Vector3(0.0,-25.0*span,0.0),"at":axis+Vector3(0.0,-8.0*span,0.0),"fov":55.0}
		"nest":
			return {"eye":ledge+toward*55.0*span+across*45.0*span+Vector3(0.0,32.0*span,0.0),"at":ledge+Vector3(0.0,4.0,0.0),"fov":55.0}
		"summit":
			return {"eye":head+toward*55.0*span-across*35.0*span+Vector3(0.0,18.0*span,0.0),"at":axis+Vector3(0.0,22.0*span,0.0),"fov":55.0}
		"low":
			# Low across the nest, at the ledge's lip (where a gap under the
			# body would show).
			return {"eye":ledge+toward*12.0*span+across*40.0*span+Vector3(0.0,4.0*span,0.0),"at":ledge-across*6.0*span+Vector3(0.0,3.0*span,0.0),"fov":60.0}
		"low_back":
			return {"eye":ledge-toward*38.0*span+across*30.0*span+Vector3(0.0,5.0*span,0.0),"at":ledge-across*8.0*span+Vector3(0.0,5.0*span,0.0),"fov":60.0}
		"back":
			return {"eye":axis-toward*110.0*span+across*60.0*span+Vector3(0.0,30.0*span,0.0),"at":axis+Vector3(0.0,12.0*span,0.0),"fov":55.0}
		"snout":
			var tip := line[0]
			return {"eye":tip+toward*16.0+across*6.0+Vector3(0.0,6.0,0.0),"at":tip,"fov":55.0}
		"top":
			return {"eye":axis+Vector3(0.5,150.0*span,0.0),"at":axis,"fov":55.0}
		"night":
			return {"eye":axis+toward*200.0*span+across*40.0*span+Vector3(0.0,-5.0,0.0),"at":axis+Vector3(0.0,4.0,0.0),"fov":60.0}
	return {}
