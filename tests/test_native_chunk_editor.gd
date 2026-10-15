extends SceneTree
## The editor changes the original fidelity terrain, without replacing its look.
## suite: gpu
var failures := 0
var capture_directory := ""
var save_file := OS.get_temp_dir().path_join("native-garden-test-%d.json" % OS.get_process_id())

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_directory = arg.trim_prefix("--capture-dir=")
	_run.call_deferred()

func _run() -> void:
	## The bare headless root is 64 px; clicks need a screen to land on.
	root.size = Vector2i(1440,960)
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = true
	var editor: NativeChunkEditor = scene._chunk_editor
	check(editor.update_ground, "Fidelity editor keeps the scene ground (rain, lightning) updated")
	editor.set_process(false)
	var terrain: MeshInstance3D = scene.get_node("Reference/terrain")
	var mesh: ArrayMesh = terrain.mesh
	var camera: Camera3D = scene.camera
	var pose := camera.transform
	var environment: Environment = scene._environment
	var arrays := mesh.surface_get_arrays(0)
	var ground_bytes: PackedByteArray = scene._precipitation.ground_texture.get_image().get_data()
	var skirt_mesh: ArrayMesh = scene.get_node("Reference/skirt").mesh
	await capture("native-original", scene)
	check(editor.data.build_mesh() == mesh, "Unedited data returns the original mesh resource")
	editor.set_active(true)
	check(terrain.mesh == mesh and scene.camera == camera and camera.transform == pose, "Build preserves original chunk and camera")
	check(scene._environment == environment, "Build preserves original environment")
	check(terrain.get_active_material(0).shader == mesh.surface_get_material(0).shader, "Build uses the original shader")
	await capture("native-build", scene)
	editor.set_active(true)
	editor.set_active(false)
	check(terrain.material_override == null, "Repeated mode selection restores the original material")
	editor.set_active(true)
	scene._growth.set_terrain(0.4)
	check(editor.pick(Vector2(800,450)) == null, "Growth replay suspends picking against the displaced shader surface")
	scene._growth.set_terrain(1.0)
	# A central triangle centroid provides a real interior point independent of
	# the irregular imported triangulation or the initial camera framing.
	var data := editor.data
	var point := Vector2.ZERO
	var original: float = data.height_at(point.x, point.y)
	check(data.height_at(80,80) == null, "Outside the chunk is not editable ground")
	var hit: Variant = data.ray_hit(Vector3(0,30,0), Vector3.DOWN)
	check(hit != null and absf(hit.y-original) < 0.0001, "Picking and height sampling agree on the actual mesh")
	data.begin_stroke()
	data.brush(point,3.0,1.5,"raise",original)
	data.end_stroke()
	editor.refresh()
	check(float(data.height_at(0,0)) > original + 0.5, "Native vertices form a sculpted hill")
	var edited := terrain.mesh.surface_get_arrays(0)
	check(edited[Mesh.ARRAY_VERTEX].size() == arrays[Mesh.ARRAY_VERTEX].size(), "Sculpt preserves source topology")
	check(edited[Mesh.ARRAY_COLOR] == arrays[Mesh.ARRAY_COLOR], "Sculpt preserves source vertex colors")
	check(edited[Mesh.ARRAY_TEX_UV] == arrays[Mesh.ARRAY_TEX_UV], "Sculpt preserves source UVs")
	check(edited[Mesh.ARRAY_CUSTOM0] == arrays[Mesh.ARRAY_CUSTOM0], "Sculpt preserves source base-color attributes")
	var verts: PackedVector3Array = edited[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = edited[Mesh.ARRAY_TEX_UV2]
	for i in range(verts.size()):
		check(absf(uv2[i].y-verts[i].y) < 0.0001, "Growth shader target height follows the edited vertex")
	check(scene.camera == camera and camera.transform == pose and scene._environment == environment, "Sculpt does not replace camera or lighting")
	var sculpted := data.heights.duplicate()
	await capture("native-sculpt", scene)
	editor.undo()
	## The plate shows the imported mesh cut to its island outline (1ed5dfe0).
	check(terrain.mesh == data.play_mesh(mesh) and data.heights == data.original_heights, "Undo restores the exact imported mesh")
	editor.redo()
	check(data.heights == sculpted, "Redo restores the exact edit")
	editor.undo()
	# Real event-time camera ray: the first click works without a cached hover.
	scene._ui.visible = false
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.position = camera.unproject_position(terrain.to_global(Vector3(0,original,0)))
	button.pressed = true
	## Under modeless controls (the default since 7a1d6669) the left press is
	## the hand's; the click-to-sculpt is --classic-controls'.
	var classic: bool = not preload("res://scripts/modeless_input.gd").enabled()
	if classic: scene._unhandled_input(button)
	button.pressed = false
	if classic: scene._input(button)
	check(not classic or data.heights != data.original_heights, "First mouse click sculpts the inspected chunk")
	check(not scene._orbiting and not editor._painting, "Left sculpt does not start orbit and release closes the stroke")
	if classic: editor.undo()
	button.button_index = MOUSE_BUTTON_RIGHT
	button.pressed = true
	scene._unhandled_input(button)
	check(scene._orbiting, "Right drag still orbits in Build mode")
	button.pressed = false
	scene._input(button)
	check(not scene._orbiting, "Camera drag ends on release")
	editor.set_active(false)
	check(terrain.material_override == null and terrain.mesh == data.play_mesh(mesh), "Inspect after undo has the exact source terrain and material")
	editor.set_active(true)
	editor.start_flat()
	check(data.blank and data.heights.count(0.0) == data.heights.size(), "Start flat clears the original terrain's own vertices")
	check(terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == arrays[Mesh.ARRAY_VERTEX].size(), "Blank canvas retains the original topology")
	check(not scene.get_node("Reference/mesh-8").visible, "Blank canvas removes the captured trees from rendering")
	scene._process(0.0)
	check(not scene.get_node("WaterfallSpray").visible and not scene._fireflies.visible, "Blank canvas has no source waterfall or floating habitat effects")
	var map: Image = scene._precipitation.ground_texture.get_image()
	check(map.get_pixel(64,64).g == 0.0 and map.get_pixel(64,64).a == -1000.0, "Blank ground map clears the original lake")
	var skirt: MeshInstance3D = scene.get_node("Reference/skirt")
	check(absf(skirt.mesh.get_aabb().end.y + skirt.position.y) < 0.0001, "Original earth rim follows the flat surface")
	await capture("native-flat", scene)
	data.begin_stroke()
	data.brush(Vector2(0,0),5,30,"raise",0)
	data.brush(Vector2(8,4),3,2,"lower",0)
	data.end_stroke()
	editor.refresh()
	check(scene._precipitation._materials[0].get_shader_parameter("top") > 24.0, "Rain and snow originate above the tallest allowed native hill")
	if scene._display_fog != null:
		check(scene._display_fog.material.get_shader_parameter("floor_height") < -1.4, "Display fog reaches the deepest native hollow")
	editor.undo()
	data.begin_stroke()
	data.brush(Vector2(-4,-3),4,3,"raise",0)
	data.brush(Vector2(4,2),3,0.8,"lower",0)
	data.end_stroke()
	editor.refresh()
	check(float(data.height_at(-4,-3)) > 2.0 and float(data.height_at(4,2)) < -0.5, "Flat native chunk supports a hill and a hollow")
	# Author content through event-time rays on the same camera and terrain.
	data.begin_stroke()
	editor.mode = "meadow"
	editor.radius = 5.0
	editor.dab(Vector2(-3,-2),2.0)
	data.end_stroke()
	editor.refresh()
	check(editor.content.get_node("Grass").multimesh.instance_count > 500, "Native meadow renders source grass blades")
	for entry: Array in [["tree",Vector2(-4,-3)],["rock",Vector2(0,1)],["flower",Vector2(1,3)]]:
		click(editor,entry[0],entry[1])
	check(data.objects.size() == 3, "Native clicks place a tree, a rock, and an individual flower")
	var canopy := canopies(editor)[0]
	check(canopy.multimesh.mesh == editor.content._meshes[canopy.get_meta("part")], "Authored tree uses the port's actual canopy mesh")
	var tree_y := canopy.multimesh.get_instance_transform(0).origin.y
	data.begin_stroke()
	data.brush(Vector2(-4,-3),2.0,0.5,"raise",0)
	data.end_stroke()
	editor.refresh()
	check(canopies(editor)[0].multimesh.get_instance_transform(0).origin.y > tree_y, "Authored tree follows native terrain edits")
	editor.undo()
	editor.pond_level = -0.15
	click(editor,"pond",Vector2(4,2))
	click(editor,"pond",Vector2(4.1,2))
	check(data.ponds.size() == 1 and not editor.content.pond_vertices.is_empty(), "Pond fills the native hollow without duplicate surfaces")
	for vertex: Vector3 in editor.content.pond_vertices:
		check(absf(vertex.y+0.15) < 0.0001, "Native pond has a flat waterline")
	check(editor.content._water.material_override.shader.resource_path.ends_with("lake_reference_water.gdshader"), "Authored pond uses the native lake shader")
	map = scene._precipitation.ground_texture.get_image()
	## The map spans the 48 m plate's ±MAP_HALF (dd35b546); (80,72) was this point on the 28 m one.
	var plate := preload("res://scripts/plate.gd")
	var texel := Vector2i(((Vector2(3.5,1.75)+Vector2.ONE*plate.MAP_HALF)/(plate.MAP_HALF*2.0)*map.get_width()).floor())
	check(absf(map.get_pixel(texel.x,texel.y).a+0.15) < 0.0001, "Native rain and fog map includes authored water")
	await capture("native-flat-sculpt", scene)
	# Persist an in-progress native rain transition, its accumulated wetness,
	# and an intentional camera pose before destroying the entire scene.
	scene._weather_selector.item_selected.emit(1)
	scene._paused = false
	scene._process(3.0)
	scene._paused = true
	scene.yaw += 0.2
	scene.distance = 39.0
	scene.target = Vector3(0,1.2,0)
	scene._process(0.0)
	check(scene._precipitation._instances[0].visible_instance_count > 0, "Native weather control renders rain")
	editor.save_path = save_file
	scene._celestial.cycling = true
	scene._celestial.rainbow_strength = 1.0
	scene._celestial.aurora_strength = 1.25
	scene._celestial.night_fill = 0.6
	scene._atmosphere.shroud = 0.3
	scene._atmosphere.set_rays(1.5)
	scene._process(0.0)
	var expected := data.to_document()
	var expected_scene := NativeGardenStore.capture(scene)
	var expected_water := editor.content.pond_vertices.duplicate()
	var expected_ground: PackedByteArray = scene._precipitation.ground_texture.get_image().get_data()
	check(editor.save_garden(), "Native garden saves to disk")
	var saved_bytes := FileAccess.get_file_as_bytes(save_file)
	await capture("native-garden-rain",scene)
	var corrupt := expected.duplicate(true)
	corrupt.heights[0] = "invalid"
	check(not data.load_document(corrupt) and data.to_document() == expected, "Invalid native terrain cannot partially replace the open garden")
	while data.blank:
		if not data.undo():
			break
	editor.refresh()
	## An island with an outline (1ed5dfe0) shows the imported mesh cut to it, and its
	## shore wall stands in the earth sides' place.
	check(not data.blank and terrain.mesh == data.play_mesh(mesh) and skirt.mesh == editor.skirt_mesh_for(data), "Undo restores imported terrain and original earth sides")
	check(scene._precipitation.ground_texture.get_image().get_data() == ground_bytes, "Undo restores original terrain/water texture byte for byte")
	check(scene.get_node("Reference/mesh-8").visible, "Undo restores source vegetation")
	editor.set_active(false)
	scene.queue_free()
	await process_frame
	var reopened: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(reopened)
	reopened.set_process(false)
	reopened._chunk_editor.set_process(false)
	reopened._chunk_editor.save_path = save_file
	var opened: bool = reopened._chunk_editor.open_garden()
	check(opened, "Fresh fidelity scene opens the native garden: "+reopened._chunk_editor.status)
	if not opened:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_file))
		print("STORE VALID ",NativeGardenStore.valid(reopened,document.scene_state)," MODEL VALID ",reopened._chunk_editor.data.load_document(document)," TEMPLATE ",document.template == reopened._chunk_editor.data._template_id())
		reopened.queue_free()
		await process_frame
		quit(1)
		return
	check(reopened._chunk_editor.data.to_document() == expected, "Reopened native world matches every saved value exactly")
	var reopened_state := NativeGardenStore.capture(reopened)
	check(reopened_state == expected_scene, "Reopened camera and native atmosphere state match exactly")
	for group: String in expected_scene:
		if expected_scene[group] != reopened_state[group]:
			print("STATE DIFFERENCE ",group," expected=",expected_scene[group]," actual=",reopened_state[group])
	for setting: Dictionary in reopened._saved_setting_controls:
		var value: Variant = setting.object.get(setting.property)
		if setting.control is BaseButton:
			check(setting.control.button_pressed == (not bool(value) if setting.negate else bool(value)), "Reopened checkbox matches saved "+setting.property)
		elif setting.control is Range:
			check(absf(setting.control.value-float(value)) <= maxf(setting.control.step,0.00001), "Reopened slider matches saved "+setting.property)
	check(reopened._chunk_editor.content.pond_vertices == expected_water, "Reopened native pond has the exact same shoreline")
	check(reopened._precipitation.ground_texture.get_image().get_data() == expected_ground, "Reopened weather map matches byte for byte")
	check(canopies(reopened._chunk_editor).reduce(func(total: int, batch: MultiMeshInstance3D) -> int: return total+batch.multimesh.instance_count,0) == 1, "Reopened native garden reconstructs its tree")
	check(reopened._precipitation._instances[0].visible_instance_count > 0, "Reopened native weather still renders rain")
	check(reopened._chunk_editor.save_garden() and FileAccess.get_file_as_bytes(save_file) == saved_bytes, "Reopening and saving produces the same file bytes")
	await capture("native-garden-reopened",reopened)
	reopened.queue_free()
	await process_frame
	DirAccess.remove_absolute(save_file)
	print("Native chunk editor: ", failures, " failures")
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func capture(label: String, scene: Node3D) -> void:
	if capture_directory.is_empty():
		return
	scene._ui.visible = false
	if scene._chunk_editor._material != null:
		scene._chunk_editor._material.set_shader_parameter("brush_visible",false)
	for i in range(3):
		await process_frame
	RenderingServer.force_draw(false)
	check(root.get_texture().get_image().save_png(capture_directory.path_join(label+".png")) == OK, "Capture saves")

func click(editor: NativeChunkEditor, tool: String, point: Vector2) -> void:
	editor.mode = tool
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = editor.scene.camera.unproject_position(Vector3(point.x,editor.data.ground_height(point),point.y))
	## place_at is the left press's own placement (the press is the hand's under
	## modeless controls, 7a1d6669).
	editor.place_at(event.position)
	editor.finish_stroke()

## A tree's canopy batches: the spruce variants' (a2eec160), or --classic-trees' one.
func canopies(editor: NativeChunkEditor) -> Array[MultiMeshInstance3D]:
	var found: Array[MultiMeshInstance3D] = []
	for batch: MultiMeshInstance3D in editor.content._batches:
		var part: String = batch.get_meta("part")
		if part == "canopy" or (part.begins_with("tree:") and part.ends_with("-canopies")): found.append(batch)
	if found.is_empty():
		check(false, "The tree has a canopy batch")
		var none := MultiMeshInstance3D.new()
		none.multimesh = MultiMesh.new()
		found.append(none)
	return found
