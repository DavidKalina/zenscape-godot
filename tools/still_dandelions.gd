extends SceneTree
## Stills of the dandelion's round (docs/scenic/dandelions.md,
## scripts/dandelion_seeds.gd): a flattened patch of the plain with a drift of
## seed clocks and dandelions. "round" sets the clocks in bands across the
## drift, one phase each (whole, thinned, bare, gold, fluffing out); "gust"
## sends a wind-tool lane through it and takes the cloud of seed
## at GUST_AT seconds; "after" is the stripped patch a moment later; "far"
## the same from the diorama camera. Saves captures/dandelions/<tag>-<view>.png.
## Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/still_dandelions.gd -- --modeless --no-title [--tag=name]

const Seeds := preload("res://scripts/dandelion_seeds.gd")
const Emergence := preload("res://scripts/emergence.gd")
var scene: Node3D
var editor: NativeChunkEditor
const CENTRE := Vector2(2.0,-1.0)
const MOOD := "Alpine daylight"
## distance, polar, yaw
const CLOSE := Vector3(3.4,1.12,0.6)
const FAR := Vector3(14.0,1.0,0.6)
const GUST_AT := [0.6,1.1,1.8,3.5]

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		scene._atmosphere._air_strength = 0.5
		if absf(scene._atmosphere.fog_amount-0.04) > 0.01:
			scene._atmosphere.set_fog(0.04)
			scene._atmosphere.set_haze(0.06)

func save(out: String, tag: String, view: String) -> void:
	if DisplayServer.get_name() == "headless": return
	root.get_texture().get_image().save_png(out.path_join("%s-%s.png" % [tag,view]))
	print("DANDELIONS still ",tag,"-",view," seeds in air ",editor.dandelions.seeds_in_air()," stripped ",editor.dandelions.stripped," taken ",editor.dandelions.taken.size()," dearest step ",editor.dandelions.most_step_usec," us")
	editor.dandelions.most_step_usec = 0

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: push_error("dandelion still timed out"); quit(2))
	var tag := "now"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="): tag = arg.trim_prefix("--tag=")
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-dandelions-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.size = Vector2i(1280,720)
	editor = scene._chunk_editor
	# The round's stamps are times on Emergence's clock; give the stills room
	# to set phases in the past.
	Emergence.time += 300.0
	scene.world_clock.running = false
	scene.apply_scene_mood(MOOD)
	for overlay: Node in scene.find_children("*","CanvasLayer",true,false): overlay.visible = false
	var data := editor.data
	var near := PackedFloat32Array()
	for i in range(data.points.size()):
		if data.points[i].distance_to(CENTRE) < 6.0: near.append(data.heights[i])
	near.sort()
	var level: float = near[near.size()/2]
	data.begin_stroke()
	var heights := data.heights.duplicate()
	for i in range(data.points.size()):
		heights[i] = lerpf(heights[i],level,1.0-smoothstep(6.0,8.0,data.points[i].distance_to(CENTRE)))
	data.heights = heights
	data.end_stroke()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	data.begin_stroke()
	for n in range(140):
		var p := CENTRE+Vector2(rng.randf_range(-1.6,1.6),rng.randf_range(-1.0,1.0))
		data.place("dandelion_clock" if rng.randf() < 0.75 else "dandelion",p,rng.randf()*TAU,rng.randf_range(0.9,1.15))
	for n in range(70):
		var p := CENTRE+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.3,4.0)
		data.place("grass_tuft",p,rng.randf()*TAU,rng.randf_range(0.7,1.1))
	data.end_stroke()
	await editor.refresh(self)
	await frames(60)
	Input.warp_mouse(Vector2(4,4))
	var out := ProjectSettings.globalize_path("res://captures/dandelions")
	DirAccess.make_dir_recursive_absolute(out)
	var seeds: Node3D = editor.dandelions
	seeds.spreading = false
	var look := Vector3(CENTRE.x,level+0.25,CENTRE.y)
	scene.camera_rig.glide_to(editor.terrain.to_global(look),CLOSE.z,CLOSE.y,CLOSE.x)
	await frames(150)
	save(out,tag,"whole")
	# The round in bands across the drift (plate x), oldest phase last.
	var now: float = Emergence.time
	for id: int in seeds.clocks:
		var head: Vector3 = seeds.head_of(seeds.clocks[id])
		var band := clampi(int((head.x-(CENTRE.x-1.6))/3.2*5.0),0,4)
		var state := 1.0
		match band:
			1: state = 1.0+0.5
			2: state = 4.0+now
			3: state = 4.0+now-Seeds.BARE-3.0
			4: state = 4.0+now-(Seeds.BARE+Seeds.GOLD+Seeds.CLOSE+Seeds.FLUFF*0.5)
		editor.content.set_flower_state(id,state)
	await frames(90)
	save(out,tag,"round")
	# Every clock in one phase: bare, then gold.
	for phase: Array in [["bare",4.0+now],["gold",4.0+now-Seeds.BARE-3.0]]:
		for id: int in seeds.clocks: editor.content.set_flower_state(id,float(phase[1]))
		await frames(60)
		save(out,tag,str(phase[0]))
	for id: int in seeds.clocks: editor.content.set_flower_state(id,1.0)
	seeds.restored()
	await frames(30)
	# A gust from the sky across the drift.
	editor._make_gust()
	seeds.gust = editor.gust
	var heading := Vector2(1.0,0.25).normalized()
	var from := CENTRE-heading*5.0
	editor.gust.send_lane(Vector3(from.x,level,from.y),heading,0.9,2.5)
	var start := Time.get_ticks_msec()
	for at: float in GUST_AT:
		while (Time.get_ticks_msec()-start)/1000.0 < at: await frames(1)
		save(out,tag,"gust-%.1f" % at)
	if "--bench" in OS.get_cmdline_user_args():
		var plate: Node3D = editor.terrain
		var t0 := Time.get_ticks_usec()
		for k in range(200): preload("res://scripts/pollen_wind.gd").at(scene,plate,Vector2(k*0.1,1.0))
		var t1 := Time.get_ticks_usec()
		for k in range(200): editor.gust.blow_at(Vector2(k*0.1,1.0))
		var t2 := Time.get_ticks_usec()
		for k in range(200): editor.data.ground_height(Vector2(k*0.05,1.0))
		var t3 := Time.get_ticks_usec()
		print("DANDELIONS bench per call: air %.1f us, blow %.1f us, ground %.1f us" % [(t1-t0)/200.0,(t2-t1)/200.0,(t3-t2)/200.0])
	scene.camera_rig.glide_to(editor.terrain.to_global(look),FAR.z,FAR.y,FAR.x)
	await frames(120)
	save(out,tag,"far")
	quit(0)
