extends SceneTree
## Headless probe: can the watering can fill a crater to its brim? A bowl
## CRATER_RADIUS m across its rim and CRATER_DEPTH m deep is pressed into the
## new plain, then the can is pressed at its middle and held (through the
## editor's own can path, as a press would be). Every 5 s it prints the
## water's volume, how full the crater is (its surface over the rim's level),
## what the can is pouring (its spout's tap and the gush laid level, the
## lift) and how long one `fill_level` takes. --crater-radius=R
## --crater-depth=D --seconds=S size the crater and the hold. --rate-only=R --radius=r skips the can and
## opens a tap of R m³/s over r m instead, to compare the sim at a rate.
##   perl -e 'alarm 300; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
##     --script res://tools/probe_can_fill.gd -- --no-title --no-rain-runoff
## Prints JSON lines and PASS/FAIL.

const CRATER := Vector2(2.0,1.0)
var CRATER_RADIUS := 6.0
var CRATER_DEPTH := 2.2
var SECONDS := 60.0
var scene: Node3D
var editor: NativeChunkEditor
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, what: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+what)
	if not ok: failures += 1

func screen_of(point: Vector2) -> Vector2:
	var data := editor.data
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(point.x,float(data.sample(point,data.heights)),point.y)))

func mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

## How full the crater stands, 0..1: the water's mean height over the crater's
## floor cells (those at least half its depth down), against the rim's level.
func fullness(flow: RefCounted, rim: float) -> float:
	var data := editor.data
	var total := 0.0
	var count := 0
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if p.distance_to(CRATER) > CRATER_RADIUS*0.5: continue
		var ground := float(data.heights[i])
		var room := rim-ground
		if room < CRATER_DEPTH*0.5: continue
		total += clampf(flow.depth_at(p)/room,0.0,1.0)
		count += 1
	return total/maxf(count,1)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crater-radius="): CRATER_RADIUS = float(arg.trim_prefix("--crater-radius="))
		if arg.begins_with("--crater-depth="): CRATER_DEPTH = float(arg.trim_prefix("--crater-depth="))
		if arg.begins_with("--seconds="): SECONDS = float(arg.trim_prefix("--seconds="))
	create_timer(SECONDS*3.0+160.0).timeout.connect(func() -> void: push_error("Can fill probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-can-fill-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	scene.set_building(true)
	editor = scene._chunk_editor
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	while editor.flow == null or not editor.flow.ready: await process_frame
	var flow: RefCounted = editor.flow
	flow.runoff = preload("res://scripts/rain_runoff.gd").new()
	var rim := float(editor.data.sample(CRATER+Vector2(CRATER_RADIUS+1.0,0.0),editor.data.heights))
	var dug := editor.data.heights.duplicate()
	var room := 0.0
	for i in range(dug.size()):
		var d: float = (editor.data.points[i] as Vector2).distance_to(CRATER)
		dug[i] -= CRATER_DEPTH*(1.0-smoothstep(CRATER_RADIUS*0.4,CRATER_RADIUS,d))
	editor.data.heights = dug
	await editor.refresh(self)
	for i in range(dug.size()):
		if (editor.data.points[i] as Vector2).distance_to(CRATER) < CRATER_RADIUS: room += maxf(rim-dug[i],0.0)
	# The plate's points are about 0.6 m apart: room per point is about a 0.36 m² cell.
	var spacing: float = sqrt(784.0/dug.size())
	room *= spacing*spacing
	print(JSON.stringify({"crater":{"rim":snappedf(rim,0.01),"room_m3":snappedf(room,1.0)}}))
	var rate_only := -1.0
	var radius := 0.6
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rate-only="): rate_only = float(arg.trim_prefix("--rate-only="))
		if arg.begins_with("--radius="): radius = float(arg.trim_prefix("--radius="))
	var g0: PackedFloat32Array = flow.grounds()
	var h0: Dictionary = flow.hollow(CRATER,g0)
	var lowest := INF
	for c in (h0.cells as PackedInt32Array): lowest = minf(lowest,g0[c])
	print(JSON.stringify({"hollow":{"sill":snappedf(float(h0.sill),0.01),"cells":(h0.cells as PackedInt32Array).size(),"floor":snappedf(lowest,0.01),"room_m3":snappedf(flow.room(CRATER),1.0)}}))
	# Full is to the hollow's sill, where it spills: the plain slopes, and the
	# rim sampled on one side can stand above it.
	rim = float(h0.sill)
	var at := screen_of(CRATER)
	if rate_only > 0.0: flow.taps["probe"] = [CRATER.x,CRATER.y,radius,rate_only]
	else:
		mouse(at,true)
		check(editor.can_in_hand(at,1.0,false),"the can takes a press in the crater")
	var t := 0.0
	var full_at := INF
	while t < SECONDS:
		for i in range(120): await process_frame
		t += 2.0
		var full := fullness(flow,rim)
		if full >= 0.95 and full_at == INF: full_at = t
		var tap: Array = flow.taps.get("can",flow.taps.get("probe",[0,0,0,0]))
		var lift: Array = flow.lifts.get("can",[0,0,0])
		var began := Time.get_ticks_usec()
		var ground: PackedFloat32Array = flow.grounds()
		flow.fill_level(flow.hollow(CRATER,ground),1.0,ground,flow.depths())
		print(JSON.stringify({"t":t,"volume":snappedf(flow.volume(),0.1),"full":snappedf(full,0.01),"tap_rate":snappedf(float(tap[3]),0.01),"lift_rate":snappedf(float(lift[2]),0.01),"tap_radius":snappedf(float(tap[2]),0.01),"max_depth":snappedf(flow.depth_at(CRATER),0.01),"fill_usec":Time.get_ticks_usec()-began}))
		if full >= 0.99: break
	if rate_only <= 0.0:
		editor.can.release()
		mouse(at,false)
	flow.taps.erase("probe")
	print(JSON.stringify({"full_at_s":full_at}))
	check(full_at <= 20.0,"the crater (%d m³) stands 95%% full within 20 s of holding the can (%s s)" % [int(room),str(full_at)])
	print("Failures: %d" % failures)
	quit(1 if failures > 0 else 0)
