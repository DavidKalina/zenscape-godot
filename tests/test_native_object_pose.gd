extends SceneTree
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _run() -> void:
	var scene=load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor=scene._chunk_editor
	editor.start_flat()
	editor.set_active(true)
	editor.mode="tree"
	editor.object_width=1.25
	editor.object_height=1.7
	editor.object_depth=0.8
	editor.object_pitch=15.0
	editor.object_roll=-10.0
	editor.object_angle=deg_to_rad(35.0)
	editor.object_elevation=0.35
	scene._reset_camera()
	var click:=InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	click.position=scene.camera.unproject_position(Vector3.ZERO)
	editor.handle_input(click)
	click.pressed=false
	editor.handle_input(click)
	check(editor.data.objects.size()==1,"Customized tree places through camera ray")
	var item: Dictionary=editor.data.objects[0]
	var pose=preload("res://scripts/native_object_pose.gd")
	check(item.has("pose") and pose.valid(item.pose),"Custom pose is stored and valid")
	var basis: Basis=pose.decode_basis(item.pose)
	check(is_equal_approx(basis.x.length(),1.25) and is_equal_approx(basis.y.length(),1.7) and is_equal_approx(basis.z.length(),0.8),"Independent local dimensions are retained")
	check(absf(basis.y.x)>0.01 and absf(basis.y.z)>0.01,"Both tilt controls affect the pose")
	var rendered: Array[Transform3D]=[]
	for batch in editor.content._batches:
		rendered.append(batch.multimesh.get_instance_transform(0))
		check(batch.multimesh.get_instance_transform(0).basis==basis,"Both tree parts render the exact authored basis")
		check(is_equal_approx(batch.multimesh.get_instance_transform(0).origin.y,0.35),"Vertical offset reaches renderer")
	var saved=editor.data.to_document()
	check(editor.data.load_document(JSON.parse_string(JSON.stringify(saved,"",true,true))),"Customized placement reopens")
	editor.refresh()
	for i in range(rendered.size()):
		check(editor.content._batches[i].multimesh.get_instance_transform(0)==rendered[i],"Reopening preserves rendered transforms exactly")
	var before=editor.data.to_document()
	var bad=before.duplicate(true)
	bad.objects[0].pose.basis="0".repeat(72)
	check(not editor.data.load_document(bad) and editor.data.to_document()==before,"Singular pose rejects atomically")
	editor.data.begin_stroke()
	editor.data.erase_objects(Vector2.ZERO,1.0)
	editor.data.end_stroke()
	editor.undo()
	check(editor.data.objects[0].pose==item.pose,"Undo preserves the exact custom pose")
	scene.queue_free()
	await process_frame
	print("Native object pose: ",failures," failures")
	quit(1 if failures else 0)
