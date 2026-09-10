extends SceneTree
const Bubble = preload("res://scripts/reaction_bubble.gd")
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1280,720)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0,1.5,6)
	camera.look_at(Vector3(0,1.5,0))
	camera.current = true
	var head := Node3D.new()
	world.add_child(head)
	head.position = Vector3(0,1.5,0)
	var bubble = Bubble.new()
	head.add_child(bubble)
	bubble.set_process(false)
	await process_frame

	for symbol: String in Bubble.MOODS:
		bubble.show_reaction(symbol)
		var mood: Array = Bubble.MOODS[symbol]
		check(bubble.showing() and bubble.shape() == mood[0] and bubble.icon() == mood[1],"%s shows a %s bubble with %s" % [symbol,mood[0],mood[1]])
		check(bubble._bubble.texture != null,"%s bubble art loads" % symbol)
		for holder: Node2D in bubble._icon.get_children():
			check((holder.get_child(0) as Sprite2D).texture != null,"%s icon art loads" % symbol)
		bubble._process(1.0)
		check(bubble._layer.visible,"%s stays visible mid-reaction" % symbol)
		check(bubble.text == symbol,"%s is reported as the current symbol" % symbol)

	check(Bubble.MOODS["?"] == ["thought","question"],"Question marks think")
	check(Bubble.MOODS["!!"][0] == "shout","Temper shouts")
	check(Bubble.MOODS["fish"][0] == "speech","Wanting a fish is said aloud")

	bubble.show_reaction("🙃")
	check(bubble.showing() and bubble.icon() == "exclaim","Unknown symbols still get a readable bubble")

	bubble.show_reaction("fish")
	bubble._process(0.5)
	var age: float = bubble._age
	bubble.show_reaction("fish")
	check(bubble._age == age,"Repeating the shown reaction does not pop it again")

	bubble.frozen = true
	var life: float = bubble._life
	bubble._process(5.0)
	check(bubble._life == life and bubble.showing(),"Pause freezes the reaction")
	bubble.frozen = false

	var view := root.get_visible_rect()
	check(view.has_point(bubble._root.position),"The tail follows the head on screen")
	head.position = Vector3(40,-30,0)
	bubble._process(0.01)
	var reach: Rect2 = Rect2(bubble._root.position-Bubble.TAILS[bubble._shape]*bubble._root.scale,Bubble.EXTENT.size*bubble._root.scale)
	check(view.encloses(reach.grow(-1.0)),"An off-screen head keeps the bubble inside the view")
	head.position = Vector3(0,1.5,20)
	bubble._process(0.01)
	check(not bubble._layer.visible,"A head behind the camera hides the bubble")
	head.position = Vector3(0,1.5,0)
	head.visible = false
	bubble._process(0.01)
	check(not bubble._layer.visible,"A hidden creature hides his bubble")
	head.visible = true

	bubble.show_reaction("")
	check(not bubble.showing() and not bubble._layer.visible,"An empty reaction clears the bubble")
	bubble.show_reaction("rainbow")
	bubble._process(bubble.hold+0.1)
	check(not bubble.showing() and not bubble._layer.visible,"A reaction ends after its hold")

	print("Failures: %d" % failures)
	quit(failures)
