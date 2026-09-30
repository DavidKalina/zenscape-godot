extends SceneTree
## Films ponds through the year (scripts/pond_seasons.gd, docs/scenic/life.md
## "Ponds through the year") on a staged Genesis plain: a hill whose spring
## runs a rill down to a pool, with birches along it, and a dug pond ringed by
## broadleaves. The land is written straight into the data; nothing is played.
##   --shot=a  time lapse: the pond ages from clear, to a few pads, to a lily
##             edge, then flowers (life clock LAPSE times fast, summer held).
##   --shot=b  autumn: leaves fall on the rill, run down it and gather at the
##             pool's edge (real time, gold held at 0.85).
## Rendered (needs a window):
##   Godot --windowed --resolution 1280x720 --path . --write-movie /tmp/zs-film/09-pond-seasons-a.avi \
##     -s res://tools/film_pond_seasons.gd -- --no-title --modeless --shot=a
## Headless it prints the same numbers, for a dry run.

var scene: Node3D
var editor: NativeChunkEditor
var life: Node3D
var shot := "a"
const PEAK := Vector2(-6.5,-3.0)
const POND := Vector2(3.0,2.5)
const MOOD := "Alpine daylight"
## Life clock speed while the pond ages (shot a).
const LAPSE := 60.0

func _initialize() -> void: run.call_deferred()

func seconds(value: float) -> void:
	for i in range(int(value*60.0)):
		await process_frame
		scene._atmosphere.set_fog(0.04)
		scene._atmosphere.set_haze(0.06)

func height(p: Vector2) -> float:
	var h: Variant = editor.data.ground_height(p)
	return float(h) if h != null else 0.0

## Glide the orbit camera to plate point `at` over `secs` seconds.
func frame_on(at: Vector2, distance: float, polar: float, yaw: float, secs: float) -> void:
	var from := {"target":scene.target,"distance":scene.distance,"polar":scene.polar,"yaw":scene.yaw}
	var goal := editor.terrain.to_global(Vector3(at.x,height(at),at.y))
	var count := maxi(1,int(secs*60.0))
	for i in range(count):
		var t := smoothstep(0.0,1.0,float(i+1)/count)
		scene.target = (from.target as Vector3).lerp(goal,t)
		scene.distance = lerpf(from.distance,distance,t)
		scene.polar = lerpf(from.polar,polar,t)
		scene.yaw = lerpf(from.yaw,yaw,t)
		await seconds(1.0/60.0)

func report(label: String) -> void:
	var s: Node3D = life.seasons
	var shown := 0
	for pad: Dictionary in s.pads:
		if float(pad.scale) > 0.5: shown += 1
	var ages := []
	for record: Dictionary in s.bodies: ages.append([record.cells.size(),snappedf(record.age,1),record.live])
	print("FILM %s bodies=%s pads=%d shown=%d flowers=%d trees=%d leaves=%d landed=%d" % [label,ages,s.pads.size(),shown,s._flowers.multimesh.visible_instance_count,s._trees.size(),s.leaf_count,s.leaves_landed])

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): shot = arg.trim_prefix("--shot=")
	create_timer(300).timeout.connect(func() -> void: push_error("pond film timed out"); quit(2))
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-ponds-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size = Vector2i(1280,720)
	editor = scene._chunk_editor
	life = scene.land_life
	editor.set_process_input(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene.world_clock.running = false
	scene.apply_scene_mood(MOOD)
	scene._celestial.set_phase(0.4)
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	var weather: RefCounted = scene._precipitation.surface_weather
	scene.world_clock.season_override = 0.35 if shot == "a" else 0.6
	for i in range(120):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	# The land: a hill for the spring, a dug pond, trees by both.
	var data := editor.data
	data.begin_stroke()
	for _pass in range(8): data.brush(PEAK,4.5,0.45,"raise",0.0)
	for _pass in range(6): data.brush(POND,3.6,0.3,"lower",0.0)
	for i in range(9):
		var p := POND+Vector2.from_angle(0.6+float(i)*0.5)*4.2
		if data.place("broadleaf",p,float(i),0.9) >= 0: data.objects.back()["source"] = "emerged"
	data.end_stroke()
	await editor.refresh(self)
	print("FILM peak %.2f pond floor %.2f kind %s" % [height(PEAK),height(POND),editor.flow.drop(PEAK+Vector2(1.2,0.6),5.0)])
	# Birches along the rill the spring wore.
	var course: Dictionary = preload("res://scripts/water_flow.gd").descent(data,PEAK+Vector2(1.2,0.6))
	var points: PackedVector3Array = course.points
	data.begin_stroke()
	for k in range(2,points.size(),3):
		var side := 1.6 if k%2 == 0 else -1.6
		var q := Vector2(points[k].x,points[k].z)+Vector2(0,side)
		if data.place("birch",q,float(k),0.8) >= 0: data.objects.back()["source"] = "emerged"
	data.end_stroke()
	await editor.refresh(self)
	scene._overview()
	if shot == "a":
		# Fill the dug pond from the flow so it is live water.
		editor.flow.drop(POND,6.0)
		weather.autumn = 0.0
		weather.target_autumn = 0.0
		await seconds(6.0)
		await frame_on(POND,9.0,0.95,0.6,3.0)
		life.pace = LAPSE
		for beat in range(12):
			await seconds(2.5)
			report("a %d" % beat)
		life.pace = 1.0
		await seconds(3.0)
	else:
		weather.autumn = 0.85
		weather.target_autumn = 0.85
		# The rill fills and runs before the camera arrives.
		await seconds(10.0)
		var foot := Vector2(points[-1].x,points[-1].z)
		var middle := Vector2(points[points.size()/2].x,points[points.size()/2].z)
		await frame_on(middle,8.0,0.9,0.4,3.0)
		for beat in range(4):
			await seconds(3.0)
			report("b rill %d" % beat)
		await frame_on(foot,6.5,0.95,0.4,3.0)
		for beat in range(5):
			await seconds(3.0)
			report("b pool %d" % beat)
	print("FILM done")
	quit(0)
