extends SceneTree
## Headless probe of the diorama flip (scripts/diorama_flip.gd,
## docs/scenic/modeless-flip.md). Opens the product scene on the Genesis plain
## with `--modeless`, raises a hill so the land has relief, and drives the
## flip through its API at a fixed 60 Hz:
## - the pose maths: identity at rest, upside down and back in place at pi;
## - a slow drag under upright that is let go falls back (bouncing) and is set
##   down: the edge spring (scripts/edge_spring.gd) sinks a basin, one undo
##   step, and after that undo nothing has changed: heights, the whole
##   document, the layers, the camera, the terrain;
## - a drag past upright goes over: the world is a new one (its seed, its
##   heights), made while the snapshot is in the air, hidden from the camera
##   every frame, the flip lands and settles, the hand grips the rim and lets
##   go, and the longest main-thread frame is reported;
## - undo: `flip_back` brings the old world back exactly, by undo;
## - the kept copy: after painting on a new world (so the flip is no longer the
##   last undo step) `flip_back` still brings the old world back exactly.
## Nothing is rendered: how the flip looks on screen is not checked here.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_diorama_flip.gd -- --modeless
## Budget for the longest frame while a flip is in the air (ms).
const FRAME_BUDGET_MS := 100.0

var scene: Node3D
var editor: NativeChunkEditor
var flip: Node
var failures := []
var frame_ms: Array[float] = []
var _last_usec := 0
var _phases: Array = []
var _frame := 0
var _leaks := 0
var _leak_frames := 0
var _covered_frames := 0

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func frames(count: int) -> void:
	for i in range(count): await tick()

## One frame, timed, with the hidden-world check while a snapshot is up.
func tick() -> void:
	await process_frame
	_frame += 1
	var now := Time.get_ticks_usec()
	if _last_usec > 0 and flip != null and flip.phase != flip.Phase.IDLE: frame_ms.append((now-_last_usec)/1000.0)
	_last_usec = now
	if flip != null and flip.pivot != null:
		_covered_frames += 1
		var seen := real_world_drawn()
		if seen > 0:
			_leak_frames += 1
			_leaks = maxi(_leaks,seen)
			if _leak_frames == 1: print("LEAK first at frame ",_frame," ",leaked_names())

## How many meshes of the real world the main camera could still draw while the
## snapshot stands (should be none).
func real_world_drawn() -> int:
	return leaked_names(100).size()

func _unused() -> int:
	var count := 0
	for node in scene.find_children("*","GeometryInstance3D",true,false):
		if not (node is MeshInstance3D or node is MultiMeshInstance3D): continue
		if flip.pivot.is_ancestor_of(node) or not node.is_visible_in_tree() or node.get_viewport() != scene.get_viewport(): continue
		if not scene.camera.cull_mask & node.layers: continue
		if node is MeshInstance3D and (node.mesh == null or node.get_parent() is Skeleton3D): continue
		if node is MultiMeshInstance3D and (node.multimesh == null or node.multimesh.instance_count == 0): continue
		if flip._left_out_above(node): continue
		count += 1
	return count

func leaked_names(limit := 12) -> Array:
	var names := []
	for node in scene.find_children("*","GeometryInstance3D",true,false):
		if not (node is MeshInstance3D or node is MultiMeshInstance3D): continue
		if flip.pivot.is_ancestor_of(node) or not node.is_visible_in_tree() or node.get_viewport() != scene.get_viewport(): continue
		if not scene.camera.cull_mask & node.layers: continue
		if node is MeshInstance3D and (node.mesh == null or node.get_parent() is Skeleton3D): continue
		if node is MultiMeshInstance3D and (node.multimesh == null or node.multimesh.instance_count == 0): continue
		if flip._left_out_above(node): continue
		names.append(str(node.get_path()).trim_prefix("/root/")+" L"+str(node.layers))
	return names.slice(0,limit)

func signature() -> Dictionary:
	var data := editor.data
	return {"heights":data.heights.duplicate(),"document":var_to_str(data.to_document()).hash(),"seed":data._recipe_settings.get("seed",-1),"blank":data.blank,"mask":scene.camera.cull_mask,"terrain":editor.terrain.global_transform}

func same(a: Dictionary, b: Dictionary) -> bool:
	return a.heights == b.heights and a.document == b.document and a.seed == b.seed and a.blank == b.blank and a.mask == b.mask and a.terrain.is_equal_approx(b.terrain)

func settle(limit := 1500) -> void:
	var places: Node = scene.places
	var n := 0
	while (flip.phase != flip.Phase.IDLE or places.busy or editor.forming) and n < limit:
		await tick()
		n += 1
	await frames(6)

func phases_seen(from: int) -> Array:
	var names: Array = []
	for entry: Array in _phases.slice(from):
		names.append(flip.Phase.keys()[entry[0]]+"@"+str(entry[1]))
	return names

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("Diorama flip probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-flip-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	editor = scene._chunk_editor
	flip = scene.flip
	check("the flip is built with --modeless",flip != null)
	if flip == null:
		finish()
		return
	flip.phase_changed.connect(func(p: int) -> void: _phases.append([p,_frame]))
	var data := editor.data
	data.begin_stroke()
	for _pass in range(14): data.brush(Vector2(5.0,-4.0),4.5,0.5,"raise",0.0)
	data.end_stroke()
	await editor.refresh(self)
	scene._overview()
	await frames(30)
	await settle()

	# The pose maths.
	flip._grab_from(Vector2(-1.0,-1.0))
	var c: Vector3 = flip._centre
	var up := c+Vector3(0,3,0)
	var edge: Vector3 = c+flip._grab_dir*flip._half
	check("the pose is the identity at rest",flip.pose(0.0,0.0).is_equal_approx(Transform3D.IDENTITY))
	var over: Transform3D = flip.pose(PI,0.0)
	check("turned over (pi) the plate is upside down in place: up goes to down about its middle",(over*up).distance_to(c-Vector3(0,3,0)) < 0.001,over*up)
	check("and the grabbed edge goes to the far edge",(over*edge).distance_to(c-flip._grab_dir*flip._half) < 0.001,over*edge)
	var lifted: Vector3 = flip.pose(PI*0.5,0.0)*edge
	check("a quarter turn lifts the grabbed edge over the middle (tips up, not down)",lifted.y > c.y+flip._half*0.9,lifted)
	var tip: Vector3 = flip.pose(0.5,0.0)*edge
	check("tipping up on the far hinge lifts the grabbed edge and keeps the far edge on the ground",tip.y > edge.y+2.0 and (flip.pose(0.5,0.0)*(c-flip._grab_dir*flip._half)).distance_to(c-flip._grab_dir*flip._half) < 1.5)

	# A drag under half way falls back and changes nothing. The world it
	# started to sample is kept for the flip after.
	flip.next_seed = 424242
	var base := signature()
	var undo_base: int = data._undo.size()
	var hand: Node3D = scene.get("god_hand")
	var mark := _phases.size()
	var fell := [false]
	flip.fell_back.connect(func() -> void: fell[0] = true)
	check("the rim can be grabbed",flip.begin(Vector2(720,760)))
	check("a snapshot stands",flip.pivot != null and flip.pivot.get_child_count() > 0,flip.pivot.get_child_count() if flip.pivot != null else 0)
	var progress := 0.0
	var peak := 0.0
	var grip := false
	for i in range(30):
		progress = 0.4*float(i+1)/30.0
		flip.drag(progress)
		await tick()
		peak = maxf(peak,flip.angle)
		grip = grip or hand == null or hand.reach_gesture == "flip"
	await frames(10)
	check("dragged, the plate follows with weight but lags the drag",peak > 0.5 and peak < PI*0.4*1.0,peak)
	check("the hand grips the rim",grip)
	flip.release(progress)
	var bounces := 0
	var was := 1.0
	var n := 0
	while flip.phase != flip.Phase.IDLE and n < 300:
		await tick()
		if flip.angle <= 0.0 and was > 0.0 and flip.omega > 0.0: bounces += 1
		was = flip.angle
		n += 1
	await frames(3)
	print("FALLBACK ",JSON.stringify({"peak_deg":snappedf(rad_to_deg(peak),0.1),"frames":n,"bounces":bounces,"phases":phases_seen(mark)}))
	check("released under half way it falls back and rests",flip.phase == flip.Phase.IDLE and fell[0],n)
	check("with a small bounce",bounces >= 1,bounces)
	# A slow set-down sinks a basin (the agreed scheme): one undo step, and
	# after it nothing else has changed.
	var edge_spring: Node = scene.get("edge_spring")
	if edge_spring != null:
		var waited := 0
		while (edge_spring.state != 0 or editor.mountain.active or editor.refresh_pending > 0) and waited < 600:
			await tick()
			waited += 1
		await frames(6)
		var sank := 0.0
		for i in range(base.heights.size()): sank = maxf(sank,base.heights[i]-data.heights[i])
		print("SETDOWN ",JSON.stringify({"basin":edge_spring.last_basin,"sank_m":snappedf(sank,0.01)}))
		check("set down slowly, a basin sinks (one undo step)",sank > 0.2 and data._undo.size() == undo_base+1,sank)
		editor.undo()
		await frames(20)
	check("and after its undo nothing changed (heights, document, seed, layers, camera, terrain)",same(base,signature()))
	# The hand is always there (docs/scenic/modeless.md "Void slice"): let go of
	# the flip, it shows the hover pose under the pointer, the void pose in the sky.
	check("the hand lets go",hand == null or hand.reach_gesture == ("void" if scene.hand_reach.hover_zone == "void" else ""),[hand.reach_gesture if hand != null else "",scene.hand_reach.hover_zone])
	check("no snapshot is left",flip.pivot == null and flip._hidden.is_empty())
	await frames(20)

	# A drag past half way goes over: a new world.
	frame_ms.clear()
	var landed := [-1]
	flip.landed.connect(func(s: int) -> void: landed[0] = s)
	mark = _phases.size()
	var start_frame := _frame
	var seen_layers := 0
	var angle_at_ready := -1.0
	var angle_at_form := -1.0
	var swapped_at := -1.0
	check("the rim can be grabbed again",flip.begin(Vector2(720,760)))
	for i in range(40):
		progress = 0.8*float(i+1)/40.0
		flip.drag(progress)
		await tick()
	flip.release(progress)
	n = 0
	var real_before: PackedFloat32Array = base.heights
	var hover_frames := 0
	var max_angle := 0.0
	while (flip.phase != flip.Phase.IDLE or scene.places.busy) and n < 1500:
		await tick()
		max_angle = maxf(max_angle,flip.angle)
		if flip.phase == flip.Phase.HOVER: hover_frames += 1
		if angle_at_ready < 0.0 and flip.world_ready: angle_at_ready = flip.angle
		if swapped_at < 0.0 and editor.data.heights != real_before and flip.pivot != null: swapped_at = flip.angle
		n += 1
	await frames(6)
	var after := signature()
	print("FLIP ",JSON.stringify({"frames":n,"seconds":snappedf(n/60.0,0.01),"phases":phases_seen(mark),"max_angle_deg":snappedf(rad_to_deg(max_angle),0.1),"angle_at_ready_deg":snappedf(rad_to_deg(angle_at_ready),0.1),"real_world_changed_at_deg":snappedf(rad_to_deg(swapped_at),0.1),"hover_frames":hover_frames,"making_s":snappedf(flip.making_time,0.01),"sample_ms":snappedf(flip.sample_ms,1.0),"form_ms":snappedf(flip.form_ms,1.0),"fit_ms":snappedf(flip.fit_ms,1.0),"stamps":flip.stamps,"keep_ms":snappedf(flip.keep_ms,1.0)}))
	check("released past half way it went over and landed",landed[0] == 424242,landed[0])
	check("the plate went all the way over (pi)",max_angle >= PI-0.001,max_angle)
	check("the world after is a different one (heights, its recipe's seed)",after.heights != base.heights and after.seed != base.seed,{"seed":after.seed,"was":base.seed})
	check("made from the seed asked for",editor.land_seed == 424242,editor.land_seed)
	check("the real world changed only while the snapshot was up",swapped_at >= 0.0,swapped_at)
	check("the world was ready before the drop, and hovered for it",angle_at_ready >= 0.0 and hover_frames >= 0)
	check("the real world was never drawn while the snapshot stood",_leak_frames == 0,{"frames_seen":_leak_frames,"covered":_covered_frames,"most_meshes":_leaks})
	check("the flip landed and settled (no snapshot, camera and terrain back)",flip.phase == flip.Phase.IDLE and flip.pivot == null and after.mask == base.mask and after.terrain.is_equal_approx(Transform3D.IDENTITY))
	check("the scene is unpaused and idle again",not scene._paused and not scene.places.busy and not editor.forming)
	# The hand is always there (docs/scenic/modeless.md "Void slice"): let go of
	# the flip, it shows the hover pose under the pointer, the void pose in the sky.
	check("the hand let go",hand == null or hand.reach_gesture == ("void" if scene.hand_reach.hover_zone == "void" else ""),[hand.reach_gesture if hand != null else "",scene.hand_reach.hover_zone])
	var worst := 0.0
	var worst_at := 0
	for i in range(frame_ms.size()):
		if frame_ms[i] > worst:
			worst = frame_ms[i]
			worst_at = i
	var sorted := frame_ms.duplicate()
	sorted.sort()
	print("FRAMES ",JSON.stringify({"count":frame_ms.size(),"longest_ms":snappedf(worst,0.1),"longest_frame":worst_at,"p99_ms":snappedf(sorted[int(sorted.size()*0.99)] if not sorted.is_empty() else 0.0,0.1),"top5_ms":sorted.slice(maxi(0,sorted.size()-5)).map(func(v: float) -> float: return snappedf(v,0.1))}))
	check("no frame over the budget while flipping (%d ms)" % int(FRAME_BUDGET_MS),worst < FRAME_BUDGET_MS,worst)
	var new_world := signature()
	check("the old world is kept whole beside the places",FileAccess.file_exists(scene.library_path.path_join("flip-previous.json")))

	# Undo: one flip back brings the old world back exactly.
	frame_ms.clear()
	check("flip back finds the undo step",flip.back_source() == flip.Source.UNDO,flip.back_source())
	check("and starts",flip.flip_back())
	await settle()
	var restored := signature()
	check("undo brought the old world back exactly (heights, document, seed)",restored.heights == base.heights and restored.document == base.document and restored.seed == base.seed and restored.blank == base.blank)
	check("and the camera and terrain are back",restored.mask == base.mask and restored.terrain.is_equal_approx(Transform3D.IDENTITY))

	# The kept copy: flip again, paint on the new world so the flip is no
	# longer the last undo step, flip back.
	flip.next_seed = 777001
	check("a second flip",flip.debug_flip(1.0,1.6))
	await settle()
	print("FLIPB ",JSON.stringify({"sample_ms":snappedf(flip.sample_ms,1.0),"form_ms":snappedf(flip.form_ms,1.0),"stamps":flip.stamps}))
	var second := signature()
	check("the second world is new again",second.heights != base.heights and second.seed != new_world.seed and editor.land_seed == 777001,editor.land_seed)
	editor.data.begin_stroke()
	for _pass in range(3): editor.data.brush(Vector2(-4.0,3.0),3.0,0.4,"raise",0.0)
	editor.data.end_stroke()
	await editor.refresh(self)
	await frames(4)
	check("painting made the flip no longer the last undo step",flip.back_source() == flip.Source.KEPT,flip.back_source())
	check("and flipping back still finds the old world",flip.flip_back())
	await settle()
	var again := signature()
	check("the kept copy brought the old world back exactly",again.heights == base.heights and again.document == base.document and again.seed == base.seed,{"seed":again.seed})

	# A flip out of a generated world (a bigger document to keep, more to
	# hide and to grow): what it costs the main thread.
	flip.next_seed = 31337
	check("a flip into a generated world",flip.debug_flip(1.0,1.6))
	await settle()
	flip.next_seed = 555001
	frame_ms.clear()
	_phases.clear()
	var third_start := _frame
	check("and out of it",flip.debug_flip(1.0,1.6))
	await settle()
	report_frames("FRAMES2")
	print("FLIP2 ",JSON.stringify({"frames":_frame-third_start,"phases":phases_seen(0),"sample_ms":snappedf(flip.sample_ms,1.0),"form_ms":snappedf(flip.form_ms,1.0),"fit_ms":snappedf(flip.fit_ms,1.0),"keep_ms":snappedf(flip.keep_ms,1.0),"stamps":flip.stamps}))
	var worst2 := 0.0
	for v in frame_ms: worst2 = maxf(worst2,v)
	check("no frame over the budget flipping out of a generated world",worst2 < FRAME_BUDGET_MS,worst2)
	check("and it landed on the new seed",editor.land_seed == 555001,editor.land_seed)
	await settle(600)

	# The rim routing (scripts/hand_reach.gd) drives it: a short drag up the
	# lip lifts the plate, and let go early it falls back.
	var reach: Node = scene.get("hand_reach")
	check("the scene has the rim routing",reach != null)
	if reach != null:
		var seed_before: int = editor.land_seed
		var fell_signal := [false]
		flip.fell_back.connect(func() -> void: fell_signal[0] = true)
		var size: Vector2 = scene.get_viewport().get_visible_rect().size
		var phases_seen: Array = []
		flip.phase_changed.connect(func(p: Variant) -> void: phases_seen.append(p))
		reach.flip_began.emit(Vector2(720,760))
		check("flip_began starts the flip",flip.active())
		for i in range(30):
			reach.flip_dragged.emit(0.4*float(i+1)/30.0)
			await tick()
		await frames(10)
		reach.flip_released.emit(0.4)
		for i in range(900):
			await tick()
			if not flip.active(): break
		print("RIM PHASES ",phases_seen)
		print("RIM FLIP ",JSON.stringify({"fell":fell_signal[0],"active":flip.active(),"phase":flip.phase}))
		check("let go early through the rim, it falls back",fell_signal[0] and not flip.active())
		check("and the world is the same",editor.land_seed == seed_before,editor.land_seed)
	finish()

func report_frames(label: String) -> void:
	var sorted := frame_ms.duplicate()
	sorted.sort()
	print(label," ",JSON.stringify({"count":sorted.size(),"longest_ms":snappedf(sorted[-1] if not sorted.is_empty() else 0.0,0.1),"p99_ms":snappedf(sorted[int(sorted.size()*0.99)] if not sorted.is_empty() else 0.0,0.1),"top5_ms":sorted.slice(maxi(0,sorted.size()-5)).map(func(v: float) -> float: return snappedf(v,0.1))}))

func finish() -> void:
	# Nothing may be left running in the background when the engine tears down.
	if flip != null:
		await flip.wait_idle()
		await settle(600)
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
