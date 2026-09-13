extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	create_timer(90).timeout.connect(func() -> void: quit(2))
	var shelter = preload("res://scripts/bigfoot_shelter.gd").new()
	shelter.canopies.append(AABB(Vector3(-2,1,-2),Vector3(4,4,4)))
	check(shelter.quality(Vector3.ZERO)==0.0,"Low foliage cannot qualify as overhead shelter")
	var scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/home-test-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.size = Vector2i(1440,960)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	var tree := editor.data.place("broadleaf",Vector2(3,0),0,3.8)
	editor.refresh()
	scene.invite_bigfoot(Vector3.ZERO)
	var habits = scene.routine.habits
	var points: Array = []
	for point in scene.navigation._nodes:
		if scene.routine._rest_stance(point): points.append(point)
	var ranked: Array = habits.rest_candidates(points,Vector3.ZERO)
	check(not ranked.is_empty() and habits.shelter.quality(ranked[0])>0,"A reachable covered patch outranks exposed ground")
	check(not habits.can_claim(Vector3(-10,0,-10)),"Open ground does not qualify as shelter")
	habits.rested(Vector3(-5,0,0))
	check(habits.home != null and not habits.sheltered_home,"Outdoor resting memory still works")
	check(scene.routine.request("sit"),"He can approach shelter through normal routine planning")
	var inspected := false
	for frame in range(2400):
		scene._process(1.0/60.0)
		inspected = inspected or scene.routine._phase == "inspect_home"
		if habits.sheltered_home and habits.visits>0: break
	check(inspected and habits.home != null and habits.sheltered_home,"He inspects and remembers sheltered ground")
	check(habits.stage == 1 and not habits.bed.is_empty(),"First settled visit makes a leaf bed")
	if habits.home == null or habits.bed.is_empty():
		scene.free()
		quit(1)
		return
	check(not scene._home_button.disabled,"His spot becomes available after choosing a home")
	var home: Vector3 = habits.home
	var bed: Dictionary = habits.bed.duplicate(true)
	var saved: bool = scene.save_current()
	var opened: bool = editor.open_garden()
	check(saved and opened,"Sheltered home saves and reopens")
	check(habits.sheltered_home and habits.home == home and habits.bed == bed,"Home identity and bed survive reload")
	var legacy: Dictionary = habits.capture()
	legacy.version = 1
	legacy.erase("sheltered_home")
	check(habits.valid(legacy),"Existing version-one habit saves remain valid")
	editor.data.begin_stroke()
	editor.data.remove_object(tree)
	editor.data.end_stroke()
	editor.refresh()
	scene._refresh_habitat()
	check(habits.preferred() == null and habits.home == null,"Removing the canopy makes him reconsider home")
	check(editor.data.object_by_id(int(bed.id)) == bed,"Abandoning shelter never deletes the player's bed prop")
	check(habits.allows(home),"Lost cover does not permanently blacklist a repairable site")
	scene.free()
	if failures: print("Preserved fixture: ",folder); quit(1); return
	for name in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+name)
	DirAccess.remove_absolute(folder)
	print("BIGFOOT HOME: failures=",failures)
	quit(1 if failures else 0)
