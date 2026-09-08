extends Node3D
## A rendering study of the original scene. Press Tab to compare the matched
## source image; orbit to inspect the genuinely three-dimensional Godot scene.

var _chunk_editor: NativeChunkEditor
var _build_panel: NativeBuildPanel
var _build_palette: NativeBuildPalette
var _saved_setting_controls: Array[Dictionary] = []
var _display_fog: CanvasLayer
var camera: Camera3D
var target := Vector3.ZERO
var distance := 43.0
var yaw := 1.8893
var polar := 1.13
var _reference: TextureRect
var _ui: CanvasLayer
var _status: Label
var _source: Dictionary
var _orbiting := false
## Source OrbitControls damping: pointer deltas pool here and 5 % of the pool
## is applied per 60 Hz frame, so the camera glides and settles.
const CAMERA_DAMPING := 0.05
const ZOOM_STEP := 0.95
var _orbit_delta := Vector2.ZERO
var _pan_delta := Vector2.ZERO
var _auto_orbit := false
var _elapsed := 0.0
var _capture := ""
var _capture_done := false
var _preroll := 0.0
var _prerolling := false
var _film_directory := ""
var _film_frames := 0
var _recorded_frames := 0
var _processed_film_frame := -1
var _film_fps := 30.0
var _bird_flight := preload("res://studies/bird_flight.gd").new()
var _fall_foam := preload("res://studies/fall_foam.gd").new()
var _frog_motion := preload("res://studies/frog_motion.gd").new()
var _fireflies: MultiMeshInstance3D
var _birds: MultiMesh
var _motion_time := 0.0
var _paused := false
var _wind := 0.4
var _environment: Environment
var _panning := false
var _quality: OptionButton
var _atmosphere: Node3D
var _celestial: RefCounted
var _lights: Array[DirectionalLight3D] = []
var _aurora_slider: HSlider
var _cycle_toggle: CheckBox
var _time_slider: HSlider
var _time_label: Label
var _bigfoot: Node3D
var _wind_slider: HSlider
var _fog_slider: HSlider
var _haze_slider: HSlider
var _cloud_slider: HSlider
var _weather_selector: OptionButton
var _thunder_audio: Node
var _ambient_audio: Node
var _lightning: Node3D
var _precipitation: Node3D
var _growth := preload("res://studies/growth.gd").new()
var _terrain_slider: HSlider
var _foliage_slider: HSlider
var _water_slider: HSlider
var _autumn_slider: HSlider
var _cold_slider: HSlider
var _tremor := preload("res://scripts/reference_tremor.gd").new()

func _ready() -> void:
	set_process(false)
	var engine_args := OS.get_cmdline_args()
	var fps_index := engine_args.find("--fixed-fps")
	if fps_index >= 0 and fps_index + 1 < engine_args.size():
		_film_fps = maxf(1.0, float(engine_args[fps_index + 1]))
	# Render at the display's physical resolution; scale only the UI by DPI.
	get_window().content_scale_factor = DisplayServer.screen_get_scale()
	# Open large when launched as the app; tests size the root themselves.
	if get_tree().current_scene == self:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	var geometry: Node3D = $Reference
	_source = geometry.get_meta("source_settings", {})
	if _source.is_empty():
		_source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/scene.json"))
	for child in geometry.get_children():
		if child.get_meta("source_kind", "static") == "birds":
			_birds = child.multimesh
	_add_fall_mist(geometry)
	RenderingServer.global_shader_parameter_set("zs_motion_time", 0.0)
	_set_wind(_wind)
	_setup_environment()
	_celestial = preload("res://studies/celestial.gd").new()
	_celestial.setup(_lights)
	_atmosphere = preload("res://studies/atmosphere.gd").new()
	add_child(_atmosphere)
	_atmosphere.setup(geometry, _environment)
	camera = Camera3D.new()
	camera.fov = float(_source.camera.fov)
	camera.near = 0.1
	camera.far = 500.0
	add_child(camera)
	camera.current = true
	_reset_camera()
	_bigfoot = preload("res://studies/bigfoot_encounter.gd").new()
	add_child(_bigfoot)
	_bigfoot.setup(geometry)
	var bird_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/bird-flight.json"))
	var bird_ground = preload("res://scripts/reference_source_ground.gd").new()
	bird_ground.setup()
	_bird_flight.setup(_birds, bird_ground, bird_data)
	var bird_material: ShaderMaterial = geometry.get_node(bird_data.mesh).multimesh.mesh.surface_get_material(0)
	bird_material.set_shader_parameter("source_bird_flight", true)
	_precipitation = preload("res://studies/precipitation.gd").new()
	add_child(_precipitation)
	_precipitation.setup(geometry, _bigfoot.ground)
	_precipitation.weather_selected.connect(_atmosphere.set_weather_profile)
	_atmosphere.set_ground_texture(_precipitation.ground_texture, _precipitation.stream_texture)
	_lightning = preload("res://studies/lightning.gd").new()
	add_child(_lightning)
	_lightning.setup(_bigfoot.ground)
	_thunder_audio = preload("res://studies/thunder_audio.gd").new()
	add_child(_thunder_audio)
	_ambient_audio = preload("res://studies/ambient_audio.gd").new()
	add_child(_ambient_audio)
	_lightning.thunder.connect(_thunder_audio.play_thunder)
	_fall_foam.setup(geometry, JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/fall-foam.json")))
	_fireflies = preload("res://studies/fireflies.gd").new()
	_fireflies.name = "Fireflies"
	add_child(_fireflies)
	_fireflies.setup(JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/fireflies.json")))
	_growth.setup(geometry)
	_frog_motion.setup(geometry)
	_chunk_editor = NativeChunkEditor.new()
	add_child(_chunk_editor)
	_chunk_editor.setup(self)
	_build_ui()
	if not OS.get_cmdline_user_args().has("--native-fog") and RenderingServer.get_current_rendering_method() == "forward_plus":
		_enable_display_fog()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mood="):
			_apply_mood(int(argument.trim_prefix("--mood=")))
		if argument.begins_with("--preroll="):
			_preroll = float(argument.trim_prefix("--preroll="))
		if argument.begins_with("--film-dir="):
			_film_directory = argument.trim_prefix("--film-dir=")
			DirAccess.make_dir_recursive_absolute(_film_directory)
		if argument.begins_with("--film-frames="):
			_film_frames = int(argument.trim_prefix("--film-frames="))
			RenderingServer.frame_post_draw.connect(_film_frame)
		if argument.begins_with("--autumn="):
			_precipitation.surface_weather.autumn = clampf(float(argument.trim_prefix("--autumn=")), 0.0, 1.0)
			_precipitation.surface_weather.target_autumn = _precipitation.surface_weather.autumn
		if argument.begins_with("--cold="):
			_precipitation.cold_override = float(argument.trim_prefix("--cold="))
			_precipitation.surface_weather.cold = _precipitation.cold_override
		if argument.begins_with("--ice="):
			_precipitation.surface_weather.ice = float(argument.trim_prefix("--ice="))
		if argument.begins_with("--snow-cover="):
			_precipitation.surface_weather.snow_cover = float(argument.trim_prefix("--snow-cover="))
		if argument.begins_with("--water-growth="):
			_growth.set_water(float(argument.trim_prefix("--water-growth=")))
		if argument == "--water-reveal":
			_growth.replay_water()
		if argument == "--reveal":
			_growth.replay()
		if argument.begins_with("--growth="):
			var values := argument.trim_prefix("--growth=").split(",")
			_growth.set_terrain(float(values[0]))
			_growth.set_foliage(float(values[1]) if values.size() > 1 else float(values[0]))
		if argument in ["--no-rain-rings", "--no-lake-wind", "--legacy-lake-material", "--no-algae", "--opaque-water-probe", "--legacy-water-shadows", "--no-lake-glints", "--lake-display-lighting", "--lake-lighting-probe", "--legacy-lake-lighting"]:
			for node in $Reference.get_children():
				if node is MeshInstance3D:
					var water_material := node.mesh.surface_get_material(0) as ShaderMaterial
					if water_material != null and water_material.shader.resource_path.ends_with("reference_water.gdshader"):
						var parameter := "rain_rings_enabled" if argument == "--no-rain-rings" else "lake_wind_enabled" if argument == "--no-lake-wind" else "source_lake_material"
						if argument in ["--no-lake-glints", "--lake-display-lighting", "--lake-lighting-probe", "--legacy-lake-lighting"]:
							water_material.set_shader_parameter("lake_glints_enabled", false)
						elif argument == "--legacy-water-shadows":
							water_material.shader = load("res://shaders/reference_water.gdshader")
						elif argument == "--opaque-water-probe":
							water_material.set_shader_parameter("opaque_water_probe", true)
						elif argument == "--no-algae":
							water_material.set_shader_parameter("lake_algae_amount", 0.0)
						else:
							water_material.set_shader_parameter(parameter, false)
		if argument == "--no-leaves":
			_precipitation.leaves.enabled = false
		if argument == "--display-fog":
			_enable_display_fog()
		if argument == "--clean":
			_ui.visible = false
		if argument.begins_with("--capture="):
			_capture = argument.trim_prefix("--capture=")
			_ui.visible = false
		if argument == "--orbit":
			_auto_orbit = true
		if argument.begins_with("--cam="):
			var pose := argument.trim_prefix("--cam=").split(",")
			if pose.size() == 6:
				distance = maxf(0.5, float(pose[0]))
				polar = clampf(float(pose[1]), 0.05, PI - 0.05)
				yaw = float(pose[2])
				target = Vector3(float(pose[3]), float(pose[4]), float(pose[5]))
				_update_camera()
		if argument == "--horizon":
			target = Vector3(0, 4, 0)
			distance = 32.0
			polar = 1.5
			_update_camera()
		if argument == "--detail":
			target = Vector3(4.0, 1.7, -2.0)
			distance = 18.0
			yaw = 2.2
			polar = 0.75
			_update_camera()
		if argument == "--balanced":
			_set_quality(1)
		if argument == "--paused":
			_paused = true
		if argument == "--lightning":
			_lightning.strike(Vector2(4, -2), camera.global_position)
		if argument == "--no-downburst":
			_lightning.downburst_enabled = false
		if argument == "--gust":
			_atmosphere.send_gust(Vector3.ZERO)
		if argument.begins_with("--wind="):
			_set_wind(float(argument.trim_prefix("--wind=")))
			_atmosphere._air_strength = _atmosphere.strength
		if argument == "--no-fog":
			_atmosphere.set_fog(0.0)
			_atmosphere.set_haze(0.0)
			_celestial.inversion_enabled = false
		if argument.begins_with("--phase="):
			_celestial.set_phase(float(argument.trim_prefix("--phase=")))
		if argument == "--no-inversion":
			_celestial.inversion_enabled = false
		if argument == "--no-alpenglow":
			_celestial.alpen_enabled = false
		if argument == "--rainbow":
			_celestial.rainbow_strength = 1.0
			_celestial._rainbow_growth = 1.0
		if argument.begins_with("--rays="):
			_atmosphere.set_rays(float(argument.trim_prefix("--rays=")))
		if argument.begins_with("--clouds="):
			_precipitation.cloud_override = float(argument.trim_prefix("--clouds="))
		if argument.begins_with("--weather="):
			_precipitation.set_weather(int(argument.trim_prefix("--weather=")), true)
		if argument == "--bigfoot-fog":
			_atmosphere.set_fog(0.75)
			_summon_bigfoot(true)
		if argument == "--bigfoot":
			_summon_bigfoot()
			_bigfoot.age = 5.0
		if argument == "--aurora":
			_celestial.aurora_strength = 1.2
		if argument.begins_with("--shroud="):
			_atmosphere.shroud = clampf(float(argument.trim_prefix("--shroud=")), 0.0, 1.0)
		if argument.begins_with("--loosen="):
			_atmosphere.loosen = clampf(float(argument.trim_prefix("--loosen=")), 0.0, 1.0)
		if argument.begins_with("--haze="):
			_atmosphere.set_haze(float(argument.trim_prefix("--haze=")))
		if argument.begins_with("--fog="):
			_atmosphere.set_fog(float(argument.trim_prefix("--fog=")))
	_celestial.shroud = _atmosphere.shroud
	_precipitation.advance(0.0, false, _celestial)
	_atmosphere.cloud = _celestial.cloud
	_atmosphere.rain = maxf(_precipitation.state.x, _precipitation.state.y)
	_atmosphere._publish_wind()
	_celestial.update_rig()
	_bigfoot.advance(0.0, false, camera.global_position)
	if _preroll > 0.0:
		_prerolling = true
		_process(_preroll)
		_prerolling = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--garden-file="):
			_chunk_editor.save_path = argument.trim_prefix("--garden-file=")
	if OS.get_cmdline_user_args().has("--garden"):
		if FileAccess.file_exists(_chunk_editor.save_path):
			_chunk_editor.open_garden()
		_chunk_editor.set_active(true)
	set_process(true)

func _enable_display_fog() -> void:
	if _display_fog != null:
		return
	_display_fog = preload("res://studies/display_fog.gd").new()
	add_child(_display_fog)
	_display_fog.setup(_atmosphere, camera, _precipitation.ground_texture, _precipitation.stream_texture)
	_display_fog.visible = not OS.get_cmdline_user_args().has("--no-fog")
	_atmosphere.native_volume = false
	_environment.volumetric_fog_enabled = false

func _setup_environment() -> void:
	var lighting := preload("res://scripts/landscape_lighting.gd").new()
	add_child(lighting)
	lighting.setup(_source)
	_environment = lighting.environment
	_lights.assign(lighting.lights)

func _reset_camera(reference_pose := false) -> void:
	target = _vector(_source.camera.target)
	var offset := _vector(_source.camera.position) - target
	distance = offset.length()
	polar = acos(offset.y / distance)
	yaw = atan2(offset.x, offset.z)
	if not reference_pose:
		var bounds := AABB()
		var found := false
		var points := PackedVector3Array()
		var framing_nodes: Array[Node] = $Reference.get_children()
		if _chunk_editor != null and _chunk_editor.data.blank:
			framing_nodes = framing_nodes.filter(func(node: Node) -> bool: return node is Node3D and node.is_visible_in_tree())
		if _chunk_editor != null:
			framing_nodes.append_array(_chunk_editor.content.get_children())
			framing_nodes.append_array(_chunk_editor.falls.get_children())
			framing_nodes.append_array(_chunk_editor.landmarks.find_children("*","MeshInstance3D",true,false))
		for node in framing_nodes:
			if node.get_meta("source_kind","") == "birds":
				continue
			if node is MultiMeshInstance3D:
				var mesh_box: AABB = node.multimesh.mesh.get_aabb()
				for instance in range(node.multimesh.instance_count):
					var pose: Transform3D = node.transform * node.multimesh.get_instance_transform(instance)
					for corner in range(8):
						points.append(pose * mesh_box.get_endpoint(corner))
			elif node is MeshInstance3D and node.mesh != null:
				for surface in range(node.mesh.get_surface_count()):
					var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
					for vertex: Vector3 in vertices:
						points.append(global_transform.affine_inverse() * node.global_transform * vertex)
		for point: Vector3 in points:
			bounds = bounds.expand(point) if found else AABB(point,Vector3.ZERO)
			found = true
		if found:
			target = bounds.get_center()
			_update_camera()
			var size := get_viewport().get_visible_rect().size
			var vertical := tan(deg_to_rad(camera.fov)*0.5)
			var horizontal := vertical*size.x/maxf(size.y,1.0)
			distance = 0.0
			for endpoint: Vector3 in points:
				var point := endpoint-target
				var depth := point.dot(camera.basis.z)
				distance = maxf(distance,depth+absf(point.dot(camera.basis.x))*1.12/horizontal)
				distance = maxf(distance,depth+absf(point.dot(camera.basis.y))*1.12/vertical)
			distance = maxf(distance,8.0)
	_update_camera()

func _update_camera() -> void:
	camera.position = target + Vector3(sin(polar) * sin(yaw), cos(polar), sin(polar) * cos(yaw)) * distance
	camera.look_at(target)

func _face_rainbow() -> void:
	var sun: Vector3 = _celestial.state.zs_sun_direction
	yaw = atan2(sun.x, sun.z)
	polar = 1.5
	distance = maxf(distance,43.0)
	_auto_orbit = false
	_update_camera()

func _input(event: InputEvent) -> void:
	# Releases over the control panel must still finish camera gestures.
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _chunk_editor != null:
			_chunk_editor.finish_pointer_gesture()
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_orbiting = false
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = false
	# Pointer motion is read here so a drag that crosses the control panel
	# keeps moving the camera, as the source's pointer capture does.
	if event is InputEventMouseMotion and _orbiting:
		_orbit_delta += event.relative
	elif event is InputEventMouseMotion and _panning:
		_pan_delta += event.relative
	# macOS delivers trackpad momentum as pan gestures and pinch as magnify.
	if event is InputEventPanGesture:
		_zoom(event.delta.y)
	if event is InputEventMagnifyGesture:
		distance = clampf(distance / event.factor, 0.5, 150.0)
		_update_camera()

func _zoom(amount: float) -> void:
	# Source: 0.95 per 100 px of wheel; Godot's precise factor is 0.03 px.
	distance = clampf(distance / pow(ZOOM_STEP, amount / 3.0), 0.5, maxf(150.0, distance))
	_update_camera()

func _ease_camera(delta: float) -> void:
	var retain := pow(1.0 - CAMERA_DAMPING, delta * 60.0)
	var apply := 1.0 - retain
	var height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	if _orbit_delta != Vector2.ZERO:
		var step := _orbit_delta * apply
		yaw -= TAU * step.x / height
		polar = clampf(polar - TAU * step.y / height, 0.25, 1.5)
		_orbit_delta *= retain
	if _pan_delta != Vector2.ZERO:
		var step := _pan_delta * apply
		var reach := 2.0 * distance * tan(deg_to_rad(camera.fov) * 0.5) / height
		target += (-camera.global_basis.x * step.x + camera.global_basis.y * step.y) * reach
		_pan_delta *= retain

func _unhandled_input(event: InputEvent) -> void:
	if _chunk_editor != null and _chunk_editor.handle_input(event):
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_orbiting = event.pressed
		if event.pressed and (_orbiting or _panning):
			_auto_orbit = false # The source cancels its idle spin on the first press.
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom(-maxf(event.factor, 0.01))
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom(maxf(event.factor, 0.01))
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				_reset_camera(true)
				_auto_orbit = false
				_reference.visible = not _reference.visible
				_status.text = "THREE.JS  ·  captured reference" if _reference.visible else "GODOT  ·  live scene"
			KEY_R: _reset_camera()
			KEY_SPACE: _auto_orbit = not _auto_orbit
			KEY_H: _ui.visible = not _ui.visible
			KEY_P: _paused = not _paused
			KEY_G: _atmosphere.send_gust(target)
			KEY_F: _frog_motion.startle()
			KEY_N: _celestial.next_hour()
			KEY_B: _summon_bigfoot()
			KEY_T: _tremor.add(0.7)
			KEY_L: _lightning.strike(Vector2(target.x, target.z), camera.global_position)
			KEY_Y: _growth.replay()
			KEY_ESCAPE: _chunk_editor.set_active(false)

func _process(delta: float) -> void:
	# An occluded macOS movie window may update without drawing. Advance once
	# per recorded frame so offscreen stalls cannot fast-forward the evidence.
	if _film_frames > 0 and not _prerolling:
		if _processed_film_frame == _recorded_frames:
			return
		_processed_film_frame = _recorded_frames
		delta = 1.0 / _film_fps
	_elapsed += delta
	_growth.advance(delta, _paused, _tremor)
	_terrain_slider.set_value_no_signal(_growth.terrain)
	_foliage_slider.set_value_no_signal(_growth.foliage)
	_water_slider.set_value_no_signal(_growth.water)
	$WaterfallSpray.visible = not _chunk_editor.data.blank and _growth.terrain >= 0.995 and _growth.water >= 0.5
	_bigfoot.update_growth(_growth.terrain,_growth.foliage)
	_precipitation.wind = _atmosphere.strength
	_celestial.shroud = _atmosphere.shroud
	_precipitation.advance(delta, _paused, _celestial)
	_growth.set_pond_conditions(_precipitation.surface_weather.cold, _precipitation.surface_weather.ice)
	_frog_motion.advance(delta, _paused)
	_autumn_slider.set_value_no_signal(_precipitation.surface_weather.autumn)
	_cold_slider.set_value_no_signal(_precipitation.surface_weather.target_cold)
	_wind_slider.set_value_no_signal(_atmosphere.strength)
	_fog_slider.set_value_no_signal(_atmosphere.fog_amount)
	_haze_slider.set_value_no_signal(_atmosphere.haze_amount)
	_cloud_slider.set_value_no_signal(_celestial.cloud)
	_weather_selector.select(_precipitation.preset_index)
	_atmosphere.cloud = _celestial.cloud
	_atmosphere.rain = maxf(_precipitation.state.x, _precipitation.state.y)
	_thunder_audio.update_state(_paused)
	_lightning.advance(delta, _paused, _precipitation.state.w, _atmosphere._air_strength, Vector2(cos(_atmosphere._air_angle), sin(_atmosphere._air_angle)), camera.global_position)
	_atmosphere.advance(delta, _paused)
	_ambient_audio.update_state(delta,_paused,_atmosphere._air_strength*_atmosphere.gust_at(_atmosphere._wind_time),_precipitation.state.x,_precipitation.surface_weather.snow_phase,_precipitation.surface_weather.ice,_growth.terrain,0.0 if _chunk_editor.data.blank and _chunk_editor.falls.get_child_count() == 0 and _chunk_editor.content._landscape_falls.is_empty() else _growth.water)
	_celestial.wind = _atmosphere._air_strength
	_celestial.advance(delta, _paused)
	_atmosphere.set_inversion(_celestial.state.zs_inversion.x)
	if not _paused:
		_motion_time += delta
		RenderingServer.global_shader_parameter_set("zs_motion_time", _motion_time)
	_bird_flight.growth = minf(_growth.foliage, _growth.water) if _growth.terrain >= 0.995 else 0.0
	_fireflies.update_conditions(_celestial.state.get("zs_daylight",1.0), _precipitation.state.x, _precipitation.surface_weather.cold, _bird_flight.growth)
	if _chunk_editor.data.blank:
		_fireflies.visible = false
	_bigfoot.visible = not _chunk_editor.data.blank or _bigfoot.authored_tree
	_bird_flight.advance(delta, _paused, _atmosphere._air_strength, Vector2(cos(_atmosphere._air_angle),sin(_atmosphere._air_angle)))
	_time_slider.set_value_no_signal(_celestial.phase)
	_fall_foam.advance(_motion_time, _paused, _precipitation.surface_weather.ice, smoothstep(0.0,0.5,_growth.water), _growth.terrain >= 0.995)
	var minutes: int = int(_celestial.phase * 1440.0)
	_time_label.text = "Time of day · %02d:%02d" % [minutes / 60, minutes % 60]
	if _auto_orbit:
		yaw += delta * 0.055
	_ease_camera(delta)
	_tremor.advance(delta, _paused)
	_update_camera()
	camera.transform = _tremor.apply(camera.transform)
	RenderingServer.global_shader_parameter_set("zs_camera_position", camera.global_position)
	_bigfoot.advance(delta, _paused or not _bigfoot.visible, camera.global_position, camera, minf(_growth.terrain, _growth.foliage), _atmosphere.fog_amount)
	if _display_fog != null:
		_environment.volumetric_fog_enabled = false
		_display_fog.blend.set_shader_parameter("surface_fog_color", _celestial.surface_fog_color)
		_display_fog.blend.set_shader_parameter("aerial_sun_color", _celestial.aerial_sun_color)
		_display_fog.material.set_shader_parameter("fog_display", _celestial.fog_display)
		_display_fog.update_view()
	$WaterfallSpray.update_view(camera, _display_fog.depth if _display_fog != null else null)
	_chunk_editor.sync_visibility()
	if not _capture.is_empty() and not _capture_done and _elapsed > 1.0:
		_capture_done = true
		_capture_frame.call_deferred()

func _capture_frame() -> void:
	# Offscreen captures must also complete when macOS occludes the window.
	RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	RenderingServer.force_draw(false)
	var result := get_viewport().get_texture().get_image().save_png(_capture)
	print("Fidelity capture: ", _capture, " result=", result)
	get_tree().quit(result)

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_reference = TextureRect.new()
	_reference.texture = load("res://assets/zen_reference/source.png")
	_reference.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reference.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reference.visible = false
	_ui.add_child(_reference)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.085, 0.88)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	_ui.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 5)
	scroll.add_child(column)
	_status = Label.new()
	_status.text = "GODOT  ·  live scene"
	_status.add_theme_color_override("font_color", Color("e1dec6"))
	_status.add_theme_font_size_override("font_size", 18)
	column.add_child(_status)
	_build_panel = NativeBuildPanel.new()
	column.add_child(_build_panel)
	_build_panel.attach(_chunk_editor)
	# Tools and their settings live on the bottom palette; the panel keeps the
	# global build controls.
	_build_palette = NativeBuildPalette.new()
	_ui.add_child(_build_palette)
	_build_palette.attach(_chunk_editor)
	var selection_panel := preload("res://scripts/native_selection_panel.gd").new()
	_ui.add_child(selection_panel)
	selection_panel.attach(_chunk_editor)
	var help := Label.new()
	help.text = "ZenScape seed 7 · fidelity study\nDrag to orbit · Middle drag to pan · Scroll to zoom\nTab Compare · R Frame landscape · Space Drift · P Pause motion\nH Hide controls · Build edits this chunk · Esc Inspect\nIn Build: V Select · 1-4 tools · [ ] brush size · K sky"
	help.add_theme_color_override("font_color", Color("aab8ad"))
	help.add_theme_font_size_override("font_size", 13)
	column.add_child(help)
	var study_toggle := CheckButton.new()
	study_toggle.text = "Scene · study controls"
	study_toggle.focus_mode = Control.FOCUS_NONE
	column.add_child(study_toggle)
	var study := VBoxContainer.new()
	study.visible = false
	study.add_theme_constant_override("separation", 5)
	study_toggle.toggled.connect(func(value: bool) -> void: study.visible = value)
	column.add_child(study)
	var mood_label := Label.new()
	mood_label.text = "Scene moods"
	study.add_child(mood_label)
	var moods := HBoxContainer.new()
	study.add_child(moods)
	for i in range(3):
		var button := Button.new()
		button.text = ["Warm evening", "Morning mist", "Aurora night"][i]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_apply_mood.bind(i))
		moods.add_child(button)
	var replay := Button.new()
	replay.text = "Replay landscape formation · Y"
	replay.focus_mode = Control.FOCUS_NONE
	replay.pressed.connect(_growth.replay)
	study.add_child(replay)
	var refill := Button.new()
	refill.text = "Refill water"
	refill.focus_mode = Control.FOCUS_NONE
	refill.pressed.connect(_growth.replay_water)
	study.add_child(refill)
	for channel in ["Terrain formation", "Water filling", "Foliage growth"]:
		var label := Label.new()
		label.text = channel
		study.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.001
		slider.focus_mode = Control.FOCUS_NONE
		slider.value = 1.0
		if channel == "Terrain formation":
			_terrain_slider = slider
			slider.value_changed.connect(_growth.set_terrain)
		elif channel == "Water filling":
			_water_slider = slider
			slider.value_changed.connect(_growth.set_water)
		else:
			_foliage_slider = slider
			slider.value_changed.connect(_growth.set_foliage)
		study.add_child(slider)
	var wind_label := Label.new()
	wind_label.text = "Wind"
	study.add_child(wind_label)
	var wind := HSlider.new()
	_wind_slider = wind
	wind.min_value = 0.0
	wind.max_value = 3.0
	wind.step = 0.05
	wind.value = _wind
	wind.value_changed.connect(_set_wind)
	wind.focus_mode = Control.FOCUS_NONE
	study.add_child(wind)
	var direction_label := Label.new()
	direction_label.text = "Wind direction"
	study.add_child(direction_label)
	var direction := HSlider.new()
	direction.min_value = -180.0
	direction.max_value = 180.0
	direction.value = _atmosphere.direction_angle
	direction.focus_mode = Control.FOCUS_NONE
	direction.value_changed.connect(func(value: float) -> void: _atmosphere.direction_angle = value)
	study.add_child(direction)
	_remember_setting(direction,_atmosphere,"direction_angle")
	var fog_label := Label.new()
	fog_label.text = "Valley fog"
	study.add_child(fog_label)
	var fog := HSlider.new()
	_fog_slider = fog
	fog.max_value = 1.0
	fog.step = 0.02
	fog.value = _atmosphere.fog_amount
	fog.focus_mode = Control.FOCUS_NONE
	fog.editable = RenderingServer.get_current_rendering_method() == "forward_plus"
	fog.value_changed.connect(_atmosphere.set_fog)
	study.add_child(fog)
	var summit_label := Label.new()
	summit_label.text = "Summit mist · cap and downwind spill"
	study.add_child(summit_label)
	var summit := HSlider.new()
	summit.max_value = 1.5
	summit.step = 0.05
	summit.value = _atmosphere.summit_mist
	summit.focus_mode = Control.FOCUS_NONE
	summit.editable = RenderingServer.get_current_rendering_method() == "forward_plus"
	summit.value_changed.connect(func(value: float) -> void:
		_atmosphere.summit_mist = value
		_atmosphere._publish_wind())
	study.add_child(summit)
	_remember_setting(summit,_atmosphere,"summit_mist")
	var haze_label := Label.new()
	haze_label.text = "Haze · atmospheric depth"
	study.add_child(haze_label)
	_haze_slider = HSlider.new()
	_haze_slider.max_value = 1.0
	_haze_slider.step = 0.01
	_haze_slider.value = _atmosphere.haze_amount
	_haze_slider.focus_mode = Control.FOCUS_NONE
	_haze_slider.value_changed.connect(_atmosphere.set_haze)
	study.add_child(_haze_slider)
	for property in ["shroud", "loosen"]:
		var label := Label.new()
		label.text = "Fog bank coverage" if property == "shroud" else "Fog bank fluidity"
		study.add_child(label)
		var slider := HSlider.new()
		slider.max_value = 1.0
		slider.step = 0.01
		slider.value = _atmosphere.get(property)
		slider.focus_mode = Control.FOCUS_NONE
		slider.editable = not OS.get_cmdline_user_args().has("--native-fog") and RenderingServer.get_current_rendering_method() == "forward_plus"
		slider.value_changed.connect(func(value: float) -> void: _atmosphere.set(property, value))
		study.add_child(slider)
		_remember_setting(slider,_atmosphere,property)
	var rays_label := Label.new()
	rays_label.text = "Light shafts · through cloud gaps"
	study.add_child(rays_label)
	var rays := HSlider.new()
	rays.max_value = 3.0
	rays.step = 0.05
	rays.value = 1.0
	rays.focus_mode = Control.FOCUS_NONE
	rays.value_changed.connect(_atmosphere.set_rays)
	study.add_child(rays)
	_remember_setting(rays,_atmosphere,"ray_strength")
	var gust := Button.new()
	gust.text = "Send a gust · G"
	gust.focus_mode = Control.FOCUS_NONE
	gust.pressed.connect(func() -> void: _atmosphere.send_gust(target))
	study.add_child(gust)
	_time_label = Label.new()
	_time_label.text = "Time of day"
	study.add_child(_time_label)
	_time_slider = HSlider.new()
	_time_slider.max_value = 1.0
	_time_slider.step = 0.001
	_time_slider.value = _celestial.phase
	_time_slider.focus_mode = Control.FOCUS_NONE
	_time_slider.value_changed.connect(_celestial.set_phase)
	study.add_child(_time_slider)
	var cycle := CheckBox.new()
	_cycle_toggle = cycle
	cycle.text = "Day/night cycle · N advances sun"
	cycle.focus_mode = Control.FOCUS_NONE
	cycle.toggled.connect(func(value: bool) -> void: _celestial.cycling = value)
	study.add_child(cycle)
	_remember_setting(cycle,_celestial,"cycling")
	var night_label := Label.new()
	night_label.text = "Night fill · landscape visibility"
	study.add_child(night_label)
	var night_fill := HSlider.new()
	night_fill.max_value = 1.5
	night_fill.step = 0.05
	night_fill.value = _celestial.night_fill
	night_fill.focus_mode = Control.FOCUS_NONE
	night_fill.value_changed.connect(func(value: float) -> void:
		_celestial.night_fill = value
		_celestial.update_rig())
	study.add_child(night_fill)
	_remember_setting(night_fill,_celestial,"night_fill")
	var aurora_label := Label.new()
	aurora_label.text = "Aurora · visible at night"
	study.add_child(aurora_label)
	var aurora := HSlider.new()
	_aurora_slider = aurora
	aurora.max_value = 2.0
	aurora.step = 0.05
	aurora.value = _celestial.aurora_strength
	aurora.focus_mode = Control.FOCUS_NONE
	aurora.value_changed.connect(func(value: float) -> void: _celestial.aurora_strength = value)
	study.add_child(aurora)
	_remember_setting(aurora,_celestial,"aurora_strength")
	var rainbow := CheckBox.new()
	rainbow.text = "Hold rainbow · opposite the sun"
	rainbow.focus_mode = Control.FOCUS_NONE
	rainbow.toggled.connect(func(value: bool) -> void: _celestial.rainbow_strength = 1.0 if value else 0.0)
	study.add_child(rainbow)
	_remember_setting(rainbow,_celestial,"rainbow_strength")
	var face_rainbow := Button.new()
	face_rainbow.text = "Face rainbow · look opposite the sun"
	face_rainbow.focus_mode = Control.FOCUS_NONE
	face_rainbow.pressed.connect(_face_rainbow)
	study.add_child(face_rainbow)
	var weather := OptionButton.new()
	_weather_selector = weather
	for title in ["Clear weather", "Rain", "Storm", "Snow", "Fair", "Overcast", "Mist", "Autumn"]:
		weather.add_item(title)
	weather.focus_mode = Control.FOCUS_NONE
	weather.item_selected.connect(_precipitation.set_weather)
	study.add_child(weather)
	var autumn_label := Label.new()
	autumn_label.text = "Autumn · gold and rust"
	study.add_child(autumn_label)
	_autumn_slider = HSlider.new()
	_autumn_slider.max_value = 1.0
	_autumn_slider.step = 0.01
	_autumn_slider.focus_mode = Control.FOCUS_NONE
	_autumn_slider.value_changed.connect(func(value: float) -> void: _precipitation.surface_weather.target_autumn = value)
	study.add_child(_autumn_slider)
	var cold_label := Label.new()
	cold_label.text = "Cold · sustained cold freezes water"
	study.add_child(cold_label)
	_cold_slider = HSlider.new()
	_cold_slider.min_value = 0.0
	_cold_slider.max_value = 1.0
	_cold_slider.step = 0.01
	_cold_slider.focus_mode = Control.FOCUS_NONE
	_cold_slider.value_changed.connect(func(value: float) -> void: _precipitation.cold_override = value)
	study.add_child(_cold_slider)
	var cloud_label := Label.new()
	cloud_label.text = "Cloud cover · overrides weather preset"
	study.add_child(cloud_label)
	var clouds := HSlider.new()
	_cloud_slider = clouds
	clouds.max_value = 1.0
	clouds.step = 0.02
	clouds.value = 0.06
	clouds.focus_mode = Control.FOCUS_NONE
	clouds.value_changed.connect(func(value: float) -> void: _precipitation.cloud_override = value)
	study.add_child(clouds)
	var sound := CheckBox.new()
	var ambience := CheckBox.new()
	ambience.text = "Wind, rain and waterfall sound"
	ambience.button_pressed = true
	ambience.focus_mode = Control.FOCUS_NONE
	ambience.toggled.connect(func(value: bool) -> void: _ambient_audio.muted = not value)
	study.add_child(ambience)
	_remember_setting(ambience,_ambient_audio,"muted",true)
	var ambient_volume := HSlider.new()
	ambient_volume.max_value = 1.0
	ambient_volume.step = 0.05
	ambient_volume.value = _ambient_audio.volume
	ambient_volume.focus_mode = Control.FOCUS_NONE
	ambient_volume.tooltip_text = "Ambient sound volume"
	ambient_volume.value_changed.connect(func(value: float) -> void: _ambient_audio.volume = value)
	study.add_child(ambient_volume)
	_remember_setting(ambient_volume,_ambient_audio,"volume")
	sound.text = "Thunder sound"
	sound.button_pressed = true
	sound.focus_mode = Control.FOCUS_NONE
	sound.toggled.connect(func(value: bool) -> void: _thunder_audio.muted = not value)
	study.add_child(sound)
	_remember_setting(sound,_thunder_audio,"muted",true)
	var strike_button := Button.new()
	strike_button.text = "Lightning · L"
	strike_button.focus_mode = Control.FOCUS_NONE
	strike_button.pressed.connect(func() -> void: _lightning.strike(Vector2(target.x, target.z), camera.global_position))
	study.add_child(strike_button)
	var tremor := Button.new()
	tremor.text = "Ground tremor · T"
	tremor.focus_mode = Control.FOCUS_NONE
	tremor.pressed.connect(func() -> void: _tremor.add(0.7))
	study.add_child(tremor)
	var fireflies := CheckBox.new()
	var frogs := Button.new()
	frogs.text = "Startle pond frogs · F"
	frogs.focus_mode = Control.FOCUS_NONE
	frogs.pressed.connect(_frog_motion.startle)
	study.add_child(frogs)
	fireflies.text = "Invite fireflies · even in daylight"
	fireflies.focus_mode = Control.FOCUS_NONE
	fireflies.toggled.connect(func(value: bool) -> void: _fireflies.called = value)
	study.add_child(fireflies)
	var startle_birds := Button.new()
	startle_birds.text = "Startle birds"
	startle_birds.focus_mode = Control.FOCUS_NONE
	startle_birds.pressed.connect(func() -> void: _bird_flight.startle(target))
	study.add_child(startle_birds)
	var full_flock := CheckButton.new()
	full_flock.text = "Call the full flock"
	full_flock.focus_mode = Control.FOCUS_NONE
	full_flock.toggled.connect(func(value: bool) -> void: _bird_flight.swell_target = 1.0 if value else 0.0)
	study.add_child(full_flock)
	var encounter := Button.new()
	encounter.text = "Bigfoot encounter · B"
	encounter.disabled = not _bigfoot.available
	encounter.focus_mode = Control.FOCUS_NONE
	encounter.pressed.connect(_summon_bigfoot)
	study.add_child(encounter)
	var quality := OptionButton.new()
	_quality = quality
	quality.add_item("Beauty · ambient occlusion and glow")
	quality.add_item("Balanced · lighter post-processing")
	quality.focus_mode = Control.FOCUS_NONE
	quality.disabled = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	quality.tooltip_text = "Use run-fidelity.command for Forward+ ambient occlusion and glow." if quality.disabled else ""
	quality.item_selected.connect(_set_quality)
	study.add_child(quality)
	# Balanced by default: on this scene ambient occlusion and glow change no
	# pixel at any hour (the reference materials take no ambient light and
	# nothing crosses the glow threshold) yet cost about 3 ms a frame at
	# native resolution. Beauty stays selectable for scenes that use them.
	_set_quality(1)
	# The panel hugs its controls and stops short of the palette, so the column
	# never overlaps the bar and inspecting leaves no empty column behind.
	var fit_column := func() -> void:
		var window := get_window()
		var bar := NativeBuildPalette.BAR_HEIGHT if _chunk_editor.active else 0.0
		var room := clampf(window.size.y/window.content_scale_factor-56.0-bar, 180.0, 940.0)
		scroll.custom_minimum_size.y = minf(column.get_combined_minimum_size().y, room)
	fit_column.call()
	column.minimum_size_changed.connect(fit_column)
	get_window().size_changed.connect(fit_column)
	_chunk_editor.active_changed.connect(func(_enabled: bool) -> void: fit_column.call())

func _set_wind(value: float) -> void:
	_wind = value
	if _atmosphere != null:
		_atmosphere.strength = value

func _set_quality(index: int) -> void:
	_quality.select(index)
	_environment.ssao_enabled = index == 0
	_environment.glow_enabled = index == 0

func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

func _add_fall_mist(geometry: Node3D) -> void:
	var fall := geometry.get_node_or_null("strand") as MeshInstance3D
	if fall == null:
		return
	var vertices: PackedVector3Array = fall.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bottom := INF
	var top := -INF
	for point in vertices:
		bottom = minf(bottom, point.y)
		top = maxf(top, point.y)
	var fall_material := fall.mesh.surface_get_material(0) as ShaderMaterial
	fall_material.set_shader_parameter("height_range", Vector2(bottom, top))
	var center := Vector3.ZERO
	var count := 0
	for point in vertices:
		if point.y < bottom + 0.15:
			center += point
			count += 1
	center = fall.transform * (center / maxi(count, 1))
	fall.set_meta("impact", center)
	var cloud = preload("res://studies/fall_mist.gd").new()
	cloud.name = "WaterfallSpray"
	add_child(cloud)
	cloud.setup(JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/fall-mist.json")))

func _film_frame() -> void:
	if _recorded_frames >= _film_frames:
		return
	if not _film_directory.is_empty():
		var result := get_viewport().get_texture().get_image().save_jpg(_film_directory.path_join("%04d.jpg" % _recorded_frames), 0.94)
		if result != OK:
			get_tree().quit(result)
	_recorded_frames += 1
	if _recorded_frames == _film_frames:
		print("Film motion time: ", _motion_time, " cloud drift: ", _atmosphere._cloud_drift)
		get_tree().quit()

func _summon_bigfoot(fog := false) -> void:
	if (_chunk_editor.data.blank and not _bigfoot.authored_tree) or not _bigfoot.available or _growth.terrain < 0.995 or _growth.foliage < 0.7:
		return
	_bigfoot.summon(fog)
	target = _bigfoot._frame.to_global(Vector3(1.05, 1.5, 1.05)) if fog else _bigfoot.focus_point()
	distance = 6.5
	yaw = _bigfoot._frame.rotation.y
	polar = 1.25
	_update_camera()
	_bigfoot.advance(0.0, false, camera.global_position)

func _apply_mood(index: int) -> void:
	var moods := [
		{"phase":0.64,"cloud":0.16,"mist":0.18,"haze":0.12,"wind":0.5,"aurora":0.0},
		{"phase":0.285,"cloud":0.25,"mist":0.85,"haze":0.28,"wind":0.25,"aurora":0.0},
		{"phase":0.02,"cloud":0.04,"mist":0.14,"haze":0.05,"wind":0.35,"aurora":1.35},
	]
	var mood: Dictionary = moods[clampi(index,0,moods.size()-1)]
	_precipitation.set_weather(0,true)
	_precipitation.cloud_override = mood.cloud
	_atmosphere.strength = mood.wind
	_atmosphere.set_fog(mood.mist)
	_atmosphere.set_haze(mood.haze)
	_celestial.cloud = mood.cloud
	_celestial.aurora_strength = mood.aurora
	_celestial.cycling = false
	_celestial.set_phase(mood.phase)
	_cycle_toggle.set_pressed_no_signal(false)
	_aurora_slider.set_value_no_signal(mood.aurora)
	_weather_selector.select(0)

func _remember_setting(control: Control, object: Object, property: String, negate := false) -> void:
	_saved_setting_controls.append({"control":control,"object":object,"property":property,"negate":negate})

func _sync_saved_controls() -> void:
	for setting in _saved_setting_controls:
		var value: Variant = setting.object.get(setting.property)
		if setting.control is BaseButton:
			setting.control.set_pressed_no_signal(not bool(value) if setting.negate else bool(value))
		elif setting.control is Range:
			setting.control.set_value_no_signal(float(value))
