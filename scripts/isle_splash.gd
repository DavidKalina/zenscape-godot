extends CanvasLayer
## An isle's card, shown as the plane locks onto it (scripts/isle_lock.gd):
## its name in the title's inscription (Newsreader, wide-tracked, gilt, as
## scripts/title_screen.gd sets ZENSCAPE), a line of what it is, and what
## there is to find on it with how much of it has been found, in small caps
## over a hairline with a diamond at its middle. Nothing boxes it: it is
## carved onto the sky, the name settling from wide tracking as it fades in,
## the hairline drawn out from its middle. It holds HOLD seconds, then fades.
##
## `show_card(card)` with {"name", "epithet", "finds": [[label, found, of],
## ...]}. Lengths are pixels of a 1080-high screen, scaled.

const DISPLAY = preload("res://assets/fonts/newsreader-latin.woff2")
const READING = preload("res://assets/fonts/spectral-latin-400.woff2")
const GILT = preload("res://shaders/title_gilt.gdshader")
const INK := Color("e3d7bd")
const HAIRLINE := Color(0.890,0.843,0.741,0.7)
const SHADOW := Color(0.02,0.03,0.05,0.45)
## Seconds: fading in, holding, fading out; the tracking settling in.
const IN := 1.1
const HOLD := 5.0
const OUT := 1.6
## The name's tracking at rest and as it starts (design px), and its size.
const TRACK := 14.0
const TRACK_FROM := 30.0
const NAME_SIZE := 64
## Where the card's middle sits (share of the screen's height from the top).
const MIDDLE := 0.25

var card := {}
var age := INF
var _frame: Control
var _name: Label
var _name_font: FontVariation
var _epithet: Label
var _finds: Label
var _tag: Label
var _caps: FontVariation

func _ready() -> void:
	layer = 4
	_frame = Control.new()
	_frame.name = "Card"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.draw.connect(_draw_rules)
	add_child(_frame)
	_name_font = FontVariation.new()
	_name_font.base_font = DISPLAY
	_name_font.variation_opentype = {"wght":500.0}
	_caps = FontVariation.new()
	_caps.base_font = DISPLAY
	_caps.variation_opentype = {"wght":500.0}
	_tag = _label(_caps)
	_name = _label(_name_font)
	var gilt := ShaderMaterial.new()
	gilt.shader = GILT
	_name.material = gilt
	_epithet = _label(READING)
	_finds = _label(_caps)
	visible = false

func _label(font: Font) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font",font)
	label.add_theme_color_override("font_shadow_color",SHADOW)
	_frame.add_child(label)
	return label

## Shows `card` from the start.
func show_card(with: Dictionary) -> void:
	card = with
	age = 0.0
	_tag.text = str(card.get("tag","AN ISLE ADRIFT")).to_upper()
	_name.text = str(card.get("name","")).to_upper()
	_epithet.text = str(card.get("epithet",""))
	var parts := PackedStringArray()
	for find: Array in card.get("finds",[]):
		parts.append("%s   %d / %d" % [str(find[0]).to_upper(),int(find[1]),int(find[2])])
	_finds.text = "     ◆     ".join(parts)
	visible = true
	_layout(0.0)

## Lets it fade from where it is (the lock let go).
func fade() -> void:
	if age < IN+HOLD: age = maxf(IN+HOLD,IN+HOLD+OUT*(1.0-_shown()))

## How far shown it is now (0..1).
func _shown() -> float:
	if age == INF: return 0.0
	if age < IN: return smoothstep(0.0,1.0,age/IN)
	if age < IN+HOLD: return 1.0
	return 1.0-smoothstep(0.0,1.0,(age-IN-HOLD)/OUT)

func showing() -> bool:
	return visible

func _process(delta: float) -> void:
	if not visible: return
	age += delta
	if age >= IN+HOLD+OUT:
		visible = false
		age = INF
		return
	_layout(clampf(age/IN,0.0,1.0))

## The card laid out `t` of the way in (0..1).
func _layout(t: float) -> void:
	var view := _frame.get_viewport_rect().size
	var px := view.y/1080.0
	var settle := 1.0-pow(1.0-t,3.0)
	var middle := view.y*MIDDLE
	_place(_tag,_caps,13,3.0+4.0*(1.0-settle),middle-62.0*px,px)
	_place(_name,_name_font,NAME_SIZE,lerpf(TRACK_FROM,TRACK,settle),middle-36.0*px,px)
	(_name.material as ShaderMaterial).set_shader_parameter("glyph_scale",px*NAME_SIZE/58.0)
	_place(_epithet,null,22,0.0,middle+52.0*px,px)
	_place(_finds,_caps,13,3.0,middle+92.0*px,px)
	var shown := _shown()
	_tag.modulate = Color(1,1,1,0.62*shown)
	_name.modulate = Color(1,1,1,shown)
	_epithet.modulate = Color(1,1,1,0.85*smoothstep(0.35,1.0,t)*shown)
	_finds.modulate = Color(1,1,1,0.75*smoothstep(0.6,1.0,t)*shown)
	_frame.queue_redraw()

func _place(label: Label, font: FontVariation, font_size: int, track: float, top: float, px: float) -> void:
	if font != null: font.spacing_glyph = roundi(track*px)
	label.add_theme_font_size_override("font_size",maxi(1,roundi(font_size*px)))
	label.add_theme_color_override("font_color",INK if label != _name else Color.WHITE)
	label.add_theme_constant_override("shadow_offset_y",roundi(2.0*px))
	label.add_theme_constant_override("shadow_outline_size",roundi(6.0*px))
	label.position = Vector2(0.0,roundf(top))
	label.size = Vector2(_frame.get_viewport_rect().size.x,0.0)

## The hairline under the name, drawn out from its diamond.
func _draw_rules() -> void:
	if not visible: return
	var view := _frame.get_viewport_rect().size
	var px := view.y/1080.0
	var t := clampf(age/IN,0.0,1.0)
	var reach := 260.0*px*smoothstep(0.15,1.0,t)
	var y := roundf(view.y*MIDDLE+40.0*px)
	var mid := view.x*0.5
	var line := Color(HAIRLINE,HAIRLINE.a*_shown())
	var gap := 12.0*px
	if reach > gap:
		_frame.draw_line(Vector2(mid-reach,y),Vector2(mid-gap,y),line,maxf(1.0,px))
		_frame.draw_line(Vector2(mid+gap,y),Vector2(mid+reach,y),line,maxf(1.0,px))
	var d := 5.0*px*smoothstep(0.0,0.4,t)
	_frame.draw_colored_polygon(PackedVector2Array([Vector2(mid,y-d),Vector2(mid+d,y),Vector2(mid,y+d),Vector2(mid-d,y)]),line)
