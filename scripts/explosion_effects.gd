extends Node3D
## Shared flash, dust and synthesized blast rumble in world coordinates.
var audio := AudioStreamPlayer.new()
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	_build_audio()

func emit_blast(point: Vector3, radius: float) -> void:
	_flash(to_local(point),radius)
	audio.pitch_scale = lerpf(1.3,0.75,clampf((radius-1.3)/3.2,0,1))
	audio.play()

func emit_rockfall(point: Vector3, radius: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	for i in range(3):
		var dust := _mesh(self,sphere,Color("a99d89"),to_local(point)+Vector3(rng.randf_range(-0.3,0.3),0,rng.randf_range(-0.3,0.3)))
		var material := dust.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.3
		dust.scale = Vector3.ONE*0.15
		var tween := dust.create_tween().set_parallel(true)
		tween.tween_property(dust,"scale",Vector3.ONE*clampf(radius,0.5,1.4),1.6)
		tween.tween_property(dust,"position",dust.position+Vector3(rng.randf_range(-0.5,0.5),0.8,rng.randf_range(-0.5,0.5)),1.6)
		tween.tween_property(material,"albedo_color:a",0.0,1.8)
		tween.chain().tween_callback(dust.queue_free)
	audio.pitch_scale = 0.6
	audio.play(0.08)

func clear() -> void:
	audio.stop()
	for child in get_children():
		if child != audio: child.queue_free()

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

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	return result

func _mesh(parent: Node3D, shape: Mesh, color: Color, offset := Vector3.ZERO) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = shape
	visual.material_override = _material(color)
	# Translucent flash and dust must not throw opaque shadows over the hillside.
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.position = offset
	parent.add_child(visual)
	return visual

func _flash(point: Vector3, blast_radius: float) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var flash := _mesh(self, sphere, Color("ffb74b"), point)
	var material := flash.material_override as StandardMaterial3D
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash.scale = Vector3.ONE * 0.05
	var tween := flash.create_tween().set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * blast_radius, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(flash.queue_free)
	for i in range(10):
		var dust := _mesh(self, sphere, Color("b3a18a"), point + Vector3(rng.randf_range(-1, 1), 0.3, rng.randf_range(-1, 1)))
		var dust_material := dust.material_override as StandardMaterial3D
		dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dust_material.albedo_color.a = 0.35
		dust.scale = Vector3.ONE * 0.25
		var drift := dust.create_tween().set_parallel(true)
		drift.tween_property(dust, "position", dust.position + Vector3(rng.randf_range(-2, 2), 2, rng.randf_range(-2, 2)), 1.5)
		drift.tween_property(dust, "scale", Vector3.ONE * blast_radius * 0.6, 1.5)
		drift.tween_property(dust_material, "albedo_color:a", 0.0, 1.5)
		drift.chain().tween_callback(dust.queue_free)
