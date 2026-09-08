extends PanelContainer
## Persistent actions on the left; the catalog supplies the item held by Place.
const FAMILIES := {
	"Select":["select"],
	"Sculpt":["raise","lower","smooth","flatten","mountain","ground","range"],
	"Paint":["meadow","grass","blades","paint","erase"],
	"Place":["tree","rock","flower","arch","bigfoot_tree","assets"],
	"Water":["pond","waterfall"],
}
var palette: NativeBuildPalette
var editor: NativeChunkEditor
var buttons := {}
var remembered := {"Select":"select","Sculpt":"raise","Paint":"meadow","Place":"tree","Water":"pond"}
var family := "Sculpt"
var item := "tree"
var context := VBoxContainer.new()
var title := Label.new()
var hint := Label.new()
var choices := OptionButton.new()
var trail := CheckButton.new()
var dig := Button.new()

func setup(owner_palette: NativeBuildPalette) -> void:
	palette = owner_palette
	editor = palette.editor
	name = "ToolRail"
	position = Vector2(20,92)
	custom_minimum_size = Vector2(174,0)
	add_theme_stylebox_override("panel",palette._stone_style(Color(0.12,0.14,0.14,0.94),16))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	add_child(stack)
	var heading := Label.new()
	heading.text = "GARDEN TOOLS"
	heading.add_theme_font_size_override("font_size",11)
	heading.add_theme_color_override("font_color",Color("d8b26f"))
	stack.add_child(heading)
	for key: String in FAMILIES:
		var button := Button.new()
		button.text = key
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.y = 36
		button.pressed.connect(activate.bind(key))
		stack.add_child(button)
		buttons[key] = button
	stack.add_child(HSeparator.new())
	stack.add_child(context)
	title.add_theme_font_size_override("font_size",14)
	context.add_child(title)
	choices.custom_minimum_size.x = 150
	choices.item_selected.connect(func(index: int) -> void: palette._choose(FAMILIES[family][index]))
	context.add_child(choices)
	var browse := Button.new()
	browse.name = "ChooseItem"
	browse.text = "Choose item…"
	browse.pressed.connect(func() -> void:
		palette.open_palette()
		if family == "Paint": palette._browse("Flora")
		elif family == "Water": palette._browse("Water"))
	context.add_child(browse)
	trail.text = "Drag to paint"
	trail.focus_mode = Control.FOCUS_NONE
	trail.toggled.connect(func(enabled: bool) -> void:
		editor.finish_stroke()
		editor.placement_trail = enabled
		sync())
	context.add_child(trail)
	dig.text = "Dig a hollow"
	dig.pressed.connect(func() -> void: palette._choose("lower"))
	context.add_child(dig)
	var tune := Button.new()
	tune.name = "Settings"
	tune.text = "Settings"
	tune.pressed.connect(func() -> void: palette._details.visible = not palette._details.visible)
	context.add_child(tune)
	hint.custom_minimum_size.x = 150
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size",11)
	hint.modulate.a = 0.7
	context.add_child(hint)
	sync()

func activate(key: String) -> void:
	if key == "Place":
		if item == "bigfoot": palette._take_special(item)
		else: palette._choose(item)
	else: palette._choose(remembered[key])

func sync() -> void:
	var id := editor.catalog_asset if editor.mode == "assets" else editor.mode
	if palette._placing == "bigfoot": id = "bigfoot"
	for key: String in FAMILIES:
		if editor.mode in FAMILIES[key]: family = key
	if id == "bigfoot": family = "Place"
	remembered[family] = editor.mode
	if family == "Place": item = id
	for key: String in buttons: buttons[key].set_pressed_no_signal(key == family)
	title.text = ("Item · " if family == "Place" else "Tool · ")+palette._title(id)
	choices.clear()
	choices.visible = family in ["Sculpt","Paint","Water"]
	for tool: String in FAMILIES[family]: choices.add_item(palette._title(tool))
	var index: int = FAMILIES[family].find(editor.mode)
	if index >= 0: choices.select(index)
	trail.visible = editor.trail_available() and id != "bigfoot"
	trail.set_pressed_no_signal(editor.placement_trail)
	dig.visible = id == "pond"
	if id == "bigfoot": hint.text = "Click once to place. Choosing Bigfoot again moves him."
	elif editor.trail_available(): hint.text = "Hold and drag. One stroke, one undo. Esc to select." if editor.placement_trail else "Click to stamp. Your item stays selected."
	elif id == "pond": hint.text = "Dig a hollow, then return to Water. Hover to preview the shoreline."
	elif family == "Select": hint.text = "Click to select. Drag to move. Delete to remove."
	elif id in ["ground","range"]: hint.text = "Use Settings to form the whole landscape."
	elif family in ["Sculpt","Paint"]: hint.text = "Hold and drag to brush. Right drag to orbit."
	else: hint.text = "Click to place again. Esc returns to Select."
	context.get_node("Settings").visible = editor.mode != "select" and id != "bigfoot"
	context.get_node("ChooseItem").visible = family in ["Place","Paint","Water"]
	size.y = 0
	fit.call_deferred()

func fit() -> void:
	var available := get_viewport_rect().size.y-112.0
	var height := maxf(get_combined_minimum_size().y,1.0)
	scale = Vector2.ONE*minf(1.0,available/height)
