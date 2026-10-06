extends SceneTree
## The towering cumulus, rendered (scripts/sky_towers.gd, scripts/
## sky_tower.gd): the wanderer steps off into the glide, the tower in sight
## of the plate is made, and the eye is set at a row of spots round and
## through it for stills, the clock held at noon and at golden hour:
##   distant: from far off past the plate, the tower pale in the haze;
##   approach: from a few hundred metres out at glide height;
##   sunlit: as far out, from the sun's side, the tower lit full on;
##   crown: from under its shoulder, looking up the column to the crown;
##   edge: a few seconds short of its side, about to fly in;
##   inside: in its heart, flying through;
##   burst: just leaving its far side, looking out into open sky;
##   glider: the chase view behind the glider, heading into it.
## The eye is held still at each spot (the glide's own stepping is paused),
## and the sky, the haze, the vapour and the islands are advanced as the
## glide would. Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_cumulus.gd \
##     -- --no-title --out=/private/tmp/zs-cumulus
## Options: --out=DIR, --noon=HOUR, --golden=HOUR (by default the clock's
## noon and the hour the setting sun stands GOLDEN_SUN high),
## --only=approach,inside,...; --rising=0.1,0.4,... and --waning=0.3,...
## take, instead of the shots, a still from out past the plate at each point
## of the tower's rising and waning (SkyTowers `pinned`), at noon and at
## golden hour. Each still also prints the frame's time with
## the towers drawn and hidden (vsync off), a rough measure of their cost.
const GOLDEN_SUN := 0.1
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-cumulus"
var noon := WorldClock.hour_for_phase(0.5)
var golden := WorldClock.hour_for_phase(0.75-asin(clampf(GOLDEN_SUN/WorldClock.elevation_for_phase(0.5),-1.0,1.0))/TAU)
var only: Array = []
var rising: Array = []
var waning: Array = []

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
	print("CUMULUS still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--noon="): noon = float(argument.trim_prefix("--noon="))
		elif argument.begins_with("--golden="): golden = float(argument.trim_prefix("--golden="))
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
		elif argument.begins_with("--rising="): rising = Array(argument.trim_prefix("--rising=").split(",")).map(func(v: String) -> float: return float(v))
		elif argument.begins_with("--waning="): waning = Array(argument.trim_prefix("--waning=").split(",")).map(func(v: String) -> float: return float(v))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("sky cumulus capture timed out"); quit(2))
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
	islands.towers.advance(0.6,Vector3.ZERO)
	islands.towers.flush()
	if not islands.towers.built.has("0,0"):
		push_error("no sky tower was made")
		quit(1)
		return
	var b: Dictionary = islands.towers.built["0,0"]
	var shape: RefCounted = b.shape
	print("CUMULUS tower at %s, %.0f m tall, %.0f m wide, %d lobes, box %s, %d towers built" % [b.home,shape.tall,shape.wide,shape.lobes.size(),shape.box.size,islands.towers.tower_count()])
	var shots := _shots(islands.towers,b)
	if not rising.is_empty() or not waning.is_empty():
		await _life(islands.towers,shots[0])
		print("CUMULUS done")
		quit(0)
		return
	for hour: float in [noon,golden]:
		var tag := "noon" if hour == noon else "golden"
		for shot: Dictionary in shots:
			if not only.is_empty() and shot.label not in only: continue
			if hour == golden and not shot.get("golden",true): continue
			await _hold(shot,hour,90 if shot == shots[0] else 50)
			# The frame's cost here, the towers drawn and not.
			var ms := await _frame_ms(30)
			islands.towers.visible = false
			var bare := await _frame_ms(30)
			islands.towers.visible = true
			print("CUMULUS %s-%s frame %.2f ms, %.2f ms without the towers" % [shot.label,"noon" if hour == noon else "golden",ms,bare])
			if shot == shots[0]: print("CUMULUS %s hour %.2f sun %.3f, cloud sun %s, cloud sky %s" % [tag,hour,scene._celestial.sun_height,scene._celestial.state.get("zs_cloud_sun"),scene._celestial.state.get("zs_cloud_sky")])
			await still("%s-%s" % [shot.label,tag])
	print("CUMULUS done")
	quit(0)

## The spots, from the range's own shape (in its frame, then global).
## The spots, from the tower's own shape (in its frame, then global).
func _shots(towers: Node3D, b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	var g := func(local: Vector3) -> Vector3: return towers.global_of(b,local)
	var axis: Vector2 = shape._axis(20.0)
	var heart: Vector3 = g.call(Vector3(axis.x,20.0,axis.y))
	var middle: Vector3 = g.call(Vector3(shape._axis(80.0).x,80.0,shape._axis(80.0).y))
	var plate := Vector3(0.0,25.0,0.0)
	var toward := Vector3(heart.x-plate.x,0.0,heart.z-plate.z).normalized()
	# Where the body's side is, coming in from the plate and leaving the far side.
	var near_side := heart
	while towers.depth(near_side) > 0.0: near_side -= toward*2.0
	var far_side := heart
	while towers.depth(far_side) > 0.0: far_side += toward*2.0
	var shots := []
	shots.append({"label":"distant","eye":heart-toward*1500.0+Vector3.UP*10.0,"look":middle+Vector3.UP*40.0})
	shots.append({"label":"approach","eye":heart-toward*520.0,"look":middle})
	# From the sun's side, the tower lit full on (the eye set round it when
	# the clock is set).
	shots.append({"label":"sunlit","eye":heart-toward*520.0,"look":middle,"sun_side":520.0})
	shots.append({"label":"crown","eye":near_side-toward*170.0+Vector3.DOWN*30.0,"look":g.call(Vector3(shape._axis(shape.top()).x,shape.top()-60.0,shape._axis(shape.top()).y))})
	shots.append({"label":"edge","eye":near_side-toward*110.0,"look":heart+Vector3.UP*5.0})
	shots.append({"label":"inside","eye":heart,"look":heart+toward*100.0+Vector3.UP*4.0})
	shots.append({"label":"burst","eye":far_side-toward*6.0,"look":far_side+toward*200.0+Vector3.DOWN*10.0})
	shots.append({"label":"glider","eye":near_side-toward*60.0,"look":heart,"chase":true,"golden":false})
	return shots

## The tower held at points of its rising and waning, seen from out past
## the plate (`shot`, nearer than the distant still, the whole column in view).
func _life(towers: Node3D, shot: Dictionary) -> void:
	var look: Vector3 = shot.look
	var at: Vector3 = shot.eye
	var view := {"label":"life","eye":look+(at-look).normalized()*900.0+Vector3.UP*20.0,"look":look+Vector3.UP*60.0}
	var points := []
	for g: float in rising: points.append(["rising-%03d" % roundi(g*100.0),towers.REST+towers.GROW*g])
	for w: float in waning: points.append(["waning-%03d" % roundi(w*100.0),towers.REST+towers.GROW+towers.HOLD+towers.WANE*w])
	var first := true
	for hour: float in [noon,golden]:
		for p: Array in points:
			towers.pinned = p[1]
			towers.flush()
			# The first held longer: the ranges are still coming in.
			await _hold(view,hour,240 if first else 40)
			first = false
			await still("%s-%s" % [p[0],"noon" if hour == noon else "golden"])

## The mean frame time (ms) over `count` frames, the view held.
func _frame_ms(count: int) -> float:
	await RenderingServer.frame_post_draw
	var from := Time.get_ticks_usec()
	for i in range(count): await RenderingServer.frame_post_draw
	return float(Time.get_ticks_usec()-from)/count/1000.0

## Holds the eye at a shot for `count` frames at `hour`, advancing the sky,
## the haze and the islands as the glide would.
func _hold(shot: Dictionary, hour: float, count: int) -> void:
	var at: Vector3 = shot.eye
	var look: Vector3 = shot.look
	if shot.has("sun_side"):
		scene.world_clock.set_time(scene.world_clock.day,hour)
		await frames(2)
		var sun: Vector3 = scene._celestial.state.get("zs_sun_direction",Vector3.UP)
		# Into the islands' frame: the diorama may stand turned in the world.
		sun = eye.islands.global_basis.inverse()*sun
		var flat := Vector3(sun.x,0.0,sun.z).normalized()
		at = Vector3(look.x,at.y,look.z)+flat*float(shot.sun_side)
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
