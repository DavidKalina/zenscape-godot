extends SceneTree
## Headless probe of the land brush's mountain forms (scripts/mountain_forms.gd,
## docs/scenic/brushes.md "Mountain forms"). On the Genesis plain, for each
## form: press, drag out for `--hold` seconds, release, let it finish rising,
## land and weather, then undo and redo it. Prints the shape (peak, lift,
## slopes, rock and snow faces, painted rock cells), what the weathering did,
## main-thread cost (rise ticks, frame gaps, reshape) and the undo round trip.
## Then digs a pond and raises a peak beside it to check the water keep-out.
##   -- --forms=alpine,ridge --hold=1.0 --drag=2.5 --at=-1,0.5
## Frame gaps are CPU main-loop intervals under the dummy renderer.
var scene: Node3D
var editor: NativeChunkEditor
var forms: Array = ["alpine","ridge","mesa","volcano","tors"]
var hold := 1.0
var drag := 2.5
var at := Vector2(-1.0,0.5)
var _before_weather := PackedFloat32Array()
## --watch=S: raise a last alpine peak, keep it, and let emergence run S s.
var watch := 0.0

func _initialize() -> void: run.call_deferred()

func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	return {"n":sorted.size(),"median":snappedf(sorted[sorted.size()/2],0.01),"p95":snappedf(sorted[mini(sorted.size()-1,int(sorted.size()*0.95))],0.01),"max":snappedf(sorted.back(),0.01)}

## Faces the mesh builder would paint rock (steeper than the plain's rock
## slope, or above the snowline less 1.8 m) and snow, over lifted ground.
func faces(heights: PackedFloat32Array, base: PackedFloat32Array) -> Dictionary:
	var data := editor.data
	var snowline: float = data._palette.snowline
	var rock_slope: float = data._palette.rock_slope
	var counts := {"lifted":0,"rock":0,"snow":0,"slope_median":0.0,"slope_max":0.0}
	var slopes := []
	var ids := data.vertex_ids
	for f in range(0,ids.size(),3):
		var a := Vector3(data.points[ids[f]].x,heights[ids[f]],data.points[ids[f]].y)
		var b := Vector3(data.points[ids[f+1]].x,heights[ids[f+1]],data.points[ids[f+1]].y)
		var c := Vector3(data.points[ids[f+2]].x,heights[ids[f+2]],data.points[ids[f+2]].y)
		var lift := (heights[ids[f]]+heights[ids[f+1]]+heights[ids[f+2]]-base[ids[f]]-base[ids[f+1]]-base[ids[f+2]])/3.0
		if lift < 0.1: continue
		counts.lifted += 1
		var normal := (c-a).cross(b-a).normalized()
		var slope := sqrt(maxf(0.0,1.0-normal.y*normal.y))/maxf(absf(normal.y),0.001)
		slopes.append(slope)
		var y := (a.y+b.y+c.y)/3.0
		if y > snowline and slope < 2.4: counts.snow += 1
		elif y > snowline-1.8 or slope > rock_slope: counts.rock += 1
	if not slopes.is_empty():
		slopes.sort()
		counts.slope_median = snappedf(slopes[slopes.size()/2],0.01)
		counts.slope_max = snappedf(slopes.back(),0.01)
	return counts

func tinted(tint: PackedFloat32Array, before: PackedFloat32Array) -> int:
	var count := 0
	for k in range(3,tint.size(),4):
		if tint[k] != before[k]: count += 1
	return count

func wait_settled(frames: Array) -> void:
	var previous := Time.get_ticks_usec()
	var quiet := 0
	while quiet < 20:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now-previous)/1000.0)
		previous = now
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0
		quiet = 0 if busy else quiet+1

## One mountain: press at `center`, drag toward `toward` over `hold` s.
func raise(form: String, center: Vector2, toward: Vector2) -> Dictionary:
	var data := editor.data
	editor.select_land_form(form)
	var base := data.heights.duplicate()
	var tint := data.tint.duplicate()
	var ground := float(data.sample(center,data.heights))
	var ticks := []
	var reshapes := []
	var frames := []
	var began := Time.get_ticks_usec()
	editor._mountain_press(Vector3(center.x,ground,center.y))
	var press_ms := (Time.get_ticks_usec()-began)/1000.0
	var previous := Time.get_ticks_usec()
	var held := 0.0
	while held < hold:
		await process_frame
		var now := Time.get_ticks_usec()
		var delta := (now-previous)/1000000.0
		frames.append((now-previous)/1000.0)
		previous = now
		held += delta
		var tick := Time.get_ticks_usec()
		if editor.mountain.aim(data,center.lerp(toward,clampf(held/hold,0.0,1.0))): reshapes.append(editor.mountain.last_shape_usec/1000.0)
		editor._mountain_tick(delta)
		ticks.append((Time.get_ticks_usec()-tick)/1000.0)
	var rise_at_release: float = editor.mountain.rise
	var release := Time.get_ticks_usec()
	editor.finish_stroke()
	var release_ms := (Time.get_ticks_usec()-release)/1000.0
	var spread: float = editor.mountain.spread
	var height: float = editor.mountain.height
	_before_weather = PackedFloat32Array()
	var landed := Time.get_ticks_usec()
	await wait_settled(frames)
	var settle_ms := (Time.get_ticks_usec()-landed)/1000.0
	var final := data.heights.duplicate()
	var lifted := 0
	var peak := -INF
	for i in range(final.size()):
		if final[i]-base[i] > 0.1: lifted += 1
		peak = maxf(peak,final[i])
	var weather := {}
	if not _before_weather.is_empty():
		var cut := 0.0
		var fill := 0.0
		var moved := 0
		for i in range(final.size()):
			var change := final[i]-_before_weather[i]
			if absf(change) > 0.01: moved += 1
			cut = minf(cut,change)
			fill = maxf(fill,change)
		weather = {"moved":moved,"deepest_cut":snappedf(cut,0.01),"highest_fill":snappedf(fill,0.01),"usec":editor.land_brush.last_weather_usec}
	var report := {"form":form,"spread":snappedf(spread,0.01),"height":snappedf(height,0.01),"ground":snappedf(ground,0.01),"peak":snappedf(peak,0.01),
		"lifted_vertices":lifted,"faces":faces(final,base),"faces_before_weather":faces(_before_weather,base) if not _before_weather.is_empty() else {},
		"tinted_cells":tinted(data.tint,tint),"weather":weather,"rise_at_release":snappedf(rise_at_release,0.01),"press_ms":snappedf(press_ms,0.01),
		"tick_ms":stats(ticks),"reshape_ms":stats(reshapes),"release_ms":snappedf(release_ms,0.01),"settle_ms":snappedf(settle_ms,0.1),"frames_ms":stats(frames),
		"frames_over_16_7":frames.filter(func(v: float) -> bool: return v > 16.667).size(),"undo_steps":data._undo.size()}
	# One undo takes the whole mountain, weathering and rock colour; redo
	# brings it all back.
	editor.undo()
	await wait_settled([])
	report["undo_restores"] = data.heights == base and data.tint == tint
	editor.redo()
	await wait_settled([])
	report["redo_restores"] = data.heights == final
	editor.undo()
	await wait_settled([])
	return report

func pond_check() -> Dictionary:
	var data := editor.data
	var hollow := Vector2(3.0,-2.0)
	editor.select_land_form("hill")
	editor.land_brush.prepare(data,editor.land_seed)
	data.begin_stroke()
	for k in range(40): editor.land_brush.dab(data,hollow,2.2,0.1,true,10.0)
	var floor_h := float(data.sample(hollow,data.heights))
	var added := data.add_pond(hollow,floor_h+0.35)
	data.end_stroke()
	await editor.refresh(self)
	if not added: return {"pond":false}
	var surface_before := data.pond_surface(data.ponds[0]).size()
	var pond := data.ponds[0].duplicate()
	var base := data.heights.duplicate()
	var near := hollow+Vector2(-3.2,0.0)
	var ground := float(data.sample(near,data.heights))
	editor.select_land_form("alpine")
	editor._mountain_press(Vector3(near.x,ground,near.y))
	editor.mountain.aim(data,near+Vector2(-2.0,0.0))
	editor.finish_stroke()
	await wait_settled([])
	var surface_after := data.pond_surface(data.ponds[0]).size() if not data.ponds.is_empty() else 0
	var wet_moved := 0.0
	for v in data.pond_surface(pond):
		var p := Vector2(v.x,v.z)
		wet_moved = maxf(wet_moved,absf(float(data.sample(p,data.heights))-float(data.sample(p,base))))
	var lift_max := 0.0
	for i in range(base.size()): lift_max = maxf(lift_max,data.heights[i]-base[i])
	return {"pond":true,"ponds_after":data.ponds.size(),"surface_triangles_before":surface_before/3,"surface_triangles_after":surface_after/3,"max_ground_change_under_pond":snappedf(wet_moved,0.001),"mountain_lift":snappedf(lift_max,0.01)}

## A second press while the first mountain still rises lands the first (at
## full height, weathered), so each keeps its own undo step.
func interrupt_check() -> Dictionary:
	var data := editor.data
	var base := data.heights.duplicate()
	var steps: int = data._undo.size()
	var first := Vector2(-4.0,3.0)
	var second := Vector2(4.0,-3.5)
	editor.select_land_form("volcano")
	editor._mountain_press(Vector3(first.x,float(data.sample(first,data.heights)),first.y))
	editor.finish_stroke()
	for _frame in range(6): await process_frame
	var rise_when_interrupted: float = editor.mountain.rise
	editor.select_land_form("ridge")
	editor._mountain_press(Vector3(second.x,float(data.sample(second,data.heights)),second.y))
	var first_peak := 0.0
	for i in range(base.size()):
		if data.points[i].distance_to(first) < 2.0: first_peak = maxf(first_peak,data.heights[i]-base[i])
	editor.finish_stroke()
	await wait_settled([])
	var report := {"rise_when_interrupted":snappedf(rise_when_interrupted,0.01),"first_lift_at_second_press":snappedf(first_peak,0.01),"undo_steps_added":data._undo.size()-steps}
	editor.undo()
	editor.undo()
	await wait_settled([])
	report["two_undos_restore"] = data.heights == base
	# The palette's form row follows the editor, and 1 steps the form.
	var palette: Control = scene.creation_palette
	editor.select_land_form("hill")
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	scene.brush = "land"
	var crafting: bool = scene.crafting
	scene.crafting = false
	var creating: bool = scene._creating()
	scene._creation_key(key)
	palette.sync()
	report["key_1_steps_to"] = editor.land_form
	report["creating"] = creating
	report["palette_row_visible"] = palette.form_frame.visible
	report["palette_pressed"] = palette.form_buttons.keys().filter(func(id: String) -> bool: return palette.form_buttons[id].button_pressed)
	report["hint"] = palette.hint.text
	key.shift_pressed = true
	scene._creation_key(key)
	report["shift_1_steps_back_to"] = editor.land_form
	scene.crafting = crafting
	editor.select_land_form("hill")
	return report

## What emerges on a kept peak: emerged records on its lifted ground, by the
## slope under them against the rock slope, and cover on its steeps.
func emergence_check() -> Dictionary:
	var data := editor.data
	var base := data.heights.duplicate()
	var center := Vector2(-2.0,1.0)
	editor.select_land_form("alpine")
	editor._mountain_press(Vector3(center.x,float(data.sample(center,data.heights)),center.y))
	editor.mountain.aim(data,center+Vector2(1.5,0.5))
	editor.finish_stroke()
	await wait_settled([])
	editor.set_process(true)
	await create_timer(watch).timeout
	editor.set_process(false)
	var rock_slope: float = data._palette.rock_slope
	var counts := {"on_mountain":0,"on_gentle":0,"on_steep":0,"above_snowline_less_1":0,"kinds":{},"slope_max":0.0,"rock_slope":snappedf(rock_slope,0.01)}
	for item in data.objects:
		if NativeTerrainData.object_source(item) != "emerged": continue
		var p := Vector2(item.x,item.z)
		var lift := float(data.sample(p,data.heights))-float(data.sample(p,base))
		if lift < 0.3: continue
		counts.on_mountain += 1
		counts.kinds[item.asset] = counts.kinds.get(item.asset,0)+1
		var e := float(data.sample(p+Vector2(0.3,0),data.heights))-float(data.sample(p-Vector2(0.3,0),data.heights))
		var n := float(data.sample(p+Vector2(0,0.3),data.heights))-float(data.sample(p-Vector2(0,0.3),data.heights))
		var slope := Vector2(e,n).length()/0.6
		counts.slope_max = snappedf(maxf(float(counts.slope_max),slope),0.01)
		if slope > rock_slope: counts.on_steep += 1
		else: counts.on_gentle += 1
		if float(data.sample(p,data.heights)) > data._palette.snowline-1.0: counts.above_snowline_less_1 += 1
	counts["objects"] = data.objects.size()
	return counts

## The real input path: a mouse press through handle_input, the editor's own
## _process following a moving pointer (pointer_override), then a release.
func live_check() -> Dictionary:
	var data := editor.data
	var base := data.heights.duplicate()
	var camera: Camera3D = scene.camera
	var from := Vector2(0.5,-1.0)
	var to := from+Vector2(2.5,0.0)
	var start := camera.unproject_position(editor.terrain.to_global(Vector3(from.x,float(data.sample(from,data.heights)),from.y)))
	var finish := camera.unproject_position(editor.terrain.to_global(Vector3(to.x,float(data.sample(to,data.heights)),to.y)))
	editor.select_land_form("alpine")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	editor.pointer_override = start
	var took := editor.handle_input(press)
	var holding: bool = editor._mountain_holding
	editor.set_process(true)
	for frame in range(50):
		await process_frame
		editor.pointer_override = start.lerp(finish,minf(1.0,frame/40.0))
	var rise_held: float = editor.mountain.rise
	var spread_held: float = editor.mountain.spread
	var still_holding: bool = editor._mountain_holding
	var button_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = finish
	Input.parse_input_event(release)
	editor.handle_input(release)
	editor.pointer_override = null
	await wait_settled([])
	editor.set_process(false)
	var reach: Rect2 = editor.mountain.bounds.grow(1.5)
	var outside_moved := 0.0
	var peak := 0.0
	for i in range(base.size()):
		peak = maxf(peak,data.heights[i]-base[i])
		if not reach.has_point(data.points[i]): outside_moved = maxf(outside_moved,absf(data.heights[i]-base[i]))
	var report := {"press_taken":took,"holding_after_press":holding,"still_holding":still_holding,"button_down":button_down,"rise_while_held":snappedf(rise_held,0.01),"spread_while_held":snappedf(spread_held,0.01),
		"lift":snappedf(peak,0.01),"moved_outside_footprint":snappedf(outside_moved,0.001),"landed":not editor.mountain.active}
	editor.undo()
	await wait_settled([])
	report["undo_restores"] = data.heights == base
	editor.select_land_form("hill")
	return report

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--forms="): forms = Array(arg.trim_prefix("--forms=").split(","))
		if arg.begins_with("--hold="): hold = float(arg.trim_prefix("--hold="))
		if arg.begins_with("--drag="): drag = float(arg.trim_prefix("--drag="))
		if arg.begins_with("--watch="): watch = float(arg.trim_prefix("--watch="))
		if arg.begins_with("--at="):
			var parts := arg.trim_prefix("--at=").split(",")
			at = Vector2(float(parts[0]),float(parts[1]))
	create_timer(400).timeout.connect(func() -> void: push_error("Mountain probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-mountain-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	while true:
		while scene.places.busy or scene._chunk_editor.forming: await process_frame
		await create_timer(1.0).timeout
		if not scene.places.busy and not scene._chunk_editor.forming: break
	scene.set_building(true)
	editor = scene._chunk_editor
	# The probe stands in for the pointer; the editor's own loop would end a
	# stroke no button holds.
	editor.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	editor.select_tool("land")
	editor.select_brush("land")
	editor.land_weathered.connect(func(_bounds: Rect2) -> void: _before_weather = editor._weather_heights.duplicate())
	print("native kernel: ",preload("res://scripts/native_terrain_kernels.gd").get_kernel() != null," points ",editor.data.points.size()," snowline ",snappedf(editor.data._palette.snowline,0.01)," rock_slope ",snappedf(editor.data._palette.rock_slope,0.01))
	await create_timer(1.0).timeout
	for form: String in forms:
		var report := await raise(form,at,at+Vector2(1.0,0.35).normalized()*drag)
		print("FORM ",JSON.stringify(report))
	print("LIVE ",JSON.stringify(await live_check()))
	print("INTERRUPT ",JSON.stringify(await interrupt_check()))
	print("POND ",JSON.stringify(await pond_check()))
	if watch > 0.0: print("EMERGENCE ",JSON.stringify(await emergence_check()))
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit()
