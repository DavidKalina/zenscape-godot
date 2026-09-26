extends RefCounted
## Prefer the native kernel when built; keep GDScript for unbuilt checkouts.
## Load on the main thread before handing the immutable kernel to workers.
static var _kernel: RefCounted
static var _attempted := false
static func get_kernel() -> RefCounted:
	if "--gdscript-kernels" in OS.get_cmdline_user_args():
		if "--native-kernels" in OS.get_cmdline_user_args():
			_requirement_failed("Choose either --native-kernels or --gdscript-kernels, not both")
		return null
	if _attempted: return _kernel
	_attempted = true
	var path := "res://native/terrain_kernels/zenscape_kernels.gdextension"
	if not ClassDB.class_exists("ZenScapeTerrainKernels") and FileAccess.file_exists(path):
		GDExtensionManager.load_extension(path)
	if ClassDB.class_exists("ZenScapeTerrainKernels"):
		_kernel = ClassDB.instantiate("ZenScapeTerrainKernels")
	elif "--native-kernels" in OS.get_cmdline_user_args():
		_requirement_failed("--native-kernels requires a built GDExtension; run tools/build_native_kernels.py")
	return _kernel

static func _requirement_failed(message: String) -> void:
	push_error(message)
	# Explicit native validation must never succeed with fallback measurements.
	# Engine.get_main_loop() can still be null during SceneTree._initialize().
	_exit_failed_validation.call_deferred()

static func _exit_failed_validation() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null: tree.quit(1)

static func shade(kernel: RefCounted, data: NativeTerrainData, arrays: Array, faces: PackedInt32Array, water: Dictionary, sculpted: bool, has_recipe: bool, first: int, last: int) -> Dictionary:
	var inputs := {}
	for key in ["heights","vertex_ids","grass","meadow","tint","_recipe_heights","_face_probe","_locate_face","_locate_u","_locate_v","_face_x","_face_z","_face_shimmer","_face_grass","_face_rock","_face_snow","_face_rim","_recipe_gradients","blank","_ground_tint"]:
		inputs[key] = data.get(key)
	var biome: Dictionary = preload("res://scripts/native_formation_shape.gd").BIOMES.get(data._recipe_settings.get("biome",""),{})
	inputs.snowline = preload("res://scripts/biome_blend.gd").snowline(data._recipe_settings,data._palette.snowline)
	inputs.rock_slope = biome.get("rock_slope",data._palette.rock_slope)
	inputs.sand = data._palette.sand
	inputs.gravel = data._palette.gravel
	inputs.source_colors = data._arrays[Mesh.ARRAY_COLOR]
	inputs.sculpted = sculpted
	inputs.has_recipe = has_recipe
	return kernel.shade(inputs,arrays,faces,water,first,last)
