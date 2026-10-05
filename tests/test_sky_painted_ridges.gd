extends SceneTree
## The sky dome's painted horizon ridges (shaders/sky_ridges.gdshaderinc,
## reference_sky.gdshader `horizon_ridges`) are off while the sky world's
## ring of real ranges stands (scripts/sky_world.gd `painted_ridges`), in
## the build view and the glide alike (the one look pass sets the sky for
## both: scripts/look_pass.gd `_update_ridges`), and on as before with
## --no-ring. The sky objects (stars, planet) copy the sky's value, so with
## it 0 they hide behind no painted ridge. The --no-ring half runs this
## script again as a child with the flag. Headless: values only.
const LookPass = preload("res://scripts/look_pass.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
var failures := 0

func _initialize() -> void:
	if "--child" in OS.get_cmdline_user_args():
		print("RIDGES %s" % str(LookPass.ridge_strength(0.85)))
		quit(0)
		return
	check(SkyWorld.ring_on() and SkyWorld.painted_ridges() == 0.0,"With the ring on, the painted ridges are off")
	check(LookPass.ridge_strength(0.85) == 0.0,"The look pass sets horizon_ridges to 0 with the ring")
	check("ridge_strength(ridges * on)" in FileAccess.get_file_as_string("res://scripts/look_pass.gd"),"The look pass's ridges go through ridge_strength")
	var objects := FileAccess.get_file_as_string("res://shaders/sky_objects.gdshaderinc")
	check("if (horizon_ridges <= 0.0" in objects,"With no painted ridges the sky objects are open to the horizon")
	var out := []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/test_sky_painted_ridges.gd","--","--child","--no-ring"],out,true)
	var seen := -1.0
	for line: String in "\n".join(out).split("\n"):
		if line.begins_with("RIDGES "): seen = float(line.trim_prefix("RIDGES "))
	check(code == 0 and is_equal_approx(seen,0.85),"With --no-ring, the painted ridges are on as the look has them (%s)" % seen)
	print("PASS: sky painted ridges" if failures == 0 else "FAIL: sky painted ridges")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)
