extends SceneTree
## Actual life scene, real rigid-body ticks and the production brain/controller.
var failures := 0
var scene: Node3D
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func ticks(count: int) -> void:
	for i in range(count): await physics_frame
func wait_state(value: int, limit: int) -> bool:
	for i in range(limit):
		await physics_frame
		if scene.creature.state == value: return true
	return false
func wait_roam(limit: int) -> bool:
	for i in range(limit):
		await physics_frame
		if scene.creature.can_roam(): return true
	return false
func gust(direction: Vector3) -> void:
	scene.wind.emit_gust(scene.creature.global_position+Vector3.UP,direction,17,6,0.85)
func run() -> void:
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 2.0
	scene = load("res://studies/bigfoot_life.tscn").instantiate()
	root.add_child(scene)
	await ticks(8)
	check(await wait_state(CreatureActor.State.WALKING,600),"The real scene begins autonomous walking")
	for pass_index in range(2):
		gust(Vector3(-1,0,0.2) if pass_index == 0 else Vector3(1,0,-0.2))
		check(await wait_state(CreatureActor.State.WIND,90),"Gust interrupts roaming with real physical knockdown "+str(pass_index))
		await ticks(15)
		check(scene.creature.wind_body.linear_velocity.length()>0.1,"Wind physically displaces the live inhabitant")
		if pass_index == 0:
			scene._paused = true
			# Let the production process propagate pause to the physical body.
			await process_frame
			await ticks(2)
			var pose: Transform3D = scene.creature.wind_body.global_transform
			var clock: float = scene.brain._clock
			var age: float = scene.creature._age
			await ticks(30)
			check(scene.creature.wind_body.global_transform.is_equal_approx(pose),"Pause freezes the actual tumbling rigid body")
			check(scene.brain._clock==clock and scene.creature._age==age,"Pause freezes brain and creature animation clocks")
			scene._paused = false
		check(await wait_roam(900),"Physical recovery makes the live inhabitant available again")
		check(await wait_state(CreatureActor.State.WALKING,720),"Brain resumes autonomous walking after physical recovery "+str(pass_index))
	# Interrupt attention with the real carry method, while the brain keeps ticking.
	scene.creature.stop_walking()
	scene.creature.notice(scene.creature.global_position+Vector3(2,1,0))
	check(scene.creature.state==CreatureActor.State.ALERT,"Attention reaction begins before pickup")
	var safe: Vector3 = scene.creature.global_position
	check(scene.creature.pick_up(),"Head pickup interrupts the attention reaction")
	scene.creature.move_held(safe+Vector3.UP*3,1.0/60.0)
	var held: Vector3 = scene.creature.global_position
	await ticks(90)
	check(scene.creature.is_held() and scene.creature.global_position.is_equal_approx(held),"A ticking autonomous brain never drifts a held creature")
	check(scene.creature.player.current_animation=="Held" and scene.creature.player.speed_scale==1,"Head carrying preserves flailing at normal cadence")
	check(not scene.creature.release_at(null),"Invalid release is rejected")
	check(await wait_roam(300),"Invalid release lands safely")
	check(scene.creature.global_position.distance_to(safe)<0.03,"Invalid release returns to the last safe walked point")
	check(await wait_state(CreatureActor.State.WALKING,720),"Brain resumes after invalid drop and landing")
	var destination: Variant = scene.navigation.nearest_safe(scene.creature.global_position+Vector3(1,0,1))
	check(destination is Vector3,"Live navigation supplies a valid release point")
	scene.creature.pick_up()
	scene.creature.move_held(destination+Vector3.UP*3,1.0/60.0)
	check(scene.creature.release_at(destination),"Valid release accepted by real terrain and clearance checks")
	check(await wait_roam(300),"Valid drop completes landing")
	check(scene.creature.global_position.distance_to(destination)<0.03,"Valid release reaches the selected ground point")
	check(await wait_state(CreatureActor.State.WALKING,720),"Brain resumes after valid drop")
	check(scene.creature.global_transform.is_finite(),"Repeated interrupted interactions leave a finite actor pose")
	scene.queue_free()
	await process_frame
	await process_frame
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	print("Bigfoot life interruptions: ",failures," failures")
	quit(1 if failures else 0)
