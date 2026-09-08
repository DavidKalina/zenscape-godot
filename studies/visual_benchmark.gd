extends Node3D
## Isolated rendering study. F8 compares the same composition with source rendering.
var scene: Node3D
var ready_for_capture := false
var enhanced := true
var mist: FogVolume
var water_node: MeshInstance3D
var caption: Label
var planar: Node3D

func _ready() -> void:
	process_priority = 100
	get_window().title = "ZenScape · Luminous woodland"
	scene = load("res://studies/fidelity.tscn").instantiate()
	add_child(scene)
	# Preserve the historical A/B comparison; production owns its own live effects.
	scene._planar_water.enabled = false
	scene._redwood_mist.enabled = false
	scene._chunk_editor.save_path = "user://visual-benchmark.json"
	scene._paused = true
	scene._auto_orbit = false
	scene._ui.hide()
	await scene._chunk_editor.form_landscape("terraced_pools", "woodland", false)
	preload("res://scripts/scene_look_presets.gd").apply(scene, "golden_meadow")
	var look = scene._celestial.look
	look.set_value("strength", 0.85)
	look.set_value("ambient_energy", 1.25)
	var colors = {"sky":"82b7cc", "horizon":"5f929b", "glow":"afc7b1", "sun":"ffe3a8", "ambient":"c9e3ee", "grass":"62a776", "foliage":"4b9168", "rock":"879a95"}
	for key in colors: look.set_color(key, Color(colors[key]))
	scene._celestial.update_rig()
	scene._atmosphere.set_fog(0.18)
	scene._atmosphere.set_haze(0.04)
	scene._atmosphere.summit_mist = 0.0
	scene.target = Vector3(1.0, 2.2, 3.5)
	scene.distance = 25.0
	scene.yaw = -0.45
	scene.polar = 1.12
	scene._update_camera()
	water_node = scene._chunk_editor.content._water
	mist = FogVolume.new()
	mist.size = Vector3(28, 20, 28)
	mist.position.y = 6.0
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/beauty_mist.gdshader")
	material.set_shader_parameter("ground_map", scene._precipitation.ground_texture)
	material.set_shader_parameter("stream_map", scene._precipitation.stream_texture)
	mist.material = material
	add_child(mist)
	var ui := CanvasLayer.new()
	add_child(ui)
	caption = Label.new()
	caption.position = Vector2(24, 20)
	caption.add_theme_font_size_override("font_size", 14)
	ui.add_child(caption)
	planar = preload("res://scripts/benchmark_planar_water.gd").new()
	add_child(planar)
	planar.setup(scene, water_node)
	# Prototype in the lowest pool; compare with C without changing other water.
	var lowest: Dictionary = planar.views[0]
	for view in planar.views:
		if view.level < lowest.level: lowest = view
	lowest.material.set_shader_parameter("caustics_strength",0.45)
	set_meta("caustics_material",lowest.material)
	ready_for_capture = true
	set_enhanced(not "--control" in OS.get_cmdline_user_args())
	scene._paused = false
	print("VISUAL BENCHMARK READY reflected pools=", planar.views.size(), " ponds=", scene._chunk_editor.data.ponds)

func set_enhanced(value: bool) -> void:
	enhanced = value
	planar.set_enabled(value)
	scene._atmosphere.get_node("ValleyFog").visible = not value
	mist.visible = value
	scene._display_fog.visible = not value
	scene._environment.ssr_enabled = false
	scene._environment.volumetric_fog_anisotropy = 0.55 if value else 0.45
	scene._environment.volumetric_fog_ambient_inject = 0.25 if value else 0.35
	for light in scene._lights: light.light_volumetric_fog_energy = 2.0 if value and light.shadow_enabled else 0.0
	caption.text = ("Luminous woodland" if value else "Original rendering") + "  ·  F8 compare  ·  drag to orbit  ·  G gust  ·  C caustics  ·  P pause"

func _process(_delta: float) -> void:
	if ready_for_capture:
		planar.update_views()
		# The source compositor disables native fog each frame; this study
		# owns the final environment choice after the source scene updates.
		scene._environment.volumetric_fog_enabled = enhanced

func _unhandled_key_input(event: InputEvent) -> void:
	if not ready_for_capture or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F8: set_enhanced(not enhanced)
	elif event.keycode == KEY_G: scene._atmosphere.send_gust(scene.target)
	elif event.keycode == KEY_C:
		var material: ShaderMaterial = get_meta("caustics_material")
		material.set_shader_parameter("caustics_strength",0.0 if float(material.get_shader_parameter("caustics_strength"))>0.0 else 0.45)
	elif event.keycode == KEY_P: scene._paused = not scene._paused
	elif event.keycode == KEY_ESCAPE: get_tree().quit()
	# This authored study exposes viewing controls, not the source editor's
	# keyboard actions: editing would invalidate the copied reflection geometry.
	get_viewport().set_input_as_handled()
