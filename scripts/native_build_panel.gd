class_name NativeBuildPanel
extends VBoxContainer
## The global widgets for the chunk editor: entering and leaving Build, the
## history, the files and the status line. Every per-tool control, and the sky
## itself, lives on the build palette, which reads its metadata off the editor.
var editor: NativeChunkEditor
var _tools := VBoxContainer.new()
var _toggle := Button.new()
var _status := Label.new()

## Take an editor that has already been set up and build its controls.
func attach(target: NativeChunkEditor) -> void:
	editor = target
	editor.status_changed.connect(_on_status_changed)
	editor.active_changed.connect(_on_active_changed)
	_build_controls()

func _build_controls() -> void:
	_toggle.text = "Build this chunk"
	_toggle.toggle_mode = true
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.toggled.connect(editor.set_active)
	add_child(_toggle)
	add_child(_tools)
	_tools.visible = false
	var flat := Button.new()
	flat.text = "Start flat · clear this chunk"
	flat.focus_mode = Control.FOCUS_NONE
	flat.pressed.connect(editor.start_flat)
	_tools.add_child(flat)
	var history := HBoxContainer.new()
	for entry: Array in [["Undo",editor.undo],["Redo",editor.redo],["Save",editor.save_garden],["Open",editor.open_garden]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		history.add_child(button)
	_tools.add_child(history)
	_status.text = "Left drag paints · Click places · Right drag orbits\n1-4 tools · [ ] brush size · Shift [ ] strength"
	_status.add_theme_font_size_override("font_size",12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0,34)
	_tools.add_child(_status)

func _on_status_changed(text: String) -> void:
	_status.text = text

func _on_active_changed(enabled: bool) -> void:
	_toggle.set_pressed_no_signal(enabled)
	_toggle.text = "Inspect this chunk" if enabled else "Build this chunk"
	_tools.visible = enabled
