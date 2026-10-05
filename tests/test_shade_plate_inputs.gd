extends SceneTree
## The face shader takes the plate's reach and its grids' sizes as inputs and
## shades the 28 m plate exactly as it did when they were literals: the native
## kernel and the GDScript mirror agree byte for byte on a plate with a pond,
## streams and a fall (its shore, bank and meadow-cell lookups all in play),
## and a caller that sends none of the new keys (an older one) still gets it.
## Prints each arrays' hash so a run before and after a change can be compared.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func digest(arrays: Array) -> String:
	var keys := [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV2]
	var bytes := PackedByteArray()
	for key in keys: bytes.append_array(var_to_bytes(arrays[key]))
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var editor = scene._chunk_editor
	var data: NativeTerrainData = editor.data
	editor.start_flat()
	editor.select_tool("range")
	editor.form_range()
	editor.cover_grass()
	var plain := var_to_bytes(data.build_mesh(true).surface_get_arrays(0)[Mesh.ARRAY_COLOR])
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/terrain-source.json"))
	data.begin_stroke()
	check(data.add_pond(Vector2(source.pool.x,source.pool.z),source.pool.waterY),"The pond is accepted")
	data.end_stroke()
	scene._build_palette.action_for("FillLandscapeStreams").pressed.emit()
	data.paint_tint(Vector2(-3,2),4.0,Color(0.7,0.1,0.3),0.6)
	var kernel = preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	data.native_mesh_enabled = false
	var mirror := data.build_mesh(true).surface_get_arrays(0)
	check(var_to_bytes(mirror[Mesh.ARRAY_COLOR]) != plain,"The water and the tint change the colours")
	check(not data._shore_field.is_empty(),"The shore grids are in play")
	print("SHADE_MIRROR ",digest(mirror))
	if kernel == null:
		print("SHADE_NATIVE none (no kernel built)")
	else:
		data.native_mesh_enabled = true
		var native := data.build_mesh(true).surface_get_arrays(0)
		check(digest(native) == digest(mirror),"Native shading equals the mirror byte for byte")
		print("SHADE_NATIVE ",digest(native))
		# An older caller sends none of the plate keys.
		var inputs: Dictionary = preload("res://scripts/native_terrain_kernels.gd").shade_inputs(data,false,data._recipe != null)
		for key in ["plate_half","water_cells","meadow_cells","meadow_step"]: check(inputs.has(key),"The caller sends "+key)
		var arrays: Array = data._arrays.duplicate(true)
		var faces := PackedInt32Array()
		for i in range(0,arrays[Mesh.ARRAY_VERTEX].size(),3): faces.append(i)
		var water: Dictionary = data._shore_field
		var last: int = arrays[Mesh.ARRAY_VERTEX].size()
		var full: Dictionary = kernel.shade(inputs,arrays,faces,water,0,last)
		var older := inputs.duplicate()
		for key in ["plate_half","water_cells","meadow_cells","meadow_step"]: older.erase(key)
		var bare: Dictionary = kernel.shade(older,arrays,faces,water,0,last)
		# The library's own defaults are the 28 m plate's, as the literals were.
		var legacy := inputs.duplicate()
		legacy.merge({"plate_half":14.0,"water_cells":51,"meadow_cells":56,"meadow_step":0.5},true)
		var before: Dictionary = kernel.shade(legacy,arrays,faces,water,0,last)
		check(var_to_bytes(before) == var_to_bytes(bare),"Keys absent shade the same as keys sent at the 28 m plate")
		# The keys are read: a different plate changes the shading (a library
		# built before they existed ignores them, and reports no).
		var shifted := inputs.duplicate()
		shifted.plate_half = 13.0
		var moved: Dictionary = kernel.shade(shifted,arrays,faces,water,0,last)
		var reads := var_to_bytes(moved) != var_to_bytes(full)
		print("SHADE_KEYS_READ ",reads)
		if "--new-library" in OS.get_cmdline_user_args(): check(reads,"The library reads the plate keys")
	print("Shade plate inputs: ",failures," failures")
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
