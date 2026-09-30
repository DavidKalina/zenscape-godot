extends HBoxContainer
## The Lantern hint line: "DRAG raise land · SHIFT DRAG the other way · [ ] size".
## Set `text` to a plain hint in the brush registry's form ("Drag to raise
## land  ·  Shift-drag lowers") and each segment's leading key becomes a
## small-caps key cap. `text` reads back the plain hint, so probes that read
## the glass palette's hint read this one the same way.
##
## `plain` (the hand scheme): no key caps and no capitals, just the sentence,
## quiet, in the notices' face ("Hold in the sky to call a cloud").
const Style = preload("res://scripts/lantern_style.gd")
## Leading phrases that are keys or gestures, longest first.
const KEYS := ["Shift-click","Shift-drag","Right-drag","Double-click","Shift [ ]","[ ]","Drag","Press","Click","Hold","Release","Tab","Esc","P","M","1"]
const FILLERS := ["to ","for "]
const SEPARATOR := "  ·  "
## The plain line's alpha: a murmur, not a label.
const PLAIN_ALPHA := 0.82

## Set before `text`: one quiet sentence instead of key caps.
var plain := false

var text := "":
	set(value):
		if value == text: return
		text = value
		_build()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",7)
	alignment = BoxContainer.ALIGNMENT_CENTER

## [key, words] for one segment; key is "" when it opens with none.
static func split(segment: String) -> Array:
	var trimmed := segment.strip_edges()
	for key: String in KEYS:
		if trimmed.to_lower().begins_with(key.to_lower()) and (trimmed.length() == key.length() or trimmed[key.length()] == " "):
			var rest := trimmed.substr(key.length()).strip_edges()
			for filler: String in FILLERS:
				if rest.begins_with(filler): rest = rest.substr(filler.length())
			return [key.replace("-"," "),rest]
	return ["",trimmed]

func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if plain:
		if text.strip_edges().is_empty(): return
		var line := Label.new()
		line.text = SEPARATOR.join(Array(text.split("·",false)).map(func(part: String) -> String: return part.strip_edges()))
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		Style.style_label(line,15,Color(Style.LIGHT,PLAIN_ALPHA),true)
		add_child(line)
		return
	var first := true
	for segment: String in text.split("·",false):
		if segment.strip_edges().is_empty(): continue
		if not first: add_child(Style.label("·",13,Color(Style.LIGHT,0.6)))
		first = false
		var parts := split(segment)
		if not str(parts[0]).is_empty(): add_child(_cap(parts[0]))
		if not str(parts[1]).is_empty(): add_child(Style.label(parts[1],13))

func _cap(key: String) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Style.SHADE,0.42)
	style.border_color = Color(Style.LIGHT,0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 0
	style.content_margin_bottom = 1
	style.anti_aliasing = true
	cap.add_theme_stylebox_override("panel",style)
	cap.add_child(Style.label(key,12))
	return cap
