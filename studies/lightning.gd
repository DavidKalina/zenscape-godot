extends Node3D
const Plate = preload("res://scripts/plate.gd")
## Source weather.js strike timing and wind.js downburst, native tube/light rendering.
signal thunder(distance: float, energy: float)
signal struck(point: Vector3)
var clock := 0.0
var next_strike := 6.0
var flash := 0.0
var decay := 13.0
var downburst_enabled := true
var clap := Vector4.ZERO
var _clap_at := -1.0
var _foot := Vector2.ZERO
var _pulses: Array[Vector2] = []
var _thunders: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _ground: RefCounted
var _core: ShaderMaterial
var _glow: ShaderMaterial
var _bolts: Node3D
var _light: OmniLight3D
var strike_count := 0
var thunder_count := 0
var flash_position := Vector3.ZERO

func setup(ground: RefCounted) -> void:
	_ground = ground
	_rng.seed = 7
	_bolts = Node3D.new()
	add_child(_bolts)
	_core = ShaderMaterial.new()
	_core.shader = preload("res://shaders/reference_lightning.gdshader")
	_core.set_shader_parameter("tint", Color("eaf4ff").srgb_to_linear())
	_glow = _core.duplicate()
	_glow.set_shader_parameter("tint", Color("9fc4ff").srgb_to_linear())
	_light = OmniLight3D.new()
	_light.light_color = Color("d8e8ff")
	_light.omni_range = 160.0
	_light.omni_attenuation = 1.6
	# Original boltLight does not cast shadows.
	_light.shadow_enabled = false
	_light.light_energy = 0.0
	add_child(_light)
	_publish()

func strike(at: Vector2, camera_position: Vector3) -> void:
	for child in _bolts.get_children():
		_bolts.remove_child(child)
		child.queue_free()
	var height = _ground.height_at(clampf(at.x, -Plate.HALF, Plate.HALF), clampf(at.y, -Plate.HALF, Plate.HALF))
	var gy: float = height if height != null else 0.15
	var main := _jagged(at, 22.0, gy, 28.0 * 0.22)
	_add_tube(main, 0.055)
	for f in range(1 + int(_rng.randf() * 3)):
		var i := int(_rng.randf() * (main.size() - 4)) + 2
		var a := main[i]
		var drop := (a.y - gy) * (0.25 + _rng.randf() * 0.4)
		_add_tube(_jagged(Vector2(a.x, a.z), a.y, a.y - drop, 28.0 * 0.16), 0.028)
	flash_position = Vector3(at.x, (20.0 + gy) / 2.0, at.y)
	_light.position = Vector3(at.x, gy + (20.0 - gy) * 0.55, at.y)
	_pulses = [Vector2(clock, 1.0)]
	for s in range(1 + int(_rng.randf() * 3)):
		_pulses.append(Vector2(clock + 0.05 + _rng.randf() * 0.35, 0.35 + _rng.randf() * 0.55))
	var distance := camera_position.distance_to(_light.position)
	_thunders.append(Vector3(clock + distance / 28.0, distance, 0.5 + _rng.randf() * 0.5))
	_clap_at = clock + 0.5
	_foot = at
	strike_count += 1
	struck.emit(Vector3(at.x,gy,at.y))
	_update_flash()

func advance(dt: float, paused: bool, storm: float, wind: float, direction: Vector2, camera_position: Vector3) -> void:
	if paused:
		return
	clock += dt
	if storm > 0.01:
		next_strike -= dt * (0.12 + storm * 0.9)
		if next_strike <= 0.0:
			strike(Vector2(_rng.randf_range(-Plate.HALF, Plate.HALF), _rng.randf_range(-Plate.HALF, Plate.HALF)), camera_position)
			next_strike = 5.0 + _rng.randf() * 25.0 * (1.05 - storm)
	var clap_dt := dt
	if _clap_at >= 0.0 and clock >= _clap_at:
		clap_dt = minf(dt, clock - _clap_at)
		if downburst_enabled:
			clap = Vector4(_foot.x, _foot.y, 0.0, 0.9)
		_clap_at = -1.0
	if clap.w > 0.0:
		clap.x += direction.x * (1.6 + 1.9 * wind) * clap_dt
		clap.y += direction.y * (1.6 + 1.9 * wind) * clap_dt
		clap.z += 12.0 * clap_dt
		clap.w *= exp(-clap_dt / 2.6)
		if clap.z > 70.0 or clap.w < 0.02:
			clap.w = 0.0
	for i in range(_thunders.size() - 1, -1, -1):
		if _thunders[i].x <= clock:
			thunder.emit(_thunders[i].y, _thunders[i].z)
			thunder_count += 1
			_thunders.remove_at(i)
	_update_flash()

func _update_flash() -> void:
	flash = 0.0
	for pulse in _pulses:
		if clock >= pulse.x:
			flash += pulse.y * exp(-(clock - pulse.x) * decay)
	if not _pulses.is_empty() and clock - _pulses[0].x > 1.0 + 6.0 / decay:
		_pulses.clear()
	_core.set_shader_parameter("opacity", minf(1.0, flash * 2.2))
	_glow.set_shader_parameter("opacity", minf(0.5, flash * 0.55))
	_bolts.visible = flash > 0.01
	# Native LIGHT_COLOR includes PI; the source point irradiance does not.
	_light.light_energy = flash * (12.0 if "--legacy-flash-light" in preload("res://scripts/launch_args.gd").user_args() else 900.0 / PI)
	_publish()

func _publish() -> void:
	RenderingServer.global_shader_parameter_set("zs_flash", Vector4(flash_position.x, flash_position.y, flash_position.z, flash))
	RenderingServer.global_shader_parameter_set("zs_clap", clap)

func _jagged(at: Vector2, top: float, bottom: float, spread: float) -> PackedVector3Array:
	var points := PackedVector3Array([Vector3(at.x, top, at.y), Vector3(at.x + (_rng.randf() - 0.5) * spread, bottom, at.y + (_rng.randf() - 0.5) * spread)])
	for pass_index in range(4):
		var out := PackedVector3Array([points[0]])
		var amplitude := spread * 0.42 * pow(0.55, pass_index)
		for i in range(points.size() - 1):
			out.append((points[i] + points[i + 1]) * 0.5 + Vector3((_rng.randf() - 0.5) * amplitude, (_rng.randf() - 0.5) * amplitude * 0.25, (_rng.randf() - 0.5) * amplitude))
			out.append(points[i + 1])
		points = out
	return points

# Centripetal Catmull-Rom, matching Three's default curve, extrapolated endpoints.
static func _curve(points: PackedVector3Array, t: float) -> Vector3:
	var index := mini(int(t), points.size() - 2)
	var u := t - index
	var p1 := points[index]
	var p2 := points[index + 1]
	var p0 := points[index - 1] if index > 0 else 2.0 * p1 - p2
	var p3 := points[index + 2] if index + 2 < points.size() else 2.0 * p2 - p1
	var d0 := maxf(pow(p0.distance_squared_to(p1), 0.25), 0.0001)
	var d1 := maxf(pow(p1.distance_squared_to(p2), 0.25), 0.0001)
	var d2 := maxf(pow(p2.distance_squared_to(p3), 0.25), 0.0001)
	var m1 := ((p1 - p0) / d0 - (p2 - p0) / (d0 + d1) + (p2 - p1) / d1) * d1
	var m2 := ((p2 - p1) / d1 - (p3 - p1) / (d1 + d2) + (p3 - p2) / d2) * d1
	return (2*u*u*u - 3*u*u + 1)*p1 + (u*u*u - 2*u*u + u)*m1 + (-2*u*u*u + 3*u*u)*p2 + (u*u*u-u*u)*m2

func _add_tube(points: PackedVector3Array, radius: float) -> void:
	for glow in [false, true]:
		var segments := mini(60 if glow else 120, points.size() * 2)
		var rings: Array[PackedVector3Array] = []
		for i in range(segments + 1):
			var t := float(i) / segments * (points.size() - 1)
			var p := _curve(points, t)
			var tangent := (_curve(points, minf(t + 0.001, points.size() - 1)) - _curve(points, maxf(t - 0.001, 0.0))).normalized()
			var axis := tangent.cross(Vector3.RIGHT).normalized()
			var other := tangent.cross(axis).normalized()
			var ring := PackedVector3Array()
			for j in range(5):
				ring.append(p + (axis * cos(j * TAU / 5) + other * sin(j * TAU / 5)) * radius * (3.4 if glow else 1.0))
			rings.append(ring)
		var vertices := PackedVector3Array()
		for i in range(segments):
			for j in range(5):
				var k := (j + 1) % 5
				vertices.append_array(PackedVector3Array([rings[i][j], rings[i+1][j], rings[i][k], rings[i][k], rings[i+1][j], rings[i+1][k]]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = _glow if glow else _core
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bolts.add_child(node)
