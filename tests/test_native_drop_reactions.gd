extends SceneTree
## Placement reactions are purely visual: they start away from the committed
## pose, resolve to it exactly, never edit the record, freeze with the scene
## and leave nothing behind when a refresh or an undo cuts them short.
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func click(editor: NativeChunkEditor, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = editor.scene.camera.unproject_position(Vector3(point.x,editor.data.ground_height(point),point.y))
	editor.handle_input(event)
	event.pressed = false
	editor.handle_input(event)

func snapshot(editor: NativeChunkEditor) -> PackedByteArray:
	var rows := []
	for batch: MultiMeshInstance3D in editor.content._batches:
		var transforms := []
		for i in range(batch.multimesh.instance_count):
			transforms.append(batch.multimesh.get_instance_transform(i))
		rows.append([batch.get_meta("part"),transforms])
	return var_to_bytes(rows)

func instance_of(editor: NativeChunkEditor, part: String, record: Dictionary) -> Variant:
	for batch: MultiMeshInstance3D in editor.content._batches:
		if batch.get_meta("part") != part:
			continue
		var recipes: Array = editor.content._sources[part]
		for i in range(recipes.size()):
			if recipes[i].item != null and recipes[i].item.id == record.id:
				return batch.multimesh.get_instance_transform(i)
	return null

## The pose a live reaction is resolving to, read from the reaction itself so
## the test compares against the committed value and not the animated one.
func committed_of(editor: NativeChunkEditor, part: String, record: Dictionary) -> Transform3D:
	return editor.reactions.targets_of(record)[part]

func dust_nodes(editor: NativeChunkEditor) -> int:
	var count := 0
	for child in editor.reactions.get_children():
		if child.name.begins_with("Dust_"):
			count += 1
	return count

func run(editor: NativeChunkEditor, seconds: float) -> void:
	var step := 1.0/60.0
	for i in range(int(ceil(seconds/step))):
		editor.reactions.advance(step)

func _run() -> void:
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_active(true)
	editor.start_flat()
	scene._reset_camera()
	editor.reactions.set_process(false)
	check(editor.reactions_enabled,"Reactions are on by default")

	# A tree sprouts from nothing and lands on the committed instance transform.
	editor.mode = "tree"
	click(editor,Vector2(2,1))
	var tree: Dictionary = editor.data.objects.back()
	var record := var_to_bytes(tree)
	check(editor.reactions.active_count() == 1,"Placing a tree starts one reaction")
	var committed := committed_of(editor,"trunk",tree)
	check(committed == editor.reactions.record_pose(tree),"A tree renders on the record's own pose")
	var start: Transform3D = instance_of(editor,"trunk",tree)
	check(start.basis.x.length() < committed.basis.x.length()*0.05,"A sprouting tree starts far below its final size")
	run(editor,NativeDropReactions.SPROUT_DURATION*0.2)
	var midway: float = instance_of(editor,"trunk",tree).basis.x.length()
	check(midway > start.basis.x.length() and midway < committed.basis.x.length(),"The sprout grows toward its committed size")
	run(editor,NativeDropReactions.SPROUT_DURATION*0.3)
	check(instance_of(editor,"trunk",tree).basis.x.length() > committed.basis.x.length(),"The sprout overshoots its final size before settling")
	check(var_to_bytes(editor.data.objects.back()) == record,"The record is untouched while the tree sprouts")
	run(editor,NativeDropReactions.SPROUT_DURATION)
	check(editor.reactions.active_count() == 0,"The sprout ends after its duration")
	check(instance_of(editor,"trunk",tree) == committed,"The tree resolves to exactly the committed transform")
	check(instance_of(editor,"canopy",tree) == committed,"Every part of the tree resolves to the committed transform")
	check(var_to_bytes(editor.data.objects.back()) == record,"The record is untouched by the whole reaction")
	check(editor.reactions.shape({"sprout":true,"anchor":committed.origin},1.0) == Transform3D.IDENTITY,"The sprout offset is exactly identity at the end")

	# A rock falls in from above, squashes, kicks up dust and clears it away.
	editor.mode = "rock"
	click(editor,Vector2(-2,1))
	var rock: Dictionary = editor.data.objects.back()
	var rock_rest := committed_of(editor,"rock",rock)
	editor.reactions.advance(1.0/60.0)
	check(instance_of(editor,"rock",rock).origin.y > rock_rest.origin.y+0.1,"A rock starts above its resting height")
	check(dust_nodes(editor) == 0,"No dust before the rock lands")
	run(editor,NativeDropReactions.DROP_DURATION*NativeDropReactions.FALL_FRACTION)
	check(dust_nodes(editor) == 1,"Landing kicks up one dust puff")
	var landed: Transform3D = instance_of(editor,"rock",rock)
	check(landed.basis.y.length() < rock_rest.basis.y.length(),"The rock squashes as it lands")
	run(editor,NativeDropReactions.DROP_DURATION)
	check(editor.reactions.active_count() == 0 and dust_nodes(editor) == 0,"The rock reaction ends and its dust is freed")
	check(instance_of(editor,"rock",rock) == rock_rest,"The rock resolves to exactly its committed pose")

	# Pause freezes a reaction exactly where it stands.
	editor.mode = "flower"
	click(editor,Vector2(0,3))
	var flower: Dictionary = editor.data.objects.back()
	run(editor,0.15)
	var frozen: Transform3D = instance_of(editor,"stem",flower)
	scene._paused = true
	run(editor,0.4)
	check(instance_of(editor,"stem",flower) == frozen,"Pause freezes the reaction where it stands")
	check(editor.reactions.active_count() == 1,"A paused reaction stays live")
	scene._paused = false
	run(editor,NativeDropReactions.SPROUT_DURATION)
	check(editor.reactions.active_count() == 0,"Unpausing lets the reaction finish")

	# Undo mid-animation leaves no live reaction, no dust and no extra instances.
	editor.mode = "rock"
	click(editor,Vector2(3,-2))
	run(editor,NativeDropReactions.DROP_DURATION*0.75)
	check(editor.reactions.active_count() == 1 and dust_nodes(editor) == 1,"The undone rock is mid-reaction")
	var before := editor.data.objects.size()
	editor.undo()
	editor.reactions.advance(1.0/60.0)
	check(editor.data.objects.size() == before-1,"Undo removes the record")
	check(editor.reactions.active_count() == 0 and dust_nodes(editor) == 0,"Undo during a reaction leaves no reaction or dust node")
	var rock_count := 0
	for batch: MultiMeshInstance3D in editor.content._batches:
		if batch.get_meta("part") == "rock":
			rock_count = batch.multimesh.instance_count
	check(rock_count == 1,"Undo during a reaction leaves no orphan instance")

	# A landmark reacts through its own node, and the Bigfoot tree thumps.
	editor.mode = "arch"
	click(editor,Vector2(-4,-3))
	var arch: Node3D = editor.landmarks.get_child(editor.landmarks.get_child_count()-1)
	var arch_rest := committed_of(editor,"landmark",editor.data.objects.back())
	editor.reactions.advance(1.0/60.0)
	check(arch.position.y > arch_rest.origin.y+0.1,"The arch falls in from above its resting height")
	run(editor,NativeDropReactions.DROP_DURATION)
	check(arch.transform == arch_rest,"The arch resolves to exactly its rebuilt transform")
	editor.mode = "bigfoot_tree"
	scene._tremor.trauma = 0.0
	click(editor,Vector2(5,-5))
	var big: Node3D = editor.landmarks.get_child(editor.landmarks.get_child_count()-1)
	var big_rest := committed_of(editor,"landmark",editor.data.objects.back())
	check(big.basis.x.length() < big_rest.basis.x.length()*0.05,"The Bigfoot tree sprouts from nothing")
	run(editor,NativeDropReactions.BIGFOOT_DURATION*0.65)
	check(scene._bigfoot.rig != null and scene._tremor.trauma > 0.0 and scene._tremor.trauma <= NativeDropReactions.THUMP,"The Bigfoot tree thumps the ground through the tremor")
	run(editor,NativeDropReactions.BIGFOOT_DURATION)
	check(big.transform == big_rest and editor.reactions.active_count() == 0,"The Bigfoot tree resolves to its rebuilt transform")

	# With reactions off the placement is byte-identical to a resolved one.
	editor.mode = "tree"
	editor.reactions_enabled = false
	click(editor,Vector2(-1,-1))
	check(editor.reactions.active_count() == 0,"Disabled reactions never start")
	var quiet := snapshot(editor)
	var ids := var_to_bytes(editor.data.objects.map(func(item: Dictionary) -> int: return item.id))
	editor.undo()
	editor.reactions_enabled = true
	click(editor,Vector2(-1,-1))
	check(editor.reactions.active_count() == 1,"The same placement with reactions on animates")
	check(snapshot(editor) != quiet,"The reaction visibly offsets the instance while it runs")
	run(editor,NativeDropReactions.SPROUT_DURATION)
	check(snapshot(editor) == quiet,"A resolved reaction matches the disabled placement exactly")
	check(var_to_bytes(editor.data.objects.map(func(item: Dictionary) -> int: return item.id)) == ids,"Both placements commit the same records")

	# A refresh mid-reaction drops it rather than leaving a half-scaled instance.
	editor.mode = "tree"
	click(editor,Vector2(4,4))
	run(editor,0.1)
	var pending: Dictionary = editor.data.objects.back()
	editor.force_refresh()
	editor.reactions.advance(1.0/60.0)
	check(editor.reactions.active_count() == 0,"A rebuild drops the running reaction")
	check(instance_of(editor,"trunk",pending) == editor.reactions.record_pose(pending),"The rebuild leaves the committed transform, not a partial one")

	print("Native drop reactions: ",failures," failures")
	quit(1 if failures else 0)
