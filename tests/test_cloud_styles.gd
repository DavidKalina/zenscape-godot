extends SceneTree
## The cloud sea's three styles (shaders/sky_cloud_sea.gdshaderinc): each
## style value selects its variant on the sky, the Mystic motes come only
## with Mystic, --cloud-style overrides the kept choice, the choice is kept
## in a settings file, and the Settings dialog offers it as "Clouds".
const LookPass = preload("res://scripts/look_pass.gd")
const KEPT := "user://test_cloud_styles.cfg"
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(KEPT))
	# Persistence, against a scratch file so the player's own choice is untouched.
	check(LookPass.load_cloud_style(KEPT) == "opal", "Opal until the player chooses")
	LookPass.save_cloud_style("storybook", KEPT)
	check(LookPass.load_cloud_style(KEPT) == "storybook", "The chosen style is kept")
	LookPass.save_cloud_style("mystic", KEPT)
	check(LookPass.load_cloud_style(KEPT) == "mystic", "A new choice replaces the kept one")
	LookPass.save_cloud_style("lava", KEPT)
	check(LookPass.load_cloud_style(KEPT) == "opal", "An unknown kept style falls back to Opal")
	check(LookPass.cloud_style_from_args(PackedStringArray(["--cloud-style=storybook"]), "opal") == "storybook", "--cloud-style overrides the kept style")
	check(LookPass.cloud_style_from_args(PackedStringArray(["--cloud-style=MYSTIC"]), "opal") == "mystic", "--cloud-style ignores case")
	check(LookPass.cloud_style_from_args(PackedStringArray(["--no-title"]), "storybook") == "storybook", "Without the flag the kept style holds")

	var scene = load("res://studies/diorama.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var look = scene.look_pass
	look.settings_path = KEPT
	var sky: ShaderMaterial = scene._environment.sky.sky_material
	var names: Array = sky.shader.get_shader_uniform_list().map(func(entry: Dictionary) -> String: return entry.name)
	check(names.has("cloud_sea_style") and names.has("cloud_sea"), "The sky shader compiles and takes cloud_sea_style")
	var motes: Node = scene.get_node_or_null("SkyMotes")
	check(motes != null, "The look pass adds the Mystic motes")
	look.cloud_sea = 1.0
	for index in LookPass.CLOUD_STYLES.size():
		var style: String = LookPass.CLOUD_STYLES[index]
		look.set_cloud_style(style, false)
		check(int(sky.get_shader_parameter("cloud_sea_style")) == index, "%s selects sky variant %d" % [style, index])
		if motes != null: check(motes.visible == (style == "mystic"), "The motes show with Mystic only (%s)" % style)
	look.cloud_sea = 0.0
	look._update_cloud_sea(1.0)
	if motes != null: check(not motes.visible, "With the sea off (--no-cloud-sea) the motes hide too")
	check(float(sky.get_shader_parameter("cloud_sea")) == 0.0, "With the sea off the sky paints none")
	look.cloud_sea = 1.0

	# The Settings dialog's Clouds choice sets and keeps the style.
	var clouds: OptionButton = scene._settings.find_child("CloudStyle", true, false)
	check(clouds != null and clouds.item_count == 3 and clouds.get_item_text(0) == "Opal", "Settings offers Clouds: Opal, Storybook, Mystic")
	if clouds != null:
		clouds.select(1)
		clouds.item_selected.emit(1)
		check(look.cloud_style == "storybook" and int(sky.get_shader_parameter("cloud_sea_style")) == 1, "Choosing Storybook in Settings paints it")
		check(LookPass.load_cloud_style(KEPT) == "storybook", "Choosing in Settings keeps the choice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(KEPT))
	scene.queue_free()
	# The mixer lets go of the menu's cloth sounds a moment later.
	await create_timer(0.5).timeout
	print("PASS: cloud styles" if failures == 0 else "FAIL: cloud styles (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
