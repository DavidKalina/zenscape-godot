extends "res://studies/fidelity.gd"
## Review the authored Wanderer in the source landscape without replacing the encounter.
var reviewed_actor: Node3D

func _ready() -> void:
	super._ready()
	assert(_bigfoot.available, "The fixture needs a Bigfoot clearing")
	_bigfoot.summon()
	_bigfoot.active = false
	_bigfoot.rig.visible = false
	reviewed_actor = load("res://assets/models/zenscape-bigfoot-classic.glb").instantiate()
	_bigfoot._frame.add_child(reviewed_actor)
	# Match the source's mist watching position, clear of the encounter trunk.
	reviewed_actor.position = Vector3(1.05, 0, 1.05)
	reviewed_actor.scale = Vector3.ONE / _bigfoot.PEEK_SCALE
	var coat := ShaderMaterial.new()
	coat.shader = preload("res://shaders/reference_surface.gdshader")
	var eyes := ShaderMaterial.new()
	eyes.shader = preload("res://shaders/reference_bigfoot_eyes.gdshader")
	var eye_count := 0
	for node in reviewed_actor.find_children("*", "MeshInstance3D", true, false):
		var is_eye: bool = "_n7_" in node.name or "_n8_" in node.name
		node.material_override = eyes if is_eye else coat
		if is_eye:
			eye_count += 1
	assert(eye_count == 2, "Both eyes must use the darkness fade shader")
	var player := reviewed_actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.play("Walk")
	player.seek(0.0, true)
	player.pause()
	target = reviewed_actor.global_position + Vector3.UP * 1.45
	distance = 10.0
	polar = PI / 2.0
	yaw = _bigfoot._frame.rotation.y + 0.10
	_update_camera()
	_ui.visible = false
	print("BIGFOOT_LIGHTING_READY eyes=", eye_count, " distance=", distance, " phase=", _celestial.phase)

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _lighting_preset(0.5, 0.05)
			KEY_2: _lighting_preset(0.5, 0.8)
			KEY_3: _lighting_preset(0.0, 0.35)

func _lighting_preset(phase: float, fog: float) -> void:
	_paused = true
	_celestial.set_phase(phase)
	_celestial.update_rig()
	_atmosphere.set_fog(fog)
