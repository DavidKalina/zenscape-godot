extends SceneTree
## Writes the pilot's synthesized footsteps (scripts/wanderer_steps.gd) out as
## WAVs, each surface's takes and skids, for measuring them off line (peak,
## RMS, spectral centroid) or listening:
##   godot --headless --path . -s res://tools/dump_wanderer_steps.gd -- --out=/tmp/steps
const Steps = preload("res://scripts/wanderer_steps.gd")

func _initialize() -> void:
	var out := "/tmp/wanderer_steps"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	for surface: String in Steps.SURFACES:
		var takes: Array = Steps.takes_for(surface)
		for i in range(takes.size()): takes[i].save_to_wav("%s/step_%s_%d.wav" % [out,surface,i])
		var slides: Array = Steps.slides_for(surface)
		for i in range(slides.size()): slides[i].save_to_wav("%s/slide_%s_%d.wav" % [out,surface,i])
	print("wrote steps to ",out)
	quit(0)
