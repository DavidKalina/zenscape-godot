extends SceneTree
var failures := 0
var scene: Node
const DT := 1.0/60.0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1
func tick(seconds: float) -> void:
	for frame in range(ceili(seconds/DT)):
		if not scene.routine.advance(DT): scene.brain.advance(DT)
		scene.creature.advance(DT)
func wait_phase(wanted: String, seconds := 50.0) -> bool:
	for frame in range(ceili(seconds/DT)):
		if scene.routine.cave.phase == wanted: return true
		tick(DT)
	return false
func reset_visit() -> void:
	scene.routine.cancel()
	scene.creature.reset_at(scene.navigation.nearest_safe(Vector3(5.6,0.54,-7.7)))
	scene.brain.reset_behavior()
	scene.routine._next_action = scene.routine._clock+1000.0
func run() -> void:
	create_timer(180).timeout.connect(func() -> void: quit(2))
	scene = load("res://studies/bigfoot_cave.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	scene._growth.terrain = 1.0
	scene._growth.replaying = false
	scene._precipitation.set_weather(0,true)
	var cave = scene.routine.cave
	var data: NativeTerrainData = scene._chunk_editor.data
	var bore: Dictionary = data.tunnels[0].duplicate(true)
	var masks: Array = scene.cave_sites._masked.duplicate()
	check(not masks.is_empty(),"Cave masks entrance foliage on private instances")
	scene._chunk_editor.refresh()
	scene._refresh_habitat()
	var remasked := true
	for record in scene.cave_sites._masked:
		for saved in record.transforms:
			remasked = remasked and record.node.multimesh.get_instance_transform(saved.index).basis.determinant()==0.0
	check(remasked and not scene.cave_sites._masked.is_empty(),"Unrelated refresh retains the cleared doorway")
	check(NativeGardenStore.capture(scene).get("diorama",{}).get("resident",false),"Study saves include the resident for main-game loading")
	check(not cave.plan(bore).is_empty(),"Fidelity cave has a safe approach and underground passage")
	check(scene.routine.request("sleep"),"Ordinary sleep chooses the cave")
	check(wait_phase("resting"),"Bigfoot walks into the hillside and settles")
	scene._process(DT)
	check(cave.sheltered() and cave.concealed and not scene.creature.visible,"Crossing the black doorway removes Bigfoot from view")
	var floor_hit: Variant = data.ray_hit(scene.creature.position+Vector3.UP,Vector3.DOWN)
	check(floor_hit != null and floor_hit.distance_to(scene.creature.position)<0.03,"Actor feet match the actual cut floor")
	var clock: float = cave._away
	var position: Vector3 = scene.creature.position
	scene._paused = true
	for frame in range(120): scene._process(DT)
	check(is_equal_approx(cave._away,clock) and scene.creature.position == position,"Pause freezes cave rest and movement")
	scene._paused = false
	check(wait_phase("leaving",60.0) and not cave.concealed,"Rest completes by reappearing behind the doorway")
	check(wait_phase("",20.0) and cave.visits==1,"He walks back out and returns navigation ownership")
	check(scene.navigation.is_safe(scene.creature.position),"Exit finishes on safe surface ground")
	check(scene.creature._ground_probe == scene.navigation._ground,"Exit restores ordinary ground probing")
	reset_visit()
	scene._precipitation.set_weather(1,true)
	cave._cooldown = 0
	check(wait_phase("resting",60.0) and cave.reason=="rain","Sustained rain autonomously prompts shelter")
	tick(50.0)
	check(cave.phase=="resting","He remains sheltered while rain continues")
	scene._precipitation.set_weather(0,true)
	check(wait_phase("leaving",12.0),"A settled spell of clear weather prompts emergence")
	reset_visit()
	scene._precipitation.set_weather(3,true)
	cave._cooldown = 0
	check(wait_phase("resting",60.0) and cave.reason=="snow","Snow selects the longer winter rest")
	tick(50.0)
	check(cave.phase=="resting","Winter rest lasts longer than an ordinary sleep")
	check(wait_phase("leaving",60.0),"Winter rest eventually ends")
	reset_visit()
	scene._precipitation.set_weather(0,true)
	check(cave.request() and wait_phase("resting"),"Another cave visit can begin")
	data.begin_stroke()
	data.tunnels[0].sealed = true
	data.end_stroke()
	scene._chunk_editor.refresh()
	scene._refresh_habitat()
	check(cave.phase.is_empty() and scene.navigation.is_safe(scene.creature.position),"Sealing an occupied cave safely releases its resident")
	check(not cave.request(),"A sealed cave cannot be selected")
	data.undo()
	scene._chunk_editor.refresh()
	scene._refresh_habitat()
	check(cave.request(),"Undo restores a usable cave")
	cave.cancel()
	var document := data.to_document()
	check(data.load_document(JSON.parse_string(JSON.stringify(document))),"Cave terrain survives JSON save and reload")
	var narrow := bore.duplicate(true)
	narrow.width = 2.0
	narrow.erase("cave")
	check(cave.plan(narrow).is_empty(),"A tunnel too narrow for Bigfoot is rejected")
	var sealed := bore.duplicate(true)
	sealed.sealed = true
	check(cave.plan(sealed).is_empty(),"Sealed tunnel planning is rejected")
	scene.free()
	print("BIGFOOT CAVE: failures=",failures)
	quit(1 if failures else 0)
