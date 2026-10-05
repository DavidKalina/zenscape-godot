extends SceneTree
const Plate = preload("res://scripts/plate.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	# A real triangulated chunk keeps this model contract independent of the UI.
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-Plate.HALF,0,-Plate.HALF),Vector3(Plate.HALF,0,-Plate.HALF),Vector3(-Plate.HALF,0,Plate.HALF),Vector3(Plate.HALF,0,-Plate.HALF),Vector3(Plate.HALF,0,Plate.HALF),Vector3(-Plate.HALF,0,Plate.HALF)])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var data := NativeTerrainData.new()
	data.setup(mesh)
	var pose := NativeObjectPose.make(Basis.from_euler(Vector3(0.1,0.3,0.2)).scaled(Vector3(1.2,1.8,0.7)),0.4)
	var tint := NativeObjectPose.encode_tint(Color(0.3,0.6,0.2))
	var id := data.place("tree",Vector2.ZERO,0.3,1.2,pose,tint)
	var neighbor := data.place("rock",Vector2.ONE)
	var original := data.to_document()
	var snapshot := data.object_by_id(id)
	snapshot.pose.offset = "0".repeat(16)
	check(data.object_by_id(id).pose == pose,"Lookup returns a deep copy")
	data.begin_stroke()
	check(data.update_object(id,{"x":2.0,"z":3.0}),"Existing tree moves by identity")
	check(data.update_object(id,{"x":4.0,"scale":1.5,"angle":0.7}),"One gesture accepts successive edits")
	check(data.end_stroke(),"Gesture records history")
	var edited := data.to_document()
	check(data.object_by_id(id).pose == pose and data.object_by_id(id).tint == tint,"Movement preserves custom appearance")
	check(data.object_by_id(neighbor) == original.objects[1],"Editing does not touch neighboring objects")
	check(data.undo() and data.to_document() == original,"Entire gesture undoes exactly")
	check(data.redo() and data.to_document() == edited,"Redo restores exact authored records")
	var revision := data.objects_revision
	data.begin_stroke()
	check(not data.update_object(id,{"x":4.0}) and not data.update_object(id,{}),"No-op edits report no mutation")
	for patch in [{"x":NAN},{"z":INF},{"x":15.0},{"scale":0.0},{"angle":INF},{"id":777},{"asset":"rock"},{"pose":{"basis":"bad"}},{"tint":"bad"},{"scale":2.0,"z":"3"}]:
		check(not data.update_object(id,patch),"Invalid edit rejects: "+str(patch))
	check(not data.update_object(-1,{"x":1.0}),"Missing identity rejects")
	check(data.objects_revision == revision and data.to_document() == edited and not data.end_stroke(),"Rejected and no-op edits leave records, revision and history untouched")
	data.begin_stroke()
	var copy_id := data.duplicate_object(id)
	data.end_stroke()
	var copy := data.object_by_id(copy_id)
	check(copy_id > neighbor and copy_id != id,"Duplicate receives fresh identity")
	copy.id = id
	check(copy == data.object_by_id(id),"Duplicate preserves every other field")
	check(data.undo() and data.object_by_id(copy_id).is_empty(),"Duplicate undoes")
	check(data.redo() and not data.object_by_id(copy_id).is_empty(),"Duplicate redoes with same identity")
	data.begin_stroke()
	check(data.update_object(copy_id,{"pose":{},"tint":""}),"Appearance overrides can be cleared")
	data.end_stroke()
	check(not data.object_by_id(copy_id).has("pose") and data.object_by_id(id).pose == pose,"Clearing duplicate overrides leaves source intact")
	data.begin_stroke()
	check(data.remove_object(copy_id),"Delete targets selected identity")
	data.end_stroke()
	check(data.undo() and not data.object_by_id(copy_id).is_empty(),"Delete undo restores selected object")
	check(data.redo() and data.object_by_id(copy_id).is_empty(),"Delete redo removes selected object")
	var saved := data.to_document()
	check(data.load_document(JSON.parse_string(JSON.stringify(saved,"",true,true))),"Edited objects reopen from JSON")
	check(data.to_document() == saved,"Save round trip preserves identity, pose, tint and transforms")
	var arch_id := data.place("arch",Vector2(-2,0))
	check(not data.update_object(arch_id,{"pose":pose}) and not data.update_object(arch_id,{"tint":tint}),"Landmark appearance restrictions remain enforced")
	check(data.update_object(arch_id,{"x":-3.0,"angle":0.4,"scale":1.3}),"Landmark position, rotation and scale remain editable")
	revision = data.objects_revision
	check(not data.remove_object(-1) and data.duplicate_object(-1) == -1 and data.object_by_id(-1).is_empty(),"Missing IDs are safe for every operation")
	check(data.objects_revision == revision,"Missing IDs do not invalidate renderer")
	_check_generated_flora()
	print("Native object editing: ",failures," failures")
	quit(1 if failures else 0)

func _check_generated_flora() -> void:
	var geometry: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(geometry.get_node("terrain").mesh)
	geometry.free()
	data.form_range()
	check(data.fill_landscape_flora(),"Range generates editable flora")
	if data.objects.size() < 2:
		check(false,"Generated range includes multiple pieces")
		return
	var customized_id: int = data.objects[0].id
	var untouched_id: int = data.objects[1].id
	var before := data.object_by_id(customized_id)
	var revision := data.objects_revision
	check(not data.update_object(customized_id,{"x":before.x}),"No-op edit does not claim a generated piece")
	check(not data.update_object(customized_id,{"x":INF}),"Rejected edit does not claim a generated piece")
	check(data.object_by_id(customized_id).get("landscape",false) and data.objects_revision == revision,"Untouched generated ownership is preserved")
	data.begin_stroke()
	check(data.update_object(customized_id,{"angle":0.75}),"Customizing generated flora succeeds")
	data.end_stroke()
	var customized := data.object_by_id(customized_id)
	check(not customized.get("landscape",false),"Customized flora detaches from refill ownership")
	check(data.undo() and data.object_by_id(customized_id) == before,"Undo restores generated ownership and appearance")
	check(data.redo() and data.object_by_id(customized_id) == customized,"Redo restores customized ownership")
	var duplicate_id := data.duplicate_object(untouched_id)
	var duplicate := data.object_by_id(duplicate_id)
	var expected := data.object_by_id(untouched_id)
	expected.id = duplicate_id
	expected.erase("landscape")
	check(duplicate == expected,"Duplicated generated flora preserves every authored field and detaches ownership")
	check(data.object_by_id(untouched_id).get("landscape",false),"Duplicating leaves generated source ownership unchanged")
	check(data.fill_landscape_flora(),"Flora can regenerate after customization")
	check(data.object_by_id(customized_id) == customized and data.object_by_id(duplicate_id) == duplicate,"Refill preserves customized and duplicated pieces exactly")
	check(data.object_by_id(untouched_id).is_empty(),"Refill replaces untouched generated pieces")
