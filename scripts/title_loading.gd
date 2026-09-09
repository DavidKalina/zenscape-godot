extends CanvasLayer
## A real build veil, without invented percentage progress.
var _label := Label.new()
var _elapsed := 0.0
func _ready() -> void:
	layer = 100
	var backdrop := ColorRect.new()
	backdrop.color = Color("0b0e12")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font",preload("res://assets/fonts/newsreader-latin.woff2"))
	_label.add_theme_font_size_override("font_size",24)
	_label.add_theme_color_override("font_color",Color("e2d0aa"))
	stage("A wilderness is taking shape")
func stage(text: String) -> void:
	_label.text = text
func _process(delta: float) -> void:
	_elapsed += delta
	_label.modulate.a = 0.55+0.35*(0.5+0.5*sin(_elapsed*TAU/3.5))
