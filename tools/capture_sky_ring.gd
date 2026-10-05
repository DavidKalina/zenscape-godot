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
##   map: straight down over the middle, closer than top, the haze off: the
##     ridges dividing the middle into regions, the passes through them;
##   plate-valley: from the plate at glide height, down the plate's region
##     to the pass through one of the walls across the world;
##   pass: from inside the plate's region, at glide height, through
##     another wall's pass into the valley beyond;
##   col: through the col by the range in sight of the plate, into the
##     valley behind it;
##   ridge: inside the plate's region at glide height, by a wall's middle
##     (its knot), looking along it out to a corner;
##   knot: a wall's knot of peaks from out by the plate;
##   valley-region: down a valley between a wall and the band, at glide
##     height;
##   overhead: from high over the plate, out over a wall and its corner;
##   approach: a kilometre in from a range of the band, the full range near;
##   outside: from out past the ring, looking back in over it.
## The eye is held still at each spot (the glide's own stepping is paused),
## and the sky, the haze and the islands are advanced as the glide would.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_ring.gd \
##     -- --no-title --out=/private/tmp/zs-ring
## Options: --out=DIR, --only=top,notch,..., --sky-seed=N, --painted-peaks.
##   sea-N, -E, -S, -W: the cloud sea out to the horizon from the plate, the
##     Opal sea's painted peaks off with the ring (on with --painted-peaks);
const SkyWorld = preload("res://scripts/sky_world.gd")
const GOLDEN_SUN := 0.1
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-ring"
var noon := WorldClock.hour_for_phase(0.5)
var golden := WorldClock.hour_for_phase(0.75-asin(clampf(GOLDEN_SUN/WorldClock.elevation_for_phase(0.5),-1.0,1.0))/TAU)
var only: Array = []
## --painted-peaks: the Opal sea's painted peaks drawn all the same (a before).
var painted := false

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
		elif argument == "--painted-peaks": painted = true
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(900).timeout.connect(func() -> void: push_error("sky ring capture timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	# Never takes the keyboard: keys meant for another window stay there.
	root.unfocusable = true
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
	print("RING regions %s, passes %s, knot %s" % [str(layout.regions.map(func(g: Dictionary) -> String: return "%s(%.0f, %.0f)" % ["home " if g.home else "",g.at.x,g.at.z])),str(layout.passes.map(func(p: Dictionary) -> String: return "(%.0f, %.0f) %d m" % [p.at.x,p.at.z,roundi(p.open)])),str(layout.knot)])
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
	shots.append({"label":"map","eye":Vector3(0.0,6000.0,1.0),"look":Vector3.ZERO,"haze":false,"golden":false,"fov":66.0})
	# The cloud sea out to the horizon each way, where the Opal sea painted
	# its distant peaks.
	for d: Array in [["N",Vector3(0,0,-1)],["E",Vector3(1,0,0)],["S",Vector3(0,0,1)],["W",Vector3(-1,0,0)]]:
		var way: Vector3 = d[1]
		shots.append({"label":"sea-"+d[0],"eye":Vector3.UP*60.0,"look":way*1200.0+Vector3.DOWN*260.0,"golden":false,"fov":75.0})
	for d: Array in [["N",Vector3(0,0,-1)],["E",Vector3(1,0,0)],["S",Vector3(0,0,1)],["W",Vector3(-1,0,0)]]:
		var way: Vector3 = d[1]
		shots.append({"label":"skyline-"+d[0],"eye":way*30.0+Vector3.UP*45.0,"look":way*3000.0+Vector3.UP*120.0})
	var n: Dictionary = layout.notches[0]
	var nw := Vector3(cos(float(n.angle)),0.0,sin(float(n.angle)))
	var nc := SkyWorld.crest(float(n.angle))
	shots.append({"label":"notch","eye":nw*(nc-1300.0)+Vector3.UP*60.0,"look":nw*(nc+600.0)+Vector3.UP*20.0})
	# The walls across the world (SkyWorld `_ridge_plan`): each pass knows
	# its wall (`chord`, 0 the one through the range in sight of the plate).
	var passes: Array = layout.passes
	var knot: Vector3 = layout.knot
	var chords: Array = layout.get("chords",[])
	var outer: Array = passes.filter(func(p: Dictionary) -> bool: return int(p.get("chord",1)) != 0)
	var homes: Array = passes.filter(func(p: Dictionary) -> bool: return int(p.get("chord",1)) == 0)
	if not outer.is_empty():
		# Down the plate's valley to a wall's pass.
		var p0: Dictionary = outer[0]
		var to0: Vector3 = (p0.at as Vector3).normalized()
		shots.append({"label":"plate-valley","eye":to0*60.0+Vector3.UP*50.0,"look":p0.at+Vector3.UP*35.0,"fov":62.0})
		# Through another wall's pass from the plate's side.
		var p1: Dictionary = outer[mini(1,outer.size()-1)]
		var way1: Vector3 = p1.way
		if way1.dot(-(p1.at as Vector3)) < 0.0: way1 = -way1
		shots.append({"label":"pass","eye":p1.at+way1*850.0+Vector3.UP*55.0,"look":p1.at-way1*900.0+Vector3.UP*30.0})
	if not homes.is_empty():
		# Through a col by the range in sight of the plate.
		var col: Dictionary = homes[0]
		var wayc: Vector3 = col.way
		if wayc.dot(-(col.at as Vector3)) < 0.0: wayc = -wayc
		shots.append({"label":"col","eye":col.at+wayc*800.0+Vector3.UP*55.0,"look":col.at-wayc*900.0+Vector3.UP*30.0,"golden":false})
	if chords.size() > 1:
		# Along a wall from inside the plate's region, by its middle (the
		# knot), out to a corner.
		var c: Dictionary = chords[1]
		var mid: Vector3 = c.at
		var along: Vector3 = c.along
		var inward: Vector3 = -mid.normalized()
		shots.append({"label":"ridge","eye":mid+inward*700.0-along*500.0+Vector3.UP*60.0,"look":mid+along*2200.0+Vector3.UP*80.0,"fov":62.0})
		shots.append({"label":"knot","eye":knot.normalized()*80.0+Vector3.UP*45.0,"look":knot+Vector3.UP*120.0,"golden":false})
		# Down a valley between a wall and the band, at glide height.
		for g: Dictionary in layout.regions:
			if g.home: continue
			var heart: Vector3 = g.at
			var round := Vector3(-heart.z,0.0,heart.x).normalized()
			shots.append({"label":"valley-region","eye":heart-round*700.0+Vector3.UP*55.0,"look":heart+round*1500.0+Vector3.UP*40.0,"fov":64.0})
			break
	# The walls from high over the plate, looking out over a corner.
	shots.append({"label":"overhead","eye":Vector3(0.0,1500.0,1.0)-knot.normalized()*900.0,"look":knot*1.6,"haze":true,"golden":false,"fov":66.0})
	# A range of the band's (its runs and massifs, halfway round them).
	var band: Array = layout.ranges.filter(func(q: Dictionary) -> bool: return q.kind == "run" or q.kind == "massif")
	var r: Dictionary = band[band.size()/2]
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
		# The sea's painted peaks back, for a before (look_pass `apply_sea_peaks`).
		if painted: scene._environment.sky.sky_material.set_shader_parameter("sea_peaks",1.0)
		eye.sky.advance(delta,at,0.0)
		eye.islands.advance(delta,at,glide.heading,0.0)
		# The ranges near the eye made in full at once: surveyed here and now
		# (SkyPeaks surveys every CHECK seconds), then waited for.
		if i == 1:
			var peaks: Node3D = eye.islands.peaks
			peaks._since = peaks.CHECK
			peaks.advance(0.0,at)
			peaks.flush()
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
