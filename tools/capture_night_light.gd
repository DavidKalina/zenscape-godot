extends SceneTree
## The game's night lighting, captured (docs/design/night-light/round1.md):
## the game (studies/zenscape.tscn) straight in (--no-title), the sky held
## (--still-sky) at the hour asked, then a run of fixed views saved one
## after another from one window: the isle wide, the ruins up close on foot
## (the stone circle, the aqueduct's head, the plane parked), a far airship,
## the dragon (--dragon is passed) and the rune serpent. Moving things are
## followed each frame. Flags after the out dir go to the game as launch
## flags (kit_weather's --hour=, --weather=, --season=...).
##   Godot --windowed --path . --resolution 1440x900 -s res://tools/capture_night_light.gd \
##     -- --out=/private/tmp/zs-night/after [--shots=wide,circle] [--wait=3] --hour=23 --weather=clear --season=autumn
## Saves <out>_<shot>.png for each shot.
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const GAME := "res://studies/zenscape.tscn"
const SHOTS := ["wide","circle","aqueduct","arch","plane","airship","dragon","serpent"]

var game: Node3D
var camera: Camera3D

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var out := "/private/tmp/zs-night/shot"
	var wait := 3.0
	var shots: Array = SHOTS.duplicate()
	var passed := PackedStringArray(["--no-title","--day-length=0","--still-weather","--dragon","--dragon-skip=40"])
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.get_slice("=",1)
		elif arg.begins_with("--wait="): wait = float(arg.get_slice("=",1))
		elif arg.begins_with("--shots="): shots = Array(arg.get_slice("=",1).split(","))
		elif arg not in passed: passed.append(arg)
	create_timer(600).timeout.connect(func() -> void: print("capture_night_light: timed out"); quit(2))
	LaunchArgs.set_override(passed)
	change_scene_to_file(GAME)
	while current_scene == null or current_scene.scene_file_path != GAME: await process_frame
	game = current_scene
	while not game.isle_up: await process_frame
	await create_timer(4.0).timeout
	game.scripted = true
	camera = game.camera
	camera.far = maxf(camera.far,4000.0)
	for child in game.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer in [5,6]: (child as CanvasLayer).visible = false
	var circle := Art.circle_transform().origin
	print("capture_night_light: circle=%s parked=%s summit=%s isle=%s" % [circle,game.parked_at,game.isle_summit(),game.isle_circle()])
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	for shot: String in shots:
		var aim := _aim(shot)
		if aim.is_empty():
			print("capture_night_light: no %s" % shot)
			continue
		var patience := Time.get_ticks_msec()+60000
		while aim.has("waiting") and Time.get_ticks_msec() < patience:
			await process_frame
			aim = _aim(shot)
		var until := Time.get_ticks_msec()+int(wait*1000.0)
		while Time.get_ticks_msec() < until:
			aim = _aim(shot)
			camera.look_at_from_position(aim.eye,aim.at)
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s_%s.png" % [out,shot]
		root.get_texture().get_image().save_png(path)
		print("capture_night_light: saved %s eye=%s at=%s" % [path,aim.eye,aim.at])
	print("capture_night_light: done")
	# The game's quit can hang on its threads after a capture (seen with
	# capture_front_door too): end the process outright.
	quit(0)
	await create_timer(3.0).timeout
	OS.kill(OS.get_process_id())

## Where the eye stands and what it looks at for `shot`; empty if there is
## nothing to see.
func _aim(shot: String) -> Dictionary:
	var circle := Art.circle_transform().origin
	match shot:
		"wide":
			var c: Vector3 = game.isle_circle()
			var mid := Vector3(c.x,game.isle_top()-4.0,c.y)
			return {"eye":mid+Vector3(0.9,0.42,0.75).normalized()*c.z*2.3,"at":mid}
		"circle":
			# On foot, a few strides out from the stone circle, eye height.
			var foot := circle+Vector3(-3.0,0.0,6.5)
			foot.y = _ground(foot)+1.7
			return {"eye":foot,"at":circle+Vector3(6.0,1.5,-6.0)}
		"aqueduct":
			var foot := Vector3(113.0,0.0,-6.0)
			foot.y = _ground(foot)+1.7
			return {"eye":foot,"at":Vector3(100.0,foot.y+3.0,-24.0)}
		"arch":
			var foot := Vector3(109.0,0.0,-48.0)
			foot.y = _ground(foot)+1.7
			return {"eye":foot,"at":Vector3(100.0,foot.y+2.5,-62.5)}
		"plane":
			var p: Vector3 = game.parked_at
			var side := Vector3(sin(game.parked_heading+0.9),0.0,cos(game.parked_heading+0.9))
			var foot := p+side*9.0
			foot.y = _ground(foot)+1.7
			return {"eye":foot,"at":p+Vector3.UP*1.2}
		"airship":
			var sky: Node = game.get("sky")
			if sky == null or sky.get("airships") == null or (sky.airships as Array).is_empty(): return {}
			var ship: Node3D = sky.airships[0].ship
			var at: Vector3 = (ship.get("_ship") as Node3D).global_position
			var from := (Vector3(circle.x,at.y,circle.z)-at)
			from.y = 0.0
			from = from.normalized() if from.length() > 1.0 else Vector3.FORWARD
			return {"eye":at+from*520.0+Vector3.UP*30.0,"at":at}
		"dragon":
			var dragon: Node3D = game.get("dragon")
			if dragon == null: return {}
			var at: Vector3 = dragon.get("pos")
			if at.y < -150.0 or str(dragon.get("state")) == "waiting": return {"eye":Vector3(0,40,60),"at":Vector3(0,40,0),"waiting":true}
			var yaw: float = dragon.get("yaw")
			var side := Vector3(cos(yaw),0.0,-sin(yaw))
			return {"eye":at+side*48.0+Vector3.UP*14.0,"at":at}
		"serpent":
			var sky: Node = game.get("sky")
			var serpent: Node3D = sky.get("serpent") if sky != null else null
			if serpent == null: return {}
			var head: Vector3 = serpent.get("_head_pos")
			var fwd: Vector3 = serpent.get("_head_dir")
			var side := fwd.cross(Vector3.UP).normalized()
			return {"eye":head+side*22.0+fwd*8.0+Vector3.UP*6.0,"at":head-fwd*12.0}
	return {}

## The middle of a node's visible bounds (the dragon's body), else its origin.
func _middle(node: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for child in node.find_children("*","VisualInstance3D",true,false):
		var v := child as VisualInstance3D
		if not v.is_visible_in_tree(): continue
		var b := v.global_transform*v.get_aabb()
		if b.size.length() > 300.0: continue
		box = b if first else box.merge(b)
		first = false
	return box.get_center() if not first else node.global_position

func _ground(at: Vector3) -> float:
	var space := game.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(at+Vector3.UP*80.0,at+Vector3.DOWN*80.0)
	var hit := space.intersect_ray(ray)
	return (hit.position as Vector3).y if not hit.is_empty() else at.y
