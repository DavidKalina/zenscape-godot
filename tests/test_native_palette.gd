extends SceneTree
func _initialize() -> void:
	var source=load("res://assets/zen_reference/geometry.scn").instantiate()
	var arrays=source.get_node("terrain").mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var base: PackedFloat32Array=arrays[Mesh.ARRAY_CUSTOM0]
	var palette=load("res://scripts/native_terrain_palette.gd").new()
	var worst := 0.0
	for i in range(0,vertices.size(),3):
		var x: float = (float(vertices[i].x)+float(vertices[i+1].x)+float(vertices[i+2].x))/3.0
		var z: float = (float(vertices[i].z)+float(vertices[i+1].z)+float(vertices[i+2].z))/3.0
		var color: Color=palette.grass_at_coordinates(x,z)
		worst=maxf(worst,maxf(absf(color.r-base[i*3]),maxf(absf(color.g-base[i*3+1]),absf(color.b-base[i*3+2]))))
	print("Generated grass vs independent imported base colors: max error ",worst)
	var data=load("res://scripts/native_terrain_data.gd").new()
	data.setup(source.get_node("terrain").mesh)
	data.reset_flat()
	data.form_range()
	data.grass.fill(1.0)
	var generated: PackedColorArray = data.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var original: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var alpine_error := 0.0
	var alpine_faces := 0
	for i in range(0,vertices.size(),3):
		var height: float = (float(vertices[i].y)+float(vertices[i+1].y)+float(vertices[i+2].y))/3.0
		if height <= palette.snowline-1.8: continue
		alpine_faces += 1
		alpine_error=maxf(alpine_error,maxf(absf(generated[i].r-original[i].r),maxf(absf(generated[i].g-original[i].g),absf(generated[i].b-original[i].b))))
	print("Generated alpine colors: ",alpine_faces," faces; max error ",alpine_error)
	var saved=data.to_document()
	var reopened=load("res://scripts/native_terrain_data.gd").new()
	reopened.setup(source.get_node("terrain").mesh)
	var roundtrip: bool = reopened.load_document(JSON.parse_string(JSON.stringify(saved,"",true,true)))
	roundtrip = roundtrip and reopened.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR] == generated
	print("Recipe color roundtrip: ",roundtrip)
	var bad=saved.duplicate(true)
	bad.terrain_recipe.width=0.0
	var before = reopened.to_document()
	var rejects: bool = not reopened.load_document(bad) and reopened.to_document() == before
	print("Invalid recipe rejects atomically: ",rejects)
	var summit := 0
	for i in range(data.heights.size()):
		if data.heights[i] > data.heights[summit]: summit=i
	reopened.begin_stroke()
	reopened.brush(data.points[summit],2.0,5.0,"lower",0.0)
	reopened.end_stroke()
	var edited: PackedColorArray = reopened.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var sculpted: bool = edited != generated
	reopened.undo()
	sculpted = sculpted and reopened.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR] == generated
	print("Sculpt updates recipe coloring and undo restores it: ",sculpted)
	reopened.form_range(0.7,0.7,deg_to_rad(35.0),7)
	var varied = reopened.to_document()
	var varied_colors: PackedColorArray = reopened.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var exact: bool = reopened.load_document(JSON.parse_string(JSON.stringify(varied,"",true,true)))
	exact = exact and reopened.to_document() == varied and reopened.build_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR] == varied_colors
	print("Non-default recipe exact document/color roundtrip: ",exact)
	source.free()
	quit(0 if worst < 0.0001 and alpine_error < 0.0001 and alpine_faces > 100 and roundtrip and rejects and sculpted and exact else 1)
