extends Control
## The map (M, the pad's View, or the pause menu's Map): one cream sheet over
## the held flight with the land from above, north (-z) up. The land is a
## picture baked once for seed 1's wilderness (tools/map_bake.py:
## assets/ui/map/land_seed1.png, its box in map_land.gd); on another seed or
## world the sheet is bare paper with a kilometre grid and the marks alone.
##
## On it: the built places by name (PLACES, read off their own scripts), the
## Peak, the finds already found as small marks, the start, and the plane with
## its heading, pinned to the frame's edge and pointing the way when it is
## outside the view.
##
## An overlay, as the logbook (logbook_book.gd): open, it is `game.overlay`
## (the main scene's keys go quiet) and the tree is held; this runs through
## it. Arrows, WASD or the left stick pan; Q / E, - / =, the wheel or the
## triggers zoom; C or the pad's Y centres on the plane; M, Esc, the pad's B
## or View close it. The mouse drags the sheet when it is free. Closed, it
## neither processes nor takes input.

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
const Pad = preload("res://scripts/pad.gd")
const Land = preload("res://scripts/endless/ui/map_land.gd")
const CitadelSite = preload("res://scripts/endless/citadel_site.gd")
const TombsSite = preload("res://scripts/endless/tombs_site.gd")
const AgoraSite = preload("res://scripts/endless/agora_site.gd")
const TheatreSite = preload("res://scripts/endless/theatre_site.gd")
const AqueductSite = preload("res://scripts/endless/aqueduct_site.gd")
const SanctuarySite = preload("res://scripts/endless/sanctuary_site.gd")
const ArenaSite = preload("res://scripts/endless/arena_site.gd")
const TempleSite = preload("res://scripts/endless/temple_site.gd")
const ViaductSite = preload("res://scripts/endless/viaduct_site.gd")
const DomeSite = preload("res://scripts/endless/dome_site.gd")
const BridgeSite = preload("res://scripts/endless/bridge_site.gd")
const WildPlaced = preload("res://scripts/endless/world/wilderness/placed.gd")
const Glyphs = preload("res://scripts/endless/near_glyphs.gd")
const Book = preload("res://scripts/endless/ui/book_kit.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The sheet, mock px (the 1280x800 frame), and the map's frame inside it.
const SHEET := Rect2(44.0,30.0,1192.0,704.0)
const FRAME_IN := Rect2(30.0,42.0,52.0,20.0)
## Zoom: px a metre as a multiple of the whole box fitting the frame's height.
const ZOOM_OPEN := 2.4
const ZOOM_MOST := 5.0
const ZOOM_LEAST := 1.0
const ZOOM_STEP := 1.25
## Pan speed at full stick, frames a second; zoom speed held, doublings a second.
const PAN := 0.9
const ZOOM_RATE := 1.6
const WASH_A := 0.42
const WASH_T := 0.2
## The temples' and falls' names, by their handles.
const TEMPLE_NAMES := {"way/isle":"Isle temple","way/bay":"Bay temple","way/south":"South temple"}
const FALLS_NAMES := {"wild/river_falls":"River falls","wild/tarn_falls":"Tarn falls","wild/mere_falls":"Mere falls"}
const WATER_INK := Color("335866")
## The marks: each place a glyph (near_glyphs.gd) on an ink disc rimmed in
## cream (a find's rim gold), the plane the dart glyph (the tick's colour)
## turned its heading's way. Discs' diameters and the plane's box, mock px;
## a glyph's 24-unit box is GLYPH_IN of its disc. --map-marks=old draws the
## squares, triangles and circles before them.
const PLACE_GLYPHS := {"Citadel":"citadel","Town":"ruin","Theatre":"theatre","Sanctuary":"temple","Colosseum":"arena",
	"Great dome":"dome","Great bridge":"arch"}
const KIND_GLYPHS := {"temple":"temple","falls":"falls","peak":"peak","ruin":"ruin"}
const MARK_D := 22.0
const PEAK_D := 28.0
const FIND_D := 17.0
const START_D := 20.0
const PLANE_D := 30.0
const GLYPH_IN := 0.8
const RIM := 1.5
const MARK_RIM := Color("efe8d4")
const FOOT := [["Arrows","LS","pan"],["Q E","LT RT","zoom"],["C","Y","plane"],["M","B","close"]]

var game: Node
## The view: its centre (world x, z) and px a metre (screen px).
var centre := Vector2.ZERO
var zoom := 1.0
var _zoom_to := 1.0
var _tex: Texture2D
var _land := false
var _places: Array = []
var _finds: Array = []
var _view: Control
var _age := 0.0
var _was_paused := false
var _drag := false
## The marks as they were (squares, triangles, circles): --map-marks=old.
var old_marks := false

func _init(host: Node = null) -> void:
	game = host
	name = "MapPage"
	old_marks = "--map-marks=old" in LaunchArgs.user_args()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_process(false)
	set_process_input(false)
	_view = Control.new()
	_view.name = "Sheet"
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_view.draw.connect(_draw_sheet)
	add_child(_view)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Godot turns these on at ready for a script with _process and _input.
	set_process(false)
	set_process_input(false)
	resized.connect(_layout)

func is_open() -> bool:
	return game != null and game.overlay == self

## Opens it on the plane (only when no other overlay is up).
func open_map() -> void:
	if game == null or game.overlay != null: return
	game.overlay = self
	_build()
	_layout()
	zoom = _fit()*ZOOM_OPEN
	_zoom_to = zoom
	centre = _clamp(plane_at())
	_age = 0.0
	_drag = false
	visible = true
	set_process(true)
	set_process_input(true)
	_was_paused = get_tree().paused
	get_tree().paused = true
	if game.has_method("key_line_under"): game.key_line_under(true)
	queue_redraw()

func close_map() -> void:
	if not is_open(): return
	game.overlay = null
	visible = false
	set_process(false)
	set_process_input(false)
	get_tree().paused = _was_paused
	if game.has_method("key_line_under"): game.key_line_under(false)

func _exit_tree() -> void:
	# Never leave the tree held behind it.
	if is_open(): close_map()

# --- What it shows -----------------------------------------------------------------------

## The land's picture and places when this is the land they were made for.
func _build() -> void:
	var land_seed := int(game.field.seed) if game.get("field") != null else -1
	# The world as it stands at the picture's start (the doors world is the
	# wilderness there).
	var world: RefCounted = game.get("world")
	var world_id := str(world.at(Land.START.x,Land.START.y).id) if world != null else ""
	_land = land_seed == Land.SEED and world_id == Land.WORLD
	if _land and _tex == null: _tex = load(Land.PICTURE)
	_places = places(game) if _land else []
	_finds = []
	var finds: Variant = game.get("finds")
	if finds != null:
		for e: Dictionary in finds.rows:
			if str(e.get("world","")) == str(finds.world) and e.at != Vector3.INF and finds.is_found(e):
				_finds.append({"at":Vector2(e.at.x,e.at.z),"glyph":Book.find_glyph(e)})

## The built places: {name, kind (ruin, temple, falls, peak, road), at, line}.
## Their spots are their own scripts' constants; the Peak's is the land's.
static func places(host: Node) -> Array:
	var out := [
		{"name":"Citadel","kind":"ruin","at":CitadelSite.KEEP_C},
		{"name":"Road of tombs","kind":"road","line":TombsSite.LINE},
		{"name":"Town","kind":"ruin","at":AgoraSite.KEEP_C},
		{"name":"Theatre","kind":"ruin","at":TheatreSite.C},
		{"name":"Aqueduct","kind":"road","line":AqueductSite.LINE},
		{"name":"Sanctuary","kind":"ruin","at":SanctuarySite.O},
		{"name":"Colosseum","kind":"ruin","at":ArenaSite.CENTRE},
		# The viaduct's two ends and its middle (viaduct_site.gd lays it from O along DIR_DEG).
		{"name":"Viaduct","kind":"road","line":[Vector2(-3512.0,-3866.1),Vector2(-3221.3,-3362.6),Vector2(-2930.6,-2859.1)]},
		{"name":"Great dome","kind":"ruin","at":DomeSite.C},
		{"name":"Great bridge","kind":"ruin","at":BridgeSite.O}]
	for handle: String in TempleSite.SITES:
		out.append({"name":str(TEMPLE_NAMES.get(handle,"Temple")),"kind":"temple","at":TempleSite.SITES[handle].at})
	for row: Array in WildPlaced.SITES:
		if str(row[1]) == "curtain": out.append({"name":str(FALLS_NAMES.get(str(row[0]),"Falls")),"kind":"falls","at":Vector2(float(row[3]),float(row[4]))})
	var field: RefCounted = host.get("field") if host != null else null
	var pk: RefCounted = field.peak() if field != null and field.has_method("peak") else null
	if pk != null: out.append({"name":"The Peak","kind":"peak","at":pk.centre})
	for p: Dictionary in out:
		p.glyph = str(PLACE_GLYPHS.get(str(p.name),KIND_GLYPHS.get(str(p.kind),"")))
		if p.has("line"):
			var line: Array = p.line
			p.at = line[int(line.size()*0.5)]
	return out

## The plane (world x, z) and its heading.
func plane_at() -> Vector2:
	var plane: RefCounted = game.get("plane")
	if plane == null: return Vector2.ZERO
	var p: Vector3 = plane.position
	return Vector2(p.x,p.z)

func _heading() -> float:
	var plane: RefCounted = game.get("plane")
	return float(plane.heading) if plane != null else 0.0

## The mapped box: the picture's, else a box of the same size round the start.
func box() -> Rect2:
	if _land: return Land.BOX
	return Rect2(_start()-Land.BOX.size*0.5,Land.BOX.size)

func _start() -> Vector2:
	if _land: return Land.START
	var s: Variant = game.get("_start")
	return s if s is Vector2 else Vector2.ZERO

## The page as text lines (for drivers and checks).
func lines() -> Array:
	var out := ["land | %s" % ("seed %d picture" % Land.SEED if _land else "none"),
		"centre | %.0f %.0f" % [centre.x,centre.y],"zoom | %.3f px/m (%.2f of fit)" % [zoom,zoom/_fit()],
		"plane | %.0f %.0f %s" % [plane_at().x,plane_at().y,"pinned" if pinned() else "in view"],
		"finds | %d found" % _finds.size()]
	for p: Dictionary in _places: out.append("  %s (%s) | %.0f %.0f" % [p.name,p.kind,p.at.x,p.at.y])
	return out

# --- The view ----------------------------------------------------------------------------

## The map's frame, screen px.
func _frame() -> Rect2:
	var k := Kit.scale_of(size)
	var s := Rect2(((size-SHEET.size*k)*0.5).round(),SHEET.size*k)
	s.position.y = roundf(SHEET.position.y*k)
	return Rect2(s.position+FRAME_IN.position*k,s.size-(FRAME_IN.position+FRAME_IN.size)*k)

func _sheet() -> Rect2:
	var k := Kit.scale_of(size)
	var s := Rect2(((size-SHEET.size*k)*0.5).round(),SHEET.size*k)
	s.position.y = roundf(SHEET.position.y*k)
	return s

func _layout() -> void:
	var f := _frame()
	_view.position = f.position
	_view.size = f.size
	queue_redraw()
	_view.queue_redraw()

## The zoom at which the whole box fits the frame's height.
func _fit() -> float:
	return maxf(_frame().size.y,1.0)/box().size.y

## The part of the view the plane's marker stays inside (the view's px).
func _inner() -> Rect2:
	return Rect2(Vector2.ZERO,_view.size).grow(-16.0*Kit.scale_of(size))

## True when the plane is outside the view and its marker pinned to the edge.
func pinned() -> bool:
	return not _inner().has_point(to_screen(plane_at()))

## A world (x, z) on the screen (the view's own px).
func to_screen(p: Vector2) -> Vector2:
	return _view.size*0.5+(p-centre)*zoom

## A centre that keeps the box over the whole view where it can (centred
## on an axis it is narrower than the view along).
func _clamp(p: Vector2) -> Vector2:
	var b := box()
	var half := _view.size*0.5/zoom
	var out := p
	for i in 2:
		if half[i]*2.0 >= b.size[i]: out[i] = b.get_center()[i]
		else: out[i] = clampf(p[i],b.position[i]+half[i],b.end[i]-half[i])
	return out

## The view's centre to world (x, z) (kept over the box), drawn again.
func look_at(p: Vector2) -> void:
	centre = _clamp(p)
	_view.queue_redraw()

## The view zoomed by `by`, about the frame's point `about` (its own px).
func zoom_by(by: float, about := Vector2.INF) -> void:
	var fit := _fit()
	var to := clampf(_zoom_to*by,fit*ZOOM_LEAST,fit*ZOOM_MOST)
	if about.is_finite():
		# The world point under `about` stays there.
		var w := centre+(about-_view.size*0.5)/zoom
		zoom = to
		centre = _clamp(w-(about-_view.size*0.5)/to)
	_zoom_to = to

func _process(delta: float) -> void:
	if not is_open():
		close_map()
		return
	_age += delta
	var pan := Pad.stick(&"move_left",&"move_right",&"move_forward",&"move_back")
	var moved := false
	if pan != Vector2.ZERO:
		centre = _clamp(centre+pan*PAN*delta*_view.size.y/zoom)
		moved = true
	var z := Input.get_action_strength(&"zoom_in")-Input.get_action_strength(&"zoom_out")
	if absf(z) > 0.05: zoom_by(pow(2.0,z*ZOOM_RATE*delta))
	if absf(zoom-_zoom_to) > _zoom_to*0.001:
		zoom = lerpf(zoom,_zoom_to,1.0-exp(-delta*14.0))
		centre = _clamp(centre)
		moved = true
	elif zoom != _zoom_to:
		zoom = _zoom_to
		centre = _clamp(centre)
	if moved or _age < 0.4: _view.queue_redraw()
	if _age < 0.4: queue_redraw()

func _input(event: InputEvent) -> void:
	if not is_open(): return
	var view := get_viewport()
	if event is InputEventMouseMotion:
		if _drag and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			centre = _clamp(centre-(event as InputEventMouseMotion).relative/zoom)
			_view.queue_redraw()
		view.set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		var at := b.position-_view.global_position
		if b.button_index == MOUSE_BUTTON_LEFT: _drag = b.pressed
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_by(ZOOM_STEP,at)
		elif b.pressed and b.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_by(1.0/ZOOM_STEP,at)
		_view.queue_redraw()
		view.set_input_as_handled()
		return
	# The stick's and the triggers' leans are read in `_process`.
	if event is InputEventJoypadMotion:
		view.set_input_as_handled()
		return
	var key := event as InputEventKey
	var code := KEY_NONE
	if key != null and key.pressed: code = key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	var fresh := key == null or not key.echo
	var joy := event as InputEventJoypadButton
	var pad := joy.button_index if joy != null and joy.pressed else JOY_BUTTON_INVALID
	if (code in [KEY_M,KEY_ESCAPE] and fresh) or event.is_action_pressed(&"ui_cancel") or pad == JOY_BUTTON_BACK: close_map()
	elif code in [KEY_E,KEY_EQUAL,KEY_PLUS,KEY_KP_ADD]: zoom_by(ZOOM_STEP)
	elif code in [KEY_Q,KEY_MINUS,KEY_KP_SUBTRACT]: zoom_by(1.0/ZOOM_STEP)
	elif (code == KEY_C and fresh) or pad == JOY_BUTTON_Y: look_at(plane_at())
	elif key == null and joy == null: return
	# Every key and button stops here while the map is up.
	view.set_input_as_handled()

# --- Drawing -----------------------------------------------------------------------------

func _draw() -> void:
	if game == null: return
	var k := Kit.scale_of(size)
	var arrive := Kit.slip_in(_age)
	var a := arrive.y
	draw_rect(Rect2(Vector2.ZERO,size),Color(Kit.NIGHT,WASH_A*clampf(_age/WASH_T,0.0,1.0)))
	var r := _sheet()
	Kit.slip(self,r,k,a)
	Kit.head(self,r,r.position.y+8.0*k,k,"Map",30.0,0.0,Kit.VALUE_PAD+150.0,a)
	var where := "Wilderness" if _land else "Uncharted"
	Kit.text(self,Kit.MED,where.to_upper(),Vector2(r.end.x-Kit.VALUE_PAD*k-10.0*k,r.position.y+23.0*k),10.5,k,0.2,Kit.DIM,1.0,a)
	# The frame: a fine double rule round the map, as a printed sheet's.
	var f := _frame()
	draw_rect(f.grow(4.0*k),Color(Kit.INK,0.55*a),false,maxf(roundf(1.0*k),1.0))
	draw_rect(f.grow(1.0*k),Color(Kit.INK,0.25*a),false,1.0)
	_view.modulate.a = a
	Kit.prompts(self,Kit.pick(FOOT),size-Vector2(28.0,50.0)*k,k,true,false,a)

func _draw_sheet() -> void:
	var v := _view
	var k := Kit.scale_of(size)
	var b := box()
	var tl := to_screen(b.position)
	var br := to_screen(b.end)
	v.draw_rect(Rect2(Vector2.ZERO,v.size),Color("ece5d0") if not _land else Color("2c7096"))
	if _land and _tex != null:
		v.draw_texture_rect(_tex,Rect2(tl,br-tl),false)
	_draw_grid(v,k)
	if _land:
		for p: Dictionary in _places:
			if p.has("line"): _draw_line(v,p.line,k)
	# The finds found, then the start, then the places' marks and names, then
	# the plane over all.
	for f: Dictionary in _finds:
		if old_marks: _diamond(v,to_screen(f.at),3.0*k,Kit.GOLD,Kit.INK)
		else: _mark(v,str(f.glyph),to_screen(f.at),FIND_D,k,Kit.GOLD)
	_draw_start(v,to_screen(_start()),k)
	_draw_places(v,k)
	_draw_plane(v,k)
	_draw_furniture(v,k)

## Faint kilometre lines (the only land there is off the picture).
func _draw_grid(v: Control, k: float) -> void:
	var grid := 1000.0
	var col := Color(Kit.INK,0.07 if _land else 0.12)
	var w0 := centre-v.size*0.5/zoom
	var w1 := centre+v.size*0.5/zoom
	var x := ceilf(w0.x/grid)*grid
	while x <= w1.x:
		var sx := roundf(to_screen(Vector2(x,0)).x)
		v.draw_line(Vector2(sx,0),Vector2(sx,v.size.y),col,1.0)
		x += grid
	var z := ceilf(w0.y/grid)*grid
	while z <= w1.y:
		var sy := roundf(to_screen(Vector2(0,z)).y)
		v.draw_line(Vector2(0,sy),Vector2(v.size.x,sy),col,1.0)
		z += grid

## A road or channel: a dashed ink line along its points.
func _draw_line(v: Control, line: Array, k: float) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in line: pts.append(to_screen(p))
	var dash := 5.0*k
	for i in pts.size()-1:
		var a := pts[i]
		var b := pts[i+1]
		var run := a.distance_to(b)
		var t := 0.0
		while t < run:
			v.draw_line(a.lerp(b,t/run),a.lerp(b,minf(t+dash,run)/run),Color(Kit.INK,0.75),maxf(1.6*k,1.0),true)
			t += dash*1.8

func _draw_places(v: Control, k: float) -> void:
	var taken: Array[Rect2] = []
	if not old_marks:
		# The finds' marks and the start's keep the names off them.
		for f: Dictionary in _finds: taken.append(_mark_rect(to_screen(f.at),FIND_D,k))
		taken.append(_mark_rect(to_screen(_start()),START_D,k))
	var order := _places.duplicate()
	# The Peak's name first, then the rest by kind.
	order.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return _rank(p) < _rank(q))
	for p: Dictionary in order:
		var at := to_screen(p.at)
		if not old_marks:
			var d := _mark_d(p)
			if d > 0.0:
				_mark(v,str(p.glyph),at,d,k,MARK_RIM)
				taken.append(_mark_rect(at,d,k))
			continue
		match str(p.kind):
			"ruin":
				v.draw_rect(Rect2(at-Vector2(3.5,3.5)*k,Vector2(7.0,7.0)*k),Kit.CREAM)
				v.draw_rect(Rect2(at-Vector2(3.5,3.5)*k,Vector2(7.0,7.0)*k),Kit.INK,false,maxf(1.5*k,1.0))
				taken.append(Rect2(at-Vector2(4.0,4.0)*k,Vector2(8.0,8.0)*k))
			"temple":
				var t := PackedVector2Array([at+Vector2(0,-4.5)*k,at+Vector2(4.5,3.0)*k,at+Vector2(-4.5,3.0)*k])
				v.draw_colored_polygon(t,Kit.GOLD)
				v.draw_polyline(t+PackedVector2Array([t[0]]),Kit.INK,maxf(1.4*k,1.0),true)
				taken.append(Rect2(at-Vector2(5.0,5.0)*k,Vector2(10.0,9.0)*k))
			"falls":
				v.draw_circle(at,3.4*k,Color(WATER_INK,0.95))
				v.draw_circle(at,1.4*k,Color("ece5d0"))
				taken.append(Rect2(at-Vector2(4.0,4.0)*k,Vector2(8.0,8.0)*k))
	if not old_marks:
		# The plane, drawn over all, keeps the names off it too.
		if not pinned(): taken.append(_mark_rect(to_screen(plane_at()),PLANE_D*0.8,k))
		order.push_front({"name":"Start","kind":"start","at":_start()})
	for p: Dictionary in order:
		var at := to_screen(p.at)
		var kind := str(p.kind)
		var px := 11.0
		var face := Kit.MED
		var track := 0.14
		var col := Kit.INK
		var s := str(p.name).to_upper()
		if kind == "peak":
			face = Kit.SERIF
			px = 22.0
			track = 0.02
			s = str(p.name)
		elif kind == "falls": col = WATER_INK
		elif kind == "start":
			px = 9.5
			track = 0.2
			col = Kit.DIM
		elif kind == "road":
			face = Kit.NUM
			px = 10.5
			track = 0.06
			s = str(p.name)
			col = Kit.LAND
		var w := Kit.text_w(face,s,px,k,track)
		var h := px*k*1.1
		var gap := 7.0*k if old_marks else ((START_D if kind == "start" else _mark_d(p))*0.5+RIM+3.0)*k
		var tries := [Vector2(gap,-h*0.5),Vector2(-gap-w,-h*0.5),Vector2(-w*0.5,-gap-h),Vector2(-w*0.5,gap)]
		if kind == "road" or (kind == "peak" and old_marks): tries = [Vector2(-w*0.5,-h*0.5),Vector2(-w*0.5,-h*1.6),Vector2(-w*0.5,h*0.6)]
		# The Peak's name under its mark, else over it.
		elif kind == "peak": tries = [Vector2(-w*0.5,gap-1.0*k),Vector2(-w*0.5,-gap-h),Vector2(gap,-h*0.5)]
		for o: Vector2 in tries:
			var cell := Rect2(at+o,Vector2(w,h))
			var clear := true
			for t: Rect2 in taken:
				if t.intersects(cell): clear = false
			if not clear: continue
			taken.append(cell)
			_label(v,face,s,Vector2(cell.position.x,cell.get_center().y),px,k,track,col)
			break

## A place's disc, mock px across (0: no mark, a road's name alone).
static func _mark_d(p: Dictionary) -> float:
	if str(p.get("glyph","")) == "": return 0.0
	return PEAK_D if str(p.kind) == "peak" else MARK_D

static func _mark_rect(at: Vector2, d: float, k: float) -> Rect2:
	return Rect2(at-Vector2.ONE*(d*0.5+RIM)*k,Vector2.ONE*(d+RIM*2.0)*k)

## A mark: the glyph `id` on an ink disc `d` mock px across, its rim `rim`,
## a soft shadow under it so it stands off the land.
func _mark(v: Control, id: String, at: Vector2, d: float, k: float, rim: Color) -> void:
	var r := d*0.5*k
	var w := RIM*k
	v.draw_circle(at+Vector2(0.0,1.4*k),r+w+0.6*k,Color(Kit.NIGHT,0.3),true,-1.0,true)
	v.draw_circle(at,r+w,rim,true,-1.0,true)
	v.draw_circle(at,r,Kit.INK,true,-1.0,true)
	Book.glyph(v,id,"icon",at,d*GLYPH_IN*k)

static func _rank(p: Dictionary) -> int:
	return ["peak","ruin","temple","falls","road"].find(str(p.kind))

## Words with a paper halo, so a contour never runs through them.
func _label(v: Control, which: int, s: String, at: Vector2, px: float, k: float, track: float, col: Color) -> void:
	var ipx := maxi(roundi(px*k),4)
	var f := Kit.face(which,ipx,track)
	var base_y := roundf(at.y+(f.get_ascent(ipx)-f.get_descent(ipx))*0.5)
	v.draw_string_outline(f,Vector2(roundf(at.x),base_y),s,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,maxi(roundi(4.0*k),2),Color("efe8d4",0.85))
	v.draw_string(f,Vector2(roundf(at.x),base_y),s,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,col)

func _draw_start(v: Control, at: Vector2, k: float) -> void:
	if not old_marks:
		# Its name goes with the places' (`_draw_places`), clear of the marks.
		_mark(v,"start",at,START_D,k,MARK_RIM)
		return
	v.draw_arc(at,5.0*k,0.0,TAU,20,Color(Kit.INK,0.85),maxf(1.3*k,1.0),true)
	v.draw_circle(at,1.6*k,Color(Kit.INK,0.85))
	_label(v,Kit.MED,"START",at+Vector2(8.0*k,0.0),9.5,k,0.2,Kit.DIM)

func _diamond(v: Control, at: Vector2, r: float, col: Color, rim: Color) -> void:
	v.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-r-1.0),at+Vector2(r+1.0,0),at+Vector2(0,r+1.0),at+Vector2(-r-1.0,0)]),rim)
	v.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-r),at+Vector2(r,0),at+Vector2(0,r),at+Vector2(-r,0)]),col)

## The plane: a red arrow its heading's way; outside the frame, pinned to its
## edge and pointing to it, with how far.
func _draw_plane(v: Control, k: float) -> void:
	var p := plane_at()
	var at := to_screen(p)
	var inner := _inner()
	var h := _heading()
	var way := Vector2(-sin(h),-cos(h))
	if not pinned():
		_arrow(v,at,way,k,1.0)
		return
	# Pinned: where the line from the middle to the plane leaves the inner frame.
	var mid := v.size*0.5
	var d := at-mid
	var t := minf(absf((inner.size.x*0.5)/maxf(absf(d.x),0.001)),absf((inner.size.y*0.5)/maxf(absf(d.y),0.001)))
	var pin := mid+d*t
	var dir := d.normalized()
	_arrow(v,pin,dir,k,0.85)
	var km := (p-(centre+(pin-mid)/zoom)).length()/1000.0
	var s := ("%.1f km" % km) if km < 10.0 else ("%d km" % roundi(km))
	if km < 0.5: return
	var w := Kit.text_w(Kit.NUM,s,11.0,k)
	# Behind the arrow, clear of it however it points.
	var o := -dir*(22.0*k+w*0.5*absf(dir.x)+6.0*k*absf(dir.y))
	_label(v,Kit.NUM,s,pin+o-Vector2(w*0.5,0.0),11.0,k,0.0,Kit.INK)

func _arrow(v: Control, at: Vector2, way: Vector2, k: float, sc: float) -> void:
	if not old_marks:
		_plane_mark(v,at,way,k,sc)
		return
	var side := Vector2(-way.y,way.x)
	var l := 13.0*k*sc
	var tip := at+way*l
	var tail := at-way*l*0.55
	var pts := PackedVector2Array([tip,at-way*l*0.75+side*l*0.62,tail,at-way*l*0.75-side*l*0.62])
	var rim := PackedVector2Array()
	for q in pts: rim.append(q+(q-at).normalized()*2.2*k)
	v.draw_colored_polygon(rim,Color("efe8d4"))
	v.draw_colored_polygon(pts,Color(Kit.TICK,1.0))
	v.draw_polyline(pts+PackedVector2Array([pts[0]]),Color(Kit.INK,0.9),maxf(1.0*k,1.0),true)

## The plane: the dart glyph (nose up, the tick's colour) turned to
## `way`, cut out of the land by an ink line and a paper rim round it.
func _plane_mark(v: Control, at: Vector2, way: Vector2, k: float, sc: float) -> void:
	var px := maxf(roundf(PLANE_D*k*sc),6.0)
	var body := Glyphs.texture("dart","icon",px)
	var cut := Glyphs.texture("dart","shadow",px)
	if body == null or cut == null: return
	var sz := Vector2(body.get_size())
	var r := Rect2(-sz*0.5,sz)
	v.draw_set_transform(at,atan2(way.x,-way.y))
	for i in 12:
		var o := Vector2.from_angle(TAU*i/12.0)
		v.draw_texture_rect(cut,Rect2(r.position+o*3.2*k+Vector2(0.0,1.4*k).rotated(-atan2(way.x,-way.y)),r.size),false,Color(Kit.NIGHT,0.1))
	for i in 12:
		var o := Vector2.from_angle(TAU*i/12.0)
		v.draw_texture_rect(cut,Rect2(r.position+o*3.0*k,r.size),false,MARK_RIM)
	for i in 8:
		var o := Vector2.from_angle(TAU*i/8.0)
		v.draw_texture_rect(cut,Rect2(r.position+o*1.4*k,r.size),false,Kit.INK)
	v.draw_texture_rect(body,r,false)
	v.draw_set_transform(Vector2.ZERO)

## The north mark and the scale bar.
func _draw_furniture(v: Control, k: float) -> void:
	# North: an arrow and N, top right.
	var n := Vector2(v.size.x-26.0*k,30.0*k)
	v.draw_circle(n+Vector2(0,4.0)*k,17.0*k,Color("efe8d4",0.8))
	v.draw_colored_polygon(PackedVector2Array([n+Vector2(0,-14)*k,n+Vector2(5,4)*k,n+Vector2(0,0)*k]),Color(Kit.INK,0.85))
	v.draw_colored_polygon(PackedVector2Array([n+Vector2(0,-14)*k,n+Vector2(0,0)*k,n+Vector2(-5,4)*k]),Color(Kit.INK,0.3))
	_label(v,Kit.SERIF,"N",n+Vector2(-Kit.text_w(Kit.SERIF,"N",13.0,k)*0.5,14.0*k),13.0,k,0.0,Kit.INK)
	# The scale: the round length nearest a fifth of the frame.
	var want := v.size.x*0.16/zoom
	var span := 100.0
	for m: float in [100.0,200.0,250.0,500.0,1000.0,2000.0,2500.0,5000.0]:
		if m <= want: span = m
	var w := span*zoom
	var o := Vector2(18.0*k,v.size.y-18.0*k)
	var bar := Rect2(o-Vector2(0,4.0*k),Vector2(w,4.0*k))
	v.draw_rect(bar.grow(2.0*k),Color("efe8d4",0.85))
	v.draw_rect(bar,Color(Kit.INK,0.85),false,1.0)
	v.draw_rect(Rect2(bar.position,Vector2(w*0.5,bar.size.y)),Color(Kit.INK,0.85))
	var s := ("%d m" % int(span)) if span < 1000.0 else ("%s km" % str(span/1000.0).trim_suffix(".0"))
	_label(v,Kit.NUM,s,o+Vector2(w+8.0*k,-2.0*k),11.0,k,0.0,Kit.INK)
