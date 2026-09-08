class_name NativeSelectionPanel
extends PanelContainer
## Inspect the authored record in hand. Placement defaults stay independent.
const Pose = preload("res://scripts/native_object_pose.gd")
var editor: NativeChunkEditor
var _title := Label.new()
var _hint := Label.new()
var _body := VBoxContainer.new()
var _stack := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _fit_queued := false
var _details := GridContainer.new()
var _more := Button.new()
var _tint := ColorPickerButton.new()
var _tint_row := HBoxContainer.new()
var _fields := {}
var _syncing := false
var _color_editing := false
var _spin_editing := false

func attach(target: NativeChunkEditor) -> void:
	editor = target
	name = "SelectionPanel"
	custom_minimum_size.x = 332.0
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -344.0
	offset_right = -12.0
	offset_top = -490.0
	offset_bottom = -210.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055,0.075,0.085,0.97)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel",style)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.add_theme_constant_override("separation",8)
	_scroll.add_child(_stack)
	_stack.minimum_size_changed.connect(_fit)
	get_viewport().size_changed.connect(_fit)
	_title.add_theme_font_size_override("font_size",18)
	_stack.add_child(_title)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_color_override("font_color",Color("b8c7bd"))
	_stack.add_child(_hint)
	_stack.add_child(_body)
	var basics := GridContainer.new()
	basics.columns = 2
	basics.add_theme_constant_override("h_separation",8)
	_body.add_child(basics)
	_field(basics,"angle","Rotation",-180,180,1,"°")
	_field(basics,"scale","Size",0.1,5.0,0.05,"×")
	_tint_row.add_theme_constant_override("separation",8)
	_body.add_child(_tint_row)
	var tint_label := Label.new()
	tint_label.text = "Color"
	tint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tint_row.add_child(tint_label)
	_tint.custom_minimum_size = Vector2(68,28)
	_tint.edit_alpha = false
	_tint_row.add_child(_tint)
	_tint.color_changed.connect(_color_changed)
	_tint.popup_closed.connect(_color_closed)
	_tint.pressed.connect(func() -> void:
		if not _color_editing:
			_color_editing = true
			editor.begin_selection_edit())
	var reset := Button.new()
	reset.text = "Original"
	reset.tooltip_text = "Restore this object's original colors"
	reset.pressed.connect(func() -> void: editor.update_selected({"tint":""}))
	_tint_row.add_child(reset)
	_more.text = "Shape & elevation ▸"
	_more.toggle_mode = true
	_more.toggled.connect(func(open: bool) -> void:
		_details.visible = open
		_more.text = "Shape & elevation ▾" if open else "Shape & elevation ▸"
		_fit())
	_body.add_child(_more)
	_details.columns = 2
	_details.add_theme_constant_override("h_separation",8)
	_details.visible = false
	_body.add_child(_details)
	_field(_details,"width","Width",0.1,5.0,0.05,"×")
	_field(_details,"height","Height",0.1,5.0,0.05,"×")
	_field(_details,"depth","Depth",0.1,5.0,0.05,"×")
	_field(_details,"offset","Elevation",-5,10,0.1,"m")
	_field(_details,"pitch","Tilt X",-180,180,1,"°")
	_field(_details,"roll","Tilt Z",-180,180,1,"°")
	var actions := HBoxContainer.new()
	_body.add_child(actions)
	for action in ["Duplicate","Delete"]:
		var button := Button.new()
		button.name = action
		button.text = action
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(editor.duplicate_selected if action == "Duplicate" else editor.delete_selected)
		actions.add_child(button)
	editor.selection_changed.connect(_selection_changed)
	editor.tool_changed.connect(func(_mode: String) -> void: _refresh())
	editor.active_changed.connect(func(_active: bool) -> void: _refresh())
	_refresh()

## Public lookup also lets the native UI tests exercise the actual controls.
func field(key: String) -> SpinBox:
	return _fields.get(key)

func _field(parent: GridContainer, key: String, title: String, low: float, high: float, step: float, suffix: String) -> void:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size",12)
	row.add_child(label)
	var control := SpinBox.new()
	control.name = key.capitalize()
	control.min_value = low
	control.max_value = high
	control.step = step
	control.suffix = suffix
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	_fields[key] = control
	control.value_changed.connect(_value_changed.bind(key))
	# SpinBox arrow holds and vertical drags form a single undo gesture.
	control.gui_input.connect(_spin_input)
	control.get_line_edit().gui_input.connect(_spin_input)

func _spin_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not _spin_editing:
			_spin_editing = true
			editor.begin_selection_edit()
		elif not event.pressed:
			_finish_spin()

func _input(event: InputEvent) -> void:
	# Release can land outside the field that began a hold or vertical drag.
	if _spin_editing and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_spin()

func _finish_spin() -> void:
	if _spin_editing:
		_spin_editing = false
		editor.end_selection_edit()

func _selection_changed(_id: int) -> void:
	_refresh()

func _refresh() -> void:
	visible = editor.active and editor.mode == "select"
	var item: Dictionary = editor.selected_object()
	_syncing = true
	_body.visible = not item.is_empty()
	_title.text = "Select a piece" if item.is_empty() else str(item.asset).replace("_"," ").capitalize()
	_hint.text = "Click a placed tree, rock or flower to make it your own." if item.is_empty() else "Drag the selected piece to move it."
	if not item.is_empty():
		var pose: Dictionary = item.get("pose",{})
		var basis := Pose.decode_basis(pose) if not pose.is_empty() else Basis(Vector3.UP,float(item.angle)).scaled_local(Vector3.ONE*float(item.scale))
		var euler := basis.orthonormalized().get_euler()
		var dimensions := basis.get_scale()/float(item.scale)
		_fields.angle.set_value_no_signal(wrapf(rad_to_deg(euler.y),-180,180))
		_fields.scale.set_value_no_signal(float(item.scale))
		_fields.width.set_value_no_signal(dimensions.x)
		_fields.height.set_value_no_signal(dimensions.y)
		_fields.depth.set_value_no_signal(dimensions.z)
		_fields.pitch.set_value_no_signal(rad_to_deg(euler.x))
		_fields.roll.set_value_no_signal(rad_to_deg(euler.z))
		_fields.offset.set_value_no_signal(Pose.decode_offset(pose) if not pose.is_empty() else 0.0)
		var supports_pose: bool = item.asset not in ["arch","bigfoot_tree","waterfall"]
		_more.visible = supports_pose
		_details.visible = supports_pose and _more.button_pressed
		_tint_row.visible = supports_pose
		_tint.color = Pose.decode_tint(item.tint).linear_to_srgb() if item.has("tint") else Color.WHITE
	_syncing = false
	_fit()

func _fit() -> void:
	# Containers recalculate child minimums after visibility and wrapping change.
	if not _fit_queued:
		_fit_queued = true
		_apply_fit.call_deferred()

func _apply_fit() -> void:
	_fit_queued = false
	if not is_inside_tree(): return
	var parent_height := get_viewport_rect().size.y
	if get_parent() is Control:
		parent_height = get_parent().size.y
	var bottom := -NativeBuildPalette.BAR_HEIGHT-12.0
	var available := maxf(24.0,parent_height+bottom-12.0)
	var content_height := _stack.get_combined_minimum_size().y+24.0
	# Never let minimum-size changes push the panel into the palette. Advanced
	# controls scroll on shorter windows, keeping actions reachable.
	offset_bottom = bottom
	offset_top = bottom-minf(content_height,available)

func _value_changed(value: float, key: String) -> void:
	if _syncing: return
	var item: Dictionary = editor.selected_object()
	if item.is_empty(): return
	var pose: Dictionary = item.get("pose",{})
	var basis := Pose.decode_basis(pose) if not pose.is_empty() else Basis(Vector3.UP,float(item.angle)).scaled_local(Vector3.ONE*float(item.scale))
	var offset := Pose.decode_offset(pose) if not pose.is_empty() else 0.0
	var changes := {}
	match key:
		"angle":
			changes["angle"] = deg_to_rad(value)
			if not pose.is_empty():
				var angles := basis.orthonormalized().get_euler()
				angles.y = deg_to_rad(value)
				basis = Basis.from_euler(angles).scaled_local(basis.get_scale())
		"scale":
			changes["scale"] = value
			basis = basis.scaled_local(Vector3.ONE*(value/float(item.scale)))
		"offset": offset = value
		"width", "height", "depth":
			var dimensions := basis.get_scale()
			dimensions[["width","height","depth"].find(key)] = value*float(item.scale)
			basis = basis.orthonormalized().scaled_local(dimensions)
		"pitch", "roll":
			var angles := basis.orthonormalized().get_euler()
			angles.x = deg_to_rad(value) if key == "pitch" else angles.x
			angles.z = deg_to_rad(value) if key == "roll" else angles.z
			basis = Basis.from_euler(angles).scaled_local(basis.get_scale())
	if not pose.is_empty() or key not in ["angle","scale"]:
		changes["pose"] = Pose.make(basis,offset)
	editor.update_selected(changes)

func _color_changed(color: Color) -> void:
	if not _syncing: editor.update_selected({"tint":Pose.encode_tint(color.srgb_to_linear())})

func _color_closed() -> void:
	if _color_editing:
		_color_editing = false
		editor.end_selection_edit()
