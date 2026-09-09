extends SceneTree
const Presets = preload("res://scripts/native_landscape_presets.gd")
const Blast = preload("res://scripts/terrain_blast.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: "+message)

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: quit(2))
	var reference: Node3D = load("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(reference.get_node("terrain").mesh)
	reference.free()
	for family in Presets.PRESETS:
		await Presets.form(data,family)
		var p := Vector2(4,4)
		var id := data.place("explosive",p)
		var anchored := data.object_position(data.object_by_id(id))
		data.brush(p,2,0.8,"raise",0)
		var before := data._snapshot()
		check(data.object_position(data.object_by_id(id)) == anchored,family+": cover does not lift charge")
		data.begin_stroke()
		Blast.carve_native(data,anchored,3.0)
		data.remove_object(id)
		data.end_stroke()
		check(data.heights != before.heights,family+": native vertices excavate")
		var mesh := data.build_mesh()
		check(mesh != null and not mesh.get_faces().is_empty(),family+": crater renders on this terrain recipe")
		check(data.undo() and data._snapshot() == before,family+": exact restoration includes water and vegetation")
		var document := data.to_document()
		check(data.load_document(JSON.parse_string(JSON.stringify(document,"",true,true))),family+": armed world saves and reopens")
	data.reset_flat()
	var first := data.place("explosive",Vector2.ZERO)
	for i in range(data.MAX_EXPLOSIVES-1): data.duplicate_object(first)
	check(data.explosive_count() == 32 and data.duplicate_object(first) == -1 and data.place("explosive",Vector2.ONE) == -1,"Placement and duplicate respect the shared charge limit")
	var document := data.to_document()
	document.objects.append(document.objects[0].duplicate(true))
	document.objects.back().id = document.next_id
	document.next_id += 1
	check(not data.load_document(document),"Save loader rejects charges beyond the shared budget")
	# Legacy reference scenery uses the same item/remote without diorama_world_play.
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	var editor: NativeChunkEditor = scene._chunk_editor
	scene._paused = false
	var p := Vector2(-4,4)
	var id := editor.data.place("explosive",p)
	editor.refresh()
	var before := editor.data.to_document()
	editor.explosives.request_detonation()
	while editor.explosives.requested or editor.explosives.firing: await physics_frame
	await physics_frame
	check(editor.data.object_by_id(id).is_empty(),"Shared remote detonates in the original fidelity scene")
	check(editor.explosives.collisions.get_child_count()>0,"Scenes without world play receive crater collision")
	check(not editor.data.source_replacements.is_empty(),"Imported reference scenery participates in destruction")
	editor.explosives.restore_button.pressed.emit()
	await process_frame
	check(editor.data.to_document() == before,"Legacy scenery and source replacements restore exactly")
	scene.free()
	await create_timer(0.25).timeout
	print("Explosive landscape coverage: ",failures," failures")
	quit(1 if failures else 0)
