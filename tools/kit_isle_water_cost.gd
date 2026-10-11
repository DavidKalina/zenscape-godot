extends SceneTree
## What a kit isle's water costs to draw (docs/scenic/kit-isle-water.md):
## opens the isle, holds the camera on a view as a capture does (studies/
## kit_isle.gd `_take_capture`), then draws ROUNDS times FRAMES frames with
## its water shown and FRAMES hidden, and prints the wall-clock time a frame
## (vsync off; the viewport's measured GPU time reads 0 on this Mac's Metal),
## the viewport's measured CPU render time, and the draw calls and
## primitives of each. The water is every mesh drawn in a water shader (as tools/
## kit_isle_water_probe.gd finds them). Rendered (needs a window):
##   Godot --windowed --resolution 1440x900 --path . -s res://tools/kit_isle_water_cost.gd -- --no-title --isle=cloister_tarn --at=x,y,z --look=x,y,z [--old-water]
const WATER_SHADERS := ["reference_water","islet_pond","aqueduct_channel"]
const FRAMES := 120
const ROUNDS := 3

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(400.0).timeout.connect(func() -> void: push_error("water cost timed out"); quit(2))
	var isle := "cloister_tarn"
	var at := Vector3.INF
	var look := Vector3.INF
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--isle="): isle = arg.get_slice("=",1)
		elif arg.begins_with("--at="): at = _vec(arg.get_slice("=",1))
		elif arg.begins_with("--look="): look = _vec(arg.get_slice("=",1))
	var study: Node3D = load("res://studies/%s_isle.tscn" % isle).instantiate()
	root.size = Vector2i(1440,900)
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	for i in range(120): await process_frame
	var water: Array[Node3D] = []
	for node in _all(study):
		if node is MeshInstance3D and (node as MeshInstance3D).material_override is ShaderMaterial:
			var shader: Shader = ((node as MeshInstance3D).material_override as ShaderMaterial).shader
			if shader == null: continue
			for s in WATER_SHADERS:
				if shader.resource_path.contains(s):
					water.append(node)
					break
	# Held as a capture holds it: the scene's own step off, its look stepped.
	study.set_process(false)
	if at != Vector3.INF: study.camera.look_at_from_position(at,look if look != Vector3.INF else study.capture_look())
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var sums := {true:Vector4.ZERO,false:Vector4.ZERO}
	for round_index in range(ROUNDS):
		for shown: bool in [true,false]:
			for node in water: node.visible = shown
			for i in range(30): await _step(study)
			var sum := Vector4.ZERO
			for i in range(FRAMES):
				var began := Time.get_ticks_usec()
				await _step(study)
				sum += Vector4((Time.get_ticks_usec()-began)/1000.0,RenderingServer.viewport_get_measured_render_time_cpu(viewport),
					RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
			sums[shown] += sum/FRAMES
	var on: Vector4 = sums[true]/ROUNDS
	var off: Vector4 = sums[false]/ROUNDS
	print("water cost %s: %d water meshes; with water %.2f ms a frame (render CPU %.2f ms), %d draw calls, %d primitives; without %.2f ms (%.2f ms), %d draw calls, %d primitives; the water %+.2f ms a frame, %+d draw calls, %+d primitives" % [isle,water.size(),on.x,on.y,on.z,on.w,off.x,off.y,off.z,off.w,on.x-off.x,on.z-off.z,on.w-off.w])
	quit(0)

func _step(study: Node3D) -> void:
	study._advance_look(1.0/60.0)
	await RenderingServer.frame_post_draw

func _vec(text: String) -> Vector3:
	var p := text.split(",")
	return Vector3(float(p[0]),float(p[1]),float(p[2]))

func _all(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children(): out.append_array(_all(child))
	return out
