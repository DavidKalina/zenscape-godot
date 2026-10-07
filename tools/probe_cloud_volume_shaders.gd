extends SceneTree
## Compiles the unified cloud volume's compute shaders (shaders/
## cloud_volume_march.glsl, cloud_volume_resolve.glsl) and prints any error.
##   Godot --headless --path . -s res://tools/probe_cloud_volume_shaders.gd
func _initialize() -> void:
	var failed := false
	for path in ["res://shaders/cloud_volume_march.glsl","res://shaders/cloud_volume_resolve.glsl"]:
		var file: RDShaderFile = load(path)
		var spirv := file.get_spirv()
		failed = failed or not spirv.compile_error_compute.is_empty()
		print("%s: %s" % [path,"ok (%d bytes)" % spirv.bytecode_compute.size() if spirv.compile_error_compute.is_empty() else spirv.compile_error_compute])
	quit(1 if failed else 0)
