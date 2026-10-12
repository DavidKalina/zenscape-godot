extends SceneTree
## A brush drag refreshes incrementally: the terrain arrays, instance batches and
## surface maps are patched where the stroke landed instead of being rebuilt.
## Every check here compares that result byte for byte against a rebuild from the
## same records, so any cache that drifts by a single float fails.
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(label: String, condition: bool) -> void:
	if not condition:
		failures += 1
	print("%s: %s" % [label, "ok" if condition else "FAIL"])

## Everything a refresh is responsible for producing.
func capture(scene: Node, editor: Node) -> PackedByteArray:
	var state: Array = []
	state.append(editor.terrain.mesh.surface_get_arrays(0))
	state.append(editor._skirt.mesh.surface_get_arrays(0))
	var batches: Array = []
	for batch in editor.content._batches:
		var instances: Array = [batch.get_meta("part"), batch.multimesh.instance_count]
		for i in range(batch.multimesh.instance_count):
			instances.append(batch.multimesh.get_instance_transform(i))
			instances.append(batch.multimesh.get_instance_color(i))
		batches.append(instances)
	batches.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	state.append(batches)
	state.append(editor.content.pond_vertices)
	state.append(editor.content._water.mesh.surface_get_arrays(0) if editor.content._water.mesh != null else [])
	var streams: Array = []
	for node in editor.content._stream_nodes:
		streams.append(node.mesh.surface_get_arrays(0))
	state.append(streams)
	var falls: Array = []
	for node in editor.content._landscape_falls:
		falls.append([node.transform, node.mesh.surface_get_arrays(0)])
	state.append(falls)
	state.append(editor.content._landscape_mists.size())
	state.append(scene._precipitation.ground_texture.get_image().get_data())
	state.append(scene._precipitation.stream_texture.get_image().get_data())
	var landmarks: Array = []
	for node in editor.landmarks.get_children():
		landmarks.append(node.transform)
	state.append(landmarks)
	state.append(editor.falls.get_child_count())
	return var_to_bytes(state)

## Drive a stroke the way `_process` does, refreshing after every dab.
func stroke(editor: Node, from: Vector2, to: Vector2, dabs: int, amount := 0.06) -> void:
	editor.data.begin_stroke()
	for i in range(1, dabs+1):
		editor.dab(from.lerp(to, float(i)/dabs), amount)
		editor.refresh()
	editor.data.end_stroke()

func compare(scene: Node, editor: Node, label: String) -> void:
	var incremental := capture(scene, editor)
	editor.force_refresh()
	check(label, incremental == capture(scene, editor))

func run() -> void:
	var scene: Node = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor: Node = scene._chunk_editor
	editor.content.set_process(false)
	editor.save_path = "res://tests/fixtures/fall-world-proof.json"
	check("populated demo world opens", editor.open_garden())
	check("world is the populated one", editor.data.objects.size() > 3000 and editor.data.landscape_waterfall)
	editor.force_refresh()
	var original := capture(scene, editor)

	editor.mode = "raise"
	editor.radius = 2.2
	stroke(editor, Vector2(-9,-9), Vector2(-6,-7), 8)
	compare(scene, editor, "raise stroke clear of the water matches a full rebuild")

	# Straight through the pond, whose banks and bed are shaded from the shoreline
	# field, and then along the stream that feeds it.
	editor.mode = "lower"
	stroke(editor, Vector2(4.2,-4.5), Vector2(6.5,-3.5), 8)
	compare(scene, editor, "lower stroke through the pond matches a full rebuild")

	editor.mode = "raise"
	stroke(editor, Vector2(6.3,3.8), Vector2(7.8,-0.5), 8)
	compare(scene, editor, "raise stroke along the stream matches a full rebuild")

	# On the landscape waterfall's course but clear of every wet cell, so only the
	# recorded reads of the fall's trace can notice the terrain moved.
	editor.mode = "lower"
	editor.radius = 2.0
	stroke(editor, Vector2(-0.9,-1.6), Vector2(-0.3,-0.9), 5, 0.4)
	compare(scene, editor, "stroke under the waterfall's course matches a full rebuild")

	editor.mode = "smooth"
	editor.radius = 4.0
	stroke(editor, Vector2(-2,-2), Vector2(1,2), 6)
	compare(scene, editor, "smooth stroke matches a full rebuild")

	editor.mode = "grass"
	editor.grass_amount = 0.8
	stroke(editor, Vector2(-5,5), Vector2(-3,7), 5)
	compare(scene, editor, "ground cover stroke matches a full rebuild")

	editor.mode = "meadow"
	stroke(editor, Vector2(6,-6), Vector2(8,-4), 5)
	compare(scene, editor, "meadow stroke matches a full rebuild")

	editor.mode = "erase"
	stroke(editor, Vector2(-9,-9), Vector2(-7,-8), 4)
	compare(scene, editor, "erase stroke matches a full rebuild")

	var strokes := 8
	for i in range(strokes):
		editor.undo()
	check("undo restores the opened world exactly", capture(scene, editor) == original)
	editor.force_refresh()
	check("undo result is what a full rebuild produces", capture(scene, editor) == original)
	for i in range(strokes):
		editor.redo()
	var redone := capture(scene, editor)
	editor.force_refresh()
	check("redo result is what a full rebuild produces", redone == capture(scene, editor))

	# A prop commit must not regenerate unchanged water and repaint its maps.
	var water_revision: int = editor.content.revision
	var pond_mesh: Mesh = editor.content._water.mesh
	editor.data.begin_stroke()
	var prop: int = editor.data.place("rock",Vector2(-8,-8),0.0,1.0)
	editor.data.end_stroke()
	check("regression prop is placed",prop > 0)
	editor.refresh()
	check("prop placement preserves water resources",editor.content.revision == water_revision and editor.content._water.mesh == pond_mesh)
	compare(scene,editor,"prop placement matches a full rebuild")
	water_revision = editor.content.revision
	editor.select_object(prop)
	editor.begin_selection_edit()
	editor.update_selected({"x":-7.5})
	editor.end_selection_edit()
	check("drag commit preserves water revision",editor.content.revision == water_revision)
	compare(scene,editor,"drag commit matches a full rebuild")
	editor.undo()
	compare(scene,editor,"undo prop move matches a full rebuild")
	editor.delete_selected()
	compare(scene,editor,"prop removal matches a full rebuild")

	# A content revision can change water even with unchanged terrain heights.
	# Both the departed footprint and destination must be repainted exactly.
	for stream in editor.data.streams:
		for point in stream.pts: point.x *= 0.94
	editor.refresh()
	compare(scene,editor,"shifted stream footprints match a full rebuild")
	editor.data.streams.clear()
	editor.refresh()
	compare(scene,editor,"removed streams clear their previous pixels exactly")
	editor.data.ponds.clear()
	editor.refresh()
	compare(scene,editor,"removed ponds clear their previous pixels exactly")

	print("Native incremental refresh: %d failures" % failures)
	scene.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
