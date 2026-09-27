extends SceneTree
## Parses every shader under res://shaders headless (the dummy renderer still
## runs the shader parser) so a syntax or identifier error shows up without a
## GPU. Run: godot --headless --path . --script tools/check_shaders.gd
## Errors print as SHADER ERROR lines; grep the output for them.

func _init() -> void:
	var count := 0
	for file in DirAccess.get_files_at("res://shaders"):
		if not file.ends_with(".gdshader"): continue
		var shader: Shader = load("res://shaders/"+file)
		if shader == null:
			print("could not load ", file)
			continue
		# Touching the uniform list makes the dummy storage parse the code.
		shader.get_shader_uniform_list()
		count += 1
	print("check_shaders: parsed %d shaders" % count)
	quit()
