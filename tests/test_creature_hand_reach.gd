extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var actor := CreatureActor.new()
	root.add_child(actor)
	actor.setup("res://assets/models/zenscape-bigfoot-routine.glb")
	actor.set_process(false)
	actor.perform_action("StoneThrow")
	var target := Vector3(-0.457,0.08,0.864)
	actor.reach_hand(target,1.0)
	for i in range(63): actor.advance(1.0/60.0)
	actor.skeleton.force_update_all_bone_transforms()
	var error := actor.hand_position().distance_to(target)
	print("HAND REACH palm=",actor.hand_position()," target=",target," error=",error)
	var failed := error>0.04
	if failed: push_error("Palm must meet reachable contact within 4 cm")
	actor.cancel_action()
	if not actor.hand_targets.is_empty():
		failed = true
		push_error("Cancelling clears hand contacts")
	actor.free()
	quit(1 if failed else 0)
