extends SceneTree
## Headless probe of the materials as their own cursors (scripts/hand_materials.gd
## `Clump`, docs/design/tools/PLAN.md "The hand at the rim") on the real cozy
## worlds scene, driven by synthesized mouse and key input through hand_reach,
## as tools/probe_tool_feather.gd drives the Feather. With seeds, water and a
## stone in turn: no God Hand shows; the stand-in is built, faceted, of the
## kind in hand; its underside sits on the pointer's ground point, hovering
## 0.3 m, and comes down on a press. Seeds: the veil's motes gather in the
## pinch, it flicks while held and once on release, and every mote settles
## inside the veil's footprint. Water: the bead gives way to the ball, which
## is let go with no hand, pops toward the camera and lands about 0.9 s after
## release, then the bead comes back. Stone: a tap sets one down. Esc puts
## the material back and the cursor shrinks away.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_material_cursors.gd -- --modeless --no-title
## Nothing here is seen: the dummy renderer draws nothing, so the cursor is
## checked as data only.
const Motion = preload("res://scripts/cursor_motion.gd")
const Materials = preload("res://scripts/hand_materials.gd")
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var materials: Node
var hand: Node
var clump: Node3D
var failures := []
## The most the hand showed while material was in hand.
var hand_seen := 0.0

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func button(at: Vector2, pressed: bool) -> void:
	point(at)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func motion(at: Vector2, relative: Vector2, held := true) -> void:
	point(at)
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func point(at: Vector2) -> void:
	reach.pointer_override = at
	editor.pointer_override = at

func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame

## Frames, watching the hand while material is in hand.
func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if hand != null and not materials.held.is_empty(): hand_seen = maxf(hand_seen,float(hand.opacity) if hand.visible else 0.0)

func click(at: Vector2) -> void:
	button(at,true)
	await frames(2)
	button(at,false)
	await frames(2)

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func bare(at: Vector2) -> bool:
	return reach.reach_at(at) == "" and reach._land(at) != null and not reach._prop_at(at) and not materials.tray_under(at)

func hover(spot: Vector2) -> void:
	motion(spot,Vector2.ZERO,false)
	await frames(40)

## How far the cursor's underside is off the pointer's ground point across
## the land, and how high it stands over the land under it (m).
func placed() -> Dictionary:
	var tip: Vector3 = clump.motion.tip
	var hit: Variant = editor.pointer_hit
	var ground: Variant = editor.data.ground_height(Vector2(tip.x,tip.z))
	return {"off":Vector2(tip.x,tip.z).distance_to(Vector2(hit.x,hit.z)) if hit != null else INF,
		"gap":tip.y-float(ground) if ground != null else INF,"at_tip":clump.position.distance_to(tip)}

func take(id: String) -> void:
	for i in range(90):
		if materials.tray.shown > 0.99: break
		await process_frame
	await click(materials.tray.specimen_centre(id))

func built(id: String) -> void:
	var parts: Array = clump.find_children("*","MeshInstance3D",true,false)
	var faceted := parts.all(func(p: MeshInstance3D) -> bool: return p.mesh is ArrayMesh)
	check("%s: its stand-in is built, faceted (%d parts)" % [id,parts.size()],clump.kind == id and parts.size() >= 3 and faceted,[clump.kind,parts.size()])

func run() -> void:
	create_timer(170).timeout.connect(func() -> void: push_error("material cursor probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-material-cursor-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	hand = scene.get("god_hand")
	materials = reach.get("materials")
	scene.world_clock.running = false
	check("the materials tray exists",materials != null)
	if materials == null:
		quit(1)
		return
	clump = materials.clump
	var at := Vector2.INF
	for candidate in [Vector2(-2,1),Vector2(-3,-2),Vector2(2,3),Vector2(0,-4),Vector2(-5,4),Vector2(4,-3),Vector2(-6,-5),Vector2(1,0)]:
		var s := screen(candidate)
		if bare(s) and bare(s+Vector2(-160,0)) and bare(s+Vector2(160,0)) and bare(s+Vector2(0,-60)):
			at = candidate
			break
	check("found a bare spot",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	var spot := screen(at)
	print("spot ",at," on screen ",spot," hand ",hand != null)

	# --- Seeds: a pinch that flicks the veil out ---
	await take("oak")
	check("oak seeds in hand",materials.held == "oak",materials.held)
	await hover(spot)
	built("oak")
	var rest := placed()
	print("SEED REST ",JSON.stringify(rest))
	check("  the pinch shows over the land",clump.visible and float(clump.motion.shown) > 0.99,[clump.visible,clump.motion.shown])
	check("  its underside on the pointer's ground point (%.3f m off)" % float(rest.off),float(rest.off) < 0.05 and float(rest.at_tip) < 1e-4,rest)
	check("  hovering %.2f m over the land" % float(rest.gap),absf(float(rest.gap)-Motion.HOVER) < Motion.BOB+0.02,rest.gap)
	check("  no hand shows (opacity %.2f)" % (float(hand.opacity) if hand != null else 0.0),hand == null or not hand.visible or float(hand.opacity) < 0.05,[hand.reach_gesture if hand != null else ""])
	var handful: Node = editor.get("handful")
	var flicks: int = materials.flicks
	var sowings := str(editor.last_sowing.get("id",""))
	button(spot,true)
	await frames(8)
	var pressed := placed()
	var p := spot
	var in_pinch := 0
	var pinch_off := 0.0
	var lowest := INF
	var snapped := false
	var shown_pressed := true
	for i in range(40):
		p += Vector2(4,0)
		motion(p,Vector2(4,0))
		await frames(1)
		lowest = minf(lowest,float(placed().gap))
		snapped = snapped or clump.flicking()
		shown_pressed = shown_pressed and clump.visible
		handful = editor.get("handful")
		if handful != null and not handful.held.is_empty() and handful.hand_at != null:
			var waiting := 0
			for mote: Dictionary in handful.held.motes:
				if mote.has("hand"):
					waiting += 1
					pinch_off = maxf(pinch_off,Vector3(mote.p).distance_to(Vector3(handful.hand_at)))
			in_pinch = maxi(in_pinch,waiting)
	var held_flicks: int = materials.flicks-flicks
	print("SEED PRESS ",JSON.stringify({"pressed":pressed,"lowest":lowest,"in_pinch":in_pinch,"pinch_off":pinch_off,"flicks":held_flicks}))
	check("  it stays the cursor while it sows",shown_pressed)
	check("  a press brings the pinch down (%.2f m over the land)" % lowest,lowest < float(Materials.PRESS_GAP_DEFAULT)+0.05,lowest)
	check("  the veil's motes gather in the pinch (%d at most, %.2f m off at most)" % [in_pinch,pinch_off],in_pinch > 0 and pinch_off < 0.4,[in_pinch,pinch_off])
	check("  it flicks as it sows (%d flicks in %.2f s)" % [held_flicks,48.0/60.0],held_flicks >= 1,held_flicks)
	check("  and snaps as it flicks",snapped)
	var before_release: int = materials.flicks
	button(p,false)
	await frames(3)
	check("  let go, it flicks the last of it out",materials.flicks == before_release+1,materials.flicks-before_release)
	for i in range(600):
		if str(editor.last_sowing.get("id","")) != sowings: break
		await frames(1)
	var sown: Dictionary = editor.last_sowing
	print("SOWN ",JSON.stringify({"seeds":(sown.get("seeds",PackedVector2Array()) as PackedVector2Array).size(),"motes":sown.get("motes",0),"lost":sown.get("lost",0),"outside":sown.get("outside",-1),"length":sown.get("length",0.0)}))
	check("the sowing settles with seeds",str(sown.get("id","")) != sowings and (sown.get("seeds",PackedVector2Array()) as PackedVector2Array).size() > 0,sown.get("id",""))
	check("  every mote settled inside the footprint",int(sown.get("outside",-1)) == 0,sown.get("outside",-1))
	check("  no hand showed with seeds in hand (at most %.2f)" % hand_seen,hand_seen < 0.05,hand_seen)
	await frames(30)

	# --- Water: a bead, then the ball, let go with no hand ---
	await take("water")
	check("water in hand",materials.held == "water",materials.held)
	await hover(spot)
	built("water")
	rest = placed()
	check("  the bead shows, hovering %.2f m, %.3f m off the pointer" % [float(rest.gap),float(rest.off)],clump.visible and float(rest.off) < 0.05 and absf(float(rest.gap)-Motion.HOVER) < Motion.BOB+0.02,rest)
	var ball_landed := []
	button(spot,true)
	await frames(60)
	var ball: Node3D = editor.get("ball")
	check("  a press makes the ball",ball != null and ball.state == "holding",ball.state if ball != null else null)
	if ball != null:
		ball.landed.connect(func(_p: Vector2, _v: float, _f: Array) -> void: ball_landed.append(Engine.get_process_frames()))
		check("  the bead gives way to it",not clump.visible,[clump.visible,clump.motion.shown])
		button(spot,false)
		var let_go := Engine.get_process_frames()
		await frames(1)
		check("  let go, it is tossed",ball.state == "tossed",ball.state)
		var camera: Vector3 = editor.terrain.to_local(scene.camera.global_position)-ball.position
		var poke: Vector3 = ball.poke
		check("  it pops toward the camera",poke.length() > 0.5 and Vector2(poke.x,poke.z).normalized().dot(Vector2(camera.x,camera.z).normalized()) > 0.95,poke)
		for i in range(180):
			if not ball_landed.is_empty(): break
			await frames(1)
		var flight := float(int(ball_landed[0])-let_go)/60.0 if not ball_landed.is_empty() else INF
		print("WATER ",JSON.stringify({"release_to_landed":flight}))
		check("  it lands %.2f s after release (about 0.9 s)" % flight,flight > 0.75 and flight < 1.1,flight)
		for i in range(120):
			if clump.visible and float(clump.motion.shown) > 0.99: break
			await frames(1)
		check("  then the bead comes back",clump.visible,[clump.visible,ball.state])
	check("  no hand showed with water in hand (at most %.2f)" % hand_seen,hand_seen < 0.05,hand_seen)
	await frames(30)

	# --- Stone: pebbles; a tap sets one down ---
	await take("stone")
	check("a stone in hand",materials.held == "stone",materials.held)
	await hover(spot)
	built("stone")
	rest = placed()
	check("  the pebbles hover %.2f m, %.3f m off the pointer" % [float(rest.gap),float(rest.off)],clump.visible and float(rest.off) < 0.05 and absf(float(rest.gap)-Motion.HOVER) < Motion.BOB+0.02,rest)
	var set_before: int = materials.stones_set
	button(spot,true)
	await frames(10)
	var down := placed()
	var down_shown := clump.visible
	button(spot,false)
	await frames(4)
	check("  a press sets them on the land (%.2f m over it)" % float(down.gap),down_shown and float(down.gap) < 0.05,[down_shown,down])
	check("  a tap sets a stone down",materials.stones_set == set_before+1,materials.stones_set-set_before)
	check("  no hand showed with a stone in hand (at most %.2f)" % hand_seen,hand_seen < 0.05,hand_seen)

	# --- Esc puts it back ---
	await key(KEY_ESCAPE)
	await frames(30)
	check("Esc puts the stone back and the cursor shrinks away",materials.held.is_empty() and not clump.visible,[materials.held,clump.visible])
	print("FAILURES: ",failures)
	scene.queue_free()
	await frames(3)
	quit(1 if not failures.is_empty() else 0)
