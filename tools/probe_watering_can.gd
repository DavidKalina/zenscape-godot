extends SceneTree
## Headless probe of the watering can (scripts/watering_can.gd), the scooped
## water ball (NativeChunkEditor `scoop_ball`) and the springs that keep
## filling (WaterFlow SPRING_*), on the cozy worlds scene with live water.
## Prints JSON lines and PASS/FAIL:
## - "dry": a scoop on dry low ground forms no ball.
## - "pour": the can held 3 s on low ground adds about RATE × 3 s of water.
## - "scoop": a ball pressed on that water fills from it, and the water drops.
## - "spring": the can held still on the highest ground plants a spring, and
##   the sim then runs SPRING_SECONDS of water from it (no weather's water):
##   the volume on the plate, the biggest pool and the water leaving over the
##   rim every 15 s, and where the spring's water went. --spring-rate=R
##   compares another rate.
##   perl -e 'alarm 400; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
##     --script res://tools/probe_watering_can.gd -- --no-title --no-rain-runoff
## Frame timing is the dummy renderer's; nothing here is drawn.

const SPRING_SECONDS := 120.0
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

func frames(seconds: float) -> void:
	for i in range(int(seconds*60.0)): await process_frame

## Plate points `margin` m inside the rim, highest and lowest dry.
func spots(margin: float) -> Dictionary:
	var data := editor.data
	var low := Vector2(INF,INF)
	var high := -low
	for p: Vector2 in data.points:
		low = low.min(p)
		high = high.max(p)
	var top := Vector2.ZERO
	var top_h := -INF
	var bottom := Vector2.ZERO
	var bottom_h := INF
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if p.x < low.x+margin or p.y < low.y+margin or p.x > high.x-margin or p.y > high.y-margin: continue
		# In view and clear of the rim: the middle of the plate.
		if p.length() > 7.0 or editor.pick(screen_of(p)) == null: continue
		var h: float = data.heights[i]
		if h > top_h:
			top_h = h
			top = p
		if h < bottom_h and editor.flow.depth_at(p) < 0.001 and not editor.water_near(p):
			bottom_h = h
			bottom = p
	return {"top":top,"top_h":top_h,"low":bottom,"low_h":bottom_h}

func run() -> void:
	create_timer(380).timeout.connect(func() -> void: push_error("Watering can probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-can-probe-%d/places.json" % Time.get_ticks_usec()
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
	var at := spots(4.0)
	print(JSON.stringify({"spots":{"top":[snappedf(at.top.x,0.01),snappedf(at.top.y,0.01),snappedf(at.top_h,0.01)],"low":[snappedf(at.low.x,0.01),snappedf(at.low.y,0.01),snappedf(at.low_h,0.01)]},
		"top_kind":flow.source_kind(at.top),"springs":flow.springs.size(),"volume":snappedf(flow.volume(),0.01)}))

	# Dry: nothing to scoop.
	var low_screen := screen_of(at.low)
	editor.water_ball = true
	var dry: String = editor.scoop_ball(low_screen)
	check(dry == "dry","a scoop on dry ground forms no ball (%s; pick %s, forming %s, active %s)" % [dry,str(editor.pick(low_screen)),editor.forming,editor.active])
	check(not editor._ball_holding,"no ball is held after a dry scoop")

	# Pour: the can held on the low ground.
	var before: float = flow.volume()
	mouse(low_screen,true)
	check(editor.can_in_hand(low_screen,1.0,false),"the can takes a press on the land")
	await frames(3.0)
	var poured: float = editor.can.poured
	editor.can.release()
	mouse(low_screen,false)
	await frames(1.5)
	var after: float = flow.volume()
	print(JSON.stringify({"pour":{"poured":snappedf(poured,0.01),"volume_before":snappedf(before,0.01),"volume_after":snappedf(after,0.01),"depth_at":snappedf(flow.depth_at(at.low),0.001),"landing":str(editor.can.landing)}}))
	check(poured > 2.0,"the can poured over 2 m³ in 3 s")
	check(after-before > poured*0.5,"at least half of it stands on the plate 1.5 s on")
	check(editor.water_near(at.low),"water stands where the can poured")

	# Scoop: a ball from that water.
	var water_before: float = flow.volume()
	mouse(low_screen,true)
	var scooped: String = editor.scoop_ball(low_screen)
	check(scooped.is_empty(),"a scoop over the poured water forms a ball (%s)" % scooped)
	await frames(1.5)
	var held: float = editor.ball_volume
	var water_after: float = flow.volume()
	mouse(low_screen,false)
	editor._ball_release()
	print(JSON.stringify({"scoop":{"ball_volume":snappedf(held,0.01),"water_before":snappedf(water_before,0.01),"water_after":snappedf(water_after,0.01),"fish":editor.ball.fish.size()}}))
	check(held > 0.3,"the ball took up water")
	check(water_before-water_after > held*0.7,"the water on the plate dropped by about what the ball took")
	check(editor.ball.fish.is_empty(),"a ball from a fishless pour carries no fish")
	await frames(3.0)

	# Spring: a hill raised first (4.5 m, 3.5 m across the shoulders), then
	# the can held still on its top.
	var hill := Vector2(-4.0,-3.0)
	var raised := editor.data.heights.duplicate()
	for i in range(raised.size()):
		var d: float = (editor.data.points[i] as Vector2).distance_to(hill)
		raised[i] += 4.5*exp(-d*d/(2.0*3.5*3.5))
	editor.data.heights = raised
	await editor.refresh(self)
	at.top = hill
	print(JSON.stringify({"hill":{"kind":flow.source_kind(hill),"height":snappedf(float(editor.data.ground_height(hill)),0.01)}}))
	var springs: int = flow.springs.size()
	var top_screen := screen_of(at.top)
	mouse(top_screen,true)
	check(editor.can_in_hand(top_screen,1.0,false),"the can takes a press on the top")
	await frames(2.5)
	editor.can.release()
	mouse(top_screen,false)
	# The can's pour eases off over frames, not in the synchronous runs below.
	await frames(0.5)
	check(not flow.taps.has("can"),"the can's tap is closed once it is lifted")
	check(flow.springs.size() == springs+1,"holding still on the top planted a spring (%s, landing %s)" % [flow.source_kind(editor.can.landing) if editor.can.landing != Vector2.INF else "none",str(editor.can.landing)])
	if flow.springs.size() > springs: print(JSON.stringify({"spring":flow.springs.back()}))
	# The spring alone: no weather's water, and --spring-rate=R (m³/s) to
	# compare another rate on the same spring.
	flow.runoff = preload("res://scripts/rain_runoff.gd").new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--spring-rate=") and flow.springs.size() > springs: flow.springs.back().rate = float(arg.trim_prefix("--spring-rate="))
	var base: Dictionary = flow.kernel.stats()
	var rows := []
	var t := 0.0
	var rate := 0.0
	while t < SPRING_SECONDS:
		flow.run(int(15.0/flow.dt))
		t += 15.0
		var pools: Array = flow.pools()
		var biggest := {}
		for pool: Dictionary in pools:
			if float(pool.area) > float(biggest.get("area",0.0)): biggest = pool
		var edge: Dictionary = flow.edge_outflow()
		rows.append({"t":t,"volume":snappedf(flow.volume(),0.01),"pool_area":snappedf(float(biggest.get("area",0.0)),0.1),"pool_depth":snappedf(float(biggest.get("depth",0.0)),0.01),"edge_m3s":snappedf(float(edge.total),0.001)})
	for row in rows: print(JSON.stringify({"spring_fill":row}))
	var end: Dictionary = flow.kernel.stats()
	var budget := {}
	for key in ["poured","drained","soaked","removed"]: budget[key] = snappedf(float(end[key])-float(base[key]),0.01)
	budget["wet_cells"] = end.wet_cells
	budget["bed"] = {} if flow.last_bed.is_empty() else {"pool":str(flow.last_bed.pool),"radius":flow.last_bed.radius}
	print(JSON.stringify({"spring_budget":budget}))
	# Where the pool lands depends on the world (by the rim its water runs off
	# the plate; on a wide plain the overflow spreads and evaporates), so the
	# rows above are for reading. What holds everywhere: the ground does not
	# drink the spring (before saturation it took ~60%).
	check(float(budget.soaked) < float(budget.poured)*0.55,"under 55%% of the spring's water is lost to ground and air (%.0f%%)" % (100.0*float(budget.soaked)/maxf(float(budget.poured),0.001)))
	print("Failures: %d" % failures)
	quit(1 if failures > 0 else 0)
