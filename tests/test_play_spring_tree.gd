extends SceneTree
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var tree = preload("res://scripts/play_spring_tree.gd").new()
	root.add_child(tree)
	tree.begin_grab()
	tree.drag_to(Vector3(-100,0,0))
	for i in range(60): tree.advance(1.0/60.0)
	check(tree.tension <= 1.001 and tree.tension > 0.98,"Pull clamps at elastic limit")
	check(tree.center(0).is_equal_approx(tree.global_position),"Root remains anchored")
	check(tree.center(5).x < -3.0,"Crown visibly bends along trunk")
	check(tree.sweep_contact(Vector2.ZERO,Vector3(-1,2,0),0.016)==Vector3.ZERO,"Held tree cannot hit")
	tree.release()
	var maximum := 0.0
	var contacts := 0
	for i in range(360):
		var previous: Vector2 = tree.bend
		tree.advance(1.0/60.0)
		maximum = maxf(maximum,tree.bend.x)
		if tree.sweep_contact(previous,Vector3(0.8,2.2,0),1.0/60.0).length()>0: contacts+=1
	check(maximum > 0.5,"Release overshoots upright")
	check(contacts==1,"Swept branch contact fires once per release")
	check(tree.bend.length()<0.01,"Spring settles")
	tree.begin_grab()
	tree.drag_to(Vector3(4,0,0))
	for i in range(30): tree.advance(1.0/60.0)
	tree.cancel()
	for i in range(30):
		var previous: Vector2 = tree.bend
		tree.advance(1.0/60.0)
		check(tree.sweep_contact(previous,tree.center(2),1.0/60.0)==Vector3.ZERO,"Cancellation disarms rebound")
	tree.reset()
	check(tree.bend==Vector2.ZERO and tree.velocity==Vector2.ZERO and not tree.held,"Reset clears motion and input")
	tree.free()
	print("Spring tree: ",failures," failures")
	quit(1 if failures else 0)
