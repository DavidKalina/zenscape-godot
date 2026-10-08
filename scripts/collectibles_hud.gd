extends CanvasLayer
## The quiet readout of the sky's collectible tokens (scripts/
## sky_collectibles.gd): up in the top right corner, only for a moment after
## a pickup. The glyph just taken (its HUD icon, scripts/hud_icons.gd), how
## many of that glyph are collected, and under them the token's line as a
## row of small pips, the taken ones filled in its tint. It comes up over
## RISE s, holds HOLD s and fades over FADE s; another pickup holds it up.
## When a whole line is taken the pips swell and settle together, it holds a
## little longer (HOLD_LINE) and a soft chime sounds, a two-note bell made
## here (`_chime`) and played low on the world's sound bus. Nothing to press,
## nothing to navigate: the pad and the keys never reach it.
##
## Drawn in the HUD's lantern look (scripts/lantern_style.gd): warm-white
## spaced figures with a dark rim over a soft dark plate, sizes in design
## pixels scaled by `ui_scale`.

const HudIcons = preload("res://scripts/hud_icons.gd")
const Style = preload("res://scripts/lantern_style.gd")
const Audio = preload("res://scripts/genesis_audio.gd")

## Seconds: up, held (and held after a whole line), out.
const RISE := 0.18
const HOLD := 2.2
const HOLD_LINE := 3.4
const FADE := 0.9
## Design pixels: the icon, the count's type, the pips' radius and gap, the
## margin off the corner.
const ICON := 46.0
const TYPE := 27
const PIP := 4.2
const PIP_GAP := 13.0
const MARGIN := 28.0
## The plate's darkness.
const PLATE := 0.26
## The chime: its notes (Hz), length (s) and gain (linear, under the
## world's sound volume).
const NOTES := [880.0,1318.5]
const CHIME := 1.4
const CHIME_GAIN := 0.12

var _box: PanelContainer
var _icon: TextureRect
var _count: Label
var _pips: Control
var _glyph := ""
var _got := 0
var _of := 0
var _tint := Color.WHITE
var _swell := 0.0
## Seconds since the last pickup, how long it holds, and how far up it was
## when that pickup came.
var _t := INF
var _hold := HOLD
var _from := 0.0
var _player: AudioStreamPlayer
var _icons := {}
var _scale := 1.0

func _ready() -> void:
	layer = 6
	name = "CollectiblesHud"
	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_stylebox_override("panel",Style.plate(22,PLATE,10))
	_box.modulate.a = 0.0
	add_child(_box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",4)
	_box.add_child(column)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation",8)
	row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(row)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_icon)
	_count = Style.label("0",TYPE)
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_count)
	_pips = Control.new()
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.draw.connect(_draw_pips)
	column.add_child(_pips)
	_player = AudioStreamPlayer.new()
	Audio.ensure_buses()
	_player.bus = Audio.BUS
	_player.stream = _chime()
	_player.volume_db = linear_to_db(CHIME_GAIN)
	add_child(_player)
	_layout()
	get_viewport().size_changed.connect(_layout)
	set_process(false)

## A pickup: `glyph` taken, `total` of it collected now, its line `got` of
## `count`.
func show_pickup(glyph: String, total: int, got: int, count: int) -> void:
	_glyph = glyph
	_got = got
	_of = count
	_tint = Color(HudIcons.item(glyph).get("tint","fff1dc"))
	_icon.texture = _icon_for(glyph)
	_count.text = str(total)
	var whole := count > 0 and got >= count
	_from = _box.modulate.a
	_t = 0.0
	_hold = HOLD_LINE if whole else HOLD
	if whole:
		_swell = 1.0
		if _player.is_inside_tree(): _player.play()
	_layout()
	_pips.queue_redraw()
	set_process(true)

## True while it shows (tests).
func showing() -> bool:
	return _box.modulate.a > 0.0

func _process(delta: float) -> void:
	_t += delta
	_swell = maxf(_swell-delta*1.6,0.0)
	var a := 1.0
	if _t < RISE: a = lerpf(_from,1.0,_t/RISE)
	elif _t > RISE+_hold: a = 1.0-(_t-RISE-_hold)/FADE
	_box.modulate.a = clampf(a,0.0,1.0)
	if _swell > 0.0: _pips.queue_redraw()
	if _t > RISE+_hold+FADE:
		_box.modulate.a = 0.0
		set_process(false)

func _layout() -> void:
	if _box == null: return
	var screen := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1440,900)
	_scale = Style.ui_scale(screen)
	_icon.custom_minimum_size = Vector2.ONE*ICON*_scale
	_count.add_theme_font_size_override("font_size",int(TYPE*_scale))
	_pips.custom_minimum_size = Vector2(maxf(_of,1)*PIP_GAP*_scale,PIP*2.0*_scale+6.0*_scale)
	_box.reset_size()
	var size := _box.get_combined_minimum_size()
	_box.position = Vector2(screen.x-size.x-MARGIN*_scale,MARGIN*_scale)

func _icon_for(glyph: String) -> Texture2D:
	if not _icons.has(glyph): _icons[glyph] = HudIcons.texture(glyph,"icon",ICON*2.0)
	return _icons[glyph]

## The line's pips, right to left from the corner's edge: filled in the
## glyph's tint where taken, a faint ring where not; all swelling a moment
## when the line is whole.
func _draw_pips() -> void:
	if _of <= 0: return
	var r := PIP*_scale*(1.0+0.45*sin(PI*_swell))
	var gap := PIP_GAP*_scale
	var y := _pips.size.y*0.5
	var right := _pips.size.x-gap*0.5
	for k in range(_of):
		var at := Vector2(right-gap*(_of-1-k),y)
		_pips.draw_circle(at,r+1.4*_scale,Color(Style.SHADE,0.5))
		if k < _got: _pips.draw_circle(at,r,_tint.lightened(0.2))
		else: _pips.draw_arc(at,r*0.8,0.0,TAU,16,Color(Style.LIGHT,0.55),1.2*_scale,true)

## A soft two-note bell: each note a sine with a quieter octave, a quick
## swell and a long fall, the second a beat after the first.
static func _chime() -> AudioStreamWAV:
	var rate := 22050
	var n := int(CHIME*rate)
	var data := PackedByteArray()
	data.resize(n*2)
	for i in range(n):
		var t := float(i)/rate
		var v := 0.0
		for k in range(NOTES.size()):
			var s := t-0.16*k
			if s < 0.0: continue
			var f: float = NOTES[k]
			var env := minf(s/0.012,1.0)*exp(-s*3.2)
			v += env*(sin(TAU*f*s)+0.25*sin(TAU*f*2.0*s)*exp(-s*6.0))*0.5
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream
