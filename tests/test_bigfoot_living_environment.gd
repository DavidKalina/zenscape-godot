extends SceneTree
## Native integration of the cave's resident owner with main's environment owner.
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ",message)
	if not ok: failures += 1

func run() -> void:
	var scene = load("res://studies/bigfoot_living_world.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	scene._precipitation.set_weather(0,true)
	var living = scene.routine.living
	var environment = scene.environment_life
	environment.autonomous = false
	var plan: Dictionary = scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0])
	check(not plan.is_empty(),"Combined scene retains a reachable cave")
	if plan.is_empty():
		scene.free()
		quit(1)
		return
	scene.creature.reset_at(plan.entrance)
	check(living.request("check_home"),"Needs controller starts a home visit")
	check(not environment.request("horizon"),"An environmental invitation cannot steal a home journey")
	environment.autonomous = true
	environment._next = 0.0
	check(not environment.advance(0.05) and living.current=="check_home","Autonomous quiet reactions respect the needs controller")
	environment.autonomous = false

	# The owner switch must preserve unrelated props already in flight.
	var prop := MeshInstance3D.new()
	prop.mesh = SphereMesh.new()
	scene.routine.add_child(prop)
	prop.global_position = scene.creature.global_position+Vector3.UP*5.0
	var projectile := {"node":prop,"velocity":Vector3.RIGHT,"age":0.0,"source_id":-1,"settled":false}
	scene.routine._projectiles.append(projectile)
	var before: Vector3 = prop.global_position
	var needs_clock: float = living.mind.elapsed
	scene._lightning.struck.emit(scene.creature.global_position)
	scene._process(0.05)
	check(environment.active=="shock" and living.current.is_empty() and scene.routine.cave.phase.is_empty(),"Lightning releases the home journey and owns the reaction")
	check(prop.global_position!=before and is_equal_approx(projectile.age,0.05),"Existing projectiles advance exactly once during environmental ownership")
	check(is_equal_approx(living.mind.elapsed,needs_clock+0.05),"Needs advance exactly once while an environmental reaction owns movement")
	var clock: float = environment._clock
	needs_clock = living.mind.elapsed
	before = prop.global_position
	scene._paused = true
	scene._process(0.05)
	check(environment._clock==clock and prop.global_position==before and living.mind.elapsed==needs_clock,"Pause freezes the reaction, projectile, and needs together")
	scene._paused = false
	environment.cancel()
	scene.creature.reset_at(plan.entrance)
	environment._begin("rain",scene.creature.position+Vector3.FORWARD*4.0,6.0)
	check(scene.creature.can_roam() and environment.busy(),"Environmental approach owns an otherwise roamable actor")
	check(not living.request("check_home"),"A needs invitation cannot steal an environmental approach")
	environment.cancel()
	living.enabled = false
	check(scene.routine.cave.request("sleep"),"Legacy cave visit remains available")
	check(not environment.request("horizon"),"Environmental activity also respects a legacy cave visit")
	scene.routine.cancel("test complete")
	scene.free()
	print("LIVING ENVIRONMENT: failures=",failures)
	quit(1 if failures else 0)
