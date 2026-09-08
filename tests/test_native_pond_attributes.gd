extends SceneTree
var failures := 0
var checked_vertices := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func verify(view: GardenView,label: String) -> void:
	var arrays: Array = view._water.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var fetch_a: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var fetch_b: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	var max_fetch_error := 0.0
	var max_depth_error := 0.0
	var max_color_error := 0.0
	for i in range(vertices.size()):
		var p := vertices[i]
		var depth := maxf(0.0,p.y-float(view.data.ground_height(Vector2(p.x,p.z))))
		max_depth_error = maxf(max_depth_error,absf(uv[i].x-depth))
		var expected_color := Color("79ae9b").lerp(Color("245a5c"),1.0-exp(-depth/0.45)).srgb_to_linear()
		# ArrayMesh packs COLOR into 8-bit channels; compare to that storage.
		var quantized := Color.hex(expected_color.to_rgba32())
		for axis in range(4): max_color_error = maxf(max_color_error,absf(colors[i][axis]-quantized[axis]))
		var expected: PackedFloat32Array = view.data.pond_fetch(Vector2(p.x,p.z),p.y)
		for axis in range(4):
			max_fetch_error = maxf(max_fetch_error,absf(fetch_a[i*4+axis]-expected[axis]))
			max_fetch_error = maxf(max_fetch_error,absf(fetch_b[i*4+axis]-expected[axis+4]))
	checked_vertices += vertices.size()
	check(vertices.size()>0 and max_fetch_error == 0.0,label+": every fetch value matches uncached direct query")
	check(max_depth_error<0.000001,label+": every depth matches direct terrain query")
	check(max_color_error<=1.0/255.0+0.000001,label+": every color matches depth palette within vertex storage precision")
func run() -> void:
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.reset_flat()
	data.brush(Vector2.ZERO,3.0,1.0,"lower",0.0)
	check(data.add_pond(Vector2.ZERO,-0.2),"Standalone pond exists")
	var view := GardenView.new()
	view.data = data
	view.set_process(false)
	root.add_child(view)
	view.rebuild()
	verify(view,"Initial pond")
	var first: PackedVector3Array = view.pond_vertices.duplicate()
	data.brush(Vector2(1,0),1.4,0.5,"raise",0.0)
	view.rebuild()
	verify(view,"Edited basin")
	check(view.pond_vertices != first,"Terrain edit actually changes tested pond geometry")
	view.rebuild(true)
	verify(view,"Forced fresh build")
	view.free()
	print("Pond attributes: ",failures," failures; ",checked_vertices," vertex records checked")
	quit(1 if failures else 0)
