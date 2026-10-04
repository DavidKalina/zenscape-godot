extends SceneTree
## The night sky's four styles (shaders/night_sky.gdshaderinc): each style
## publishes its index on the global zs_night_style, --night-style overrides
## the kept choice, the choice is kept in a settings file beside the clouds',
## the sky shaders still take their parameters, and the Settings dialog
## offers it as "Night sky".
const LookPass = preload("res://scripts/look_pass.gd")
const KEPT := "user://test_night_styles.cfg"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(KEPT))
	check(LookPass.load_night_style(KEPT) == "nocturne", "Nocturne until the player chooses")
	LookPass.save_night_style("storybook", KEPT)
	check(LookPass.load_night_style(KEPT) == "storybook", "The chosen night style is kept")
	LookPass.save_cloud_style("mystic", KEPT)
	check(LookPass.load_night_style(KEPT) == "storybook" and LookPass.load_cloud_style(KEPT) == "mystic", "Night and clouds are kept apart")
	LookPass.save_night_style("lava", KEPT)
	check(LookPass.load_night_style(KEPT) == "nocturne", "An unknown kept style falls back to Nocturne")
	check(LookPass.night_style_from_args(PackedStringArray(["--night-style=OPAL"]), "nocturne") == "opal", "--night-style overrides the kept style, any case")
	check(LookPass.night_style_from_args(PackedStringArray(["--cloud-style=opal"]), "mystic") == "mystic", "Without the flag the kept style holds")

	var scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var look = scene.look_pass
	look.settings_path = KEPT
	for index in LookPass.NIGHT_STYLES.size():
		look.set_night_style(LookPass.NIGHT_STYLES[index], false)
		check(published() in [null, index], "%s publishes zs_night_style %d" % [LookPass.NIGHT_STYLES[index], index])
	var sky: ShaderMaterial = scene._environment.sky.sky_material
	var names: Array = sky.shader.get_shader_uniform_list().map(func(entry: Dictionary) -> String: return entry.name)
	check(names.has("real_stars") and names.has("cloud_sea_style"), "The sky shader compiles with the night styles")
	for path: String in ["res://shaders/sky_planet_body.gdshader", "res://shaders/sky_planet_rings.gdshader", "res://shaders/sky_planet_glow.gdshader", "res://shaders/sky_stars.gdshader"]:
		var uniforms: Array = (load(path) as Shader).get_shader_uniform_list().map(func(entry: Dictionary) -> String: return entry.name)
		check(uniforms.has("sky_distance"), "%s compiles with the night styles" % path.get_file())

	var night: OptionButton = scene._settings.find_child("NightStyle", true, false)
	check(night != null and night.item_count == 4 and night.get_item_text(0) == "Nocturne", "Settings offers Night sky: Nocturne, Opal, Storybook, Mystic")
	if night != null:
		night.select(2)
		night.item_selected.emit(2)
		check(look.night_style == "storybook" and published() in [null, 2], "Choosing Storybook in Settings paints it")
		check(LookPass.load_night_style(KEPT) == "storybook", "Choosing in Settings keeps the choice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(KEPT))
	scene.queue_free()
	await process_frame
	print("PASS: night styles" if failures == 0 else "FAIL: night styles (%d)" % failures)
	quit(1 if failures else 0)

## The published global; null under the dummy renderer, which keeps none.
func published() -> Variant:
	return RenderingServer.global_shader_parameter_get("zs_night_style")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
