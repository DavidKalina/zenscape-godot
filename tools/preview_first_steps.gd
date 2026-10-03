extends SceneTree
## Dev-only: the first-steps card (scripts/first_steps_card.gd) over a dark
## stand-in for the world, with the real roll, foot, materials bar and almanac
## so its pointing can be seen, to look at by eye. Windowed, by hand only:
##   godot --path . --script tools/preview_first_steps.gd
## Every 4 s the current step is marked done, so the card walks its six steps
## and its last card; a few seconds after that it restarts. Pointing prints.
## No hand is routing presses here, so Skip does nothing; nothing is saved.
const Card = preload("res://scripts/first_steps_card.gd")
const FirstSteps = preload("res://scripts/first_steps.gd")
const Roll = preload("res://scripts/tool_roll.gd")
const Tray = preload("res://scripts/materials_tray.gd")
const Almanac = preload("res://scripts/almanac.gd")
const Foot = preload("res://scripts/tool_foot.gd")
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
	var model := FirstSteps.new()
	model.settings_path = ""
	root.add_child.call_deferred(model)
	var roll := Roll.new()
	var tray := Tray.new()
	var almanac := Almanac.new()
	almanac.settings_path = ""
	var foot := Foot.new()
	foot.setup(roll,null)
	var card: Control = Card.new()
	for piece: Control in [roll,tray,almanac,foot,card]: root.add_child.call_deferred(piece)
	var pieces := {"roll":roll,"tray":tray,"almanac":almanac,"foot":foot}
	card.pointing_changed.connect(func(piece: String, id: String) -> void:
		print("pointing at: %s %s" % [piece,id])
		for key: String in pieces: pieces[key].nudge(id if key == piece else ""))
	card.ready.connect(func() -> void:
		almanac.setup(null,null)
		card.setup(null,model)
		for piece: Control in [roll,tray,almanac,card]: piece.want(true))
	model.finished.connect(func() -> void:
		print("finished")
		create_timer(14.0).timeout.connect(model.restart))
	var timer := Timer.new()
	timer.wait_time = 4.0
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		if not model.current().is_empty(): model.mark(model.current()))
	root.add_child.call_deferred(timer)
