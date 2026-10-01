extends Control
## The tool roll's foot (design "ZenScape HUD 5 Air", section F;
## docs/design/hud-5/README.md and FOOT.md): a separate small piece of the same
## linen, FOOT_GAP under the tool roll (scripts/tool_roll.gd) and as wide, with
## small stitched slots, Undo and Photo, and the Lens under them. They are not tools: nothing is
## taken into the hand, a press just does the thing. So they live apart from
## the roll's pockets, on their own scrap of cloth, and never show a badge or
## a count: an empty history is not greyed out, a press on it does nothing.
##
## - **Undo** takes back one step, exactly as Cmd Z does: it calls the same
##   NativeChunkEditor `undo` the key calls (and the Lantern shell's Undo
##   button did), so the two can never drift apart.
## - **Photo** enters photo mode (scripts/photo_mode.gd, through the scene's
##   `enter_photo`, as P and the Lantern shell's Photo button do). The Lantern
##   UI is going away, so under the hand scheme this is Photo's home. For the
##   shot every HUD piece steps out: photo mode's `entered` and `left` throw
##   the HUD's one "hud hidden" switch (scripts/hand_materials.gd
##   `hud_hidden`), whichever way the mode was entered.
##
## - **Lens** opens the command palette (scripts/command_palette.gd), as Cmd K
##   and / do. Two slots fit across the roll's width, so it sits centred on a
##   second row.
##
## It is placed from the roll's actual rect each frame, so it follows the roll
## as it tucks at rest and as the roll grows (the Feather will make it taller).
## It rests and wakes with the roll, sharing its `shown` and `awake` rather
## than keeping its own: the pointer over the foot is within the roll's reach,
## and a drag that keeps the roll quiet keeps the foot quiet too. A hovered
## slot shows the 4c side tag to the right, as the roll's does, with its
## whisper (lowpoly.js ROLL_FOOT_WHISPER) on a second line in Spectral.
##
## It only draws and acts on presses the hand gives it (scripts/hand_materials.gd
## `press`, which asks `press` first); `contains_pointer` makes the hand treat
## it as UI (`tray_under`).

const Linen = preload("res://scripts/hud_linen.gd")
const ClaySound = preload("res://scripts/clay_sound.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const WHISPER_FONT = preload("res://assets/fonts/spectral-latin-400.woff2")
## The slots, left to right, and each one's whisper (ROLL_FOOT_WHISPER).
const SLOTS := ["undo","photo","palette"]
const WHISPERS := {"undo":"or Cmd Z","photo":"the cloth steps out of the shot","palette":"reach for anything · or Cmd K"}
## Slots to a row; a last row with fewer is centred.
const COLUMNS := 2
## Layout, design pixels: the gap under the roll; the foot's slot and icon
## sizes; its padding and the gap between the slots (6+32+4+32+6 is the
## roll's 80); the cloth's corner radius and its hem (inset, radius).
const FOOT_GAP := 8.0
const SLOT := 32.0
const ICON := 24.0
const PAD := 6.0
const GAP := 4.0
const RADIUS := 10.0
const HEM := Vector2(4.0,7.0)
## The pressed and hover patch's corner radius on these smaller slots.
const SLOT_RADIUS := 7.0
## The icon's drop shadow, design pixels below it (lowpoly.js `shadowY`).
const ICON_SHADOW_Y := 2.0
## The tag: its gap right of the foot (the roll's tag sits the same 4 px right
## of the roll), its padding (left, top, right, bottom), and the whisper line:
## Spectral at WHISPER_SIZE, its baseline WHISPER_DROP under the caps' rule,
## in WHISPER_INK (AIR_TOKENS.whisperInk).
const TAG_GAP := 4.0
const TAG_PAD := Vector4(12.0,6.0,10.0,7.0)
const WHISPER_SIZE := 13.0
const WHISPER_DROP := 16.0
const WHISPER_DESCENT := 4.0
const WHISPER_INK := Color("d6cbb2")
## Hover and press take HOVER_TIME s (the Motion table's 150 ms, linear).
const HOVER_TIME := 0.15

## The roll it hangs under, and the hand's materials node that owns the HUD
## (for the editor, the scene and the hud-hidden switch).
var roll: Control
var materials: Node
var ui_scale := 1.0
var shown := 0.0
var awake := 0.0
var hovered := ""
var pointer_override: Variant = null
## Presses taken, for probes: {"undo": n, "photo": n}.
var presses := {"undo":0,"photo":0,"palette":0}
var _font: FontVariation
var _whisper_font: Font
var _textures := {}
var _texture_px := 0.0
var _cloth: Linen.Cloth
var _tag_cloth: Linen.Cloth
var _states := {}
var _photo_linked: Node = null

func setup(tool_roll: Control, hand_materials: Node) -> void:
	roll = tool_roll
	materials = hand_materials

func _ready() -> void:
	name = "ToolFoot"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = Linen.tag_font()
	_whisper_font = WHISPER_FONT
	_cloth = Linen.Cloth.new()
	add_child(_cloth)
	_tag_cloth = Linen.Cloth.new()
	add_child(_tag_cloth)
	for id: String in SLOTS: _states[id] = {"hover":0.0,"press":0.0}
	modulate.a = 0.0
	visible = false

# --- Reading the pointer --------------------------------------------------------

## The foot's cloth, viewport pixels: FOOT_GAP under the roll's rect, as wide.
func rect() -> Rect2:
	if roll == null: return Rect2()
	var above: Rect2 = roll.rect()
	var rows := ceili(SLOTS.size()/float(COLUMNS))
	var height := roundf((PAD*2.0+SLOT*rows+GAP*(rows-1))*ui_scale)
	return Rect2(Vector2(above.position.x,above.end.y+roundf(FOOT_GAP*ui_scale)),Vector2(above.size.x,height))

func _cell(i: int) -> Rect2:
	var foot := rect()
	var row := i/COLUMNS
	var in_row := mini(COLUMNS,SLOTS.size()-row*COLUMNS)
	var x := (COLUMNS-in_row)*(SLOT+GAP)*0.5+(SLOT+GAP)*(i%COLUMNS)
	return Rect2((foot.position+Vector2(PAD+x,PAD+(SLOT+GAP)*row)*ui_scale).round(),Vector2.ONE*roundf(SLOT*ui_scale))

## The slot under a viewport point ("undo", "photo"), or "".
func slot_at(point: Vector2) -> String:
	if shown < 0.5: return ""
	for i in range(SLOTS.size()):
		if _cell(i).has_point(point): return SLOTS[i]
	return ""

func slot_centre(id: String) -> Vector2:
	return _cell(SLOTS.find(id)).get_center()

func contains_pointer(point: Vector2) -> bool:
	return shown >= 0.5 and rect().grow(2.0*ui_scale).has_point(point)

# --- Presses --------------------------------------------------------------------

## A left press the hand passed on. True when it was the foot's (a press on
## the cloth between the slots is swallowed, as the roll's is).
func press(point: Vector2) -> bool:
	var id := slot_at(point)
	if id.is_empty(): return contains_pointer(point)
	_states[id].press = 1.0
	presses[id] = int(presses[id])+1
	match id:
		"undo":
			ClaySound.cue(&"ui_undo")
			undo()
		"photo":
			ClaySound.cue(&"ui_shutter")
			photo()
		"palette":
			if materials != null and materials.palette != null: materials.palette.open()
	return true

## Cmd Z's own path. With nothing to undo it quietly does nothing.
func undo() -> void:
	var editor: Node = materials.reach._editor() if materials != null and materials.reach != null else null
	if editor != null: editor.undo()

## Into photo mode; the switch drops the HUD when the mode says it has entered.
func photo() -> void:
	if materials == null: return
	_link_photo()
	var scene: Node = materials.scene
	if scene.has_method("enter_photo"): scene.enter_photo()
	elif scene.get("photo") != null: scene.photo.enter()

## Photo mode throws the hud-hidden switch however it was entered (P, this
## foot, the Lantern shell while it lasts).
func _link_photo() -> void:
	if materials == null or materials.scene == null: return
	var mode: Node = materials.scene.get("photo")
	if mode == null or mode == _photo_linked: return
	_photo_linked = mode
	mode.entered.connect(func() -> void: materials.hud_hidden = true)
	mode.left.connect(func() -> void: materials.hud_hidden = false)

# --- Frames ---------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	if roll == null: return
	_link_photo()
	# It rests and wakes with the roll, and is hidden whenever the roll is.
	shown = roll.shown
	awake = roll.awake
	if not is_equal_approx(roll.ui_scale,ui_scale) or _textures.is_empty():
		ui_scale = roll.ui_scale
		var px := ICON*ui_scale
		if not is_equal_approx(px,_texture_px) or _textures.is_empty():
			_texture_px = px
			Linen.rasterise(_textures,SLOTS,px)
	visible = shown > 0.0
	for id: String in SLOTS: _states[id].press = move_toward(float(_states[id].press),0.0,delta/HOVER_TIME)
	if not visible:
		hovered = ""
		return
	modulate.a = Linen.eased(shown)*lerpf(Linen.REST_OPACITY,1.0,Linen.eased(awake))
	var pointer: Variant = pointer_override if pointer_override != null else roll.pointer_override
	if pointer == null: pointer = get_viewport().get_mouse_position()
	var was_hovered := hovered
	hovered = slot_at(pointer) if awake > 0.5 and not roll.quiet else ""
	if hovered != was_hovered and not hovered.is_empty(): ClaySound.cue(&"ui_hover")
	for id: String in SLOTS:
		var state: Dictionary = _states[id]
		state.hover = move_toward(float(state.hover),1.0 if id == hovered else 0.0,delta/HOVER_TIME)
	_cloth.place(rect(),ui_scale,RADIUS,HEM)
	var tag := _tag_rect()
	_tag_cloth.visible = tag.size.x > 0.0
	if _tag_cloth.visible: _tag_cloth.place(tag,ui_scale,2.0,Vector2.ZERO)
	_tag_cloth.modulate.a = Linen.eased(_tag_hover())
	queue_redraw()

## The slot whose tag shows (the hovered one, or the one fading out) and how far.
func _tag_slot() -> String:
	var best := ""
	var most := 0.0
	for id: String in SLOTS:
		if float(_states[id].hover) > most:
			most = float(_states[id].hover)
			best = id
	return best

func _tag_hover() -> float:
	var id := _tag_slot()
	return float(_states[id].hover) if not id.is_empty() else 0.0

## The tag's two lines: the 4c caps label and the whisper.
func tag_text(id: String) -> Array:
	return [str(Icons.item(id).get("label","")),str(WHISPERS.get(id,""))]

## The hovered slot's tag strip, right of the foot, centred on the slot.
func _tag_rect() -> Rect2:
	var id := _tag_slot()
	if id.is_empty(): return Rect2()
	var lines := tag_text(id)
	var caps := Linen.tag_width(_font,lines[0],ui_scale)
	var whisper := _whisper_font.get_string_size(lines[1],HORIZONTAL_ALIGNMENT_LEFT,-1,_whisper_size()).x
	var width := maxf(caps,whisper)
	var height := (Linen.TAG_SIZE+4.0+WHISPER_DROP+WHISPER_DESCENT)*ui_scale
	var extent := Vector2(width+(TAG_PAD.x+TAG_PAD.z)*ui_scale,height+(TAG_PAD.y+TAG_PAD.w)*ui_scale)
	var cell := _cell(SLOTS.find(id))
	return Rect2(Vector2(rect().end.x+TAG_GAP*ui_scale,roundf(cell.get_center().y-extent.y*0.5)),extent.round())

func _whisper_size() -> int:
	return maxi(6,roundi(WHISPER_SIZE*ui_scale))

func _draw() -> void:
	for i in range(SLOTS.size()):
		var id: String = SLOTS[i]
		var state: Dictionary = _states[id]
		var cell := _cell(i)
		var h := maxf(Linen.eased(state.hover)*0.5,Linen.eased(state.press))
		if h > 0.0: _patch(cell,Color(Linen.PRESSED,Linen.PRESSED.a*h),Color(Linen.PRESSED_SHADE,Linen.PRESSED_SHADE.a*h))
		Linen.icon(self,_textures,id,cell.get_center(),ICON*ui_scale,ui_scale,"icon",ICON_SHADOW_Y)
	var tag := _tag_rect()
	var alpha := Linen.eased(_tag_hover())
	if tag.size.x > 0.0 and alpha > 0.0:
		var lines := tag_text(_tag_slot())
		var caps := Linen.tag_width(_font,lines[0],ui_scale)
		var left := tag.position.x+TAG_PAD.x*ui_scale
		var rule_y := tag.position.y+(TAG_PAD.y+Linen.TAG_SIZE+4.0)*ui_scale
		Linen.tag(self,_font,lines[0],left+caps*0.5,rule_y,ui_scale,alpha)
		draw_string(_whisper_font,Vector2(roundf(left),roundf(rule_y+WHISPER_DROP*ui_scale)),lines[1],HORIZONTAL_ALIGNMENT_LEFT,-1,_whisper_size(),Color(WHISPER_INK,alpha))

## The 4c pressed patch at the foot's smaller radius: hover is half of it
## (README: "hover = half patch"), a press the whole.
func _patch(rect_in: Rect2, patch: Color, shade: Color) -> void:
	Linen.fill_round(self,rect_in,SLOT_RADIUS*ui_scale,patch)
	for i in range(3):
		var h := (2.0+i*1.6)*ui_scale
		var box := StyleBoxFlat.new()
		box.bg_color = Color(shade,shade.a*0.34)
		box.corner_radius_top_left = int(round(SLOT_RADIUS*ui_scale))
		box.corner_radius_top_right = box.corner_radius_top_left
		box.corner_radius_bottom_left = int(round(minf(SLOT_RADIUS*ui_scale,h*0.5)))
		box.corner_radius_bottom_right = box.corner_radius_bottom_left
		box.anti_aliasing = true
		draw_style_box(box,Rect2(rect_in.position,Vector2(rect_in.size.x,h)))
