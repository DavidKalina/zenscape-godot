extends RefCounted
## The scene gust's gesture (Wind gust): it precedes authoring, and while it
## is held a drag across the ground aims a gust and its release sends it.
var scene: Node3D
var gust := false
var hint := Label.new()
var _cursor_owned := false
var aim_start: Variant = null
var aim_end := Vector3.ZERO

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	var overlay := CanvasLayer.new()
	scene.add_child(overlay)
	overlay.add_child(hint)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_color",Color("fff0d9"))
	hint.add_theme_color_override("font_shadow_color",Color("25202a"))
	hint.add_theme_constant_override("shadow_offset_x",1)
	hint.add_theme_constant_override("shadow_offset_y",2)
	hint.hide()

func owns_pointer() -> bool:
	return gust

func clear_aim() -> void:
	aim_start = null
	scene._resident_wind.visuals.clear_aim()

func update_aim(mouse: Vector2) -> void:
	var at: Variant = Plane(Vector3.UP,aim_start.y).intersects_ray(scene.camera.project_ray_origin(mouse),scene.camera.project_ray_normal(mouse))
	if at != null:
		aim_end = at
		scene._resident_wind.visuals.set_aim(aim_start,aim_end,scene._resident_wind.ground)

func cancel() -> void:
	clear_aim()
	gust = false
	hint.hide()
	if scene._gust_button != null: scene._gust_button.set_pressed_no_signal(false)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_cursor_owned = false

func toggle_gust() -> void:
	clear_aim()
	gust = not gust
	if gust:
		scene._build_palette._finish_placing()
		scene._chunk_editor.finish_stroke()
	scene._gust_button.set_pressed_no_signal(gust)

func handle(event: InputEvent) -> bool:
	if aim_start != null:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			clear_aim()
			return true
		if event is InputEventMouseMotion:
			update_aim(event.position)
			return true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			update_aim(event.position)
			var direction: Vector3 = aim_end-aim_start
			direction.y = 0.0
			if not scene._paused and scene._chunk_editor.pointer_in_world(event.position) and direction.length() >= 0.3:
				scene.send_scene_gust(aim_start,direction.normalized())
			clear_aim()
			return true
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and gust:
		gust = false
		scene._gust_button.set_pressed_no_signal(false)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and gust and not scene._paused and scene._chunk_editor.pointer_in_world(event.position):
			var hit: Variant = scene._chunk_editor.pick(event.position)
			if hit != null:
				aim_start = scene._chunk_editor.terrain.to_global(hit)
				aim_end = aim_start
				scene._chunk_editor.finish_stroke()
			return true
	return false

func update(_delta: float) -> void:
	var mouse: Vector2 = scene.get_viewport().get_mouse_position()
	var available: bool = scene._chunk_editor.pointer_in_world(mouse) and not scene._paused
	if scene._paused and aim_start != null: clear_aim()
	hint.visible = available and owns_pointer()
	hint.text = "Release to send wind · Esc to cancel" if aim_start != null else "Wind gust · Drag the ground to aim · Esc to finish"
	hint.position = (mouse+Vector2(18,22)).clamp(Vector2.ZERO,scene.get_viewport().get_visible_rect().size-hint.size)
	if available and owns_pointer():
		Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		_cursor_owned = true
	elif _cursor_owned:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_cursor_owned = false
