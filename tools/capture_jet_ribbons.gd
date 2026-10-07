extends SceneTree
## The sky's currents as ribbons (scripts/sky_currents.gd, shaders/
## sky_jet_ribbon.gdshader), rendered: the wanderer steps off into the glide
## and the eye is set at a row of spots along the islands' low jet stream
## and by a thermal, the clock held at noon, at golden hour and at night:
##   ride: in the jet's core, looking downstream (the chase view);
##   ride_side: in the core, looking across the stream;
##   near: 90 m off the jet, a stretch of it going by;
##   distant: 350 m off and above, the jet's sweep round the islands;
##   thermal: 70 m from a thermal beside the plate, looking at its column.
## Run again with `--old-currents` for the old streaks, to the same --out
## (stills are tagged "old"). Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_jet_ribbons.gd \
##     -- --no-title --out=docs/captures/jet-ribbons/try1 [--old-currents] [--only=ride,near]
## Each still also prints the frame's time with the currents drawn and
## hidden (vsync off), a rough measure of their cost.
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-jet-ribbons"
var only: Array = []
var hours := {"noon": WorldClock.hour_for_phase(0.5), "golden": WorldClock.hour_for_phase(0.72), "night": WorldClock.hour_for_phase(0.02)}
var tag := "new"
var _currents: Node3D
var _parent: Node3D

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label+".png")
	image.save_png(path)
	print("JETS still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
		elif argument == "--old-currents": tag = "old"
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("jet ribbons capture timed out"); quit(2))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = out.path_join("places-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	scene.world_clock.running = false
	eye = scene.wanderer
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	await frames(5)
	eye._launch(6.0,false)
	eye.set_process(false)
	eye._layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var islands: Node3D = eye.islands
	for i in range(900):
		if not islands.lands.has(null): break
		await frames(1)
	var currents: Node3D = islands.currents
	var parent: Node3D = scene.camera.get_parent()
	print("JETS islands %s currents %s camera parent %s, %d currents, %d strokes" % [islands.global_transform.origin,currents.global_transform.origin,parent.global_transform.origin,currents.currents.size(),currents.wisp_count()])
	_currents = currents
	_parent = parent
	var shots := _shots(currents)
	for hour_name: String in ["noon","golden","night"]:
		for shot: Dictionary in shots:
			if not only.is_empty() and shot.label not in only: continue
			if hour_name != "noon" and shot.label not in ["ride","distant"]: continue
			await _hold(shot,hours[hour_name],90 if shot == shots[0] else 40)
			var ms := await _frame_ms(30)
			currents.visible = false
			var bare := await _frame_ms(30)
			currents.visible = true
			print("JETS %s-%s frame %.2f ms, %.2f ms without the currents" % [shot.label,hour_name,ms,bare])
			await _hold(shot,hours[hour_name],2)
			await still("%s-%s-%s" % [shot.label,hour_name,tag])
	print("JETS done")
	quit(0)

## The spots, from the low jet's path and the plate's first thermal, in the
## currents' own frame (the islands shift the world as the eye moves; each
## frame turns them into the camera's, `_view`).
func _shots(currents: Node3D) -> Array:
	var jet: Dictionary = currents.currents[0]
	var points: PackedVector3Array = jet.points
	# A stretch of the jet a little way round from the plate.
	var i0 := 20
	var here: Vector3 = points[i0]
	var ahead: Vector3 = points[(i0+6)%points.size()]
	var way := (ahead-here).normalized()
	var side := way.cross(Vector3.UP).normalized()
	var mid: Vector3 = points[(i0+3)%points.size()]
	var shots := []
	shots.append({"label":"ride","eye":here,"look":here+way*60.0+Vector3.DOWN*2.0,"chase":true})
	shots.append({"label":"ride_side","eye":here,"look":here+side*40.0+way*25.0})
	shots.append({"label":"near","eye":mid+side*90.0+Vector3.UP*10.0,"look":mid})
	shots.append({"label":"distant","eye":mid+side*330.0+Vector3.UP*120.0,"look":mid+way*60.0})
	for c: Dictionary in currents.currents:
		if c.kind != "thermal": continue
		var base: Vector3 = c.points[0]
		var top: Vector3 = c.points[c.points.size()-1]
		var middle := (base+top)*0.5
		var out_ := Vector3(middle.x,0.0,middle.z).normalized()
		shots.append({"label":"thermal","eye":middle+out_*70.0+Vector3.UP*5.0,"look":middle+Vector3.UP*10.0})
		break
	return shots

func _view(local: Vector3) -> Vector3:
	return _parent.to_local(_currents.to_global(local))

func _frame_ms(count: int) -> float:
	await RenderingServer.frame_post_draw
	var from := Time.get_ticks_usec()
	for i in range(count): await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec()-from)/count/1000.0

## Holds the eye at a shot for `count` frames at `hour`, advancing the sky,
## the haze and the islands as the glide would.
func _hold(shot: Dictionary, hour: float, count: int) -> void:
	var at := _view(shot.eye)
	var look := _view(shot.look)
	var way := (look-at).normalized()
	var glide: RefCounted = eye.glide
	glide.position = at
	glide.heading = atan2(-way.x,-way.z)
	glide.pitch = asin(clampf(way.y,-1.0,1.0))
	glide.bank = 0.0
	glide.speed = 8.0
	glide.velocity = glide.forward()*8.0
	var chase: bool = shot.get("chase",false)
	eye.glider.visible = chase
	if chase:
		eye.chase.first_person = false
		eye.chase.reset(glide,at-way*6.0+Vector3.UP*2.0)
	for i in range(count):
		# The islands may have shifted the world under the eye.
		at = _view(shot.eye)
		look = _view(shot.look)
		glide.position = at
		scene.world_clock.running = false
		scene.world_clock.set_time(scene.world_clock.day,hour)
		var delta := 1.0/60.0
		var view_eye := at
		var view_look := look
		if chase:
			eye.chase.step(delta,glide,0.0)
			eye.glider.update(delta,glide,0.0,eye._fly_ground,false)
			view_eye = eye.chase.eye
			view_look = eye.chase.look
		eye.sky.advance(delta,view_eye,eye.islands.in_cloud(view_eye,scene._motion_time))
		eye.islands.advance(delta,at,glide.heading,0.0)
		var o := view_eye-view_look
		scene.target = view_look
		scene.distance = maxf(o.length(),0.01)
		var dir: Vector3 = o/maxf(o.length(),0.01)
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = clampf(acos(clampf(dir.y,-1.0,1.0)),0.05,PI-0.05)
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		eye.camera.fov = 70.0 if chase else 64.0
		await process_frame
	print("JETS %s eye %s look %s camera %s (scene camera %s) currents at %s, scale %s" % [shot.label,at,look,eye.camera.global_position,scene.camera.global_position,_currents.global_transform.origin,_currents.global_transform.basis.get_scale()])
