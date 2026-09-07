extends Node3D
## Original rangy rig and peek animation from bigfoot-model.js.
## All targets are world coordinates; each arm solve happens in trunk space.

var joints: Dictionary = {}
var actor: Node3D
var body: Node3D
var trunk: Node3D
var head: Node3D
var coat: ShaderMaterial
const ARMS := [[-1, 9, 11, 13, 14], [1, 31, 33, 35, 36]]
const LEGS := [[-1, 53, 55, 57], [1, 59, 61, 63]]
const GAZE := [[0.0,-0.16,0.035],[1.2,-0.16,0.035],[2.8,-0.67,0.005],[4.6,-0.67,0.005],[6.2,-0.06,0.065],[7.1,-0.06,0.065],[8.8,0.57,-0.025],[10.7,0.57,-0.025],[12.8,-0.16,0.035],[14.0,-0.16,0.035]]

func setup() -> void:
	var imported := preload("res://assets/bigfoot/wanderer.glb").instantiate()
	add_child(imported)
	coat = ShaderMaterial.new()
	coat.shader = preload("res://shaders/reference_surface.gdshader")
	var eyes := ShaderMaterial.new()
	eyes.shader = preload("res://shaders/reference_bigfoot_eyes.gdshader")
	for node in imported.find_children("*", "Node3D", true, false):
		node.rotation_order = EULER_ORDER_XYZ
		var id := int(str(node.name).get_slice("_", 0).trim_prefix("n"))
		joints[id] = node
		node.visible = true
		if node is MeshInstance3D:
			node.material_override = eyes if id in [7, 8] else coat
	actor = joints[0]
	body = joints[1]
	trunk = joints[2]
	head = joints[4]

func set_silhouette(enabled: bool) -> void:
	coat.set_shader_parameter("base_color", Color("626762") if enabled else Color.WHITE)

func _ease(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _gaze(time: float) -> Vector2:
	var t := fposmod(time, 14.0)
	for i in range(1, GAZE.size()):
		if GAZE[i][0] >= t:
			var a: Array = GAZE[i - 1]
			var b: Array = GAZE[i]
			return Vector2(a[1], a[2]).lerp(Vector2(b[1], b[2]), _ease((t - a[0]) / (b[0] - a[0])))
	return Vector2(-0.16, 0.035)

func pose(kind: String, time: float, camera_position := Vector3(0, 2.2, 8), anchor: Dictionary = {}, foot_heights: Dictionary = {}) -> void:
	if kind == "idle":
		time = 0.0
	var weight := 1.0 if kind in ["walk", "stride"] else 0.0
	var gait_time := 0.63 if kind == "stride" else time
	var phase := gait_time / 3.6 * TAU
	var looking := kind == "look"
	var gaze := _gaze(time) if looking else Vector2(-0.16, 0.035)
	var late_yaw := _gaze(maxf(0.0, time - 0.65)).x if looking else -0.16
	var breath := 0.0 if kind in ["idle", "stride"] else sin(time * 1.12)
	actor.position.z = 0.0
	actor.rotation.y = 0.0
	body.position.y = 1.041 + minf(0.0, minf(foot_heights.get(-1, 0.0), foot_heights.get(1, 0.0))) + weight * 0.008 * cos(phase * 2.0)
	body.rotation.y = weight * sin(phase) * 0.025 - (1.0 - weight) * 0.025
	trunk.scale.y = 1.0 + breath * 0.003
	trunk.rotation = Vector3(0.13 + breath * 0.004, weight * -sin(phase) * 0.030 + (1.0 - weight) * late_yaw * 0.19, 0.018 + weight * cos(phase) * 0.012 + (1.0 - weight) * late_yaw * 0.012)
	head.position.x = 0.0
	head.rotation = Vector3(0.07 if kind == "glance" else gaze.y, -0.46 if kind == "glance" else gaze.x, -0.035 - (gaze.x * 0.022 if looking else 0.0))
	for arm in ARMS:
		var side: float = arm[0]
		joints[arm[1]].rotation = Vector3(-0.13 + weight * sin(phase) * side * 0.21, (1.0 - weight) * late_yaw * -0.035, side * (0.07 + breath * 0.002))
		joints[arm[2]].rotation = Vector3(-0.15 - weight * (1.0 - sin(phase - 0.25) * side) * 0.035, 0, 0)
		joints[arm[3]].rotation = Vector3(0.07 + weight * sin(phase - 0.6) * side * 0.025, side * -0.15, side * -0.04)
		for finger in range(4):
			joints[arm[4] + finger * 4].rotation.x = 0.0
			joints[arm[4] + finger * 4 + 2].rotation.x = 0.0
	for leg in LEGS:
		var side: int = leg[0]
		var u := fposmod(gait_time / 3.6 + (0.5 if side > 0 else 0.0), 1.0)
		var planted := u < 0.62
		var swing := 0.0 if planted else (u - 0.62) / 0.38
		var z := weight * (0.22 * 3.6 * 0.62) * ((0.5 - u / 0.62) if planted else (-0.5 + _ease(swing))) + (1.0 - weight) * side * 0.035
		var lift := weight * (0.0 if planted else pow(sin(swing * PI), 2.0) * 0.10)
		var down: float = body.position.y - 0.12 - lift - foot_heights.get(side, 0.0)
		var reach := minf(0.959, Vector2(down, z).length())
		var bend := PI - acos(clampf((0.25 + 0.2116 - reach * reach) / 0.46, -1.0, 1.0))
		var offset := acos(clampf((0.25 + reach * reach - 0.2116) / reach, -1.0, 1.0))
		joints[leg[1]].rotation.x = -atan2(z, down) - offset
		joints[leg[2]].rotation.x = bend
		joints[leg[3]].rotation = Vector3(-joints[leg[1]].rotation.x - bend, side * 0.065, 0.0)
	if kind == "peek":
		var t := fposmod(time, 16.0)
		var reach := _ease((t - 1.3) / 1.7) * (1.0 - _ease((t - 11.6) / 1.5))
		var lean := _ease((t - 3.0) / 2.5) * (1.0 - _ease((t - 9.0) / 2.3))
		var notice := _ease((t - 4.8) / 1.0) * (1.0 - _ease((t - 9.4) / 1.0))
		actor.position.z = -0.38 * actor.scale.z
		body.rotation.y = 0.0
		trunk.rotation = Vector3(0.10, -0.05 * lean, 0.012 - 0.62 * lean)
		head.position.x = 0.045 * lean
		var eye_target := trunk.to_local(camera_position) - head.position
		var gaze_yaw := clampf(atan2(eye_target.x, eye_target.z), -0.72, 0.72)
		var gaze_pitch := clampf(-atan2(eye_target.y, Vector2(eye_target.x, eye_target.z).length()), -0.18, 0.20)
		head.rotation = Vector3(lerpf(0.07, gaze_pitch, notice), lerpf(-0.32, gaze_yaw, notice), 0.05 + 0.39 * lean)
		joints[9].rotation.z = lerpf(-0.07, 0.18, lean)
		_hold_tree(reach, anchor)

func _hold_tree(amount: float, anchor: Dictionary) -> void:
	var shoulder: Node3D = joints[31]
	var elbow: Node3D = joints[33]
	var wrist: Node3D = joints[35]
	var target_world: Vector3 = anchor.get("grip", Vector3(0.455, 1.67, 0.294) * actor.scale.x)
	var target_local := trunk.to_local(target_world)
	var direction := target_local - shoulder.position
	var upper := 0.57 * 1.15
	var lower_axis := Vector3(0, -0.47 * 1.15, 0.014)
	var lower := lower_axis.length()
	var reach := clampf(direction.length(), absf(upper - lower) + 0.001, upper + lower - 0.001)
	direction = direction.normalized()
	var pole := Vector3(0.45, -0.90, -0.10)
	pole = (pole - direction * direction.dot(pole)).normalized()
	var along := (upper * upper - lower * lower + reach * reach) / (2.0 * reach)
	var elbow_point := direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along))
	var upper_aim := Quaternion(Vector3.DOWN, elbow_point.normalized())
	direction = (upper_aim.inverse() * (target_local - shoulder.position - elbow_point)).normalized()
	var lower_aim := Quaternion(lower_axis.normalized(), direction)
	shoulder.quaternion = shoulder.quaternion.slerp(upper_aim, amount)
	elbow.quaternion = elbow.quaternion.slerp(lower_aim, amount)
	var grip_rotation: Quaternion = anchor.get("rotation", Basis.from_euler(Vector3(0, -PI / 3.0, PI / 2.0), EULER_ORDER_YXZ).get_rotation_quaternion())
	# Column normalization matches the source decomposition, but breathing
	# shear can leave its quaternion non-unit after a parent rotation.
	var wrist_aim := (_source_world_rotation(elbow.global_basis).normalized().inverse() * grip_rotation.normalized()).normalized()
	wrist.quaternion = wrist.quaternion.slerp(wrist_aim, amount)
	for finger in range(4):
		joints[36 + finger * 4].rotation.x = -0.16 * amount
		joints[38 + finger * 4].rotation.x = -0.30 * amount

# Three.js decomposes a scaled matrix by normalizing its columns. Preserve that
# convention for the breathing trunk, whose nonuniform scale introduces shear.
func _source_world_rotation(value: Basis) -> Quaternion:
	var m := Basis(value.x.normalized(), value.y.normalized(), value.z.normalized())
	var trace := m.x.x + m.y.y + m.z.z
	if trace > 0.0:
		var s := 0.5 / sqrt(trace + 1.0)
		return Quaternion((m.y.z - m.z.y) * s, (m.z.x - m.x.z) * s, (m.x.y - m.y.x) * s, 0.25 / s)
	if m.x.x > m.y.y and m.x.x > m.z.z:
		var s := 2.0 * sqrt(1.0 + m.x.x - m.y.y - m.z.z)
		return Quaternion(0.25 * s, (m.y.x + m.x.y) / s, (m.z.x + m.x.z) / s, (m.y.z - m.z.y) / s)
	if m.y.y > m.z.z:
		var s := 2.0 * sqrt(1.0 + m.y.y - m.x.x - m.z.z)
		return Quaternion((m.y.x + m.x.y) / s, 0.25 * s, (m.z.y + m.y.z) / s, (m.z.x - m.x.z) / s)
	var s := 2.0 * sqrt(1.0 + m.z.z - m.x.x - m.y.y)
	return Quaternion((m.z.x + m.x.z) / s, (m.z.y + m.y.z) / s, 0.25 * s, (m.x.y - m.y.x) / s)
