extends SceneTree
## The forested isles, rendered (scripts/sky_forest_isles.gd, scripts/
## sky_forest_isle.gd): the wanderer steps off into the glide, the isle in
## sight of the plate is made, and the eye is set at a row of spots round it
## for stills, the clock held at noon and at golden hour:
##   distant: from far off past the plate, the isle long across the haze;
##   approach: from out by the plate, its forest and its rim;
##   underside: from under its rim, up at the rock hanging under it;
##   canopy: in under the crowns, down an aisle at glide height;
##   lake: at the forest's edge, bursting out over the water;
##   above: over the canopy, down onto the lake;
##   fall: beside the outflow's fall off the rim;
##   glider: the chase view behind the glider in an aisle.
## The eye is held still at each spot (the glide's own stepping is paused),
## and the sky, the haze and the islands are advanced as the glide would.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_forest_isles.gd \
##     -- --no-title --out=/private/tmp/zs-forest-isles
## Options: --out=DIR, --noon=HOUR, --golden=HOUR, --only=canopy,lake,...
const GOLDEN_SUN := 0.1
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-forest-isles"
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
	print("ISLES still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--noon="): noon = float(argument.trim_prefix("--noon="))
		elif argument.begins_with("--golden="): golden = float(argument.trim_prefix("--golden="))
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("forest isles capture timed out"); quit(2))
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
	var isles: Node3D = islands.isles
	isles.advance(0.6,Vector3.ZERO)
	isles.flush()
	var b: Dictionary = {}
	for key in isles.built:
		if isles.built[key].cell == Vector2i.ZERO: b = isles.built[key]
	if b.is_empty():
		push_error("no forested isle was made by the plate")
		quit(1)
		return
	var shape: RefCounted = b.shape
	var giants := 0
	for k: int in shape.kinds: giants += int(k == -1)
	var body: ArrayMesh = b.node.get_node("Body").mesh
	print("ISLES isle at %s turn %.2f, %.0f x %.0f m, top %.1f bottom %.1f canopy %.1f, %d lakes, %d giants, %d spruces, %d roots, %d faces" % [b.home,b.turn,shape.length,shape.width,shape.top,shape.bottom,shape.canopy,shape.lakes.size(),giants,shape.kinds.size()-giants,shape.roots.size(),body.surface_get_array_len(0)/3])
	var shots := _shots(isles,b)
	for hour: float in [noon,golden]:
		var tag := "noon" if hour == noon else "golden"
		for shot: Dictionary in shots:
			if not only.is_empty() and shot.label not in only: continue
			if hour == golden and not shot.get("golden",true): continue
			await _hold(shot,hour,90 if shot == shots[0] else 50)
			await still("%s-%s" % [shot.label,tag])
	print("ISLES done")
	quit(0)

## The spots, from the isle's own shape (in its frame, then global).
func _shots(isles: Node3D, b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	var g := func(local: Vector3) -> Vector3: return isles.global_of(b,local)
	var middle: Vector3 = g.call(Vector3(0.0,20.0,0.0))
	var plate := Vector3(0.0,25.0,0.0)
	var toward := Vector3(middle.x-plate.x,0.0,middle.z-plate.z).normalized()
	var shots := []
	shots.append({"label":"distant","eye":plate-toward*300.0+Vector3.UP*40.0,"look":middle})
	shots.append({"label":"approach","eye":middle-toward*260.0+Vector3.UP*15.0,"look":middle+Vector3.DOWN*25.0})
	# Under the rim on the plate's side, looking up at the rock.
	var side: float = 1.0 if (isles.local_of(b,plate) as Vector3).z > 0.0 else -1.0
	shots.append({"label":"underside","eye":g.call(Vector3(-shape.half.x*0.35,shape.bottom-15.0,side*(shape.half.y+110.0))),"look":g.call(Vector3(shape.half.x*0.1,shape.bottom*0.55,0.0))})
	# Down the first aisle, from the rim toward the lake, under the crowns.
	# The aisle and the point along it most under the crowns.
	var lane: PackedVector3Array = shape.lane(0,12.0)
	var k := 0
	var most := -1
	for a in range(shape.aisles.size()):
		var candidate: PackedVector3Array = shape.lane(a,12.0)
		var found: Vector2i = _shadiest(shape,candidate)
		if found.y > most:
			most = found.y
			lane = candidate
			k = found.x
	var ahead := mini(k+12,lane.size()-1)
	shots.append({"label":"canopy","eye":g.call(lane[k]),"look":g.call(lane[ahead]+Vector3.UP*1.0)})
	# Just out from under the trees at the lake's shore where the aisle
	# meets it, over the water, looking across to the far shore.
	var lake: Dictionary = shape.lakes[0]
	var middle_lake: Vector2 = lake.middle
	var entry := Vector2(lane[0].x,lane[0].z)
	var a := (entry-middle_lake).angle()-float(lake.turn)
	var near_shore: Vector2 = shape._lake_point(lake,a,0.92)
	var far_shore: Vector2 = shape._lake_point(lake,a+PI,1.0)
	var over := Vector3(near_shore.x,float(lake.level)+8.0,near_shore.y)
	var across := Vector3(far_shore.x,float(lake.level)+6.0,far_shore.y)
	shots.append({"label":"lake","eye":g.call(over),"look":g.call(across)})
	shots.append({"label":"above","eye":g.call(Vector3(middle_lake.x-shape.half.x*0.5,shape.canopy+55.0,middle_lake.y+shape.half.y*0.9)),"look":g.call(Vector3(middle_lake.x,float(lake.level),middle_lake.y))})
	var lip := Vector3(shape.lip.x,shape.lip_level,shape.lip.y)
	var out_way := Vector3(shape.lip_out.x,0.0,shape.lip_out.y)
	var along := out_way.cross(Vector3.UP)
	shots.append({"label":"fall","eye":g.call(lip+out_way*70.0+along*45.0+Vector3.DOWN*35.0),"look":g.call(lip+out_way*4.0+Vector3.DOWN*30.0)})
	shots.append({"label":"glider","eye":g.call(lane[k]),"look":g.call(lane[ahead]),"chase":true,"golden":false})
	return shots

## The lane's point most under the crowns, in its first two thirds, off the
## water: the one the most crowns reach over, counting a little way ahead;
## Vector2i(its index, that count).
func _shadiest(shape: RefCounted, lane: PackedVector3Array) -> Vector2i:
	var best := 0
	var most := -1
	for i in range(int(lane.size()*0.1),int(lane.size()*0.66)):
		var covered := 0
		for j in range(i,mini(i+6,lane.size())):
			var p := Vector2(lane[j].x,lane[j].z)
			if not shape._dry(p,1.6,SkyForestIsle_CHANNEL()+8.0): covered -= 100
			for index in shape.near(p):
				var t: Vector4 = shape.trees[index]
				if shape.kinds[index] == -1 and p.distance_to(Vector2(t.x,t.y)) < shape.crowns[index].z+3.0: covered += 1
		if covered > most:
			most = covered
			best = i
	return Vector2i(best,most)

func SkyForestIsle_CHANNEL() -> float:
	return preload("res://scripts/sky_forest_isle.gd").CHANNEL

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
			eye.chase.step(delta,glide,0.0,eye._solid)
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
