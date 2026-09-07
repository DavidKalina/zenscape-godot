extends Node3D

var yaw := 0.65
var pitch := 0.80
var navigating := false
@onready var camera: Camera3D = $Camera3D

func _ready() -> void:
	rotation = Vector3(-pitch, yaw, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			navigating = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera.size = clampf(camera.size * 0.92, 3.0, 55.0)
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera.size = clampf(camera.size / 0.92, 3.0, 55.0)
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			var scale_factor := camera.size / get_viewport().get_visible_rect().size.y
			position += (-camera.global_basis.x * event.relative.x + camera.global_basis.y * event.relative.y) * scale_factor
			position = position.clamp(Vector3(-10, -2, -10), Vector3(10, 6, 10))
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			yaw -= event.relative.x * 0.006
			pitch = clampf(pitch + event.relative.y * 0.005, 0.35, 1.35)
			rotation = Vector3(-pitch, yaw, 0.0)

func _process(_delta: float) -> void:
	# Releases over the UI still end camera navigation.
	navigating = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)
