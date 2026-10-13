extends CanvasLayer
## The run's few words on the screen (docs/design/roguelike/
## stakes-experiment.md), quiet: a small readout in the corner (the layer,
## the runes carried), a veil over everything (dark for a fall, warm for
## the gate), a caption that comes and goes ("Layer 2"), and the card a
## fall ends on. Drawn only; scripts/roguelike/run_loop.gd says what.
const INK := Color("fbf6ea")
const DARK := Color(0.035,0.04,0.055)
const WARM := Color(1.0,0.93,0.8)

var readout: Label
var veil: ColorRect
var caption: Label
var card: VBoxContainer
var card_main: Label
var card_hint: Label

func _init() -> void:
	name = "RunOverlay"
	layer = 60

func _ready() -> void:
	veil = ColorRect.new()
	veil.name = "Veil"
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(DARK,0.0)
	add_child(veil)
	readout = _label(15,Color(INK,0.72))
	readout.name = "Readout"
	readout.position = Vector2(18.0,14.0)
	add_child(readout)
	caption = _label(24,Color(INK,0.0))
	caption.name = "Caption"
	caption.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.anchor_left = 0.0
	caption.anchor_right = 1.0
	caption.offset_left = 0.0
	caption.offset_right = 0.0
	caption.offset_top = 0.0
	caption.anchor_top = 0.28
	caption.anchor_bottom = 0.28
	add_child(caption)
	card = VBoxContainer.new()
	card.name = "Card"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_constant_override("separation",26)
	card.visible = false
	add_child(card)
	card_main = _label(22,Color(INK,0.9))
	card_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(card_main)
	card_hint = _label(14,Color(INK,0.45))
	card_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(card_hint)

func _label(size: int, colour: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",colour)
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,0.5))
	l.add_theme_constant_override("line_spacing",6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func set_veil(colour: Color, alpha: float) -> void:
	veil.color = Color(colour,clampf(alpha,0.0,1.0))

func set_caption(text: String, alpha: float) -> void:
	caption.text = text
	caption.add_theme_color_override("font_color",Color(INK,clampf(alpha,0.0,1.0)*0.85))

func show_card(main: String, hint: String) -> void:
	card_main.text = main
	card_hint.text = hint
	card.visible = true

func hide_card() -> void:
	card.visible = false

func set_hint(hint: String) -> void:
	card_hint.text = hint
