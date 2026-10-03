extends Control
## The materials bar (design "ZenScape HUD 4c", scripts/hud_linen.gd;
## docs/design/materials-tray/HUD-4c.md): a strip of linen in shadow along
## the bottom edge, one faceted low-poly icon to a slot (scripts/hud_icons.gd).
## Seeds, then water, stones and the footbridge, then frost, each group parted by a double
## stitched line. What you ADD to the world; the tool roll on the left
## (scripts/tool_roll.gd) holds how you shape it. Kinds not found yet show
## only their silhouette in pale linen.
##
## It only draws; the hand (scripts/hand_materials.gd) reads `specimen_at` and
## `contains_pointer` and takes the presses, and it never takes a right press,
## so the camera's drag starts over it as anywhere.
##
## Nothing bounces or loops. It rests receded (REST_OPACITY, sunk REST_SINK)
## and rises as the pointer nears the bottom edge; a drag in progress never
## wakes it, so pulling the plate's near rim down does not raise it under the
## hand. The material in hand is pressed into the cloth, its icon lit. Its
## name, or the hovered slot's, shows on a small tag of linen over the bar, in
## small caps over a hairline.

const Linen = preload("res://scripts/hud_linen.gd")
const ClaySound = preload("res://scripts/clay_sound.gd")
const Icons = preload("res://scripts/hud_icons.gd")
## The bar, in order: id (what the hand holds) and group. Those marked
## "hidden" are not found yet: a silhouette only.
const SPECIMENS := [
	{"id":"oak","group":0},
	{"id":"pine","group":0},
	{"id":"willow","group":0},
	{"id":"birch","group":0},
	{"id":"redwood","group":0},
	{"id":"juniper","group":0},
	{"id":"joshua","group":0},
	{"id":"wildflower","group":0},
	{"id":"dandelion","group":0},
	{"id":"poppy","group":0},
	{"id":"cosmos","group":0},
	{"id":"sunflower","group":0},
	{"id":"reed","group":0},
	{"id":"water","group":1},
	{"id":"stone","group":1},
	{"id":"lamp","group":1},
	{"id":"fence","group":1},
	{"id":"bridge","group":1},
	{"id":"crystal","group":1,"hidden":true},
	{"id":"snow","group":2,"hidden":true},
]
## Layout, design pixels: the gap between slots, a group divider's width (two
## lines 4 px apart) and height, the padding and the bar's lift off the bottom
## edge. At rest it sinks REST_SINK. The name of the slot hovered or in hand is
## on its own scrap of linen TAG_GAP over the bar: TAG_PAD (x, y) round the
## small caps, coming and going over TAG_TIME s.
const GAP := 4.0
const DIVIDER_W := 5.0
const DIVIDER_H := 40.0
const PAD_TOP := 10.0
const TAG_GAP := 6.0
const TAG_PAD := Vector2(10.0,6.0)
const TAG_TIME := 0.15
const PAD_SIDE := 12.0
const PAD_BOTTOM := 10.0
const BOTTOM := 22.0
const REST_SINK := 8.0
## Within NEAR of the bottom edge it is reached for.
const NEAR := 150.0
## Seconds for a slot's hover patch, and a hidden slot's quiet refusal.
const HOVER_TIME := 0.15
const NOT_YET := 0.45
## First steps (scripts/first_steps_card.gd) points at a pocket with `nudge`:
## the ring takes NUDGE_FADE s to come and go and breathes once every
## NUDGE_PERIOD s.
const NUDGE_FADE := 0.5
const NUDGE_PERIOD := 3.0

var ui_scale := 1.0
## 0..1 how shown it is (a world open, nothing over it), and how reached for.
var shown := 0.0
var awake := 0.0
## The material the hand holds, or "".
var held := ""
## The slot under the pointer, or "".
var hovered := ""
## True while a drag is under way elsewhere: the bar does not wake.
var quiet := false
## Headless probes have no pointer: where they say it is.
var pointer_override: Variant = null
var _want_shown := false
var _away := 0.0
var _font: FontVariation
var _textures := {}
var _texture_px := 0.0
var _cloth: Linen.Cloth
## The name tag over the bar: its cloth, the slot it names and how shown it is.
var _tag_cloth: Linen.Cloth
var _tag_for := ""
var _tag_a := 0.0
## Per slot: "hover", "refuse" (0..1, linear).
var _states := {}
## The pocket the first-steps card is pointing at, or "". While one is
## pointed at the bar stays reached for and that pocket is stitched round, slowly.
var nudged := ""
var _nudge_for := ""
var _nudge_a := 0.0
var _nudge_t := 0.0

func _ready() -> void:
	name = "MaterialsTray"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = Linen.tag_font()
	_cloth = Linen.Cloth.new()
	add_child(_cloth)
	_tag_cloth = Linen.Cloth.new()
	add_child(_tag_cloth)
	for entry: Dictionary in SPECIMENS: _states[entry.id] = {"hover":0.0,"refuse":0.0}
	modulate.a = 0.0
	visible = false

## Show or hide it, eased.
func want(on: bool) -> void:
	_want_shown = on

## Points at slot `id` (a SPECIMENS id), or at none with "": the bar stays reached for (a
## drag still keeps it quiet) and the pocket is stitched round and lifts a
## little, over and over, until it is cleared.
func nudge(id: String) -> void:
	nudged = id
	if not id.is_empty(): _nudge_for = id

## The nudge's frame: its ring comes and goes eased, and breathes while it is on.
func _nudge_step(delta: float) -> void:
	_nudge_a = move_toward(_nudge_a,1.0 if not nudged.is_empty() else 0.0,delta/NUDGE_FADE)
	_nudge_t = fposmod(_nudge_t+delta,NUDGE_PERIOD)
	if _nudge_a <= 0.0: _nudge_for = ""

## The pointing ring on `cell`: a faint lift of the hover patch and a stitched
## ring in the pip's stitch, both breathing. Nothing without a nudge.
func _nudge_ring(item: CanvasItem, cell: Rect2, line: float, radius: float) -> void:
	var a := Linen.eased(_nudge_a)
	if a <= 0.0: return
	var breath := 0.5-0.5*cos(_nudge_t/NUDGE_PERIOD*TAU)
	Linen.pressed_patch(item,cell,ui_scale,Color(Linen.HOVER,Linen.HOVER.a*a*breath),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*a*breath))
	var ring := cell.grow((1.0-3.0*breath)*ui_scale)
	Linen.dashed_round(item,ring,radius*ui_scale,Color(Linen.PIP_STITCH,Linen.PIP_STITCH.a*a*(0.45+0.55*breath)),line,ui_scale)

## False for a slot whose kind has not been found.
func discovered(id: String) -> bool:
	var entry := _entry(id)
	return not entry.is_empty() and not entry.get("hidden",false)

func _entry(id: String) -> Dictionary:
	for entry: Dictionary in SPECIMENS:
		if entry.id == id: return entry
	return {}

# --- Reading the pointer --------------------------------------------------------

## The slot under a viewport point, or "". Undiscovered ones count.
func specimen_at(point: Vector2) -> String:
	if shown < 0.5: return ""
	for i in range(SPECIMENS.size()):
		if _cell(i).has_point(point): return SPECIMENS[i].id
	return ""

## True over the bar.
func contains_pointer(point: Vector2) -> bool:
	return shown >= 0.5 and _bar().grow(2.0*ui_scale).has_point(point)

## A slot's centre, in viewport pixels.
func specimen_centre(id: String) -> Vector2:
	var i := _index(id)
	if i < 0: return _bar().get_center()
	return _cell(i).get_center()

func _index(id: String) -> int:
	for i in range(SPECIMENS.size()):
		if SPECIMENS[i].id == id: return i
	return -1

func _width() -> float:
	var n := SPECIMENS.size()
	return PAD_SIDE*2.0+Linen.SLOT*n+GAP*(n-1)+(DIVIDER_W+GAP)*int(SPECIMENS.back().group)

## The bar, viewport pixels.
func _bar() -> Rect2:
	var height := PAD_TOP+Linen.SLOT+PAD_BOTTOM
	var extent := Vector2(_width(),height)*ui_scale
	var sink := REST_SINK*(1.0-Linen.eased(awake))*ui_scale
	return Rect2(Vector2(roundf((size.x-extent.x)*0.5),roundf(size.y-(BOTTOM+height)*ui_scale+sink)),extent.round())

## A slot's rect, viewport pixels.
func _cell(i: int) -> Rect2:
	var bar := _bar()
	var x := PAD_SIDE+(Linen.SLOT+GAP)*i+(DIVIDER_W+GAP)*int(SPECIMENS[i].group)
	return Rect2((bar.position+Vector2(x,PAD_TOP)*ui_scale).round(),Vector2.ONE*roundf(Linen.SLOT*ui_scale))

# --- Reactions ------------------------------------------------------------------

## The hand takes `id`: its slot is pressed into the cloth.
func lift_out(id: String) -> void:
	held = id

## The material goes back: its slot comes up again. (`_from`, where the hand
## let it go, is kept for the API; nothing glides.)
func return_home(id: String, _from := Vector2.ZERO) -> void:
	if held == id: held = ""

## A press on a slot not found yet: its silhouette warms a little and cools
## again. Nothing is given.
func not_yet(id: String) -> void:
	if _states.has(id): _states[id].refuse = 1.0
	ClaySound.cue(&"ui_refuse")

# --- Frames ---------------------------------------------------------------------

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var screen := get_viewport().get_visible_rect().size
	var scale_now := Linen.hud_scale_for(screen)
	if not is_equal_approx(scale_now,ui_scale) or _textures.is_empty():
		ui_scale = scale_now
		_rasterise()
	var pointer: Vector2 = get_viewport().get_mouse_position() if pointer_override == null else pointer_override
	shown = move_toward(shown,1.0 if _want_shown else 0.0,delta/Linen.REACH)
	var near := _want_shown and not quiet and (screen.y-pointer.y <= NEAR*ui_scale or (awake > 0.0 and _bar().grow(6.0*ui_scale).has_point(pointer)) or not nudged.is_empty())
	if near:
		_away = 0.0
		if awake == 0.0: ClaySound.cue(&"ui_reach")
		awake = move_toward(awake,1.0,delta/Linen.REACH)
	else:
		_away += delta
		if _away >= Linen.HOLD: awake = move_toward(awake,0.0,delta/Linen.RECEDE)
	_nudge_step(delta)
	visible = shown > 0.0
	if not visible: return
	modulate.a = Linen.eased(shown)*lerpf(Linen.REST_OPACITY,1.0,Linen.eased(awake))
	var was_hovered := hovered
	hovered = specimen_at(pointer) if _want_shown and awake > 0.5 else ""
	if hovered != was_hovered and not hovered.is_empty() and hovered != held: ClaySound.cue(&"ui_hover")
	for entry: Dictionary in SPECIMENS:
		var state: Dictionary = _states[entry.id]
		var on: bool = entry.id == hovered and entry.id != held and not entry.get("hidden",false)
		state.hover = move_toward(float(state.hover),1.0 if on else 0.0,delta/HOVER_TIME)
		state.refuse = move_toward(float(state.refuse),0.0,delta/NOT_YET)
	_cloth.place(_bar(),ui_scale)
	# The tag names the hovered slot (once found), else what is in hand.
	var named := hovered if not hovered.is_empty() and discovered(hovered) else held
	if not named.is_empty(): _tag_for = named
	_tag_a = move_toward(_tag_a,1.0 if not named.is_empty() and named == _tag_for else 0.0,delta/TAG_TIME)
	var tag := _tag_rect()
	_tag_cloth.visible = tag.size.x > 0.0
	if _tag_cloth.visible: _tag_cloth.place(tag,ui_scale,2.0,Vector2.ZERO)
	_tag_cloth.modulate.a = Linen.eased(_tag_a)
	queue_redraw()

## The name tag's scrap of linen over its slot, or an empty rect for none.
func _tag_rect() -> Rect2:
	if _tag_a <= 0.0 or _index(_tag_for) < 0: return Rect2()
	var cell := _cell(_index(_tag_for))
	var extent := Vector2(Linen.tag_width(_font,_tag_text(),ui_scale)+TAG_PAD.x*2.0*ui_scale,(Linen.TAG_CAPS+TAG_PAD.y*2.0+4.0)*ui_scale)
	return Rect2(Vector2(roundf(cell.get_center().x-extent.x*0.5),roundf(_bar().position.y-TAG_GAP*ui_scale-extent.y)),extent.round())

func _tag_text() -> String:
	return str(Icons.item(_tag_for).get("label",""))

func _rasterise() -> void:
	var px := Linen.ICON*ui_scale
	if is_equal_approx(px,_texture_px) and not _textures.is_empty(): return
	_texture_px = px
	var ids := []
	for entry: Dictionary in SPECIMENS: ids.append(entry.id)
	Linen.rasterise(_textures,ids,px)

func _draw() -> void:
	var line := maxf(1.0,roundf(ui_scale))
	# Group dividers: two stitched lines, 4 px apart.
	for i in range(1,SPECIMENS.size()):
		if SPECIMENS[i].group == SPECIMENS[i-1].group: continue
		var cell := _cell(i)
		var x := cell.position.x-(GAP+DIVIDER_W)*ui_scale
		var top := cell.get_center().y-DIVIDER_H*0.5*ui_scale
		for k in range(2):
			var lx := roundf(x+k*4.0*ui_scale)+line*0.5
			Linen.dashed(self,PackedVector2Array([Vector2(lx,top),Vector2(lx,top+DIVIDER_H*ui_scale)]),Linen.DIVIDER,line,3.0*ui_scale,3.0*ui_scale)
	for i in range(SPECIMENS.size()):
		var entry: Dictionary = SPECIMENS[i]
		var state: Dictionary = _states[entry.id]
		var cell := _cell(i)
		var on: bool = entry.id == held
		if on: Linen.pressed_patch(self,cell,ui_scale,Linen.PRESSED,Linen.PRESSED_SHADE)
		elif float(state.hover) > 0.0:
			var h := Linen.eased(state.hover)
			Linen.pressed_patch(self,cell,ui_scale,Color(Linen.HOVER,Linen.HOVER.a*h),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*h))
		if entry.id == _nudge_for: _nudge_ring(self,cell,line,Linen.SLOT_RADIUS)
		if entry.get("hidden",false):
			var warm := Linen.eased(state.refuse)*0.25
			Linen.icon(self,_textures,entry.id,cell.get_center(),Linen.ICON*ui_scale,ui_scale,"locked",0.0,Color.WHITE.lerp(Color(1.25,1.2,1.1),warm))
			continue
		Linen.icon(self,_textures,entry.id,cell.get_center(),Linen.ICON*ui_scale,ui_scale,"lit" if on else "icon",1.0 if on else 2.0)
	# The name of the slot hovered or in hand, on its tag over the bar.
	var tag := _tag_rect()
	if tag.size.x > 0.0: Linen.tag(self,_font,_tag_text(),tag.get_center().x,tag.end.y-TAG_PAD.y*ui_scale,ui_scale,Linen.eased(_tag_a))
