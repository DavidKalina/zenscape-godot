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
## It only draws; the hand (scripts/hand_materials.gd) reads `tool_at`,
## `pip_at`, `mode_at` and `contains_pointer` and takes the presses. It rests receded
## (REST_OPACITY, tucked REST_TUCK) and comes out as the pointer nears the
## left edge; a drag in progress never wakes it.

const Linen = preload("res://scripts/hud_linen.gd")
const Icons = preload("res://scripts/hud_icons.gd")
const ClaySound = preload("res://scripts/clay_sound.gd")
## The tools, top to bottom. The Feather (HUD 5, "Gust") holds wind and the
## watering can ("Pour") water, not clay: they sit under the shaping tools
## after a divider (DIVIDER_BEFORE).
const TOOLS := ["hand","hills","mountain","bowl","paddle","chisel","wire","hammer","feather","can"]
## Indices in TOOLS that a stitched divider sits above (lowpoly.js
## TOOL_DIVIDER_BEFORE): the Feather, set apart from the tools that shape.
const DIVIDER_BEFORE := [8]
## The fan beside a tool with modes: a cell (design pixels) and icon each,
## the fan's padding, and the seconds it takes to fan out.
const MODE_CELL := 46.0
const MODE_ICON := 36.0
const MODE_PAD := 4.0
const FAN_TIME := 0.18
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
var quiet := false
var pointer_override: Variant = null
var _want_shown := false
var _away := 0.0
var _font: FontVariation
var _textures := {}
var _texture_px := 0.0
var _cloth: Linen.Cloth
var _tag_cloth: Linen.Cloth
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

## The size pip under a viewport point, or -1.
func pip_at(point: Vector2) -> int:
	if shown < 0.5: return -1
	for i in range(SIZES.size()):
		if _pip_cell(i).has_point(point): return i
	return -1

func contains_pointer(point: Vector2) -> bool:
	return shown >= 0.5 and (_roll().grow(2.0*ui_scale).has_point(point) or (_modes_shown() and _tag_rect().has_point(point)))

## The roll's cloth, viewport pixels (the foot, scripts/tool_foot.gd, hangs under it).
func rect() -> Rect2:
	return _roll()

func _height() -> float:
	return PAD.y*2.0+Linen.SLOT*TOOLS.size()+GAP*(TOOLS.size()+1)+DIVIDER*(1+DIVIDER_BEFORE.size())+PIPS_H

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

func _cell(i: int) -> Rect2:
	var roll := _roll()
	return Rect2((roll.position+Vector2(PAD.x,PAD.y+(Linen.SLOT+GAP)*i+_dividers_above(i))*ui_scale).round(),Vector2.ONE*roundf(Linen.SLOT*ui_scale))

## The pips' row, and one pip's hit cell.
func _pips() -> Rect2:
	var roll := _roll()
	var y := PAD.y+Linen.SLOT*TOOLS.size()+GAP*(TOOLS.size()+1)+DIVIDER*(1+DIVIDER_BEFORE.size())
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
	visible = shown > 0.0
	if not visible: return
	modulate.a = Linen.eased(shown)*lerpf(Linen.REST_OPACITY,1.0,Linen.eased(awake))
	var was_hovered := hovered
	hovered = tool_at(pointer) if _want_shown and awake > 0.5 else ""
	if hovered != was_hovered and discovered(hovered): ClaySound.cue(&"ui_hover")
	var was_mode := hovered_mode
	hovered_mode = mode_at(pointer) if _want_shown else ""
	if hovered_mode != was_mode and not hovered_mode.is_empty(): ClaySound.cue(&"ui_hover")
	for id: String in TOOLS:
		var state: Dictionary = _states[id]
		var on := id == hovered and not (id == tool and not material_held) and discovered(id)
		state.hover = move_toward(float(state.hover),1.0 if on else 0.0,delta/HOVER_TIME)
		state.refuse = move_toward(float(state.refuse),0.0,delta/NOT_YET)
	_cloth.place(_roll(),ui_scale)
	var tag := _tag_rect()
	_tag_cloth.visible = tag.size.x > 0.0
	if _tag_cloth.visible: _tag_cloth.place(tag,ui_scale,2.0,Vector2.ZERO)
	_tag_cloth.modulate.a = 1.0 if _modes_shown() else Linen.eased(awake)
	queue_redraw()

## The held tool's tag strip, right of its pocket; empty with a material held.
func _tag_rect() -> Rect2:
	if material_held or not tool in TOOLS: return Rect2()
	var cell := _cell(TOOLS.find(tool))
	if _modes_shown():
		var out := Linen.eased(fan)
		var reach := Vector2(MODE_PAD*2.0+MODE_CELL*lerpf(1.0,modes.size(),out),MODE_PAD*2.0+MODE_CELL)*ui_scale
		return Rect2(Vector2(cell.end.x+(TAG_LEFT-Linen.SLOT)*ui_scale,roundf(cell.get_center().y-reach.y*0.5)),reach.round())
	var width := Linen.tag_width(_font,str(Icons.item(tool).get("label","")),ui_scale)
	var height := (Linen.TAG_SIZE+4.0)*ui_scale
	var extent := Vector2(width+(TAG_PAD.x+TAG_PAD.z)*ui_scale,height+(TAG_PAD.y+TAG_PAD.w)*ui_scale)
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
	var line := maxf(1.0,roundf(ui_scale))
	for i in range(TOOLS.size()):
		var id: String = TOOLS[i]
		var state: Dictionary = _states[id]
		var cell := _cell(i)
		var on := id == tool and not material_held
		if on: Linen.pressed_patch(self,cell,ui_scale,Linen.PRESSED,Linen.PRESSED_SHADE)
		elif float(state.hover) > 0.0:
			var h := Linen.eased(state.hover)
			Linen.pressed_patch(self,cell,ui_scale,Color(Linen.HOVER,Linen.HOVER.a*h),Color(Linen.HOVER_SHADE,Linen.HOVER_SHADE.a*h))
		var centre := cell.get_center()-Vector2(0.0,LIFT*ui_scale)
		if discovered(id): Linen.icon(self,_textures,id,centre,Linen.ICON*ui_scale,ui_scale,"lit" if on else "icon",1.0 if on else 2.0)
		else:
			var warm := Linen.eased(state.refuse)*0.25
			Linen.icon(self,_textures,id,centre,Linen.ICON*ui_scale,ui_scale,"locked",0.0,Color.WHITE.lerp(Color(1.25,1.2,1.1),warm))
		_pocket(cell,line)
		if id == "hand" and material_held:
			Linen.dashed_round(self,cell.grow(-2.0*ui_scale),8.0*ui_scale,Linen.CUE,line,ui_scale)
	# The dividers: two stitched lines, 3 px apart, over the pips and over
	# each tool set apart (the Feather).
	var row := _pips()
	var mid := row.position.x+row.size.x*0.5
	var tops := [row.position.y-GAP*ui_scale-DIVIDER*ui_scale]
	for at: int in DIVIDER_BEFORE: tops.append(_cell(at).position.y-(GAP*0.5+DIVIDER)*ui_scale)
	for top: float in tops:
		for k in range(2):
			var y := roundf(top+(6.0+k*4.0)*ui_scale)+line*0.5
			Linen.dashed(self,PackedVector2Array([Vector2(mid-20.0*ui_scale,y),Vector2(mid+20.0*ui_scale,y)]),Linen.DIVIDER,line,3.0*ui_scale,3.0*ui_scale)
	# The size pips.
	for i in range(SIZES.size()):
		var cell := _pip_cell(i)
		var r := float(SIZES[i].pip)*0.5*ui_scale
		var centre := cell.get_center()
		if i == size_level:
			draw_circle(centre,r,held_tint,true,-1.0,true)
			draw_arc(centre+Vector2(0.0,0.75*ui_scale),r-0.75*ui_scale,0.15*PI,0.85*PI,12,Color(0.1,0.078,0.055,0.28),1.5*ui_scale,true)
			Linen.dashed_circle(self,centre,r,Linen.PIP_STITCH,line,ui_scale)
		else:
			Linen.dashed_circle(self,centre,r,Linen.PIP_REST,line,ui_scale)
	# The held tool's name, on its strip of cloth; the Sculpt's modes fanned
	# out in its place, the one in hand pressed in, shown at rest too.
	var tag := _tag_rect()
	if tag.size.x > 0.0 and _modes_shown():
		var cells := _mode_cells()
		var out := Linen.eased(fan)
		# Drawn last first, so the fan's folded cells sit under the first.
		for k in range(modes.size()-1,-1,-1):
			var id: String = modes[k]
			var cell: Rect2 = cells[k]
			var on := id == mode
			if on: Linen.pressed_patch(self,cell.grow(-2.0*ui_scale),ui_scale,Linen.PRESSED,Linen.PRESSED_SHADE)
			elif id == hovered_mode: Linen.pressed_patch(self,cell.grow(-2.0*ui_scale),ui_scale,Linen.HOVER,Linen.HOVER_SHADE)
			var alpha := 1.0 if k == 0 else out
			Linen.icon(self,_textures,_mode_icon(id),cell.get_center(),MODE_ICON*ui_scale,ui_scale,"lit" if on else "icon",1.0 if on else 1.5,Color(1.0,1.0,1.0,alpha))
	elif tag.size.x > 0.0 and awake > 0.0:
		var text := str(Icons.item(tool).get("label",""))
		var width := Linen.tag_width(_font,text,ui_scale)
		var x := tag.position.x+TAG_PAD.x*ui_scale+width*0.5
		Linen.tag(self,_font,text,x,tag.end.y-TAG_PAD.w*ui_scale,ui_scale,Linen.eased(awake))

## A pocket across the slot's foot: stitched sides and bottom, a darker mouth
## with a glint under it.
func _pocket(cell: Rect2, line: float) -> void:
	var inset := POCKET_INSET*ui_scale
	var rect := Rect2(Vector2(cell.position.x+inset,cell.end.y-inset-POCKET_H*ui_scale).round(),Vector2(cell.size.x-inset*2.0,POCKET_H*ui_scale).round())
	var box := StyleBoxFlat.new()
	box.bg_color = Linen.POCKET
	box.corner_radius_bottom_left = int(round(POCKET_RADIUS*ui_scale))
	box.corner_radius_bottom_right = box.corner_radius_bottom_left
	box.anti_aliasing = true
	draw_style_box(box,rect)
	var points := Linen.round_points(rect,POCKET_RADIUS*ui_scale)
	# Only the sides and bottom are stitched: down the right side, across the
	# bottom and up the left (round_points 6..21: the right edge's foot of the
	# top-right arc to the start of the top-left arc).
	var open := PackedVector2Array()
	open.append(Vector2(rect.end.x,rect.position.y))
	for k in range(6,22): open.append(points[k])
	open.append(Vector2(rect.position.x,rect.position.y))
	Linen.dashed(self,open,Linen.POCKET_STITCH,line,3.0*ui_scale,3.0*ui_scale)
	var y := rect.position.y+line*0.5
	draw_line(Vector2(rect.position.x,y),Vector2(rect.end.x,y),Linen.POCKET_MOUTH,line)
	draw_line(Vector2(rect.position.x,y+line),Vector2(rect.end.x,y+line),Linen.POCKET_LIGHT,line)
