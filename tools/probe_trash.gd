extends SceneTree
## Headless probe of the trash can (scripts/clay_tools/trash.gd) on the real
## cozy worlds scene, driven by synthesized input through hand_reach. Checks:
## it has a pocket on the top strip; a sweep takes a tree, a boulder, a log, a
## shrub and a leaf bed off its line and leaves one off it; it moves no
## ground; the stroke is one undo step that brings them all back; Shift
## spares the tree and the boulder. Built things: Shift spares a stone lamp, a
## campfire, a cabin, a footbridge and a fence, but takes wheat and flowers;
## without Shift the sweep takes them all, and cuts the fence.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_trash.gd -- --modeless --no-title
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var clay: Node
var materials: Node
var hand: Node
var failures := []

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

func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)
		await process_frame

func shift(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

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

func plate(at: Vector2) -> Variant:
	var hit: Variant = editor.pick(at)
	return Vector2(hit.x,hit.z) if hit != null else null

func bare(at: Vector2) -> bool:
	return reach.reach_at(at) == "" and reach._land(at) != null and not reach._prop_at(at)

func stroke(spot: Vector2) -> void:
	var from := spot+Vector2(-120,0)
	button(from,true)
	await frames(2)
	for k in range(24):
		motion(from+Vector2(10*(k+1),0),Vector2(10,0))
		await frames(1)
	await frames(10)
	button(from+Vector2(240,0),false)
	await settled()

func has(id: int) -> bool:
	for item: Dictionary in editor.data.objects:
		if int(item.id) == id: return true
	return false

## Sets one of each kind down along the stroke's line, and one well off it.
func lay(spot: Vector2) -> Dictionary:
	var data := editor.data
	data.begin_stroke()
	var ids := {}
	var kinds := ["tree","boulder_1","log","shrub","leaf_bed"]
	for k in range(kinds.size()):
		var p: Variant = plate(spot+Vector2(-80+40*k,0))
		if p != null: ids[kinds[k]] = data.place(kinds[k],p)
	var far: Variant = plate(spot+Vector2(0,120))
	if far != null: ids["far"] = data.place("shrub",far)
	data.end_stroke()
	editor.force_refresh()
	await settled()
	return ids

## Sets the built things down along the stroke's line (a cabin, a lamp, a
## campfire, wheat and a flower), a footbridge and a fence across it.
func lay_built(spot: Vector2) -> Dictionary:
	var data := editor.data
	data.begin_stroke()
	var ids := {}
	var kinds := {"cabin":-100,"stone_lamp":-60,"campfire":-20,"wheat":20,"daisy_flower":45}
	for kind: String in kinds:
		var p: Variant = plate(spot+Vector2(kinds[kind],0))
		if p != null: ids[kind] = data.place(kind,p)
	var a: Variant = plate(spot+Vector2(75,-45))
	var b: Variant = plate(spot+Vector2(75,45))
	if a != null and b != null: ids["bridge"] = data.add_bridge(a,b)
	data.end_stroke()
	if editor.bridges != null: editor.bridges.rebuild()
	editor.force_refresh()
	await settled()
	var f0: Variant = plate(spot+Vector2(105,-70))
	var f1: Variant = plate(spot+Vector2(105,70))
	if f0 != null and f1 != null:
		var laid: Array = editor.lay_fence(PackedVector2Array([f0,f1]))
		if not laid.is_empty(): ids["fence"] = laid[0]
	await settled()
	return ids

func run() -> void:
	create_timer(200).timeout.connect(func() -> void: push_error("trash probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-trash-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	clay = scene.get("land_clay")
	hand = scene.get("god_hand")
	materials = reach.get("materials")
	scene.world_clock.running = false
	check("land clay and the materials tray exist",clay != null and materials != null)
	if clay == null or materials == null:
		quit(1)
		return
	await settled()
	var data := editor.data
	var roll: Control = materials.roll
	var at := Vector2.INF
	for candidate in [Vector2(-2,1),Vector2(-3,-2),Vector2(2,3),Vector2(0,-4),Vector2(-5,4),Vector2(4,-3),Vector2(-6,-5),Vector2(1,0)]:
		var s := screen(candidate)
		if bare(s) and bare(s+Vector2(-140,0)) and bare(s+Vector2(140,0)):
			at = candidate
			break
	check("found a bare spot",at != Vector2.INF,at)
	if at == Vector2.INF:
		quit(1)
		return
	var spot := screen(at)
	for i in range(120):
		if roll.shown > 0.99: break
		await process_frame
	var pocket: Vector2 = roll._cell(roll.TOOLS.find("trash")).get_center()
	check("the trash can has a pocket on the top strip",roll.tool_at(pocket) == "trash" and "trash" in roll.TOP,roll.tool_at(pocket))
	await click(pocket)
	await frames(30)
	check("pressing it takes the trash can",clay.tool_id == "trash",clay.tool_id)

	# --- A sweep takes everything on its line, one undo step ---
	var ids := await lay(spot)
	check("laid a tree, a boulder, a log, a shrub, a leaf bed and a far shrub",ids.size() == 6,ids)
	var undo0: int = data._undo.size()
	var heights0 := data.heights.duplicate()
	await stroke(spot)
	var left := []
	for kind in ["tree","boulder_1","log","shrub","leaf_bed"]:
		if has(int(ids.get(kind,-1))): left.append(kind)
	check("the sweep takes them all",left.is_empty(),left)
	check("but not the shrub off its line",has(int(ids.get("far",-1))))
	check("it moves no ground",data.heights == heights0)
	check("one undo step",data._undo.size() == undo0+1,data._undo.size()-undo0)
	await frames(60)
	check("the flights are drawn in and gone",not clay.tool.busy())
	editor.undo()
	await settled()
	var back := []
	for kind in ["tree","boulder_1","log","shrub","leaf_bed"]:
		if has(int(ids.get(kind,-1))): back.append(kind)
	check("undo brings them all back",back.size() == 5,back)

	# --- Shift spares the big things ---
	shift(true)
	await stroke(spot)
	shift(false)
	check("Shift spares the tree and the boulder",has(int(ids.tree)) and has(int(ids.boulder_1)))
	check("and takes the small things",not has(int(ids.log)) and not has(int(ids.shrub)) and not has(int(ids.leaf_bed)))

	# --- Shift spares everything built; wheat and flowers are small ---
	const Trash = preload("res://scripts/clay_tools/trash.gd")
	check("lamps and campfires count as big, as cabins and bridges do","stone_lamp" in Trash.BIG and "campfire" in Trash.BIG and "cabin" in Trash.BIG and "bridge" in Trash.BIG)
	check("wheat and flowers do not","wheat" not in Trash.BIG and "daisy_flower" not in Trash.BIG)
	editor.undo()
	await settled()
	var built := await lay_built(spot)
	check("laid a cabin, a lamp, a campfire, wheat, a flower, a footbridge and a fence",built.size() == 7,built)
	var fences0: Array = data.fences.duplicate(true)
	shift(true)
	await stroke(spot)
	shift(false)
	var lost := []
	for kind in ["cabin","stone_lamp","campfire","bridge"]:
		if not has(int(built.get(kind,-1))): lost.append(kind)
	check("Shift spares the cabin, lamp, campfire and bridge",lost.is_empty(),lost)
	check("and the fence, whole",data.fences == fences0,[fences0.size(),data.fences.size()])
	check("but takes the wheat and the flower",not has(int(built.get("wheat",-1))) and not has(int(built.get("daisy_flower",-1))))
	await stroke(spot)
	var kept := []
	for kind in ["cabin","stone_lamp","campfire","bridge"]:
		if has(int(built.get(kind,-1))): kept.append(kind)
	check("without Shift the sweep takes them all",kept.is_empty(),kept)
	check("and cuts the fence",data.fences != fences0,data.fences.size())

	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
