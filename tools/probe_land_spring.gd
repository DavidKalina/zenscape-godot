extends SceneTree
## Headless probe of the land spring (scripts/land_spring.gd,
## docs/scenic/modeless-spring.md) on the real cozy worlds scene. Pulls down
## and lets go (a mountain, small and big), pulls up (a basin), tiny and
## returned pulls, and undo, and prints what the land did: heights at the
## spot, the spring's overshoot and ring-down, and the longest frames.
## With --modeless (after the `--`) it runs the spring; without it, it proves
## the spring is absent and the brush still paints.
##   perl -e 'alarm 300; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
##     --script res://tools/probe_land_spring.gd -- --modeless
## Frame gaps are CPU main-loop intervals under the dummy renderer, so they
## show the cost of the work, not of drawing it.

var scene: Node3D
var editor: NativeChunkEditor
var spring: Node
var failures := 0
var at := Vector2(-2.0,1.0)
var frames: Array[float] = []
var _last := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func tick() -> void:
	await process_frame
	var now := Time.get_ticks_usec()
	frames.append((now-_last)/1000.0)
	_last = now

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func settled() -> void:
	var quiet := 0
	while quiet < 20:
		await tick()
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or (spring != null and spring.state != 0)
		quiet = 0 if busy else quiet+1

## Press at `at`, pull `amount` (of the cap, down positive) over `frames_held`
## frames, then let go and follow the centre height until the spring lands.
func spring_at(amount: float, frames_held := 30, wait_land := true) -> Dictionary:
	var span: float = root.size.y*spring.PULL_SCREEN
	var start := screen(at)
	frames.clear()
	_last = Time.get_ticks_usec()
	var t0 := Time.get_ticks_usec()
	var pressed: bool = spring.press(start)
	var press_ms := (Time.get_ticks_usec()-t0)/1000.0
	var hand: Node = scene.get("god_hand")
	var held: Array = []
	for f in range(frames_held):
		spring.pull(start+Vector2(0.0,amount*span*minf(1.0,(f+1)/12.0)))
		await tick()
		if f == frames_held-1: held = [height(at),hand.reach_gesture if hand != null else "-"]
	var pull_frames := frames.duplicate()
	var pull_max: float = pull_frames.max() if not pull_frames.is_empty() else 0.0
	frames.clear()
	t0 = Time.get_ticks_usec()
	spring.release()
	var release_ms := (Time.get_ticks_usec()-t0)/1000.0
	var series: Array = [height(at)]
	var hand_after: String = hand.reach_gesture if hand != null else "-"
	if wait_land:
		for f in range(400):
			await tick()
			series.append(height(at))
			if spring.state == 0: break
	var rest: float = series.back()
	var release_max: float = frames.max() if not frames.is_empty() else 0.0
	return {"pressed":pressed,"press_ms":press_ms,"release_ms":release_ms,"held_height":held[0] if held.size() > 0 else 0.0,"held_gesture":held[1] if held.size() > 1 else "",
		"hand_after":hand_after,"series":series,"rest":rest,"peak":series.max(),"low":series.min(),"pull_max_ms":pull_max,"release_max_ms":release_max,
		"peak_x":spring.spring_peak,"refreshes":spring.refreshes}

func heights_equal(a: PackedFloat32Array) -> bool:
	return editor.data.heights == a

func run() -> void:
	create_timer(290).timeout.connect(func() -> void: push_error("Spring probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-spring-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	scene.set_building(true)
	editor = scene._chunk_editor
	spring = scene.get("land_spring")
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	editor.select_tool("land")
	editor.select_brush("land")
	await create_timer(1.0).timeout
	var modeless: bool = "--modeless" in OS.get_cmdline_user_args()
	if not modeless:
		await baseline()
	else:
		await modeless_run()
	print("FAILURES ",failures)
	scene.queue_free()
	for _f in range(3): await process_frame
	quit(1 if failures > 0 else 0)

## Without --modeless: no spring, and a left press still paints land.
func baseline() -> void:
	check(spring == null,"no land spring without --modeless")
	editor.set_process(false)
	var before := editor.data.heights.duplicate()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen(at)
	var took := editor.handle_input(press)
	for _i in range(20):
		editor._land_step(at,1.0/30.0)
		await process_frame
	editor.finish_stroke()
	await settled()
	check(took and editor.data.heights != before,"the brush still paints under a plain press")
	print("BASELINE raise at spot ",snappedf(height(at)-float(editor.data.sample(at,before)),0.01))

func modeless_run() -> void:
	check(spring != null,"land spring exists under --modeless")
	if spring == null: return
	var data := editor.data
	var base := data.heights.duplicate()
	var undo_before: int = data._undo.size()
	var ground := height(at)
	print("points ",data.points.size()," ground at spot ",snappedf(ground,0.01)," hand ",scene.get("god_hand") != null)

	# A press that misses the land does nothing.
	check(not spring.press(Vector2(-50,-50)),"a press off the land is ignored")
	check(spring.state == 0,"and leaves the spring idle")

	# Tiny pulls, a click, a returned pull.
	for amount in [0.0,0.02,0.08]:
		await spring_at(amount,10)
		await settled()
		check(heights_equal(base),"a pull of %.2f of the cap changes nothing" % amount)
	var returned := await spring_at(0.0,1,false)
	spring.state = 0
	await settled()
	# Pull down, come back to the start, let go.
	var start := screen(at)
	var span: float = root.size.y*spring.PULL_SCREEN
	spring.press(start)
	for f in range(20):
		spring.pull(start+Vector2(0,0.7*span*sin(PI*(f+1)/20.0)))
		await tick()
	var mid: float = height(at)
	for f in range(6):
		spring.pull(start)
		await tick()
	spring.release()
	for f in range(200):
		await tick()
		if spring.state == 0: break
	await settled()
	check(heights_equal(base),"a pull that returned to the start changes nothing")
	check(data._undo.size() == undo_before,"and adds no undo step")

	# Mountains: small and big.
	var small := await spring_at(0.45)
	await settled()
	var small_final := height(at)-ground
	print("SMALL ",JSON.stringify({"held":snappedf(small.held_height-ground,0.01),"gesture":small.held_gesture,"after_release":small.hand_after,"peak":snappedf(small.peak-ground,0.01),"rest":snappedf(small.rest-ground,0.01),"final":snappedf(small_final,0.01),"peak_x":snappedf(small.peak_x,0.01),"press_ms":snappedf(small.press_ms,0.1),"release_ms":snappedf(small.release_ms,0.1),"pull_max_ms":snappedf(small.pull_max_ms,0.1),"release_max_ms":snappedf(small.release_max_ms,0.1),"refreshes":small.refreshes}))
	check(small_final > 1.0,"a pull down then release raises land at the spot (%.2f m)" % small_final)
	check(data._undo.size() == undo_before+1,"one undo step for the whole spring")
	check(small.held_gesture == "pinch","the hand pinches while pulling down")
	check(small.hand_after == "","and lets go on release")
	editor.undo()
	await settled()
	check(heights_equal(base),"one undo restores the heights exactly (small mountain)")
	check(data._undo.size() == undo_before,"undo removed the step")

	var big := await spring_at(1.0)
	await settled()
	var big_final := height(at)-ground
	print("BIG ",JSON.stringify({"held":snappedf(big.held_height-ground,0.01),"peak":snappedf(big.peak-ground,0.01),"rest":snappedf(big.rest-ground,0.01),"final":snappedf(big_final,0.01),"peak_x":snappedf(big.peak_x,0.01),"press_ms":snappedf(big.press_ms,0.1),"release_ms":snappedf(big.release_ms,0.1),"pull_max_ms":snappedf(big.pull_max_ms,0.1),"release_max_ms":snappedf(big.release_max_ms,0.1),"refreshes":big.refreshes}))
	check(big_final > small_final+1.0,"a bigger pull gives a bigger mountain (%.2f > %.2f m)" % [big_final,small_final])
	var rest: float = big.rest-ground
	check(big.peak-ground > rest*1.1 and big.peak_x > 1.15,"the height overshoots its rest (peak %.2f vs %.2f m, x %.2f)" % [big.peak-ground,rest,big.peak_x])
	var tail: Array = big.series.slice(big.series.size()-6)
	check(tail.max()-tail.min() < 0.05,"then settles (last frames within %.3f m)" % (tail.max()-tail.min()))
	var dips := 0
	var series: Array = big.series
	for k in range(1,series.size()-1):
		if series[k] > series[k-1] and series[k] >= series[k+1]: dips += 1
	check(dips >= 1,"it rings: %d local peak(s) in the series" % dips)
	editor.undo()
	await settled()
	check(heights_equal(base),"one undo restores the heights exactly (big mountain)")

	# A basin.
	var basin := await spring_at(-0.85)
	await settled()
	var basin_final := height(at)-ground
	print("BASIN ",JSON.stringify({"held":snappedf(basin.held_height-ground,0.01),"gesture":basin.held_gesture,"low":snappedf(basin.low-ground,0.01),"rest":snappedf(basin.rest-ground,0.01),"final":snappedf(basin_final,0.01),"peak_x":snappedf(basin.peak_x,0.01),"press_ms":snappedf(basin.press_ms,0.1),"release_ms":snappedf(basin.release_ms,0.1),"pull_max_ms":snappedf(basin.pull_max_ms,0.1),"release_max_ms":snappedf(basin.release_max_ms,0.1)}))
	check(basin_final < -0.4,"a pull up makes a basin lower than before (%.2f m)" % basin_final)
	check(basin.held_gesture == "press","the hand presses while pulling up")
	check(basin.low-ground < basin_final-0.05,"the basin overshoots deeper before it settles (%.2f m below rest)" % (basin_final-(basin.low-ground)))
	var fetch := data.pond_fetch(at,-0.15)
	var holds := true
	for d in fetch: holds = holds and d > 0.3 and d < 20.0
	check(holds,"the basin holds water (fetch at pond level %s m)" % str(fetch))
	var pond: Dictionary = {"x":at.x,"z":at.y,"level":-0.2}
	check(not data.pond_surface(pond).is_empty(),"a pond surface finds the basin")
	check(data._undo.size() == undo_before+1,"one undo step for the basin")
	editor.undo()
	await settled()
	check(heights_equal(base),"one undo restores the heights exactly (basin)")

	# The modeless input's land signals (scripts/hand_reach.gd) drive it.
	editor.pointer_override = null
	var reach: Node = scene.hand_reach
	var start_at := screen(at)
	reach.land_pressed.emit(start_at)
	check(spring.state == 1,"the land press signal starts a pull")
	reach.land_dragged.emit(start_at+Vector2(0,120),Vector2(0,120))
	check(spring.pulled > 0.3,"and follows the pointer's pull (%.2f)" % spring.pulled)
	reach.land_released.emit(start_at+Vector2(0,120))
	check(spring.state == 2,"and springs on release")
	spring.land_now()
	await settled()
	check(height(at) > ground+0.5,"land_now lands a springing mountain at once")
	editor.undo()
	await settled()
	check(heights_equal(base),"and one undo restores it")
