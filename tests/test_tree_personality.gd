extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func simulate(fps: int) -> Array[Vector3]:
	var tree := PlaySpringTree.new()
	root.add_child(tree)
	tree.begin_grab()
	tree.drag_to(Vector3(-4,0,1))
	for i in range(fps): tree.advance(1.0/fps)
	tree.release()
	var samples: Array[Vector3] = []
	for i in range(fps*6):
		var previous := tree.bend
		var previous_tip := tree.center(5)
		tree.advance(1.0/fps)
		check(tree.center(5,previous).distance_to(previous_tip)<0.00001,"Sweep begins at last rendered crown")
		check(tree.center(0).is_equal_approx(tree.global_position),"Root stays anchored throughout recoil")
		check(tree.center(5).is_finite(),"Finite crown under rebound")
		if i%int(fps/10)==int(fps/10)-1: samples.append(tree.center(5))
	check(tree.bend==Vector2.ZERO and tree.crown==Vector2.ZERO and tree.tip==Vector2.ZERO,"All motion comes to rest")
	tree.reset()
	check(tree.center(5).is_equal_approx(Vector3.UP*5),"Reset clears deformation")
	tree.free()
	return samples
func _run() -> void:
	for profile in [1,2]:
		PlaySpringTree.motion_style = profile
		var low := simulate(30)
		var high := simulate(120)
		var error := 0.0
		for i in range(low.size()): error = maxf(error,low[i].distance_to(high[i]))
		check(error<0.002,"30/120 Hz crown paths agree")
		print("Profile ",profile," maximum frame-rate difference: ",error)
	PlaySpringTree.motion_style = 2
	var tree := PlaySpringTree.new()
	root.add_child(tree)
	tree.begin_grab()
	tree.drag_to(Vector3(-4,0,0))
	for i in range(120): tree.advance(1.0/120.0)
	tree.release()
	for i in range(20): tree.advance(1.0/120.0)
	check((tree.crown-tree.bend).length()>0.15,"Crown visibly trails trunk on release")
	tree.begin_grab()
	tree.cancel()
	for i in range(120):
		var before := tree.bend
		tree.advance(1.0/120.0)
		check(tree.sweep_contact(before,tree.center(3),1.0/120.0)==Vector3.ZERO,"Cancelled secondary motion cannot strike")
	tree.free()
	print("Tree personality: ",failures," failures")
	quit(1 if failures else 0)
