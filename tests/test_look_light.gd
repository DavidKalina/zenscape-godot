extends SceneTree
## The light and colour pass: the light shafts drawn by both of the look
## pass's grades (shaders/look_rays.gdshaderinc, through the display-fog blend
## and the standalone grade the woodland mist leaves on), their strength and
## off switch (scripts/look_pass.gd `rays`, --no-rays); the day's key over its
## fill (studies/celestial.gd key_gain, fill_gain); and the light's colour
## tempered where it is made: a cool but not blue sky fill, a near-neutral
## bounce, a sky whose teal turns blue. Headless: what it draws is not
## checked here, only that the shaders compile with the shafts and the
## colours come out as asked.
const LookPass = preload("res://scripts/look_pass.gd")
const Celestial = preload("res://studies/celestial.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for path: String in ["res://shaders/look_grade.gdshader","res://shaders/reference_air_blend.gdshader"]:
		var names: Array = (load(path) as Shader).get_shader_uniform_list().map(func(entry: Dictionary) -> String: return entry.name)
		check(names.has("rays_strength") and names.has("rays_sun") and names.has("rays_color") and names.has("surface_depth"), "%s draws the shafts from the depth copy" % path)
	check(LookPass.default_rays() == LookPass.RAYS and LookPass.RAYS > 0.22, "The shafts are on by default, stronger than before (%s)" % LookPass.default_rays())
	check(LookPass.RAYS_LIGHT > 0.0, "The shafts carry light")
	check(LookPass._arg_float("--no-such-flag=", 0.5) == 0.5, "Without the flag the default stands")
	check(Celestial.key_gain > 1.0 and Celestial.fill_gain < 1.0, "By day the sun leads its fill (key %s, fill %s)" % [Celestial.key_gain, Celestial.fill_gain])
	# The fill: the same brightness, its colour halved toward grey.
	var blue := Vector3(0.31, 0.47, 0.68)
	var fill := Celestial._temper_fill(blue)
	check(is_equal_approx(Celestial._luma(fill), Celestial._luma(blue)), "The fill keeps its brightness")
	check(fill.z / fill.x < blue.z / blue.x and fill.z > fill.x, "The fill stays cool but is no longer blue (%s)" % fill)
	# The bounce: a grass-green from below goes most of the way to a warm grey.
	var green := Vector3(0.068, 0.084, 0.051)
	var bounce := Celestial._temper_bounce(green)
	check(bounce.y / bounce.x < green.y / green.x and bounce.y / bounce.z < green.y / green.z, "The bounce loses its green (%s)" % bounce)
	# The sky: teal turns blue; blue, warm and grey are left alone.
	var teal := Celestial._temper_sky(Vector3(0.28, 0.37, 0.40))
	check(teal.y <= lerpf(teal.x, teal.z, Celestial.SKY_GREEN_CAP) + 1e-6, "A teal sky turns blue (%s)" % teal)
	check(Celestial._temper_sky(Vector3(0.1, 0.2, 0.5)) == Vector3(0.1, 0.2, 0.5), "A blue sky is left alone")
	check(Celestial._temper_sky(Vector3(0.6, 0.4, 0.2)) == Vector3(0.6, 0.4, 0.2), "A warm sky is left alone")
	print("PASS: look light" if failures == 0 else "FAIL: look light (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
