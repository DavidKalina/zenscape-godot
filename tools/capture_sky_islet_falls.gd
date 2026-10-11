extends SceneTree
## An islet's fall carried down to the cloud sea, rendered (scripts/
## sky_fall_thread.gd, scripts/sky_islets.gd `_fall`): the wanderer steps off
## into the glide, the spring islet nearest the plate is made, and the eye
## is set at a row of spots round its fall for stills, the clock held at
## noon and at golden hour:
##   side: level with the islet, off to the side, the whole thread in view;
##   low: halfway down, looking along the veil to the bloom on the sea;
##   down: above and out past the lip, looking down the fall to where it lands;
##   distant: far off, the islet small, its thread down to the sea in the haze;
##   glider: the chase view behind the glider, heading past the fall.
## The eye is held still at each spot (the glide's own stepping is paused),
## and the sky, the haze and the islands are advanced as the glide would.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_islet_falls.gd \
##     -- --no-title --out=/private/tmp/zs-islet-falls
## Options: --out=DIR, --noon=HOUR, --golden=HOUR, --only=side,down,...
const GOLDEN_SUN := 0.1
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyFallThread = preload("res://scripts/sky_fall_thread.gd")
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-islet-falls"
var noon := WorldClock.hour_for_phase(0.5)
var golden := WorldClock.hour_for_phase(0.75-asin(clampf(GOLDEN_SUN/WorldClock.elevation_for_phase(0.5),-1.0,1.0))/TAU)
var only: Array = []

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
	print("ISLET FALL still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--noon="): noon = float(argument.trim_prefix("--noon="))
		elif argument.begins_with("--golden="): golden = float(argument.trim_prefix("--golden="))
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("islet falls capture timed out"); quit(2))
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
	var islets: Node3D = islands.islets
	var found := _nearest_spring(islets)
	if found.is_empty():
		push_error("no spring islet near the plate")
		quit(1)
		return
	var b: Dictionary = islets.built[islets._key(found.cell)]
	var node: Node3D = b.node
	var thread: MeshInstance3D = node.get_node_or_null("FallThread")
	if thread == null:
		push_error("the spring islet has no fall thread")
		quit(1)
		return
	var water: Dictionary = (b.shape as RefCounted).water()
	var lip := node.global_position+Vector3(water.lip.x,water.level,water.lip.y)
	var way := Vector3(water.out.x,0.0,water.out.y).normalized()
	var sea_y: float = SkyFallThread.SEA+islets.global_position.y
	print("ISLET FALL islet %s at %s, lip %.1f m, sea %.1f m, drop %.0f m" % [found.cell,node.global_position,lip.y,sea_y,lip.y-sea_y])
	var shots := _shots(lip,way,sea_y)
	for hour: float in [noon,golden]:
		var tag := "noon" if hour == noon else "golden"
		for shot: Dictionary in shots:
			if not only.is_empty() and shot.label not in only: continue
			if hour == golden and not shot.get("golden",true): continue
			await _hold(shot,hour,90 if shot == shots[0] else 50)
			await still("%s-%s" % [shot.label,tag])
	print("ISLET FALL done")
	quit(0)

## The nearest cell to the plate holding a spring islet, built.
func _nearest_spring(islets: Node3D) -> Dictionary:
	var best := {}
	var best_d := INF
	for x in range(-5,6):
		for z in range(-5,6):
			var cell := Vector2i(x,z)
			var home: Variant = islets.spot(cell)
			if home == null: continue
			if SkyIslet.make(SkyIslets.seed_of(cell)).water().is_empty(): continue
			var d: float = Vector2(home.x,home.z).length()
			if d < best_d:
				best_d = d
				best = {"cell":cell,"home":home}
	if best.is_empty(): return best
	if not islets.built.has(islets._key(best.cell)): islets._build(best.cell,best.home)
	return best

func _shots(lip: Vector3, way: Vector3, sea_y: float) -> Array:
	var across := way.cross(Vector3.UP).normalized()
	var drop := lip.y-sea_y
	var mid := lip+way*6.0+Vector3.DOWN*drop*0.5
	var foot := lip+way*8.0+Vector3.DOWN*drop
	var shots := []
	shots.append({"label":"side","eye":mid+across*drop*1.1+way*drop*0.4+Vector3.UP*drop*0.25,"look":mid})
	shots.append({"label":"low","eye":foot+across*45.0+way*30.0+Vector3.UP*drop*0.55,"look":foot})
	shots.append({"label":"down","eye":lip+way*28.0+across*18.0+Vector3.UP*22.0,"look":foot})
	shots.append({"label":"distant","eye":mid+across*380.0+way*160.0+Vector3.UP*30.0,"look":mid})
	shots.append({"label":"glider","eye":mid+way*70.0+across*40.0+Vector3.UP*drop*0.3,"look":mid,"chase":true,"golden":false})
	return shots

## Holds the eye at a shot for `count` frames at `hour`, advancing the sky,
## the haze and the islands as the glide would.
func _hold(shot: Dictionary, hour: float, count: int) -> void:
	var at: Vector3 = shot.eye
	var look: Vector3 = shot.look
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
		eye.sky.advance(delta,view_eye,0.0)
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
