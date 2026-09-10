extends SceneTree
var failures := 0
var scene: Node
const DT := 1.0/60.0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1

func tick() -> void:
	scene._process(DT)

func wait_until(condition: Callable, seconds := 80.0) -> bool:
	for frame in range(ceili(seconds/DT)):
		if condition.call(): return true
		tick()
	return false

func loose_visual(name: String) -> Node3D:
	var result := Node3D.new()
	result.name = name
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	result.add_child(mesh)
	scene.add_child(result)
	result.global_position = scene.creature.hand_position()
	return result

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: quit(2))
	scene = load("res://studies/bigfoot_lair.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.replaying = false
	scene._growth.publish()
	scene._precipitation.set_weather(0,true)
	scene.routine._next_action = scene.routine._clock+1000.0

	var selected := {}
	for candidate: Dictionary in scene.routine._targets("tree"):
		var nearby: Variant = scene.navigation.nearest_safe(candidate.position+Vector3(0,0,3.0))
		if nearby == null: continue
		scene.creature.reset_at(nearby)
		if scene.creature.position.distance_to(candidate.position)<=11.0 and scene.routine._plan_approach(candidate,"tree") and not scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0]).is_empty():
			selected = candidate
			break
	check(not selected.is_empty(),"Prepared lair study has a reachable material tree")
	if not selected.is_empty():
		check(scene.routine.request("tree",selected),"Tree foraging starts through the ordinary activity request")
		check(wait_until(func() -> bool: return scene.creature.action_clip=="TreeShake",35.0),"Bigfoot reaches the tree and performs authored TreeShake")
		var carrying := wait_until(func() -> bool: return scene.routine.foraging.carrying() and scene.routine.cave.reason=="forage",12.0)
		check(carrying,"TreeShake hands one visible loose branch into the cave carry")
		check(carrying and wait_until(func() -> bool: return scene.creature.player.current_animation=="LogCarry",2.0),"Cave approach uses authored carry locomotion")
		check(carrying and scene.routine.foraging.held.name=="GatheredBranch" and scene.routine.foraging.held.visible and scene.routine.foraging.held.global_position.distance_to(scene.creature.hand_position())<1.0,"The gathered branch remains visible at Bigfoot's hand")
		check(wait_until(func() -> bool: return scene.lair.stash.size()==1,75.0),"Crossing the cave threshold commits the branch to the lair")
		check(scene.lair.stash==["branch"] and scene.lair.stockpile.get_child_count()==1,"The committed branch has one matching stockpile visual")
		check("tree" in scene.routine.history and "branch" in scene.routine.history,"The completed shake and deposited material both remain in activity history")
		check(not scene.routine.foraging.carrying(),"A committed branch has no duplicate transient visual")
		check(wait_until(func() -> bool: return scene.routine.cave.phase.is_empty(),20.0),"Foraging visit exits and returns surface navigation ownership")
		check(scene.navigation.is_safe(scene.creature.position) and scene.routine.active.is_empty(),"Bigfoot finishes the bounded loop on safe surface ground")

	var released := [0]
	var cancelled_visual := loose_visual("CancelledCatch")
	var release_cancelled := func() -> void:
		released[0] += 1
		cancelled_visual.queue_free()
	check(scene.routine.carry_catch_home("leaves","cancelled-source",cancelled_visual,release_cancelled),"A generic gathered material can enter the same carry contract")
	for frame in range(10): tick()
	scene.routine.cancel("test cancellation")
	check(released[0]==1 and scene.lair.stash==["branch"],"Cancellation releases its source exactly once without depositing")
	check(not scene.routine.foraging.carrying() and scene.routine.cave.phase.is_empty(),"Cancellation clears cave and carry ownership")

	# Preserve the successful branch as part of the capacity fixture.
	var full: Array = ["branch"]
	for i in range(23): full.append("leaves")
	scene.lair.restore_stash(full)
	var rejected := [0]
	var committed := [0]
	var full_visual := loose_visual("FullStashCatch")
	var release_full := func() -> void:
		rejected[0] += 1
		full_visual.queue_free()
	var commit_full := func() -> void: committed[0] += 1
	check(scene.routine.carry_catch_home("fruit","full-source",full_visual,release_full,commit_full),"A gathered item can start while capacity is checked at physical deposit")
	check(wait_until(func() -> bool: return rejected[0]>0,75.0),"A full stash rejects the item at the cave threshold")
	check(rejected[0]==1 and committed[0]==0 and scene.lair.stash.size()==24,"Capacity rejection releases once, never commits, and creates no duplicate")
	check(not scene.routine.foraging.carrying(),"Rejected material leaves no held representation")
	check(wait_until(func() -> bool: return scene.routine.cave.phase.is_empty(),20.0),"Rejected delivery still completes its bounded cave exit")

	scene.lair.restore_stash([])
	var failed_release := [0]
	var failed_commit := [0]
	var failed_visual := loose_visual("FailedCommitCatch")
	var release_failed := func() -> void:
		failed_release[0] += 1
		failed_visual.queue_free()
	var commit_failed := func() -> bool:
		failed_commit[0] += 1
		return false
	check(scene.routine.carry_catch_home("fish","failed-source",failed_visual,release_failed,commit_failed),"A source-backed item begins with free stash capacity")
	check(wait_until(func() -> bool: return failed_release[0]>0,75.0),"A failed source commit returns ownership at the threshold")
	check(failed_commit[0]==1 and failed_release[0]==1 and scene.lair.stash.is_empty(),"Failed commit is atomic: no stash item, no lost source, and one release")
	check(not scene.routine.foraging.carrying(),"Failed commit leaves no transient carry representation")

	scene.routine.cancel()
	scene.queue_free()
	await process_frame
	RenderingServer.force_draw(false)
	print("BIGFOOT LAIR FORAGING: failures=",failures)
	quit(1 if failures else 0)
