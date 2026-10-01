extends SceneTree
## Headless probe of the tool roll's foot (scripts/tool_foot.gd, design "ZenScape
## HUD 5 Air" section F, docs/design/hud-5/FOOT.md) on the real cozy worlds
## scene, driven by synthesized mouse and key input through hand_reach.
## Checks: the foot hangs FOOT_GAP under the roll's rect, as wide, and
## follows it (the roll tucking at rest, and a taller stand-in roll); it rests
## and wakes with the roll and stays quiet during a drag; its slots hit-test
## and the hand counts it as UI; Undo after a clay stroke restores the heights
## exactly, as Cmd Z does; Undo with nothing to undo does nothing; Photo
## enters photo mode and the hud-hidden switch takes every piece away, and
## leaving brings them back; hovering shows each tag and its whisper.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_tool_foot.gd -- --modeless --no-title
## Nothing here is seen: the dummy renderer draws nothing, so the cloth, the
## icons and the tag are checked as layout and state only.
const Foot = preload("res://scripts/tool_foot.gd")
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
var failures := []

## A stand-in roll for the "follows it" check: only what the foot reads.
class StandInRoll extends Control:
	var shown := 1.0
	var awake := 1.0
	var ui_scale := 1.0
	var quiet := false
	var pointer_override: Variant = Vector2(720,400)
	var box := Rect2(24,210,80,370)
	func rect() -> Rect2: return box

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

func motion(at: Vector2, relative: Vector2, held := true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event)

func cmd_z() -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = KEY_Z
		event.physical_keycode = KEY_Z
		event.meta_pressed = true
		event.pressed = down
		root.push_input(event)
		await process_frame

func frames(count: int) -> void:
	for i in range(count): await process_frame

func click(at: Vector2) -> void:
	button(at,true)
	await frames(2)
	button(at,false)
	await frames(2)

func settled() -> void:
	var quiet := 0
	while quiet < 20:
		await process_frame
		var busy: bool = editor.mountain.active or editor.land_settling or editor.refresh_pending > 0 or clay.state != 0 or clay.poking
		quiet = 0 if busy else quiet+1

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func bare(at: Vector2) -> bool:
	return reach.reach_at(at) == "" and reach._land(at) != null and not reach._prop_at(at)

## The Hand's thumb drawn `pixels` along screen x from `start`: a groove, one
## undo step. `aside` is where the roll is told the pointer is meanwhile.
func stroke(start: Vector2, pixels: float, aside: Variant = null) -> void:
	button(start,true)
	await frames(1)
	var p := start
	for i in range(int(pixels/5.0)):
		p += Vector2(5,0)
		motion(p,Vector2(5,0))
		if aside != null: materials.roll.pointer_override = aside
		await frames(1)
	button(p,false)
	await settled()

func rest(roll: Control) -> void:
	roll.pointer_override = Vector2(720,400)
	for i in range(90):
		if roll.awake < 0.001: break
		await process_frame

func run() -> void:
	create_timer(240).timeout.connect(func() -> void: push_error("foot probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-foot-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	materials = reach.get("materials")
	scene.world_clock.running = false
	check("land clay, the materials tray and the foot exist",clay != null and materials != null and materials.get("foot") != null)
	if clay == null or materials == null or materials.get("foot") == null:
		quit(1)
		return
	await settled()
	var roll: Control = materials.roll
	var foot: Control = materials.foot
	var tray: Control = materials.tray
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	check("the roll and the foot show",roll.shown > 0.99 and foot.shown > 0.99 and foot.visible,[roll.shown,foot.shown])

	# --- Placement: 8 px under the roll's rect, as wide, following it ---
	await rest(roll)
	var s: float = roll.ui_scale
	var under := func() -> Array:
		var r: Rect2 = roll.rect()
		var f: Rect2 = foot.rect()
		return [r,f,f.position.y-r.end.y,f.position.x-r.position.x,f.size.x-r.size.x]
	var at_rest: Array = under.call()
	print("REST roll ",at_rest[0]," foot ",at_rest[1]," scale ",s)
	check("at rest the foot sits 8 px under the roll",absf(float(at_rest[2])-8.0*s) <= 1.0,at_rest[2])
	check("as wide as the roll, 80 design px",absf(float(at_rest[4])) < 0.5 and absf(at_rest[1].size.x-80.0*s) < 2.0,at_rest[1].size.x)
	check("the foot is 80 design px tall (two rows of 32 px slots, 4 px apart, 6 px padding)",absf(at_rest[1].size.y-80.0*s) < 1.0,at_rest[1].size.y)
	roll.pointer_override = Vector2(40,450)
	await frames(40)
	var woken: Array = under.call()
	print("AWAKE roll ",woken[0]," foot ",woken[1])
	check("it follows the roll out of its tuck",absf(float(woken[3])) < 0.5 and woken[1].position.x > at_rest[1].position.x and absf(float(woken[2])-8.0*s) <= 1.0,[at_rest[1].position.x,woken[1].position.x])
	var stand_in := StandInRoll.new()
	var lone := Foot.new()
	lone.setup(stand_in,null)
	root.add_child(stand_in)
	root.add_child(lone)
	await frames(2)
	var short: Rect2 = lone.rect()
	stand_in.box = Rect2(24,150,80,480)
	await frames(2)
	var tall: Rect2 = lone.rect()
	print("STAND-IN 370 tall: ",short,"  480 tall: ",tall)
	check("a taller roll (the Feather's 80x480) carries the foot down with it",is_equal_approx(short.position.y,588.0) and is_equal_approx(tall.position.y,638.0),[short.position.y,tall.position.y])
	lone.queue_free()
	stand_in.queue_free()

	# --- The icons: Undo's sampled arrow and the camera rasterise and are faceted.
	# The arrow is a thin half ring and its head, about 11 % of the 28-unit box by
	# area (the half ring's 62 units² plus the head's 21); the camera about 30 %.
	# Pixels at least half covered are counted. ---
	for id: String in Foot.SLOTS:
		var texture: Texture2D = foot._textures.get(id+":icon")
		var image: Image = texture.get_image() if texture != null else null
		var cover := 0
		var tones := {}
		if image != null:
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var c := image.get_pixel(x,y)
					if c.a > 0.5:
						cover += 1
						tones[c.to_html(false)] = true
		var share := float(cover)/float(image.get_width()*image.get_height()) if image != null else 0.0
		print("ICON %s %s cover %.2f tones %d" % [id,image.get_size() if image != null else Vector2i.ZERO,share,tones.size()])
		check("the %s icon rasterises at 24 px, faceted" % id,image != null and share > 0.06 and share < 0.8 and tones.size() >= 8,[share,tones.size()])

	# --- Rest and wake with the roll ---
	await rest(roll)
	check("at rest together",roll.awake < 0.01 and foot.awake == roll.awake and absf(foot.modulate.a-0.6) < 0.02,[foot.awake,foot.modulate.a])
	roll.pointer_override = foot.slot_centre("undo")
	await frames(30)
	check("reaching for the foot wakes both",roll.awake > 0.99 and foot.awake == roll.awake and absf(foot.modulate.a-1.0) < 0.01,[roll.awake,foot.modulate.a])

	# --- Hit tests, and the hand treats it as UI ---
	for id: String in Foot.SLOTS:
		check("slot %s hit-tests to itself" % id,foot.slot_at(foot.slot_centre(id)) == id)
	var middle: Vector2 = foot.rect().get_center()
	check("the gap between the slots is the foot's, not a slot's",foot.slot_at(middle) == "" and foot.contains_pointer(middle))
	check("the hand counts the foot as UI (tray_under)",materials.tray_under(foot.slot_centre("photo")) and materials.tray_under(middle))
	check("under the foot is not UI",not materials.tray_under(Vector2(middle.x,foot.rect().end.y+40.0)) and foot.slot_at(Vector2(middle.x,foot.rect().end.y+40.0)) == "")

	# --- Tags and whispers on hover ---
	for id: String in Foot.SLOTS:
		roll.pointer_override = foot.slot_centre(id)
		await frames(20)
		var tag: Rect2 = foot._tag_rect()
		var text: Array = foot.tag_text(id)
		print("TAG %s %s %s" % [id,text,tag])
		check("hovering %s shows its tag right of the foot" % id,foot.hovered == id and tag.size.x > 0.0 and tag.position.x >= foot.rect().end.x and foot._tag_hover() > 0.99)
		check("with its whisper",text[1] == Foot.WHISPERS[id],text)
	roll.pointer_override = Vector2(720,400)
	await frames(20)
	check("the tag goes when the pointer leaves",foot.hovered == "" and foot._tag_hover() == 0.0)

	# --- Quiet during a drag ---
	var at := Vector2.INF
	for candidate in [Vector2(-2,1),Vector2(-3,-2),Vector2(2,3),Vector2(0,-4),Vector2(-5,4),Vector2(4,-3),Vector2(-6,-5),Vector2(1,0)]:
		var p := screen(candidate)
		if bare(p) and bare(p+Vector2(-160,0)) and bare(p+Vector2(160,0)):
			at = candidate
			break
	check("found a bare spot",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	var spot := screen(at)
	var data := editor.data
	await rest(roll)
	var undo0: int = data._undo.size()
	var base := data.heights.duplicate()
	var woke := 0.0
	var hover_seen := ""
	button(spot+Vector2(-150,0),true)
	await frames(1)
	var p := spot+Vector2(-150,0)
	for i in range(60):
		p += Vector2(5,0)
		motion(p,Vector2(5,0))
		roll.pointer_override = foot.slot_centre("undo")
		await frames(1)
		woke = maxf(woke,foot.awake)
		if not foot.hovered.is_empty(): hover_seen = foot.hovered
	check("a drag with the pointer on the foot leaves it asleep and unhovered",woke < 0.01 and hover_seen == "" and roll.quiet,[woke,hover_seen])
	button(p,false)
	await settled()
	var grooved: int = 0
	for i in range(base.size()):
		if absf(data.heights[i]-base[i]) > 0.01: grooved += 1
	check("that drag was a clay stroke, one undo step",data._undo.size() == undo0+1 and grooved > 20,[data._undo.size()-undo0,grooved])

	# --- Undo: the foot's press is Cmd Z ---
	roll.pointer_override = foot.slot_centre("undo")
	await frames(30)
	await click(foot.slot_centre("undo"))
	await settled()
	check("the foot's Undo restores the heights exactly",data.heights == base and data._undo.size() == undo0 and foot.presses.undo == 1,[data._undo.size()-undo0,foot.presses.undo])
	await stroke(spot+Vector2(-150,0),300.0)
	check("a second stroke",data._undo.size() == undo0+1 and data.heights != base)
	await cmd_z()
	await settled()
	check("Cmd Z restores the same heights",data.heights == base and data._undo.size() == undo0)

	# --- Undo with nothing to undo ---
	var guard := 0
	while not data._undo.is_empty() and guard < 200:
		editor.undo()
		guard += 1
	await settled()
	var empty := data.heights.duplicate()
	var redo_before: int = data._redo.size()
	roll.pointer_override = foot.slot_centre("undo")
	await frames(30)
	await click(foot.slot_centre("undo"))
	await settled()
	check("Undo with an empty history does nothing",data._undo.is_empty() and data.heights == empty and data._redo.size() == redo_before and foot.presses.undo == 2,[data._undo.size(),data._redo.size()-redo_before])

	# --- Photo: in, every piece away; out, back ---
	var photo: Node = scene.photo
	roll.pointer_override = foot.slot_centre("photo")
	await frames(30)
	await click(foot.slot_centre("photo"))
	await frames(40)
	check("Photo enters photo mode",photo.active and foot.presses.photo == 1)
	check("the hud-hidden switch is thrown",materials.hud_hidden)
	check("the bar, the roll and the foot are gone",tray.shown == 0.0 and roll.shown == 0.0 and foot.shown == 0.0 and not tray.visible and not roll.visible and not foot.visible,[tray.shown,roll.shown,foot.shown])
	check("and none of them catch the pointer",not materials.tray_under(foot.slot_centre("photo")) and foot.slot_at(foot.slot_centre("photo")) == "")
	photo.leave()
	await frames(40)
	check("leaving photo mode clears the switch",not photo.active and not materials.hud_hidden)
	check("and brings the pieces back",tray.shown > 0.99 and roll.shown > 0.99 and foot.shown > 0.99 and tray.visible and roll.visible and foot.visible,[tray.shown,roll.shown,foot.shown])
	# The switch alone, as the almanac or anything else would use it.
	materials.hud_hidden = true
	await frames(30)
	check("the switch alone hides every piece",tray.shown == 0.0 and roll.shown == 0.0 and foot.shown == 0.0)
	materials.hud_hidden = false
	await frames(30)
	check("and brings them back",tray.shown > 0.99 and roll.shown > 0.99 and foot.shown > 0.99)
	print("FAILURES: ",failures)
	scene.queue_free()
	await frames(3)
	quit(1 if not failures.is_empty() else 0)
