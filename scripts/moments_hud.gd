extends CanvasLayer
## The moments set pieces' readout (scripts/sky_moments.gd): small and
## quiet, top middle, in the HUD's lantern look (scripts/lantern_style.gd)
## as the tokens' readout is (scripts/collectibles_hud.gd), and with its
## sounds: a pop (`pop`) that rises, holds HOLD s and fades, for a free
## collectible taken, a challenge started or ended, or a hop (the debug N);
## and under it, while a challenge is on, its count (`status`: "challenge
## 1/3"), which stays till the challenge ends. A free or challenge
## collectible sounds the tokens' blip, climbing the steps as the station's
## are taken; a challenge complete sounds their sparkling run.

const Style = preload("res://scripts/lantern_style.gd")
const Audio = preload("res://scripts/genesis_audio.gd")
const TokensHud = preload("res://scripts/collectibles_hud.gd")

const RISE := 0.15
const HOLD := 2.0
const FADE := 0.8
const TYPE := 24
const STATUS_TYPE := 21
const MARGIN := 64.0
## The challenge's tint in the status line (the diamonds' orange-red).
const CHALLENGE := Color(1.0,0.62,0.45)

var _column: VBoxContainer
var _box: PanelContainer
var _pop: Label
var _status_box: PanelContainer
var _status: Label
var _t := INF
var _from := 0.0
var _hold := HOLD
var _blip: AudioStreamPlayer
var _flourish: AudioStreamPlayer
## The last texts shown (tests).
var last_pop := ""
var last_status := ""

func _ready() -> void:
	layer = 6
	name = "MomentsHud"
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",6)
	column.set_anchors_preset(Control.PRESET_CENTER_TOP)
	add_child(column)
	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_stylebox_override("panel",Style.plate(22,0.26,10))
	_box.modulate.a = 0.0
	column.add_child(_box)
	_pop = Style.label("",TYPE)
	_pop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(_pop)
	_status_box = PanelContainer.new()
	_status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_box.add_theme_stylebox_override("panel",Style.plate(18,0.22,8))
	_status_box.visible = false
	column.add_child(_status_box)
	_status = Style.label("",STATUS_TYPE,CHALLENGE)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_box.add_child(_status)
	Audio.ensure_buses()
	_blip = _player(TokensHud._blip(),TokensHud.BLIP_GAIN)
	_flourish = _player(TokensHud._flourish(),TokensHud.FLOURISH_GAIN)
	_column = column
	_layout()
	get_viewport().size_changed.connect(_layout)
	set_process(false)


## A pop of `text`, held `hold` s.
func pop(text: String, hold := HOLD) -> void:
	last_pop = text
	if _pop == null: return
	_pop.text = text
	_from = _box.modulate.a
	_t = 0.0
	_hold = hold
	_layout()
	set_process(true)


## The line under the pop while a challenge is on ("" hides it).
func status(text: String) -> void:
	last_status = text
	if _status == null: return
	_status.text = text
	_status_box.visible = text != ""
	_layout()

## The tokens' blip, `step` steps up their scale (0 the first).
func blip(step: int) -> void:
	if _blip == null or not _blip.is_inside_tree(): return
	_blip.pitch_scale = pow(2.0,TokensHud.STEPS[clampi(step,0,TokensHud.STEPS.size()-1)]/12.0)
	_blip.play()

## The tokens' sparkling run (a challenge complete).
func flourish() -> void:
	if _flourish != null and _flourish.is_inside_tree(): _flourish.play()

## True while the pop shows (tests).
func showing() -> bool:
	return _box != null and _box.modulate.a > 0.0

func _process(delta: float) -> void:
	_t += delta
	var a := 1.0
	if _t < RISE: a = lerpf(_from,1.0,_t/RISE)
	elif _t > RISE+_hold: a = 1.0-(_t-RISE-_hold)/FADE
	_box.modulate.a = clampf(a,0.0,1.0)
	if _t > RISE+_hold+FADE:
		_box.modulate.a = 0.0
		set_process(false)

func _layout() -> void:
	if _column == null or get_viewport() == null: return
	var screen := get_viewport().get_visible_rect().size
	var scale := Style.ui_scale(screen)
	_pop.add_theme_font_size_override("font_size",int(TYPE*scale))
	_status.add_theme_font_size_override("font_size",int(STATUS_TYPE*scale))
	_column.reset_size()
	var size := _column.get_combined_minimum_size()
	_column.position = Vector2((screen.x-size.x)*0.5,MARGIN*scale)

func _player(stream: AudioStreamWAV, gain: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = Audio.BUS
	player.stream = stream
	player.volume_db = linear_to_db(gain)
	player.max_polyphony = 4
	add_child(player)
	return player
