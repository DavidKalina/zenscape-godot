extends SceneTree
## Headless probe of the glide (scripts/sky_glide.gd) in the cozy worlds
## scene, through the wanderer (scripts/wanderer_eye.gd):
##   - walked off the plate's edge, the figure glides, flat chunks
##     out in the sky (scripts/sky_islands.gd);
##   - the view leans into a turn;
##   - wandered far off, an island rises ahead with a thermal; fallen into
##     the parted sea, one surfaces just ahead; past the cap the farthest go;
##   - a slow skim on the plate lands, back to walking;
##   - V mid-glide steps out onto the plate;
##   - the chase camera trails the glider, drawn under its wing; C swaps to
##     its eyes and back;
##   - under the plate the glide stays under it, never snapped on top;
##   - landing, the camera swoops down into the eyes;
##   - flown into, a chunk is claimed as the plate, the island left kept in
##     the sky and the save; flown back, the island built returns;
##   - F comes in to land, slows, flares and touches down.
## Visuals (the chunks' look, the streaks) need a rendered run.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_sky_glide.gd -- --no-title
var scene: Node3D
var editor: NativeChunkEditor
var eye: Node
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func frames(count: int) -> void:
	for i in range(count): await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	create_timer(260).timeout.connect(func() -> void: push_error("sky glide probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-glide-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	eye = scene.wanderer
	scene.world_clock.running = false
	await frames(30)

	# Off the edge.
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	eye._yaw = atan2(-1.0,0.0)+eye._turn()
	eye._polar = PI*0.5
	key(KEY_W,true)
	for i in range(120):
		await frames(1)
		if eye.flying: break
	key(KEY_W,false)
	check("walked off the edge, it glides",eye.flying)
	if not eye.flying:
		finish()
		return
	# Their plains bake on a worker.
	for i in range(600):
		if not eye.islands.lands.has(null): break
		await frames(1)
	check("fresh chunks stand out in the sky",eye.islands.copy_count() == eye.islands.OFFSETS.size() and eye.islands._copies[0].get_child_count() == 2,
		"%d chunks of %d parts" % [eye.islands.copy_count(),eye.islands._copies[0].get_child_count()])
	# Each is the Quiet plain its seed forms, and no two seeds match.
	var fresh := NativeTerrainData.new()
	fresh.setup(eye.editor.data.source_mesh,eye.editor.data._arrays.duplicate())
	preload("res://scripts/genesis_canvas.gd").shape(fresh,eye.islands.seeds[0])
	var probe_at := Vector2(3.0,-2.0)
	var chunk_ground: Variant = eye.islands.ground(eye.islands.offsets[0]+eye.editor.terrain.to_global(Vector3(probe_at.x,0.0,probe_at.y)))
	var plain_y: float = eye.editor.terrain.to_global(Vector3(probe_at.x,float(fresh.ground_height(probe_at)),probe_at.y)).y+eye.islands.offsets[0].y
	check("a chunk is the fresh plain of its seed",chunk_ground != null and absf(float(chunk_ground)-plain_y) < 0.05,"%s vs %.2f" % [chunk_ground,plain_y])
	check("each chunk has its own seed",eye.islands.seeds[0] != eye.islands.seeds[1])
	var start_y: float = eye.glide.position.y
	await frames(40)
	check("it drops away off the edge",eye.glide.position.y < start_y-1.0,"%.1f to %.1f m" % [start_y,eye.glide.position.y])
	check("the chase view takes its own field of view",absf(scene.camera.fov-eye.CHASE_FOV) < 3.0,"%.1f deg" % scene.camera.fov)
	key(KEY_D,true)
	await frames(45)
	key(KEY_D,false)
	check("a turn leans the view",scene.camera_roll < -0.2,"%.2f rad" % scene.camera_roll)
	var cam_at: Vector3 = scene.camera.global_position
	var trail: Vector3 = cam_at-eye.glide.position
	check("the camera chases from behind and above",trail.length() > 2.5 and trail.length() < 10.0 and trail.dot(-eye.glide.forward()) > 1.0 and trail.y > 0.0,"%.1f m off" % trail.length())
	check("the glider is drawn in the air",eye.glider.visible and eye.glider.position.distance_to(eye.glide.position) < 0.6)
	key(KEY_C,true)
	key(KEY_C,false)
	await frames(2)
	check("C looks from its eyes",scene.camera.global_position.distance_to(eye.glide.position) < 0.5 and not eye.glider.visible)
	key(KEY_C,true)
	key(KEY_C,false)
	await frames(2)
	check("and C again chases",eye.glider.visible and not eye.chase.first_person)
	var flaps_before: int = eye.glide.flaps
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	Input.flush_buffered_events()
	await frames(3)
	key(KEY_E,true)
	key(KEY_E,false)
	await frames(40)
	check("a click flaps, and so does E",eye.glide.flaps == flaps_before+2,"%d flaps" % (eye.glide.flaps-flaps_before))

	# Under the plate: it stays under, and comes out beyond.
	eye.glide.position = eye.editor.terrain.to_global(Vector3(-20.0,-22.0,0.0))
	eye.glide.heading = -PI*0.5
	eye.glide.pitch = 0.0
	eye.glide.speed = 8.0
	var below := 0
	var snapped := false
	for i in range(300):
		await frames(1)
		var local: Vector3 = eye.editor.terrain.to_local(eye.glide.position)
		if absf(local.x) < 13.0 and absf(local.z) < 13.0:
			below += 1
			if local.y > NativeTerrainData.SLAB_BASE: snapped = true
	check("under the plate it passes beneath",below > 60 and not snapped,"%d frames under" % below)
	check("the camera keeps out of the rock",not eye._solid(scene.camera.global_position))

	# The sky answers: the sea slides by and swells, parts under a fall,
	# and a cloud's heart is a white-out.
	var flight: Vector4 = eye.sky.flight
	check("the cloud sea follows the glide",flight.z != 1.0 or Vector2(flight.x,flight.y).length() > 0.0,flight)
	# Beside an island, so none surfaces to catch the fall yet.
	eye.glide.position = Vector3(eye.islands.offsets[0].x+150.0,-95.0,eye.islands.offsets[0].z)
	eye.glide.airborne = 10.0
	await frames(30)
	check("falling to the cloud sea parts it",eye.sky.flight.w > 0.5,"%.2f" % eye.sky.flight.w)
	# A cloud near the field's middle, so following the eye doesn't re-wrap it.
	var clouds: Node3D = eye.islands.clouds
	var middle: Vector3 = Vector3(clouds.field.x+clouds.field.z*0.5,0.0,clouds.field.y+clouds.field.w*0.5)+clouds.shift
	var cloud := 0
	for i in range(clouds.clouds.size()):
		var c: Vector3 = clouds.centre(i,scene._motion_time)
		var best: Vector3 = clouds.centre(cloud,scene._motion_time)
		if Vector2(c.x-middle.x,c.z-middle.z).length() < Vector2(best.x-middle.x,best.z-middle.z).length(): cloud = i
	eye.glide.position = clouds.centre(cloud,scene._motion_time)
	await frames(30)
	check("flown into a cloud, the view goes to vapour",eye.sky.vapour > 0.3,"%.2f" % eye.sky.vapour)
	check("the clouds show while gliding",eye.islands.clouds.visible)

	# Wandered off: an island rises ahead, with a thermal.
	var isl: Node3D = eye.islands
	var thermals := func() -> int: return isl.currents.currents.filter(func(c: Dictionary) -> bool: return c.kind == "thermal").size()
	var had: int = isl.copy_count()
	var had_thermals: int = thermals.call()
	# Set back from a far spot along the heading, so it lies ahead.
	var heading_way := Vector2(-sin(0.7),-cos(0.7))
	var ahead: Vector3 = isl.cells.spots_near(Vector3(2600.0,0.0,-2300.0),600.0)[0]+isl.cells.origin
	eye.glide.position = ahead-Vector3(heading_way.x,0.0,heading_way.y)*isl.cells.IDEAL+Vector3.UP*30.0
	eye.glide.heading = 0.7
	eye.glide.pitch = 0.0
	await frames(2)
	isl.cells.wandered = isl.cells.WANDER_TIME
	await frames(2)
	var new_at: Vector3 = isl.offsets[isl.offsets.size()-1]
	var out := Vector2(new_at.x-eye.glide.position.x,new_at.z-eye.glide.position.z).length()
	check("wandered off, an island turns up ahead",isl.copy_count() == had+1 and out > isl.cells.NEAR-20.0 and out < isl.cells.FAR+20.0,"%d copies, %.0f m out" % [isl.copy_count(),out])
	check("it rises out of the haze",isl.sunk(isl.offsets.size()-1) > 30.0,"%.0f m below" % isl.sunk(isl.offsets.size()-1))
	check("it brings a thermal",thermals.call() == had_thermals+1,"%d thermals" % thermals.call())
	await frames(int(isl.WANDER_RISE.y*60.0)+10)
	check("then it stands at its spot",isl.sunk(isl.offsets.size()-1) == 0.0 and isl._copies[isl.offsets.size()-1].position.is_equal_approx(new_at))
	# Fallen into the parted sea: one surfaces just ahead.
	had = isl.copy_count()
	eye.glide.position = Vector3(-2400.0,-95.0,2600.0)
	eye.glide.airborne = 10.0
	for i in range(60):
		await frames(1)
		if isl.copy_count() > had: break
	var fall_at: Vector3 = isl.offsets[isl.offsets.size()-1]
	var gap := Vector2(fall_at.x-eye.glide.position.x,fall_at.z-eye.glide.position.z).length()
	check("fallen into the sea, an island surfaces just ahead",isl.copy_count() == had+1 and gap < isl.cells.AHEAD+isl.cells.RANGE,"%.0f m off, parted %.2f" % [gap,eye.sky.flight.w])
	await frames(30)
	check("with one in reach, no more turn up",isl.copy_count() == had+1,"%d copies" % isl.copy_count())
	# Past the cap the farthest go, never the newest.
	var home: Vector3 = eye.glide.position-isl.cells.origin
	var taken := []
	for h: Vector3 in isl.homes: taken.append(h)
	for s: Vector3 in isl.cells.spots_near(home,2000.0):
		if isl.copy_count() >= isl.CAP+3: break
		var free := true
		for t: Vector3 in taken: if Vector2(t.x-s.x,t.z-s.z).length() < 1.0: free = false
		if free: isl.realise(s,"wander")
	var newest: Vector3 = isl._newest
	await frames(2)
	check("past the cap the farthest copies go",isl.copy_count() <= isl.CAP,"%d copies" % isl.copy_count())
	check("never the newest",isl.homes.any(func(h: Vector3) -> bool: return h.distance_to(newest) < 1.0))

	# A slow skim lands.
	var ground: float = eye.islands.ground(Vector3(3.0,0.0,3.0))
	eye.glide.position = Vector3(3.0,ground+1.0,3.0)
	eye.glide.speed = 5.5
	eye.glide.pitch = -0.3
	for i in range(240):
		await frames(1)
		if not eye.flying: break
	check("a slow skim on the plate lands",not eye.flying and eye.active,"flying %s" % eye.flying)
	check("landed, the feet are on the plate",absf(eye._feet.x) <= eye.PLATE_REACH and absf(eye._feet.z) <= eye.PLATE_REACH,eye._feet)
	check("landed, the lean is gone",scene.camera_roll == 0.0)
	check("landed, the camera swoops down into the eyes",eye._swoop > 0.0 and scene.camera.global_position.distance_to(eye._eye_global()) > 0.5,"%.2f s" % eye._swoop)
	check("landed, the glider is put away",not eye.glider.visible)
	await frames(70)
	check("then it looks from the eyes",scene.camera.global_position.distance_to(eye._eye_global()) < 0.3,scene.camera.global_position.distance_to(eye._eye_global()))
	await frames(120)
	check("landed, the cloud sea settles back to rest",eye.sky.flight.is_equal_approx(Vector4(0.0,0.0,1.0,0.0)) and eye.sky.vapour < 0.01,eye.sky.flight)
	check("landed, the clouds hide",not eye.islands.clouds.visible)

	# Glide from anywhere: a tap of Space hops; held, it opens the glide.
	await frames(30)
	eye._feet = eye._clamped(Vector3(2.0,0.0,2.0))
	eye._pace = Vector2.ZERO
	await frames(10)
	var stand: float = eye._eye_y
	key(KEY_SPACE,true)
	await frames(4)
	key(KEY_SPACE,false)
	var peak := stand
	for i in range(60):
		await frames(1)
		peak = maxf(peak,eye._eye_y)
	check("a tap of Space jumps and comes down",peak > stand+0.3 and eye._hop == 0.0 and not eye.flying,"%.2f m up" % (peak-stand))
	key(KEY_SPACE,true)
	for i in range(40):
		await frames(1)
		if eye.flying: break
	check("held, it opens the glide anywhere",eye.flying)
	check("opened from a jump, there is no drop",eye.glide.airborne >= eye.glide.FALL_TIME)
	check("off flat ground, Rise barely lifts it (no airspeed)",eye.glide.climb < 1.5,"%.2f m/s" % eye.glide.climb)
	key(KEY_SPACE,false)
	for i in range(360):
		await frames(1)
		if not eye.flying: break
	check("off flat ground it flutters and lands",not eye.flying and eye.active)
	# The wind over the island: up a windward slope the air rises.
	var atmosphere: Node = scene._atmosphere
	var way := Vector2(cos(atmosphere._air_angle),sin(atmosphere._air_angle))
	var best := Vector3.ZERO
	var steepest := 0.0
	for x in range(-12,13):
		for z in range(-12,13):
			var p := Vector3(x,0.0,z)
			var a: Variant = eye.islands._height(p+Vector3(way.x,0.0,way.y))
			var b: Variant = eye.islands._height(p-Vector3(way.x,0.0,way.y))
			if a == null or b == null: continue
			if float(a)-float(b) > steepest:
				steepest = float(a)-float(b)
				best = Vector3(x,float(eye.islands._height(p)),z)
	if steepest > 0.2:
		var ridge: Dictionary = eye._fly_air(best+Vector3.UP*2.0)
		var breeze: float = 1.6+1.9*float(atmosphere._air_strength)
		var expected: float = minf(steepest*0.5*breeze*eye.RIDGE_GAIN,eye.RIDGE_MAX)
		check("where the wind blows up a slope, the air lifts in step with it",ridge.island.y > 0.1 and absf(ridge.island.y-expected) < 0.15,"%.2f m/s over a %.2f slope (expected %.2f)" % [ridge.island.y,steepest*0.5,expected])
		var high: Dictionary = eye._fly_air(best+Vector3.UP*40.0)
		check("high over the slope, the ridge lift is gone",high.island.y < 0.05,"%.2f m/s" % high.island.y)
	else:
		print("     (no windward slope on this world; ridge lift unchecked)")
	# A gust front passing lifts it.
	var front: Dictionary = atmosphere.fronts.send(way,atmosphere._air_strength,0.5,1.0)
	var gusted := 0.0
	for i in range(600):
		await frames(1)
		gusted = maxf(gusted,eye._fly_air(Vector3(0.0,6.0,0.0)).island.y)
		if gusted > 0.5: break
	check("a gust front passing lifts the glide",gusted > 0.5,"%.2f m/s" % gusted)
	# Tree crowns lift it over them.
	eye._read_obstacles(true)
	if not eye._crowns.is_empty():
		var c: Vector4 = eye._crowns[0]
		var over: Vector3 = editor.terrain.to_global(Vector3(c.x,c.w-0.5,c.y))
		var ground_there: Variant = eye._fly_ground(over)
		check("a tree's crown is ground to the glide",ground_there != null and (ground_there as Vector2).x >= editor.terrain.to_global(Vector3(c.x,c.w,c.y)).y-0.01,"crown top %.2f" % c.w)
	else:
		print("     (no crowns on this world; crown lift unchecked)")

	# Off again, and V mid-glide.
	eye._feet = eye._clamped(Vector3(0.0,0.0,-(eye.PLATE_REACH-0.4)))
	eye._yaw = 0.0+eye._turn()
	key(KEY_W,true)
	for i in range(120):
		await frames(1)
		if eye.flying: break
	key(KEY_W,false)
	await frames(60)
	check("off another edge, it glides again",eye.flying)
	key(KEY_V,true)
	key(KEY_V,false)
	await frames(60)
	check("V mid-glide steps out",not eye.active and not eye.flying)
	check("stepped out, the figure stands on the plate",absf(eye._feet.x) <= eye.PLATE_REACH and absf(eye._feet.z) <= eye.PLATE_REACH,eye._feet)

	# Claiming a chunk: flown into, it becomes the plate, as its own plain.
	var spot := Vector2(3.0,-2.0)
	var home_height: float = float(editor.data.ground_height(spot))
	await frames(90)
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	eye._yaw = atan2(-1.0,0.0)+eye._turn()
	eye._polar = PI*0.5
	key(KEY_W,true)
	for i in range(120):
		await frames(1)
		if eye.flying: break
	key(KEY_W,false)
	check("off the edge again, to go claiming",eye.flying,"active %s" % eye.active)
	isl = eye.islands
	var target: Vector3 = isl.offsets[0]
	var target_home: Vector3 = isl.homes[0]
	var target_seed: int = isl.seeds[0]
	eye.glide.position = target+Vector3(2.0,25.0,1.0)
	await frames(2)
	for i in range(600):
		if not isl.claiming: break
		await frames(1)
	var at: Vector2 = Vector2(eye.glide.position.x,eye.glide.position.z)
	check("flown into a chunk, it becomes the plate",at.length() < 6.0 and eye.flying,at)
	var plain := NativeTerrainData.new()
	plain.setup(editor.data.source_mesh,editor.data._arrays.duplicate())
	preload("res://scripts/genesis_canvas.gd").shape(plain,target_seed)
	check("the plate is the chunk's own plain",absf(float(editor.data.ground_height(spot))-float(plain.ground_height(spot))) < 0.01 and isl.plate_seed == target_seed)
	var left: int = isl.homes.find(Vector3.ZERO)
	check("the island left is kept, and stands where it was",left >= 0 and isl.built_islands.has("0,0") and isl.offsets[left].is_equal_approx(-target),"%d islands kept" % isl.built_islands.size())
	for i in range(600):
		if left < 0 or isl.lands[left] != null: break
		await frames(1)
	var there: Variant = isl.ground(isl.offsets[left]+editor.terrain.to_global(Vector3(spot.x,0.0,spot.y)))
	var home_y: float = editor.terrain.to_global(Vector3(spot.x,home_height,spot.y)).y+isl.offsets[left].y
	check("it shows its own land",there != null and absf(float(there)-home_y) < 0.05,"%s vs %.2f" % [there,home_y])
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.places_path))
	check("the world's save keeps it",saved.has("islands") and saved.islands.built.size() == 1 and saved.islands.plate_seed == target_seed)
	check("nothing of the plate stays hidden",editor.terrain.layers != 0)

	# Back to the island left: its land comes back, and the fresh plain left
	# untouched goes back to being a chunk.
	eye.glide.position = isl.offsets[left]+Vector3(2.0,25.0,1.0)
	await frames(2)
	for i in range(600):
		if not isl.claiming: break
		await frames(1)
	check("flown back, the island built is the plate again",absf(float(editor.data.ground_height(spot))-home_height) < 0.01 and isl.plate_seed == -1 and isl.built_islands.is_empty(),"%d kept" % isl.built_islands.size())
	check("and the chunk is a fresh chunk again",isl.homes.has(target_home))

	# F comes in to land: it slows, noses down, flares and touches down.
	eye.glide.position = editor.terrain.to_global(Vector3(-6.0,18.0,-6.0))
	eye.glide.heading = atan2(-1.0,-1.0)
	eye.glide.speed = 7.0
	eye.glide.pitch = 0.0
	key(KEY_F,true)
	key(KEY_F,false)
	var slowest := INF
	var landed_in := -1.0
	for i in range(900):
		await frames(1)
		if not eye.flying:
			landed_in = i/60.0
			break
		slowest = minf(slowest,eye.glide.speed)
	check("F comes in to land and touches down",landed_in > 0.0 and landed_in < 12.0 and eye.active,"%.1f s" % landed_in)
	check("it slows to land",slowest < eye.glide.APPROACH_SPEED+0.6,"%.1f m/s" % slowest)
	check("landed on the plate",absf(eye._feet.x) <= eye.PLATE_REACH and absf(eye._feet.z) <= eye.PLATE_REACH,eye._feet)
	finish()

func finish() -> void:
	print("sky glide probe: %s" % ("PASS" if failures.is_empty() else "FAIL %s" % str(failures)))
	quit(0 if failures.is_empty() else 1)
