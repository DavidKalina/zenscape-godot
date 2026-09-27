extends SceneTree
## Headless probe of the water ball (scripts/water_ball.gd, docs/scenic/water-brush.md
## "Water ball") on the Genesis plain, through the real input path: a mouse
## press with water in hand, the editor's own _process following the pointer
## (pointer_override) while the ball fills, then a release. Each drop reports
## what the land made of it (NativeChunkEditor `ball_settled`: waterfall,
## stream, lake, pond), its volume and fish, main-loop frame gaps while held
## and from release until the pour closed, the pour's undo steps, and whether
## one undo takes the whole drop back. Then the fish: how many of the ball's
## fish LandLife placed and how many have arrived.
##   -- --hold=1.5 --big=6.0 --fish-wait=10
## Drops: "hollow" on the plain, "big" (held --big s), "full" (held 12 s, past
## the cap) on the plain, and "peak"
## on the top of an alpine peak raised first, so the stream and waterfall
## paths run. Frame gaps are CPU main-loop intervals under the dummy renderer.
var scene: Node3D
var editor: NativeChunkEditor
var hold := 1.5
var big := 6.0
var fish_wait := 10.0
var _outcome := {}
## The refresh stage in flight over each settle frame above 16.7 ms.
var slow_stages := []

func _initialize() -> void: run.call_deferred()

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	return {"n":sorted.size(),"median":snappedf(sorted[sorted.size()/2],0.01),"p95":snappedf(sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],0.01),"max":snappedf(sorted.back(),0.01),
		"over_16_7":sorted.filter(func(v: float) -> bool: return v > 16.667).size()}

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
	editor.handle_input(event)

## Until the ball has splashed and its pour closed, and the world is quiet.
func wait_settled(frames: Array, limit := 20.0) -> void:
	var previous := Time.get_ticks_usec()
	var began := previous
	var quiet := 0
	while quiet < 20 and (Time.get_ticks_usec()-began)/1000000.0 < limit:
		var stage := editor.refresh_stage
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		if frames.back() > 16.667: slow_stages.append([snappedf(frames.back(),0.1),stage])
		previous = now
		var busy: bool = editor.ball.state != "idle" or not editor._pour.is_empty() or editor.water_settling or editor.refresh_pending > 0 or editor.land_settling or editor.mountain.active
		quiet = 0 if busy else quiet+1

func drop(label: String, at: Vector2, seconds: float) -> Dictionary:
	var data := editor.data
	var ponds := data.ponds.duplicate(true)
	var streams := data.streams.duplicate(true)
	var objects := data.objects.size()
	var steps: int = data._undo.size()
	_outcome = {}
	var point := screen_of(at)
	editor.pointer_override = point
	mouse(point,true)
	var holding: bool = editor._ball_holding
	var held_frames := []
	var previous := Time.get_ticks_usec()
	var held := 0.0
	var radius_at := {}
	while held < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		held_frames.append((now-previous)/1000.0)
		held += (now-previous)/1000000.0
		previous = now
		if radius_at.is_empty() and held >= 0.5: radius_at = {"t":0.5,"radius":snappedf(editor.ball.radius,0.01),"fish":editor.ball.carried().size()}
	var volume := editor.ball_volume
	var radius: float = editor.ball.radius
	var carried: int = editor.ball.carried().size()
	var hover: float = editor.ball.position.y-editor.ball.radius-editor.ball.ground
	var release := Time.get_ticks_usec()
	mouse(point,false)
	var release_ms := (Time.get_ticks_usec()-release)/1000.0
	editor.pointer_override = null
	var settle_frames := []
	slow_stages.clear()
	var began := Time.get_ticks_usec()
	await wait_settled(settle_frames)
	var report := {"drop":label,"at":[at.x,at.y],"press_taken":holding,"held_s":snappedf(held,0.01),"volume":snappedf(volume,0.01),"radius":snappedf(radius,0.01),
		"hover_m":snappedf(hover,0.01),"at_half_second":radius_at,"fish_in_ball":carried,"outcome":_outcome,
		"ponds":[ponds.size(),data.ponds.size()],"streams":[streams.size(),data.streams.size()],"objects":[objects,data.objects.size()],
		"undo_steps_added":data._undo.size()-steps,"release_ms":snappedf(release_ms,0.01),"held_frames_ms":stats(held_frames),"settle_frames_ms":stats(settle_frames),"slow_stages":slow_stages.duplicate(),
		"settle_s":snappedf((Time.get_ticks_usec()-began)/1000000.0,0.01)}
	return report

func undo_check(report: Dictionary, heights: PackedFloat32Array, ponds: Array, streams: Array, objects: int) -> void:
	var data := editor.data
	editor.undo()
	await wait_settled([])
	report["undo_restores"] = {"heights":data.heights == heights,"ponds":data.ponds == ponds,"streams":data.streams == streams,"objects":data.objects.size() == objects}

func fish_check(outcome: Dictionary) -> Dictionary:
	var life: Variant = scene.get("land_life")
	if life == null: return {"life":false}
	var began := Time.get_ticks_usec()
	var placed := 0
	var here := 0
	while (Time.get_ticks_usec()-began)/1000000.0 < fish_wait:
		await process_frame
		placed = 0
		here = 0
		for site: Dictionary in life.sites.fish.values():
			if not site.has("carried"): continue
			placed += 1
			if site.here: here += 1
		if here >= int(outcome.get("fish",0)) and here > 0: break
	var kinds := []
	for site: Dictionary in life.sites.fish.values():
		if site.has("carried") and site.here: kinds.append(site.look)
	var bodies := []
	if life.survey != null:
		for record: Dictionary in life.survey.bodies: bodies.append([snappedf(record.area,0.1),record.deep.size()])
	return {"bodies":bodies,"surveys":life.surveys,"life":true,"active":life.active,"carried_by_ball":outcome.get("fish",0),"sites_taken":placed,"arrived":here,"looks":kinds,"waited_s":snappedf((Time.get_ticks_usec()-began)/1000000.0,0.1),"fish_sites":life.sites.fish.size()}

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hold="): hold = float(arg.trim_prefix("--hold="))
		if arg.begins_with("--big="): big = float(arg.trim_prefix("--big="))
		if arg.begins_with("--fish-wait="): fish_wait = float(arg.trim_prefix("--fish-wait="))
	create_timer(420).timeout.connect(func() -> void: push_error("Water ball probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-ball-probe-%d/places.json" % Time.get_ticks_usec()
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
	editor.select_tool("land")
	editor.select_brush("water")
	editor.ball_settled.connect(func(outcome: Dictionary) -> void:
		_outcome = outcome.duplicate()
		_outcome.erase("center"))
	print("water_ball ",editor.water_ball," brush ",editor.held_brush()," life ",scene.get("land_life") != null)
	await create_timer(1.0).timeout
	var data := editor.data
	for spec: Array in [["hollow",Vector2(-3.0,2.0),hold],["big",Vector2(2.5,-1.5),big],["full",Vector2(0.5,1.0),12.0]]:
		var heights := data.heights.duplicate()
		var ponds := data.ponds.duplicate(true)
		var streams := data.streams.duplicate(true)
		var objects := data.objects.size()
		var report := await drop(spec[0],spec[1],spec[2])
		report["fish"] = await fish_check(report.outcome)
		await undo_check(report,heights,ponds,streams,objects)
		print("DROP ",JSON.stringify(report))
	# A peak first (the land brush's alpine form), then a ball on its top.
	var peak_at := Vector2(-1.0,-3.0)
	editor.select_brush("land")
	editor.select_land_form("alpine")
	editor._mountain_press(Vector3(peak_at.x,float(data.sample(peak_at,data.heights)),peak_at.y))
	editor.mountain.aim(data,peak_at+Vector2(1.0,0.4)*2.5)
	editor.finish_stroke()
	await wait_settled([])
	var top := peak_at
	var best := -INF
	for x in range(-12,13):
		for z in range(-12,13):
			var p := peak_at+Vector2(x,z)*0.25
			var h := float(data.sample(p,data.heights))
			if h > best:
				best = h
				top = p
	editor.select_brush("water")
	var peak_heights := data.heights.duplicate()
	var peak_ponds := data.ponds.duplicate(true)
	var peak_streams := data.streams.duplicate(true)
	var peak_objects := data.objects.size()
	var report := await drop("peak",top,hold*2.0)
	report["peak_height"] = snappedf(best,0.01)
	var falls := []
	for item in data.objects:
		if item.asset == "waterfall": falls.append({"from":[snappedf(item.x,0.01),snappedf(item.z,0.01)],"to":[snappedf(item.end_x,0.01),snappedf(item.end_z,0.01)],"scale":snappedf(item.scale,0.01)})
	report["waterfalls"] = falls
	report["fall_nodes"] = editor.falls.get_child_count()
	report["fish"] = await fish_check(report.outcome)
	await undo_check(report,peak_heights,peak_ponds,peak_streams,peak_objects)
	print("DROP ",JSON.stringify(report))
	# Shift still drains the old way: press with Shift over nothing leaves no ball.
	Input.parse_input_event(_shift(true))
	var point := screen_of(Vector2(0.0,0.0))
	editor.pointer_override = point
	mouse(point,true)
	var shift_ball: bool = editor._ball_holding
	var shift_painting: bool = editor._painting
	mouse(point,false)
	Input.parse_input_event(_shift(false))
	editor.pointer_override = null
	await wait_settled([])
	print("SHIFT ",JSON.stringify({"ball":shift_ball,"painting":shift_painting}))
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit()

func _shift(pressed: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.physical_keycode = KEY_SHIFT
	key.pressed = pressed
	return key
