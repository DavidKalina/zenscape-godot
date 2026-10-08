extends CanvasLayer
## The quiet readout of the sky's collectible tokens (scripts/
## sky_collectibles.gd): up in the top right corner, only for a moment after
## a pickup. The glyph just taken (its HUD icon, scripts/hud_icons.gd), how
## many of that glyph are collected, and under them the token's line as a
## row of small pips, the taken ones filled in its tint. It comes up over
## RISE s, holds HOLD s and fades over FADE s; another pickup holds it up.
## Every pickup sounds a bright little blip (`_blip`), a quick grace note
## leaping a fourth into a shimmering ring, pitched up the line's pentatonic
## steps as its tokens are taken. When a whole line is taken the pips swell
## and settle together, it holds a little longer (HOLD_LINE) and a sparkling
## run (`_flourish`) climbs over the blip. Both are made here and played on
## the world's sound bus. Nothing to press, nothing to navigate: the pad and
## the keys never reach it.
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
## The sounds: the rate they're made at, the blip's grace and ringing notes
## (Hz) and the flourish's run (Hz), their gains (linear, under the world's
## sound volume), and the semitone steps a line's pickups climb.
const RATE := 32000
const BLIP_NOTES := [1046.5,1396.9]
const RUN_NOTES := [1396.9,1568.0,1760.0,2093.0,2793.8]
const BLIP_GAIN := 0.16
const FLOURISH_GAIN := 0.12
const STEPS := [0,2,4,7,9,12]

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
var _blip_player: AudioStreamPlayer
var _flourish_player: AudioStreamPlayer
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
	Audio.ensure_buses()
	_blip_player = _sound_player(_blip(),BLIP_GAIN)
	_flourish_player = _sound_player(_flourish(),FLOURISH_GAIN)
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
	_blip_player.pitch_scale = pow(2.0,STEPS[clampi(got-1,0,STEPS.size()-1)]/12.0)
	if _blip_player.is_inside_tree(): _blip_player.play()
	if whole:
		_swell = 1.0
		if _flourish_player.is_inside_tree(): _flourish_player.play()
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

func _sound_player(stream: AudioStreamWAV, gain: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = Audio.BUS
	player.stream = stream
	player.volume_db = linear_to_db(gain)
	player.max_polyphony = 4
	add_child(player)
	return player

## One shiny note at `f` Hz from `s` s into it: a sine pair detuned a hair
## for shimmer, a soft square-ish edge of odd overtones that fades fast, a
## bell's inharmonic glint at the strike, a 3 ms rise and a fall of `decay`.
static func _note(f: float, s: float, decay: float) -> float:
	if s < 0.0: return 0.0
	var env := minf(s/0.003,1.0)*exp(-s*decay)
	var v := 0.5*(sin(TAU*f*s)+sin(TAU*(f+2.5)*s))
	v += (0.22*sin(TAU*f*3.0*s)+0.1*sin(TAU*f*5.0*s))*exp(-s*14.0)
	v += 0.3*sin(TAU*f*2.76*s)*exp(-s*40.0)
	return env*v

## The pickup: a 45 ms grace note leaping a fourth into a note that rings
## out and shimmers away, all in under half a second.
static func _blip() -> AudioStreamWAV:
	var n := int(0.45*RATE)
	var data := PackedFloat32Array()
	data.resize(n)
	for i in range(n):
		var t := float(i)/RATE
		var grace := _note(BLIP_NOTES[0],t,9.0)*clampf((0.05-t)/0.008,0.0,1.0)
		data[i] = (grace+_note(BLIP_NOTES[1],t-0.045,7.5))
	return _wav(data)

## A whole line: a quick run up the pentatonic, starting under the blip's
## ring so it follows at once, its top note left to sparkle out.
static func _flourish() -> AudioStreamWAV:
	var n := int(1.1*RATE)
	var data := PackedFloat32Array()
	data.resize(n)
	for i in range(n):
		var t := float(i)/RATE
		var v := 0.0
		for k in range(RUN_NOTES.size()):
			var last := k == RUN_NOTES.size()-1
			v += _note(RUN_NOTES[k],t-0.07-0.055*k,3.5 if last else 11.0)*(0.8 if last else 0.6)
		data[i] = v
	return _wav(data)

## 16-bit mono, its loudest sample brought to 0.9.
static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0
	for v in samples: peak = maxf(peak,absf(v))
	var gain := 0.9/peak if peak > 0.0 else 1.0
	var data := PackedByteArray()
	data.resize(samples.size()*2)
	for i in range(samples.size()):
		data.encode_s16(i*2,int(clampf(samples[i]*gain,-1.0,1.0)*32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
