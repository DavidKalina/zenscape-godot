extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var scene=load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var water: MeshInstance3D=scene.get_node("Reference/mesh-30")
	var arrays=water.mesh.surface_get_arrays(0)
	var v: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var reference:=PackedVector3Array()
	var indices: Variant=arrays[Mesh.ARRAY_INDEX]
	if indices!=null and indices.size()>0:
		for i in indices: reference.append(water.to_global(v[i]))
	else:
		for vertex in v: reference.append(water.to_global(vertex))
	var editor=scene._chunk_editor
	editor.start_flat()
	editor.select_tool("range")
	editor.form_range()
	editor.cover_grass()
	var params: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/terrain-source.json")).pool
	var accepted: bool=editor.data.add_pond(Vector2(params.x,params.z),params.waterY)
	var with_fall: bool="--with-fall" in OS.get_cmdline_user_args()
	var with_streams: bool=with_fall or "--with-streams" in OS.get_cmdline_user_args()
	if with_streams: scene._build_palette.action_for("FillLandscapeStreams").pressed.emit()
	if with_fall: scene._build_palette.action_for("FillLandscapeWaterfall").pressed.emit()
	editor.refresh()
	var authored: PackedVector3Array=editor.content.pond_vertices
	var counts: Dictionary={"reference":0,"authored":0,"both":0,"different":0}
	for z in range(-85,20):
		for x in range(20,105):
			var point:=Vector2(x*0.1,z*0.1)
			var a: bool=GardenWater.covers(reference,point)
			var b: bool=GardenWater.covers(authored,point)
			if a: counts.reference+=1
			if b: counts.authored+=1
			if a and b: counts.both+=1
			if a!=b: counts.different+=1
	print("Pond accepted ",accepted,"; footprint samples ",JSON.stringify(counts)," reference height ",reference[0].y)
	var reference_depths: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
	var by_center := {}
	var reference_colors := {}
	for i in range(0,reference.size(),3):
		var c: Vector3=(reference[i]+reference[i+1]+reference[i+2])/3.0
		var key:=Vector2i(roundi(c.x*10000),roundi(c.z*10000))
		var index: int=indices[i] if indices!=null and indices.size()>0 else i
		by_center[key]=reference_depths[index].x
		reference_colors[key]=arrays[Mesh.ARRAY_COLOR][index]
	var generated_arrays=editor.content._water.mesh.surface_get_arrays(0)
	var generated_depths: PackedVector2Array=generated_arrays[Mesh.ARRAY_TEX_UV2]
	var source_streams: Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/terrain-source.json")).genome.streams
	var color_matches:=0
	var color_error:=0.0
	var matched:=0
	var depth_error:=0.0
	for i in range(0,authored.size(),3):
		var c: Vector3=(authored[i]+authored[i+1]+authored[i+2])/3.0
		var key:=Vector2i(roundi(c.x*10000),roundi(c.z*10000))
		var near_stream:=false
		for stream in source_streams:
			for j in range(stream.pts.size()-1):
				var a: Dictionary=stream.pts[j]
				var b: Dictionary=stream.pts[j+1]
				var point:=Vector2(c.x,c.z)
				near_stream=near_stream or point.distance_to(Geometry2D.get_closest_point_to_segment(point,Vector2(a.x,a.z),Vector2(b.x,b.z))) < 1.6
		if by_center.has(key) and (with_streams or not near_stream):
			matched+=1
			var expected: Color=reference_colors[key]
			# Imported white impact foam requires an authored fall, absent here.
			if with_fall or expected.r<0.8:
				color_matches+=1
				var actual: Color=generated_arrays[Mesh.ARRAY_COLOR][i]
				color_error=maxf(color_error,maxf(absf(actual.r-expected.r),maxf(absf(actual.g-expected.g),absf(actual.b-expected.b))))
			depth_error=maxf(depth_error,absf(generated_depths[i].x-by_center[key]))
	print("Matched lake depth faces (streams included: ",with_streams,"): ",matched,"; max depth error ",depth_error)
	var material_match: bool=editor.content._water_material.get_shader_parameter("source_lake_material")==true
	for parameter in ["lake_swell","lake_look","lake_volume","lake_algae_amount","lake_algae_richness","lake_algae_seed"]:
		material_match=material_match and editor.content._water_material.get_shader_parameter(parameter)==water.mesh.surface_get_material(0).get_shader_parameter(parameter)
	print("Reference lake material settings retained: ",material_match)
	print("Lake color faces (impact included: ",with_fall,"): ",color_matches,"; max RGB error ",color_error)
	var reference_fetch := {}
	for i in range(reference.size()):
		var index: int=indices[i] if indices!=null and indices.size()>0 else i
		var key:=Vector2i(roundi(reference[i].x*10000),roundi(reference[i].z*10000))
		var values: Array[float]=[]
		for channel in [Mesh.ARRAY_CUSTOM0,Mesh.ARRAY_CUSTOM1]:
			for axis in range(4): values.append(arrays[channel][index*4+axis])
		reference_fetch[key]=values
	var fetch_error:=0.0
	var fetch_vertices:=0
	for i in range(authored.size()):
		var key:=Vector2i(roundi(authored[i].x*10000),roundi(authored[i].z*10000))
		if not reference_fetch.has(key): continue
		fetch_vertices+=1
		for c in range(2):
			var channel: int=Mesh.ARRAY_CUSTOM0 if c==0 else Mesh.ARRAY_CUSTOM1
			for axis in range(4):
				fetch_error=maxf(fetch_error,absf(generated_arrays[channel][i*4+axis]-reference_fetch[key][c*4+axis]))
	print("Fetch matched vertices ",fetch_vertices,"; eight-direction max error ",fetch_error)
	var foam_lifecycle:=true
	if with_fall:
		var foam_colors: PackedColorArray=preload("res://scripts/native_recipe_water.gd").build(editor.data,editor.data.ponds[0]).colors
		editor.data.begin_stroke()
		editor.data.landscape_waterfall=false
		editor.data.end_stroke()
		var clear_colors: PackedColorArray=preload("res://scripts/native_recipe_water.gd").build(editor.data,editor.data.ponds[0]).colors
		editor.data.undo()
		foam_lifecycle=clear_colors!=foam_colors and preload("res://scripts/native_recipe_water.gd").build(editor.data,editor.data.ponds[0]).colors==foam_colors
		print("Removing waterfall clears foam; undo restores exact colors: ",foam_lifecycle)
	var saved=editor.data.to_document()
	var original_surface: PackedVector3Array=authored.duplicate()
	var roundtrip: bool=editor.data.load_document(JSON.parse_string(JSON.stringify(saved,"",true,true)))
	roundtrip = roundtrip and editor.data.pond_surface(editor.data.ponds[0]) == original_surface
	editor.data.begin_stroke()
	editor.data.heights.fill(20.0)
	editor.data.end_stroke()
	var dry: bool=editor.data.pond_surface(editor.data.ponds[0]).is_empty()
	editor.data.undo()
	var restored: bool=editor.data.pond_surface(editor.data.ponds[0])==original_surface
	print("Pond exact roundtrip ",roundtrip,"; raised basin dry ",dry,"; undo restored ",restored)
	var ok: bool=accepted and counts.reference>3000 and counts.different==0 and roundtrip and dry and restored and matched>100 and depth_error<0.00001 and material_match and fetch_vertices>500 and fetch_error<0.00001 and color_matches>100 and color_error<0.00001 and foam_lifecycle and (not with_fall or color_matches==authored.size()/3)
	scene.queue_free()
	await process_frame
	quit(0 if ok else 1)
