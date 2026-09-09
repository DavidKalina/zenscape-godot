extends Node3D
## Isolated explosion study. Nothing is saved into the authored garden.
const Blast = preload("res://scripts/terrain_blast.gd")
const MAX_CHARGES := 12
const MAX_DEBRIS := 100
@onready var terrain: TerrainView = $Terrain
@onready var camera: Camera3D = $OrbitCamera/Camera3D
var ground_shape := CollisionShape3D.new()
var props: Array[RigidBody3D] = []
var debris: Array[RigidBody3D] = []
var charges: Array[Dictionary] = []
var effects := Node3D.new()
var original_heights := PackedFloat32Array()
var original_meadow := PackedFloat32Array()
var rng := RandomNumberGenerator.new()
var radius := 2.6
var blast_count := 0
var pending_reset := false
var pending_detonation := false
var pending_point: Variant = null
var status := Label.new()
var power_label := Label.new()
var panel := PanelContainer.new()
var audio := AudioStreamPlayer.new()

func _ready() -> void:
	var data := GardenData.new()
	data.meadow.fill(0.95)
	for z in range(LandscapeData.SIDE):
		for x in range(LandscapeData.SIDE):
			var p := LandscapeData.grid_position(x, z)
			data.heights[z * LandscapeData.SIDE + x] = 0.55 + 2.5 * exp(-p.length_squared() / 65.0) + 0.22 * sin(p.x * 0.7) * cos(p.y * 0.6)
	terrain.data = data
	original_heights = data.heights.duplicate()
	original_meadow = data.meadow.duplicate()
	# Use the shared terrain geometry with a simple, self-contained study material.
	var earth := StandardMaterial3D.new()
	earth.vertex_color_use_as_albedo = true
	earth.roughness = 1.0
	terrain.material_override = earth
	terrain._skirt.material_override = earth
	var ground := StaticBody3D.new()
	ground.name = "DestructibleGround"
	ground.collision_layer = 1
	ground.collision_mask = 2
	add_child(ground)
	ground.add_child(ground_shape)
	add_child(effects)
	$OrbitCamera.position = Vector3(0, 1, 0)
	camera.size = 34.0
	_rebuild_ground()
	_populate()
	_build_ui()
	_build_audio()

func _build_audio() -> void:
	# Short synthesized rumble: no imported sound asset or external dependency.
	var samples := PackedByteArray()
	var sample_rate := 22050
	samples.resize(sample_rate * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 730
	var filtered := 0.0
	for i in range(sample_rate):
		var time := float(i) / sample_rate
		filtered = lerpf(filtered, noise.randf_range(-1, 1), 0.18)
		var value := (filtered * 0.8 + sin(TAU * (65 * time - 20 * time * time)) * 0.3) * exp(-time * 7) * minf(time * 300, 1)
		samples.encode_s16(i * 2, int(clampf(value, -1, 1) * 26000))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = sample_rate
	sound.data = samples
	audio.stream = sound
	audio.volume_db = -9
	add_child(audio)

func _rebuild_ground() -> void:
	terrain.rebuild()
	ground_shape.shape = terrain.mesh.create_trimesh_shape()

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	return result

func _mesh(parent: Node3D, shape: Mesh, color: Color, offset := Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = shape
	visual.material_override = _material(color)
	visual.position = offset
	parent.add_child(visual)
	return visual

func _body(point: Vector3, size: Vector3, mass_value: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = mass_value
	body.collision_layer = 2
	body.collision_mask = 3
	body.continuous_cd = true
	body.linear_damp = 0.15
	body.angular_damp = 0.3
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	add_child(body)
	body.position = point
	return body

func _populate() -> void:
	rng.seed = 90210
	for i in range(48):
		var p := Vector2(rng.randf_range(-10.5, 10.5), rng.randf_range(-10.5, 10.5))
		var tree := i % 3 != 0
		var size := rng.randf_range(0.65, 1.15)
		var extent := Vector3(0.48, 2.8, 0.48) * size if tree else Vector3(1.0, 0.75, 0.85) * size
		var body := _body(Vector3(p.x, terrain.data.height_at(p) + extent.y * 0.5 + 0.02, p.y), extent, 2.5 if tree else 4.0)
		body.freeze = true
		body.rotation.y = rng.randf_range(0, TAU)
		if tree:
			var trunk := CylinderMesh.new()
			trunk.top_radius = 0.12 * size
			trunk.bottom_radius = 0.19 * size
			trunk.height = extent.y
			trunk.radial_segments = 7
			_mesh(body, trunk, Color("72523a"))
			for tier in range(3):
				var crown := CylinderMesh.new()
				crown.top_radius = 0.0
				crown.bottom_radius = (1.0 - tier * 0.19) * size
				crown.height = 1.5 * size
				crown.radial_segments = 7
				_mesh(body, crown, Color("527859").lightened(tier * 0.055), Vector3(0, (0.1 + tier * 0.52) * size, 0))
		else:
			var rock := SphereMesh.new()
			rock.radius = extent.x * 0.5
			rock.height = extent.y
			rock.radial_segments = 7
			rock.rings = 4
			_mesh(body, rock, Color("929388"))
		props.append(body)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(panel)
	panel.position = Vector2(24, 24)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192b2bed")
	style.set_corner_radius_all(14)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "BLAST GARDEN"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A little controlled chaos."
	column.add_child(subtitle)
	column.add_child(power_label)
	var slider := HSlider.new()
	slider.min_value = 1.3
	slider.max_value = 4.5
	slider.step = 0.1
	slider.value = radius
	slider.custom_minimum_size.x = 270
	slider.value_changed.connect(func(value: float) -> void:
		radius = value
		_update_status())
	column.add_child(slider)
	for entry in [["Detonate all  ·  SPACE", func() -> void: pending_detonation = true],
		["Restore landscape  ·  R", func() -> void: pending_reset = true]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 40
		button.pressed.connect(entry[1])
		button.focus_mode = Control.FOCUS_NONE
		column.add_child(button)
	var help := Label.new()
	help.text = "Click ground to plant a charge\nShift + click for an instant blast\nRight drag · orbit    Wheel · zoom\nMiddle drag · pan"
	help.add_theme_font_size_override("font_size", 14)
	column.add_child(help)
	column.add_child(status)
	_update_status()

func _update_status() -> void:
	power_label.text = "Blast radius  ·  %.1f m" % radius
	status.text = "%d / %d charges   ·   %d blasts" % [charges.size(), MAX_CHARGES, blast_count]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R: pending_reset = true
		if event.keycode == KEY_SPACE: pending_detonation = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit: Variant = terrain.ray_hit(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
		if hit != null:
			if event.shift_pressed: pending_point = {"point": hit, "radius": radius}
			else: plant_charge(hit, radius)

func plant_charge(point: Vector3, blast_radius: float) -> void:
	if charges.size() >= MAX_CHARGES: return
	var marker := Node3D.new()
	effects.add_child(marker)
	marker.position = point
	var bomb := SphereMesh.new()
	bomb.radius = 0.23
	bomb.height = 0.46
	_mesh(marker, bomb, Color("ea683d"), Vector3(0, 0.25, 0))
	var ring := ImmediateMesh.new()
	ring.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(64):
		for step in [i, i + 1]:
			var angle: float = TAU * step / 64.0
			var p := Vector2(point.x, point.z) + Vector2(cos(angle), sin(angle)) * blast_radius
			ring.surface_add_vertex(Vector3(p.x, terrain.data.height_at(p) + 0.06, p.y) - point)
	ring.surface_end()
	var outline := _mesh(marker, ring, Color("f9ba61"))
	outline.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	charges.append({"point": point, "radius": blast_radius, "marker": marker})
	_update_status()

func _physics_process(_delta: float) -> void:
	# Shape replacement and impulses happen outside physics callbacks.
	if pending_reset:
		reset_world()
		pending_reset = false
		pending_detonation = false
		pending_point = null
	if pending_detonation:
		pending_detonation = false
		var batch := charges.duplicate()
		charges.clear()
		for charge in batch:
			charge.marker.queue_free()
			detonate(charge.point, charge.radius)
	if pending_point != null:
		detonate(pending_point.point, pending_point.radius)
		pending_point = null
	for body in props + debris:
		if is_instance_valid(body) and body.position.y < -20:
			body.freeze = true
			body.hide()

func detonate(point: Vector3, blast_radius: float) -> void:
	Blast.carve(terrain.data, Vector2(point.x, point.z), blast_radius)
	_rebuild_ground()
	for body in props + debris:
		if not is_instance_valid(body) or not body.visible: continue
		var kick := Blast.impulse(point, body.position, blast_radius)
		if kick.length_squared() < 0.01: continue
		body.freeze = false
		body.sleeping = false
		body.apply_central_impulse(kick * body.mass)
		body.apply_torque_impulse(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * body.mass * 3.0)
	for i in range(18):
		if debris.size() >= MAX_DEBRIS:
			var oldest: RigidBody3D = debris.pop_front()
			oldest.collision_layer = 0
			oldest.collision_mask = 0
			oldest.queue_free()
		var angle := rng.randf_range(0, TAU)
		var offset := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.2, blast_radius * 0.6)
		var size := rng.randf_range(0.12, 0.32)
		var fragment := _body(point + offset + Vector3.UP * 0.3, Vector3.ONE * size, 0.2)
		fragment.collision_mask = 1
		var chunk := BoxMesh.new()
		chunk.size = Vector3.ONE * size
		_mesh(fragment, chunk, Color("947657"))
		fragment.apply_central_impulse(Blast.impulse(point, fragment.position, blast_radius) * fragment.mass * rng.randf_range(0.5, 1.0))
		debris.append(fragment)
	_flash(point, blast_radius)
	audio.pitch_scale = lerpf(1.3, 0.75, inverse_lerp(1.3, 4.5, blast_radius))
	audio.play()
	blast_count += 1
	_update_status()

func _flash(point: Vector3, blast_radius: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var flash := _mesh(effects, sphere, Color("ffb74b"), point)
	var material := flash.material_override as StandardMaterial3D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.scale = Vector3.ONE * 0.05
	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * blast_radius, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(flash.queue_free)
	for i in range(10):
		var dust := _mesh(effects, sphere, Color("b3a18a"), point + Vector3(rng.randf_range(-1, 1), 0.3, rng.randf_range(-1, 1)))
		var dust_material := dust.material_override as StandardMaterial3D
		dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dust_material.albedo_color.a = 0.35
		dust.scale = Vector3.ONE * 0.25
		var drift := dust.create_tween().set_parallel(true)
		drift.tween_property(dust, "position", dust.position + Vector3(rng.randf_range(-2, 2), 2, rng.randf_range(-2, 2)), 1.5)
		drift.tween_property(dust, "scale", Vector3.ONE * blast_radius * 0.6, 1.5)
		drift.tween_property(dust_material, "albedo_color:a", 0.0, 1.5)
		drift.chain().tween_callback(dust.queue_free)

func reset_world() -> void:
	audio.stop()
	for body in props + debris:
		body.collision_layer = 0
		body.collision_mask = 0
		body.queue_free()
	props.clear()
	debris.clear()
	for child in effects.get_children(): child.queue_free()
	charges.clear()
	terrain.data.heights = original_heights.duplicate()
	terrain.data.meadow = original_meadow.duplicate()
	_rebuild_ground()
	_populate()
	blast_count = 0
	_update_status()
