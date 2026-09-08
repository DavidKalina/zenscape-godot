extends SceneTree
## Metal integration: unprompted development, ownership and transactional saves.
var failures := 0
var scene: Node
var save_path := "/tmp/bigfoot-habits-%d.json" % OS.get_process_id()
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func tick(seconds: float) -> void:
	for frame in range(roundi(seconds*60)): scene._process(1.0/60.0)
func write_document(document: Dictionary) -> void:
	var file := FileAccess.open(save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(document,"",true,true))
	file.close()
func _run() -> void:
	scene = load("res://studies/fidelity_life.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene._refresh_habitat()
	var grass: MultiMeshInstance3D = scene.get_node("Reference/mesh-15")
	var source: MultiMesh = grass.multimesh
	var source_poses: Array[Transform3D] = []
	for i in range(source.instance_count): source_poses.append(source.get_instance_transform(i))
	var habits = scene.routine.habits
	var stages: Array[int] = [0]
	var first_home: Variant = null
	var unsafe := 0
	for second in range(310):
		tick(1.0)
		if not scene.navigation.is_safe(scene.creature.position): unsafe += 1
		if habits.home != null and first_home == null: first_home = habits.home
		if habits.stage not in stages:
			stages.append(habits.stage)
			print("HABIT stage=",habits.stage," at=",second+1," home=",habits.home," visits=",habits.visits)
		if second%10 == 0: await process_frame
	check(stages == [0,1,2,3],"Ordinary play develops all three bed stages")
	check(first_home != null and habits.home == first_home and habits.visits>=4,"He returns to the remembered place across repeated rests")
	check(unsafe==0 and scene.routine.last_cancel.is_empty(),"Natural development remains navigable without interrupted routines: "+scene.routine.last_cancel)
	var editor: NativeChunkEditor = scene._chunk_editor
	var bed_count := 0
	for record in editor.data.objects:
		if record.asset == "leaf_bed": bed_count += 1
	check(bed_count==1,"Repeated visits improve one bed, without littering the garden")
	check(grass.multimesh != source,"A bed flattens a private copy of soft bank cover")
	for i in range(source.instance_count): check(source.get_instance_transform(i)==source_poses[i],"Imported foliage remains unchanged")
	var selectable := false
	for part in editor.selection.parts():
		if int(part.id)==int(habits.bed.get("id",-1)): selectable = true
	check(selectable,"Bed mesh participates in actual editor selection")
	if habits.bed.is_empty():
		scene.free()
		quit(1)
		return
	scene._paused = true
	var saved_memory: Dictionary = habits.capture()
	tick(8)
	check(habits.capture()==saved_memory,"Pause freezes habit development")
	editor.save_path = save_path
	check(editor.save_garden(),"Garden saves the developed resting spot")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	habits.forget()
	check(editor.open_garden(),"Saved garden opens while paused")
	check(habits.home==first_home and habits.stage==3 and habits.visits==int(document.scene_state.bigfoot_habits.visits) and habits.bed==editor.data.object_by_id(int(document.scene_state.bigfoot_habits.bed.id)),"Open restores favorite, visits, stage and bed identity")
	var invalid := document.duplicate(true)
	invalid.scene_state.bigfoot_habits.stage = 999
	write_document(invalid)
	var before := editor.data.to_document()
	var memory: Dictionary = habits.capture()
	check(not editor.open_garden() and editor.data.to_document()==before and habits.capture()==memory,"Invalid habit data rejects the entire open without mutation")
	if habits.bed.is_empty():
		scene.free()
		quit(1)
		return
	var id := int(habits.bed.id)
	var old_home: Vector3 = habits.home
	editor.select_object(id)
	editor.delete_selected()
	check(grass.multimesh == source,"Deleting the bed restores the original soft cover")
	check(habits.home==null and not habits.allows(old_home),"Deleting the selectable bed relinquishes its place")
	editor.undo()
	check(not editor.data.object_by_id(id).is_empty() and habits.home==null,"Undo restores the prop without overriding the player's choice to clear the habit")
	check(editor.save_garden() and editor.open_garden() and not habits.allows(old_home),"Respect for a cleared place survives save/load")
	write_document(document)
	check(editor.open_garden(),"Original developed garden can be reopened")
	editor.data.begin_stroke()
	editor.data.update_object(id,{"x":float(habits.bed.x)+0.6})
	editor.data.end_stroke()
	editor.refresh()
	var moved := editor.data.object_by_id(id)
	check(habits.home==null and moved.x!=document.scene_state.bigfoot_habits.bed.x,"Moving his bed transfers authorship to the player")
	habits.tend(old_home,Vector3.UP,0.0)
	check(editor.data.object_by_id(id)==moved,"He never moves a player-edited bed back")
	write_document(document)
	editor.open_garden()
	editor.data.begin_stroke()
	editor.data.brush(Vector2(old_home.x,old_home.z),2.0,2.0,"lower",old_home.y)
	editor.data.end_stroke()
	editor.refresh()
	scene._refresh_habitat()
	check(habits.home==null,"Terrain removal invalidates the remembered resting surface")
	var legacy := document.duplicate(true)
	legacy.scene_state.erase("bigfoot_habits")
	write_document(legacy)
	check(editor.open_garden() and habits.home==null and habits.avoided.is_empty(),"Legacy garden opens with fresh memory, retaining its ordinary bed prop")
	DirAccess.remove_absolute(save_path)
	print("BIGFOOT HABITS: stages=",stages," failures=",failures)
	scene.free()
	quit(1 if failures else 0)
