extends SceneTree
## The mountain ring round the world's edge, rendered (scripts/sky_world.gd,
## scripts/sky_ring.gd): the wanderer steps off into the glide, the ring's
## skyline is made whole, and the eye is set at a row of spots for stills,
## the clock held at noon (and golden hour for the skylines):
##   top: high over the world's middle looking straight down, the haze off,
##     the ring's layout as a map (the notches, the saddles, the bounds);
##   skyline-N, -E, -S, -W: from the plate at glide height, looking out each
##     way, the ring as a skyline in the haze;
##   notch: from inside, near a notch, looking out through it;
##   approach: a kilometre in from a ring range, the full range near;
##   outside: from out past the ring, looking back in over it.
## The eye is held still at each spot (the glide's own stepping is paused),
## and the sky, the haze and the islands are advanced as the glide would.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_ring.gd \
##     -- --no-title --out=/private/tmp/zs-ring
## Options: --out=DIR, --only=top,notch,..., --sky-seed=N.
const SkyWorld = preload("res://scripts/sky_world.gd")
const GOLDEN_SUN := 0.1
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-ring"
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
	print("RING still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("sky ring capture timed out"); quit(2))
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
	var peaks: Node3D = islands.peaks
	peaks.advance(0.6,Vector3.ZERO)
	peaks.flush()
	var layout := SkyWorld.layout()
	print("RING seed %d: %d ranges, %d skylines, notches at %s deg, camera far %.0f m" % [SkyWorld.seed,layout.ranges.size(),peaks.ring.line_count(),str(layout.notches.map(func(n: Dictionary) -> int: return roundi(rad_to_deg(n.angle)))),eye.camera.far])
	for hour: float in [noon,golden]:
		var tag := "noon" if hour == noon else "golden"
		for shot: Dictionary in _shots():
			if not only.is_empty() and shot.label not in only: continue
			if hour == golden and not shot.get("golden",true): continue
			await _hold(shot,hour,60)
			await still("%s-%s" % [shot.label,tag])
	print("RING done")
	quit(0)

func _shots() -> Array:
	var shots := []
	var layout := SkyWorld.layout()
	shots.append({"label":"top","eye":Vector3(0.0,7600.0,1.0),"look":Vector3.ZERO,"haze":false,"golden":false,"fov":70.0})
	for d: Array in [["N",Vector3(0,0,-1)],["E",Vector3(1,0,0)],["S",Vector3(0,0,1)],["W",Vector3(-1,0,0)]]:
		var way: Vector3 = d[1]
		shots.append({"label":"skyline-"+d[0],"eye":way*30.0+Vector3.UP*45.0,"look":way*3000.0+Vector3.UP*120.0})
	var n: Dictionary = layout.notches[0]
	var nw := Vector3(cos(float(n.angle)),0.0,sin(float(n.angle)))
	var nc := SkyWorld.crest(float(n.angle))
	shots.append({"label":"notch","eye":nw*(nc-1300.0)+Vector3.UP*60.0,"look":nw*(nc+600.0)+Vector3.UP*20.0})
	var r: Dictionary = layout.ranges[layout.ranges.size()/2]
	var rw := Vector3(r.at.x,0.0,r.at.z).normalized()
	shots.append({"label":"approach","eye":r.at-rw*1100.0+Vector3.UP*70.0,"look":r.at+Vector3.UP*150.0})
	var o: Dictionary = layout.ranges[1]
	var ow := Vector3(o.at.x,0.0,o.at.z).normalized()
	shots.append({"label":"outside","eye":o.at+ow*1500.0+Vector3.UP*90.0,"look":-ow*2000.0+Vector3.UP*60.0,"golden":false})
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
	eye.glider.visible = false
	for i in range(count):
		scene.world_clock.running = false
		scene.world_clock.set_time(scene.world_clock.day,hour)
		var delta := 1.0/60.0
		eye.sky.haze = 1.0 if shot.get("haze",true) else 0.0
		eye.sky.advance(delta,at,0.0)
		eye.islands.advance(delta,at,glide.heading,0.0)
		# The ranges near the eye made in full at once.
		if i == 1: eye.islands.peaks.flush()
		var o := at-look
		scene.target = look
		scene.distance = maxf(o.length(),0.01)
		var dir: Vector3 = o/maxf(o.length(),0.01)
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = clampf(acos(clampf(dir.y,-1.0,1.0)),0.0005,PI-0.05)
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		eye.camera.fov = shot.get("fov",64.0)
		await process_frame
