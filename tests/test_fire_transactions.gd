extends SceneTree
## Fire history and asynchronous terrain ownership in the actual fidelity scene.
## Run with Forward+; fixtures hand-drive weather and simulation.

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

	var before := editor.data._snapshot()
	field.ignite(Vector3.ZERO,1.0,1.0)
	scene._advance_fire(0.25)
	check(field.active(),"Fixture has an active fire with initially empty history")
	editor.undo()
	check(not field.active() and not scene._fire_stroke,"Undo closes an active fire and its transaction")
	check(editor.data._snapshot()==before,"Undo the first fire restores exact terrain without an older history entry")

	dry_meadow()
	editor.data.grass.fill(0.2)
	editor.data.meadow.fill(0.1)
	var destination := editor.data.to_document()
	var destination_scene := NativeGardenStore.capture(scene)
	editor.data.grass.fill(1.0)
	editor.data.meadow.fill(0.6)
	field.rebuild()
	field.ignite(Vector3.ZERO,1.0,1.0)
	field.advance(0.25,false)
	check(editor.data.load_document(destination),"Destination garden is valid")
	NativeGardenStore.restore(scene,destination_scene)
	check(editor.data.to_document()==destination,"Loading a different garden cannot inherit old fire cover or tint")

	dry_meadow()
	var charge := editor.data.place("explosive",Vector2.ZERO)
	editor.refresh()
	scene._paused = true
	field.rebuild()
	field.ignite(Vector3.ZERO,1.0,1.0)
	field.advance(0.25,false)
	check(editor.explosives.fire_queue == [charge],"Fire queues a real cook-off while physics is paused")
	field.restore({})
	editor.explosives.clear_effects()
	check(editor.explosives.fire_queue.is_empty(),"Clearing fire/effects cancels queued cook-offs")
	scene._paused = false
	editor.explosives._physics_process(0.0)
	check(not editor.data.object_by_id(charge).is_empty(),"A cancelled cook-off cannot detonate afterward")
	while editor.explosives.firing: await process_frame

	dry_meadow()
	field.ignite(Vector3(5,0,5),1.0,1.0)
	var terrain_before := editor.data._snapshot()
	editor.forming = true
	scene._advance_fire(0.25)
	check(editor.data._snapshot()==terrain_before,"Fire cannot write terrain owned by formation or a blast worker")
	editor.forming = false
	dry_meadow()
	var old_log := editor.data.place("log",Vector2(-5,0))
	field.rebuild()
	field.ignite(Vector3(-5,0,0),0.6,1.0)
	field.advance(0.25,false)
	field.objects_state[old_log].elapsed = 8.0
	field.advance(0.125,false)
	wet = 1.0
	rain = 1.0
	force_weather()
	for i in range(80):
		if not field.active(): break
		field.advance(0.125,false)
	check(not field.active() and field.recovering(),"First fire leaves a partially charred log and recovering ash")
	wet = 0.0
	rain = 0.0
	force_weather()
	var earlier := field.document()
	var earlier_terrain := editor.data._snapshot()
	field.ignite(Vector3(6,0,0),0.6,1.0)
	field.advance(0.25,false)
	editor.undo()
	check(field.document()==earlier,"Undo a later fire preserves earlier char and recovering ash")
	check(editor.data._snapshot()==earlier_terrain,"Undo a later fire preserves the preceding terrain exactly")
	# A real in-flight refresh must observe a stable simulation snapshot.
	dry_meadow()
	field.ignite(Vector3.ZERO,1.0,1.0)
	scene._advance_fire(0.25)
	editor.data.tint[0] = 0.5
	editor.refresh(self)
	check(editor.refresh_pending > 0,"Fixture has an asynchronous refresh in flight")
	var publishing_before := editor.data._snapshot()
	var fire_before := field.document()
	scene._advance_fire(0.25)
	check(editor.data._snapshot()==publishing_before and field.document()==fire_before,"Fire yields terrain ownership throughout refresh publication")
	while editor.refresh_pending > 0: await process_frame
	check(editor.refresh_stage.is_empty(),"Refresh completes while a fire is waiting")

	# Live cook-offs serialize, retain the user's selected target, and undo
	# together with the fire that set them off.
	dry_meadow()
	var first := editor.data.place("explosive",Vector2(-6,0))
	var second := editor.data.place("explosive",Vector2(6,0))
	var untouched := editor.data.place("explosive",Vector2(0,10))
	editor.refresh()
	var remote = editor.explosives
	remote.set_physics_process(false)
	remote.target_id = untouched
	var before_chain := editor.data.to_document()
	field.ignite(Vector3(-6,0,0),1.0,1.0)
	scene._advance_fire(0.25)
	remote.ignite_charge(first)
	remote.ignite_charge(second)
	remote._physics_process(0.0)
	check(remote.firing and editor.forming and remote.fire_queue==[second],"First cook-off starts live preparation and leaves the next charge queued")
	while remote.firing: await process_frame
	check(editor.data.object_by_id(first).is_empty() and not editor.data.object_by_id(second).is_empty(),"One cook-off transaction consumes only its own charge")
	remote._physics_process(0.0)
	while remote.firing: await process_frame
	scene._advance_fire(0.25)
	check(editor.data.object_by_id(second).is_empty() and remote.target_id==untouched,"Queued cook-offs preserve the user's remote selection")
	check(remote.can_restore(),"Remote restoration remains available during the resulting fire")
	var chain_after := editor.data.to_document()
	remote.restore_button.pressed.emit()
	check(editor.data.to_document()==before_chain and not field.active(),"One remote Undo restores both cook-offs and the fire's original terrain")
	check(remote.fire_queue.is_empty() and remote.bodies.is_empty(),"Undo also clears queued blasts and debris")

	editor.redo()
	check(editor.data.to_document()==chain_after and field.active() and remote.can_restore(),"Redo restores the grouped blast and running fire")
	scene._advance_fire(0.25)
	remote.restore_button.pressed.emit()
	check(editor.data.to_document()==before_chain and not field.active(),"Undo after Redo still restores the whole blast and fire group")

	# A separately started blast's later fire belongs to the blast, including
	# after rain has closed the fire stroke.
	dry_meadow()
	var single := editor.data.place("explosive",Vector2(3,3))
	editor.refresh()
	var before_blast := editor.data.to_document()
	remote.target_id = single
	await remote.detonate(true)
	scene._advance_fire(0.25)
	check(field.active(),"A dry blast has a subsequent active fire")
	wet = 1.0
	rain = 1.0
	force_weather()
	for i in range(80):
		if not field.active(): break
		field.advance(0.125,false)
	check(not field.active() and remote.can_restore(),"Remote still offers Undo after the blast's fire goes out")
	remote.restore_button.pressed.emit()
	check(editor.data.to_document()==before_blast,"Undo after extinction restores the blast, not just its fire")

	# Failed heat must not pin an older history snapshot across later recovery.
	wet = 0.0
	rain = 0.0
	force_weather()
	dry_meadow()
	field.ignite(Vector3.ZERO,0.6,0.01)
	for i in range(200): field.advance(0.125,false)
	check(not field.active() and not field.ignition_pending(),"An unsuccessful spark releases its pending history after cooling")
	var char_log := editor.data.place("log",Vector2(8,8))
	field.object_char[char_log] = 0.4
	var after_spark := field.document()
	field.ignite(Vector3.ZERO,0.6,1.0)
	field.advance(0.25,false)
	editor.undo()
	check(field.document()==after_spark,"A later fire captures current char instead of the failed spark's history")

	scene.free()
	await process_frame
	print("Fire transactions: ",failures," failures")
	quit(1 if failures else 0)
