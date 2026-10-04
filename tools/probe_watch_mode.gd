extends SceneTree
## Headless probe of watch mode (scripts/watch_mode.gd, docs/scenic/watch.md).
## Opens the product scene on the Genesis plain, raises a hill, digs a pond
## and stands a small wood, presses O, and lets the director run for WATCH
## seconds at a fixed 60 Hz, once for each of a few seeds. Prints each shot as it begins, then the path:
## the largest frame-to-frame step and change of step (jerk), the least
## ground clearance, and how far the eye strayed from the plate. Then a click
## comes back: the chrome returns, the rig takes the camera where the watch
## left it, and the lens eases home. Nothing is rendered, so how it looks is
## not checked here.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_watch_mode.gd
const WATCH := 110.0
## Each seed is one watch; the director is random, so a few seeds cover more
## shots and places.
const SEEDS := [37,11,23,51]
var scene: Node3D
var editor: NativeChunkEditor
var watch: Node
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func key(code: Key) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event)

func frames(count: int) -> void:
	for i in range(count): await process_frame

func run() -> void:
	create_timer(1200).timeout.connect(func() -> void: push_error("Watch probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = "/private/tmp/zs-watch-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	editor = scene._chunk_editor
	watch = scene.watch
	var data := editor.data
	var basin := Vector2(-3.0,2.0)
	var hill := Vector2(5.0,-4.0)
	data.begin_stroke()
	for _pass in range(6): data.brush(basin,4.2,0.3,"lower",0.0)
	for _pass in range(16): data.brush(hill,4.5,0.5,"raise",0.0)
	var bottom: float = data.ground_height(basin)
	data.add_pond(basin,bottom+0.75)
	for i in range(18):
		var p := basin+Vector2.from_angle(-1.2+float(i)*0.19)*(6.0+0.8*sin(float(i)*2.3))
		data.place("broadleaf" if i%3 else "tree",p,float(i),0.9)
	for i in range(12): data.place("oxeye_daisy",Vector2(-8.0+float(i%4)*0.6,-6.0+float(i/4)*0.6),float(i),1.0)
	data.end_stroke()
	await editor.refresh(self)
	scene._overview()
	await frames(30)
	var fov_before: float = scene.camera.fov

	var began := Time.get_ticks_usec()
	var places: Array = watch.gather_places()
	var kinds := {}
	for place: Dictionary in places: kinds[place.kind] = int(kinds.get(place.kind,0))+1
	print("PLACES ",JSON.stringify({"count":places.size(),"kinds":kinds,"ms":snappedf((Time.get_ticks_usec()-began)/1000.0,0.01)}))
	check("finds the pond and a grove",kinds.has("pond") and kinds.has("grove"),kinds)

	for seed: int in SEEDS:
		watch._rng.seed = seed
		print("SEED ",seed)
		await watch_once(seed,fov_before)
	finish()

## One watch on a fixed seed: press O, run the director for WATCH seconds,
## measure the path, click back.
func watch_once(seed: int, fov_before: float) -> void:
	key(KEY_O)
	await frames(3)
	check("seed %d: " % seed+"O opens watch mode",watch.active)
	if not watch.active:
		return
	check("seed %d: " % seed+"the rig stands aside",not scene.camera_rig.live)
	check("seed %d: " % seed+"the chrome is hidden",watch.chrome_hidden())

	var positions: Array[Vector3] = []
	var reaches: Array[float] = []
	var clearance := INF
	var stray := 0.0
	var shots := 0
	var cost := 0.0
	var cost_at := 0.0
	var count := int(WATCH*60.0)
	for i in range(count):
		var before := Time.get_ticks_usec()
		await process_frame
		var spent := (Time.get_ticks_usec()-before)/1000.0
		if spent > cost and i > 0:
			cost = spent
			cost_at = i/60.0
		var eye: Vector3 = scene.camera.global_position
		positions.append(eye)
		reaches.append(scene.distance)
		var ground: Variant = scene.camera_rig.inspector.ground_y(eye)
		if ground != null: clearance = minf(clearance,eye.y-float(ground))
		var local := editor.terrain.to_local(eye)
		stray = maxf(stray,maxf(absf(local.x),absf(local.z)))
		if watch.taken.size() != shots:
			shots = watch.taken.size()
			var shot: Dictionary = watch.shot
			print("SHOT ",JSON.stringify({"at_s":snappedf(i/60.0,0.1),"kind":shot.kind,"place":shot.get("place",""),"length_s":snappedf(float(shot.length),0.1),
				"distance":snappedf(exp(shot.distance.x),0.1),"polar":snappedf(shot.polar.x,0.01),"fov":shot.fov}))
	var step := 0.0
	var jerk := 0.0
	var pace := 0.0
	var pace_at := 0.0
	for i in range(1,positions.size()):
		step = maxf(step,positions[i].distance_to(positions[i-1]))
		# How fast the picture moves: the eye's speed over its reach to the pivot.
		var now := positions[i].distance_to(positions[i-1])*60.0/maxf(reaches[i],0.5)
		if now > pace:
			pace = now
			pace_at = i/60.0
		if i > 1: jerk = maxf(jerk,(positions[i]-positions[i-1]).distance_to(positions[i-1]-positions[i-2]))
	var seen := {}
	for kind: String in watch.taken: seen[kind] = true
	print("PATH ",JSON.stringify({"seconds":WATCH,"shots":watch.taken,"max_step_m":snappedf(step,0.0001),"max_jerk_m":snappedf(jerk,0.0001),"max_pace":snappedf(pace,0.001),"pace_at_s":snappedf(pace_at,0.1),"slowest_at_s":snappedf(cost_at,0.1),
		"clearance_min":snappedf(clearance,0.01),"stray_local":snappedf(stray,0.1),"slowest_frame_ms":snappedf(cost,0.1)}))
	check("seed %d: " % seed+"several shots",watch.taken.size() >= 4,watch.taken.size())
	check("seed %d: " % seed+"three kinds of shot",seen.size() >= 3,seen.keys())
	check("seed %d: " % seed+"never the same kind twice running",_no_repeats(watch.taken),watch.taken)
	# Pace: the eye's speed over its distance to the pivot, per second; for a
	# dolly it is how fast the view's depth grows. The director caps it near
	# 0.24 (watch_mode.gd PACE). 0.2 m a frame is 12 m/s; a change of 4 mm a
	# frame is 14 m/s².
	check("seed %d: " % seed+"moves calmly",pace < 0.3 and step < 0.2,{"pace":snappedf(pace,0.001),"step_m":snappedf(step,0.0001)})
	check("seed %d: " % seed+"never jerks",jerk < 0.004,snappedf(jerk,0.0001))
	check("seed %d: " % seed+"stays over the ground",clearance > 0.5,snappedf(clearance,0.01))
	check("seed %d: " % seed+"still in watch mode",watch.active)

	# A click comes back: the chrome returns and the rig takes the camera as it is.
	var eye_before: Vector3 = scene.camera.global_position
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(720,450)
	click.pressed = true
	root.push_input(click)
	await frames(45)
	check("seed %d: " % seed+"a click comes back",not watch.active)
	check("seed %d: " % seed+"the chrome is back",not watch.chrome_hidden())
	check("seed %d: " % seed+"the rig takes over",scene.camera_rig.live)
	check("seed %d: " % seed+"the camera stays where it was",scene.camera.global_position.distance_to(eye_before) < 0.5,snappedf(scene.camera.global_position.distance_to(eye_before),0.01))
	check("seed %d: " % seed+"the lens is home",is_equal_approx(scene.camera.fov,fov_before),scene.camera.fov)
	await frames(30)

func _no_repeats(kinds: Array[String]) -> bool:
	for i in range(1,kinds.size()):
		if kinds[i] == kinds[i-1]: return false
	return true

func finish() -> void:
	print("FAILURES ",failures.size()," ",failures)
	quit(1 if not failures.is_empty() else 0)
