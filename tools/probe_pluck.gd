extends SceneTree
## Headless probe of plucking (scripts/hand_reach.gd `pluck`) on the cozy
## worlds scene, driven by synthesized mouse and Shift input through the
## hand's reach, with the Feather in hand (a free hand: no shaping tool):
##   - a plain press on a tree still takes it in hand to bend, and keeps it;
##   - a Shift-press on the tree plucks it, with a crumble and a rustle: its
##     record goes, the cover cells under its root turn hand-made (emergence
##     would not plant there), and one undo brings the record and the ground
##     back;
##   - with Shift held the hover outlines a shrub; a Shift-press on an emerged
##     shrub plucks it and drops the forest wish under it to CLEAR_BELOW;
##     one undo restores the shrub and the wish;
##   - a Shift-press on a flower plucks it;
##   - Bigfoot's tree is never plucked, by a Shift-press at its root or by
##     `pluck` itself, nor is a rock.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_pluck.gd -- --no-title
## Nothing here is seen: the dummy renderer draws nothing, so the pop and the
## burst are checked only for being made and freeing themselves.
const ForestBrush = preload("res://scripts/forest_brush.gd")
var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var play: Node
var failures := []
var cues := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func frames(count: int) -> void:
	for i in range(count): await process_frame

func point(at: Vector2) -> void:
	editor.pointer_override = at
	reach.pointer_override = at

func shift(down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SHIFT
	event.physical_keycode = KEY_SHIFT
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func button(at: Vector2, pressed: bool, with_shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = pressed
	event.shift_pressed = with_shift
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event)

## A press and release at `at`, with Shift held through it or not; returns
## what the hand held while pressed.
func press(at: Vector2, with_shift := false) -> String:
	point(at)
	if with_shift: shift(true)
	await frames(3)
	button(at,true,with_shift)
	await frames(2)
	var held: String = reach.holding
	button(at,false,with_shift)
	await frames(2)
	if with_shift: shift(false)
	return held

func settled() -> void:
	var quiet := 0
	while quiet < 10:
		await process_frame
		quiet = 0 if editor.refresh_pending > 0 or editor.forming else quiet+1

func record(id: int) -> Dictionary:
	return editor.data.object_by_id(id)

func ground_screen(p: Vector2) -> Vector2:
	var h: Variant = editor.data.ground_height(p)
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,float(h),p.y)))

func on_screen(s: Vector2) -> bool:
	return Rect2(Vector2(120,120),Vector2(root.size)-Vector2(240,240)).has_point(s)

func cell(p: Vector2) -> int:
	return editor.data.meadow_cell(p)

## An open spot on screen, `clear` m from any object and from `taken`, whose
## ground the pointer reaches with nothing in the way.
func open_spot(clear: float, taken: Array) -> Variant:
	for z in range(-9,10):
		for x in range(-9,10):
			var p := Vector2(x,z)*1.1+Vector2(0.3,0.2)
			if editor.data.ground_height(p) == null or not on_screen(ground_screen(p)): continue
			if editor.emergence.takes(p) == false: continue
			var near := false
			for item: Dictionary in editor.data.objects:
				if Vector2(item.x,item.z).distance_to(p) < clear: near = true
			for q: Vector2 in taken:
				if q.distance_to(p) < clear: near = true
			if near: continue
			var s := ground_screen(p)
			if reach.reach_at(s) != "" or reach._tree_under(s) > 0 or reach._land(s) == null: continue
			var land: Vector3 = reach._land(s)
			if Vector2(land.x,land.z).distance_to(p) > 0.2: continue
			return p
	return null

## Sets a plant down at `p` from `source`, and waits for it to be drawn.
func plant(kind: String, p: Vector2, source: String) -> int:
	var id: int = editor.data.place(kind,p)
	if id > 0:
		editor.data.objects.back()["source"] = source
		editor.data.objects_revision += 1
		editor.refresh()
		await settled()
		await frames(5)
	return id

func run() -> void:
	create_timer(200).timeout.connect(func() -> void: push_error("pluck probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-pluck-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	play = scene.world_play
	scene.world_clock.running = false
	editor.emergence_enabled = false
	await frames(30)
	check("the tray and tool roll are up",reach.materials != null)
	if reach.materials == null:
		finish()
		return
	scene.land_clay.sounded.connect(func(cue: StringName, _at: Vector3, _strength: float) -> void: cues.append(cue))
	reach.materials.select_tool("feather",true)
	await frames(3)
	check("with the Feather the hand is free (no shaping tool)",not reach.shaping())

	# The tree: find one whose mesh the pointer reaches.
	var tree_id := -1
	var at_tree := Vector2.ZERO
	for record_id: int in play._records:
		var item: Dictionary = play._records[record_id]
		if not str(item.asset) in reach.PLUCK_TREES: continue
		var base: Vector3 = editor.terrain.global_transform*editor.data.object_position(item)
		for height: float in [1.0,1.5,2.5,3.5]:
			var s: Vector2 = scene.camera.unproject_position(base+Vector3.UP*height)
			if on_screen(s) and reach._tree_under(s) == record_id:
				tree_id = record_id
				at_tree = s
				break
		if tree_id > 0: break
	check("a tree is on screen to press",tree_id > 0)
	if tree_id < 0:
		finish()
		return
	var tree: Dictionary = record(tree_id)
	var root_p := Vector2(tree.x,tree.z)
	print("     tree %s #%d at %s (%s)" % [tree.asset,tree_id,root_p,NativeTerrainData.object_source(tree)])

	# A plain press bends it, and keeps it.
	var held := await press(at_tree)
	check("a plain press on the tree takes it in hand to bend",held == "tree",held)
	check("and the tree stays",not record(tree_id).is_empty())
	for i in range(600):
		await frames(1)
		if not reach._springing.has(tree_id): break
	await frames(5)

	# Shift-press plucks it.
	var undo0: int = editor.data._undo.size()
	var provenance_before: PackedByteArray = editor.data.provenance.duplicate()
	var plucked0: int = reach.plucked
	cues.clear()
	held = await press(at_tree,true)
	check("it comes up with a crumble of soil and a rustle",&"crumble" in cues and &"trees" in cues,cues)
	check("a Shift-press on the tree plucks it",held == "pluck" and record(tree_id).is_empty() and reach.plucked == plucked0+1,[held,reach.plucked-plucked0])
	check("the hand lets go on release",reach.holding.is_empty(),reach.holding)
	check("it springs no more",not reach._springing.has(tree_id) and not reach._tree_springs.has(tree_id) and not play._active.has(tree_id))
	check("the ground under its root turns hand-made",editor.data.provenance[cell(root_p)] == NativeTerrainData.SOURCE_HAND,editor.data.provenance[cell(root_p)])
	check("emergence will not plant there",not editor.emergence.takes(root_p))
	check("the pluck is one undo step",editor.data._undo.size() == undo0+1,editor.data._undo.size()-undo0)
	check("it pops out of the ground",reach.get_node_or_null("PluckPop") != null)
	await settled()
	await frames(40)
	check("the pop frees itself",reach.get_node_or_null("PluckPop") == null)
	editor.undo()
	await settled()
	check("one undo brings the tree back",not record(tree_id).is_empty() and editor.data._undo.size() == undo0,[record(tree_id).get("asset",""),editor.data._undo.size()-undo0])
	check("and its ground",editor.data.provenance == provenance_before)

	# A shrub, emerged, on open ground.
	var taken := []
	var shrub_p: Variant = open_spot(1.6,taken)
	check("an open spot for a shrub",shrub_p != null)
	if shrub_p == null:
		finish()
		return
	taken.append(shrub_p)
	var shrub := await plant("shrub",shrub_p,"emerged")
	check("the shrub is set down",shrub > 0)
	var at_shrub := ground_screen(shrub_p)
	check("the shrub is the plant under the pointer",reach.plant_under(at_shrub) == shrub,reach.plant_under(at_shrub))
	# The hover outlines it with Shift held, not without.
	point(at_shrub)
	reach._hover_key = []
	await frames(4)
	var plain_outline: int = reach.outline.tree_id
	shift(true)
	await frames(4)
	check("Shift outlines the shrub",reach.outline.tree_id == shrub and plain_outline != shrub,[plain_outline,reach.outline.tree_id])
	shift(false)
	await frames(2)
	var wish_cell := cell(shrub_p)
	var intent: RefCounted = editor.emergence.intent
	var wish_before: float = intent.forest[wish_cell]
	var revision: int = intent.revision
	held = await press(at_shrub,true)
	check("a Shift-press on the shrub plucks it",held == "pluck" and record(shrub).is_empty(),held)
	check("its ground turns hand-made",editor.data.provenance[wish_cell] == NativeTerrainData.SOURCE_HAND)
	check("the forest wish there drops to CLEAR_BELOW",intent.forest[wish_cell] <= ForestBrush.CLEAR_BELOW and intent.revision > revision,[intent.forest[wish_cell]])
	await settled()
	editor.undo()
	await settled()
	check("one undo brings the shrub and the wish back",not record(shrub).is_empty() and is_equal_approx(intent.forest[wish_cell],wish_before),[record(shrub).get("asset",""),intent.forest[wish_cell]])
	# A plain press on it with the Feather is the wind's, not a pluck.
	held = await press(at_shrub)
	check("a plain press on the shrub plucks nothing",not record(shrub).is_empty(),held)
	await settled()

	# A flower set by hand.
	var flower_p: Variant = open_spot(1.6,taken)
	if flower_p != null:
		taken.append(flower_p)
		var flower := await plant("daisy_flower",flower_p,"hand")
		held = await press(ground_screen(flower_p),true)
		check("a Shift-press on a flower plucks it",flower > 0 and held == "pluck" and record(flower).is_empty(),[flower,held])
		await settled()
	else: check("an open spot for a flower",false)

	# Bigfoot's tree and a rock stay.
	var big_p: Variant = open_spot(2.5,taken)
	if big_p != null:
		taken.append(big_p)
		var big := await plant("bigfoot_tree",big_p,"hand")
		check("Bigfoot's tree is set down",big > 0)
		held = await press(ground_screen(big_p),true)
		check("a Shift-press at Bigfoot's tree plucks nothing",not record(big).is_empty() and held != "pluck",held)
		check("nor does pluck itself",not reach.pluck(big) and not record(big).is_empty())
	else: check("an open spot for Bigfoot's tree",false)
	var rock_p: Variant = open_spot(1.6,taken)
	if rock_p != null:
		var rock := await plant("rock",rock_p,"hand")
		check("a rock is not a plant",not reach.pluck(rock) and not record(rock).is_empty())
	finish()

func finish() -> void:
	print("pluck probe: %s" % ("PASS" if failures.is_empty() else "FAIL %s" % str(failures)))
	quit(0 if failures.is_empty() else 1)
