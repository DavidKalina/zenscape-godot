extends CanvasLayer
## An isle's card, shown as the plane locks onto it (scripts/isle_lock.gd),
## centred in the upper part of the screen: its name in the title's
## inscription (Newsreader, tracked, gilt, as scripts/title_screen.gd sets
## ZENSCAPE) over a hairline with a diamond at its middle, a line of what it
## is, and what there is to find on it as one row of slots, a group per
## kind of find with its name and count under it, each slot a faceted
## socket holding its collectible's icon (scripts/hud_icons.gd) as a gem:
## lit where found, a dim shape sunk in the socket where not. Behind it a
## soft dark band (shaders/isle_card_band.gdshader), deepest through its
## middle, thinning out toward both ends, feathered top and bottom, so it
## has no edge.
##
## It fades in with the name settling from wider tracking, the hairline
## drawing out under it and the slots coming up one after another, holds
## HOLD seconds, then fades.
##
## `show_card(card)` with {"name", "epithet", "finds": [[icon id, label,
## found, of], ...]}. Lengths are pixels of a 1080-high screen, scaled.

const DISPLAY = preload("res://assets/fonts/newsreader-latin.woff2")
const READING = preload("res://assets/fonts/spectral-latin-400.woff2")
const GILT = preload("res://shaders/title_gilt.gdshader")
const BAND = preload("res://shaders/isle_card_band.gdshader")
const HudIcons = preload("res://scripts/hud_icons.gd")
const INK := Color("e3d7bd")
const HAIRLINE := Color(0.890,0.843,0.741,0.7)
const SHADOW := Color(0.02,0.03,0.05,0.4)
## The sockets: their well, the rim's lit and shaded edges, an empty gem.
const WELL := Color(0.03,0.04,0.06,0.62)
const RIM_LIT := Color(0.890,0.843,0.741,0.75)
const RIM_SHADE := Color(0.35,0.31,0.25,0.75)
const EMPTY := Color(0.62,0.66,0.72,0.16)
## Seconds: fading in, holding, fading out; each slot after the last.
const IN := 1.1
const HOLD := 5.0
const OUT := 1.6
const SLOT_STAGGER := 0.04
## Design px: the card's top, the name's tracking at rest and as it starts,
## its size; the slots across, the icon in one, the gap between slots and
## between groups (a small diamond in it).
const TOP := 150.0
const TRACK := 12.0
const TRACK_FROM := 26.0
const NAME_SIZE := 50
const SLOT := 28.0
const GEM := 18.0
const SLOT_GAP := 6.0
const GROUP_GAP := 46.0
## The band past the widest line at each end (design px), and how dark.
const BAND_PAST := 200.0
const BAND_STRENGTH := 0.5

var card := {}
var age := INF
## Seconds it holds (HOLD; longer for captures, kit_isle's --card-hold).
var hold := HOLD
var _frame: Control
var _band: ColorRect
var _name: Label
var _name_font: FontVariation
var _epithet: Label
var _tag: Label
var _caps: FontVariation
var _counts: Array[Label] = []
## Each find's icon, lit and as a silhouette, by icon id and size.
var _icons := {}
var _px := 1.0

func _ready() -> void:
	layer = 4
	_frame = Control.new()
	_frame.name = "Card"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	_band = make_band()
	_frame.add_child(_band)
	# The hairline and the slots, over the band, under the text.
	var marks := Control.new()
	marks.name = "Marks"
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marks.draw.connect(_draw_marks.bind(marks))
	_frame.add_child(marks)
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
	visible = false

func _label(font: Font) -> Label:
	var label := Label.new()
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
	for label in _counts: label.queue_free()
	_counts.clear()
	for find: Array in card.get("finds",[]):
		var label := _label(_caps)
		label.text = "%s   %d / %d" % [str(find[1]).to_upper(),int(find[2]),int(find[3])]
		_counts.append(label)
	visible = true
	_layout(0.0)

## Lets it fade from where it is (the lock let go).
func fade() -> void:
	if age < IN+hold: age = maxf(IN+hold,IN+hold+OUT*(1.0-_shown()))

## How far shown it is now (0..1).
func _shown() -> float:
	if age == INF: return 0.0
	if age < IN: return smoothstep(0.0,1.0,age/IN)
	if age < IN+hold: return 1.0
	return 1.0-smoothstep(0.0,1.0,(age-IN-HOLD)/OUT)

func showing() -> bool:
	return visible

func _process(delta: float) -> void:
	if not visible: return
	age += delta
	if age >= IN+hold+OUT:
		visible = false
		age = INF
		return
	_layout(clampf(age/IN,0.0,1.0))

## The card laid out `t` of the way in (0..1).
func _layout(t: float) -> void:
	var view := _frame.get_viewport_rect().size
	_px = view.y/1080.0
	var px := _px
	var settle := 1.0-pow(1.0-t,3.0)
	var y := TOP*px
	_centre(_tag,_caps,11,3.0+3.0*(1.0-settle),y-8.0*px,px)
	_centre(_name,_name_font,NAME_SIZE,lerpf(TRACK_FROM,TRACK,settle),y+14.0*px,px)
	(_name.material as ShaderMaterial).set_shader_parameter("glyph_scale",px*NAME_SIZE/58.0)
	_centre(_epithet,null,19,0.0,y+98.0*px,px)
	for label in _counts: _style(label,_caps,10,2.5,px)
	var groups := _groups()
	for i in range(_counts.size()):
		var w := _counts[i].get_minimum_size().x
		_counts[i].position = Vector2(roundf(groups[i].x+groups[i].y*0.5-w*0.5),roundf(_slots_y()+22.0*px))
	# The band: centred, past the widest line at each end.
	var wide := 0.0
	for label: Label in [_name,_epithet]:
		wide = maxf(wide,_text_width(label))
	if not groups.is_empty(): wide = maxf(wide,groups[-1].x+groups[-1].y-groups[0].x)
	var shown := _shown()
	lay_band(_band,view.x*0.5,y-44.0*px,_slots_y()+78.0*px,wide,px,BAND_STRENGTH*shown)
	_tag.modulate = Color(1,1,1,0.62*shown)
	_name.modulate = Color(1,1,1,shown)
	_epithet.modulate = Color(1,1,1,0.85*smoothstep(0.35,1.0,t)*shown)
	for i in range(_counts.size()):
		_counts[i].modulate = Color(1,1,1,0.7*_slot_in(i,0)*shown)
	_frame.get_node("Marks").queue_redraw()

func _style(label: Label, font: FontVariation, font_size: int, track: float, px: float) -> void:
	style(label,font,font_size,track,px,INK if label != _name else Color.WHITE)

## `label` across the screen, its text centred, its top at `top`.
func _centre(label: Label, font: FontVariation, font_size: int, track: float, top: float, px: float) -> void:
	_style(label,font,font_size,track,px)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(0.0,roundf(top))
	label.size = Vector2(_frame.get_viewport_rect().size.x,0.0)

func _text_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	return font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x

## The slots' row's middle (screen y).
func _slots_y() -> float:
	return (TOP+152.0)*_px

func _slots_width(n: int) -> float:
	return (SLOT*float(n)+SLOT_GAP*float(maxi(n-1,0)))*_px

## Each group's left edge and width (screen px: its slots or its label,
## the wider), the row centred.
func _groups() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var finds: Array = card.get("finds",[])
	var widths: Array[float] = []
	var total := GROUP_GAP*_px*float(maxi(finds.size()-1,0))
	for i in range(finds.size()):
		var w := _slots_width(int(finds[i][3]))
		if i < _counts.size(): w = maxf(w,_counts[i].get_minimum_size().x)
		widths.append(w)
		total += w
	var x := _frame.get_viewport_rect().size.x*0.5-total*0.5
	for w in widths:
		out.append(Vector2(x,w))
		x += w+GROUP_GAP*_px
	return out

## How far in slot `k` of group `row` is (0..1): one after another along
## the row, starting as the name settles.
func _slot_in(row: int, k: int) -> float:
	var before := 0
	for i in range(row): before += int(card.finds[i][3])
	var start := IN*0.45+SLOT_STAGGER*float(before+k)
	return smoothstep(start,start+0.35,age) if age != INF else 0.0

func _icon(id: String, variant: String) -> Texture2D:
	var key := "%s:%s:%d" % [id,variant,roundi(GEM*_px)]
	if not _icons.has(key): _icons[key] = HudIcons.texture(id,variant,GEM*_px)
	return _icons[key]

## The hairline under the name, drawn out from its diamond, the slots,
## and a small diamond between each group.
func _draw_marks(on: Control) -> void:
	if not visible: return
	var px := _px
	var t := clampf(age/IN,0.0,1.0)
	var shown := _shown()
	var mid := on.get_viewport_rect().size.x*0.5
	var y := roundf((TOP+86.0)*px)
	var reach := 240.0*px*smoothstep(0.15,1.0,t)
	var line := Color(HAIRLINE,HAIRLINE.a*shown)
	hairline(on,mid,y,reach,px,line,4.5*px*smoothstep(0.0,0.4,t))
	var groups := _groups()
	var row_y := _slots_y()
	for g in range(groups.size()):
		var find: Array = card.finds[g]
		for k in range(int(find[3])):
			var left := groups[g].x+(groups[g].y-_slots_width(int(find[3])))*0.5
			var at := Vector2(left+(SLOT*0.5+(SLOT+SLOT_GAP)*float(k))*px,row_y)
			_socket(on,at,str(find[0]),k < int(find[2]),_slot_in(g,k)*shown)
		if g > 0:
			var between := groups[g].x-GROUP_GAP*px*0.5
			_stud(on,_diamond(Vector2(between,row_y),2.5*px),Color(HAIRLINE,HAIRLINE.a*0.6*_slot_in(g,0)*shown))

## One socket at `at`: a faceted octagon sunk into the band, its rim lit
## on its upper left and shaded on its lower right, holding the gem: the
## find's icon lit, with a glow in its tint, or its dim silhouette.
func _socket(on: Control, at: Vector2, id: String, found: bool, a: float) -> void:
	if a <= 0.0: return
	var r := SLOT*0.5*_px*lerpf(0.7,1.0,a)
	var rim := _octagon(at,r)
	var well := _octagon(at,r*0.8)
	on.draw_colored_polygon(rim,Color(RIM_SHADE,RIM_SHADE.a*a))
	# The rim's lit half: the octagon's upper left facets.
	var lit := PackedVector2Array([rim[3],rim[4],rim[5],rim[6],rim[7],well[7],well[6],well[5],well[4],well[3]])
	on.draw_colored_polygon(lit,Color(RIM_LIT,RIM_LIT.a*a*(1.0 if found else 0.55)))
	on.draw_colored_polygon(well,Color(WELL,WELL.a*a))
	var tint := Color(HudIcons.item(id).get("tint","fff1dc"))
	var gem := GEM*_px*HudIcons.BOX/24.0
	var box := Rect2(at-Vector2(gem,gem)*0.5,Vector2(gem,gem))
	if found:
		for i in range(3): on.draw_circle(at,r*(0.55+0.18*float(i)),Color(tint,0.10*a))
		var lit_icon := _icon(id,"lit")
		if lit_icon != null: on.draw_texture_rect(lit_icon,box,false,Color(1,1,1,a))
		# A glint on the gem's upper left.
		on.draw_colored_polygon(_diamond(at+Vector2(-r*0.38,-r*0.38),1.6*_px),Color(1,1,1,0.8*a))
	else:
		var shape := _icon(id,"locked")
		if shape != null: on.draw_texture_rect(shape,box,false,Color(EMPTY,EMPTY.a*a))

# --- The card's pieces, shared ---------------------------------------------------

## The inscription's face: Newsreader at weight 500, its tracking set per
## use (`style`).
static func inscription_font() -> FontVariation:
	var font := FontVariation.new()
	font.base_font = DISPLAY
	font.variation_opentype = {"wght":500.0}
	return font

## A gilt material for a label in the inscription face, its glyph scale
## kept by `gild` (design px of the type, the screen's scale).
static func gilt_material() -> ShaderMaterial:
	var gilt := ShaderMaterial.new()
	gilt.shader = GILT
	return gilt

static func gild(label: Label, font_size: float, px: float) -> void:
	(label.material as ShaderMaterial).set_shader_parameter("glyph_scale",px*font_size/58.0)

## `label` in the card's type: `font_size` design px, tracked `track`
## (on `font`, if one), in `colour`, its soft shadow scaled by `px`.
static func style(label: Label, font: FontVariation, font_size: int, track: float, px: float, colour: Color) -> void:
	if font != null: font.spacing_glyph = roundi(track*px)
	label.add_theme_font_size_override("font_size",maxi(1,roundi(font_size*px)))
	label.add_theme_color_override("font_color",colour)
	label.add_theme_constant_override("shadow_offset_y",roundi(1.5*px))
	label.add_theme_constant_override("shadow_outline_size",roundi(4.0*px))
	label.size = Vector2.ZERO

## The soft dark band, laid by `lay_band`.
static func make_band() -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band := ShaderMaterial.new()
	band.shader = BAND
	rect.material = band
	return rect

## The band centred on `mid`, from `top` to `bottom` (screen px), `past`
## design px past `wide` at each end, `strength` dark.
static func lay_band(rect: ColorRect, mid: float, top: float, bottom: float, wide: float, px: float, strength: float, past := BAND_PAST) -> void:
	rect.size = Vector2(wide+past*2.0*px,bottom-top)
	rect.position = Vector2(mid-rect.size.x*0.5,top)
	var band := rect.material as ShaderMaterial
	band.set_shader_parameter("fade_from",clampf(wide/rect.size.x*0.7,0.1,0.9))
	band.set_shader_parameter("feather",0.35)
	band.set_shader_parameter("strength",strength)

## The hairline at `y`, `reach` each way from `mid`, parted round its
## diamond (`diamond` px from its middle to a point).
static func hairline(on: Control, mid: float, y: float, reach: float, px: float, line: Color, diamond: float) -> void:
	var gap := 11.0*px
	if reach > gap:
		on.draw_line(Vector2(mid-reach,y),Vector2(mid-gap,y),line,maxf(1.0,px))
		on.draw_line(Vector2(mid+gap,y),Vector2(mid+reach,y),line,maxf(1.0,px))
	_stud(on,_diamond(Vector2(mid,y),diamond),line)

## `points` filled, unless it has collapsed to (near) nothing: the title
## diamond grows from zero size as the card fades in, and one under a few
## thousandths of a pixel across, at screen coordinates, has no area the
## triangulator can find ("Invalid polygon data, triangulation failed").
static func _stud(on: Control, points: PackedVector2Array, color: Color) -> void:
	if Geometry2D.triangulate_polygon(points).is_empty(): return
	on.draw_colored_polygon(points,color)

static func _octagon(at: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(8):
		var angle := TAU*(float(i)+0.5)/8.0
		points.append(at+Vector2(cos(angle),sin(angle))*r)
	return points

static func _diamond(at: Vector2, d: float) -> PackedVector2Array:
	return PackedVector2Array([at+Vector2(0,-d),at+Vector2(d,0),at+Vector2(0,d),at+Vector2(-d,0)])
