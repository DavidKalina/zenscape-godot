extends SceneTree
## Rendered film: a lake made by hand. The Crater is pulled down as deep as
## it goes (--big: at the biggest size pip, its rim out near the plate's
## edges) in the new plain, the watering can is held in it (through the editor's own can
## path, as a press is) until it brims, and then reeds and redwoods are set
## round its shore and it steeps to tea. Frames go to --out (default
## /tmp/zs-lake-film) as PNGs every FRAME_EVERY frames, with stills named
## for each beat. Windowed: run it only when a film is wanted.
##   Godot --fixed-fps 60 --path . --script res://tools/film_lake.gd -- --no-title --no-rain-runoff

var CRATER := Vector2(1.0,0.5)
var RADIUS := 7.0
var DEPTH := 6.0
const FRAME_EVERY := 4
var scene: Node3D
var editor: NativeChunkEditor
var out := "/tmp/zs-lake-film"
var frame := 0
var shot := 0

func _initialize() -> void: run.call_deferred()

func mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func screen_of(point: Vector2) -> Vector2:
	var data := editor.data
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(point.x,float(data.sample(point,data.heights)),point.y)))

## Runs `frames` frames, saving every FRAME_EVERY-th, the camera turning slowly.
func roll(frames: int) -> void:
	for i in frames:
		scene.yaw += 0.0012
		scene._update_camera()
		await process_frame
		frame += 1
		if frame%FRAME_EVERY == 0:
			root.get_texture().get_image().save_png("%s/frame_%05d.png" % [out,shot])
			shot += 1

func still(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out,name])

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		# --big: the Crater at its biggest pip (×1.5), in the plate's middle,
		# its rim out near the edges.
		if arg == "--big":
			CRATER = Vector2.ZERO
			RADIUS = 10.5
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-lake-film-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	editor = scene._chunk_editor
	# The game as played: the hand, the tool roll and the case, not the old
	# build bar. The pointer is pinned where the film points, whatever the
	# real cursor over the window does.
	if not editor.active: scene.set_building(false)
	var clay: Node = scene.get("land_clay")
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	while editor.flow == null or not editor.flow.ready: await process_frame
	var flow: RefCounted = editor.flow
	flow.runoff = preload("res://scripts/rain_runoff.gd").new()
	scene.set("_auto_orbit",false)
	scene.target = editor.terrain.to_global(Vector3(CRATER.x,-1.0,CRATER.y))
	# Steep enough that the crater's floor shows over its near rim: lower,
	# a press at its middle lands on the rim.
	scene.distance = 30.0 if RADIUS < 9.0 else 40.0
	scene.polar = 0.55
	scene.yaw = 0.6
	scene._update_camera()
	await roll(30)
	await still("0-plain")
	# The Crater is taken from the roll and pulled down as a hand does
	# (LandClay press, pull, release), so the land is the clay's own: dug
	# behind its back, its putting down wrote the plain back under the lake.
	clay.set_tool("crater")
	clay.size_scale = 1.5 if RADIUS > 9.0 else 1.0
	var spot := screen_of(CRATER)
	editor.pointer_override = spot
	clay.press(spot)
	for k in 90:
		var down := spot+Vector2(0.0,10.0*(k+1))
		editor.pointer_override = down
		clay.pull(down)
		await roll(1)
	clay.release()
	editor.pointer_override = spot
	print(JSON.stringify({"crater_lift":snappedf(float(clay.lift),0.01),"floor":snappedf(float(editor.data.sample(CRATER,editor.data.heights)),0.01)}))
	await roll(40)
	await still("1-crater")
	print(JSON.stringify({"room_m3":snappedf(flow.room(CRATER),1.0)}))
	# The can, held still in the middle of the crater.
	clay.set_tool("can")
	var at := screen_of(CRATER)
	editor.pointer_override = at
	await roll(20)
	mouse(at,true)
	print(JSON.stringify({"can_took":editor.can_in_hand(at,1.0,false)}))
	var t := 0.0
	var brimmed_at := -1.0
	while t < 40.0:
		await roll(60)
		t += 1.0
		editor.pointer_override = screen_of(CRATER)
		var lift: Array = flow.lifts.get("can",[0,0,0])
		print(JSON.stringify({"t":t,"landing":[snappedf(editor.can.landing.x,0.1),snappedf(editor.can.landing.y,0.1)],"pointer":str(editor.pointer_hit),"volume":snappedf(flow.volume(),1.0),"depth":snappedf(flow.depth_at(CRATER),0.01),"lift":snappedf(float(lift[2]),0.1)}))
		if t == 5.0: await still("2-filling")
		if brimmed_at < 0.0 and editor.can._brimmed: brimmed_at = t
		if brimmed_at > 0.0 and t >= brimmed_at+2.0: break
	editor.can.release()
	mouse(at,false)
	clay.put_tool_down()
	# --diagnose: what the water's mesh says at the lake's middle, a line a
	# half second, through the moment it has gone wrong before.
	if "--diagnose" in OS.get_cmdline_user_args():
		for k in 24:
			await roll(30)
			print(JSON.stringify(_diagnose(flow,k*0.5)))
	await roll(180)
	await still("3-full")
	# Reeds and redwoods round the shore: the lake steeps to tea.
	# Round the water's own edge (the pool's reach from its middle), where a
	# hand plants a shore: the crater's size is the pull's, not RADIUS.
	var pools: Array = flow.pools()
	var edge: float = sqrt(float(pools[0].area)/PI) if not pools.is_empty() else RADIUS
	print(JSON.stringify({"water_radius":snappedf(edge,0.1)}))
	var shore := 0
	for k in 28:
		var around := CRATER+Vector2.from_angle(k*TAU/28.0)*(edge+(0.4 if k%2 == 0 else 2.6))
		if editor.data.place("reeds" if k%2 == 0 else "redwood",around,randf()*TAU,1.0) >= 0: shore += 1
	for k in 6:
		var near := CRATER+Vector2.from_angle(k*TAU/6.0+0.3)*(edge-0.3)
		if editor.data.place("reeds",near,randf()*TAU,1.1) >= 0: shore += 1
	await editor.refresh(self)
	print(JSON.stringify({"shore_things":shore}))
	# --tea-now: the lake takes its tea at once (as a load does), for looking
	# at the colour without the minute's steeping.
	var steeping := 60
	if "--tea-now" in OS.get_cmdline_user_args():
		await roll(60)
		editor.flow_view.steep(flow.pools(),editor.data.objects,1.0,true)
		print(JSON.stringify({"steep_s":0,"tea":snappedf(editor.flow_view.tea.tea_at(CRATER),0.01)}))
		steeping = 4
	for s in steeping:
		await roll(60)
		if s%10 == 0: print(JSON.stringify({"steep_s":s,"tea":snappedf(editor.flow_view.tea.tea_at(CRATER),0.01)}))
	await still("4-tea")
	print("Film done: %d frames in %s" % [shot,out])
	quit(0)

func _diagnose(flow: RefCounted, t: float) -> Dictionary:
	var view: Node3D = editor.flow_view
	var vertices: PackedVector3Array = view._still_vertices
	var indices: PackedInt32Array = view._still_indices
	var nearest := -1
	var best := INF
	for v in vertices.size():
		var d := Vector2(vertices[v].x,vertices[v].z).distance_to(CRATER)
		if d < best:
			best = d
			nearest = v
	var at_k := indices.find(nearest)
	var moving: ArrayMesh = view.moving.mesh
	var moving_count := moving.surface_get_array_len(0) if moving.get_surface_count() > 0 else 0
	var stats: Dictionary = flow.stats()
	var pools: Array = flow.pools()
	var material: ShaderMaterial = view.still.material_override
	return {"t":t,"still_vertices":vertices.size(),"still_indices":indices.size(),"calm":view._calm,
		"middle_index_pos":at_k,"middle_in_calm":at_k >= 0 and at_k < view._calm,"middle_y":snappedf(vertices[nearest].y,0.01) if nearest >= 0 else null,
		"moving_vertices":moving_count,"settled":view._settled,"pools":pools.size(),"pool_area":snappedf(float(pools[0].area),1.0) if not pools.is_empty() else 0.0,
		"depth_mid":snappedf(flow.depth_at(CRATER),0.01),"stats":stats.keys(),"wind":editor.flow.wind != null,
		"reflect_on":view.reflection._view_on if view.reflection != null else false,
		"growth_water":snappedf(float(scene._growth.water),0.01),"tea":snappedf(view.tea.tea_at(CRATER),0.01)}
