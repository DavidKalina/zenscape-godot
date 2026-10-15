extends Control
## [items] The items carried (docs/design/roguelike/items-contract.md), a
## plain row of names under the hearts, riding the readout's alpha. A
## stand-in: icons and a find's swell come later.
const ItemCatalog = preload("res://scripts/roguelike/item_catalog.gd")
const Splash = preload("res://scripts/isle_splash.gd")

## Design px: the row's top-left, its type.
const AT := Vector2(28.0,92.0)
const TYPE := 15

var _label: Label

func _init() -> void:
	name = "Items"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_label.position = AT
	_label.add_theme_font_override("font",Splash.READING)
	_label.add_theme_font_size_override("font_size",TYPE)
	_label.add_theme_color_override("font_color",Color("e8dcc0"))
	_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.6))
	_label.add_theme_constant_override("shadow_offset_x",1)
	_label.add_theme_constant_override("shadow_offset_y",1)
	add_child(_label)

func show_items(ids: Array[StringName]) -> void:
	var names := PackedStringArray()
	for id in ids: names.append(ItemCatalog.title(id))
	_label.text = "  ·  ".join(names)
