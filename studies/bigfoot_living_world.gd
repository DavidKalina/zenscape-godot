extends "res://studies/bigfoot_lair.gd"
## First living-world slice. All behavior uses the same saved controller that
## can resume in the main diorama; these buttons are optional study invitations.
var _mind_panel := Label.new()
var _mind_timer := 0.0
var _study_ui := CanvasLayer.new()

func _ready() -> void:
	super._ready()
	get_window().title = "ZenScape · Bigfoot makes a home"
	routine.living.enabled = true
	brain.scenery_chance = 0.0
	brain._pending_interest.clear()
	_build_living_controls()
	# Begin with an actual home inspection rather than granting omniscient supply
	# knowledge. Gathering and eating become consequential subsequent choices.
	routine._next_action = routine._clock+3.0

func _build_living_controls() -> void:
	_ui.hide()
	var old_column := _life_status.get_parent()
	old_column.hide()
	add_child(_study_ui)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -342
	panel.offset_right = -12
	panel.offset_top = 12
	_study_ui.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055,0.075,0.07,0.9)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",8)
	panel.add_child(column)
	_life_status.reparent(column)
	_life_status.add_theme_font_size_override("font_size",14)
	_life_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_life_status.custom_minimum_size.x = 300
	var menus := HBoxContainer.new()
	column.add_child(menus)
	_menu_button(menus,"View",[["See both stories",_focus_stack],["Find Bigfoot",_focus_bigfoot],["Look into his home",_focus_lair],["Find cave entrance",_focus_cave],["Show walkable ground",_toggle_navigation]])
	_menu_button(menus,"Activities",[["Watch him choose",_watch_choices],["Gather a branch",func() -> void: _invite("gather")],["Bring home a fish",func() -> void: _invite("fish")],["Rest at home",func() -> void: _invite("sleep")],["Check his home",func() -> void: _invite("check_home")],["Make the bed",func() -> void: _invite("tend")],["Eat from his stash",func() -> void: _invite("eat")],["Arrange his stones",func() -> void: _invite("play")],["Visit his quiet spot",func() -> void: _invite("ritual")]])
	_menu_button(menus,"Experiment",[["Disturb the bedding",_disturb_bedding],["Take one stored item",_take_supply],["Generate another cave",_regenerate],["Change cave palette",_change_palette],["Another rock arrangement",_redress]])
	var controls := HBoxContainer.new()
	column.add_child(controls)
	for entry in [["His thoughts",func() -> void: _mind_panel.visible = not _mind_panel.visible],["Build / Enjoy",func() -> void:
		_chunk_editor.set_active(not _chunk_editor.active)
		_ui.visible = _chunk_editor.active]]:
		var button := Button.new()
		button.text = entry[0]
		button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(entry[1])
		controls.add_child(button)
	_mind_panel.name = "BigfootThoughts"
	_mind_panel.add_theme_font_size_override("font_size",13)
	_mind_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mind_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_mind_panel)
	_mind_panel.hide()

func _menu_button(parent: Control, title: String, entries: Array) -> void:
	var menu := MenuButton.new()
	menu.text = title
	menu.add_theme_font_size_override("font_size",14)
	parent.add_child(menu)
	for entry in entries: menu.get_popup().add_item(entry[0])
	menu.get_popup().id_pressed.connect(func(id: int) -> void: entries[id][1].call())

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_H:
		_study_ui.visible = not _study_ui.visible
		get_viewport().set_input_as_handled()
		return
	super._input(event)

func _watch_choices() -> void:
	routine.cancel("watching his choices")
	routine.living.enabled = true
	routine._next_action = routine._clock+1.0

func _focus_lair() -> void:
	if not is_instance_valid(lair): return
	_auto_orbit = false
	target = lair.bed.global_position+Vector3(0,1.1,0)
	distance = 17.0
	yaw = -0.20
	polar = 1.40
	_orbit_delta = Vector2.ZERO
	_pan_delta = Vector2.ZERO
	_update_camera()

func _invite(kind: String) -> void:
	routine.cancel("activity invited")
	if not routine.living.request(kind):
		_invitation_notice = {"tend":"He needs stored branches or leaves, and an unfinished bed.","eat":"His stash needs a fish or fruit first.","play":"His three stones are already arranged."}.get(kind,"He needs a reachable place for that activity.")
		_invitation_notice_time = 5.0

func _disturb_bedding() -> void:
	if lair.disturb_bed():
		_invitation_notice = "The bedding is disturbed. He can notice when he visits."
	else: _invitation_notice = "The bedding is already sparse."
	_invitation_notice_time = 5.0

func _take_supply() -> void:
	var removed: String = lair.remove_one_supply()
	_invitation_notice = "Removed one %s. He can notice when he visits." % removed if not removed.is_empty() else "His stash is empty."
	_invitation_notice_time = 5.0

func _process(delta: float) -> void:
	super._process(delta)
	if routine==null or not is_instance_valid(_mind_panel): return
	var life = routine.living
	if not life.current.is_empty() and _invitation_notice_time<=0.0:
		_life_status.text = "Bigfoot · %s · P pause" % ("paused" if _paused else life.reason)
	_mind_timer -= delta
	if _mind_timer>0.0 or not _mind_panel.visible: return
	_mind_timer = 0.25
	var lines := PackedStringArray(["Hunger %d%%   Tiredness %d%%" % [roundi(life.mind.hunger*100),roundi(life.mind.fatigue*100)],"Bed %d/3   Food %d   Stones %d/3" % [lair.capture_living().bed_stage,lair.food_count(),lair.capture_living().play_stage],"Choosing: "+life.current])
	for option: Dictionary in life.scores.slice(0,4):
		lines.append("%s  %.2f — %s" % [option.kind,option.score,option.reason])
	_mind_panel.text = "\n".join(lines)
