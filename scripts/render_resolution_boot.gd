extends Node
## Draws every scene's 3D at the kept render resolution cap from boot
## (scripts/render_resolution.gd): the root window outlives scene changes, so
## attaching it once covers studies that never ask. Headless runs keep the
## window's own resolution, so tests see the scale only when they set it.

func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	preload("res://scripts/render_resolution.gd").attach(get_tree().root)
