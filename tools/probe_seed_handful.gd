extends SceneTree
## Headless probe of the seed sprinkle (scripts/seed_handful.gd,
## docs/scenic/brushes.md "Seed sprinkle") on the Genesis plain, through the
## real input path: a mouse press with forest in hand, the editor's own
## _process following the pointer (pointer_override) while seeds pour, then a
## release. Each stroke reports the seeds dropped and landed, every landed
## seed's distance from the centre of the mark it was promised against that
## mark's radius (all must be inside), how far landings and the spout were from
## the pointer, the seeds sent to emergence after thinning, what grew and where
## (saplings on seed points first, then the forest round them; trees far from
## any seed), main-loop frame gaps and the sprinkle's own step while pouring and
## settling and while the forest grew, the undo steps added, and whether one
## undo restores the wish, the floor tint and the objects. Then an undo with
## seeds still in the air, a Shift press (clears by painting) and a press with
## the sprinkle off (--paint-forest paints).
##   -- --grow=24
## Frame gaps are CPU main-loop intervals under the dummy renderer.
var scene: Node3D
var editor: NativeChunkEditor
var grow := 24.0
var failures := 0
var _landings := []

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

func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ",what)

## Frames until no seed is in the air and the view has settled.
func wait_quiet(frames: Array, limit := 10.0) -> void:
	var previous := Time.get_ticks_usec()
	var began := previous
	var quiet := 0
	while quiet < 10 and (Time.get_ticks_usec()-began)/1000000.0 < limit:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		previous = now
		var busy: bool = (editor.handful != null and editor.handful.active()) or editor.refresh_pending > 0
		quiet = 0 if busy else quiet+1

func ids() -> Dictionary:
	var known := {}
	for item: Dictionary in editor.data.objects: known[int(item.id)] = true
	return known

## One stroke: press at `at`, pour for `seconds` while the pointer runs to
## `to` (null: stays), release, let the seeds land and the forest grow.
func stroke(label: String, at: Vector2, seconds: float, to: Variant = null, radius := -1.0) -> Dictionary:
	var data := editor.data
	var forest = editor.brushes.forest
	var old_radius: float = forest.radius
	if radius > 0.0: forest.radius = radius
	var wish: PackedFloat32Array = editor.emergence.intent.forest.duplicate()
	var tint := data.tint.duplicate()
	var known := ids()
	var objects := data.objects.size()
	var steps: int = data._undo.size()
	_landings.clear()
	var point := screen_of(at)
	editor.pointer_override = point
	mouse(point,true)
	var pouring: bool = editor._handful_holding
	var h = editor.handful
	var pour_frames := []
	var pour_step := []
	var spout_lag := []
	var air_most := 0
	var previous := Time.get_ticks_usec()
	var held := 0.0
	var pointer := at
	while held < seconds:
		await process_frame
		var now := Time.get_ticks_usec()
		pour_frames.append((now-previous)/1000.0)
		pour_step.append(h.last_usec/1000.0)
		held += (now-previous)/1000000.0
		previous = now
		air_most = maxi(air_most,h.seeds_in_air())
		spout_lag.append(Vector2(h.spout.x,h.spout.z).distance_to(pointer))
		for landing: Array in _landings:
			if landing.size() == 2: landing.append(Vector2(landing[0]).distance_to(pointer))
		if to != null:
			pointer = at.lerp(to,clampf(held/seconds,0.0,1.0))
			editor.pointer_override = screen_of(pointer)
	var release := Time.get_ticks_usec()
	mouse(editor.pointer_override,false)
	var release_ms := (Time.get_ticks_usec()-release)/1000.0
	editor.pointer_override = null
	var in_air_at_release: int = h.seeds_in_air()
	var settle_frames := []
	var settle_step := []
	previous = Time.get_ticks_usec()
	var began := previous
	while h.active() and (Time.get_ticks_usec()-began)/1000000.0 < 5.0:
		await process_frame
		var now := Time.get_ticks_usec()
		settle_frames.append((now-previous)/1000.0)
		settle_step.append(h.last_usec/1000.0)
		previous = now
	var settle_s := (Time.get_ticks_usec()-began)/1000000.0
	var sown: float = preload("res://scripts/emergence.gd").time
	var sprouts: int = h._sprouts.size()
	await wait_quiet(settle_frames)
	var sowing: Dictionary = editor.last_sowing
	var points: PackedVector2Array = sowing.get("points",PackedVector2Array())
	var planted: PackedVector2Array = sowing.get("planted",PackedVector2Array())
	var outside := 0
	var worst := 0.0
	var to_pointer := []
	for landing: Array in _landings:
		var mark: Vector3 = landing[1]
		var share := Vector2(landing[0]).distance_to(Vector2(mark.x,mark.y))/mark.z
		worst = maxf(worst,share)
		if share > 1.0: outside += 1
		if landing.size() > 2: to_pointer.append(landing[2])
	var wish_cells := 0
	for cell in range(wish.size()):
		if editor.emergence.intent.forest[cell] != wish[cell]: wish_cells += 1
	# The forest grows: saplings on the planted seeds first, then round them.
	var refusals_before: Dictionary = editor.emergence.refusals.duplicate()
	var grow_frames := []
	previous = Time.get_ticks_usec()
	began = previous
	while (Time.get_ticks_usec()-began)/1000000.0 < grow:
		await process_frame
		var now := Time.get_ticks_usec()
		grow_frames.append((now-previous)/1000.0)
		previous = now
		if not editor.emergence.busy() and (now-began)/1000000.0 > 3.0: break
	var trees := 0
	var shrubs := 0
	var on_seed := 0
	var first_on_seed := INF
	var others := []
	var far := []
	var kinds := {}
	const Emergence := preload("res://scripts/emergence.gd")
	for item: Dictionary in data.objects:
		if NativeTerrainData.object_source(item) != "emerged" or known.has(int(item.id)): continue
		if not item.asset in Emergence.TREES and not item.asset in ["snag","log","stump"]:
			shrubs += 1
			continue
		trees += 1
		kinds[item.asset] = kinds.get(item.asset,0)+1
		var p := Vector2(item.x,item.z)
		var after := float(item.get("born",sown))-sown
		# A spruce may sit a few centimetres off its seed (Emergence `_dead_top`).
		if Emergence._nearest(planted,p) < 0.05:
			on_seed += 1
			first_on_seed = minf(first_on_seed,after)
		else: others.append(after)
		var nearest := Emergence._nearest(points,p)
		if nearest > 1.5: far.append(snappedf(nearest,0.01))
	var refused := {}
	for reason: String in editor.emergence.refusals:
		var more: int = int(editor.emergence.refusals[reason])-int(refusals_before.get(reason,0))
		if more > 0: refused[reason] = more
	var report := {"stroke":label,"from":[at.x,at.y],"to":[pointer.x,pointer.y],"brush_radius":forest.radius,"mark_radius":snappedf(h.mark_radius,0.01),"press_taken":pouring,"held_s":snappedf(held,0.01),
		"dropped":h.dropped,"landed":points.size(),"most_in_air":air_most,"in_air_at_release":in_air_at_release,"settle_s":snappedf(settle_s,0.01),
		"outside_mark":outside,"worst_share_of_radius":snappedf(worst,0.01),"landing_to_pointer_m":stats(to_pointer),"spout_lag_m":stats(spout_lag),
		"planted":planted.size(),"sprouts":sprouts,"wish_cells":wish_cells,"undo_steps_added":data._undo.size()-steps,
		"grown":{"trees":trees,"shrubs":shrubs,"kinds":kinds,"on_planted_seeds":on_seed,"first_on_seed_s":snappedf(first_on_seed,0.1) if first_on_seed < INF else null,
			"others_after_s":stats(others),"trees_over_1_5m_from_any_seed":far,"refused":refused},
		"release_ms":snappedf(release_ms,0.01),"pour_frames_ms":stats(pour_frames),"pour_step_ms":stats(pour_step),"settle_frames_ms":stats(settle_frames),"settle_step_ms":stats(settle_step),"grow_frames_ms":stats(grow_frames)}
	check(pouring,label+": press started the sprinkle")
	check(outside == 0,label+": every seed landed inside its mark")
	check(points.size() == h.dropped and h.dropped > 0,label+": every seed dropped landed")
	check(data._undo.size()-steps == 1,label+": one undo step")
	editor.undo()
	await wait_quiet([])
	var restored := {"wish":editor.emergence.intent.forest == wish,"tint":data.tint == tint,"objects":data.objects.size() == objects,"sprouts_left":h._sprouts.size()}
	report["undo_restores"] = restored
	check(restored.wish and restored.tint and restored.objects,label+": undo restores")
	forest.radius = old_radius
	return report

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--grow="): grow = float(arg.trim_prefix("--grow="))
	create_timer(600).timeout.connect(func() -> void: push_error("Seed sprinkle probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-seed-probe-%d/places.json" % Time.get_ticks_usec()
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
	editor.select_brush("forest")
	print("seed_handful ",editor.seed_handful," brush ",editor.held_brush())
	await create_timer(1.0).timeout
	# The sprinkle is made on the first press; listen from then on.
	var tap := screen_of(Vector2(8.0,8.0))
	editor.pointer_override = tap
	mouse(tap,true)
	mouse(tap,false)
	editor.pointer_override = null
	editor.handful.seed_landed.connect(func(point: Vector2, mark: Vector3) -> void: _landings.append([point,mark]))
	await wait_quiet([])
	editor.undo()
	await wait_quiet([])
	for spec: Array in [["tap",Vector2(-3.0,2.0),0.05,null,-1.0],["linger",Vector2(0.5,1.0),3.0,null,-1.0],["slow drag",Vector2(-5.0,-4.0),3.0,Vector2(0.0,-4.0),-1.0],
			["fast drag",Vector2(-6.0,3.0),1.2,Vector2(4.0,3.0),-1.0],["wide drag",Vector2(-6.0,6.0),2.0,Vector2(2.0,6.0),6.0]]:
		var report := await stroke(spec[0],spec[1],spec[2],spec[3],spec[4])
		print("STROKE ",JSON.stringify(report))
	# An undo with seeds still in the air lands them and takes the stroke back.
	var data := editor.data
	var wish: PackedFloat32Array = editor.emergence.intent.forest.duplicate()
	var tint := data.tint.duplicate()
	var steps: int = data._undo.size()
	var point := screen_of(Vector2(1.0,-2.0))
	editor.pointer_override = point
	mouse(point,true)
	for _frame in range(40): await process_frame
	var in_air: int = editor.handful.seeds_in_air()
	editor.undo()
	mouse(point,false)
	editor.pointer_override = null
	await wait_quiet([])
	var midair := {"seeds_in_air_at_undo":in_air,"active":editor.handful.active(),"wish":editor.emergence.intent.forest == wish,"tint":data.tint == tint,"undo_steps":data._undo.size()-steps}
	print("MIDAIR ",JSON.stringify(midair))
	check(in_air > 0 and midair.wish and midair.tint and midair.undo_steps == 0 and not midair.active,"undo in the air restores")
	# Shift still clears by painting: no sprinkle.
	Input.parse_input_event(_shift(true))
	point = screen_of(Vector2(0.0,0.0))
	editor.pointer_override = point
	mouse(point,true)
	var shift := {"sprinkle":editor._handful_holding,"painting":editor._painting}
	mouse(point,false)
	Input.parse_input_event(_shift(false))
	editor.pointer_override = null
	await wait_quiet([])
	print("SHIFT ",JSON.stringify(shift))
	check(not shift.sprinkle and shift.painting,"Shift paints a clearing")
	# With the sprinkle off (--paint-forest) a press paints as before.
	editor.seed_handful = false
	point = screen_of(Vector2(-2.0,-1.0))
	editor.pointer_override = point
	mouse(point,true)
	var painted := {"sprinkle":editor._handful_holding,"painting":editor._painting}
	for _frame in range(10): await process_frame
	mouse(point,false)
	editor.pointer_override = null
	await wait_quiet([])
	editor.seed_handful = true
	print("PAINT ",JSON.stringify(painted))
	check(not painted.sprinkle and painted.painting,"--paint-forest paints")
	print("failures=",failures)
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit(1 if failures > 0 else 0)

func _shift(pressed: bool) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_SHIFT
	key.physical_keycode = KEY_SHIFT
	key.pressed = pressed
	return key
