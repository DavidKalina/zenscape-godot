extends SceneTree
## The playground's real camera and terrain must agree with the interaction
## actor about picking, grounding, invalid drops and resetting mid-drag.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var scene: Node3D = load("res://studies/bigfoot_playground.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var creature: Node3D = scene.creature
	check(creature != null,"Playground starts with a Bigfoot actor")
	if creature == null:
		quit(1)
		return
	creature.set_process(false)
	var home: Vector3 = creature.land_position
	check(scene.valid_landing(home),"Bigfoot starts on a valid piece of terrain")
	check(not scene.valid_landing(Vector3(1000,0,1000)),"The void outside the chunk cannot accept a drop")
	var on_screen: Vector2 = scene.camera.unproject_position(home+Vector3.UP*0.8)
	check(scene.pick_creature(on_screen),"The visible creature can be selected through the real camera ray")
	check(not scene.pick_creature(Vector2(-10000,-10000)),"An off-screen pointer cannot select Bigfoot")
	creature.pick_up()
	creature.move_held(home+Vector3(4,3,0),1.0/60.0)
	scene.reset_creature()
	check(not creature.is_held(),"Reset interrupts a held creature")
	check(creature.land_position.is_equal_approx(home),"Reset restores the initial safe position")
	check(creature.global_position.is_equal_approx(home),"Reset puts the creature back on the clearing")
	check(creature.global_transform.is_finite(),"Reset leaves a finite transform")
	print("Bigfoot playground: ",failures," failures")
	quit(1 if failures else 0)
