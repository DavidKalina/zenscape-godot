extends Node3D
## Bare sandbox for the rope crossing: a forty-five metre chasm between two
## level cliff tops, thirty metres of fall under it, and nothing else in frame
## to flatter it.
##
## W holds a gust on the deck, D drops a five kilogram weight at mid-span,
## drag orbits and the wheel zooms. `--still=<path.png>` lets the rope settle
## for five seconds, saves a frame and quits; `--view=` picks the framing,
## `--gust` captures mid-sway, `--drop` throws the weight in first, and
## `--drop-height=<m>` sets the chasm's far rim below the near one.

const GAP := 45.0
const CLIFF := 60.0
## yaw, pitch, distance, height above the anchor line.
const VIEWS := {
	"three-quarter": [0.80, 0.27, 54.0, -2.2],
	"low-oblique": [1.17, 0.05, 31.0, -1.4],
	"gust": [0.95, 0.27, 46.0, -1.0],
	"side": [0.0, 0.05, 52.0, -2.2],
	"top": [0.0, 1.35, 52.0, 0.0],
}

var bridge: SuspensionBridge
var _yaw := 0.80
var _pitch := 0.34
var _distance := 70.0
var _height := 3.0
var _view := "three-quarter"
var _gusting := false
var _dropping := false
var _weight: RigidBody3D = null
var _age := 0.0
var _still := ""
var _captured := false
var _drop_height := 0.0
@onready var _pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D

func _ready() -> void:
	var view := "three-quarter"
	var size := Vector2i(1600, 1000)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--still="): _still = argument.split("=", true, 1)[1]
		elif argument.begins_with("--view="): view = argument.split("=", true, 1)[1]
		elif argument.begins_with("--drop-height="): _drop_height = float(argument.split("=", true, 1)[1])
		elif argument.begins_with("--size="):
			var pair := argument.split("=", true, 1)[1].split("x")
			if pair.size() == 2: size = Vector2i(int(pair[0]), int(pair[1]))
		elif argument == "--gust": _gusting = true
		elif argument == "--drop": _dropping = true
	get_window().size = size
	_build_cliffs()
	bridge = SuspensionBridge.new()
	bridge.name = "Bridge"
	add_child(bridge)
	bridge.setup(Transform3D(Basis(), Vector3(-GAP * 0.5, 0.0, 0.0)), Transform3D(Basis(), Vector3(GAP * 0.5, -_drop_height, 0.0)), {"seed": 11})
	_view = view
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
		bridge.apply_wind(Vector3.FORWARD, 2.4 + 1.8 * sin(_age * 1.1) + 0.7 * sin(_age * 3.1))
	if _dropping and _age > 1.4:
		_dropping = false
		_weight = bridge.drop_weight(0.5)
	if _view in ["deck", "low-oblique"]: _frame_camera()
	if _still != "" and not _captured and _age > 5.0:
		_captured = true
		_capture()

## Two framings are staged rather than orbited: head height in the middle of
## the crossing looking at the far anchor, and a perch on the near cliff top.
func _frame_camera() -> void:
	if _view == "deck":
		_stage(bridge.deck_point(0.5) + Vector3(0.0, 1.7, 0.0), bridge.deck_point(0.985) + Vector3(0.0, 1.2, 0.0))
		return
	if _view == "low-oblique":
		_stage(Vector3(-GAP * 0.5 - 11.0, 5.5, 16.0), bridge.deck_point(0.5) + Vector3(0.0, 1.4, 0.0))
		return
	_pivot.position = Vector3(0.0, -_drop_height * 0.5 + _height, 0.0)
	_pivot.rotation = Vector3(-_pitch, _yaw, 0.0)
	_camera.rotation = Vector3.ZERO
	_camera.position = Vector3(0.0, 0.0, _distance)

func _stage(eye: Vector3, at: Vector3) -> void:
	_pivot.position = eye
	_pivot.rotation = Vector3.ZERO
	_camera.position = Vector3.ZERO
	_camera.look_at(at)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_yaw -= event.relative.x * 0.006
		_pitch = clampf(_pitch + event.relative.y * 0.005, -0.2, 1.4)
		_frame_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _distance = clampf(_distance * 0.92, 6.0, 400.0)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _distance = clampf(_distance / 0.92, 6.0, 400.0)
		_frame_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W:
			_gusting = not _gusting
			if not _gusting: bridge.apply_wind(Vector3.ZERO, 0.0)
		if event.keycode == KEY_D:
			if is_instance_valid(_weight): _weight.queue_free()
			_weight = bridge.drop_weight(0.5)
		if event.keycode == KEY_C: _view = "three-quarter" if _view == "deck" else "deck"

## Two cliff tops with the chasm between their inner faces.
func _build_cliffs() -> void:
	for side: float in [-1.0, 1.0]:
		var cliff := StaticBody3D.new()
		cliff.name = "Cliff%d" % (0 if side < 0.0 else 1)
		var size := Vector3(26.0, CLIFF, 24.0)
		cliff.position = Vector3(side * (GAP * 0.5 + size.x * 0.5), -CLIFF * 0.5 - (_drop_height if side > 0.0 else 0.0), 0.0)
		var mesh := BoxMesh.new()
		mesh.size = size
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		var rock := StandardMaterial3D.new()
		rock.albedo_color = Color(0.35, 0.40, 0.29)
		rock.roughness = 1.0
		rock.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		visual.material_override = rock
		cliff.add_child(visual)
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		cliff.add_child(collision)
		add_child(cliff)

func _capture() -> void:
	# Offscreen captures must also complete when macOS occludes the window.
	RenderingServer.viewport_set_update_mode(get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_UPDATE_ALWAYS)
	for frame in range(3): await get_tree().process_frame
	RenderingServer.force_draw(false)
	DirAccess.make_dir_recursive_absolute(_still.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(_still)
	print("Bridge still: ", _still, " result=", result, " sag=%.2f rebuild=%.0fus" % [bridge.sag_depth(), bridge.rebuild_cost_usec()])
	get_tree().quit(0 if result == OK else 1)
