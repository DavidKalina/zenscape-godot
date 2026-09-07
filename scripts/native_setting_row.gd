class_name NativeSettingRow
extends RefCounted
## One labelled control for a chunk-editor setting. The build panel and the
## build palette share it, so both read the same bounds, wording and wiring.

## Continuous settings read as a slider under a label that carries the value;
## seeds stay whole numbers on a spin box. Every bound comes from the editor.
static func build(editor: NativeChunkEditor, property: String, compact := false) -> Dictionary:
	var spec := editor.setting_spec(property)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",1)
	var label := Label.new()
	label.add_theme_font_size_override("font_size",11 if compact else 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value: Range
	if spec.whole:
		value = SpinBox.new()
		var row := HBoxContainer.new()
		row.add_child(label)
		row.add_child(value)
		box.add_child(row)
	else:
		value = HSlider.new()
		value.focus_mode = Control.FOCUS_NONE
		box.add_child(label)
		box.add_child(value)
	value.min_value = spec.low
	value.max_value = spec.high
	value.step = spec.step
	value.value = editor.get(property)
	var entry := {"box":box,"control":value,"label":label,"title":spec.title,"unit":spec.unit,"whole":spec.whole,"modes":spec.modes}
	value.value_changed.connect(func(number: float) -> void: editor.set_setting(property,number))
	show_value(entry,float(editor.get(property)))
	return entry

## Restate the title with the value the control now holds.
static func show_value(entry: Dictionary, number: float) -> void:
	var text: String = "%d" % roundi(number) if entry.whole or entry.unit == "°" else String.num(number,2)
	entry.label.text = entry.title if entry.whole else "%s · %s%s" % [entry.title,text,entry.unit]
