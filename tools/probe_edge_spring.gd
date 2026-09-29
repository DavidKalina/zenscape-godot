extends SceneTree
## Headless probe of the edge spring (docs/scenic/modeless-spring.md, "From
## the edge"; docs/scenic/modeless.md): the real product scene, `--modeless`,
## synthesized mouse input at a fixed 60 Hz.
## - a downward drag from the lip decides "spring": no turn, no flip; the land
##   sags with the pull and the hand pinches; let go and a ridge rises inward
##   of the grabbed edge, one undo step, which restores the heights exactly;
## - the same from the block's wall, from a low close camera;
## - a tiny pull decides "spring" but keeps nothing and adds no undo step;
## - a sideways drag still turns; an upward drag still flips.
## Nothing is rendered: how any of it looks or feels is not checked.
##   perl -e 'alarm 300; exec @ARGV' Godot --headless --fixed-fps 60 --path . \
##     -s res://tools/probe_edge_spring.gd -- --modeless
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var spring: Node
var rig: Node
var failures := []
var sprung := []
var flips := 0

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

func settled() -> void:
	var quiet := 0
	var n := 0
	while quiet < 20 and n < 2000:
		await process_frame
		n += 1
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or spring.state != 0
		quiet = 0 if busy else quiet+1

## The deepest sag below `base` (metres, positive down) and the highest rise.
func sag(base: PackedFloat32Array) -> float:
	var deepest := 0.0
	var heights := editor.data.heights
	for i in range(heights.size()): deepest = maxf(deepest,base[i]-heights[i])
	return deepest

## The plate point that rose most over `base`, and by how much.
func rise(base: PackedFloat32Array) -> Array:
	var heights := editor.data.heights
	var best := 0.0
	var at := Vector2.ZERO
	for i in range(heights.size()):
		var up := heights[i]-base[i]
		if up > best:
			best = up
			at = editor.data.points[i]
	return [best,at]

## A lip point on screen: the land just inside the rim on the nearest side.
func lip_point() -> Vector2:
	var terrain: Node3D = editor.terrain
	var best := Vector2.ZERO
	for side in range(4):
		for i in range(7):
			var f := -6.0+12.0*i/6.0
			var edge: Vector2 = [Vector2(f,-13.7),Vector2(13.7,f),Vector2(f,13.7),Vector2(-13.7,f)][side]
			var top := float(editor.data.ground_height(edge))
			var world := terrain.to_global(Vector3(edge.x,top,edge.y))
			if scene.camera.is_position_behind(world): continue
			var at: Vector2 = scene.camera.unproject_position(world)
			if reach.reach_at(at) != "rim": continue
			if at.y > best.y and at.y < root.size.y-220: best = at
	return best

## Press at `from`, move by `step` for `count` frames, hold, and return the
## pull's record: the sag after a third and at the end, the intent, the hand.
func pull_down(from: Vector2, step: Vector2, count: int) -> Dictionary:
	var base := editor.data.heights.duplicate()
	button(from,true)
	await frames(1)
	var at := from
	var early := 0.0
	for i in range(count):
		at += step
		motion(at,step)
		await frames(1)
		if i == count/3: early = sag(base)
	await frames(10)
	var hand: Node = scene.get("god_hand")
	return {"end":at,"early":early,"late":sag(base),"intent":reach.rim_intent,"state":spring.state,"from_edge":spring.from_edge,
		"pulled":spring.pulled,"gesture":hand.reach_gesture if hand != null else "-","base":base}

## One full edge spring from `from`; checks under `label`.
func edge_spring(label: String, from: Vector2, step: Vector2, count: int) -> void:
	var data := editor.data
	var before := data.heights.duplicate()
	var undo0: int = data._undo.size()
	var yaw0: float = scene.yaw
	flips = 0
	sprung.clear()
	var what: String = reach.reach_at(from)
	check("%s: the press is on the rim" % label,what == "rim",what)
	var t0 := Time.get_ticks_usec()
	var held := await pull_down(from,step,count)
	var pull_ms := (Time.get_ticks_usec()-t0)/1000.0/float(count+11)
	var edge: Vector3 = reach._press_edge
	print("%s: grabbed edge %s, pull %.2f, sag %.3f then %.3f m, mean frame while pulling %.1f ms" % [label,edge,held.pulled,held.early,held.late,pull_ms])
	check("%s: a downward rim drag decides the spring" % label,held.intent == "spring" and held.state == 1 and held.from_edge,[held.intent,held.state])
	check("%s: it does not flip" % label,flips == 0,flips)
	check("%s: it does not turn the world" % label,absf(angle_difference(yaw0,scene.yaw)) < 0.001,rad_to_deg(scene.yaw-yaw0))
	check("%s: the land sags with the pull" % label,held.early > 0.02 and held.late > held.early+0.1,[held.early,held.late])
	check("%s: the sag is capped" % label,held.late <= spring.SAG_DEPTH.y*(1.0+spring.TREMBLE)+0.01,held.late)
	check("%s: the hand pinches while pulling" % label,held.gesture == "pinch" or scene.get("god_hand") == null,held.gesture)
	button(held.end,false)
	await frames(1)
	check("%s: let go, it springs" % label,spring.state == 2,spring.state)
	await settled()
	var up: Array = rise(before)
	var peak: Vector2 = up[1]
	var out := Vector2(signf(edge.x),0.0) if absf(edge.x) >= absf(edge.z) else Vector2(0.0,signf(edge.z))
	var inward: float = 14.0-peak.dot(out)
	print("%s: highest rise %.2f m at %s, %.2f m in from the grabbed edge, sprung %s" % [label,up[0],peak,inward,sprung])
	check("%s: land rises" % label,float(up[0]) > 2.0,up[0])
	check("%s: inward of the grabbed edge" % label,inward > 2.0 and inward < 10.0,inward)
	var along := peak.dot(Vector2(out.y,out.x).abs())
	var grab_along := Vector2(edge.x,edge.z).dot(Vector2(out.y,out.x).abs())
	check("%s: along the edge near the grab" % label,absf(along-grab_along) < 10.0,[along,grab_along])
	var back := 0.0
	var heights := data.heights
	for i in range(heights.size()):
		if 14.0-data.points[i].dot(out) > 12.0: back = maxf(back,absf(heights[i]-before[i]))
	check("%s: the far side of the plate is untouched" % label,back < 0.3,back)
	check("%s: sprung a range" % label,sprung.size() == 1 and sprung[0][0] == "range",sprung)
	check("%s: one undo step" % label,data._undo.size() == undo0+1,data._undo.size()-undo0)
	editor.undo()
	await settled()
	check("%s: one undo restores the heights exactly" % label,data.heights == before)

func run() -> void:
	create_timer(280).timeout.connect(func() -> void: push_error("Edge spring probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-edge-spring-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	editor = scene._chunk_editor
	reach = scene.hand_reach
	spring = scene.get("land_spring")
	rig = scene.camera_rig
	check("run with --modeless",reach.modeless and spring != null)
	if spring == null:
		quit(1)
		return
	scene.world_clock.running = false
	reach.flip_began.connect(func(_p: Vector2) -> void: flips += 1)
	spring.sprung.connect(func(kind: String, size: float) -> void: sprung.append([kind,size]))
	scene._overview()
	await frames(60)
	await settled()

	# --- From the lip ---------------------------------------------------------------
	var lip := lip_point()
	check("a lip point is found on screen",lip != Vector2.ZERO,lip)
	await edge_spring("lip",lip,Vector2(0.4,6.0),32)
	check("the lip grab is on the lip",absf(reach._press_edge.y-reach._rim_height(Vector2(reach._press_edge.x,reach._press_edge.z))) < 0.35,reach._press_edge)

	# --- A tiny pull keeps nothing ---------------------------------------------------
	var data := editor.data
	var before := data.heights.duplicate()
	var undo0: int = data._undo.size()
	sprung.clear()
	lip = lip_point()
	var tiny := await pull_down(lip,Vector2(0.0,7.0),2)
	check("a tiny pull still decides the spring",tiny.intent == "spring",tiny.intent)
	button(tiny.end,false)
	await settled()
	check("a tiny pull raises nothing",data.heights == before and sprung.is_empty(),sprung)
	check("and adds no undo step",data._undo.size() == undo0)

	# --- Sideways still turns --------------------------------------------------------
	lip = lip_point()
	var yaw0: float = scene.yaw
	button(lip,true)
	await frames(1)
	var p := lip
	for i in range(12):
		p += Vector2(7.0,0.0)
		motion(p,Vector2(7.0,0.0))
		await frames(1)
	check("a sideways rim drag still turns",reach.rim_intent == "turn" and absf(angle_difference(yaw0,scene.yaw)) > 0.01,[reach.rim_intent,rad_to_deg(scene.yaw-yaw0)])
	check("and draws no spring",spring.state == 0,spring.state)
	button(p,false)
	await frames(30)
	rig.turn.stop()
	await frames(10)

	# --- From the wall ---------------------------------------------------------------
	rig.glide_to(Vector3(0,-1.0,8.0),0.0,1.42,16.0)
	await frames(150)
	var wall_local := Vector3(2.0,-1.6,14.0)
	var wall: Vector2 = scene.camera.unproject_position(editor.terrain.to_global(wall_local))
	print("wall point on screen ",wall)
	await edge_spring("wall",wall,Vector2(0.0,6.0),32)
	check("the wall grab is on the wall",reach._press_edge.y < reach._rim_height(Vector2(reach._press_edge.x,reach._press_edge.z))-0.5,reach._press_edge)

	# --- Up still flips (last: it turns the diorama over) ---------------------------
	scene._overview()
	await frames(90)
	lip = lip_point()
	flips = 0
	button(lip,true)
	await frames(1)
	p = lip
	for i in range(10):
		p += Vector2(0.0,-12.0)
		motion(p,Vector2(0.0,-12.0))
		await frames(1)
	check("an upward rim drag still flips",reach.rim_intent == "flip" and flips == 1 and spring.state == 0,[reach.rim_intent,flips,spring.state])
	button(p,false)
	await frames(5)
	var flip: Node = scene.get("flip")
	if flip != null: await flip.wait_idle()
	print("FAILURES: ",failures)
	quit(1 if not failures.is_empty() else 0)
