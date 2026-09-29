extends SceneTree
## Headless probe of live water in the product (docs/scenic/water-flow.md
## "Integration"), on the cozy worlds scene under --modeless, driven by
## synthesized input:
##   - the live water is set up and takes the native kernel;
##   - the probe shapes a peak with a groove down its flank to a basin (its
##     own set-up, written into the heights and refreshed);
##   - a drag from the sky onto the groove's head condenses a water ball, held
##     until the button is let go; it falls and becomes a spring;
##   - the water runs down the groove and fills the basin; the view draws it,
##     life's survey sees the pond, and `water_settled` reports it;
##   - a real thumb groove (scripts/land_clay.gd) cut from the pond outward
##     fills from it: the water reads the clay's change;
##   - undo takes the groove back, then the spring;
##   - CPU frame gaps while the water runs (dummy renderer: the cost of the
##     work, not of drawing it).
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_water_flow_modeless.gd -- --modeless [--planned-water]
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var failures := []
var gaps: Array[float] = []
var _last := 0
const Probe := preload("res://tools/probe_water_flow.gd")

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	editor.pointer_override = at
	reach.pointer_override = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tick() -> void:
	await process_frame
	var now := Time.get_ticks_usec()
	gaps.append((now-_last)/1000.0)
	_last = now

func frames(count: int) -> void:
	for i in range(count): await tick()

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func settled() -> void:
	var quiet := 0
	while quiet < 20:
		await process_frame
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or (clay != null and (clay.state != 0 or clay.poking))
		quiet = 0 if busy else quiet+1

func water(center: Vector2, radius: float) -> float:
	var flow: RefCounted = editor.flow
	var depths: PackedFloat32Array = flow.depths()
	var total := 0.0
	for j in range(flow.height):
		for i in range(flow.width):
			if (flow.origin+Vector2(i+0.5,j+0.5)*flow.cell).distance_to(center) < radius: total += depths[j*flow.width+i]
	return total*flow.cell*flow.cell

func stats(values: Array[float]) -> String:
	if values.is_empty(): return "-"
	var total := 0.0
	for v in values: total += v
	return "max %.1f ms, mean %.1f ms over %d frames" % [values.max(),total/values.size(),values.size()]

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("live water probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-flow-modeless-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	scene.world_clock.running = false
	if "--planned-water" in OS.get_cmdline_user_args():
		check("--planned-water keeps the one-shot plan",editor.flow == null)
		print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
		quit(0 if failures.is_empty() else 1)
		return
	for i in range(120):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	check("live water is set up under --modeless",editor.flow != null and editor.flow.ready and editor.flow_view != null)
	if editor.flow == null or not editor.flow.ready:
		quit(1)
		return
	check("it takes the native kernel",editor.flow.native,editor.flow.stats())

	# The probe's land: peak, groove, basin (tools/probe_water_flow.gd).
	var data := editor.data
	for i in range(data.points.size()): data.heights[i] = Probe.land(data.points[i])
	editor.force_refresh()
	await settled()
	editor.flow.drain(Vector2.ZERO,40.0)

	# Water from the sky: press in the void, drag onto the groove's head.
	var sky := Vector2.INF
	for candidate in [Vector2(720,20),Vector2(200,20),Vector2(1240,20),Vector2(720,60),Vector2(40,440),Vector2(1400,440)]:
		if reach.void_at(candidate):
			sky = candidate
			break
	check("found the sky",sky != Vector2.INF)
	var head := screen(Probe.HEAD)
	var settled_outcome := {}
	editor.ball_settled.connect(func(outcome: Dictionary) -> void: settled_outcome.merge(outcome))
	var reported: Array[Rect2] = []
	editor.water_settled.connect(func(rect: Rect2) -> void: reported.append(rect))
	editor.pointer_override = sky
	reach.pointer_override = sky
	button(sky,true)
	await frames(2)
	check("a press in the sky is the void's",reach.holding == "void",reach.holding)
	var p := sky
	for i in range(30):
		var step := (head-sky)/30.0
		p += step
		motion(p,step)
		await frames(1)
		if editor._ball_holding: break
	check("dragged onto the land, the sky's press becomes a held water ball",editor._ball_holding and reach.holding.is_empty(),[editor._ball_holding,reach.holding])
	check("the hand cups it",editor.hand_gesture() == "cup")
	for i in range(10):
		p += (head-p)*0.5
		motion(p,Vector2.ZERO)
		await frames(1)
	await frames(150)
	var held: float = editor.ball_volume
	button(p,false)
	for i in range(240):
		await frames(1)
		if not settled_outcome.is_empty(): break
	check("let go, the ball falls and becomes a spring",settled_outcome.get("kind") == "spring" and editor.flow.springs.size() == 1,[settled_outcome,held])
	check("no one-shot plan ran",editor._pour.is_empty() and data.ponds.is_empty())

	# Let it run: fast-forward the water, then a few seconds of real frames.
	for i in range(12):
		editor.flow.run(roundi(10.0/editor.flow.dt))
	gaps.clear()
	_last = Time.get_ticks_usec()
	await frames(300)
	var run_gaps := gaps.duplicate()
	var basin := water(Probe.BASIN,3.0)
	var total: float = editor.flow.volume()
	print("POND ",JSON.stringify({"basin_m3":snappedf(basin,0.01),"total_m3":snappedf(total,0.01),"ball_m3":snappedf(held,0.01),"stats":editor.flow.stats()}))
	check("the water runs down the groove into the basin",basin > 0.6*total and basin > 3.0,"%.2f of %.2f m³" % [basin,total])
	var still: Mesh = editor.flow_view.still.mesh
	check("the view draws the pond",still.get_surface_count() == 1 and still.surface_get_array_len(0) > 50,still.get_surface_count())
	check("life's survey sees it as still water",editor.still_water_triangles().size() > 150,editor.still_water_triangles().size())
	check("the new pond is reported to life and emergence",reported.any(func(rect: Rect2) -> bool: return rect.has_point(Probe.BASIN)),reported)
	check("emergence knows where the water stands",preload("res://scripts/water_flow.gd").wet_in(editor.emergence.flow_wet,Probe.BASIN))
	var view: Node = editor.flow_view
	print("VIEW ",JSON.stringify({"build_us":view.last_build_usec,"publish_us":view.last_publish_usec,"worst_publish_us":view.worst_publish_usec,"falls":view.fall_count(),"moving_surfaces":view.moving.mesh.get_surface_count()}))
	check("frames stay interactive while the water runs (CPU)",run_gaps.max() < 25.0,stats(run_gaps))

	# A real thumb groove out of the pond: the water follows the clay.
	var level: float = editor.flow.grounds()[editor.flow.cell_at(Probe.BASIN)]+editor.flow.depths()[editor.flow.cell_at(Probe.BASIN)]
	var from := Probe.BASIN+Vector2(1.8,0)
	var to := Probe.BASIN+Vector2(8.0,0)
	var undo0: int = data._undo.size()
	if clay != null:
		var a := screen(from)
		var b := screen(to)
		var steps := maxi(ceili(a.distance_to(b)/5.0),10)
		editor.pointer_override = a
		reach.pointer_override = a
		button(a,true)
		await tick()
		p = a
		for i in range(steps):
			var step := (b-a)/steps
			p += step
			motion(p,step)
			await tick()
		button(p,false)
		await settled()
		var dug := height(Probe.BASIN+Vector2(5.0,0))
		check("the thumb cut a groove from the pond",dug < -0.1 and data._undo.size() == undo0+1,"ground %.2f, pond level %.2f" % [dug,level])
		var before := water(Probe.BASIN+Vector2(5.5,0),1.5)
		await frames(600)
		var after := water(Probe.BASIN+Vector2(5.5,0),1.5)
		check("water runs into the new groove",after > before+0.05,"%.3f → %.3f m³" % [before,after])
		editor.undo()
		await settled()
		check("undo takes the groove back; the spring stays",data._undo.size() == undo0 and editor.flow.springs.size() == 1)
	editor.undo()
	await settled()
	check("undo takes the spring back",editor.flow.springs.is_empty())
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
