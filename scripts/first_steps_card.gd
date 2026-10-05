extends Control
## The first-steps card (docs/scenic/first-steps.md): a small scrap of the
## HUD's linen (scripts/hud_linen.gd) in the top right corner that asks for
## one gesture at a time, the step the model (scripts/first_steps.gd) says is
## current. A murmur, not a tutorial: it never takes a press on the world and
## nothing in the world waits on it. Its kicker ("First steps") and a quiet
## Skip sit on the first line over a hairline, then the verb's name in
## Newsreader and how it is done in the whisper face, one part to a line as the
## hint line's " · " parts are, and under them seven stitched pips, a found
## step's filled as the tool roll's size pip is.
##
## - **Found.** When the verb is done the pip fills, the name settles with a
##   running stitch drawn under it and the line dims, a beat later the words
##   leave and the next step's ease in. After the last one (`finished`) it is
##   one last card, "The rest is yours to find", with where the field notes
##   are, which lingers LAST_HOLD s and then leaves for good. A skip leaves at
##   once. `restart` on the model (the field notes' "Walk me through it
##   again") brings it back from its first step.
## - **Where.** The top right corner, inset as the almanac (RIGHT) and the top
##   strip (TOP) are, and clear of everything else: the roll and its foot are
##   on the left edge, the top strip centred (a held tool's fan hangs under it
##   but ends well short of the right third), the tray and the hint line along
##   the bottom, and the almanac on the right edge starts 150 design pixels
##   under the card even at 1440x810 (its strip is centred, 361 tall).
##
## It rests at CALM of itself, wakes as the pointer comes over it, and goes
## quiet (QUIET, still there) while `quiet` is set: the hand sets it for a drag
## under way, as for the roll and the bars. It joins "hud_piece" so photo mode's
## `want(false)` steps it out with the rest.
##
## It only draws; the hand (scripts/hand_materials.gd) hands it the presses
## `contains_pointer` claims and asks `press` first, and the scene joins
## `near` to the cloth that should be pointed at: `pointing()` names the piece
## ("roll", "tray", "almanac", "foot") and the id for its `nudge`, and
## `pointing_changed` says when that changes.

const Linen = preload("res://scripts/hud_linen.gd")
const FirstSteps = preload("res://scripts/first_steps.gd")
const WHISPER_FONT = preload("res://assets/fonts/spectral-latin-400.woff2")

## A step's or the last card's change of pointing: the piece ("roll", "tray",
## "almanac", "foot"; "" for none) and the id its `nudge` takes.
signal pointing_changed(piece: String, id: String)

## The copy that is the card's own.
const KICKER := "First steps"
const SKIP := "Skip"
const LAST_NAME := "The rest is yours to find"
const LAST_LINE := "The field notes are under Esc"
const PAD_LAST_LINE := "The field notes are under Menu"
## Layout, design pixels: the card's width, its inset from the right and top
## edges (the almanac's RIGHT and the top strip's TOP_INSET), its padding (x, y).
const WIDTH := 300.0
const RIGHT := 24.0
const TOP := 18.0
const PAD := Vector2(16.0,13.0)
const RADIUS := 12.0
## The kicker's rule below its baseline; the name's size and its baseline under
## the rule; the whisper's size (as the tags') and the gap between parts; the
## pips' diameter and pitch, and their gap from the text.
const KICKER_RULE := 4.0
const NAME_SIZE := 19.0
const NAME_DROP := 26.0
const LINE_SIZE := 13.0
const LINE_TOP := 8.0
const LINE_GAP := 3.0
const PIP := 8.0
const PIP_PITCH := 17.0
const PIP_TOP := 14.0
## Skip's size and the room round it to press.
const SKIP_SIZE := 12.0
const SKIP_GROW := Vector2(6.0,4.0)
## The pip's fill (the clay's tint, as the roll's size pip takes) and the ink of
## the lines after the first.
const PIP_FILL := Color("e0a07a")
const WHISPER_INK := Color("d6cbb2")
const LATER_LINE := 0.72
## Seconds: it comes and goes over FADE; the found beat's name settles over
## SETTLE, the words stay BEAT_HOLD s in all and then take SWAP s to leave or
## come in; a pip fills over FILL; the last card stays LAST_HOLD.
const FADE := 0.6
const SETTLE := 0.4
const BEAT_HOLD := 1.3
const SWAP := 0.4
const FILL := 0.45
const LAST_HOLD := 8.0
## How much of itself it shows at rest, with the pointer over it, and quiet
## (a drag under way); and the seconds to move between them.
const CALM := 0.82
const QUIET := 0.38
const LEVEL_TIME := 0.4
## How a verb's `near` splits: "roll:hand" -> piece "roll", id "hand".
const PIECES := ["roll","tray","almanac","foot"]

## The rim's outline on screen while a step shows it (scripts/hand_materials.gd
## sets it each frame), drawn lit; empty otherwise. Its band and stitched
## line's widths (design pixels) and its breath (s).
const RIM_BAND := 7.0
const RIM_LINE := 2.0
const RIM_PERIOD := 2.4
var rim := PackedVector2Array()

var ui_scale := 1.0
## 0..1 how shown it is: wanted, and past its entrance.
var presence := 0.0
## A drag or camera move is under way: it recedes (QUIET) but stays.
var quiet := false
## Seconds after the world is first shown before the card comes in.
var intro_delay := 1.5
var pointer_override: Variant = null
var scene: Node
var steps: Node
## "step" (asking), "last" (the closing card) or "gone" (put away).
var mode := "gone"
var _step := ""
var _target := ""
var _finishing := false
## Seconds into the found beat, -1 when none; how far the name has settled; how
## visible the words are (0 between steps).
var _beat := -1.0
var _settle := 0.0
var _content := 0.0
var _last_for := 0.0
var _level := CALM
var _wake := 0.0
var _height := 0.0
var _want_shown := false
var _pointed := ""
var _fill: Array[float] = []
var _font: FontVariation
var _name_font: FontVariation
var _cloth: Linen.Cloth

func _ready() -> void:
	name = "FirstStepsCard"
	# Every HUD piece is in this group; photo mode rests them all with want(false).
	add_to_group("hud_piece")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = Linen.tag_font()
	_name_font = Linen.tag_font()
	_cloth = Linen.Cloth.new()
	add_child(_cloth)
	modulate.a = 0.0
	visible = false

## Wires it to the world's scene and the model it shows. It starts put away if
## there is nothing to ask (done, or skipped before).
func setup(owner_scene: Node, model: Node) -> void:
	scene = owner_scene
	steps = model
	_fill.clear()
	for id: String in FirstSteps.STEPS: _fill.append(1.0 if model.found.get(id,false) else 0.0)
	_step = model.current()
	mode = "step" if not _step.is_empty() else "gone"
	_target = _step
	model.step_changed.connect(_on_step_changed)
	model.finished.connect(_on_finished)

## Shows it (resting) or puts it away, as the roll's `want`.
func want(on: bool) -> void:
	_want_shown = on

# --- What it asks for -------------------------------------------------------------

## The current verb's `near` ("roll:hand", "tray:water", "almanac:time",
## "foot:undo"), or "" for the world, between steps and when put away.
func near() -> String:
	if mode != "step" or _beat >= 0.0 or steps == null or _step.is_empty(): return ""
	return str(steps.verb(_step).get("near",""))

## The plate's rim lit for a step that names it (VERBS `show`): a soft band
## with a stitched line over it, breathing once every RIM_PERIOD s.
func _draw_rim(px: float) -> void:
	if rim.size() < 3: return
	var breath := 0.5-0.5*cos(fposmod(Time.get_ticks_msec()/1000.0,RIM_PERIOD)/RIM_PERIOD*TAU)
	draw_polyline(rim,Color(Linen.INK,0.16+0.2*breath),RIM_BAND*px,true)
	Linen.dashed(self,rim,Color(Linen.INK,0.6+0.4*breath),maxf(1.5,RIM_LINE*px),7.0*px,5.0*px)

## The step whose words are on the card now, or "" between steps (the found
## beat), on the closing card and when put away: what the hand should hold
## follows it (scripts/hand_materials.gd `_take_for`).
func asking() -> String:
	if mode != "step" or _beat >= 0.0 or steps == null or not _want_shown: return ""
	return _step

## The cloth to point at: [piece, id] for `near`, ["", ""] for none. The piece
## is "roll", "tray", "almanac" or "foot": the scene's `nudge` to call.
func pointing() -> Array:
	return point_at(near())

## "roll:hand" as ["roll","hand"]; ["",""] for a `near` that names no piece.
static func point_at(spot: String) -> Array:
	var parts := spot.split(":")
	if parts.size() != 2 or not parts[0] in PIECES or parts[1].is_empty(): return ["",""]
	return [parts[0],parts[1]]

## The words on the card now: its name and the parts of its line.
func words() -> Array:
	if mode == "last": return [LAST_NAME,[preload("res://scripts/pad.gd").pick(LAST_LINE,PAD_LAST_LINE)]]
	if steps == null or _step.is_empty(): return ["",[]]
	var verb: Dictionary = steps.verb(_step)
	var line := FirstSteps.line(_step)
	return [str(verb.get("name","")),Array(line.split(" · ")) if not line.is_empty() else []]

# --- Reading the pointer --------------------------------------------------------

## True over the card while it shows.
func contains_pointer(point: Vector2) -> bool:
	return presence >= 0.5 and _card().grow(2.0*ui_scale).has_point(point)

## A left press the hand passed on. True, and the card is put away for good, when
## it was on Skip; false for anything else (the world's, or the card's own cloth,
## which the hand still treats as UI through `contains_pointer`).
func press(point: Vector2) -> bool:
	if mode != "step" or presence < 0.5 or not _skip_rect().has_point(point): return false
	if steps != null: steps.skip()
	_leave()
	return true

## The card, viewport pixels.
func rect() -> Rect2:
	return _card()

func _card() -> Rect2:
	var extent := Vector2(WIDTH*ui_scale,_height)
	return Rect2(Vector2(roundf(size.x-RIGHT*ui_scale-extent.x),roundf(TOP*ui_scale)),extent.round())

## Skip's cell on the kicker's line, with room to press.
func _skip_rect() -> Rect2:
	var card := _card()
	var width := WHISPER_FONT.get_string_size(SKIP,HORIZONTAL_ALIGNMENT_LEFT,-1,_size(SKIP_SIZE)).x
	var box := Rect2(Vector2(card.end.x-PAD.x*ui_scale-width,card.position.y+PAD.y*ui_scale-2.0*ui_scale),Vector2(width,(Linen.TAG_CAPS+4.0)*ui_scale))
	return box.grow_individual(SKIP_GROW.x*ui_scale,SKIP_GROW.y*ui_scale,SKIP_GROW.x*ui_scale,SKIP_GROW.y*ui_scale)

func _size(design: float) -> int:
	return maxi(6,roundi(design*ui_scale))

# --- Following the model ------------------------------------------------------------

func _on_step_changed(id: String) -> void:
	_target = id
	_finishing = false
	if id.is_empty() and steps.skipped:
		_leave()
		return
	if mode != "step" or _step.is_empty():
		# Back from put away, or the closing card: from its first step.
		if not id.is_empty(): _show(id)
		return
	if _beat < 0.0 and steps.found.get(_step,false): _beat = 0.0
	elif _beat < 0.0: _step = id

func _on_finished() -> void:
	_finishing = true
	if mode == "step" and _beat < 0.0: _end_beat()

## It comes back at `id` (a restart), its words easing in.
func _show(id: String) -> void:
	mode = "step"
	_step = id
	_beat = -1.0
	_settle = 0.0
	_content = 0.0
	_fill.clear()
	for step_id: String in FirstSteps.STEPS: _fill.append(1.0 if steps.found.get(step_id,false) else 0.0)

## The beat is over: the next step, the closing card, or away.
func _end_beat() -> void:
	_beat = -1.0
	_settle = 0.0
	if not _target.is_empty(): _step = _target
	elif _finishing:
		mode = "last"
		_last_for = 0.0
	else: _leave()

## Put away for good: it fades out and stays out until the model restarts.
func _leave() -> void:
	mode = "gone"
	_beat = -1.0

# --- Frames ---------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var screen := get_viewport().get_visible_rect().size
	ui_scale = Linen.hud_scale_for(screen)
	var pointer: Vector2 = get_viewport().get_mouse_position() if pointer_override == null else pointer_override
	if _want_shown and mode != "gone" and intro_delay > 0.0: intro_delay -= delta
	var wanted := _want_shown and mode != "gone" and intro_delay <= 0.0
	presence = move_toward(presence,1.0 if wanted else 0.0,delta/FADE)
	if _beat >= 0.0:
		_beat += delta
		_settle = move_toward(_settle,1.0,delta/SETTLE)
		if _beat >= BEAT_HOLD:
			_content = move_toward(_content,0.0,delta/SWAP)
			if _content <= 0.0: _end_beat()
	elif mode != "gone":
		_content = move_toward(_content,1.0,delta/SWAP)
	if mode == "last" and presence >= 1.0:
		_last_for += delta
		if _last_for >= LAST_HOLD: _leave()
	for i in range(_fill.size()):
		var done: bool = steps != null and (mode == "last" or steps.found.get(FirstSteps.STEPS[i],false))
		_fill[i] = move_toward(_fill[i],1.0 if done else 0.0,delta/FILL)
	var spot := near()
	if spot != _pointed:
		_pointed = spot
		var at := point_at(spot)
		pointing_changed.emit(at[0],at[1])
	visible = presence > 0.0
	if not visible: return
	_wake = move_toward(_wake,1.0 if _card().grow(6.0*ui_scale).has_point(pointer) else 0.0,delta/LEVEL_TIME)
	_level = move_toward(_level,QUIET if quiet else lerpf(CALM,1.0,Linen.eased(_wake)),delta/LEVEL_TIME*(1.0-QUIET))
	modulate.a = Linen.eased(presence)*_level
	var target: float = _layout().height
	_height = target if absf(_height-target) < 0.5 or _height == 0.0 else lerpf(_height,target,1.0-exp(-delta*10.0))
	_cloth.place(_card(),ui_scale,RADIUS)
	queue_redraw()

## Where everything sits inside the card, from its top: the kicker's baseline
## and rule, the name's baseline, the baseline of each part of the line, the
## pips' centre line and the whole height, in viewport pixels.
func _layout() -> Dictionary:
	var px := ui_scale
	var out := {}
	out.kicker = (PAD.y+Linen.TAG_CAPS)*px
	out.rule = out.kicker+KICKER_RULE*px
	out.name = out.rule+NAME_DROP*px
	var at: float = out.name+LINE_TOP*px
	var parts: Array = words()[1]
	var lines: Array = []
	var size := _size(LINE_SIZE)
	for part: String in parts:
		var block := WHISPER_FONT.get_multiline_string_size(part,HORIZONTAL_ALIGNMENT_LEFT,(WIDTH-PAD.x*2.0)*px,size)
		lines.append(at+WHISPER_FONT.get_ascent(size))
		at += block.y+LINE_GAP*px
	out.lines = lines
	out.pips = at+(PIP_TOP-LINE_GAP if not parts.is_empty() else PIP_TOP-LINE_TOP)*px+PIP*0.5*px
	out.height = out.pips+PIP*0.5*px+PAD.y*px
	return out

func _draw() -> void:
	var px := ui_scale
	_draw_rim(px)
	var card := _card()
	var lay := _layout()
	var line := maxf(1.0,roundf(px))
	var inner := (WIDTH-PAD.x*2.0)*px
	var left := card.position.x+PAD.x*px
	# The kicker: caps over a hairline, and Skip at the other end.
	var kicker := KICKER.to_upper()
	var caps := _size(Linen.TAG_CAPS)
	_font.spacing_glyph = roundi(Linen.TAG_TRACK*Linen.TAG_SIZE*px)
	draw_string(_font,Vector2(roundf(left),roundf(card.position.y+float(lay.kicker))),kicker,HORIZONTAL_ALIGNMENT_LEFT,-1,caps,Color(Linen.INK,0.72))
	var rule := roundf(card.position.y+float(lay.rule))+line*0.5
	draw_line(Vector2(left,rule),Vector2(left+inner,rule),Linen.HAIRLINE,line)
	if mode == "step":
		var skip := _skip_rect()
		var pointer: Vector2 = get_viewport().get_mouse_position() if pointer_override == null else pointer_override
		var over := skip.has_point(pointer)
		var width := WHISPER_FONT.get_string_size(SKIP,HORIZONTAL_ALIGNMENT_LEFT,-1,_size(SKIP_SIZE)).x
		draw_string(WHISPER_FONT,Vector2(roundf(card.end.x-PAD.x*px-width),roundf(card.position.y+float(lay.kicker))),SKIP,HORIZONTAL_ALIGNMENT_LEFT,-1,_size(SKIP_SIZE),Color(WHISPER_INK,1.0 if over else 0.55))
	# The name and how it is done.
	var copy := words()
	var settled := Linen.eased(_settle)
	var name_size := _size(NAME_SIZE)
	_name_font.spacing_glyph = 0
	var base := Vector2(roundf(left),roundf(card.position.y+float(lay.name)-3.0*px*(1.0-settled)))
	draw_string(_name_font,base,str(copy[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,name_size,Color(Linen.INK,_content*(0.92+0.08*settled)))
	if settled > 0.0:
		var width := _name_font.get_string_size(str(copy[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,name_size).x
		var y := base.y+5.0*px
		Linen.dashed(self,PackedVector2Array([Vector2(base.x,y),Vector2(base.x+width*settled,y)]),Color(Linen.PIP_STITCH,Linen.PIP_STITCH.a*_content),line,3.0*px,3.0*px)
	var parts: Array = copy[1]
	for i in range(parts.size()):
		var ink := Color(WHISPER_INK,_content*(1.0 if i == 0 else LATER_LINE)*(1.0-0.45*settled))
		draw_multiline_string(WHISPER_FONT,Vector2(roundf(left),roundf(card.position.y+float(lay.lines[i]))),str(parts[i]),HORIZONTAL_ALIGNMENT_LEFT,inner,_size(LINE_SIZE),-1,ink)
	# The pips: stitched, a found one filled, the one asked for ringed.
	var r := PIP*0.5*px
	for i in range(_fill.size()):
		var centre := Vector2(left+r+PIP_PITCH*px*i,card.position.y+float(lay.pips))
		var f := _fill[i]
		if f > 0.0:
			draw_circle(centre,r,Color(PIP_FILL,f),true,-1.0,true)
			draw_arc(centre+Vector2(0.0,0.75*px),r-0.75*px,0.15*PI,0.85*PI,12,Color(0.1,0.078,0.055,0.28*f),1.5*px,true)
		Linen.dashed_circle(self,centre,r,Color(Linen.PIP_REST,Linen.PIP_REST.a).lerp(Linen.PIP_STITCH,f),line,px)
		if mode == "step" and _beat < 0.0 and FirstSteps.STEPS[i] == _step:
			Linen.dashed_circle(self,centre,r+2.5*px,Linen.PIP_STITCH,line,px)
