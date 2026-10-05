extends SceneTree
## The sky peaks, rendered (scripts/sky_peaks.gd, scripts/sky_peak.gd): the
## wanderer steps off into the glide, the range in sight of the plate is
## made, and the eye is set at a row of spots round it for stills, the clock
## held at noon and at golden hour:
##   distant: from far off past the plate, the range pale in the haze;
##   overview: over the plate, the islands in front and the range behind;
##   approach: from out by the plate, the range across the sky;
##   cliff: beside a face under the highest summit, looking along it;
##   gorge: inside the gorge at glide height, looking out of its far mouth;
##   base: over the flank, looking down to where it goes into the cloud;
##   foot: level with the cloud sea off the flank, the foot going into it;
##   slot, fins: down a pinch's tight slot, and over its fins (if any);
##   another: a range further off in the sky;
##   glider: the chase view behind the glider, heading for the gorge.
## The eye is held still at each spot (the glide's own stepping is paused),
## and the sky, the haze and the islands are advanced as the glide would.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_peaks.gd \
##     -- --no-title --out=/private/tmp/zs-peaks
## Options: --out=DIR, --noon=HOUR, --golden=HOUR (by default the clock's
## noon and the hour the setting sun stands GOLDEN_SUN high),
## --only=approach,gorge,...
const GOLDEN_SUN := 0.1
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-peaks"
var noon := WorldClock.hour_for_phase(0.5)
var golden := WorldClock.hour_for_phase(0.75-asin(clampf(GOLDEN_SUN/WorldClock.elevation_for_phase(0.5),-1.0,1.0))/TAU)
var only: Array = []

func _initialize() -> void:
	# The wonders are off in play (SkyHomes `stone`, `isles`); on here.
	preload("res://scripts/sky_homes.gd").stone = true
	preload("res://scripts/sky_homes.gd").isles = true
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label+".png")
	image.save_png(path)
	print("PEAKS still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--noon="): noon = float(argument.trim_prefix("--noon="))
		elif argument.begins_with("--golden="): golden = float(argument.trim_prefix("--golden="))
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("sky peaks capture timed out"); quit(2))
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
	if islands.peaks.range_count() == 0:
		push_error("no sky peak was made")
		quit(1)
		return
	# Ranges further off too, so a scattered one stands for its still; from
	# a spot near enough that the home range is kept (SkyPeaks FORGET).
	islands.peaks.advance(0.6,Vector3(-700.0,0.0,700.0))
	islands.peaks.flush()
	var b: Dictionary = islands.peaks.built["0,0"]
	var shape: RefCounted = b.shape
	print("PEAKS range at %s turn %.2f, top %.0f m, summits %s, %d wraps, %d spruces, %d faces" % [b.home,b.turn,shape.top,shape.summits,shape.wraps.size(),shape.trees.size(),(b.node.get_node("Body").mesh as ArrayMesh).surface_get_array_len(0)/3])
	var shots := _shots(islands.peaks,b)
	for hour: float in [noon,golden]:
		var tag := "noon" if hour == noon else "golden"
		for shot: Dictionary in shots:
			if not only.is_empty() and shot.label not in only: continue
			if hour == golden and not shot.get("golden",true): continue
			await _hold(shot,hour,90 if shot == shots[0] else 50)
			if shot == shots[0]: print("PEAKS %s hour %.2f sun %.3f" % [tag,hour,scene._celestial.sun_height])
			await still("%s-%s" % [shot.label,tag])
	print("PEAKS done")
	quit(0)

## The spots, from the range's own shape (in its frame, then global).
func _shots(peaks: Node3D, b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	var g := func(local: Vector3) -> Vector3: return peaks.global_of(b,local)
	var middle: Vector3 = g.call(Vector3(0.0,90.0,0.0))
	var plate := Vector3(0.0,25.0,0.0)
	var toward := Vector3(middle.x-plate.x,0.0,middle.z-plate.z).normalized()
	var shots := []
	# Far off past the plate, the range pale in the haze.
	shots.append({"label":"distant","eye":plate-toward*520.0+Vector3.UP*20.0,"look":middle+Vector3.UP*20.0})
	# Over the plate, as the builder's eye sees it: the islands' land in
	# front, the range across the sky behind.
	shots.append({"label":"overview","eye":plate-toward*70.0+Vector3.UP*45.0,"look":middle+Vector3.UP*10.0})
	# Out by the plate, looking across at the range.
	shots.append({"label":"approach","eye":plate+toward*180.0+Vector3.UP*10.0,"look":middle})
	# Beside a face under the highest summit, on the side toward the plate.
	var summit: Vector3 = shape.summits[0]
	var side := 1.0 if (peaks.local_of(b,plate) as Vector3).z > 0.0 else -1.0
	var z := summit.z
	while z*side < SkyPeak_half() and shape.height_at(Vector2(summit.x,z)) != null and float(shape.height_at(Vector2(summit.x,z))) > 30.0: z += side*4.0
	var cliff_eye: Vector3 = g.call(Vector3(summit.x+90.0,35.0,z+side*75.0))
	shots.append({"label":"cliff","eye":cliff_eye,"look":g.call(Vector3(summit.x-60.0,110.0,z-side*40.0))})
	# In the gorge at glide height, looking out of the far mouth.
	var gz := -side*60.0
	shots.append({"label":"gorge","eye":g.call(Vector3(shape.gorge_x(gz),12.0,gz)),"look":g.call(Vector3(shape.gorge_x(gz-side*260.0),0.0,gz-side*260.0))})
	# Looking back into the gorge's mouth from the plate's side.
	var mz := side*420.0
	shots.append({"label":"mouth","eye":g.call(Vector3(shape.gorge_x(mz)+30.0,40.0,mz)),"look":g.call(Vector3(shape.gorge_x(0.0),20.0,0.0))})
	# Over the flank, looking down to the foot in the cloud.
	var fz := summit.z
	while fz*side < SkyPeak_half() and shape.height_at(Vector2(summit.x+140.0,fz)) != null and float(shape.height_at(Vector2(summit.x+140.0,fz))) > -95.0: fz += side*4.0
	shots.append({"label":"base","eye":g.call(Vector3(summit.x+140.0,70.0,fz+side*130.0)),"look":g.call(Vector3(summit.x+100.0,-105.0,fz-side*30.0))})
	# Level with the cloud sea, off the flank: the foot going into the cloud.
	var foot_out: Vector3 = g.call(Vector3(summit.x+140.0,0.0,fz+side*260.0))
	shots.append({"label":"foot","eye":foot_out+Vector3.UP*(SkyPeak_sea()+45.0),"look":g.call(Vector3(summit.x-40.0,SkyPeak_sea()+20.0,fz-side*20.0))})
	# Through a pinch, if the gorge has one: down the slot, and over the fins.
	if not shape.pinch.is_empty():
		var pz: float = shape.pinch.z
		var top: float = shape.pinch.top
		var from := pz+side*110.0
		shots.append({"label":"slot","eye":g.call(Vector3(shape.gorge_x(from),top-24.0,from)),"look":g.call(Vector3(shape.gorge_x(pz),top-24.0,pz))})
		shots.append({"label":"fins","eye":g.call(Vector3(shape.gorge_x(from),top+30.0,from)),"look":g.call(Vector3(shape.gorge_x(pz-side*60.0),top-10.0,pz-side*60.0))})
	# Another range off in the sky, from out by the plate.
	for key in peaks.built:
		if key == "0,0": continue
		var other: Dictionary = peaks.built[key]
		var at: Vector3 = peaks.global_of(other,Vector3(0.0,120.0,0.0))
		var to := Vector3(at.x,0.0,at.z).normalized()
		shots.append({"label":"another","eye":Vector3(at.x,30.0,at.z)-to*1000.0,"look":at})
		break
	# The chase view behind the glider, heading into the gorge.
	shots.append({"label":"glider","eye":g.call(Vector3(shape.gorge_x(side*300.0),30.0,side*300.0)),"look":g.call(Vector3(shape.gorge_x(0.0),20.0,0.0)),"chase":true,"golden":false})
	return shots

func SkyPeak_sea() -> float:
	return preload("res://scripts/sky_peak.gd").SEA

func SkyPeak_half() -> float:
	return preload("res://scripts/sky_peak.gd").HALF.y

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
		# A range let go while the eye was elsewhere is made again at once.
		if i == 1: eye.islands.peaks.flush()
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
