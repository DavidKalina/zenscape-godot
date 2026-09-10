extends Node3D
## Bare sandbox for the rope bridge: two island slabs nine metres apart at
## slightly different heights and nothing else to hide a bad plank behind.
##
## W holds a gust on the deck, D drops a five kilogram sphere onto it, drag
## orbits and the wheel zooms. `--still=<path.png>` lets the deck settle for
## three seconds, saves a frame and quits; `--view=` picks the framing and
## `--gust` captures mid-sway and `--drop` throws the weight in first, which is
## how the reference stills were taken.

const SPAN := Vector2(-4.5, 4.5)
const VIEWS := {
	"three-quarter": [0.82, 0.45, 11.2, 0.1],
	"low": [1.24, 0.13, 8.6, 0.75],
	"gust": [1.05, 0.24, 9.0, 0.35],
	"side": [0.0, 0.08, 12.5, 0.1],
	"top": [0.0, 1.35, 12.0, 0.0],
}

var bridge: SuspensionBridge
var _yaw := 0.78
var _pitch := 0.40
var _distance := 13.5
var _height := 0.2
var _gusting := false
var _dropping := false
var _age := 0.0
var _still := ""
var _captured := false
@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D

func _ready() -> void:
	var view := "three-quarter"
	var size := Vector2i(1600, 1000)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--still="): _still = argument.split("=", true, 1)[1]
		elif argument.begins_with("--view="): view = argument.split("=", true, 1)[1]
		elif argument.begins_with("--size="):
			var pair := argument.split("=", true, 1)[1].split("x")
			if pair.size() == 2: size = Vector2i(int(pair[0]), int(pair[1]))
		elif argument == "--gust": _gusting = true
		elif argument == "--drop": _dropping = true
	get_window().size = size
	_build_islands()
	var a := Transform3D(Basis(), Vector3(SPAN.x, 0.0, 0.0))
	var b := Transform3D(Basis(), Vector3(SPAN.y, -0.8, 0.0))  # A drop across the gap.
	bridge = SuspensionBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	bridge.setup(a, b, {"seed": 11})
	var framing: Array = VIEWS.get(view, VIEWS["three-quarter"])
	_yaw = framing[0]
	_pitch = framing[1]
	_distance = framing[2]
	_height = framing[3]
	_frame_camera()
	get_window().title = "ZenScape study · Suspension bridge"

func _process(delta: float) -> void:
	_age += delta
	if _gusting:
		# A gust breathes rather than shoves, so the deck keeps swaying under it.
		bridge.apply_wind(Vector3.FORWARD, 4.0 + 3.0 * sin(_age * 1.6) + 1.2 * sin(_age * 4.3))
	if _dropping and _age > 1.4:
		_dropping = false
		_drop_weight()
	if _still != "" and not _captured and _age > 3.0:
		_captured = true
		_capture()

func _frame_camera() -> void:
	_pivot.position = Vector3((SPAN.x + SPAN.y) * 0.5, -0.4 + _height, 0.0)
	_pivot.rotation = Vector3(-_pitch, _yaw, 0.0)
	_camera.position = Vector3(0.0, 0.0, _distance)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_yaw -= event.relative.x * 0.006
		_pitch = clampf(_pitch + event.relative.y * 0.005, -0.2, 1.4)
		_frame_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _distance = clampf(_distance * 0.92, 2.5, 48.0)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _distance = clampf(_distance / 0.92, 2.5, 48.0)
		_frame_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W:
			_gusting = not _gusting
			if not _gusting: bridge.apply_wind(Vector3.ZERO, 0.0)
		if event.keycode == KEY_D: _drop_weight()

## Two flat slabs with a nine metre gap between their inner faces.
func _build_islands() -> void:
	for side in [-1.0, 1.0]:
		var island := StaticBody3D.new()
		island.name = "Island%d" % (0 if side < 0.0 else 1)
		# Inner faces exactly at the anchors, tops flush with the deck mouths.
		island.position = Vector3(side * (absf(SPAN.y) + 4.0), -0.6 if side < 0.0 else -1.4, 0.0)
		var size := Vector3(8.0, 1.2, 9.0)
		var mesh := BoxMesh.new()
		mesh.size = size
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		var grass := StandardMaterial3D.new()
		grass.albedo_color = Color(0.33, 0.42, 0.26)
		grass.roughness = 1.0
		grass.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		visual.material_override = grass
		island.add_child(visual)
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		island.add_child(collision)
		add_child(island)

func _drop_weight() -> void:
	var ball := RigidBody3D.new()
	ball.mass = 5.0
	ball.collision_layer = 1
	ball.collision_mask = 3
	ball.position = bridge.deck_point(0.5) + Vector3(0.0, 3.0, 0.0)
	var shape := SphereShape3D.new()
	shape.radius = 0.26
	var collision := CollisionShape3D.new()
	collision.shape = shape
	ball.add_child(collision)
	var mesh := SphereMesh.new()
	mesh.radius = 0.26
	mesh.height = 0.52
	mesh.radial_segments = 10
	mesh.rings = 5
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.46, 0.46, 0.44)
	stone.roughness = 1.0
	visual.mesh.material = stone
	ball.add_child(visual)
	add_child(ball)

func _capture() -> void:
	# Offscreen captures must also complete when macOS occludes the window.
	RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	for frame in range(3): await get_tree().process_frame
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(_still.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(_still)
	print("Bridge still: ", _still, " result=", result)
	get_tree().quit(0 if result == OK else 1)
