extends SceneTree
## The sky's collectible tokens (scripts/sky_collectibles.gd), rendered:
## the game with --collectibles-near-home (every kind laid near the home),
## the wanderer stepped off into the plane and the eye held by a line of
## each category (bridge, under, air: a swoop between islands and a
## cluster's gap or peak, foot), at noon, golden hour and night; then the
## readout during a pickup. Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_collectibles.gd \
##     -- --no-title --collectibles-near-home --out=captures/collectibles/try1 [--hours=noon,golden,night]
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-collectibles"
var hours_wanted: Array = ["noon","golden","night"]
var hours := {"noon": WorldClock.hour_for_phase(0.5), "golden": WorldClock.hour_for_phase(0.72), "night": WorldClock.hour_for_phase(0.02)}
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
	print("COLLECTIBLES still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--hours="): hours_wanted = Array(argument.trim_prefix("--hours=").split(","))
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(1500).timeout.connect(func() -> void: push_error("collectibles capture timed out"); quit(2))
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
		if islands.built(): break
		await frames(1)
	_parent = scene.camera.get_parent()
	var tokens: Node3D = islands.collectibles
	var field: Node3D = islands.clusters
	await _hold_at(Vector3(0.0,30.0,40.0),Vector3.ZERO,hours.noon,30)
	for s: Dictionary in field.spots:
		if str(s.key).begins_with("near:"): field.plan_now(s.key)
	await _hold_at(Vector3(0.0,30.0,40.0),Vector3.ZERO,hours.noon,120)
	tokens.flush(Vector3(0.0,30.0,40.0))
	print("COLLECTIBLES census %s" % str(tokens.census()))
	await _hold_at(Vector3(0.0,30.0,40.0),Vector3.ZERO,hours.noon,30)
	print("COLLECTIBLES cost: survey %d us, %d points looked over, %d standing; the sky's advance spent %s" % [int(tokens.spent.get("survey",0)),int(tokens.spent.get("looked",0)),int(tokens.spent.get("live",0)),str(islands.spent)])
	# One line of each category (the air's twice: a swoop and a cluster's),
	# the nearest to the home first.
	var picks := {}
	var lines: Array = tokens.all_lines()
	lines.sort_custom(func(a: Array, b: Array) -> bool: return _middle(tokens,a).length() < _middle(tokens,b).length())
	for entry: Array in lines:
		var l: Dictionary = entry[1]
		var label: String = l.category if l.category != "air" else ("air-trail" if l.kind == "trail" else "air-"+str(l.kind))
		if not picks.has(label): picks[label] = entry
	print("COLLECTIBLES views: %s" % str(picks.keys()))
	for label: String in picks:
		var entry: Array = picks[label]
		var view := _view_of(tokens,entry)
		for hour_name: String in hours_wanted:
			await _hold_at(view.eye,view.look,hours[hour_name],50)
			tokens.flush(view.eye)
			await _hold_at(view.eye,view.look,hours[hour_name],10)
			await still("%s-%s" % [label,hour_name])
	# The readout during a pickup: by a line, one taken, then the next.
	for label: String in ["foot","bridge","air-trail"]:
		if not picks.has(label): continue
		var entry: Array = picks[label]
		var view := _view_of(tokens,entry)
		await _hold_at(view.eye,view.look,hours.golden,40)
		tokens.flush(view.eye)
		var s: Dictionary = tokens.sources[entry[0]]
		var l: Dictionary = entry[1]
		for k in range(2):
			var id := "%s:%d" % [l.id,k]
			if s.live.has(id): tokens.collect(s,id)
			await _hold_at(view.eye,view.look,hours.golden,12)
		await still("hud-%s" % label)
		break
	print("COLLECTIBLES done")
	quit(0)

## A line's middle (global).
func _middle(tokens: Node3D, entry: Array) -> Vector3:
	var s: Dictionary = tokens.sources[entry[0]]
	var points: PackedVector3Array = entry[1].points
	var sum := Vector3.ZERO
	for p in points: sum += tokens.place(s,p)
	return sum/maxf(points.size(),1)

## Where to stand to see a line: behind its first token along it and to
## one side, low by the walker's lines, under the rock for an under line.
func _view_of(tokens: Node3D, entry: Array) -> Dictionary:
	var s: Dictionary = tokens.sources[entry[0]]
	var l: Dictionary = entry[1]
	var points: PackedVector3Array = l.points
	var first: Vector3 = tokens.place(s,points[0])
	var last: Vector3 = tokens.place(s,points[points.size()-1])
	var middle := _middle(tokens,entry)
	var way := (last-first)
	way.y = 0.0
	way = way.normalized() if way.length() > 0.01 else Vector3.FORWARD
	var side := way.cross(Vector3.UP)
	match str(l.category):
		"foot": return {"eye":first-way*2.6+side*1.4+Vector3.UP*1.1,"look":middle}
		"bridge": return {"eye":middle+side*4.5-way*2.0+Vector3.UP*1.6,"look":middle}
		"under": return {"eye":first-way*10.0+side*6.0+Vector3.DOWN*1.5,"look":middle+Vector3.UP*2.0}
	if l.kind == "trail": return {"eye":first-way*9.0+side*3.0+Vector3.UP*1.5,"look":middle}
	return {"eye":first-way*14.0+side*4.0+Vector3.UP*2.5,"look":middle}

func _view(global: Vector3) -> Vector3:
	return _parent.to_local(global)

## Holds the eye at `at` looking at `look` (global) for `count` frames at
## `hour`, advancing the sky and the islands as the glide would.
func _hold_at(at_global: Vector3, look_global: Vector3, hour: float, count: int) -> void:
	var glide: RefCounted = eye.glide
	eye.glider.visible = false
	for i in range(count):
		var at := _view(at_global)
		var look := _view(look_global)
		var way := (look-at).normalized()
		glide.position = at
		glide.heading = atan2(-way.x,-way.z)
		glide.pitch = asin(clampf(way.y,-1.0,1.0))
		glide.bank = 0.0
		glide.speed = 8.0
		glide.velocity = glide.forward()*8.0
		scene.world_clock.running = false
		scene.world_clock.set_time(scene.world_clock.day,hour)
		var delta := 1.0/60.0
		eye.sky.advance(delta,at,eye.islands.in_cloud(at,scene._motion_time))
		eye.islands.advance(delta,at,glide.heading,0.0)
		var o := at-look
		scene.target = look
		scene.distance = maxf(o.length(),0.01)
		var dir: Vector3 = o/maxf(o.length(),0.01)
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = clampf(acos(clampf(dir.y,-1.0,1.0)),0.05,PI-0.05)
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		eye.camera.fov = 64.0
		await process_frame
