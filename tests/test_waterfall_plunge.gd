extends SceneTree
## An authored fall lands with spray, bobbing foam, and rings on its pond.
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: "+message)
func click(editor: NativeChunkEditor, point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = editor.scene.camera.unproject_position(Vector3(point.x,editor.data.ground_height(point),point.y))
	editor.handle_input(event)
	event.pressed = false
	editor.handle_input(event)
func _run() -> void:
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.reactions_enabled = false
	editor.set_active(true)
	editor.start_flat()
	var data := editor.data
	data.begin_stroke()
	data.mountain(Vector2(-5,0),7.0,10.0)
	data.brush(Vector2(3,0),3.0,1.0,"lower",0.0)
	data.end_stroke()
	check(data.add_pond(Vector2(3,0),-0.2),"Create receiving pond")
	editor.refresh()
	scene._reset_camera()
	editor.mode = "waterfall"
	click(editor,Vector2(-4,0))
	click(editor,Vector2(3,0))
	check(data.objects.size() == 1 and editor.falls.get_child_count() == 2,"Waterfall keeps one mesh and one spray child")
	if data.objects.is_empty():
		quit(1)
		return
	var entry: Dictionary = editor.falls._entries[data.objects[0].id]
	check(entry.has("plunge") and entry.plunge.get_parent() == entry.mesh,"Plunge rides under the fall mesh")
	var plunge = entry.plunge
	var ends: PackedVector3Array = NativeGardenFalls.endpoints(data,data.objects[0])
	check(plunge.base.distance_to(ends[1]) < 0.001,"Plunge sits at the fall's landing point")
	check(plunge.in_pool,"Landing in the pond enables ripple rings")
	check(plunge.spray.emitting and plunge.spray.amount >= 24,"Droplet spray emits at the plunge")
	check(plunge.foam.multimesh.instance_count == roundi(4+plunge.flow*3),"Foam blob count follows the source cluster rule")
	check(plunge.rings.multimesh.instance_count == plunge.RINGS,"Ripple rings are allocated for a pond landing")
	var rest: float = plunge.foam.multimesh.get_instance_transform(0).origin.y
	var ring_before: float = plunge.rings.multimesh.get_instance_transform(0).basis.x.length()
	editor.falls._process(0.4)
	var bobbed: float = plunge.foam.multimesh.get_instance_transform(0).origin.y
	check(absf(bobbed-rest) > 0.001 and absf(bobbed-rest) <= 0.081,"Foam bobs within the source amplitude")
	check(plunge.rings.multimesh.get_instance_transform(0).basis.x.length() != ring_before,"Rings roll outward over time")
	scene._paused = true
	editor.falls._process(0.4)
	check(plunge.spray.speed_scale == 0.0,"Pause holds the spray")
	scene._paused = false
	# A fall that ends on dry ground gets foam and spray but no rings.
	data.begin_stroke()
	data.ponds.clear()
	data.end_stroke()
	editor.refresh()
	if editor.falls._entries.has(data.objects[0].id):
		var dry = editor.falls._entries[data.objects[0].id].plunge
		check(not dry.in_pool and dry.rings.multimesh == null,"Dry landing skips ripple rings")
	editor.undo()
	check(editor.falls.get_child_count() == 2 and editor.falls._entries[data.objects[0].id].plunge.in_pool,"Undo restores the pond plunge")
	scene.free()
	await create_timer(0.25).timeout
	print("Waterfall plunge: ",failures," failures")
	quit(1 if failures else 0)
