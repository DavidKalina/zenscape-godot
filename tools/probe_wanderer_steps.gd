extends SceneTree
## Headless probe of the wanderer's footsteps and bob (scripts/wanderer_eye.gd,
## scripts/wanderer_steps.gd) on the real cozy worlds scene: stepped into the
## figure and run with W held, a footfall sounds at each boot's touchdown
## (scripts/pilot_figure.gd), about six a second, with puffs kicked up
## behind (scripts/pilot_puffs.gd), none standing still; thrown back with S
## it skids, scraping once and spraying puffs; and the ground underfoot
## sounds as itself.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_wanderer_steps.gd -- --modeless --no-title --no-rain-runoff
const Steps = preload("res://scripts/wanderer_steps.gd")
const Preload = preload("res://scripts/wanderer_eye.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

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

## Holds `code` for `seconds`; the steps sounded, the most puffs out, and
## how far the camera's look point trailed the feet (the most, and in the
## first tenth of a second).
func hold(code: Key, seconds: float) -> Dictionary:
	var count0: int = eye.steps.count
	var puffed := 0
	var trail := 0.0
	var early := 0.0
	key(code,true)
	for i in range(int(seconds*60.0)):
		await process_frame
		puffed = maxi(puffed,eye.puffs.alive)
		var off: float = eye.cam_at.distance_to(Vector2(eye.motor.feet.x,eye.motor.feet.z))
		trail = maxf(trail,off)
		if i == 6: early = off
	key(code,false)
	return {"steps":eye.steps.count-count0,"puffs":puffed,"trail":trail,"early":early}

## A plate point with `length` m of dry, level, open land ahead the way the
## camera looks (the way W runs), for a run that never meets a slope.
func open_run(length: float) -> Vector3:
	var data := editor.data
	var ahead: Vector2 = PilotMotor.forward(eye._yaw-eye._turn())
	for ring in range(0,14):
		for k in range(maxi(1,ring*6)):
			var at := Vector2.from_angle(TAU*k/maxf(1.0,ring*6.0))*ring*1.5
			var base: Variant = data.ground_height(at)
			if base == null: continue
			var ok := true
			for d in range(0,int(length)+1):
				var p := at+ahead*d
				var h: Variant = data.ground_height(p)
				if h == null or not data.has_land(p) or absf(float(h)-float(base)) > 0.25*d+0.3 or eye._depth(p) > 0.0 or eye._surface_at(p) == "stone":
					ok = false
					break
			if ok: return Vector3(at.x,float(base),at.y)
	return Vector3(-6.0,0.0,0.0)

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
	var start := open_run(14.0)
	eye.motor.reset(start,eye.motor.facing)
	eye._stand_camera()
	for i in range(5): await process_frame
	var ran := await hold(KEY_W,3.0)
	print("run: ",ran," from ",start)
	check("a run sounds a footfall at each touchdown, about six a second",ran.steps >= 14 and ran.steps <= 20,ran.steps)
	check("on open ground, grass or earth",eye.steps.last_surface in ["grass","earth"],eye.steps.last_surface)
	check("and kicks up puffs behind",ran.puffs >= 2,ran.puffs)
	check("the camera lets the pilot drift ahead, slow to follow, then keeps about a metre behind the run",ran.early > 0.05 and ran.trail > 0.6 and ran.trail < eye.CAM_LAG,[ran.early,ran.trail])
	for i in range(60): await process_frame
	check("and stopping, it eases back in over them",eye.cam_at.distance_to(Vector2(eye.motor.feet.x,eye.motor.feet.z)) < 0.1,eye.cam_at.distance_to(Vector2(eye.motor.feet.x,eye.motor.feet.z)))
	var still: int = eye.steps.count
	for i in range(60): await process_frame
	check("and no footfalls sound",eye.steps.count == still)
	check("and the puffs are gone",eye.puffs.alive == 0,eye.puffs.alive)
	# A skid: a run, then thrown back.
	eye.motor.reset(start,eye.motor.facing)
	key(KEY_W,true)
	for i in range(60): await process_frame
	key(KEY_W,false)
	var slides0: int = eye.steps.slides
	var skid := await hold(KEY_S,0.3)
	print("skid: ",skid)
	check("thrown back at a run it skids, scraping once",eye.steps.slides == slides0+1,eye.steps.slides-slides0)
	check("and sprays puffs",skid.puffs >= 4,skid.puffs)
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
		for take: AudioStreamWAV in takes: ok = ok and take.data.size() > 1000 and take.get_length() > 0.1 and take.get_length() < 0.2
		for take: AudioStreamWAV in Steps.slides_for(surface): ok = ok and take.get_length() > 0.3
		check("%s steps are synthesized, short, and its skid" % surface,ok)
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
