extends SceneTree
## Headless probe of the seed handful (scripts/seed_handful.gd,
## docs/scenic/brushes.md "Seed handful") on the Genesis plain, through the
## real input path: a mouse press with forest in hand, the editor's own
## _process following the pointer (pointer_override) while the handful fills,
## then a release. Each handful reports the seeds gathered and the mark's
## radius, every landed seed's distance from the mark's centre against the
## radius (all must be inside), what emergence grew and where (saplings on the
## landing points first, then the forest round them; trees outside the mark),
## main-loop frame gaps while held, while the seeds fell and while the forest
## grew, the undo steps added, and whether one undo restores the wish, the
## floor tint and the objects. Then an undo while seeds are still in the air,
## a Shift press (clears by painting, no handful) and a press with the handful
## off (--paint-forest paints).
##   -- --grow=24
## Frame gaps are CPU main-loop intervals under the dummy renderer.
var scene: Node3D
var editor: NativeChunkEditor
var grow := 24.0
var failures := 0

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

## Frames until the handful's seeds are all down and the view has settled.
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

func emerged_since(before: Dictionary) -> Array:
	var found := []
	for item: Dictionary in editor.data.objects:
		if NativeTerrainData.object_source(item) == "emerged" and not before.has(int(item.id)): found.append(item)
	return found

func ids() -> Dictionary:
	var known := {}
	for item: Dictionary in editor.data.objects: known[int(item.id)] = true
	return known

## One handful: press at `at`, hold `seconds` while the pointer runs to `to`
## (null: stays), release, let the seeds land and the forest grow.
func handful(label: String, at: Vector2, seconds: float, to: Variant = null, radius := -1.0) -> Dictionary:
	var data := editor.data
	var forest = editor.brushes.forest
	var old_radius: float = forest.radius
	if radius > 0.0: forest.radius = radius
	var wish: PackedFloat32Array = editor.emergence.intent.forest.duplicate()
	var tint := data.tint.duplicate()
	var known := ids()
	var objects := data.objects.size()
	var steps: int = data._undo.size()
	var point := screen_of(at)
	editor.pointer_override = point
	mouse(point,true)
	var holding: bool = editor._handful_holding
	var held_frames := []
	var previous := Time.get_ticks_usec()
	var held := 0.0
	var grew := []
	var step_usec := []
	while held < seconds:
		await process_frame
		step_usec.append(editor.handful.last_usec/1000.0)
		var now := Time.get_ticks_usec()
		held_frames.append((now-previous)/1000.0)
		held += (now-previous)/1000000.0
		previous = now
		if to != null: editor.pointer_override = screen_of(at.lerp(to,clampf(held/seconds,0.0,1.0)))
		if grew.size() < 8 and held >= 0.5*(grew.size()+1): grew.append([snappedf(held,0.1),editor.handful.seed_count(),snappedf(editor.handful.mark_radius,0.01)])
	var h = editor.handful
	var seeds: int = h.seed_count()
	var pointer_end: Vector2 = at if to == null else to
	var release := Time.get_ticks_usec()
	mouse(editor.pointer_override,false)
	var release_ms := (Time.get_ticks_usec()-release)/1000.0
	editor.pointer_override = null
	var center: Vector2 = h.mark_center
	var mark: float = h.mark_radius
	# While the seeds fall: how far any strays from the mark in the air.
	var fall_frames := []
	var fall_step := []
	var air_max := 0.0
	previous = Time.get_ticks_usec()
	var began := previous
	while h.active() and (Time.get_ticks_usec()-began)/1000000.0 < 8.0:
		await process_frame
		var now := Time.get_ticks_usec()
		fall_frames.append((now-previous)/1000.0)
		fall_step.append(h.last_usec/1000.0)
		previous = now
		for s: Dictionary in h._seeds:
			if s.has("from") and not s.done: air_max = maxf(air_max,Vector2(s.p.x,s.p.z).distance_to(center)/mark)
	var fell_s := (Time.get_ticks_usec()-began)/1000000.0
	var sown: float = preload("res://scripts/emergence.gd").time
	var sprouts: int = h._sprouts.size()
	await wait_quiet(fall_frames)
	var sowing: Dictionary = editor.last_sowing
	var points: PackedVector2Array = sowing.get("points",PackedVector2Array())
	var distances := []
	var outside := 0
	for p in points:
		var d := p.distance_to(center)
		distances.append(snappedf(d,0.01))
		if d > mark: outside += 1
	distances.sort()
	var changed_cells := 0
	var outside_wish := 0
	var side := data.MEADOW_CELLS
	for cell in range(wish.size()):
		if editor.emergence.intent.forest[cell] != wish[cell]:
			changed_cells += 1
			var c := data.meadow_position(cell%side,cell/side)+Vector2.ONE*data.MEADOW_STEP*0.5
			if c.distance_to(center) > mark+preload("res://scripts/forest_brush.gd").SEED_EDGE+data.MEADOW_STEP: outside_wish += 1
	# The forest grows: saplings on the landing points first, then round them.
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
	var grown := emerged_since(known)
	var trees := []
	var shrubs := 0
	var on_seed := 0
	var outside_trees := []
	var first_on_seed := INF
	var first_other := INF
	var others := []
	for item: Dictionary in grown:
		if not item.asset in preload("res://scripts/emergence.gd").TREES and not item.asset in ["snag","log","stump"]:
			shrubs += 1
			continue
		var p := Vector2(item.x,item.z)
		var nearest := INF
		for q in points: nearest = minf(nearest,p.distance_to(q))
		var after := float(item.get("born",sown))-sown
		trees.append({"asset":item.asset,"centre_m":snappedf(p.distance_to(center),0.01),"seed_m":snappedf(nearest,0.01),"after_s":snappedf(after,0.1)})
		# A spruce may sit a few centimetres off its seed (Emergence `_dead_top`).
		if nearest < 0.05:
			on_seed += 1
			first_on_seed = minf(first_on_seed,after)
		else:
			first_other = minf(first_other,after)
			others.append(after)
		if p.distance_to(center) > mark: outside_trees.append(snappedf(p.distance_to(center)-mark,0.01))
	var kinds := {}
	for t: Dictionary in trees: kinds[t.asset] = kinds.get(t.asset,0)+1
	var refused := {}
	for reason: String in editor.emergence.refusals:
		var more: int = int(editor.emergence.refusals[reason])-int(refusals_before.get(reason,0))
		if more > 0: refused[reason] = more
	var report := {"handful":label,"at":[at.x,at.y],"to":[pointer_end.x,pointer_end.y],"brush_radius":forest.radius,"press_taken":holding,"held_s":snappedf(held,0.01),
		"gathering":grew,"seeds":seeds,"mark":{"center":[snappedf(center.x,0.01),snappedf(center.y,0.01)],"radius":snappedf(mark,0.01)},
		"landed":points.size(),"outside_mark":outside,"max_share_of_radius":snappedf(float(distances.back())/mark if not distances.is_empty() else 0.0,0.01),
		"distances_m":distances,"air_max_share":snappedf(air_max,0.01),"fell_s":snappedf(fell_s,0.01),"sprouts":sprouts,"handful_step_ms":{"held":stats(step_usec),"falling":stats(fall_step)},
		"wish_cells":changed_cells,"wish_cells_past_mark":outside_wish,"undo_steps_added":data._undo.size()-steps,
		"grown":{"trees":trees.size(),"shrubs":shrubs,"kinds":kinds,"on_seed_points":on_seed,"first_on_seed_s":snappedf(first_on_seed,0.1) if first_on_seed < INF else null,
			"first_other_s":snappedf(first_other,0.1) if first_other < INF else null,"others_after_s":stats(others),"trees_past_mark_m":outside_trees,"refused":refused},
		"release_ms":snappedf(release_ms,0.01),"held_frames_ms":stats(held_frames),"fall_frames_ms":stats(fall_frames),"grow_frames_ms":stats(grow_frames)}
	check(holding,label+": press took the handful")
	check(outside == 0,label+": every seed landed inside the mark")
	check(points.size() == seeds,label+": every seed landed")
	check(data._undo.size()-steps == 1,label+": one undo step")
	# One undo takes the handful back: wish, floor and what grew.
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
	create_timer(600).timeout.connect(func() -> void: push_error("Seed handful probe timed out"); quit(2))
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
	for spec: Array in [["tap",Vector2(-3.0,2.0),0.1,null,-1.0],["short",Vector2(2.5,-1.5),1.0,null,-1.0],["full",Vector2(0.5,1.0),3.5,null,-1.0],
			["moving",Vector2(-5.0,-4.0),2.0,Vector2(3.0,-4.5),-1.0],["wide",Vector2(-1.0,4.0),3.0,null,6.0]]:
		var report := await handful(spec[0],spec[1],spec[2],spec[3],spec[4])
		print("HANDFUL ",JSON.stringify(report))
	# An undo while the seeds are still in the air lands them and takes the
	# whole handful back.
	var data := editor.data
	var wish: PackedFloat32Array = editor.emergence.intent.forest.duplicate()
	var tint := data.tint.duplicate()
	var steps: int = data._undo.size()
	var point := screen_of(Vector2(1.0,-2.0))
	editor.pointer_override = point
	mouse(point,true)
	for _frame in range(30): await process_frame
	mouse(point,false)
	editor.pointer_override = null
	for _frame in range(6): await process_frame
	var in_air: int = editor.handful._seeds.filter(func(s: Dictionary) -> bool: return not s.done).size()
	editor.undo()
	await wait_quiet([])
	var midair := {"seeds_in_air_at_undo":in_air,"handful_active":editor.handful.active(),"wish":editor.emergence.intent.forest == wish,"tint":data.tint == tint,"undo_steps":data._undo.size()-steps}
	print("MIDAIR ",JSON.stringify(midair))
	check(midair.wish and midair.tint and midair.undo_steps == 0 and not midair.handful_active,"undo in the air restores")
	# Shift still clears by painting: no handful.
	Input.parse_input_event(_shift(true))
	point = screen_of(Vector2(0.0,0.0))
	editor.pointer_override = point
	mouse(point,true)
	var shift := {"handful":editor._handful_holding,"painting":editor._painting}
	mouse(point,false)
	Input.parse_input_event(_shift(false))
	editor.pointer_override = null
	await wait_quiet([])
	print("SHIFT ",JSON.stringify(shift))
	check(not shift.handful and shift.painting,"Shift paints a clearing")
	# With the handful off (--paint-forest) a press paints as before.
	editor.seed_handful = false
	point = screen_of(Vector2(-2.0,-1.0))
	editor.pointer_override = point
	mouse(point,true)
	var painted := {"handful":editor._handful_holding,"painting":editor._painting}
	for _frame in range(10): await process_frame
	mouse(point,false)
	editor.pointer_override = null
	await wait_quiet([])
	editor.seed_handful = true
	print("PAINT ",JSON.stringify(painted))
	check(not painted.handful and painted.painting,"--paint-forest paints")
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
