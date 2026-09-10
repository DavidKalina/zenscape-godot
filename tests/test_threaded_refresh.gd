extends SceneTree
## Publication hooks must describe completed stages, including rejected workers.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func refresh(editor: NativeChunkEditor, events: Array, completed: Array) -> void:
	completed.append(await editor.refresh(self,func(stage: String) -> void: events.append(stage)))
func run() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(2))
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_process(false)
	editor.data.blades.fill(0.8)
	var id := editor.data.place("tree",Vector2.ZERO)
	editor.refresh()
	editor.data.update_object(id,{"angle":0.3})
	var events: Array = []
	var completed: Array = []
	refresh(editor,events,completed)
	while not editor.content._instance_busy and completed.is_empty(): await process_frame
	check(editor.content._instance_busy,"Refresh reaches pending content preparation")
	editor.data.objects[0].angle += 0.2
	while completed.is_empty(): await process_frame
	check(events == ["terrain"],"Rejected content must not announce content or landmark publication")
	check(completed == [false],"Refresh reports rejected content to its caller")
	check(not editor.content._view_ready,"Rejected content remains eligible for repair")
	events.clear()
	check(await editor.refresh(self,func(stage: String) -> void: events.append(stage)),"A subsequent refresh repairs the changed inputs")
	check(events == ["terrain","content","landmarks"],"Successful repair announces each published stage in order")
	var changed_at_hook := func(stage: String) -> void:
		if stage == "content": editor.data.objects[0].angle += 0.1
	check(not await editor.refresh(self,changed_at_hook),"An input change at a publication hook rejects the remaining refresh")
	check(not editor.content._view_ready,"A change after content publication invalidates its cache for ordinary repair")
	check(await editor.refresh(self),"Ordinary refresh repairs input changes after publication")

	editor.data.update_object(id,{"angle":0.8})
	events.clear()
	completed.clear()
	refresh(editor,events,completed)
	while not editor.content._instance_busy and completed.is_empty(): await process_frame
	check(editor.content._instance_busy,"Older refresh is waiting for content when superseded")
	check(await editor.refresh(),"Synchronous refresh supersedes the pending refresh")
	var current_batches: Array = editor.content._batches.duplicate()
	while completed.is_empty(): await process_frame
	check(completed == [false] and events == ["terrain"],"Superseded refresh stops before announcing rejected content")
	check(current_batches == editor.content._batches and editor.refresh_stage.is_empty(),"Old completion cannot replace the newer scene or its stage status")

	editor._map_ready = false
	events.clear()
	completed.clear()
	refresh(editor,events,completed)
	while not editor._map_busy and completed.is_empty(): await process_frame
	check(editor._map_busy,"Refresh reaches pending surface maps")
	editor.data.heights[0] += 0.1
	while completed.is_empty(): await process_frame
	check(completed == [false],"Refresh reports rejected map inputs instead of completing post-map publication")
	check(editor.refresh_stage == "maps","Rejected maps stop before post-map scene updates")
	check(await editor.refresh(self),"Refresh repairs rejected maps")
	print("REFRESH_INPUT_COST ",JSON.stringify(editor.last_refresh_usec))

	var charge := editor.data.place("explosive",Vector2.ZERO)
	editor.refresh()
	var before_blast: Dictionary = editor.data.to_document()
	editor.explosives.target_id = charge
	editor.explosives.detonate(true)
	while editor.explosives.firing and not (editor.explosives.phase == "refresh" and editor.content._instance_busy): await process_frame
	check(editor.explosives.firing and editor.content._instance_busy,"Blast reaches pending content publication")
	var rejected_generation := editor._refresh_generation
	editor.content.cancel_rebuild()
	while editor.explosives.firing:
		for body in editor.explosives.bodies:
			check(body.freeze and body.collision_layer == 0 and body.collision_mask == 0,"Retried blast keeps debris outside physics until publication completes")
		await process_frame
	check(editor._refresh_generation > rejected_generation,"Blast retries a rejected refresh")
	check(editor.content._view_ready and editor._map_ready and editor.refresh_stage.is_empty(),"Blast finishes only after content and maps are published")
	check(not editor.explosives.bodies.is_empty(),"Retried blast retains its prepared debris")
	await physics_frame
	await physics_frame
	check(editor.explosives.bodies.all(func(body: RigidBody3D) -> bool: return not body.freeze),"Retried debris enters physics after successful publication")
	editor.undo()
	check(editor.data.to_document() == before_blast,"Undo after a retried refresh restores the exact pre-blast document")
	scene.free()
	print("Threaded refresh: ",failures," failures")
	quit(1 if failures else 0)
