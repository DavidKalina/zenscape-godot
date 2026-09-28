extends Control
## The Lantern Maker creation shell (docs/ui/DIRECTIONS.md, "B2 · Lantern
## Maker"): Lantern's glowing line glyphs laid out like Super Mario Maker 2's
## editor. The brushes run along the top (Land carries its form as a badge and
## opens the forms wheel), the hand modes and the Undo wisp run down the left,
## Mood, World and Craft down the right, Photo is the play button at the lower
## right, and a slim bottom holds the season and time scrubber over one hint
## line. Size and strength live on the cursor (scripts/lantern_cursor.gd).
## While you paint everything recedes but the brush in hand.
##
## It stands in for scripts/creation_palette.gd (--classic-shell brings that
## back) and keeps its interface: `buttons` by brush, `look_button`,
## `photo_button`, `mood_button`, `form_buttons`, `form_frame`, `hint.text`,
## `sync`, `contains_pointer`. The scene owns the state (`select_brush`,
## `set_looking`, `toggle_mood`); the shell only shows it and asks.
const Style = preload("res://scripts/lantern_style.gd")
const Slot = preload("res://scripts/lantern_slot.gd")
const Wheel = preload("res://scripts/lantern_wheel.gd")
const Scrubber = preload("res://scripts/lantern_scrubber.gd")
const Hint = preload("res://scripts/lantern_hint.gd")
const Cursor = preload("res://scripts/lantern_cursor.gd")
const MoodVeil = preload("res://scripts/lantern_mood.gd")
const Palette = preload("res://scripts/creation_palette.gd")
const Forms = preload("res://scripts/mountain_forms.gd")
## Holding Land this long opens the forms wheel (Mario Maker's parts wheel).
const HOLD_SECONDS := 0.3
## Empty dotted slots after the brushes, for brushes still to come.
const EMPTY_SLOTS := 3
## The 1 key flashes the wheel open this long to show the form it stepped to.
const KEY_WHEEL_SECONDS := 1.6
## Painting: the shell recedes over RECEDE_IN and returns RETURN_DELAY after release.
const RECEDE_IN := 0.2
const RETURN_DELAY := 0.5
const RETURN_OUT := 0.35
const LOOK_HINT := "Just looking  ·  Drag to orbit  ·  Double-click something to go there  ·  P for a photo  ·  Tab to create again"
const MOOD_HINT := "Click a mood  ·  Tune this mood for season, time, weather and colours  ·  Esc to close"
## "Other way" in hand: what a drag does with each brush.
const OTHER_WAY := {"land":"Drag to lower land","water":"Drag to drain water","meadow":"Drag to lift the meadow",
	"forest":"Drag to clear forest","path":"Drag to grow the path back"}
const WATER_BALL_HINT := "Hold to gather a ball of water  ·  Release to drop it  ·  Shift-drag drains"

var scene: Node3D
var editor: NativeChunkEditor
var entries: Array[Dictionary] = []
var buttons := {}
var look_button: Button
var photo_button: Button
var mood_button: Button
var paint_button: Button
var other_button: Button
var undo_button: Button
var world_button: Button
var craft_button: Button
var form_buttons := {}
var form_frame: Control
var wheel: Control
var hint: HBoxContainer
var scrubber: Control
var cursor: Control
var mood: Control
## The design canvas: 1440x900 units scaled to the window (`Style.ui_scale`).
var root := Control.new()
var frame := Panel.new()
var bar := HBoxContainer.new()
var modes_plate := Panel.new()
var modes := VBoxContainer.new()
var world_plate := Panel.new()
var world := VBoxContainer.new()
var bottom_plate := Panel.new()
var bottom := VBoxContainer.new()
var photo_group := Control.new()
## The brush in hand, alone at the top while painting.
var lantern: Button
var ui_scale := 1.0
var _recede := 0.0
var _released := 0.0
var _painted := false
var _hint_tween: Tween
var _last_state := ""
var _land_down := -1.0
var _wheel_by_hold := false
var _held_until := 0
var _wheel_close_at := -1.0
var _clock := 0.0

static func registered() -> Array[Dictionary]:
	return Palette.registered()

func brush_ids() -> Array:
	return entries.map(func(info: Dictionary) -> String: return info.brush_id)

func info_for(id: String) -> Dictionary:
	for info in entries:
		if info.brush_id == id: return info
	return {}

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	name = "LanternShell"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Glyphs are imported at 4x with mipmaps; sample them trilinearly.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	entries = registered()
	cursor = Cursor.new()
	add_child(cursor)
	cursor.setup(scene,self)
	root.name = "Design"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_bar()
	_build_modes()
	_build_world()
	_build_photo()
	_build_bottom()
	mood = MoodVeil.new()
	root.add_child(mood)
	mood.setup(scene,self)
	editor.tool_changed.connect(func(_tool: String) -> void: sync())
	editor.brush_changed.connect(func(_id: String) -> void: sync())
	editor.active_changed.connect(func(_enabled: bool) -> void: sync())
	editor.land_form_changed.connect(_form_changed)
	editor.stroke_finished.connect(func(_center: Vector3, _radius: float, _mode: String) -> void:
		if not _painted:
			_painted = true
			_fade_hint(2.5))
	get_viewport().size_changed.connect(fit)
	sync()
	fit.call_deferred()

## A plate and the box laid over it; `fit` sizes the plate to the box.
func _group(plate: Panel, box: BoxContainer, radius := 40) -> void:
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override("panel",Style.plate(radius))
	root.add_child(plate)
	box.add_theme_constant_override("separation",int(Style.GAP))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(box)

func _slot(id: String, title: String, side: String, box: Control, slot_size := Style.SLOT) -> Button:
	var slot: Button = Slot.new()
	slot.setup(id,title,slot_size,side)
	box.add_child(slot)
	return slot

# --- Parts bar and the forms wheel ------------------------------------------------

func _build_bar() -> void:
	frame.name = "PartsPlate"
	bar.name = "Parts"
	_group(frame,bar)
	for index in range(entries.size()):
		var info: Dictionary = entries[index]
		var id: String = info.brush_id
		var slot := _slot(id,info.title,"below",bar)
		slot.tooltip_text = info.title+("  ·  %d" % (index+1) if index < 9 else "")
		slot.pressed.connect(_brush_pressed.bind(id))
		buttons[id] = slot
	for i in range(EMPTY_SLOTS):
		var empty := _slot("empty","More brushes to come","",bar)
		empty.disabled = true
		empty.mouse_default_cursor_shape = Control.CURSOR_ARROW
		empty.underglow.modulate.a = 0.5
	if buttons.has("land"):
		var land: Button = buttons.land
		land.tooltip_text = "Land  ·  1  ·  hold or click again for its forms"
		land.button_down.connect(func() -> void: _land_down = _clock)
		land.button_up.connect(_land_up)
		land.set_badge("hill")
	wheel = Wheel.new()
	root.add_child(wheel)
	wheel.setup()
	wheel.picked.connect(func(id: String) -> void:
		editor.select_land_form(id)
		if not _wheel_by_hold: _close_wheel())
	form_frame = wheel
	form_buttons = wheel.buttons
	lantern = Slot.new()
	lantern.setup("land","",44.0,"")
	lantern.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lantern.modulate.a = 0.0
	root.add_child(lantern)

func _brush_pressed(id: String) -> void:
	# The release that ends a hold picks its form, not the brush again.
	if Time.get_ticks_msec() < _held_until: return
	if id == "land" and held() == "land":
		if wheel.open: _close_wheel()
		else: _open_wheel(-1.0)
		return
	scene.select_brush(id)
	editor.set("other_way",false)
	sync()

func _land_up() -> void:
	_land_down = -1.0
	if not _wheel_by_hold: return
	var id: String = wheel.form_at(get_viewport().get_mouse_position())
	if not id.is_empty(): editor.select_land_form(id)
	_held_until = Time.get_ticks_msec()+150
	_wheel_by_hold = false
	_close_wheel()

## Open the wheel; `seconds` > 0 closes it again after that long.
func _open_wheel(seconds: float) -> void:
	wheel.set_open(true)
	_wheel_close_at = _clock+seconds if seconds > 0.0 else -1.0
	sync()

func _close_wheel() -> void:
	wheel.set_open(false)
	_wheel_close_at = -1.0

func _form_changed(_id: String) -> void:
	# The 1 key steps the form: flash the wheel so the step shows.
	if not wheel.open and held() == "land" and not _wheel_by_hold: _open_wheel(KEY_WHEEL_SECONDS)
	elif _wheel_close_at > 0.0: _wheel_close_at = _clock+KEY_WHEEL_SECONDS
	sync()

# --- Hand modes, world column, Photo ------------------------------------------------

func _build_modes() -> void:
	modes_plate.name = "ModesPlate"
	modes.name = "Modes"
	_group(modes_plate,modes)
	paint_button = _slot("paint","Paint","right",modes)
	paint_button.tooltip_text = "Paint with the brush in hand"
	paint_button.pressed.connect(func() -> void:
		editor.set("other_way",false)
		if scene.looking: scene.set_looking(false)
		sync())
	other_button = _slot("lower","Other way","right",modes)
	other_button.tooltip_text = "Work the brush the other way: lower, drain, lift, clear  ·  or Shift-drag"
	other_button.pressed.connect(func() -> void:
		var on: bool = not editor.get("other_way") or scene.looking
		if scene.looking: scene.set_looking(false)
		editor.set("other_way",on)
		sync())
	look_button = _slot("look","Look","right",modes)
	look_button.tooltip_text = "Put the brush away and just look  ·  Tab"
	look_button.pressed.connect(func() -> void: scene.set_looking(not scene.looking))
	var divider := Control.new()
	divider.custom_minimum_size = Vector2(Style.SLOT,1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.draw.connect(func() -> void: divider.draw_line(Vector2(12,0),Vector2(Style.SLOT-12,0),Color(Style.LIGHT,0.3),1.0))
	modes.add_child(divider)
	undo_button = _slot("undo","Undo","right",modes)
	undo_button.toggle_mode = false
	undo_button.tint = Style.tint("undo")
	undo_button.tooltip_text = "Undo  ·  Cmd Z   Shift-click redoes  ·  Shift Cmd Z"
	undo_button.pressed.connect(func() -> void:
		var redo := Input.is_key_pressed(KEY_SHIFT)
		if redo: editor.redo()
		else: editor.undo()
		undo_button.hop(-1.0 if redo else 1.0))

func _build_world() -> void:
	world_plate.name = "WorldPlate"
	world.name = "World"
	_group(world_plate,world)
	mood_button = _slot("mood","Mood","left",world)
	mood_button.tooltip_text = "Moods: sky, light, weather, season and colours  ·  M"
	mood_button.pressed.connect(func() -> void: scene.toggle_mood())
	world_button = _slot("world","World","left",world)
	world_button.toggle_mode = false
	world_button.tooltip_text = "New plain, regenerate, save and the main menu"
	world_button.pressed.connect(_world_menu)
	craft_button = _slot("craft","Craft","left",world)
	craft_button.toggle_mode = false
	craft_button.tooltip_text = "Fine sculpt, paint and place tools"
	craft_button.pressed.connect(func() -> void: scene.set_building(true))

## The scene's World menu (studies/diorama.gd `_world_menu`), opened beside
## the World slot rather than under the old toolbar.
func _world_menu() -> void:
	var menu: MenuButton = scene.get("_world_menu")
	if menu == null: return
	var popup := menu.get_popup()
	menu.about_to_popup.emit()
	popup.reset_size()
	var rect := Rect2(world_button.get_screen_position(),world_button.size*ui_scale)
	popup.position = Vector2i(int(rect.position.x-popup.size.x-14.0*ui_scale),int(rect.get_center().y-popup.size.y*0.5))
	popup.popup()

func _build_photo() -> void:
	photo_group.name = "PhotoGroup"
	photo_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(photo_group)
	photo_button = _slot("photo","Photo","below",photo_group,Style.PHOTO_SLOT)
	photo_button.toggle_mode = false
	photo_button.label_always = true
	photo_button.tooltip_text = "Compose and take a photo, with no UI  ·  P"
	photo_button.caption.add_theme_font_size_override("font_size",13)
	photo_button._place_caption()
	photo_button.pressed.connect(func() -> void: scene.enter_photo())

func _build_bottom() -> void:
	bottom_plate.name = "ScrubberPlate"
	bottom_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_plate.add_theme_stylebox_override("panel",Style.plate(22))
	root.add_child(bottom_plate)
	bottom.name = "Bottom"
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation",6)
	root.add_child(bottom)
	scrubber = Scrubber.new()
	scrubber.setup(scene)
	scrubber.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottom.add_child(scrubber)
	hint = Hint.new()
	hint.name = "Hint"
	bottom.add_child(hint)

# --- State ---------------------------------------------------------------------------

## The brush in hand, or "" while looking or crafting.
func held() -> String:
	if scene.looking or not editor.active: return ""
	var id := editor.held_brush()
	return id if buttons.has(id) else ""

func sync() -> void:
	if scene == null: return
	var holding := held()
	var other: bool = editor.get("other_way") == true and not holding.is_empty()
	for id: String in buttons:
		buttons[id].set_pressed_no_signal(id == holding)
		buttons[id].set_held(id == holding)
	look_button.set_pressed_no_signal(scene.looking)
	look_button.set_held(scene.looking)
	paint_button.set_pressed_no_signal(not holding.is_empty() and not other)
	paint_button.set_held(not holding.is_empty() and not other)
	other_button.set_pressed_no_signal(other)
	other_button.set_held(other)
	var mood_open: bool = scene.has_method("mood_open") and scene.mood_open()
	mood_button.set_pressed_no_signal(mood_open)
	mood_button.set_held(mood_open)
	if holding != "land" and wheel.open and not _wheel_by_hold: _close_wheel()
	wheel.sync(editor.land_form)
	if buttons.has("land"):
		var form := str(Forms.form_entry(editor.land_form).get("glyph","land"))
		buttons.land.set_badge("hill" if editor.land_form == "hill" else form)
	if not holding.is_empty():
		lantern.glyph.texture = Style.glyph(holding)
		lantern.tint = Style.tint(holding)
		lantern.set_held(true)
	_sync_hint(holding,other,mood_open)

func _sync_hint(holding: String, other: bool, mood_open: bool) -> void:
	var ball: bool = editor.get("_ball_holding") == true
	var state := "look" if scene.looking else "mood" if mood_open else holding+("/"+editor.land_form if holding == "land" else "")+("/other" if other else "")
	if ball: state = "ball/%d" % int(editor.ball_volume)
	if state == _last_state: return
	_last_state = state
	var text := LOOK_HINT
	if ball:
		var volume := int(round(editor.ball_volume))
		var made := "a lake" if editor.ball_volume >= editor.LAKE_VOLUME else "a pond"
		text = "Release to drop it  ·  %d m³, %s" % [volume,made]+("  ·  it is full" if editor.ball_volume >= editor.BALL_MAX_VOLUME-0.01 else "  ·  Hold for more")
	elif mood_open: text = MOOD_HINT
	elif not scene.looking:
		text = str(info_for(holding).get("hint",""))
		if holding == "water" and editor.water_ball: text = WATER_BALL_HINT
		if holding == "land": text = str(Forms.form_entry(editor.land_form).get("hint",text))
		if other: text = str(OTHER_WAY.get(holding,text))+"  ·  Paint to go back"
		text = ("" if text.is_empty() else text+"  ·  ")+"[ ] size  ·  Shift [ ] strength"+("  ·  1 forms" if holding == "land" else "")
	hint.text = text
	hint.modulate.a = 1.0
	if _hint_tween != null: _hint_tween.kill()
	# Until the first stroke the how-to stays; after it, each change shows briefly.
	if _painted and not ball and not mood_open: _fade_hint(5.0)
	fit()

func _fade_hint(delay: float) -> void:
	if _hint_tween != null: _hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(delay)
	_hint_tween.tween_property(hint,"modulate:a",0.0,1.4)

func painting() -> bool:
	return editor._painting or editor.get("_ball_holding") == true

func _process(delta: float) -> void:
	_clock += delta
	if not is_visible_in_tree(): return
	# A hold on Land opens the wheel; releasing over a form picks it.
	if _land_down >= 0.0 and not _wheel_by_hold and _clock-_land_down >= HOLD_SECONDS and buttons.has("land") and buttons.land.button_pressed:
		if held() != "land": scene.select_brush("land")
		_wheel_by_hold = true
		_open_wheel(-1.0)
	if _wheel_by_hold:
		var under: String = wheel.form_at(get_viewport().get_mouse_position())
		for id: String in wheel.buttons: wheel.buttons[id]._hover_target = 1.0 if id == under else 0.0
	if _wheel_close_at > 0.0 and _clock >= _wheel_close_at: _close_wheel()
	# Painting: the shell recedes, and comes back a moment after release.
	var busy := painting()
	if busy:
		_released = 0.0
		_recede = move_toward(_recede,1.0,delta/RECEDE_IN)
		if wheel.open: _close_wheel()
	else:
		_released += delta
		if _released >= RETURN_DELAY: _recede = move_toward(_recede,0.0,delta/RETURN_OUT)
	var ball: bool = editor.get("_ball_holding") == true
	var fill := clampf(editor.ball_volume/editor.BALL_MAX_VOLUME,0.0,1.0) if ball else -1.0
	if buttons.has("water"): buttons.water.fill = fill
	lantern.fill = fill
	if ball: _sync_hint(held(),false,false)
	elif _last_state.begins_with("ball/"): sync()
	undo_button.disabled = editor.data._undo.is_empty() and editor.data._redo.is_empty()
	_apply_recede(ball)

func _apply_recede(ball: bool) -> void:
	var r := smoothstep(0.0,1.0,_recede)
	frame.modulate.a = 1.0-r
	bar.modulate.a = 1.0-r
	frame.position.y = _bar_y()-18.0*r
	bar.position.y = frame.position.y+12.0
	lantern.modulate.a = r
	for pair: Array in [[modes_plate,modes,-1.0],[world_plate,world,1.0]]:
		pair[0].modulate.a = 1.0-0.84*r
		pair[1].modulate.a = 1.0-0.84*r
		pair[0].position.x = _column_x(pair[2])+14.0*r*pair[2]
		pair[1].position.x = pair[0].position.x+12.0
	photo_group.modulate.a = 1.0-0.84*r
	# A growing water ball keeps its line: the hint reads its size.
	bottom_plate.modulate.a = 1.0-r
	bottom.modulate.a = 1.0 if ball else 1.0-r
	scrubber.modulate.a = 1.0-r if ball else 1.0

# --- Layout --------------------------------------------------------------------------

func _bar_y() -> float:
	return 20.0

## The left edge of a side column's plate: -1 the hands, 1 the world.
func _column_x(side: float) -> float:
	var width := Style.SLOT+24.0
	return Style.MARGIN if side < 0.0 else root.size.x-Style.MARGIN-width

func fit() -> void:
	if not is_inside_tree(): return
	var screen := get_viewport().get_visible_rect().size
	ui_scale = Style.ui_scale(screen)
	root.scale = Vector2.ONE*ui_scale
	root.size = screen/ui_scale
	var design := root.size
	# Parts bar: top centre, its plate 20 below the top edge.
	bar.size = bar.get_combined_minimum_size()
	frame.size = bar.size+Vector2(40,24)
	frame.position = Vector2((design.x-frame.size.x)*0.5,_bar_y())
	bar.position = frame.position+Vector2(20,12)
	# The wheel hangs from Land's centre.
	if buttons.has("land"):
		var land: Control = buttons.land
		wheel.position = bar.position+land.position+land.size*0.5
	lantern.position = Vector2((design.x-lantern.size.x)*0.5,14.0)
	# Side columns, vertically centred and mirrored.
	for pair: Array in [[modes_plate,modes,-1.0],[world_plate,world,1.0]]:
		var box: BoxContainer = pair[1]
		box.size = box.get_combined_minimum_size()
		pair[0].size = box.size+Vector2(24,24)
		pair[0].position = Vector2(_column_x(pair[2]),(design.y-pair[0].size.y)*0.5)
		box.position = pair[0].position+Vector2(12,12)
	# Photo, the play button, at the lower right.
	photo_group.size = Vector2.ONE*Style.PHOTO_SLOT
	photo_group.position = design-Vector2(Style.MARGIN,Style.MARGIN+22.0)-photo_group.size
	# The scrubber over the hint, bottom centre.
	bottom.size = Vector2(minf(design.x-2.0*(Style.MARGIN+Style.PHOTO_SLOT+24.0),1000.0),0)
	bottom.size = Vector2(bottom.size.x,bottom.get_combined_minimum_size().y)
	bottom.position = Vector2((design.x-bottom.size.x)*0.5,design.y-16.0-bottom.size.y)
	bottom_plate.size = scrubber.size+Vector2(28,4)
	bottom_plate.position = bottom.position+Vector2((bottom.size.x-bottom_plate.size.x)*0.5,-2.0)
	_apply_recede(false)
	# The scene's notices sit above Photo (studies/cozy_worlds.gd `_layout_shell`).
	if scene.has_method("_layout_shell"): scene._layout_shell()

## The shell's lowest point along the top, in viewport pixels: a first-run
## hint (scripts/camera_rig.gd) sits under it.
func top_clearance() -> float:
	var bottom_y := frame.position.y+frame.size.y+14.0
	if wheel.visible: bottom_y = maxf(bottom_y,wheel.position.y+Wheel.RADIUS+Style.FORM_SLOT*0.5+34.0)
	return bottom_y*ui_scale

## Where the moods pour from, and the column they bow away from (design units).
func mood_anchor() -> Vector2:
	return world.position+mood_button.position+mood_button.size*0.5

func world_column_left() -> float:
	return world_plate.position.x

## Right above Photo: where the scene's notices sit (viewport pixels).
func notice_bottom() -> float:
	return (photo_group.position.y-18.0)*ui_scale

func contains_pointer(point: Vector2) -> bool:
	if not is_visible_in_tree(): return false
	if mood.contains_pointer(point) or wheel.contains_pointer(point): return true
	# A receded shell never blocks the stroke that made it recede.
	if _recede > 0.5: return false
	for control: Control in [frame,modes_plate,world_plate,bottom_plate]:
		if control.get_global_rect().has_point(point): return true
	return photo_button.get_global_rect().has_point(point)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and wheel.open:
		_close_wheel()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and wheel.open and not _wheel_by_hold:
		# A press anywhere but the wheel or Land folds the wheel away.
		if wheel.form_at(event.position).is_empty() and not buttons.land.get_global_rect().has_point(event.position): _close_wheel()
