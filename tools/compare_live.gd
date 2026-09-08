extends SceneTree
## Interactive seed-7 comparison; uses the native scene and its real controls.
class ResetView extends Node:
	var scene: Node3D
	var old_shadows := false
	var display_synced := true
	var atmosphere_test := 0
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
			atmosphere_test = (atmosphere_test + 1) % 3
			_set_atmosphere_test()
			_refresh_title()
			get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
			display_synced = not display_synced
			_set_presentation()
			_refresh_title()
			get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
			scene.camera_time_based_damping = not scene.camera_time_based_damping
			_refresh_title()
			get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
			old_shadows = not old_shadows
			RenderingServer.directional_soft_shadow_filter_set_quality(1 if old_shadows else 3)
			for light in scene._lights: light.shadow_blur = 0.2 if old_shadows else 0.5
			_refresh_title()
			get_viewport().set_input_as_handled()
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
			scene._auto_orbit = false
			scene._orbit_delta = Vector2.ZERO
			scene._pan_delta = Vector2.ZERO
			scene.target = Vector3(0, 3, 0)
			scene.distance = 43.0
			scene.polar = 1.13
			scene.yaw = 1.8893
			scene._update_camera()
			get_viewport().set_input_as_handled()
	func _refresh_title() -> void:
		DisplayServer.window_set_title("Godot · camera: %s · shadows: %s · pacing: %s · air: %s" % ["previous" if scene.camera_time_based_damping else "revised", "previous" if old_shadows else "filtered", "display sync" if display_synced else "120 timer", ["normal", "no history", "hidden"][atmosphere_test]])
	func _set_atmosphere_test() -> void:
		var fog: CanvasLayer = scene._display_fog
		if fog == null: return
		# Keep the rendering workload running when hidden: this comparison
		# removes its visible contribution, not its GPU cost.
		fog.visible = atmosphere_test != 2
		fog.temporal_blend = 0.12 if atmosphere_test == 0 else 1.0
		fog.forget()
	func _set_presentation() -> void:
		Engine.max_fps = 0 if display_synced else 120
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if display_synced else DisplayServer.VSYNC_DISABLED)

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	DisplayServer.window_set_size(Vector2i(2400, 1500))
	DisplayServer.window_set_title("ZenScape · Godot comparison")
	var scene: Node3D = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	var reset := ResetView.new()
	reset.scene = scene
	root.add_child(reset)
	reset._set_presentation()
	reset._set_atmosphere_test()
	reset._refresh_title()
	print("COMPARISON: seed 7, physical viewport ", root.size, "; F6 resets the shared view.")
