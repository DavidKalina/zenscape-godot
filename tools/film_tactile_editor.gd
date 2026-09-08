extends SceneTree
## Scripted mouse gestures through the real controls; disposable scene and save path.
const FRAMES := "/private/tmp/zenscape-tactile-film"
var scene: Node3D
var editor: NativeChunkEditor
var palette: NativeBuildPalette
var cursor := Vector2.ZERO
var down := false
var frame := 0
var caption := Label.new()
var marker := Panel.new()
var failures := 0
func _initialize() -> void:
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec",1000.0)
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	print("FRAME ",frame,": ",message," = ",ok)
	if not ok: failures += 1
func motion() -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform()*cursor
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event)
func press(value: bool) -> void:
	down = value
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform()*cursor
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event)
func shoot() -> void:
	motion()
	marker.position = cursor-Vector2(4,4)
	marker.modulate.a = 1.0 if down else 0.65
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(FRAMES.path_join("%04d.jpg" % frame),0.95)
	frame += 1
func hold(count: int) -> void:
	for i in range(count): await shoot()
func glide(target: Vector2, count := 24) -> void:
	var start := cursor
	for i in range(1,count+1):
		var t := float(i)/count
		cursor = start.lerp(target,t*t*(3-2*t))
		await shoot()
func click(target: Vector2, settle := 18) -> void:
	await glide(target)
	press(true)
	await hold(3)
	press(false)
	await hold(settle)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
func ground(x: float, z: float) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(x,editor.data.ground_height(Vector2(x,z)),z)))
func chapter(text: String) -> void:
	caption.text = text
	print("CHAPTER ",frame/30.0,": ",text)
func run() -> void:
	create_timer(180).timeout.connect(func() -> void: quit(2))
	DirAccess.make_dir_recursive_absolute(FRAMES)
	root.size = Vector2i(1440,900)
	scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/zenscape-film-world-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.add_child(scene)
	await process_frame
	scene.new_diorama()
	editor = scene._chunk_editor
	palette = scene._build_palette
	await editor.form_landscape("valley","",false)
	preload("res://scripts/scene_look_presets.gd").apply(scene,"golden_meadow")
	scene._frame_diorama()
	palette._choose("select")
	# Video-only pointer and chapter caption, kept out of the editable scene.
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	caption.position = Vector2(0,62)
	caption.size.x = root.get_visible_rect().size.x
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",palette.theme.default_font)
	caption.add_theme_font_size_override("font_size",12)
	caption.add_theme_color_override("font_color",Color("e0d6c9"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(caption)
	marker.size = Vector2(8,8)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := StyleBoxFlat.new()
	dot.bg_color = Color("eed9b7")
	dot.set_corner_radius_all(4)
	dot.set_border_width_all(1)
	dot.border_color = Color("453a32")
	marker.add_theme_stylebox_override("panel",dot)
	overlay.add_child(marker)
	# Avoid two competing pointers in a scripted recording.
	palette._hand.modulate.a = 0.0
	cursor = Vector2(85,root.get_visible_rect().size.y-38)
	chapter("Choose a piece")
	await hold(30)
	await click(palette._tool_rail.dock.find_child("Browse",true,false).get_global_rect().get_center(),30)
	check(palette._bar.visible,"Browse opens the catalog")
	palette._search.text = "pine"
	palette._search.text_changed.emit("pine")
	await hold(40)
	await click(palette._row_buttons["tree"].get_global_rect().get_center(),36)
	check(editor.mode == "tree" and not palette._bar.visible,"Choose Pine through the catalog")
	chapter("A small control, only when you need it")
	await click(palette._tool_rail.held.get_global_rect().get_center(),36)
	check(palette._tool_rail.card.visible,"Click the held piece to reveal controls")
	var slider: HSlider = palette._tool_rail.quick_row.control
	var rect := slider.get_global_rect()
	await glide(Vector2(rect.position.x+rect.size.x*0.19,rect.get_center().y))
	press(true)
	await hold(3)
	await glide(Vector2(rect.position.x+rect.size.x*0.32,rect.get_center().y),35)
	press(false)
	await hold(25)
	check(editor.object_scale > 1.2,"Drag the size control")
	await click(palette._tool_rail.held.get_global_rect().get_center(),18)
	check(not palette._tool_rail.card.visible,"Put the control away")
	chapter("Plant a few trees")
	var before := editor.data.objects.size()
	await click(ground(-7,4),28)
	await click(ground(-5,6),28)
	await click(ground(-9,2),40)
	check(editor.data.objects.size() == before+3,"Three mouse clicks place three pines")
	chapter("Undo. Try again.")
	await click(palette._tool_rail._undo.get_global_rect().get_center(),32)
	check(editor.data.objects.size() == before+2,"Undo removes the last tree")
	await click(palette._tool_rail._redo.get_global_rect().get_center(),32)
	check(editor.data.objects.size() == before+3,"Redo restores it")
	chapter("Put the tools down")
	key(KEY_ESCAPE)
	await hold(30)
	check(editor.mode == "select","Escape returns to selection")
	await click(scene._build_button.get_global_rect().get_center(),40)
	check(not palette.visible,"Enjoy hides the tray")
	await glide(Vector2(40,root.get_visible_rect().size.y-40))
	chapter("")
	await hold(60)
	print("FILM COMPLETE frames=",frame," seconds=",frame/30.0," failures=",failures)
	scene.free()
	for file in DirAccess.get_files_at(folder): DirAccess.remove_absolute(folder+"/"+file)
	DirAccess.remove_absolute(folder)
	quit(1 if failures else 0)
