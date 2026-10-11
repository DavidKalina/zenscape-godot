extends SceneTree
## The Opal cloud sea's painted distant peaks (shaders/
## sky_cloud_sea_opal.gdshaderinc `sea_peaks`) are off while the sky world's
## ring of real ranges stands (scripts/sky_world.gd, kept but unwired: only
## with --peak-ring), and on by default: the sky's own shader keeps them,
## and the look pass (scripts/look_pass.gd `apply_sea_peaks`) sets the sky
## to 0 with the ring and 1 without. The --peak-ring half runs this script
## again as a child with the flag. Headless: the sky material's parameters
## only, nothing drawn.
const LookPass = preload("res://scripts/look_pass.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
var failures := 0

func _initialize() -> void:
	if "--child" in OS.get_cmdline_user_args():
		print("SEA_PEAKS %s" % str(_set_on_sky()))
		quit(0)
		return
	var shader: Shader = load("res://shaders/reference_sky.gdshader")
	var declared := false
	for u: Dictionary in shader.get_shader_uniform_list():
		if u.name == "sea_peaks": declared = true
	check(declared and "uniform float sea_peaks = 1.0;" in FileAccess.get_file_as_string("res://shaders/sky_cloud_sea_opal.gdshaderinc"),"The sky's shader paints the sea's peaks by default (sea_peaks 1)")
	check(not SkyWorld.ring_on() and _set_on_sky() == 1.0,"By default (no ring) the look pass sets sea_peaks to 1")
	var out := []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/test_sky_sea_peaks.gd","--","--child","--peak-ring"],out,true)
	var seen := -1.0
	for line: String in "\n".join(out).split("\n"):
		if line.begins_with("SEA_PEAKS "): seen = float(line.trim_prefix("SEA_PEAKS "))
	check(code == 0 and seen == 0.0,"With --peak-ring, it sets sea_peaks to 0 (%s)" % seen)
	print("PASS: sky sea peaks" if failures == 0 else "FAIL: sky sea peaks")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## The value the look pass leaves on a sky material.
func _set_on_sky() -> float:
	var sky := ShaderMaterial.new()
	sky.shader = load("res://shaders/reference_sky.gdshader")
	LookPass.apply_sea_peaks(sky)
	return float(sky.get_shader_parameter("sea_peaks"))
