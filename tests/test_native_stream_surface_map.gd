extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var scene=load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var expected: Image=scene._precipitation.stream_texture.get_image()
	var expected_ground: Image=scene._precipitation.ground_texture.get_image()
	var texture=scene._precipitation.stream_texture
	var editor=scene._chunk_editor
	editor.start_flat()
	editor.form_range()
	var pool: Dictionary=editor.data._recipe.source.pool
	editor.data.add_pond(Vector2(pool.x,pool.z),pool.waterY)
	scene._build_panel._tools.find_child("FillLandscapeStreams",true,false).pressed.emit()
	var actual: Image=texture.get_image()
	var actual_ground: Image=scene._precipitation.ground_texture.get_image()
	var wet:=0
	var mask_errors:=0
	var error:=0.0
	var height_error:=0.0
	for z in range(128):
		for x in range(128):
			var a:=expected.get_pixel(x,z)
			var b:=actual.get_pixel(x,z)
			if (a.a>0.5)!=(b.a>0.5): mask_errors+=1
			if a.a<0.5: continue
			wet+=1
			error=maxf(error,maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b))))
			height_error=maxf(height_error,absf(expected_ground.get_pixel(x,z).a-actual_ground.get_pixel(x,z).a))
	var before: PackedByteArray=actual.get_data()
	editor.data.undo()
	editor.refresh()
	var removed: bool=texture.get_image().get_data().count(0)==texture.get_image().get_data().size()
	editor.data.redo()
	editor.refresh()
	var restored: bool=texture.get_image().get_data()==before and scene._precipitation.stream_texture==texture
	var saved=JSON.parse_string(JSON.stringify(editor.data.to_document(),"",true,true))
	var reopened: bool=editor.data.load_document(saved)
	editor.refresh()
	reopened=reopened and texture.get_image().get_data()==before
	print("Reopened stream surface map exact: ",reopened)
	print("Stream surface pixels ",wet,"; mask differences ",mask_errors,"; channels max error ",error,"; water height error ",height_error,"; undo clears ",removed,"; redo restores existing texture ",restored)
	var ok: bool=wet>100 and mask_errors==0 and error<0.00001 and height_error<0.00001 and removed and restored and reopened
	scene.queue_free()
	await process_frame
	quit(0 if ok else 1)
