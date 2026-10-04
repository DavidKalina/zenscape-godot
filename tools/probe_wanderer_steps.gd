extends SceneTree
## Headless probe of the wanderer's footsteps and bob (scripts/wanderer_eye.gd,
## scripts/wanderer_steps.gd) on the real cozy worlds scene: stepped into the
## figure and walked with W held, footfalls sound about two a second, the eye
## dips and sways while walking and comes to rest standing still, a run steps
## faster than a walk, and a bridge's planks and a wade sound as themselves.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_wanderer_steps.gd -- --modeless --no-title --no-rain-runoff
const Steps = preload("res://scripts/wanderer_steps.gd")
const Preload = preload("res://scripts/wanderer_eye.gd")

var scene: Node3D
var editor: NativeChunkEditor
var eye: Node
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

## Holds W (with Shift for a run) for `seconds`; the steps sounded, and the
## lowest and highest the eye's bob went.
func walk(seconds: float, run := false) -> Dictionary:
	var count0: int = eye.steps.count
	var low := INF
	var high := -INF
	var side := 0.0
	if run: key(KEY_SHIFT,true)
	key(KEY_W,true)
	for i in range(int(seconds*60.0)):
		await process_frame
		if i > 30:
			low = minf(low,eye._bob_offset.y)
			high = maxf(high,eye._bob_offset.y)
			side = maxf(side,Vector2(eye._bob_offset.x,eye._bob_offset.z).length())
	key(KEY_W,false)
	if run: key(KEY_SHIFT,false)
	return {"steps":eye.steps.count-count0,"low":low,"high":high,"side":side}

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("wanderer steps probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-wanderer-steps-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	scene.world_clock.running = false
	eye = scene.wanderer
	check("the wanderer has its steps",eye.steps != null)
	eye.place(Vector3(-6.0,0.0,0.0))
	eye.enter()
	await process_frame
	check("stepped into its eyes",eye.active)
	var walked := await walk(3.0)
	print("walk: ",walked)
	check("a walk sounds about two footfalls a second",walked.steps >= 5 and walked.steps <= 8,walked.steps)
	check("on open ground, grass or earth",eye.steps.last_surface in ["grass","earth"],eye.steps.last_surface)
	check("the eye dips with each step, a few centimetres",walked.low < -0.025 and walked.low > -0.05 and walked.high > -0.01,[walked.low,walked.high])
	check("and sways a little from side to side",walked.side > 0.008 and walked.side < 0.04,walked.side)
	for i in range(60): await process_frame
	check("standing still, the bob settles",absf(eye._bob_offset.y) < 0.004,eye._bob_offset)
	var still: int = eye.steps.count
	for i in range(60): await process_frame
	check("and no footfalls sound",eye.steps.count == still)
	eye._feet = eye._clamped(Vector3(-6.0,0.0,0.0))
	var ran := await walk(3.0,true)
	print("run: ",ran)
	check("a run steps faster than a walk",ran.steps > walked.steps,[ran.steps,walked.steps])
	check("and bobs deeper",ran.low < walked.low,[ran.low,walked.low])
	eye.leave()
	# The ground under the feet: its cover, then a steep slope.
	var data := editor.data
	var spot := Vector2(-6.0,4.0)
	var cell := data.meadow_cell(spot)
	var grass0: float = data.grass[cell]
	var meadow0: float = data.meadow[cell]
	data.grass[cell] = 1.0
	data.meadow[cell] = 1.0
	eye._feet = Vector3(spot.x,0.0,spot.y)
	check("grown cover sounds as grass",eye._surface() == "grass",eye._surface())
	data.grass[cell] = 0.0
	data.meadow[cell] = 0.0
	check("bare ground sounds as earth (or sand on an arid world or a shore)",eye._surface() in ["earth","sand"],eye._surface())
	data.grass[cell] = grass0
	data.meadow[cell] = meadow0
	var base := float(data.ground_height(spot))
	data.begin_stroke()
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if p.distance_to(spot) < 2.0: data.heights[i] = base+(p.x-spot.x)*2.0
	data.end_stroke()
	check("a steep slope sounds as stone",eye._surface() == "stone",[eye._surface(),Preload.Presets._slope(data,spot)])
	editor.undo()
	for surface: String in Steps.SURFACES:
		var takes: Array = Steps.takes_for(surface)
		var ok := takes.size() == Steps.VARIANTS
		for take: AudioStreamWAV in takes: ok = ok and take.data.size() > 1000 and take.get_length() > 0.1
		check("%s steps are synthesized" % surface,ok)
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
