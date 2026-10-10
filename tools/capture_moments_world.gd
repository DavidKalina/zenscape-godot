extends SceneTree
## The moments set pieces in the sky (--moments: scripts/sky_moments.gd),
## rendered: the game booted with them, the plane put on the nearest set
## piece's way in (its hop), and stills of it from the approach (far, mid,
## off to one side) with the eye held, then from the game's own chase
## camera flying straight in down its line: before the hoop, just through
## it (the challenge on: the diamonds out, the HUD's count) and inside.
## Prints the frame's cost with the set pieces shown and hidden, held at
## the same view. Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_moments_world.gd \
##     -- --no-title --moments --out=captures/moments-world/try1 [--set-piece=N]
const Plan = preload("res://scripts/sky_moments_plan.gd")
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-moments-world"
var pick := -1
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
	print("MOMENTS still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--set-piece="): pick = int(argument.trim_prefix("--set-piece="))
	if out.is_relative_path(): out = ProjectSettings.globalize_path("res://").path_join(out)
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("moments capture timed out"); quit(2))
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
	scene.world_clock.set_time(scene.world_clock.day,WorldClock.hour_for_phase(0.45))
	eye = scene.wanderer
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	await frames(5)
	eye._launch(14.0,false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var islands: Node3D = eye.islands
	for i in range(900):
		if not islands.lands.has(null): break
		await frames(1)
	var moments: Node3D = islands.moments
	if moments == null:
		push_error("run with --moments")
		quit(1)
		return
	_parent = scene.camera.get_parent()
	# The nearest set piece, or the one asked for.
	var rows: Array = moments.list(Vector3.ZERO)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	var k: int = pick if pick >= 0 else rows[0].index
	var p: Dictionary = moments.placements[k]
	print("MOMENTS set piece %d: %s %s" % [k,p.key,Plan.footprint(int(p.layout)).name])
	var origin: Vector3 = islands.global_transform*islands.cells.origin
	var at := func(local: Vector3) -> Vector3: return origin+Plan.place(p,local)
	var hoop: Vector3 = at.call(Plan.starter())
	var middle: Vector3 = at.call(Vector3(0.0,0.0,-80.0))
	eye.set_process(false)
	eye._layer.visible = false
	# From the approach, the eye held.
	await _hold_at(at.call(Vector3(0.0,30.0,900.0)),hoop,120)
	await still("%02d-approach-900m" % k)
	await _hold_at(at.call(Vector3(0.0,10.0,320.0)),hoop,60)
	await still("%02d-approach-320m" % k)
	await _hold_at(at.call(Vector3(380.0,25.0,-60.0)),middle,60)
	await still("%02d-side-380m" % k)
	await _hold_at(at.call(Vector3(-120.0,60.0,120.0)),middle,60)
	await still("%02d-over" % k)
	# The frame's cost, the set pieces shown and hidden, the same view.
	for shown: bool in [true,false,true]:
		moments.visible = shown
		await _hold_at(at.call(Vector3(0.0,10.0,320.0)),middle,90)
		var ms := 0.0
		var calls := 0
		for i in range(60):
			await _hold_at(at.call(Vector3(0.0,10.0,320.0)),middle,1)
			ms += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
			calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		print("MOMENTS cost %s: process %.2f ms, fps %d, draw calls %d, primitives %d" % ["shown" if shown else "hidden",ms/60.0,Performance.get_monitor(Performance.TIME_FPS),calls,Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	# The chase camera, flying straight in down its line.
	moments.visible = true
	eye._layer.visible = true
	eye.set_process(true)
	var target: Dictionary = moments.hop(k)
	var start: Vector3 = islands.global_transform*(target.position as Vector3)
	eye._launch(14.0,false,start,float(target.heading))
	eye.chase.reset(eye.glide,start-Vector3(-sin(target.heading),0.0,-cos(target.heading))*6.0+Vector3.UP*2.0,eye.camera.fov)
	var shots := {60.0:"chase-before-hoop",20.0:"chase-through-hoop",-40.0:"chase-inside"}
	for i in range(60*30):
		eye.glide.heading = float(target.heading)
		await process_frame
		var z := Plan.unplace(p,(eye.glide.position as Vector3)-islands.cells.origin).z
		for at_z: float in shots.keys():
			if z <= at_z:
				await still("%02d-%s" % [k,shots[at_z]])
				shots.erase(at_z)
				print("MOMENTS hud: \"%s\" / \"%s\"" % [moments.hud.last_pop,moments.hud.last_status])
		if shots.is_empty(): break
	print("MOMENTS done")
	quit(0)

func _view(global: Vector3) -> Vector3:
	return _parent.to_local(global)

## Holds the eye at `at` looking at `look` (global) for `count` frames,
## advancing the sky and the islands as the glide would.
func _hold_at(at_global: Vector3, look_global: Vector3, count: int) -> void:
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
