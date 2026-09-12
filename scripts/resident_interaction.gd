extends RefCounted
## Resident gestures precede authoring; a grab owns its motion and release.
var scene: Node3D
var hovered := false
var pressed := false
var carrying := false
var gust := false
var press_at := Vector2.ZERO
var hold_plane := Plane(Vector3.UP,3.0)
var hint := Label.new()
var _cursor_owned := false
var _wet_hold := false
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

func pick(mouse: Vector2) -> bool:
	if scene.creature == null or not scene.resident_enabled or not scene.creature.visible or scene._paused or not scene._chunk_editor.pointer_in_world(mouse): return false
	if scene.get("world_play") != null and scene.world_play.owner_scene != null and scene.world_play.loose_props.held_at(mouse): return false
	var ray: Vector3 = scene.camera.project_ray_origin(mouse)
	var direction: Vector3 = scene.camera.project_ray_normal(mouse)
	var inverse: Transform3D = scene.creature.global_transform.affine_inverse()
	var hit: Variant = AABB(Vector3(-0.65,0,-0.45),Vector3(1.3,2.9,0.9)).intersects_ray(inverse*ray,(inverse.basis*direction).normalized())
	if hit == null: return false
	var ground: Variant = scene._chunk_editor.pick(mouse)
	return ground == null or ray.distance_to(scene.creature.global_transform*hit) <= ray.distance_to(scene._chunk_editor.terrain.to_global(ground))+0.1

func owns_pointer() -> bool:
	return hovered or pressed or carrying or gust

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
	if carrying: release(Vector2(-1,-1))
	pressed = false
	gust = false
	hovered = false
	hint.hide()
	if scene._gust_button != null: scene._gust_button.set_pressed_no_signal(false)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_cursor_owned = false

func toggle_gust() -> void:
	if carrying: release(Vector2(-1,-1))
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
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and (pressed or carrying or gust):
		if carrying: release(Vector2(-1,-1))
		pressed = false
		gust = false
		scene._gust_button.set_pressed_no_signal(false)
		return true
	if event is InputEventMouseMotion and pressed:
		if not carrying and event.position.distance_to(press_at) >= 5.0:
			if scene.get("world_play") != null: scene.world_play.cancel()
			scene.routine.cancel("picked up")
			carrying = scene.creature.pick_up()
			hold_plane = Plane(Vector3.UP,scene.creature.global_position.y+scene.creature.grasp_height+0.9)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and pressed:
			if carrying: release(event.position)
			pressed = false
			return true
		if event.pressed and pick(event.position):
			pressed = true
			press_at = event.position
			scene._chunk_editor.finish_stroke()
			return true
		if event.pressed and gust and not scene._paused and scene._chunk_editor.pointer_in_world(event.position):
			var hit: Variant = scene._chunk_editor.pick(event.position)
			if hit != null:
				aim_start = scene._chunk_editor.terrain.to_global(hit)
				aim_end = aim_start
				scene._chunk_editor.finish_stroke()
			return true
	return false

func release(mouse: Vector2) -> void:
	if scene.get("world_play") != null and scene._chunk_editor.pointer_in_world(mouse):
		var play: Node = scene.world_play
		var water: Variant = play.water_play.pick(mouse)
		if water != null:
			play.ensure_collision()
			var shore: Variant = play.water_play.shore_from(scene.creature.global_position)
			if shore != null and scene.creature.enter_water(water.y,shore):
				play.water_play.splash(water,1.0)
				carrying = false
				pressed = false
				_wet_hold = false
				return
	var destination: Variant = null
	if scene._chunk_editor.pointer_in_world(mouse) and not scene._habitat_changed and not scene.navigation.rebuilding:
		var p: Vector3 = scene.creature.global_position
		var ground: Variant = scene.habitat.ground_height(Vector2(p.x,p.z))
		if ground != null:
			p.y = ground
			if scene.navigation.is_safe(p): destination = p
	scene.creature.release_at(destination)
	carrying = false
	pressed = false
	_wet_hold = false

func update(delta: float) -> void:
	var mouse: Vector2 = scene.get_viewport().get_mouse_position()
	var available: bool = scene._chunk_editor.pointer_in_world(mouse) and not scene._paused
	if scene._paused and aim_start != null: clear_aim()
	hovered = available and aim_start == null and pick(mouse)
	if carrying and available:
		var at: Variant = hold_plane.intersects_ray(scene.camera.project_ray_origin(mouse),scene.camera.project_ray_normal(mouse))
		if at != null:
			var destination: Vector3 = at-Vector3.UP*scene.creature.grasp_height
			var terrain_hit: Variant = scene._chunk_editor.pick(mouse)
			if terrain_hit != null:
				destination = scene._chunk_editor.terrain.to_global(terrain_hit)+Vector3.UP*0.9
			var over_water := false
			if scene.get("world_play") != null:
				var water: Variant = scene.world_play.water_play.pick(mouse)
				if water != null:
					over_water = true
					var ground: Variant = scene.world_play._probe_ground(water)
					if ground != null: destination = Vector3(water.x,maxf(ground.y,water.y-1.65),water.z)
					if scene.creature.global_position.y<water.y-0.6 and not _wet_hold:
						scene.world_play.water_play.splash(water,1.0)
						_wet_hold = true
				else: _wet_hold = false
			var position: Vector3 = scene.creature.global_position.lerp(destination,1.0-exp(-22.0*delta))
			# Smoothing can cut through a slope even when its endpoint is above it.
			var floor_height: Variant = scene.habitat.ground_height(Vector2(position.x,position.z))
			if floor_height != null:
				position.y = maxf(position.y,float(floor_height)+(0.0 if over_water else 0.9))
			scene.creature.move_held(position,delta)
	hint.visible = available and owns_pointer()
	hint.text = "Release to set down · Esc to return" if carrying else ("Release to send wind · Esc to cancel" if aim_start != null else ("Bigfoot · Drag to pick up" if hovered else "Wind gust · Drag the ground to aim · Esc to finish"))
	hint.position = (mouse+Vector2(18,22)).clamp(Vector2.ZERO,scene.get_viewport().get_visible_rect().size-hint.size)
	if available and owns_pointer():
		Input.set_default_cursor_shape(Input.CURSOR_DRAG if carrying else (Input.CURSOR_POINTING_HAND if hovered else Input.CURSOR_CROSS))
		_cursor_owned = true
	elif _cursor_owned:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		_cursor_owned = false
