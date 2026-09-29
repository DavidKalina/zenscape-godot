extends SceneTree
## Headless probe of the deep edge pull (scripts/edge_spring.gd "The deep
## pull", scripts/camera_rig.gd `lean`): past the cap the block and the camera
## keep sinking, and on release the plate fills with a plateau, green on top,
## the rim left where it was, one undo step. Nothing is rendered.
##   perl -e 'alarm 320; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
##     -s res://tools/probe_edge_deep.gd
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var spring: Node
var flip: Node
var rig: Node
var failures := []
var sprung := []
var flips := 0
var set_downs := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func button(at: Vector2, pressed: bool, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.shift_pressed = shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event)

func motion(at: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)

func frames(count: int) -> void:
	for i in range(count): await process_frame

## Move by `step` a frame, `count` frames, from `from`; returns where it ended.
func move(from: Vector2, step: Vector2, count: int) -> Vector2:
	var at := from
	for i in range(count):
		at += step
		motion(at,step)
		await frames(1)
	return at

func settled() -> void:
	var quiet := 0
	var n := 0
	while quiet < 20 and n < 3000:
		await process_frame
		n += 1
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or spring.state != 0 or spring.waiting or flip.active() or scene.places.busy or editor.forming
		quiet = 0 if busy else quiet+1

## The highest rise over `base` and where.
func lip_point() -> Vector2:
	var terrain: Node3D = editor.terrain
	var best := Vector2.ZERO
	for side in range(4):
		for i in range(7):
			var f := -6.0+12.0*i/6.0
			var edge: Vector2 = [Vector2(f,-13.7),Vector2(13.7,f),Vector2(f,13.7),Vector2(-13.7,f)][side]
			var h: Variant = editor.data.ground_height(edge)
			if h == null: continue
			var top := float(h)
			var world := terrain.to_global(Vector3(edge.x,top,edge.y))
			if scene.camera.is_position_behind(world): continue
			var at: Vector2 = scene.camera.unproject_position(world)
			if reach.reach_at(at) != "rim": continue
			if at.y > best.y and at.y < root.size.y-300 and at.y > 330: best = at
	return best


func run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("Deep probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-edge-deep-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	editor = scene._chunk_editor
	reach = scene.hand_reach
	spring = scene.get("edge_spring")
	flip = scene.get("flip")
	rig = scene.camera_rig
	scene.world_clock.running = false
	spring.sprung.connect(func(kind: String, size: float) -> void: sprung.append([kind,size]))
	scene._overview()
	await frames(60)
	await settled()
	var data := editor.data
	var before := data.heights.duplicate()
	var undo0: int = data._undo.size()
	var target0: Vector3 = scene.target
	var distance0: float = scene.distance
	var lip := lip_point()
	check("a lip point is found on screen",lip != Vector2.ZERO,lip)
	# Past the bottom of the screen: the travel counts, not the pointer's place.
	var span: float = root.size.y*spring.PULL_SCREEN
	var deep_span: float = root.size.y*spring.DEEP_SCREEN
	button(lip,true)
	await frames(1)
	var at := await move(lip,Vector2(0.0,(span+deep_span*1.2)/40.0),40)
	await frames(20)
	print("held: pulled %.2f deep %.2f dip %.2f, pivot down %.2f m, distance x%.2f" % [spring.pulled,spring.deep,flip.dip,target0.y-scene.target.y,scene.distance/distance0])
	check("past the cap the pull is full and the deep pull is full",spring.pulled == 1.0 and spring.deep == 1.0,[spring.pulled,spring.deep])
	check("the block dips past a full pull",flip.dip > 1.4,flip.dip)
	check("the camera leans down and in with it",scene.target.y < target0.y-0.5 and scene.distance < distance0*0.9,[scene.target,scene.distance])
	button(at,false)
	await frames(1)
	await settled()
	var middle: Variant = data.sample(Vector2.ZERO,data.heights)
	var middle0: Variant = data.sample(Vector2.ZERO,before)
	var inner := 0.0
	var inner_n := 0
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if maxf(absf(p.x),absf(p.y)) < 7.0:
			inner += data.heights[i]-before[i]
			inner_n += 1
	var rim := 0.0
	for i in range(data.points.size()):
		var p: Vector2 = data.points[i]
		if maxf(absf(p.x),absf(p.y)) > 13.6: rim = maxf(rim,absf(data.heights[i]-before[i]))
	print("landed: fill %s, inner rise mean %.2f m, middle %.2f -> %.2f, rim moved %.3f m, camera back %.3f m" % [spring.last_fill,inner/maxf(inner_n,1),float(middle0),float(middle),rim,scene.target.distance_to(target0)])
	check("the plate fills with height",inner/maxf(inner_n,1) > spring.FILL_HEIGHT*0.7,inner/maxf(inner_n,1))
	check("the rim stays where it was",rim < 0.3,rim)
	check("the camera is back where it was",scene.target.distance_to(target0) < 0.05 and absf(scene.distance-distance0) < 0.05)
	check("one spring, one undo step",sprung.size() == 1 and data._undo.size() == undo0+1,[sprung,data._undo.size()-undo0])
	var tint_top := 0.0
	var side := data.MEADOW_CELLS
	var mid_cell := (side/2)*side+side/2
	tint_top = data.tint[mid_cell*NativeTerrainTint.STRIDE+3]
	print("rock weight in the middle of the plateau %.2f" % tint_top)
	editor.undo()
	await settled()
	check("one undo restores the heights exactly",data.heights == before)
	print("FAILURES: %s" % [failures] if not failures.is_empty() else "ALL OK")
	quit(0 if failures.is_empty() else 1)
