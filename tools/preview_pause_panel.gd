extends SceneTree
## Dev-only: the pause panel (scripts/pause_panel.gd) over a dark stand-in for
## the world, to look at by eye. Windowed, by hand only:
##   godot --path . --script tools/preview_pause_panel.gd
## Signals print; after Resume it opens again a moment later. The status
## swaps between "Keeping…" and "Kept safe · 4 minutes ago" every 3 s.
const Pause = preload("res://scripts/pause_panel.gd")
const Worlds = preload("res://scripts/worlds_style.gd")

func _initialize() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("5b6572"),Worlds.PAGE_DARK])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5,0.0)
	texture.fill_to = Vector2(0.5,1.0)
	var backdrop := TextureRect.new()
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	root.add_child.call_deferred(backdrop)
	backdrop.set_anchors_preset.call_deferred(Control.PRESET_FULL_RECT)
	var panel: Control = Pause.new()
	root.add_child.call_deferred(panel)
	panel.resumed.connect(func() -> void:
		print("resumed")
		create_timer(1.2).timeout.connect(panel.open.bind("The quiet plain")))
	panel.copy_requested.connect(func(copy_name: String, carry_on: bool) -> void: print("copy_requested: %s, carry on %s" % [copy_name,carry_on]))
	panel.settings_requested.connect(func() -> void: print("settings_requested"))
	panel.title_requested.connect(func() -> void: print("title_requested"))
	panel.ready.connect(panel.open.bind("The quiet plain"))
	var keeping := [false]
	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		keeping[0] = not keeping[0]
		var now := Time.get_unix_time_from_system()
		panel.set_status(keeping[0],now-240.0,now))
	root.add_child.call_deferred(timer)
