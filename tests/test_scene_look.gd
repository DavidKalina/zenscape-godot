extends SceneTree
const Look = preload("res://scripts/scene_look.gd")
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("Scene look test timed out"); quit(2))
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._paused = true
	scene._auto_orbit = false
	scene._chunk_editor.set_active(true)
	scene._build_palette._entries["command_scene_colors"].button.pressed.emit()
	check(scene._build_palette.sky_tile_for("scene_mood_Meadow morning") != null,"Moods are reachable from the build catalog")
	var panel = scene._look_editor
	var look = scene._celestial.look
	var baseline: Dictionary = look.document()
	for key in Look.SURFACES: check(look.ratio(key).is_equal_approx(Vector3.ONE),"Default multiplier preserves "+key)
	for title in Look.palette_names():
		look.choose(title)
		check(Look.valid(JSON.parse_string(JSON.stringify(look.document()))),"Palette validates after JSON: "+title)
	look.restore(baseline)
	# Real control signals, including one continuous color gesture and undo/redo.
	panel.palette_choice.select(3)
	panel.palette_choice.item_selected.emit(3)
	check(look.palette == "Desert" and look.ratio("grass").distance_to(Vector3.ONE)>0.2,"Preset changes landscape colors")
	panel.pickers.grass.pressed.emit()
	panel.pickers.grass.color_changed.emit(Color("c978b8"))
	panel.pickers.grass.popup_closed.emit()
	check(look.palette == "Custom" and look.colors.grass.is_equal_approx(Color("c978b8")),"Color picker writes custom palette")
	panel.undo_edit()
	check(look.palette == "Desert","Undo restores palette before picker gesture")
	panel.redo_edit()
	check(look.palette == "Custom","Redo restores custom color")
	var undo_key := InputEventKey.new()
	undo_key.keycode = KEY_Z
	undo_key.ctrl_pressed = true
	undo_key.pressed = true
	root.push_input(undo_key)
	check(look.palette == "Desert","Keyboard undo targets look history while its panel is open")
	panel.redo_edit()
	panel.sliders.exposure.control.value = 1.3
	check(is_equal_approx(scene._environment.tonemap_exposure,float(scene._source.exposure)/1.08*1.3),"Exposure reaches rendering environment")
	panel.sliders.wind_direction.control.value = 180
	check(is_equal_approx(scene._atmosphere._air_angle,PI),"Wind direction uses degrees and updates while paused")
	panel.sliders.cold.control.value = 0.8
	check(is_equal_approx(scene._celestial.cold,0.8),"Cold authoring updates paused scene")
	panel.sliders.autumn.control.value = 0.7
	check(is_equal_approx(scene._celestial.autumn,0.7),"Autumn authoring updates paused scene")
	panel.sliders.mist.control.value = 0.64
	check(is_equal_approx(scene._atmosphere.fog_amount,0.64),"Mist authoring updates paused scene")
	# Sky edits must reach night, not only the daytime endpoint.
	scene._celestial.set_phase(0.02)
	var old_sky: Vector3 = scene._celestial.state.zs_sky_up
	look.set_color("sky",Color("ab3958"))
	check(scene._celestial.state.zs_sky_up.distance_to(old_sky)>0.001,"Upper sky edit changes night sky")
	for title in Look.MOODS:
		scene.apply_scene_mood(title)
		check(is_equal_approx(scene._celestial.phase,Look.MOODS[title][1]),"Mood hour: "+title)
		check(scene._precipitation.PRESET_NAMES[scene._precipitation.preset_index] == Look.MOODS[title][2],"Mood weather: "+title)
	# The mood selector also participates in authoring undo.
	var before: Dictionary = panel.capture_edit()
	panel.mood_choice.select(2)
	panel.mood_choice.item_selected.emit(2)
	panel.undo_edit()
	check(panel.capture_edit() == before,"Mood undo restores palette and atmosphere together")
	look.set_color("water",Color("a68ebc"))
	var saved: Dictionary = NativeGardenStore.capture(scene)
	check(NativeGardenStore.valid(scene,saved),"Complete scene state validates")
	var path := "/private/tmp/zenscape-scene-look-test-"+str(Time.get_ticks_usec())+".json"
	scene._chunk_editor.save_path = path
	check(scene._chunk_editor.save_garden(),"Saves palette to a real world file")
	look.choose("Meadow")
	scene._chunk_editor.open_garden()
	check(look.document() == saved.look,"Reopen restores exact custom palette")
	check(panel._undo.is_empty(),"Opening a world clears look history")
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.look.colors.water = [1.0,-0.5,0.2]
	check(not NativeGardenStore.valid(scene,corrupt),"Invalid palette rejected before restore")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("look")
	check(NativeGardenStore.valid(scene,legacy),"Legacy scenes remain readable")
	NativeGardenStore.restore(scene,legacy)
	check(look.document() == baseline,"Legacy scene resets previous custom look")
	# Validate actual material coverage, including objects created after choosing a palette.
	var editor = scene._chunk_editor
	check(editor.terrain.mesh.surface_get_material(0).get_shader_parameter("palette_role") == 1,"Terrain participates in palette")
	check(editor.content._materials.canopy.get_shader_parameter("palette_role") == 2,"New trees participate")
	check(editor.content._materials.rock.get_shader_parameter("palette_role") == 3,"New rocks participate")
	check(editor.content._materials.petal.get_shader_parameter("palette_role") == 0,"Flowers retain their individual colors")
	root.content_scale_factor = 2.0
	for dimensions in [Vector2i(960,640),Vector2i(1440,960)]:
		root.size = dimensions
		panel.show()
		await process_frame
		panel._layout()
		await process_frame
		check(panel.tabs.size.y > 180,"Controls remain usable on a small Retina window")
		check(not editor.pointer_in_world(panel.get_global_rect().get_center()),"Palette controls block the terrain brush")
		check(root.get_visible_rect().encloses(panel.get_global_rect()),"Editor fits "+str(dimensions))
	DirAccess.remove_absolute(path)
	scene.free()
	print("SCENE LOOK: failures=",failures)
	quit(1 if failures else 0)
