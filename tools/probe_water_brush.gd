extends SceneTree
## Headless probe of the water brush's settling (scripts/water_brush.gd).
## Opens the product scene on a plain, pours at a few points (a hollow, a
## hilltop, a long pour that overflows) and prints each plan: ponds, their
## depth and rise, streams, delays and planning time. Nothing is rendered.
##   -- --plain-seed 7 [--volume=seconds] [--land]
## --land first raises a ridge through the middle, so there is a hill to pour on.
var scene: Node3D
var editor: NativeChunkEditor

func _initialize() -> void: run.call_deferred()

func pour(label: String, points: Array, seconds: float) -> void:
	editor.water_brush.begin()
	for point: Vector2 in points:
		for tick in range(int(seconds*30.0/points.size())):
			editor.water_brush.dab(editor.data,point,editor.water_brush.radius,editor.water_brush.strength/30.0,false)
	var dabs: PackedVector3Array = editor.water_brush.dabs
	var detached := preload("res://scripts/native_terrain_snapshot.gd").for_height(editor.data)
	var plan: Dictionary = preload("res://scripts/water_brush.gd").plan(detached,editor.data.ponds.duplicate(true),editor.data.streams.duplicate(true),dabs,true)
	var ponds := []
	for entry: Dictionary in plan.added:
		ponds.append({"x":snappedf(entry.record.x,0.01),"z":snappedf(entry.record.z,0.01),"level":snappedf(entry.record.level,0.001),"drop":snappedf(entry.drop,0.001),"delay":snappedf(entry.delay,0.01),"rect":str(entry.rect)})
	var streams := []
	for entry: Dictionary in plan.added_streams:
		var pts: Array = entry.record.pts
		streams.append({"points":pts.size(),"from":[snappedf(pts[0].x,0.1),snappedf(pts[0].z,0.1),snappedf(pts[0].h,0.01)],"to":[snappedf(pts[-1].x,0.1),snappedf(pts[-1].z,0.1),snappedf(pts[-1].h,0.01)],"width":snappedf(entry.record.width,0.01),"delay":snappedf(entry.delay,0.01),"seconds":snappedf(entry.seconds,0.01)})
	var poured := 0.0
	for d in dabs: poured += d.z
	var summary := {"label":label,"dabs":dabs.size(),"poured_m3":snappedf(poured,0.01),"plan_ms":snappedf(plan.usec/1000.0,0.1),"ponds_total":plan.ponds.size(),"new_ponds":ponds,"new_streams":streams,"rect":str(plan.rect),"scoops":plan.scoops,"lips":plan.get("lips",0),"beds":plan.get("beds",false)}
	# Apply as the editor does, so the next pour sees this water.
	if plan.changed:
		editor.data.begin_stroke()
		if plan.has("heights"): editor.data.heights = plan.heights
		editor.data.ponds.assign(plan.ponds)
		editor.data.streams.assign(plan.streams)
		editor.data.end_stroke()
	summary["level_at_pour"] = snappedf(_level_over(points[0]),0.001)
	print("POUR ",JSON.stringify(summary))

func run() -> void:
	create_timer(120).timeout.connect(func() -> void: push_error("Water probe timed out"); quit(2))
	root.size = Vector2i(1280,800)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-water-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	editor = scene._chunk_editor
	editor.set_process(false)
	var seconds := 3.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--volume="): seconds = float(arg.trim_prefix("--volume="))
	if "--land" in OS.get_cmdline_user_args():
		editor.land_brush.prepare(editor.data,editor.land_seed)
		editor.land_brush.begin()
		editor.data.begin_stroke()
		for i in range(90):
			editor.land_brush.dab(editor.data,Vector2(-6.0+i*0.12,1.0),4.5,1.0/30.0,false,editor.land_ceiling)
		editor.data.end_stroke()
	var heights: PackedFloat32Array = editor.data.heights
	var low := 0
	var high := 0
	for i in range(heights.size()):
		if absf(editor.data.points[i].x) > 11.0 or absf(editor.data.points[i].y) > 11.0: continue
		if heights[i] < heights[low] or absf(editor.data.points[low].x) > 11.0 or absf(editor.data.points[low].y) > 11.0: low = i
		if heights[i] > heights[high] or absf(editor.data.points[high].x) > 11.0 or absf(editor.data.points[high].y) > 11.0: high = i
	print("PLAIN ",JSON.stringify({"low":[str(editor.data.points[low]),heights[low]],"high":[str(editor.data.points[high]),heights[high]]}))
	pour("hollow",[editor.data.points[low]],seconds)
	pour("hilltop",[editor.data.points[high]],seconds)
	pour("long pour in the hollow",[editor.data.points[low]],seconds*4.0)
	pour("stroke across",[Vector2(-4,-2.5),Vector2(-1,-1),Vector2(3,2)],seconds)
	# The pond nearest the plate's rim, poured into until it brims there: it
	# should raise a lip at the rim and rise, not only deepen.
	var rim_pond: Dictionary = {}
	for pond: Dictionary in editor.data.ponds:
		if rim_pond.is_empty() or maxf(absf(pond.x),absf(pond.z)) > maxf(absf(rim_pond.x),absf(rim_pond.z)): rim_pond = pond
	if not rim_pond.is_empty():
		var before_level: float = rim_pond.level
		pour("into the rim pond",[Vector2(rim_pond.x,rim_pond.z)],seconds*4.0)
		pour("into the rim pond again",[Vector2(rim_pond.x,rim_pond.z)],seconds*4.0)
		print("RIM ",JSON.stringify({"at":[rim_pond.x,rim_pond.z],"level_before":snappedf(before_level,0.001),"level_after":snappedf(_level_over(Vector2(rim_pond.x,rim_pond.z)),0.001)}))

	scene.queue_free()
	for _frame in range(3): await process_frame
	quit()

## The level of the pond whose drawn surface covers `point`, or -1 if none.
func _level_over(point: Vector2) -> float:
	var level := -1.0
	for pond: Dictionary in editor.data.ponds:
		for v in NativeGardenWater.surface(editor.data,pond):
			if Vector2(v.x,v.z).distance_to(point) < 0.8:
				level = maxf(level,float(pond.level))
				break
	return level
