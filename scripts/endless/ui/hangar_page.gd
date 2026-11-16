extends Control
## The hangar (docs/design/endless-flight/spec-hangar.md): a slip down the
## left where the plane's look (scripts/endless/plane_look.gd) is set part by
## part, over the live plane with the eye going round it. A page of the menus
## (menu_base.gd `open_hangar`): the title's and the pause menu's Hangar rows
## open it, and `--hangar` opens it as the game starts.
##
## Each part of the look is a section, a script of its own in
## scripts/endless/ui/hangar/ (paint_section.gd says what a section is). The
## page shows one section's rows at a time; with more than one in SECTIONS a
## Part row at the top picks which.
##
## A change is on the plane at once and in the book (PilotBook `set_look`,
## then ShopStock `dress`, which is all that repaints: nothing here paints
## per frame). The book is written when the page closes. Reset takes the
## look off again: the plane wears its skin as the shop sells it.
##
## The eye: the plane is held to the right of the slip (the camera's
## picture slid sideways: `set_frustum`'s offset). On the title the stage's orbit carries on (menu_stage.gd);
## under pause the tree is held, so the page circles the camera itself and
## puts it back on leaving. Q E, the right stick or a drag off the slip turn
## the eye round the plane.
##
## The contract with what opens it is the settings page's: `setup(host)`
## before it enters the tree, every event taken while up, `closed` once on
## leaving.

signal closed

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
const Pad = preload("res://scripts/pad.gd")
const StickSteps = preload("res://scripts/endless/ui/stick_steps.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const MenuStage = preload("res://scripts/endless/menu_stage.gd")
const ShopStock = preload("res://scripts/endless/shop_stock.gd")

## The sections, in the Part row's order. A new part of the look adds its
## script here.
const SECTIONS: Array[GDScript] = [
	preload("res://scripts/endless/ui/hangar/paint_section.gd"),
	preload("res://scripts/endless/ui/hangar/decal_section.gd"),
]

## Measures, px in the mock-ups' 1280x800 frame (the settings page's).
const SLIP_AT := Vector2(72.0,150.0)
const SLIP_W := 452.0
const PAD_TOP := 8.0
const PAD_FOOT := 12.0
const HEAD_H := 30.0
const ROW_H := 28.0
const BACK_H := 30.0
const BACK_GAP := 8.0
## A swatch's width and the gap to the next.
const SWATCH := Vector2(13.0,4.0)
## A list row: a line's height, the lines shown (a row may say its own) and
## the space under the last.
const LIST_LINE := 21.0
const LIST_LINES := 8
const LIST_FOOT := 4.0
const FOOT := [["Up Down","D-pad","select"],["Left Right","Left Right","change"],["Q E","R stick","turn"],["Esc","B","back"]]

## The eye: the plane stands SHIFT of the view's width right of its middle
## (eased in over SHIFT_T s); under pause the eye circles ORBIT_R wingspans
## out and ORBIT_UP up, reached from the flight's eye over SWING s; TURN is
## Q E's and the stick's rate (rad/s), DRAG a mouse drag's (rad/px).
const SHIFT := 0.19
const SHIFT_T := 0.4
const ORBIT_R := 2.5
const ORBIT_UP := 0.45
const SWING := 0.7
const TURN := 1.6
const DRAG := 0.008
const EYE_OVER := 0.4

## For the pause menu: the scene under this page is what it shows, so no
## wash is drawn over it.
var shows_scene := true
var host: Node
var book: PilotBook
## The look being edited (PlaneLook), and whether the book holds it.
var look := {}
## The section shown: an index into SECTIONS.
var part := 0
## The row selected: an index into `rows`.
var sel := 1
## The rows shown now: {head}, a section's rows ({id, label, kind, ...}),
## the page's own (ids starting "_") and {back}.
var rows: Array[Dictionary] = []
var _sections: Array[RefCounted] = []
var _sel_t := PackedFloat32Array()
var _age := 0.0
var _drag := -1
var _turning := false
var _spin := 0.0
var _stick := StickSteps.new()
var _mouse_was := Input.MOUSE_MODE_VISIBLE
var _closing := false
## Under pause: the camera as it was, and the orbit's angle.
var _own_eye := false
var _eye_was := Transform3D.IDENTITY
var _fov_was := 0.0
var _angle := 0.0

func setup(by: Node) -> void:
	host = by

func _init() -> void:
	name = "HangarPage"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _enter_tree() -> void:
	_mouse_was = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not Pad.hub.device_changed.is_connected(_device_changed): Pad.hub.device_changed.connect(_device_changed)
	book = host.get("book") if host != null else null
	if book == null:
		book = PilotBook.new()
		book.path = ""
	look = PlaneLook.of(book,ShopStock.item(ShopStock.worn(book,"paint")))
	_sections.clear()
	for script in SECTIONS:
		var s: RefCounted = script.new()
		s.begin(look)
		_sections.append(s)
	_rebuild()
	_take_eye()

func _exit_tree() -> void:
	if Pad.hub.device_changed.is_connected(_device_changed): Pad.hub.device_changed.disconnect(_device_changed)
	_give_eye()
	if book != null: book.save()

func _device_changed(_pad: bool) -> void:
	queue_redraw()

# --- The rows ----------------------------------------------------------------------------

func _rebuild() -> void:
	rows.clear()
	rows.append({"head":"Hangar"})
	if _sections.size() > 1:
		var names: Array[String] = []
		for script in SECTIONS: names.append(str(script.get("TITLE")))
		rows.append({"id":"_part","label":"Part","kind":"seg","opts":names,"on":part})
	rows.append_array(_sections[part].rows())
	rows.append({"id":"_reset","label":"Reset to skin","kind":"button"})
	rows.append({"back":true})
	if _sel_t.size() != rows.size():
		_sel_t.resize(rows.size())
		_sel_t.fill(Kit.OFF)
		sel = clampi(sel,1,rows.size()-1)
		_sel_t[sel] = 0.0
	queue_redraw()

func is_row(i: int) -> bool:
	return i >= 0 and i < rows.size() and not rows[i].has("head")

## The id of the row selected ("back" on Back).
func selected() -> String:
	return "back" if rows[sel].has("back") else str(rows[sel]["id"])

## The index of the row with `id`, or -1.
func row_of(id: String) -> int:
	for i in rows.size():
		if str(rows[i].get("id","back" if rows[i].has("back") else "")) == id: return i
	return -1

func select(i: int) -> void:
	if not is_row(i) or i == sel: return
	_sel_t[sel] = -0.0001
	sel = i
	_sel_t[i] = 0.0
	queue_redraw()

func move(n: int) -> void:
	# In a list row Up and Down step through its parts, and leave it at its ends.
	if absi(n) == 1 and str(rows[sel].get("kind","")) == "list":
		var to := int(rows[sel].on)+n
		if to >= 0 and to < (rows[sel].names as Array).size():
			change(n)
			return
	var i := sel
	for _s in absi(n):
		i = posmod(i+signi(n),rows.size())
		while not is_row(i): i = posmod(i+signi(n),rows.size())
	select(i)

## Left or Right on the row selected.
func change(dir: int) -> void:
	var row := rows[sel]
	if row.has("back") or str(row.kind) == "button": return
	var id := str(row.id)
	if id == "_part": _show_part(clampi(part+dir,0,_sections.size()-1))
	elif _sections[part].change(id,dir): _changed()
	_rebuild()

## The mouse on row `i`: a slider's 0..1, or the option or swatch clicked.
func set_to(i: int, v: float) -> void:
	var id := str(rows[i].id)
	if id == "_part": _show_part(clampi(int(v),0,_sections.size()-1))
	elif _sections[part].set_to(id,v): _changed()
	_rebuild()

## Enter on the row selected: Back leaves, Reset resets, options step round.
func accept() -> void:
	var row := rows[sel]
	if row.has("back"): close()
	elif str(row.id) == "_reset": reset()
	elif str(row.kind) == "seg":
		var n := (row.opts as Array).size()
		set_to(sel,float((int(row.on)+1)%n))

func _show_part(to: int) -> void:
	if to == part: return
	part = to
	_sel_t.resize(0)

## The look changed: kept in the book and put on the plane.
func _changed() -> void:
	book.set_look(look.duplicate(true))
	_dress()

## The look taken off: the plane wears its skin as the shop sells it.
func reset() -> void:
	book.set_look({})
	_dress()
	look = PlaneLook.of(book,ShopStock.item(ShopStock.worn(book,"paint")))
	for s in _sections: s.begin(look)
	_rebuild()

func _dress() -> void:
	var figure: Node3D = host.get("plane_figure") if host != null else null
	if figure != null: ShopStock.dress(figure,book)

func close() -> void:
	if _closing: return
	_closing = true
	_drag = -1
	Input.mouse_mode = _mouse_was
	closed.emit()
	queue_free()

# --- Layout ------------------------------------------------------------------------------

func _k() -> float:
	return Kit.scale_of(size)

func _row_h(row: Dictionary) -> float:
	if str(row.get("kind","")) == "list": return ROW_H+_list_lines(row)*LIST_LINE+LIST_FOOT
	return HEAD_H if row.has("head") else (BACK_H if row.has("back") else ROW_H)

## A list row's lines shown, and the first of them: the part picked is kept
## in the middle of the window where the list is longer than it.
func _list_lines(row: Dictionary) -> int:
	return mini(int(row.get("lines",LIST_LINES)),(row.names as Array).size())

func _list_first(row: Dictionary) -> int:
	var lines := _list_lines(row)
	return clampi(int(row.on)-lines/2,0,(row.names as Array).size()-lines)

## A list row's lines now, top to bottom: [index into its names, rect].
func list_rects(i: int) -> Array:
	var row := rows[i]
	var k := _k()
	var slip := slip_rect()
	var first := _list_first(row)
	var out := []
	for j in _list_lines(row):
		out.append([first+j,Rect2(slip.position.x+Kit.LABEL_X*k,row_top(i)+(ROW_H+j*LIST_LINE)*k,slip.size.x-(Kit.LABEL_X+Kit.VALUE_PAD)*k,LIST_LINE*k)])
	return out

func slip_rect() -> Rect2:
	var k := _k()
	var h := PAD_TOP+PAD_FOOT+BACK_GAP
	for row in rows: h += _row_h(row)
	return Rect2((SLIP_AT*k).round(),Vector2(roundf(SLIP_W*k),roundf(h*k)))

func row_top(i: int) -> float:
	var k := _k()
	var y := PAD_TOP
	for j in rows.size():
		if rows[j].has("back"): y += BACK_GAP
		if j == i: break
		y += _row_h(rows[j])
	return roundf(SLIP_AT.y*k)+y*k

func row_rect(i: int) -> Rect2:
	return Kit.row_rect(slip_rect(),row_top(i),_k(),_row_h(rows[i]))

func option_rects(i: int) -> Array[Rect2]:
	var row := rows[i]
	return Kit.seg_rects(slip_rect(),row_top(i),_k(),PackedStringArray(row.opts as Array),int(row.on),ROW_H)

func track_rect(i: int) -> Rect2:
	return Kit.slider_rect(slip_rect(),row_top(i),_k(),ROW_H)

## A swatches row's chips, left to right, ended where the options end.
func swatch_rects(i: int) -> Array[Rect2]:
	var k := _k()
	var n := (rows[i].colours as Array).size()
	var out: Array[Rect2] = []
	var x := slip_rect().end.x-Kit.VALUE_PAD*k-(n*SWATCH.x+(n-1)*SWATCH.y)*k
	for j in n:
		out.append(Rect2(x,row_top(i)+7.0*k,SWATCH.x*k,(ROW_H-14.0)*k))
		x += (SWATCH.x+SWATCH.y)*k
	return out

func _row_at(at: Vector2) -> int:
	for i in rows.size():
		if is_row(i) and row_rect(i).has_point(at): return i
	return -1

# --- Time and drawing --------------------------------------------------------------------

func _process(delta: float) -> void:
	_age += delta
	var moving := _age < Kit.T_SLIP+0.1 or _drag >= 0
	for i in rows.size():
		if not is_row(i): continue
		var t := _sel_t[i]
		if i == sel: t = Kit.ON if t > 0.5 else maxf(t,0.0)+delta
		else: t = Kit.OFF if t < -0.5 else minf(t,0.0)-delta
		_sel_t[i] = t
		if absf(t) < 0.6: moving = true
	_step_stick(delta)
	_eye(delta)
	if moving: queue_redraw()

func _draw() -> void:
	var k := _k()
	var arrive := Kit.slip_in(_age)
	var a := arrive.y
	var slip := slip_rect()
	slip.position.x -= roundf(arrive.x*k)
	Kit.slip(self,slip,k,a)
	for i in rows.size():
		var row := rows[i]
		var y := row_top(i)
		if row.has("head"):
			Kit.head(self,slip,y,k,str(row.head),HEAD_H,6.0,38.0,a)
		elif row.has("back"):
			Kit.row(self,slip,y,k,"Back",_sel_t[i],BACK_H,15.0,"B" if Pad.using_pad() else "Esc",42.0,a)
		else:
			match str(row.kind):
				"slider":
					var track := Kit.slider_row(self,slip,y,k,str(row.label),float(row.frac),str(row.value),_sel_t[i],ROW_H,15.0,a)
					if row.has("ramp"): _draw_ramp(track,row.ramp,k,a)
				"seg":
					var rects := Kit.seg_row(self,slip,y,k,str(row.label),PackedStringArray(row.opts as Array),int(row.on),_sel_t[i],Kit.ON,ROW_H,15.0,a)
					var dots: Array = row.get("dots",[])
					for j in mini(dots.size(),rects.size()):
						# Each option's colour, a bar over its name.
						var bar := Rect2(rects[j].position.x,rects[j].get_center().y-12.0*k,rects[j].size.x-2.0*k,maxf(roundf(4.0*k),2.0))
						draw_rect(bar.grow(maxf(roundf(k),1.0)),Color(Kit.INK,0.45*a))
						draw_rect(bar,Color(dots[j] as Color,a))
				"swatches":
					Kit.row(self,slip,y,k,str(row.label),_sel_t[i],ROW_H,15.0,"",0.0,a)
					var chips := swatch_rects(i)
					for j in chips.size():
						var c := chips[j]
						if j == int(row.on): draw_rect(c.grow(3.0*k),Color(Kit.TICK if _sel_t[i] >= 0.0 else Kit.INK,a),false,maxf(roundf(1.5*k),1.0))
						draw_rect(c.grow(maxf(roundf(k),1.0)),Color(Kit.INK,0.45*a))
						draw_rect(c,Color((row.colours as Array)[j] as Color,a))
				"list":
					var names: Array = row.names
					var notes: Array = row.get("notes",[])
					Kit.row(self,slip,y,k,str(row.label),_sel_t[i],ROW_H,15.0,"%d / %d" % [int(row.on)+1,names.size()],Kit.VALUE_PAD,a)
					var first := _list_first(row)
					var lines := list_rects(i)
					for line: Array in lines:
						var at: int = line[0]
						var r: Rect2 = line[1]
						var cy := r.get_center().y
						var on := at == int(row.on)
						if on:
							draw_rect(Rect2(r.position.x,r.position.y+1.0*k,r.size.x,r.size.y-2.0*k),Color(Kit.BAND,Kit.BAND.a*a))
							Kit.slant(self,Rect2(r.position.x+5.0*k,cy-5.5*k,3.0*k,11.0*k),Color(Kit.TICK if _sel_t[i] >= 0.0 else Kit.INK,a))
						Kit.text(self,Kit.NUM if on else Kit.MED,str(names[at]),Vector2(r.position.x+16.0*k,cy),14.0,k,0.02,Kit.INK if on else Kit.LAND,0.0,a)
						if at < notes.size(): Kit.text(self,Kit.MED,str(notes[at]).to_upper(),Vector2(r.end.x-6.0*k,cy),10.0,k,0.12,Kit.DIM,1.0,a)
					# More above or below the window: a mark at its edge.
					if first > 0: Kit.text(self,Kit.MED,"^",Vector2(slip.position.x+(Kit.LABEL_X-10.0)*k,(lines[0][1] as Rect2).get_center().y),11.0,k,0.0,Kit.DIM,0.5,a)
					if first+lines.size() < names.size(): Kit.text(self,Kit.MED,"v",Vector2(slip.position.x+(Kit.LABEL_X-10.0)*k,(lines[lines.size()-1][1] as Rect2).get_center().y),11.0,k,0.0,Kit.DIM,0.5,a)
				_:
					Kit.row(self,slip,y,k,str(row.label),_sel_t[i],ROW_H,15.0,"",0.0,a)
	Kit.prompts(self,Kit.pick(FOOT),size-Vector2(28.0,50.0)*k,k,true,false,a)

## A slider's colours, a strip under its track: `stops` evenly along it.
func _draw_ramp(track: Rect2, stops: Array, k: float, a: float) -> void:
	if stops.size() < 2: return
	var n := 33
	var w := track.size.x/float(n)
	var top := track.position.y+15.0*k
	for i in n:
		var f := (float(i)+0.5)/float(n)*float(stops.size()-1)
		var j := mini(int(f),stops.size()-2)
		var c: Color = (stops[j] as Color).lerp(stops[j+1] as Color,f-float(j))
		draw_rect(Rect2(track.position.x+w*i,top,ceilf(w),maxf(roundf(4.0*k),2.0)),Color(c,a))

# --- The eye -----------------------------------------------------------------------------

func _game() -> bool:
	return host != null and "camera" in host and "plane" in host and "ground_scale" in host and host.get("camera") != null and host.get("plane") != null

func _on_title() -> bool:
	return host.get("stage") != null and host.stage.holding()

## Under pause the camera is the page's: kept as it was, to put back.
func _take_eye() -> void:
	if not _game() or _on_title(): return
	var cam: Camera3D = host.camera
	_own_eye = true
	_eye_was = cam.global_transform
	_fov_was = cam.fov
	var off: Vector3 = cam.global_position-_centre()
	_angle = atan2(-off.x,-off.z)

func _give_eye() -> void:
	if not _game() or not is_instance_valid(host.camera): return
	var cam: Camera3D = host.camera
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.frustum_offset = Vector2.ZERO
	if not _own_eye: return
	_own_eye = false
	cam.global_transform = _eye_was
	cam.fov = _fov_was

func _centre() -> Vector3:
	return host.plane.position+host.ground_scale.lift()

func _eye(delta: float) -> void:
	if not _game(): return
	var cam: Camera3D = host.camera
	var turn := _spin
	_spin = 0.0
	if not _closing:
		turn += (float(Input.is_physical_key_pressed(KEY_E))-float(Input.is_physical_key_pressed(KEY_Q)))*TURN*delta
		for pad in Input.get_connected_joypads():
			var x := Input.get_joy_axis(pad,JOY_AXIS_RIGHT_X)
			if absf(x) > 0.25: turn += x*TURN*delta
	var centre := _centre()
	if _own_eye:
		var span: float = WorldScale.TOY_SPAN*host.ground_scale.size()
		_angle += MenuStage.ORBIT*delta+turn
		var eye := centre+Vector3(-sin(_angle),0.0,-cos(_angle))*ORBIT_R*span+Vector3.UP*ORBIT_UP*span
		if "field" in host and host.get("field") != null:
			var under := float(host.field.height(eye.x,eye.z))
			if not is_nan(under): eye.y = maxf(eye.y,under+EYE_OVER*span)
		var to := Transform3D(Basis.IDENTITY,eye).looking_at(centre,Vector3.UP)
		var w := smoothstep(0.0,SWING,_age)
		cam.global_transform = _eye_was.interpolate_with(to,w) if w < 1.0 else to
		cam.fov = lerpf(_fov_was,MenuStage.FOV,w)
	elif _on_title():
		host.stage.angle += turn
	# The plane to the right of the slip: the picture slid right by SHIFT of
	# its width, the eye where it was (the title parts the grass round it).
	var tall := 2.0*cam.near*tan(deg_to_rad(cam.fov)*0.5)
	cam.set_frustum(tall,Vector2(-SHIFT*tall*size.x/maxf(size.y,1.0)*smoothstep(0.0,SHIFT_T,_age),0.0),cam.near,cam.far)

# --- Input -------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if _closing or not is_visible_in_tree(): return
	var view := get_viewport()
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed: _key(key.keycode,key.echo)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _turning: _spin -= motion.relative.x*DRAG
		else: _point(motion.position)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and (button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			# The wheel over a list row steps through it.
			var over := _row_at(button.position)
			if over >= 0 and str(rows[over].get("kind","")) == "list":
				select(over)
				change(-1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed: _click(button.position)
			else:
				_drag = -1
				_turning = false
	elif event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if joy.pressed: _button(joy.button_index)
	elif event is InputEventJoypadMotion:
		pass
	else: return
	if view != null: view.set_input_as_handled()

func _key(code: Key, echo: bool) -> void:
	match code:
		KEY_UP, KEY_W: move(-1)
		KEY_DOWN, KEY_S: move(1)
		KEY_LEFT, KEY_A: change(-1)
		KEY_RIGHT, KEY_D: change(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if not echo: accept()
		KEY_ESCAPE:
			if not echo: close()

func _button(index: JoyButton) -> void:
	match index:
		JOY_BUTTON_DPAD_UP: move(-1)
		JOY_BUTTON_DPAD_DOWN: move(1)
		JOY_BUTTON_DPAD_LEFT: change(-1)
		JOY_BUTTON_DPAD_RIGHT: change(1)
		JOY_BUTTON_A: accept()
		JOY_BUTTON_B: close()

func _step_stick(delta: float) -> void:
	if _closing or not is_visible_in_tree():
		_stick.rest()
		return
	var dir := _stick.step(delta)
	if dir.y != 0: move(dir.y)
	elif dir.x != 0: change(dir.x)

func _point(at: Vector2) -> void:
	if _drag >= 0 and _drag < rows.size():
		set_to(_drag,Kit.slider_frac(track_rect(_drag),at.x))
		return
	var i := _row_at(at)
	if i >= 0: select(i)

func _click(at: Vector2) -> void:
	var i := _row_at(at)
	if i < 0:
		# Off the slip: a drag turns the eye.
		_turning = not slip_rect().has_point(at)
		return
	select(i)
	var row := rows[i]
	var k := _k()
	if row.has("back"):
		close()
		return
	match str(row.kind):
		"button": accept()
		"slider":
			var track := track_rect(i)
			if at.x < track.position.x-8.0*k or at.x > track.end.x+8.0*k: return
			_drag = i
			_point(at)
		"seg":
			var rects := option_rects(i)
			for o in rects.size():
				if rects[o].grow_individual(14.0*k,0.0,4.0*k,0.0).has_point(at):
					set_to(i,float(o))
					return
		"swatches":
			var chips := swatch_rects(i)
			for o in chips.size():
				if chips[o].grow(2.0*k).has_point(at):
					set_to(i,float(o))
					return
		"list":
			for line: Array in list_rects(i):
				if (line[1] as Rect2).has_point(at):
					set_to(i,float(line[0]))
					return
