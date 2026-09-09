extends SceneTree
## Fire in the real scene: lightning ignition and its weather gate, explosives
## both starting and being started by fire, the undo bracket, and the optional
## save sub-document. Runs the actual fidelity scene, so it needs a renderer:
##   --path . --rendering-method forward_plus --script res://tests/test_fire_integration.gd

var failures := 0
var scene: Node3D
var editor: NativeChunkEditor
var field: FireField
## Weather is forced every step; the scene's own advance would otherwise drift
## the numbers the field reads while a case is running.
var wet := 0.0
var rain := 0.0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: "+message)
		print("FAIL: ",message)
	else:
		print("PASS: ",message)

func force_weather() -> void:
	var weather = scene._precipitation.surface_weather
	weather.ground_wet = wet
	weather.air_wet = wet
	weather.foliage_wet = wet
	weather.snow_cover = 0.0
	scene._precipitation.state.x = rain

## Hand-driven frames: the scene's own `_process` is off, so one call is one
## simulated step. Real frames are yielded often enough for the editor's
## budgeted refresh coroutine to finish.
func advance(seconds: float) -> void:
	for i in range(int(seconds*30.0)):
		force_weather()
		scene._process(1.0/30.0)
		if i%3 == 2:
			await process_frame

## A clean, dry, fully fuelled meadow with an empty history, so each case starts
## from the same world however the previous one left it.
func dry_meadow() -> void:
	force_weather()
	field.restore({})
	editor.data.end_stroke()
	scene._fire_stroke = false
	editor.data.begin_stroke()
	editor.data.grass.fill(1.0)
	editor.data.meadow.fill(0.6)
	editor.data.end_stroke()
	editor.data._undo.clear()
	editor.data._redo.clear()
	editor.refresh()
	field.rebuild()

func run() -> void:
	create_timer(300).timeout.connect(func() -> void:
		print("FIRE INTEGRATION: timed out")
		quit(2))
	root.size = Vector2i(960,600)
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	for i in range(6):
		await process_frame
	scene.set_process(false)
	editor = scene._chunk_editor
	editor.set_active(true)
	editor.start_flat()
	field = scene._fire_field
	check(field != null,"The scene owns a FireField beside its other subsystems")
	scene._precipitation.set_weather(0,true)
	dry_meadow()

	# (a) A dry strike catches, and the global rises with it.
	scene._lightning.strike(Vector2(0,0),scene.camera.global_position)
	await advance(2.0)
	check(field.active(),"Lightning on dry grass starts a fire")
	var intensity: float = scene._fire_intensity
	check(intensity > 0.0,"zs_fire rises with the fire (%.3f)" % intensity)
	check(scene._fire_stroke,"The fire opened one editor stroke")

	# (b) The same strike in rain does nothing.
	wet = 1.0
	rain = 1.0
	await advance(6.0)
	check(not field.active(),"Rain puts the fire out")
	check(scene._fire_intensity == 0.0,"zs_fire falls back to zero")
	check(not scene._fire_stroke and editor.data._undo.back().get("fire",false),"The extinguished fire closed one undo step tagged fire")
	var burnt_cover: float = editor.data.grass[editor.data.meadow_cell(Vector2.ZERO)]
	editor.undo()
	await process_frame
	check(editor.data.grass[editor.data.meadow_cell(Vector2.ZERO)] >= burnt_cover,"Undo after a fire restores the burnt cover")
	check(not field.active() and field.burning_cells().is_empty(),"Undo leaves the field cold")
	dry_meadow()
	scene._lightning.strike(Vector2(2,2),scene.camera.global_position)
	await advance(1.0)
	check(not field.active(),"A strike into soaked ground never catches")

	# (c) A detonation leaves fire behind.
	wet = 0.0
	rain = 0.0
	dry_meadow()
	var charge := editor.data.place("explosive",Vector2(-3,1))
	editor.refresh()
	editor.explosives.target_id = charge
	editor.explosives.request_detonation()
	await physics_frame
	await physics_frame
	check(editor.data.object_by_id(charge).is_empty(),"The charge detonated")
	await advance(1.5)
	check(field.active(),"An explosion sets the meadow alight")

	# (d) A charge caught by the fire cooks off through the ordinary path.
	var cooked := editor.data.place("explosive",Vector2(4,-4))
	editor.refresh()
	field.ignite(Vector3(4,editor.data.ground_height(Vector2(4,-4)),-4),1.0,1.0)
	var gone := false
	for i in range(120):
		await advance(0.2)
		await physics_frame
		if editor.data.object_by_id(cooked).is_empty():
			gone = true
			break
	check(gone,"An explosive standing in a fire detonates itself")

	# (e) A torched tree becomes a snag, and undo brings the tree back.
	wet = 0.0
	rain = 0.0
	dry_meadow()
	var trunk := editor.data.place("tree",Vector2(-6,6),0.0,1.0)
	editor.refresh()
	editor.data._undo.clear()
	var before := editor.data._snapshot()
	field.ignite(Vector3(-6,editor.data.ground_height(Vector2(-6,6)),6),0.8,1.0)
	await advance(2.0)
	check(field.objects_state.has(trunk),"The tree over the burning cell catches")
	if field.objects_state.has(trunk):
		field.objects_state[trunk].elapsed = 39.5
	await advance(2.0)
	check(editor.data.object_by_id(trunk).get("asset","") == "snag","A torched tree is left as a snag")
	wet = 1.0
	rain = 1.0
	await advance(10.0)
	check(not field.active(),"The rest of the fire goes out under rain")
	editor.undo()
	await process_frame
	check(editor.data.object_by_id(trunk).get("asset","") == "tree","Undo restores the pre-swap tree record")
	check(editor.data._snapshot() == before,"Undo restores cover, tint and records exactly")

	# The ember tool: a live coal, no record.
	wet = 0.0
	rain = 0.0
	dry_meadow()
	var palette: NativeBuildPalette = scene._build_palette
	var records := editor.data.objects.size()
	palette._take_special("ember")
	check(palette._placing == "ember","The ember palette entry goes into the hand")
	var aim: Vector2 = scene.camera.unproject_position(editor.terrain.to_global(Vector3(0,editor.data.ground_height(Vector2.ZERO),0)))
	check(palette._place_special(aim),"The ember drops onto the ground")
	await advance(2.0)
	check(field.active(),"A dropped ember starts a fire")
	check(editor.data.objects.size() == records,"The ember leaves no record behind")

	# (f) An active fire survives a save and a reopen.
	wet = 0.0
	rain = 0.0
	dry_meadow()
	editor.save_path = "user://fire-integration-test.json"
	field.ignite(Vector3(0,editor.data.ground_height(Vector2.ZERO),0),1.2,1.0)
	await advance(2.0)
	var alight := field.burning_cells().size()
	check(alight > 0,"A fire is burning before the save")
	check(editor.save_garden(),"The burning garden saves")
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(editor.save_path))
	check(stored.scene_state.has("fire") and not stored.scene_state.fire.is_empty(),"The save carries a fire sub-document")
	check(editor.open_garden(),"The burning garden reopens")
	check(field.burning_cells().size() == alight,"The reopened fire has the same burning cells (%d)" % alight)
	await advance(1.0)
	check(field.active(),"The restored fire keeps burning")

	# (g) A save written before fire existed still loads.
	stored.scene_state.erase("fire")
	var old_path := "user://fire-integration-old.json"
	FileAccess.open(old_path,FileAccess.WRITE).store_string(JSON.stringify(stored,"",true,true))
	editor.save_path = old_path
	check(editor.open_garden(),"A save without a fire sub-document still opens")
	check(not field.active(),"An old save restores an inert field")

	scene.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("FIRE INTEGRATION: failures=",failures)
	quit(1 if failures else 0)
