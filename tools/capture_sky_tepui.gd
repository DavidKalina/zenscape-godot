extends SceneTree
## The sky tepui, rendered (scripts/sky_tepuis.gd, scripts/sky_tepui.gd): the
## wanderer steps off into the glide, the table mountain in sight of the
## plate is made, and the eye is set at a row of spots round it for stills,
## the clock held at noon and at golden hour:
##   distant: from far off past the plate, the tepui pale in the haze;
##   approach: from out by the plate, the tepui and its great fall;
##   fall: alongside the great fall at glide height;
##   behind: in the gap behind the curtain, looking along it;
##   plateau: over the plateau, looking across it, its towers and water;
##   down: over the lip, looking down the fall into the mist;
##   wall: beside the fluted walls, looking along them;
##   glider: the chase view behind the glider, heading for the fall.
## The eye is held still at each spot (the glide's own stepping is paused),
## and the sky, the haze and the islands are advanced as the glide would.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_tepui.gd \
##     -- --no-title --out=/private/tmp/zs-tepui
## Options: --out=DIR, --noon=HOUR, --golden=HOUR, --only=fall,behind,...
const GOLDEN_SUN := 0.1
const SkyTepui = preload("res://scripts/sky_tepui.gd")
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-tepui"
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
	print("TEPUI still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--noon="): noon = float(argument.trim_prefix("--noon="))
		elif argument.begins_with("--golden="): golden = float(argument.trim_prefix("--golden="))
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("sky tepui capture timed out"); quit(2))
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
	# Into the glide from the plate's edge, then the glide's stepping paused:
	# the eye is set by hand at each spot.
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
	islands.peaks.advance(0.6,Vector3.ZERO)
	islands.peaks.flush()
	var tepuis: Node3D = islands.peaks.tepuis
	if tepuis.tepui_count() == 0:
		push_error("no sky tepui was made")
		quit(1)
		return
	var b: Dictionary = tepuis.built.values()[0]
	var shape: RefCounted = b.shape
	print("TEPUI at %s turn %.2f, top %.0f m, plateau %.0f, %d towers, %d wraps, %d spruces, %d faces, gap %.0f-%.0f m" % [b.home,b.turn,shape.top,shape.plateau,shape.towers.size(),shape.wraps.size(),shape.trees.size(),(b.node.get_node("Body").mesh as ArrayMesh).surface_get_array_len(0)/3,shape.gap(-55.0),shape.gap(95.0)])
	var shots := _shots(tepuis,b)
	for hour: float in [noon,golden]:
		var tag := "noon" if hour == noon else "golden"
		for shot: Dictionary in shots:
			if not only.is_empty() and shot.label not in only: continue
			if hour == golden and not shot.get("golden",true): continue
			await _hold(shot,hour,90 if shot == shots[0] else 50)
			if shot == shots[0]: print("TEPUI %s hour %.2f sun %.3f" % [tag,hour,scene._celestial.sun_height])
			await still("%s-%s" % [shot.label,tag])
	print("TEPUI done")
	quit(0)

## The spots, from the tepui's own shape (in its frame, then global).
func _shots(tepuis: Node3D, b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	var g := func(local: Vector3) -> Vector3: return tepuis.global_of(b,local)
	var middle: Vector3 = g.call(Vector3(0.0,60.0,0.0))
	var plate := Vector3(0.0,25.0,0.0)
	var toward := Vector3(middle.x-plate.x,0.0,middle.z-plate.z).normalized()
	var f: Dictionary = shape.falls[0]
	var lip: Vector3 = f.lip
	var way: Vector2 = f.out
	var out3 := Vector3(way.x,0.0,way.y)
	var across := Vector3(way.y,0.0,-way.x)
	var mid: Vector3 = SkyTepui.fall_point(f,float(f.drop)*0.45)
	var shots := []
	shots.append({"label":"distant","eye":plate-toward*420.0+Vector3.UP*20.0,"look":middle+Vector3.UP*10.0})
	shots.append({"label":"approach","eye":plate+toward*250.0+Vector3.UP*10.0,"look":g.call(mid)})
	shots.append({"label":"fall","eye":g.call(mid+out3*170.0+across*120.0+Vector3.UP*-10.0),"look":g.call(mid+Vector3.UP*10.0)})
	var behind: Vector3 = SkyTepui.fall_point(f,lip.y-40.0)-out3*(shape.gap(40.0)*0.5+1.5)
	shots.append({"label":"behind","eye":g.call(behind+across*28.0),"look":g.call(behind-across*30.0+out3*6.0)})
	shots.append({"label":"plateau","eye":g.call(Vector3(lip.x,shape.top+35.0,lip.z)+out3*40.0),"look":g.call(Vector3(0.0,shape.plateau,-shape.radius*0.6))})
	shots.append({"label":"down","eye":g.call(lip+out3*25.0+across*115.0+Vector3.UP*60.0),"look":g.call(SkyTepui.fall_point(f,float(f.drop)*0.8))})
	var side_way := Vector2(way.x,way.y).rotated(-1.3)
	var wall_at: Vector2 = side_way*(shape.rim_radius(side_way)+90.0)
	shots.append({"label":"wall","eye":g.call(Vector3(wall_at.x,30.0,wall_at.y)),"look":g.call(Vector3(wall_at.x,70.0,wall_at.y)+Vector3(side_way.y,0.0,-side_way.x)*150.0-Vector3(side_way.x,0.0,side_way.y)*60.0)})
	shots.append({"label":"glider","eye":g.call(mid+out3*260.0+Vector3.UP*-20.0),"look":g.call(mid),"chase":true,"golden":false})
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
