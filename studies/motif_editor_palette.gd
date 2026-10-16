extends "res://scripts/command_palette.gd"
## The motif editor's palette (round 3): the early game's command palette
## (scripts/command_palette.gd, its linen, search, pockets and keys, Cmd/Ctrl
## K or /) holding the editor's things instead of the hand's: the land
## tools and stamps (their tool-roll icons), the kit's pieces and the trees
## (thumbnails rendered from their real meshes), the landforms, and the
## world's verbs (undo, save, play, open a saved motif).
##
## A piece row can be dragged out into the world: past DRAG_SLOP the palette
## goes away and the editor carries the piece's ghost over the ground until
## the button is let go (`begin_ghost`). A plain click arms it instead
## (click the ground to set it down).

const MotifAuthored = preload("res://scripts/kit_isle/motif_authored.gd")
const TrapRegistry = preload("res://scripts/traps/trap_registry.gd")
const RuinKitScript = preload("res://scripts/ruin_kit.gd")
const DRAG_SLOP := 8.0
const POCKETS := ["All","Land","Kit","Trees","Landforms","World","Traps"]
const POCKET_ICONS := ["all","mountain","stone","oak","island","globe","hammer"]
## The land tools: [editor tool, name, sub, roll icon, description, keys].
const LAND := [
	["select","Select","Move","","Pick a piece or marker; drag it along the ground. Z X turn it.",["1"]],
	["raise","Modeller","Raise","hand_pinch","Raise the land under the brush; hold still to pile it up.",["2"]],
	["lower","Modeller","Lower","hand_groove","Lower the land under the brush.",["3"]],
	["smooth","Paddle","Smooth","paddle_plane","Smooth the land under the brush.",["4"]],
	["flatten","Paddle","Flatten","paddle_pat","Flatten to the height where the stroke began.",["5"]],
	["ravine","Ravine","Carve","wire","Draw a line: a ravine. Draw a loop: a lake, dug and filled.",["6"]],
	["water","Watering can","Pour","can","Pour a pond into the hollow you click. Shift takes one away.",["7"]],
	["outline","Outline","Edge","","Drag the isle's edge points. Shift adds one, Alt takes one away.",["8"]],
	["stamp_mountain","Mountain","Peak","mountain","Click to stamp a mountain the size of the ring; drag up to pull it taller.",[]],
	["stamp_hills","Hills","Roll","hills","Click to stamp rolling hills; drag up for taller.",[]],
	["stamp_crater","Crater","Hollow","crater","Click to stamp a crater; drag down to dig deeper. Pour water in it.",[]],
	["stamp_mesa","Mesa","Chisel","chisel_mesa","Click to stamp a flat-topped mesa; drag up for taller.",[]],
	["stamp_island","Island","Spread","island_spread","Click near the edge: new land swells out, the outline grows round it.",[]],
	["new_land","New land","Draw","island_draw","Draw a loop out past the edge: the isle grows to it.",[]],
	["trash","Trash can","Clear","trash","Click a piece, a run, a stamp or a pond to take it away.",[]],
	["run_aqueduct","Aqueduct run","Run","","Click a start and an end: spans fill between, piers to the ground, heads at both ends.",[]],
	["run_wall","Wall run","Run","","Click a start and an end: walls step with the ground; ends snap to cliff lips.",[]],
	["run_bridge","Rope bridge","Run","","Click one cliff lip, then the other: a rope bridge between stone anchors.",[]],
]
const WORLD_VERBS := [
	["undo","Undo","Take back the last change","U",["⌘","Z"]],
	["redo","Redo","Put it back","R",["⇧","⌘","Z"]],
	["save","Save","motifs/authored/<name>.json","S",["⌘","S"]],
	["play","Play","Drop the pilot at the spawn","P",["P"]],
	["dress","Full look / grey","The full look (turf, flora, life, sky) or back to the grey editing look","D",["G"]],
	["reroll","Re-roll","A new seed, the same sliders","R",[]],
	["frame","Frame","Back to the whole isle","F",[]],
]

var editor: Node
## Thumbnails by piece id (the editor renders them: `set_thumb`).
var thumbs := {}
var _pending := {}

func tabs() -> Array:
	return POCKETS

func tab_icons() -> Array:
	return POCKET_ICONS

func setup_editor(owner_editor: Node) -> void:
	editor = owner_editor
	scene = owner_editor
	materials = null
	_build_items()

func set_thumb(id: String, texture: Texture2D) -> void:
	thumbs[id] = texture

func _build_items() -> void:
	_items.clear()
	if editor == null: return
	for e: Array in LAND:
		var item := {"kind":"tool","cat":1,"id":e[0],"name":e[1],"sub":e[2],"desc":e[4],"keys":e[5],"glyph":str(e[1]).left(1)}
		if str(e[3]) != "": item.icon = e[3]
		_items.append(item)
	for entry: Array in MotifAuthored.palette():
		var id := str(entry[0])
		var tree := id.begins_with("tree_")
		var family := "Tree"
		for f: String in RuinKitScript.FAMILIES:
			if id in RuinKitScript.FAMILIES[f]: family = f.capitalize()
		_items.append({"kind":"piece","cat":3 if tree else 2,"id":id,"name":str(entry[1]).trim_prefix("Tree: "),"sub":family+" · drag it in","desc":"Drag into the world, or take it and click the ground.","glyph":""})
	for key: String in MotifAuthored.PRESETS:
		_items.append({"kind":"preset","cat":4,"id":key,"name":str(MotifAuthored.PRESET_NAMES.get(key,key)),"sub":"Landform: its sliders top left","desc":"","icon":"island"})
	for e: Array in WORLD_VERBS:
		_items.append({"kind":"world","cat":5,"id":e[0],"name":e[1],"sub":e[2],"glyph":e[3],"keys":e[4],"desc":""})
	# The traps (scripts/traps/trap_registry.gd), one tile each; "trap" in
	# the sub so typing "trap" finds them all.
	for key: String in TrapRegistry.keys():
		_items.append({"kind":"trap","cat":6,"id":key,"name":TrapRegistry.display_name(key),"sub":"Trap · drag it in","desc":"Drag onto the ground or a piece's top. Z X turn it.","glyph":""})
	for slug: String in MotifAuthored.saved():
		_items.append({"kind":"open","cat":5,"id":slug,"name":"Open "+slug,"sub":MotifAuthored.path_of(slug),"glyph":"O","desc":""})
	# A coded pool motif stood read-only to build on (motif_editor_base.gd).
	for id_name: String in load("res://scripts/kit_isle/motif_based.gd").bases():
		_items.append({"kind":"base","cat":5,"id":id_name,"name":"Base: "+id_name,"sub":"build on "+id_name+" (read-only)","glyph":"B","desc":""})

func _locked(_item: Dictionary) -> bool:
	return false

func _can_open() -> bool:
	return editor != null and bool(editor.editing) and not (editor.get_viewport().gui_get_focus_owner() is LineEdit)

func open() -> void:
	_build_items()
	super.open()
	if editor != null: editor.palette_opened()

## Round 4: the Kit and Trees pockets lay their pieces out as a grid of
## tiles (TILE px, the thumbnail large over its name), picked by eye.
const TILE := Vector2(142.0,156.0)
const TILE_GAP := 6.0
const TILE_TABS := [2,3,6]

func _tiled() -> bool:
	return tab in TILE_TABS

func _refresh() -> void:
	super._refresh()
	if not _tiled(): return
	var width := WIDTH-PAD*2.0
	var cols := maxi(1,int((width+TILE_GAP)/(TILE.x+TILE_GAP)))
	var spare := (width-cols*TILE.x-(cols-1)*TILE_GAP)*0.5
	var k := 0
	for line: Dictionary in _rows:
		var c := k%cols
		var r := k/cols
		line.x = spare+c*(TILE.x+TILE_GAP)
		line.w = TILE.x
		line.y = 6.0+r*(TILE.y+TILE_GAP)
		line.h = TILE.y
		line.tile = true
		k += 1
	_list_h = maxf(6.0+ceilf(float(k)/cols)*(TILE.y+TILE_GAP)+10.0,96.0)

func _row_at(point: Vector2) -> int:
	if not _tiled(): return super._row_at(point)
	var local := point-panel_rect().position
	var list := _list_rect()
	if not list.has_point(local): return -1
	var y := (local.y-list.position.y)/ui_scale+scroll
	var x := (local.x-list.position.x)/ui_scale
	for line: Dictionary in _rows:
		if y >= float(line.y) and y < float(line.y)+float(line.h) and x >= float(line.x) and x < float(line.x)+float(line.w): return int(line.index)
	return -1

## A tile: the thumbnail filling its top, the name under it.
func _draw_tile(entry: Dictionary, rect: Rect2, line: float) -> void:
	var px := ui_scale
	var item: Dictionary = entry.item
	var tile := Rect2(Vector2(rect.position.x+float(entry.x)*px,rect.position.y),Vector2(float(entry.w)*px,rect.size.y))
	var on: bool = entry.index == sel
	_patch(tile,10.0,WELL if on else Color(WELL,0.45),WELL_SHADE)
	var side := tile.size.x-14.0*px
	var pic := Rect2(Vector2(tile.position.x+7.0*px,tile.position.y+7.0*px),Vector2(side,side))
	var texture: Texture2D = thumbs.get(str(item.id)) if str(item.kind) != "trap" else null
	if texture != null: _body.draw_texture_rect(texture,pic,false)
	elif str(item.kind) == "trap": _draw_trap_stand_in(pic,line)
	else: Linen.dashed_round(_body,pic.grow(-6.0*px),8.0*px,GLYPH_STITCH,line,px)
	var name_ := str(item.name)
	var size := roundi(13.0*px)
	var w := _text_font.get_string_size(name_,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	_body.draw_string(_text_font,Vector2(tile.get_center().x-minf(w,side)*0.5,tile.end.y-9.0*px),name_,HORIZONTAL_ALIGNMENT_LEFT,side,size,T1)
	if on: Linen.dashed_round(_body,tile.grow(-2.0*px),8.0*px,ON_STITCH,line,px)

## A trap's tile picture, a drawn stand-in (no rendered thumbnail yet,
## and labelled so): a lane, its way in (green arrow) and out (orange ring).
func _draw_trap_stand_in(pic: Rect2, line: float) -> void:
	var px := ui_scale
	var inner := pic.grow(-10.0*px)
	Linen.dashed_round(_body,inner,8.0*px,GLYPH_STITCH,line,px)
	var cx := inner.get_center().x
	var lane := Rect2(Vector2(cx-12.0*px,inner.position.y+22.0*px),Vector2(24.0*px,inner.size.y-40.0*px))
	_body.draw_rect(lane,Color(T1,0.25))
	var low := Vector2(cx,lane.end.y+4.0*px)
	_body.draw_colored_polygon(PackedVector2Array([low+Vector2(-9.0,8.0)*px,low+Vector2(9.0,8.0)*px,low+Vector2(0.0,-6.0)*px]),Color(0.3,0.75,0.4))
	_body.draw_arc(Vector2(cx,lane.position.y-6.0*px),7.0*px,0.0,TAU,20,Color(0.9,0.5,0.2),2.5*px)
	var size := roundi(10.0*px)
	_body.draw_string(_text_font,Vector2(inner.position.x+6.0*px,inner.position.y+14.0*px),"stand-in",HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(T1,0.6))

## A piece's row: the parent's row with the thumbnail in its glyph box.
func _draw_row(entry: Dictionary, rect: Rect2, line: float) -> void:
	if entry.get("tile",false):
		_draw_tile(entry,rect,line)
		return
	super._draw_row(entry,rect,line)
	var item: Dictionary = entry.item
	if str(item.kind) != "piece": return
	var texture: Texture2D = thumbs.get(str(item.id))
	if texture == null: return
	var px := ui_scale
	var box := Rect2(Vector2(rect.position.x+6.0*px,rect.get_center().y-24.0*px),Vector2.ONE*48.0*px)
	_body.draw_texture_rect(texture,box,false)

## A press on a piece's row waits to see whether it is a drag (the piece's
## ghost carried into the world) or a click (taken in hand).
func handle_event(event: InputEvent) -> bool:
	if not _want or editor == null: return super.handle_event(event)
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			var row := _row_at(mb.position)
			if row >= 0 and str(_rows[row].item.kind) in ["piece","trap"]:
				sel = row
				_pending = {"item":_rows[row].item,"at":mb.position}
				return true
		elif not _pending.is_empty():
			var item: Dictionary = _pending.item
			_pending = {}
			_take(item)
			return true
	if event is InputEventMouseMotion and not _pending.is_empty():
		var mm := event as InputEventMouseMotion
		if mm.position.distance_to(_pending.at) > DRAG_SLOP:
			var item: Dictionary = _pending.item
			_pending = {}
			_remember(item)
			close()
			if str(item.kind) == "trap": editor.begin_trap(str(item.id),mm.position,true)
			else: editor.begin_ghost(str(item.id),mm.position)
			return true
	return super.handle_event(event)

func _remember(item: Dictionary) -> void:
	last_taken = _key_of(item)
	recent.erase(last_taken)
	recent.push_front(last_taken)
	if recent.size() > 3: recent.resize(3)

func _take(item: Dictionary) -> void:
	var refusal := ""
	match str(item.kind):
		"tool": editor.pick_tool(str(item.id))
		"piece": editor.arm(str(item.id))
		"trap": editor.begin_trap(str(item.id),editor.get_viewport().get_mouse_position())
		"preset": editor.set_preset(str(item.id))
		"open": if not editor.load_motif(str(item.id)): refusal = "Could not open %s" % item.id
		"base": if not editor.load_base(str(item.id)): refusal = "Could not stand %s" % item.id
		"world": refusal = editor.world_verb(str(item.id))
	if not refusal.is_empty():
		last_refusal = refusal
		editor.say(refusal)
		ClaySound.cue(&"ui_refuse")
		return
	ClaySound.cue(&"ui_take")
	_remember(item)
	close()

func _process(delta: float) -> void:
	super._process(delta)
	if visible and not thumbs.is_empty(): _body.queue_redraw()
