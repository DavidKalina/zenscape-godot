extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var scene=load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor=scene._chunk_editor
	var reference=editor.data.source_mesh.surface_get_arrays(0)
	editor.start_flat()
	editor.form_range()
	editor.cover_grass()
	var before=editor.data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/terrain-source.json"))
	editor.data.begin_stroke()
	var accepted: bool=editor.data.add_pond(Vector2(source.pool.x,source.pool.z),source.pool.waterY)
	editor.data.end_stroke()
	var with_streams: bool="--with-streams" in OS.get_cmdline_user_args()
	if with_streams: editor._tools.find_child("FillLandscapeStreams",true,false).pressed.emit()
	var field=preload("res://scripts/native_recipe_water.gd").shoreline(editor.data)
	var generated=editor.data.build_mesh().surface_get_arrays(0)
	var vertices: PackedVector3Array=generated[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray=generated[Mesh.ARRAY_COLOR]
	var matched:=0
	var changed:=0
	var max_error:=0.0
	for i in range(0,vertices.size(),3):
		var c: Vector3=(vertices[i]+vertices[i+1]+vertices[i+2])/3.0
		var point:=Vector2(c.x,c.z)
		var shore: float=preload("res://scripts/native_recipe_water.gd").sample_grid(field.shore,c.x,c.z)
		if colors[i]!=before[i]: changed+=1
		if shore>=0.6 or editor.data._recipe_gradients[i/3].length()>=2.1: continue
		var near_stream:=false
		for stream in source.genome.streams:
			for j in range(stream.pts.size()-1):
				var a=stream.pts[j]
				var b=stream.pts[j+1]
				near_stream=near_stream or point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(a.x,a.z),Vector2(b.x,b.z)))<2.0
		if near_stream and not with_streams: continue
		matched+=1
		var expected: Color=reference[Mesh.ARRAY_COLOR][i]
		max_error=maxf(max_error,maxf(absf(colors[i].r-expected.r),maxf(absf(colors[i].g-expected.g),absf(colors[i].b-expected.b))))
	var full_error:=0.0
	var full_mismatches:=0
	if with_streams:
		for i in range(0,colors.size(),3):
			var expected: Color=reference[Mesh.ARRAY_COLOR][i]
			var error:=maxf(absf(colors[i].r-expected.r),maxf(absf(colors[i].g-expected.g),absf(colors[i].b-expected.b)))
			full_error=maxf(full_error,error)
			if error>0.00001: full_mismatches+=1
		print("Whole terrain color mismatches ",full_mismatches," / ",colors.size()/3,"; max error ",full_error)
	var saved=JSON.parse_string(JSON.stringify(editor.data.to_document(),"",true,true))
	var reopened: bool=editor.data.load_document(saved) and editor.data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]==colors
	editor.data.begin_stroke()
	editor.data.heights.fill(20.0)
	editor.data.streams.clear()
	editor.data.end_stroke()
	var dry: bool=preload("res://scripts/native_recipe_water.gd").shoreline(editor.data).is_empty()
	editor.data.undo()
	var undo: bool=editor.data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]==colors
	print("Shoreline changed faces ",changed,"; matched water bank/bed faces ",matched,"; max RGB error ",max_error,"; reopened ",reopened,"; dry ",dry,"; undo ",undo)
	var ok: bool=accepted and changed>50 and matched>30 and max_error<0.00001 and reopened and dry and undo and (not with_streams or full_mismatches==0)
	scene.queue_free()
	await process_frame
	quit(0 if ok else 1)
