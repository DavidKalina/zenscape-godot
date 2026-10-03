extends Control
## The tool roll (design "ZenScape HUD 4c", scripts/hud_linen.gd;
## docs/design/materials-tray/HUD-4c.md): a canvas roll of the same linen on
## the left edge, one shaping tool tucked into each stitched pocket, and under
## a double stitched line three pips for the size of whatever is in hand.
## What the hand SHAPES with; the materials bar (scripts/materials_tray.gd)
## holds what it adds. One thing is in hand across both: the Modeller (the
## first pocket, id `hand`, a sculptor's boxwood modelling tool) unless a
## material is taken, and then the Modeller's pocket is stitched round faintly,
## "put this down".
##
## The tools not built yet show as undiscovered silhouettes (UNBUILT) until
## each has its verbs: a tool is built when scripts/clay_tools/<id>.gd holds
## them (docs/design/tools/PLAN.md) and it is taken off UNBUILT.
##
## A tool with modes (scripts/clay_tools/clay_tool.gd `modes`: the Modeller,
## the Paddle, the Chisel, the Wire) has them fanned out beside its
## pocket in place of its name: a small icon each (scripts/hud_icons.gd
## "<tool>_<mode>"), the one in hand pressed into the cloth. The fan stays
## shown at rest so the mode can be read while working. The hand sets `modes`
## and `mode` when it takes a tool.
##
## The tools that tend rather than shape (TOP: the Feather, the can, the
## Brush) sit on a second, short strip of the same linen along the top edge,
## so the roll stays short enough for the screen. It is the same roll: one
## tool in hand across both, and a top tool's fan drops down under the strip
## rather than out to the side. Each piece rests and wakes on its own reach.
##
## It only draws; the hand (scripts/hand_materials.gd) reads `tool_at`,
## `pip_at`, `mode_at` and `contains_pointer` and takes the presses. It rests receded
## (REST_OPACITY, tucked REST_TUCK) and comes out as the pointer nears the
## left edge; a drag in progress never wakes it.

const Linen = preload("res://scripts/hud_linen.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const ClaySound = preload("res://scripts/clay_sound.gd")
## Every tool. The Feather (HUD 5, "Gust") holds wind, the watering can
## ("Pour") water and the Brush ("Paint") colour, not clay: they are TOP, on
## the strip along the top edge, left to right; the rest go down the roll.
const TOOLS := ["hand","hills","mountain","wire","chisel","paddle","hammer","feather","can","brush"]
const TOP := ["feather","can","brush"]
## Places on the roll (not indices in TOOLS) that a stitched divider sits
## above (lowpoly.js TOOL_DIVIDER_BEFORE); none since the Feather went up top.
const DIVIDER_BEFORE := []
## The fan beside a tool with modes: a cell (design pixels) and icon each,
## the fan's padding, and the seconds it takes to fan out.
const MODE_CELL := 46.0
const MODE_ICON := 36.0
const MODE_PAD := 4.0
const FAN_TIME := 0.18
## The swatch strip under the fan while the mode in hand lays a colour (the
## Brush's Colour): a cell and swatch diameter each (design pixels), and the
## gap between it and the fan. Its last cell opens the full picker.
const SWATCH_CELL := 26.0
const SWATCH_PIP := 16.0
const SWATCH_GAP := 4.0
## Tools without verbs yet: shown as undiscovered.
const UNBUILT := []
## Sizes: the pip's diameter and hit cell (design pixels) and the scale it
## gives the held thing's reach (the clay's radii, a scatter's spread).
const SIZES := [{"pip":8.0,"cell":16.0,"scale":0.6},{"pip":12.0,"cell":20.0,"scale":1.0},{"pip":18.0,"cell":24.0,"scale":1.5}]
## Layout, design pixels: the roll's inset from the left edge, its padding,
## the gap between slots, the divider block's height (lines 40 wide, 3 apart,
## 6 of padding each side), the pips' row, and the tag's offset from a slot's
## left edge. At rest it tucks REST_TUCK to the left.
const LEFT := 24.0
const PAD := Vector2(10.0,12.0)
const GAP := 4.0
const DIVIDER := 17.0
const PIPS_H := 30.0
const TAG_LEFT := 74.0
const TAG_PAD := Vector4(12.0,6.0,10.0,7.0)
const REST_TUCK := 6.0
## Within NEAR of the left edge it is reached for.
const NEAR := 180.0
## The top strip: its inset from the top edge, and within NEAR_TOP of the top
## edge it is reached for. At rest it tucks REST_TUCK up. Its fan or tag hangs
## HANG under the strip.
const TOP_INSET := 18.0
const NEAR_TOP := 120.0
const HANG := 6.0
## The pocket: its height, inset in the slot, bottom radius; the icon sits
## LIFT higher so it reads as tucked in.
const POCKET_H := 22.0
const POCKET_INSET := 5.0
const POCKET_RADIUS := 7.0
const LIFT := 6.0
const HOVER_TIME := 0.15
const NOT_YET := 0.45

var ui_scale := 1.0
var shown := 0.0
var awake := 0.0
## How far the top strip is reached for, as `awake` is the roll's.
var awake_top := 0.0
## The tool in hand, and whether a material is held instead (then no tool is
## pressed and the Modeller's pocket shows the put-down cue).
var tool := "hand"
var material_held := false
## The size level (index into SIZES) and the held thing's tint for its pip.
var size_level := 1
var held_tint := Color("e0a07a")
var hovered := ""
## The tool in hand's mode ids (empty for none), the one in hand, and the
## one under the pointer.
var modes: Array = []
var mode := ""
var hovered_mode := ""
## How far the Sculpt's fan is out, 0..1.
var fan := 0.0
## The swatch strip's colours (sRGB, empty for none), the colour in hand and
## the cell under the pointer (a swatch index, swatches.size() for the
## picker, -1 for none); `picker` false when the strip has no picker's cell
## (clay_tool `picks`).
var swatches: Array = []
var colour := Color.WHITE
var picker := true
var hovered_swatch := -1
var quiet := false
var pointer_override: Variant = null
var _want_shown := false
var _away := 0.0
var _away_top := 0.0
## The tools down the roll (TOOLS less TOP), and the top strip's layer, drawn
## over the roll so it can rest and wake apart from it.
var _side: Array = TOOLS.filter(func(id: String) -> bool: return not id in TOP)
var _top_layer := Control.new()
var _top_cloth: Linen.Cloth
var _font: FontVariation
var _textures := {}
var _texture_px := 0.0
var _cloth: Linen.Cloth
var _tag_cloth: Linen.Cloth
var _swatch_cloth: Linen.Cloth
var _picker_popup: PopupPanel
var _states := {}

func _ready() -> void:
	name = "ToolRoll"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_font = Linen.tag_font()
	_cloth = Linen.Cloth.new()
	add_child(_cloth)
	_tag_cloth = Linen.Cloth.new()
	add_child(_tag_cloth)
	_swatch_cloth = Linen.Cloth.new()
	add_child(_swatch_cloth)
	_top_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_top_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_top_layer)
	_top_cloth = Linen.Cloth.new()
	_top_layer.add_child(_top_cloth)
	_top_layer.draw.connect(func() -> void: _paint(_top_layer,true))
	for id: String in TOOLS: _states[id] = {"hover":0.0,"refuse":0.0}
	modulate.a = 0.0
	visible = false

func want(on: bool) -> void:
	_want_shown = on

func discovered(id: String) -> bool:
	return id in TOOLS and not id in UNBUILT

## The size scale in hand.
func size_scale() -> float:
	return float(SIZES[size_level].scale)

# --- Reading the pointer --------------------------------------------------------

## The tool under a viewport point, or "". Undiscovered ones count.
func tool_at(point: Vector2) -> String:
	if shown < 0.5: return ""
	for i in range(TOOLS.size()):
		if _cell(i).has_point(point): return TOOLS[i]
	return ""

## The Sculpt mode word under a viewport point, or "".
func mode_at(point: Vector2) -> String:
	if shown < 0.5 or not _modes_shown(): return ""
	var cells := _mode_cells()
	for k in range(cells.size()):
		if (cells[k] as Rect2).has_point(point): return modes[k]
	return ""

## The swatch strip's cell under a viewport point: a swatch's index,
## `swatches.size()` for the picker, or -1.
func swatch_at(point: Vector2) -> int:
	if shown < 0.5 or not _swatches_shown(): return -1
	for k in range(_swatch_cells()):
		if _swatch_cell(k).has_point(point): return k
	return -1

## The size pip under a viewport point, or -1.
func pip_at(point: Vector2) -> int:
	if shown < 0.5: return -1
	for i in range(SIZES.size()):
		if _pip_cell(i).has_point(point): return i
	return -1

func contains_pointer(point: Vector2) -> bool:
	if picker_open(): return true
	return shown >= 0.5 and (_roll().grow(2.0*ui_scale).has_point(point) or _strip().grow(2.0*ui_scale).has_point(point) or (_modes_shown() and _tag_rect().has_point(point)) or (_swatches_shown() and _swatch_rect().has_point(point)))

## The roll's cloth, viewport pixels (the foot, scripts/tool_foot.gd, hangs under it).
func rect() -> Rect2:
	return _roll()

func _height() -> float:
	return PAD.y*2.0+Linen.SLOT*_side.size()+GAP*(_side.size()+1)+DIVIDER*(1+DIVIDER_BEFORE.size())+PIPS_H

## Design pixels of tool dividers above slot `i` (each is one DIVIDER block).
func _dividers_above(i: int) -> float:
	var count := 0
	for at: int in DIVIDER_BEFORE:
		if at <= i: count += 1
	return DIVIDER*count

func _roll() -> Rect2:
	var extent := Vector2(PAD.x*2.0+Linen.SLOT,_height())*ui_scale
	var tuck := REST_TUCK*(1.0-Linen.eased(awake))*ui_scale
	return Rect2(Vector2(roundf(LEFT*ui_scale-tuck),roundf((size.y-extent.y)*0.5)),extent.round())

## The top strip's cloth, viewport pixels: centred along the top edge.
func _strip() -> Rect2:
	var extent := Vector2(PAD.y*2.0+Linen.SLOT*TOP.size()+GAP*(TOP.size()-1),PAD.x*2.0+Linen.SLOT)*ui_scale
	var tuck := REST_TUCK*(1.0-Linen.eased(awake_top))*ui_scale
	return Rect2(Vector2(roundf((size.x-extent.x)*0.5),roundf(TOP_INSET*ui_scale-tuck)),extent.round())

## Tool `i` of TOOLS's slot, on the roll or the top strip.
func _cell(i: int) -> Rect2:
	var id: String = TOOLS[i]
	if id in TOP:
		var strip := _strip()
		return Rect2((strip.position+Vector2(PAD.y+(Linen.SLOT+GAP)*TOP.find(id),PAD.x)*ui_scale).round(),Vector2.ONE*roundf(Linen.SLOT*ui_scale))
	var j := _side.find(id)
	var roll := _roll()
	return Rect2((roll.position+Vector2(PAD.x,PAD.y+(Linen.SLOT+GAP)*j+_dividers_above(j))*ui_scale).round(),Vector2.ONE*roundf(Linen.SLOT*ui_scale))

## True while the tool in hand is one of the top strip's.
func _held_on_top() -> bool:
	return tool in TOP

## The pips' row, and one pip's hit cell.
func _pips() -> Rect2:
	var roll := _roll()
	var y := PAD.y+Linen.SLOT*_side.size()+GAP*(_side.size()+1)+DIVIDER*(1+DIVIDER_BEFORE.size())
	return Rect2(roll.position+Vector2(PAD.x,y)*ui_scale,Vector2(Linen.SLOT,PIPS_H)*ui_scale)

func _pip_cell(i: int) -> Rect2:
	var row := _pips()
	var x := 0.0
	for k in range(i): x += float(SIZES[k].cell)
	return Rect2(row.position+Vector2(x*ui_scale,0.0),Vector2(float(SIZES[i].cell),PIPS_H)*ui_scale)

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
		var px := Linen.ICON*ui_scale
		if not is_equal_approx(px,_texture_px) or _textures.is_empty():
			_texture_px = px
			Linen.rasterise(_textures,TOOLS,px)
	_rasterise_modes()
	var pointer: Vector2 = get_viewport().get_mouse_position() if pointer_override == null else pointer_override
	shown = move_toward(shown,1.0 if _want_shown else 0.0,delta/Linen.REACH)
	fan = move_toward(fan,1.0 if _modes_shown() else 0.0,delta/FAN_TIME)
	var near := _want_shown and not quiet and (pointer.x <= NEAR*ui_scale or (awake > 0.0 and _roll().grow(6.0*ui_scale).has_point(pointer)))
	if near:
		_away = 0.0
		if awake == 0.0: ClaySound.cue(&"ui_reach")
		awake = move_toward(awake,1.0,delta/Linen.REACH)
	else:
		_away += delta
		if _away >= Linen.HOLD: awake = move_toward(awake,0.0,delta/Linen.RECEDE)
	var near_top := _want_shown and not quiet and (pointer.y <= NEAR_TOP*ui_scale or (awake_top > 0.0 and _strip().grow(6.0*ui_scale).has_point(pointer)))
	if near_top:
		_away_top = 0.0
		if awake_top == 0.0: ClaySound.cue(&"ui_reach")
		awake_top = move_toward(awake_top,1.0,delta/Linen.REACH)
	else:
		_away_top += delta
		if _away_top >= Linen.HOLD: awake_top = move_toward(awake_top,0.0,delta/Linen.RECEDE)
	visible = shown > 0.0
	if not visible: return
	# Each piece rests and wakes on its own: the roll's own drawing and cloth,
	# and the top strip's layer.
	modulate.a = Linen.eased(shown)
	var side_alpha := lerpf(Linen.REST_OPACITY,1.0,Linen.eased(awake))
	var top_alpha := lerpf(Linen.REST_OPACITY,1.0,Linen.eased(awake_top))
	self_modulate.a = side_alpha
	_cloth.modulate.a = side_alpha
	_top_layer.modulate.a = top_alpha
	var held_alpha := top_alpha if _held_on_top() else side_alpha
	var held_awake := awake_top if _held_on_top() else awake
	var was_hovered := hovered
	hovered = tool_at(pointer) if _want_shown else ""
	if (hovered in TOP and awake_top <= 0.5) or (not hovered.is_empty() and not hovered in TOP and awake <= 0.5): hovered = ""
	if hovered != was_hovered and discovered(hovered): ClaySound.cue(&"ui_hover")
	var was_mode := hovered_mode
	hovered_mode = mode_at(pointer) if _want_shown else ""
	if hovered_mode != was_mode and not hovered_mode.is_empty(): ClaySound.cue(&"ui_hover")
	var was_swatch := hovered_swatch
	hovered_swatch = swatch_at(pointer) if _want_shown else -1
	if hovered_swatch != was_swatch and hovered_swatch >= 0: ClaySound.cue(&"ui_hover")
	for id: String in TOOLS:
		var state: Dictionary = _states[id]
		var on := id == hovered and not (id == tool and not material_held) and discovered(id)
		state.hover = move_toward(float(state.hover),1.0 if on else 0.0,delta/HOVER_TIME)
		state.refuse = move_toward(float(state.refuse),0.0,delta/NOT_YET)
	_cloth.place(_roll(),ui_scale)
	_top_cloth.place(_strip(),ui_scale)
	var tag := _tag_rect()
	_tag_cloth.visible = tag.size.x > 0.0
	if _tag_cloth.visible: _tag_cloth.place(tag,ui_scale,2.0,Vector2.ZERO)
	_tag_cloth.modulate.a = held_alpha*(1.0 if _modes_shown() else Linen.eased(held_awake))
	var strip := _swatch_rect()
	_swatch_cloth.visible = strip.size.x > 0.0
	if _swatch_cloth.visible:
		_swatch_cloth.place(strip,ui_scale,2.0,Vector2.ZERO)
		_swatch_cloth.modulate.a = held_alpha*Linen.eased(fan)
	queue_redraw()
	_top_layer.queue_redraw()

## The held tool's tag strip, right of its pocket; empty with a material held.
func _tag_rect() -> Rect2:
	if material_held or not tool in TOOLS: return Rect2()
	var cell := _cell(TOOLS.find(tool))
	# A top tool's fan or tag hangs under the strip, starting under its slot.
	var under := Vector2(cell.position.x,_strip().end.y+HANG*ui_scale)
	if _modes_shown():
		var out := Linen.eased(fan)
		var reach := Vector2(MODE_PAD*2.0+MODE_CELL*lerpf(1.0,modes.size(),out),MODE_PAD*2.0+MODE_CELL)*ui_scale
		if _held_on_top(): return Rect2(under.round(),reach.round())
		return Rect2(Vector2(cell.end.x+(TAG_LEFT-Linen.SLOT)*ui_scale,roundf(cell.get_center().y-reach.y*0.5)),reach.round())
	var width := Linen.tag_width(_font,str(Icons.item(tool).get("label","")),ui_scale)
	var height := (Linen.TAG_SIZE+4.0)*ui_scale
	var extent := Vector2(width+(TAG_PAD.x+TAG_PAD.z)*ui_scale,height+(TAG_PAD.y+TAG_PAD.w)*ui_scale)
	if _held_on_top(): return Rect2(Vector2(roundf(cell.get_center().x-extent.x*0.5),under.y),extent.round())
	return Rect2(Vector2(cell.position.x+TAG_LEFT*ui_scale,roundf(cell.get_center().y-extent.y*0.5)),extent.round())

## The tool in hand's modes (ids) and the one in hand; a new set fans out
## afresh.
func set_modes(ids: Array, current: String) -> void:
	if ids != modes: fan = 0.0
	modes = ids.duplicate()
	mode = current
	_rasterise_modes()

func _modes_shown() -> bool:
	return not modes.is_empty() and not material_held

## The swatch strip's colours (sRGB; empty hides it), the colour in hand, and
## whether the strip ends with the full picker's cell.
func set_swatches(colours: Array, current: Color, picks := true) -> void:
	swatches = colours.duplicate()
	colour = current
	picker = picks
	if (swatches.is_empty() or not picker) and picker_open(): _picker_popup.hide()

func _swatches_shown() -> bool:
	return not swatches.is_empty() and _modes_shown()

## The strip, under the fan's tag; empty while it is hidden.
func _swatch_rect() -> Rect2:
	if not _swatches_shown(): return Rect2()
	var tag := _tag_rect()
	var extent := Vector2(MODE_PAD*2.0+SWATCH_CELL*_swatch_cells(),MODE_PAD*2.0+SWATCH_CELL)*ui_scale
	return Rect2(Vector2(tag.position.x,tag.end.y+SWATCH_GAP*ui_scale).round(),extent.round())

## The strip's cells: a swatch each, and the picker's when it has one.
func _swatch_cells() -> int:
	return swatches.size()+(1 if picker else 0)

func _swatch_cell(k: int) -> Rect2:
	var strip := _swatch_rect()
	var out := Linen.eased(fan)
	return Rect2((strip.position+Vector2(MODE_PAD+SWATCH_CELL*k*out,MODE_PAD)*ui_scale).round(),Vector2.ONE*roundf(SWATCH_CELL*ui_scale))

## The colour in hand is one of the swatches (else it came from the picker).
func _swatch_index() -> int:
	for k in range(swatches.size()):
		if (swatches[k] as Color).is_equal_approx(colour): return k
	return -1

# --- The full picker ----------------------------------------------------------------

## Open the full colour picker beside the swatch strip at `colour`;
## `picked` hears each colour chosen on it (sRGB).
func open_picker(picked: Callable) -> void:
	if _picker_popup == null:
		_picker_popup = PopupPanel.new()
		_picker_popup.name = "BrushColourPicker"
		var picker := ColorPicker.new()
		picker.name = "Picker"
		picker.edit_alpha = false
		picker.picker_shape = ColorPicker.SHAPE_OKHSL_CIRCLE
		picker.presets_visible = false
		picker.color_modes_visible = false
		picker.sampler_visible = false
		_picker_popup.add_child(picker)
		add_child(_picker_popup)
	var picker: ColorPicker = _picker_popup.get_node("Picker")
	for connection: Dictionary in picker.color_changed.get_connections(): picker.color_changed.disconnect(connection.callable)
	picker.color = colour
	picker.color_changed.connect(picked)
	var strip := _swatch_rect()
	_picker_popup.popup(Rect2i(Vector2i(strip.end.x+int(SWATCH_GAP*ui_scale),strip.position.y),Vector2i.ZERO))

func picker_open() -> bool:
	return _picker_popup != null and _picker_popup.visible

## The icon of mode `id` of the tool in hand.
func _mode_icon(id: String) -> String:
	return tool+"_"+id

## The mode icons of the tool in hand, rasterised at the roll's icon size
## if they are not yet.
func _rasterise_modes() -> void:
	if _texture_px <= 0.0: return
	for id: String in modes:
		var icon := _mode_icon(id)
		if _textures.has(icon+":icon"): continue
		for variant: String in ["icon","lit","shadow"]:
			var texture: Texture2D = Icons.texture(icon,variant,_texture_px)
			if texture != null: _textures[icon+":"+variant] = texture

## Each mode's cell on the fan, fanning out from the first.
func _mode_cells() -> Array[Rect2]:
	var tag := _tag_rect()
	var cells: Array[Rect2] = []
	var out := Linen.eased(fan)
	for k in range(modes.size()):
		var at := tag.position+Vector2(MODE_PAD+MODE_CELL*k*out,MODE_PAD)*ui_scale
		cells.append(Rect2(at.round(),Vector2.ONE*roundf(MODE_CELL*ui_scale)))
	return cells

func _draw() -> void:
	_paint(self,false)

## Draws one piece onto `item`: the roll (its tools, dividers and pips) or the
## top strip (`top`); and the held tool's tag or fan with whichever holds it.
func _paint(item: CanvasItem, top: bool) -> void:
	var line := maxf(1.0,roundf(ui_scale))
	for i in range(TOOLS.size()):
		var id: String = TOOLS[i]
		if (id in TOP) != top: continue
		var state: Dictionary = _states[id]
		var cell := _cell(i)
		var on := id == tool and not material_held
		if on: Linen.pressed_patch(item,cell,ui_scale,Linen.PRESSED,Linen.PRESSED_SHADE)
		elif float(state.hover) > 0.0:
			var h := Linen.eased(state.hover)
			Linen.pressed_patch(item,cell,ui_scale,Color(Linen.HOVER,Linen.HOVER.a*h),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*h))
		var centre := cell.get_center()-Vector2(0.0,LIFT*ui_scale)
		if discovered(id): Linen.icon(item,_textures,id,centre,Linen.ICON*ui_scale,ui_scale,"lit" if on else "icon",1.0 if on else 2.0)
		else:
			var warm := Linen.eased(state.refuse)*0.25
			Linen.icon(item,_textures,id,centre,Linen.ICON*ui_scale,ui_scale,"locked",0.0,Color.WHITE.lerp(Color(1.25,1.2,1.1),warm))
		_pocket(item,cell,line)
		if id == "hand" and material_held:
			Linen.dashed_round(item,cell.grow(-2.0*ui_scale),8.0*ui_scale,Linen.CUE,line,ui_scale)
	_paint_held(item,top,line)
	if top: return
	# The dividers: two stitched lines, 3 px apart, over the pips and over
	# each tool set apart (DIVIDER_BEFORE).
	var row := _pips()
	var mid := row.position.x+row.size.x*0.5
	var tops := [row.position.y-GAP*ui_scale-DIVIDER*ui_scale]
	for at: int in DIVIDER_BEFORE: tops.append(_cell(at).position.y-(GAP*0.5+DIVIDER)*ui_scale)
	for above: float in tops:
		for k in range(2):
			var y := roundf(above+(6.0+k*4.0)*ui_scale)+line*0.5
			Linen.dashed(item,PackedVector2Array([Vector2(mid-20.0*ui_scale,y),Vector2(mid+20.0*ui_scale,y)]),Linen.DIVIDER,line,3.0*ui_scale,3.0*ui_scale)
	# The size pips.
	for i in range(SIZES.size()):
		var cell := _pip_cell(i)
		var r := float(SIZES[i].pip)*0.5*ui_scale
		var centre := cell.get_center()
		if i == size_level:
			item.draw_circle(centre,r,held_tint,true,-1.0,true)
			item.draw_arc(centre+Vector2(0.0,0.75*ui_scale),r-0.75*ui_scale,0.15*PI,0.85*PI,12,Color(0.1,0.078,0.055,0.28),1.5*ui_scale,true)
			Linen.dashed_circle(item,centre,r,Linen.PIP_STITCH,line,ui_scale)
		else:
			Linen.dashed_circle(item,centre,r,Linen.PIP_REST,line,ui_scale)

## The held tool's name, on its strip of cloth, drawn with the piece that
## holds it; the modes fanned out in its place, the one in hand pressed in,
## shown at rest too.
func _paint_held(item: CanvasItem, top: bool, line: float) -> void:
	if top != _held_on_top(): return
	var held_awake := awake_top if top else awake
	var tag := _tag_rect()
	if tag.size.x > 0.0 and _modes_shown():
		var cells := _mode_cells()
		var out := Linen.eased(fan)
		# Drawn last first, so the fan's folded cells sit under the first.
		for k in range(modes.size()-1,-1,-1):
			var id: String = modes[k]
			var cell: Rect2 = cells[k]
			var on := id == mode
			if on: Linen.pressed_patch(item,cell.grow(-2.0*ui_scale),ui_scale,Linen.PRESSED,Linen.PRESSED_SHADE)
			elif id == hovered_mode: Linen.pressed_patch(item,cell.grow(-2.0*ui_scale),ui_scale,Linen.HOVER,Linen.HOVER_SHADE)
			var alpha := 1.0 if k == 0 else out
			Linen.icon(item,_textures,_mode_icon(id),cell.get_center(),MODE_ICON*ui_scale,ui_scale,"lit" if on else "icon",1.0 if on else 1.5,Color(1.0,1.0,1.0,alpha))
			# A mode that lays a colour carries the colour in hand.
			if id == "colour":
				var dot := cell.end-Vector2.ONE*11.0*ui_scale
				item.draw_circle(dot,5.0*ui_scale,Color(colour,alpha),true,-1.0,true)
				Linen.dashed_circle(item,dot,5.0*ui_scale,Color(Linen.PIP_STITCH,Linen.PIP_STITCH.a*alpha),line,ui_scale)
		_draw_swatches(item,line)
	elif tag.size.x > 0.0 and held_awake > 0.0:
		var text := str(Icons.item(tool).get("label",""))
		var width := Linen.tag_width(_font,text,ui_scale)
		var x := tag.position.x+TAG_PAD.x*ui_scale+width*0.5
		Linen.tag(item,_font,text,x,tag.end.y-TAG_PAD.w*ui_scale,ui_scale,Linen.eased(held_awake))

## The swatch strip: each swatch a disc, the one in hand ringed as a size
## pip is; the last cell, when it has one, a faceted hue wheel for the full
## picker, ringed when the colour in hand came from it.
func _draw_swatches(item: CanvasItem, line: float) -> void:
	if not _swatches_shown(): return
	var out := Linen.eased(fan)
	var picked := _swatch_index()
	var r := SWATCH_PIP*0.5*ui_scale
	for k in range(_swatch_cells()-1,-1,-1):
		var cell := _swatch_cell(k)
		var centre := cell.get_center()
		var alpha := 1.0 if k == 0 else out
		if k == hovered_swatch: Linen.pressed_patch(item,cell.grow(-1.0*ui_scale),ui_scale,Linen.HOVER,Linen.HOVER_SHADE)
		var on := k == picked or (k == swatches.size() and picked < 0)
		if k < swatches.size():
			item.draw_circle(centre,r,Color(swatches[k] as Color,alpha),true,-1.0,true)
		else:
			for w in range(6):
				var a0 := w*TAU/6.0-PI*0.5
				var a1 := a0+TAU/6.0
				item.draw_colored_polygon(PackedVector2Array([centre,centre+Vector2(cos(a0),sin(a0))*r,centre+Vector2(cos(a1),sin(a1))*r]),Color.from_hsv(w/6.0,0.45,0.82,alpha))
			if picked < 0: item.draw_circle(centre,r*0.45,Color(colour,alpha),true,-1.0,true)
		if on:
			item.draw_arc(centre+Vector2(0.0,0.75*ui_scale),r-0.75*ui_scale,0.15*PI,0.85*PI,12,Color(0.1,0.078,0.055,0.28*alpha),1.5*ui_scale,true)
			Linen.dashed_circle(item,centre,r+2.5*ui_scale,Color(Linen.PIP_STITCH,Linen.PIP_STITCH.a*alpha),line,ui_scale)
		else:
			Linen.dashed_circle(item,centre,r,Color(Linen.PIP_REST,Linen.PIP_REST.a*alpha),line,ui_scale)

## A pocket across the slot's foot: stitched sides and bottom, a darker mouth
## with a glint under it.
func _pocket(item: CanvasItem, cell: Rect2, line: float) -> void:
	var inset := POCKET_INSET*ui_scale
	var rect := Rect2(Vector2(cell.position.x+inset,cell.end.y-inset-POCKET_H*ui_scale).round(),Vector2(cell.size.x-inset*2.0,POCKET_H*ui_scale).round())
	var box := StyleBoxFlat.new()
	box.bg_color = Linen.POCKET
	box.corner_radius_bottom_left = int(round(POCKET_RADIUS*ui_scale))
	box.corner_radius_bottom_right = box.corner_radius_bottom_left
	box.anti_aliasing = true
	item.draw_style_box(box,rect)
	var points := Linen.round_points(rect,POCKET_RADIUS*ui_scale)
	# Only the sides and bottom are stitched: down the right side, across the
	# bottom and up the left (round_points 6..21: the right edge's foot of the
	# top-right arc to the start of the top-left arc).
	var open := PackedVector2Array()
	open.append(Vector2(rect.end.x,rect.position.y))
	for k in range(6,22): open.append(points[k])
	open.append(Vector2(rect.position.x,rect.position.y))
	Linen.dashed(item,open,Linen.POCKET_STITCH,line,3.0*ui_scale,3.0*ui_scale)
	var y := rect.position.y+line*0.5
	item.draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Linen.POCKET_MOUTH,line)
	item.draw_line(Vector2(rect.position.x,y+line),Vector2(rect.end.x,y+line),Linen.POCKET_LIGHT,line)
