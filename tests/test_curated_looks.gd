extends SceneTree
const Presets = preload("res://scripts/scene_look_presets.gd")
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("Curated preset test timed out"); quit(2))
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene._paused = true
	scene.edit_scene_look()
	var panel = scene._look_editor
	check(panel.tabs.get_tab_title(0) == "Looks" and panel.tabs.current_tab == 0,"Visual looks are the first thing the editor presents")
	var geometry: Dictionary = scene._chunk_editor.data.to_document()
	var camera: Vector3 = scene.camera.position
	var appearances := []
	for id in Presets.PRESETS:
		check(panel.preset_buttons[id].get_child(0).texture != null,"Card has a real rendered preview: "+id)
		check(preload("res://scripts/scene_look.gd").valid(Presets.look_document(id)),"Preset has a valid persistable look: "+id)
		Presets.apply(scene,"first_snow")
		scene._celestial.look.set_value("exposure",0.5)
		scene._celestial.look.set_value("sun_energy",0)
		scene._atmosphere.shroud = 1.0
		var before: Dictionary = panel.capture_edit()
		panel.preset_buttons[id].pressed.emit()
		check(panel.preset_buttons[id].button_pressed,"Applied card reads as selected: "+id)
		check(Presets.matches(scene,id),"Card applies a complete preset over previous overrides: "+id)
		check(is_equal_approx(scene._precipitation.surface_weather.ice,Presets.PRESETS[id].get("ice",0.0)),"Preset resets inherited ice: "+id)
		check(is_equal_approx(scene._precipitation.surface_weather.snow_cover,Presets.PRESETS[id].get("snow",0.0)),"Preset resets inherited snow: "+id)
		var after: Dictionary = panel.capture_edit()
		panel.undo_edit()
		check(panel.capture_edit() == before,"One undo restores the complete previous look: "+id)
		panel.redo_edit()
		check(panel.capture_edit() == after,"Redo restores the complete preset: "+id)
		var saved: Dictionary = NativeGardenStore.capture(scene)
		Presets.apply(scene,"alpine_morning")
		NativeGardenStore.restore(scene,JSON.parse_string(JSON.stringify(saved)))
		check(Presets.matches(scene,id),"Saved preset remains selected after restore: "+id)
		panel.show()
		check(scene._chunk_editor.data.to_document() == geometry and scene.camera.position == camera,"Choosing looks leaves terrain and framing intact")
		check(after.look not in appearances,"Each preset has its own appearance")
		appearances.append(after.look)
	# User tweaks must not continue to claim an exact preset match.
	Presets.apply(scene,"golden_meadow")
	scene._celestial.look.set_color("grass",Color.RED)
	check(not Presets.matches(scene,"golden_meadow"),"Editing colors clears the preset match")
	root.content_scale_factor = 2.0
	root.size = Vector2i(960,640)
	panel.show()
	await process_frame
	panel._layout()
	await process_frame
	check(panel.tabs.size.y>180 and root.get_visible_rect().encloses(panel.get_global_rect()),"Gallery fits a small Retina window")
	check(panel._preset_grid.columns == 2,"Gallery offers visual comparison in two columns")
	var scroll: ScrollContainer = panel.tabs.get_child(0)
	scroll.scroll_vertical = 10000
	await process_frame
	check(scroll.get_global_rect().intersects(panel.preset_buttons.after_the_rain.get_global_rect()),"The last look is reachable by scrolling")
	scene.free()
	print("CURATED LOOKS: failures=",failures)
	quit(1 if failures else 0)
