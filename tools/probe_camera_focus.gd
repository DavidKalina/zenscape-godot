extends SceneTree
## Headless probe of the shell's camera (scripts/camera_rig.gd,
## docs/scenic/camera.md). Opens the product scene on the Genesis plain, raises
## a hill, digs a pond and stands a small wood, then drives the camera with
## synthesized input at a fixed 60 Hz: a double-click on a tree (with the land
## brush in hand, so the first click's dab must be taken back), a double-click
## on the pond and on bare ground, a right drag and its fling, trackpad swipes
## and pinches, a dive of wheel notches into the hill, R, Backspace, and a
## followed "creature" walking away. Prints each glide's path: settle time,
## the largest frame-to-frame step and change of step (jerk), the final
## distance and pivot, and the least ground clearance seen. Nothing is rendered.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_camera_focus.gd
var scene: Node3D
var editor: NativeChunkEditor
var rig: Node
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func click(at: Vector2, button := MOUSE_BUTTON_LEFT, double := false, pressed := true, shift := false, ctrl := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.double_click = double
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT and pressed else MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT and pressed else 0
	event.factor = 1.0
	root.push_input(event)

func motion(at: Vector2, relative: Vector2, mask := 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = mask
	root.push_input(event)

func frames(count: int) -> void:
	for i in range(count): await process_frame

## Step frames and describe the camera's path until it settles (or `most` frames).
func path(label: String, most := 150) -> Dictionary:
	var positions: Array[Vector3] = []
	var clearance := INF
	var settled := -1
	for i in range(most):
		await process_frame
		var eye: Vector3 = scene.camera.global_position
		positions.append(eye)
		var ground: Variant = rig.inspector.ground_y(eye)
		if ground != null: clearance = minf(clearance,eye.y-float(ground))
	# Settled: from here on within 1 % of the move (or 5 mm) of where it came to rest.
	var final: Vector3 = positions.back()
	var travel := positions[0].distance_to(final)
	for i in range(positions.size()-1,-1,-1):
		if positions[i].distance_to(final) > maxf(travel*0.01,0.005):
			settled = i+1
			break
	var step := 0.0
	var jerk := 0.0
	var reversals := 0
	for i in range(1,positions.size()):
		step = maxf(step,positions[i].distance_to(positions[i-1]))
		if i > 1:
			var a := positions[i]-positions[i-1]
			var b := positions[i-1]-positions[i-2]
			jerk = maxf(jerk,a.distance_to(b))
			if a.length() > 0.002 and b.length() > 0.002 and a.dot(b) < 0.0: reversals += 1
	var summary := {"label":label,"settle_s":snappedf(settled/60.0,0.01) if settled > 0 else -1,"max_step_m":snappedf(step,0.001),
		"max_jerk_m":snappedf(jerk,0.001),"reversals":reversals,"distance":snappedf(scene.distance,0.01),"pivot":str(scene.target.snapped(Vector3.ONE*0.01)),
		"polar":snappedf(scene.polar,0.001),"clearance_min":snappedf(clearance,0.01)}
	print("PATH ",JSON.stringify(summary))
	return summary

func screen_of(point: Vector3) -> Vector2:
	return scene.camera.unproject_position(point)

func run() -> void:
	create_timer(170).timeout.connect(func() -> void: push_error("Camera probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-camera-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	editor = scene._chunk_editor
	rig = scene.camera_rig
	var data := editor.data
	# A hill, a pond in a basin, and a small wood between them.
	var basin := Vector2(-3.0,2.0)
	var hill := Vector2(5.0,-4.0)
	data.begin_stroke()
	for _pass in range(6): data.brush(basin,4.2,0.3,"lower",0.0)
	for _pass in range(14): data.brush(hill,4.5,0.5,"raise",0.0)
	var bottom: float = data.ground_height(basin)
	data.add_pond(basin,bottom+0.75)
	for i in range(14):
		var p := basin+Vector2.from_angle(-1.2+float(i)*0.19)*(6.0+0.8*sin(float(i)*2.3))
		data.place("broadleaf" if i%3 else "tree",p,float(i),0.9)
	data.end_stroke()
	await editor.refresh(self)
	scene._overview()
	await frames(30)
	check("rig live on the plain",rig.live,{"brush":scene.brush,"creating":scene._creating()})
	print("START ",JSON.stringify({"distance":snappedf(scene.distance,0.01),"polar":snappedf(scene.polar,0.01),"pivot":str(scene.target)}))

	# Hover naming, and its cost.
	var tree: Dictionary = {}
	for item: Dictionary in data.objects:
		if item.asset == "broadleaf":
			tree = item
			break
	var tree_at: Vector3 = editor.terrain.to_global(data.object_position(tree)+Vector3.UP*1.5)
	var tree_point := screen_of(tree_at)
	var began := Time.get_ticks_usec()
	rig.inspector.ground_hit(tree_point+Vector2(1,0))
	print("COST ground ray %.2f ms" % ((Time.get_ticks_usec()-began)/1000.0))
	began = Time.get_ticks_usec()
	var found: Dictionary = rig.inspector.inspect(tree_point)
	# The dummy renderer keeps no MultiMesh transforms, so the triangle pick of
	# drawn instances cannot find a tree headless: say so, and frame it by record.
	var picked: bool = found.get("kind","") == "plant"
	print(("OK   " if picked else "SKIP ")+"hover names the tree  "+JSON.stringify({"title":found.get("title",""),"inspect_ms":snappedf((Time.get_ticks_usec()-began)/1000.0,0.01),"note":"" if picked else "instance pick unverified headless"}))
	var pond_point := screen_of(editor.terrain.to_global(Vector3(basin.x,bottom+0.75,basin.y)))
	var pond: Dictionary = rig.inspector.inspect(pond_point)
	check("hover names the pond",pond.get("kind","") == "pond",{"title":pond.get("title",""),"size":snappedf(float(pond.get("size",0)),0.01)})

	# Double-click the tree with the land brush in hand: glide there, and the
	# first click's dab comes back out.
	scene.select_brush("land")
	await frames(2)
	var heights_before: PackedFloat32Array = data.heights.duplicate()
	var undo_before: int = data._undo.size()
	click(tree_point)
	await frames(3)
	click(tree_point,MOUSE_BUTTON_LEFT,false,false)
	await frames(8)
	var dabbed: bool = data.heights != heights_before
	click(tree_point,MOUSE_BUTTON_LEFT,true)
	click(tree_point,MOUSE_BUTTON_LEFT,false,false)
	if not picked:
		await frames(2)
		rig.frame(rig.inspector.object_found(int(tree.id)))
	var glide := await path("focus tree")
	check("first click dabbed, then was taken back",dabbed and data.heights == heights_before and data._undo.size() == undo_before,{"dabbed":dabbed,"undo":[undo_before,data._undo.size()],"redo":data._redo.size()})
	check("tree framed",rig.focus.get("kind","") == "plant" and absf(scene.distance-glide.distance) < 0.01 and scene.distance < 20.0,{"title":rig.focus.get("title",""),"distance":scene.distance})
	check("glide settles in 0.6-1.3 s",glide.settle_s > 0.5 and glide.settle_s < 1.3,glide.settle_s)
	check("glide never reverses",glide.reversals == 0,glide.reversals)
	check("camera stays above ground",glide.clearance_min > 0.5,glide.clearance_min)

	# Right drag orbits with the brush in hand and paints nothing.
	var undo_now: int = data._undo.size()
	var yaw_before: float = scene.yaw
	var middle := Vector2(720,450)
	click(middle,MOUSE_BUTTON_RIGHT)
	for i in range(12):
		motion(middle+Vector2(i*14,0),Vector2(14,0),MOUSE_BUTTON_MASK_RIGHT)
		await process_frame
	click(middle+Vector2(168,0),MOUSE_BUTTON_RIGHT,false,false)
	var drag_yaw: float = scene.yaw
	var goal_yaw: float = rig._view_goal.x
	var fling := await path("right drag release",90)
	check("right drag orbits",absf(scene.yaw-yaw_before) > 0.5,{"turned":snappedf(scene.yaw-yaw_before,0.001),"after_release":snappedf(scene.yaw-drag_yaw,0.001),"fling_beyond_hand":snappedf(scene.yaw-goal_yaw,0.001)})
	check("right drag paints nothing",data._undo.size() == undo_now and not editor._painting)
	check("orbit keeps the tree as pivot",not rig.focus.is_empty() and scene.target.distance_to(rig.focus.point) < 0.05,str(scene.target))

	# Trackpad: two-finger swipe orbits, Shift-swipe pans, pinch zooms.
	yaw_before = scene.yaw
	for i in range(20):
		var swipe := InputEventPanGesture.new()
		swipe.position = middle
		swipe.delta = Vector2(-0.4,0.0)
		root.push_input(swipe)
		await process_frame
	await path("swipe",40)
	check("swipe orbits",absf(scene.yaw-yaw_before) > 0.3,snappedf(scene.yaw-yaw_before,0.001))
	var pivot_before: Vector3 = scene.target
	for i in range(20):
		var swipe := InputEventPanGesture.new()
		swipe.position = middle
		swipe.delta = Vector2(0.0,-0.5)
		swipe.shift_pressed = true
		root.push_input(swipe)
		await process_frame
	await path("shift swipe",40)
	check("shift swipe pans",scene.target.distance_to(pivot_before) > 0.5,snappedf(scene.target.distance_to(pivot_before),0.01))
	var distance_before: float = scene.distance
	for i in range(15):
		var pinch := InputEventMagnifyGesture.new()
		pinch.position = middle
		pinch.factor = 1.04
		root.push_input(pinch)
		await process_frame
	await path("pinch",40)
	check("pinch zooms in",scene.distance < distance_before*0.7,[snappedf(distance_before,0.01),snappedf(scene.distance,0.01)])

	# Dive into the hill with the wheel: the camera never goes under it.
	var hill_at: Vector3 = editor.terrain.to_global(Vector3(hill.x,data.ground_height(hill),hill.y))
	rig.glide_to(hill_at+Vector3(0,0,4),rig._view.x,1.3,16.0)
	await frames(80)
	var hill_point := screen_of(hill_at)
	check("hill on screen",Rect2(Vector2.ZERO,Vector2(root.size)).has_point(hill_point) and not scene.camera.is_position_behind(hill_at),str(hill_point))
	for i in range(80):
		click(hill_point,MOUSE_BUTTON_WHEEL_UP)
		if i%4 == 0: await process_frame
	var dive := await path("wheel dive",90)
	check("wheel dive stops at the limit, above ground",scene.distance >= 1.59 and dive.clearance_min > 0.6,{"distance":scene.distance,"clearance":dive.clearance_min})
	# Tilt toward the horizon at the hill's foot.
	click(middle,MOUSE_BUTTON_RIGHT)
	for i in range(20):
		motion(middle+Vector2(0,i*20),Vector2(0,-20),MOUSE_BUTTON_MASK_RIGHT)
		await process_frame
	click(middle,MOUSE_BUTTON_RIGHT,false,false)
	var low := await path("tilt low",90)
	check("tilting low keeps clearance",low.clearance_min > 0.6,low.clearance_min)

	# R glides to the overview; Backspace glides back.
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	root.push_input(key)
	var over := await path("overview")
	check("R glides to the overview",over.settle_s > 0.4 and scene.distance > 25.0,{"distance":scene.distance,"settle":over.settle_s})
	var back := InputEventKey.new()
	back.keycode = KEY_BACKSPACE
	back.pressed = true
	root.push_input(back)
	var returned := await path("back")
	check("Backspace glides back",scene.distance < 25.0,{"distance":scene.distance,"settle":returned.settle_s})

	# Double-click bare ground in Look: the pivot moves there.
	scene.set_looking(true)
	await frames(3)
	scene._overview()
	await frames(4)
	var ground_at: Vector3 = editor.terrain.to_global(Vector3(-8.0,data.ground_height(Vector2(-8.0,-6.0)),-6.0))
	var ground_point := screen_of(ground_at)
	click(ground_point)
	click(ground_point,MOUSE_BUTTON_LEFT,false,false)
	click(ground_point,MOUSE_BUTTON_LEFT,true)
	click(ground_point,MOUSE_BUTTON_LEFT,false,false)
	await path("recentre")
	check("ground double-click recentres",Vector2(scene.target.x,scene.target.z).distance_to(Vector2(ground_at.x,ground_at.z)) < 0.3 and rig.focus.is_empty(),str(scene.target))

	# Double-click the pond, with the birds and fish away so none is nearer.
	scene.land_life.set_process(false)
	scene.land_life.active = false
	rig.glide_to(editor.terrain.to_global(Vector3(basin.x,bottom+0.75,basin.y)),rig._view.x,0.9,20.0)
	await frames(80)
	pond_point = screen_of(editor.terrain.to_global(Vector3(basin.x,bottom+0.75,basin.y)))
	click(pond_point)
	click(pond_point,MOUSE_BUTTON_LEFT,false,false)
	click(pond_point,MOUSE_BUTTON_LEFT,true)
	click(pond_point,MOUSE_BUTTON_LEFT,false,false)
	await path("focus pond")
	check("pond framed",rig.focus.get("kind","") == "pond",rig.focus.get("title",""))

	# Follow: a stand-in deer walks away at a deer's walk; the pivot keeps up
	# smoothly, an orbit keeps following and a pan lets go.
	var deer := Node3D.new()
	scene.add_child(deer)
	deer.global_position = editor.terrain.to_global(Vector3(2.0,data.ground_height(Vector2(2.0,6.0)),6.0))
	rig.frame({"kind":"deer","title":"Deer","point":deer.global_position+Vector3.UP*0.8,"size":1.1,"node":deer,"lift":0.8})
	var lags: Array[float] = []
	var steps: Array[float] = []
	var last: Vector3 = scene.target
	for i in range(240):
		var along := Vector2(2.0-i*0.02,6.0-i*0.012)
		var h: Variant = data.ground_height(along)
		deer.global_position = editor.terrain.to_global(Vector3(along.x,float(h) if h != null else 0.0,along.y))
		await process_frame
		if i > 60: lags.append(scene.target.distance_to(deer.global_position+Vector3.UP*0.8))
		steps.append(scene.target.distance_to(last))
		last = scene.target
	check("follow keeps up",rig.following and lags.max() < 1.2,{"lag_max_m":snappedf(lags.max(),0.01),"step_max_m":snappedf(steps.max(),0.003)})
	click(middle,MOUSE_BUTTON_RIGHT)
	motion(middle+Vector2(30,0),Vector2(30,0),MOUSE_BUTTON_MASK_RIGHT)
	await frames(2)
	click(middle+Vector2(30,0),MOUSE_BUTTON_RIGHT,false,false)
	await frames(2)
	check("orbit keeps following",rig.following)
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_LEFT
	arrow.pressed = true
	root.push_input(arrow)
	rig.pan_pixels(Vector2(40,0))
	await frames(2)
	check("pan lets go",not rig.following)
	deer.queue_free()

	print("CAMERA ",JSON.stringify({"failures":failures}))
	scene.queue_free()
	await frames(3)
	quit(1 if not failures.is_empty() else 0)
