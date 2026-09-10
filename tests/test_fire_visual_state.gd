extends SceneTree
## Actual field/view/save and authored-to-physical transitions. Run with Forward+.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: "+message)
func fire_on(node: Node3D, expected: Vector2) -> bool:
	var seen := false
	for visual: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		var material := visual.material_override as ShaderMaterial
		if not FireMaterial.supported(material): continue
		seen = true
		if material.get_shader_parameter("instance_fire_enabled") == true: return false
		var value: Variant = material.get_shader_parameter("object_fire")
		if not value is Vector2 or not value.is_equal_approx(expected): return false
	return seen
func run() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	root.size = Vector2i(1440,900)
	var scene = load("res://studies/diorama.tscn").instantiate()
	scene.library_path = "/private/tmp/fire-visual-state-"+str(Time.get_ticks_usec())
	scene.recent_file = scene.library_path+"/recent.cfg"
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.data.heights.fill(2.0)
	editor.data.objects.clear()
	var log_id := editor.data.place("log",Vector2.ZERO)
	var old_tree := editor.data.place("bigfoot_tree",Vector2(10,-10))
	editor.refresh()
	scene.set_building(false)
	check(scene.invite_bigfoot(Vector3(8,2,8)),"World play is available for physical promotion")
	var field: FireField = scene._fire_field
	var look: FireLook = scene._fire_look
	field._weather = func(): return {"ground_wet":0.0,"snow_cover":0.0,"rain":0.0}
	field.rebuild()
	field._ignite_object(log_id)
	field.objects_state[log_id].elapsed = 10.0
	field.advance(0.125,false)
	look.advance(0.125,false)
	var burning := editor.content.object_fire(log_id)
	check(burning.x > 0.3 and burning.y > 0.5,"Burning log publishes char and ember heat")
	var promoted: Node3D = scene.world_play.promote(log_id)
	check(promoted != null and fire_on(promoted,burning),"Promoted physical log keeps the authored fire appearance")
	# Replacing only painted batches must update play's source references while
	# preserving the live physical object and hiding its authored replacement.
	editor.data.tint[0] = 0.5
	await editor.refresh(self)
	check(scene.world_play._active.get(log_id)==promoted,"Fire refresh preserves the promoted object")
	var hidden := true
	for part in scene.world_play._parts.get(log_id,[]):
		if part.has("batch"):
			hidden = hidden and part.batch.multimesh.get_instance_transform(part.index).basis.determinant()==0.0
	check(hidden,"Fresh authored batches stay hidden for an existing physical object")
	check(scene.world_play._parts[old_tree].all(func(part): return is_instance_valid(part.node)),"Landmark publication also replaces the physical-play source references")
	field._weather = func(): return {"ground_wet":1.0,"snow_cover":0.0,"rain":1.0}
	for i in range(32): field.advance(0.125,false)
	look.advance(0.125,false)
	var quenched := editor.content.object_fire(log_id)
	check(quenched.x > 0.3 and quenched.y == 0.0,"Rain clears ember heat while retaining partial char")
	check(fire_on(promoted,quenched),"Rain also updates the physical log's fire material")
	scene.flush_world_play()
	var saved := editor.data.to_document()
	var fire_saved := field.document()
	check(FireField.valid(fire_saved),"Settled char has a valid optional save document")
	field.restore({})
	check(editor.content.object_fire(log_id)==Vector2.ZERO,"Reset clears authored fire appearance immediately")
	check(editor.data.load_document(saved),"Saved partially charred log restores")
	field.restore(fire_saved)
	check(editor.content.object_fire(log_id).is_equal_approx(quenched),"Saved partial char returns without relighting")
	check(field.document()==fire_saved,"Settled char round-trips exactly")

	# Capture through the actual blast visual-transfer path, without destroying
	# the record before the test has inspected its source material.
	var item := editor.data.object_by_id(log_id)
	var parts: Dictionary = editor.explosives._capture_parts({log_id:{"item":item,"kick":Vector3.ZERO}})
	check(parts.has(log_id),"Blast captures the authored log")
	if parts.has(log_id):
		editor.explosives._launch_parts(parts[log_id],Vector3.ZERO)
		check(fire_on(editor.explosives.bodies.back(),quenched),"Blast debris retains its source char appearance")

	field.restore({})
	check(look.charred().is_empty() and editor.content.object_fire(log_id)==Vector2.ZERO,"Discarding a fire clears both visual caches")
	check(scene._fire_effects._puffs.is_empty() and scene._fire_effects._sparks.is_empty(),"Discarding a fire clears lingering effects")
	scene.free()
	await process_frame
	print("Fire visual state: ",failures," failures")
	quit(1 if failures else 0)
