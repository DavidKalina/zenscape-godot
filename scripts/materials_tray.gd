extends Control
## The materials bar (design "ZenScape HUD 4c", scripts/hud_linen.gd;
## docs/design/materials-tray/HUD-4c.md): a strip of linen in shadow along
## the bottom edge, one faceted low-poly icon to a slot (scripts/hud_icons.gd).
## Seeds, then water and stones, then frost, each group parted by a double
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
## hand. The material in hand is pressed into the cloth, its icon lit, and its
## name printed on the linen above it in small caps over a hairline.

const Linen = preload("res://scripts/hud_linen.gd")
const ClaySound = preload("res://scripts/clay_sound.gd")
const Icons = preload("res://scripts/hud_icons.gd")
## The bar, in order: id (what the hand holds) and group. Those marked
## "hidden" are not found yet: a silhouette only.
const SPECIMENS := [
	{"id":"oak","group":0},
	{"id":"pine","group":0},
	{"id":"willow","group":0},
	{"id":"wildflower","group":0},
	{"id":"dandelion","group":0},
	{"id":"poppy","group":0},
	{"id":"cosmos","group":0},
	{"id":"sunflower","group":0},
	{"id":"reed","group":0},
	{"id":"water","group":1},
	{"id":"stone","group":1},
	{"id":"crystal","group":1,"hidden":true},
	{"id":"snow","group":2,"hidden":true},
]
## Layout, design pixels: the gap between slots, a group divider's width (two
## lines 4 px apart) and height, the padding (the top holds the tag) and the
## bar's lift off the bottom edge. At rest it sinks REST_SINK.
const GAP := 4.0
const DIVIDER_W := 5.0
const DIVIDER_H := 40.0
const PAD_TOP := 30.0
const PAD_SIDE := 12.0
const PAD_BOTTOM := 10.0
const BOTTOM := 22.0
const REST_SINK := 8.0
## Within NEAR of the bottom edge it is reached for.
const NEAR := 150.0
## Seconds for a slot's hover patch, and a hidden slot's quiet refusal.
const HOVER_TIME := 0.15
const NOT_YET := 0.45

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
## Per slot: "hover", "refuse" (0..1, linear).
var _states := {}

func _ready() -> void:
	name = "MaterialsTray"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = Linen.tag_font()
	_cloth = Linen.Cloth.new()
	add_child(_cloth)
	for entry: Dictionary in SPECIMENS: _states[entry.id] = {"hover":0.0,"refuse":0.0}
	modulate.a = 0.0
	visible = false

## Show or hide it, eased.
func want(on: bool) -> void:
	_want_shown = on

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
	var scale_now := Linen.scale_for(screen)
	if not is_equal_approx(scale_now,ui_scale) or _textures.is_empty():
		ui_scale = scale_now
		_rasterise()
	var pointer: Vector2 = get_viewport().get_mouse_position() if pointer_override == null else pointer_override
	shown = move_toward(shown,1.0 if _want_shown else 0.0,delta/Linen.REACH)
	var near := _want_shown and not quiet and (screen.y-pointer.y <= NEAR*ui_scale or (awake > 0.0 and _bar().grow(6.0*ui_scale).has_point(pointer)))
	if near:
		_away = 0.0
		if awake == 0.0: ClaySound.cue(&"ui_reach")
		awake = move_toward(awake,1.0,delta/Linen.REACH)
	else:
		_away += delta
		if _away >= Linen.HOLD: awake = move_toward(awake,0.0,delta/Linen.RECEDE)
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
	queue_redraw()

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
		if entry.get("hidden",false):
			var warm := Linen.eased(state.refuse)*0.25
			Linen.icon(self,_textures,entry.id,cell.get_center(),Linen.ICON*ui_scale,ui_scale,"locked",0.0,Color.WHITE.lerp(Color(1.25,1.2,1.1),warm))
			continue
		Linen.icon(self,_textures,entry.id,cell.get_center(),Linen.ICON*ui_scale,ui_scale,"lit" if on else "icon",1.0 if on else 2.0)
	# The held material's name, printed on the linen over its slot.
	if not held.is_empty() and _index(held) >= 0:
		var cell := _cell(_index(held))
		Linen.tag(self,_font,str(Icons.item(held).get("label","")),cell.get_center().x,cell.position.y-6.0*ui_scale,ui_scale,1.0)
