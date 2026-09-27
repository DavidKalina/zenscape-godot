extends Node
## Photo mode (docs/scenic/PLAN.md, Phase 3 slice 7): the finished moment.
## From the creation shell (P, or the camera in the palette) the brush is put
## away, every piece of chrome hides and the world keeps living. The camera is
## composed rather than driven: orbit, dolly and pan glide to rest, a ground
## eye walks the land at a low eye height and levels itself gently, the lens
## steps through focal lengths, and depth of field focuses on a clicked point.
## Space takes a full-resolution PNG with no UI into ~/Pictures/ZenScape. A
## click on a creature or plant shows a small label from the life and
## emergence records. P or Esc returns to Look or the brush, and the camera
## glides back to where it was.
##
## The scene's own orbit (target, yaw, polar, distance) still places the
## camera: this node runs before the scene each frame (process_priority) and
## writes the eased pose into it, so the fog, reflections and look pass read
## the same camera they always do.
const Glass = preload("res://scripts/glass_chrome.gd")
const PAD := Vector2(10,8)
## Seconds for a glide to cover about 63 % of the way (exponential ease).
const EASE_ORBIT := 0.22
const EASE_LOOK := 0.14
const EASE_LENS := 0.35
const EASE_FOCUS := 0.45
## Drag sensitivity, in turns per screen height (the orbit's own is 1).
const TURN := 0.55
const LOOK_TURN := 0.35
## Ground eye: height above the ground, walk step per wheel notch and per
## screen height of drag, and how far the plate lets it wander.
const EYE_HEIGHT := 0.85
const WALK_STEP := 0.7
const WALK_DRAG := 6.0
const PLATE_REACH := 13.5
## Auto-level: after this many idle seconds the ground eye's pitch settles
## toward LEVEL_POLAR (just below the horizon) at LEVEL_RATE per second.
const LEVEL_IDLE := 1.6
const LEVEL_POLAR := 1.5
const LEVEL_RATE := 0.35
const ORBIT_POLAR := Vector2(0.2,1.52)
const GROUND_POLAR := Vector2(0.95,2.05)
const DISTANCE := Vector2(2.0,120.0)
## Focal lengths on a full-frame 24 mm-high sensor; the scene's own 45° is
## about 29 mm.
const LENSES := [16.0,24.0,29.0,35.0,50.0,70.0,100.0]
const EXPOSURE_STEP := 0.25
const EXPOSURE_RANGE := 1.5
const DOF_AMOUNT := 0.09
## The strip wakes on pointer movement and fades after this many still seconds.
const STRIP_IDLE := 2.2
const HINT := "Drag to orbit  ·  right-drag to pan  ·  scroll to dolly  ·  G ground eye  ·  [ ] lens  ·  F focus  ·  Space takes the photo  ·  P back"
const GROUND_HINT := "Ground eye  ·  drag to look  ·  right-drag or arrows to walk  ·  scroll to step  ·  G to rise"
## Seconds the return glide takes after leaving.
const RETURN := 0.7

signal entered
signal left
## A photo was written (path), or could not be ("").
signal saved(path: String)

var scene: Node3D
var editor: NativeChunkEditor
var camera: Camera3D
var active := false
var ground := false
var clean := false
## What photo mode came from: {looking, target, yaw, polar, distance, fov, attributes}.
var _before := {}
var _hidden: Array[CanvasLayer] = []
var _attributes := CameraAttributesPractical.new()
var _attributes_on := false
# The eased pose and its goal. Orbit: pivot/yaw/polar/distance. Ground: eye/yaw/polar.
var _pivot := Vector3.ZERO
var _eye := Vector3.ZERO
var _yaw := 0.0
var _polar := 1.0
var _distance := 30.0
var _goal := {}
var _fov := 45.0
var _fov_goal := 45.0
var _lens := 2
var _ev := 0.0
var _exposure := 1.0
var focus_on := false
var _focus := 20.0
var _focus_goal := 20.0
var _blur := 0.0
var _idle := 0.0
var _drag := ""
var _press_at := Vector2.ZERO
var _moved := 0.0
var _returning := 0.0
var _taken := false
var _glyph_cache := {}
# Chrome.
var layer := CanvasLayer.new()
var frame := Control.new()
var glass: Panel
var row := HBoxContainer.new()
var view_button: Button
var lens_button: Button
var focus_button: Button
var exposure_label := Label.new()
var shutter: Button
var done_button: Button
var hint := Label.new()
var toast := Control.new()
var toast_glass: Panel
var toast_row := HBoxContainer.new()
var toast_label := Label.new()
var reveal_button: Button
var label := Label.new()
var label_glass: Panel
var _label_box := Control.new()
var _flash := ColorRect.new()
var _strip_alpha := 0.0
var _hint_time := 0.0
var _toast_time := 0.0
var _label_time := 0.0
var _label_at := Vector3.ZERO
# Capture.
var capturing := false
var last_path := ""
var _saving := 0
var _tasks: Array[int] = []
## Main-thread timings of the last enter, leave and capture, in microseconds.
## "look" is the part of entering spent in the shell's own Look.
var timings := {"enter":0,"look":0,"leave":0,"hide":0,"readback":0,"capture":0}
## Names what a click lands on; the camera shares it (scene_inspector.gd).
var inspector := preload("res://scripts/scene_inspector.gd").new()
var _roots := {}

const GLYPHS := {
	"camera":'<path d="M3 8 H7.2 L8.8 5.5 H15.2 L16.8 8 H21 V19 H3 Z"/><circle cx="12" cy="13.2" r="3.6"/>',
	"ground":'<path d="M2 20 H22"/><circle cx="12" cy="5.5" r="2"/><path d="M12 8 V14 M12 14 L9 19.5 M12 14 L15 19.5 M8.2 10.8 H15.8"/>',
	"aerial":'<path d="M2 20 H22"/><path d="M4.5 15.5 C5.5 9 18.5 9 19.5 15.5"/><circle cx="12" cy="5.5" r="2"/>',
	"lens":'<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="4"/><path d="M12 3.5 L15 8.4 M20.5 12 L15.3 13.8 M12 20.5 L9 15.6 M3.5 12 L8.7 10.2"/>',
	"focus":'<path d="M4 8.5 V4 H8.5 M15.5 4 H20 V8.5 M20 15.5 V20 H15.5 M8.5 20 H4 V15.5"/><circle cx="12" cy="12" r="2.6"/>',
	"sun":'<circle cx="12" cy="12" r="3.8"/><path d="M12 2.8 V5 M12 19 V21.2 M2.8 12 H5 M19 12 H21.2 M5.5 5.5 L7.1 7.1 M16.9 16.9 L18.5 18.5 M5.5 18.5 L7.1 16.9 M16.9 7.1 L18.5 5.5"/>',
	"shutter":'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="6" fill="#ffffff"/>',
	"minus":'<path d="M7 12 H17"/>',
	"plus":'<path d="M7 12 H17 M12 7 V17"/>',
	"back":'<path d="M14.5 6 L8.5 12 L14.5 18"/>',
}

## A thin line glyph, drawn like glass_chrome's own.
static func glyph(kind: String, size := 22) -> Texture2D:
	var image := Image.new()
	image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24"><g fill="none" stroke="#ffffff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">'+str(GLYPHS.get(kind,GLYPHS.camera))+'</g></svg>',size/24.0)
	return ImageTexture.create_from_image(image)

static func focal_to_fov(mm: float) -> float:
	return rad_to_deg(2.0*atan(12.0/mm))

static func fov_to_focal(fov: float) -> float:
	return 12.0/tan(deg_to_rad(fov)*0.5)

## Where photos go: ~/Pictures/ZenScape, or user://photos when Pictures is
## unavailable. `--photo-dir=PATH` points it elsewhere (probes, the build check).
static func folder() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--photo-dir="): return arg.trim_prefix("--photo-dir=")
	var pictures := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if not pictures.is_empty() and DirAccess.dir_exists_absolute(pictures): return pictures.path_join("ZenScape")
	return ProjectSettings.globalize_path("user://photos")

## The world's hour as a word: dawn, morning, midday, afternoon, dusk, evening or night.
static func part_of_day(hour: float) -> String:
	return preload("res://scripts/scene_inspector.gd").part_of_day(hour)

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	camera = scene.camera
	name = "PhotoMode"
	# Before the scene's own _process, so it reads this frame's pose.
	process_priority = -10
	set_process(false)
	_build_chrome()
	inspector.setup(scene)

# --- Chrome -------------------------------------------------------------------

func _build_chrome() -> void:
	layer.name = "PhotoChrome"
	layer.layer = 90
	layer.visible = false
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	glass = Glass.surface(16)
	frame.add_child(glass)
	row.add_theme_constant_override("separation",2)
	row.position = PAD
	frame.add_child(row)
	view_button = _button("Ground","ground","Walk the ground at eye height · G")
	view_button.toggle_mode = true
	view_button.pressed.connect(func() -> void: set_ground(not ground))
	lens_button = _button("29 mm","lens","Lens · [ ]  (click for the next)")
	lens_button.pressed.connect(func() -> void: step_lens(1 if _lens < LENSES.size()-1 else -LENSES.size()))
	focus_button = _button("Focus","focus","Depth of field · F\nClick the world to focus there")
	focus_button.toggle_mode = true
	focus_button.pressed.connect(func() -> void: set_focus(not focus_on))
	row.add_child(_divider())
	var darker := _small("minus","Darker · Shift [")
	darker.pressed.connect(func() -> void: step_exposure(-1))
	exposure_label.add_theme_font_size_override("font_size",12)
	exposure_label.add_theme_color_override("font_color",Color(Glass.INK,0.82))
	exposure_label.custom_minimum_size = Vector2(38,0)
	exposure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exposure_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exposure_label.mouse_filter = Control.MOUSE_FILTER_PASS
	exposure_label.tooltip_text = "Exposure · Shift [ ]"
	row.add_child(exposure_label)
	var lighter := _small("plus","Lighter · Shift ]")
	lighter.pressed.connect(func() -> void: step_exposure(1))
	row.add_child(_divider())
	shutter = _button("","shutter","Take the photo · Space")
	shutter.custom_minimum_size = Vector2(56,56)
	shutter.icon = glyph("shutter",30)
	shutter.pressed.connect(capture)
	done_button = _button("Back","back","Back to where you were · P or Esc")
	done_button.pressed.connect(leave)
	hint.add_theme_font_size_override("font_size",13)
	hint.add_theme_color_override("font_color",Color(Glass.INK,0.72))
	hint.add_theme_color_override("font_shadow_color",Color("182628",0.8))
	hint.add_theme_constant_override("shadow_offset_y",1)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)
	# "Saved" toast, top centre, with a way to the file.
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast)
	toast_glass = Glass.surface(12)
	toast.add_child(toast_glass)
	toast_row.add_theme_constant_override("separation",10)
	toast_row.position = Vector2(14,6)
	toast.add_child(toast_row)
	toast_label.add_theme_font_size_override("font_size",13)
	toast_label.add_theme_color_override("font_color",Color(Glass.INK,0.9))
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_row.add_child(toast_label)
	reveal_button = Button.new()
	reveal_button.text = "Show in Finder" if OS.get_name() == "macOS" else "Show folder"
	reveal_button.focus_mode = Control.FOCUS_NONE
	reveal_button.add_theme_font_size_override("font_size",12)
	Glass.button(reveal_button)
	reveal_button.pressed.connect(func() -> void:
		if not last_path.is_empty(): OS.shell_show_in_file_manager(last_path))
	toast_row.add_child(reveal_button)
	toast.modulate.a = 0.0
	toast.hide()
	# Inspect label: a small glass pill beside what was clicked.
	_label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_label_box)
	label_glass = Glass.surface(10)
	_label_box.add_child(label_glass)
	label.add_theme_font_size_override("font_size",13)
	label.add_theme_color_override("font_color",Color(Glass.INK,0.92))
	label.position = Vector2(12,5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_box.add_child(label)
	_label_box.hide()
	_flash.color = Color(1,1,1,0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_flash)
	scene.get_viewport().size_changed.connect(fit)

func _button(title: String, kind: String, tip: String) -> Button:
	var button := Button.new()
	button.text = title
	button.icon = glyph(kind,22)
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.custom_minimum_size = Vector2(62,56)
	button.add_theme_font_size_override("font_size",12)
	button.add_theme_constant_override("h_separation",3)
	Glass.button(button)
	row.add_child(button)
	return button

func _small(kind: String, tip: String) -> Button:
	var button := Button.new()
	button.icon = glyph(kind,16)
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(26,56)
	Glass.button(button)
	row.add_child(button)
	return button

func _divider() -> Control:
	var line := VSeparator.new()
	var style := StyleBoxLine.new()
	style.vertical = true
	style.color = Color(Glass.INK,0.12)
	style.grow_begin = -10
	style.grow_end = -10
	line.add_theme_stylebox_override("separator",style)
	line.add_theme_constant_override("separation",14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func fit() -> void:
	if not layer.is_inside_tree(): return
	var screen := scene.get_viewport().get_visible_rect().size
	var factor := minf(1.0,minf(screen.x/1080.0,screen.y/720.0))
	row.size = row.get_combined_minimum_size()
	glass.size = row.size+PAD*2.0
	frame.size = glass.size
	frame.scale = Vector2.ONE*factor
	frame.position = Vector2((screen.x-frame.size.x*factor)*0.5,screen.y-frame.size.y*factor-34.0*factor-14.0)
	hint.size = Vector2(screen.x,hint.get_minimum_size().y)
	hint.position = Vector2(0,screen.y-hint.size.y-14.0)
	toast_row.size = toast_row.get_combined_minimum_size()
	toast_glass.size = toast_row.size+Vector2(28,12)
	toast.size = toast_glass.size
	toast.scale = Vector2.ONE*factor
	toast.position = Vector2((screen.x-toast.size.x*factor)*0.5,22.0)
	label.size = label.get_minimum_size()
	label_glass.size = label.size+Vector2(24,10)
	_label_box.size = label_glass.size

func _sync_strip() -> void:
	view_button.set_pressed_no_signal(ground)
	view_button.text = "Rise" if ground else "Ground"
	var kind := "aerial" if ground else "ground"
	if not _glyph_cache.has(kind): _glyph_cache[kind] = glyph(kind,22)
	view_button.icon = _glyph_cache[kind]
	view_button.tooltip_text = ("Back up to the orbit" if ground else "Walk the ground at eye height")+" · G"
	lens_button.text = "%d mm" % roundi(fov_to_focal(_fov_goal))
	focus_button.set_pressed_no_signal(focus_on)
	exposure_label.text = "±0" if is_zero_approx(_ev) else ("%+.2f" % _ev).rstrip("0").rstrip(".")
	fit()

## Photo chrome and the hint over the frame, never in a photo.
func contains_pointer(point: Vector2) -> bool:
	return active and not clean and layer.visible and _strip_alpha > 0.05 and Rect2(frame.global_position,frame.size*frame.scale).has_point(point) \
		or active and toast.visible and toast.modulate.a > 0.05 and Rect2(toast.global_position,toast.size*toast.scale).has_point(point)

# --- Entering and leaving -------------------------------------------------------

func can_enter() -> bool:
	if active or scene == null or not scene.get("shell_ready") or not scene._has_world: return false
	if scene._menu.visible or scene.crafting: return false
	var places: Node = scene.get("places")
	return places == null or not places.busy

func enter() -> void:
	if not can_enter(): return
	var started := Time.get_ticks_usec()
	_before = {"looking":scene.looking,"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance,"fov":camera.fov,"attributes":camera.attributes,"auto":scene._auto_orbit}
	# The brush goes away first: the stroke ends and the editor parks, as in
	# Look. Look's world-play preparation (props and their collision, 20 ms
	# on a fresh world) is skipped: photo mode keeps every press for the camera.
	var look_started := Time.get_ticks_usec()
	if not scene.looking:
		scene._set_looking_state(true)
		editor.set_active(false)
		scene._sync_creation_ui()
	timings.look = Time.get_ticks_usec()-look_started
	active = true
	_returning = 0.0
	ground = false
	clean = false
	scene._orbiting = false
	scene._panning = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	scene._auto_orbit = false
	_pivot = scene.target
	_yaw = scene.yaw
	_polar = scene.polar
	_distance = scene.distance
	_goal = {"pivot":_pivot,"yaw":_yaw,"polar":_polar,"distance":_distance,"eye":Vector3.ZERO}
	_fov = camera.fov
	_fov_goal = _fov
	_lens = _nearest_lens(fov_to_focal(_fov))
	_ev = 0.0
	_exposure = 1.0
	focus_on = false
	_blur = 0.0
	_focus = _distance
	_focus_goal = _focus
	# Camera attributes go on only when exposure or focus is first touched, so
	# entering changes nothing the renderer has to prepare.
	_attributes = CameraAttributesPractical.new() if _before.attributes == null else (_before.attributes as CameraAttributes).duplicate()
	_attributes_on = false
	_hide_chrome()
	layer.visible = true
	_strip_alpha = 1.0
	_idle = 0.0
	_hint_time = 0.0
	hint.text = HINT
	hint.modulate.a = 1.0
	_label_box.hide()
	_sync_strip()
	set_process(true)
	timings.enter = Time.get_ticks_usec()-started
	entered.emit()

func leave() -> void:
	if not active or capturing: return
	var started := Time.get_ticks_usec()
	active = false
	_drag = ""
	scene._orbiting = false
	scene._panning = false
	layer.visible = false
	_label_box.hide()
	_show_chrome()
	# Back to where you were: Look, or the brush in hand.
	if not bool(_before.looking): scene.select_brush(scene.brush)
	scene._auto_orbit = bool(_before.auto)
	# The camera glides home; any drag in the meantime takes it over.
	if ground: _to_orbit_state()
	ground = false
	_returning = RETURN
	_taken = false
	_goal = {"pivot":_before.target,"yaw":_before.yaw,"polar":_before.polar,"distance":_before.distance}
	_fov_goal = float(_before.fov)
	timings.leave = Time.get_ticks_usec()-started
	left.emit()

func toggle() -> void:
	if active: leave()
	else: enter()

## Every CanvasLayer at layer 1 or above is chrome (the shell, notices, hints,
## the place badge). Layers at 0 and below are the picture: the display fog,
## the look grade and the fall mist.
func _hide_chrome() -> void:
	for node in scene.get_tree().root.find_children("*","CanvasLayer",true,false):
		var canvas := node as CanvasLayer
		if canvas == layer or canvas.layer < 1 or not canvas.visible: continue
		canvas.visible = false
		_hidden.append(canvas)

func _show_chrome() -> void:
	for canvas in _hidden:
		if is_instance_valid(canvas): canvas.visible = true
	_hidden.clear()

## True while every piece of chrome but the photo strip is hidden.
func chrome_hidden() -> bool:
	for node in scene.get_tree().root.find_children("*","CanvasLayer",true,false):
		var canvas := node as CanvasLayer
		if canvas != layer and canvas.layer >= 1 and canvas.visible: return false
	return true

# --- Camera ---------------------------------------------------------------------

func _nearest_lens(mm: float) -> int:
	var best := 0
	for i in range(LENSES.size()):
		if absf(LENSES[i]-mm) < absf(LENSES[best]-mm): best = i
	return best

func step_lens(step: int) -> void:
	_lens = clampi(_lens+step,0,LENSES.size()-1)
	_fov_goal = focal_to_fov(LENSES[_lens])
	_sync_strip()

func step_exposure(step: int) -> void:
	_ev = clampf(_ev+step*EXPOSURE_STEP,-EXPOSURE_RANGE,EXPOSURE_RANGE)
	_use_attributes()
	_sync_strip()

func set_focus(enabled: bool) -> void:
	focus_on = enabled
	if enabled:
		_use_attributes()
		# Start on what the centre of the frame rests on.
		var hit: Variant = _ground_hit(scene.get_viewport().get_visible_rect().size*0.5)
		_focus_goal = camera.global_position.distance_to(hit) if hit != null else _distance
		if _blur <= 0.0: _focus = _focus_goal
	_sync_strip()

func set_ground(enabled: bool) -> void:
	if enabled == ground: return
	if enabled:
		# Step down to the ground a little in front of where the camera was,
		# facing the same way.
		var camera_now := _orbit_camera()
		var flat := Vector3(_pivot.x-camera_now.x,0.0,_pivot.z-camera_now.z)
		var reach := minf(flat.length()*0.55,_distance*0.6)
		var spot := camera_now+flat.normalized()*maxf(reach,0.0) if flat.length() > 0.01 else _pivot
		_eye = camera_now
		ground = true
		_goal.eye = _grounded(spot)
		_goal.polar = LEVEL_POLAR
		hint.text = GROUND_HINT
	else:
		_to_orbit_state()
		ground = false
		_goal.distance = clampf(maxf(_distance,14.0),DISTANCE.x,DISTANCE.y)
		_goal.polar = 1.1
		hint.text = HINT
	hint.modulate.a = 1.0
	_hint_time = 0.0
	_sync_strip()

## Re-express the ground eye as an orbit around a point ahead of it, so the
## camera does not jump when the orbit takes over.
func _to_orbit_state() -> void:
	var reach := 10.0
	_pivot = _eye-_offset(_yaw,_polar)*reach
	_distance = reach
	var eye_goal: Vector3 = _goal.get("eye",_eye)
	_goal.pivot = eye_goal-_offset(_goal.yaw,_goal.polar)*reach
	_goal.distance = reach

static func _offset(yaw: float, polar: float) -> Vector3:
	return Vector3(sin(polar)*sin(yaw),cos(polar),sin(polar)*cos(yaw))

func _orbit_camera() -> Vector3:
	return _pivot+_offset(_yaw,_polar)*_distance

## A plate point at eye height over the ground, clamped to the plate.
func _grounded(point: Vector3) -> Vector3:
	var local := editor.terrain.to_local(point)
	local.x = clampf(local.x,-PLATE_REACH,PLATE_REACH)
	local.z = clampf(local.z,-PLATE_REACH,PLATE_REACH)
	var h: Variant = editor.data.ground_height(Vector2(local.x,local.z))
	local.y = (float(h) if h != null else local.y-EYE_HEIGHT)+EYE_HEIGHT
	return editor.terrain.to_global(local)

func _ground_hit(point: Vector2) -> Variant:
	var hit: Variant = editor.pick(point)
	return editor.terrain.to_global(hit) if hit != null else null

func _process(delta: float) -> void:
	if active: _advance_camera(delta)
	elif _returning > 0.0: _advance_return(delta)
	else: set_process(false)
	_advance_chrome(delta)

func _ease(rate: float, delta: float) -> float:
	return 1.0-exp(-delta/rate)

func _advance_camera(delta: float) -> void:
	_idle += delta
	var k := _ease(EASE_LOOK if ground else EASE_ORBIT,delta)
	if ground:
		if _idle > LEVEL_IDLE and _drag.is_empty():
			_goal.polar = move_toward(_goal.polar,LEVEL_POLAR,LEVEL_RATE*delta*absf(_goal.polar-LEVEL_POLAR)*2.0+0.02*delta)
		_goal.eye = _grounded(_goal.eye)
		_eye = _eye.lerp(_goal.eye,_ease(EASE_ORBIT,delta))
		_yaw = lerp_angle(_yaw,_goal.yaw,k)
		_polar = lerpf(_polar,_goal.polar,k)
		# Never below the ground under the eased eye.
		_eye.y = maxf(_eye.y,_grounded(_eye).y-EYE_HEIGHT*0.6)
		var reach := 6.0
		scene.target = _eye-_offset(_yaw,_polar)*reach
		scene.distance = reach
	else:
		_pivot = _pivot.lerp(_goal.pivot,k)
		_yaw = lerp_angle(_yaw,_goal.yaw,k)
		_polar = lerpf(_polar,_goal.polar,k)
		_distance = lerpf(_distance,_goal.distance,k)
		# Over the plate the orbit never dips under the ground.
		var at := _orbit_camera()
		var local := editor.terrain.to_local(at)
		if absf(local.x) < PLATE_REACH and absf(local.z) < PLATE_REACH:
			var floor_y := _grounded(at).y-EYE_HEIGHT+0.4
			if at.y < floor_y:
				_polar = minf(_polar,acos(clampf((floor_y-_pivot.y)/_distance,-1.0,1.0)))
				_goal.polar = minf(_goal.polar,_polar)
		scene.target = _pivot
		scene.distance = _distance
	scene.yaw = _yaw
	scene.polar = _polar
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	_fov = lerpf(_fov,_fov_goal,_ease(EASE_LENS,delta))
	camera.fov = _fov
	_exposure = lerpf(_exposure,pow(2.0,_ev),_ease(EASE_LENS,delta))
	_blur = move_toward(_blur,1.0 if focus_on else 0.0,delta*2.5)
	_focus = lerpf(_focus,_focus_goal,_ease(EASE_FOCUS,delta))
	_apply_attributes()

func _advance_return(delta: float) -> void:
	_returning = maxf(0.0,_returning-delta)
	# A drag or zoom takes the camera back from the glide where it is; the
	# lens and exposure still ease home.
	if scene._orbiting or scene._panning or scene._orbit_delta != Vector2.ZERO or scene._pan_delta != Vector2.ZERO:
		_taken = true
	var k := _ease(EASE_ORBIT*0.8,delta) if _returning > 0.0 else 1.0
	if not _taken:
		_pivot = _pivot.lerp(_goal.pivot,k)
		_yaw = lerp_angle(_yaw,_goal.yaw,k)
		_polar = lerpf(_polar,_goal.polar,k)
		_distance = lerpf(_distance,_goal.distance,k)
		scene.target = _pivot
		scene.yaw = _yaw
		scene.polar = _polar
		scene.distance = _distance
	_fov = lerpf(_fov,_fov_goal,k)
	camera.fov = _fov
	_exposure = lerpf(_exposure,1.0,k)
	_blur = lerpf(_blur,0.0,k)
	_apply_attributes()
	if _returning <= 0.0:
		camera.fov = float(_before.fov)
		camera.attributes = _before.attributes

func _use_attributes() -> void:
	if _attributes_on: return
	_attributes_on = true
	camera.attributes = _attributes

func _apply_attributes() -> void:
	if not _attributes_on: return
	_attributes.exposure_multiplier = _exposure
	var blur := _blur > 0.001
	_attributes.dof_blur_far_enabled = blur
	_attributes.dof_blur_near_enabled = blur
	if not blur: return
	var f := maxf(_focus,0.5)
	_attributes.dof_blur_far_distance = f*1.12+0.3
	_attributes.dof_blur_far_transition = f*1.6
	_attributes.dof_blur_near_distance = maxf(f*0.72-0.2,0.05)
	_attributes.dof_blur_near_transition = maxf(f*0.5,0.05)
	_attributes.dof_blur_amount = DOF_AMOUNT*_blur

func _advance_chrome(delta: float) -> void:
	if not active: return
	_hint_time += delta
	if _hint_time > 6.0: hint.modulate.a = move_toward(hint.modulate.a,0.0,delta/1.4)
	var mouse := scene.get_viewport().get_mouse_position()
	var over := Rect2(frame.global_position,frame.size*frame.scale).has_point(mouse)
	var want := 0.0 if clean or (_idle > STRIP_IDLE and not over) or not _drag.is_empty() else 1.0
	_strip_alpha = move_toward(_strip_alpha,want,delta*(4.0 if want > _strip_alpha else 1.6))
	frame.modulate.a = _strip_alpha
	frame.visible = _strip_alpha > 0.01
	hint.visible = not clean
	if toast.visible:
		_toast_time += delta
		var over_toast := Rect2(toast.global_position,toast.size*toast.scale).has_point(mouse)
		if over_toast: _toast_time = minf(_toast_time,2.0)
		toast.modulate.a = move_toward(toast.modulate.a,0.0 if _toast_time > 4.5 else 1.0,delta*(4.0 if _toast_time <= 4.5 else 1.2))
		if _toast_time > 4.5 and toast.modulate.a <= 0.0: toast.hide()
	if _label_box.visible:
		_label_time += delta
		_label_box.modulate.a = clampf(minf(_label_time*4.0,(4.5-_label_time)/1.2),0.0,1.0)
		if not camera.is_position_behind(_label_at):
			var at := camera.unproject_position(_label_at)
			_label_box.position = at+Vector2(-_label_box.size.x*0.5,-_label_box.size.y-18.0)
		if _label_time > 4.5: _label_box.hide()
	_flash.color.a = move_toward(_flash.color.a,0.0,delta*1.6)

# --- Input ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if active and handle(event): get_viewport().set_input_as_handled()

## Photo mode's input. Returns true when the event was used. Pointer events
## over the strip or the toast fall through to their buttons.
func handle(event: InputEvent) -> bool:
	if not active: return false
	if event is InputEventMouseMotion:
		_wake()
		if _drag.is_empty(): return false
		_drag_by(event.relative,event.shift_pressed)
		_moved += event.relative.length()
		return true
	if event is InputEventMouseButton:
		_wake()
		if event.pressed and contains_pointer(event.position): return false
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed: _dolly((-1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0)*maxf(event.factor,0.01))
			return true
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT,MOUSE_BUTTON_MIDDLE]:
			if event.pressed and _drag.is_empty():
				_drag = "pan" if event.button_index != MOUSE_BUTTON_LEFT or event.shift_pressed else "turn"
				_press_at = event.position
				_moved = 0.0
			elif not event.pressed and not _drag.is_empty():
				var clicked: bool = _drag == "turn" and _moved < 5.0
				_drag = ""
				if clicked: click(event.position)
			return true
		return false
	if event is InputEventMagnifyGesture:
		_dolly((1.0-event.factor)*12.0)
		return true
	if event is InputEventPanGesture:
		_dolly(event.delta.y*0.5)
		return true
	if event is InputEventKey and event.pressed:
		return _key(event)
	return false

func _key(event: InputEventKey) -> bool:
	if event.ctrl_pressed or event.meta_pressed: return false
	var code := event.keycode
	if code in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
		var move := Vector2(float(code == KEY_RIGHT)-float(code == KEY_LEFT),float(code == KEY_DOWN)-float(code == KEY_UP))
		_wake()
		if ground: _walk(move*0.6)
		else: _pan(-move*40.0)
		return true
	if event.echo: return code in [KEY_BRACKETLEFT,KEY_BRACKETRIGHT,KEY_SPACE,KEY_P,KEY_ESCAPE]
	match code:
		KEY_P, KEY_ESCAPE: leave()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_C: capture()
		KEY_G: set_ground(not ground)
		KEY_F: set_focus(not focus_on)
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT:
			var step := 1 if code == KEY_BRACKETRIGHT else -1
			if event.shift_pressed: step_exposure(step)
			else: step_lens(step)
		KEY_H:
			clean = not clean
			_label_box.hide()
		KEY_R:
			# Frame again from where photo mode began.
			if ground: set_ground(false)
			_goal = {"pivot":_before.target,"yaw":_before.yaw,"polar":_before.polar,"distance":_before.distance,"eye":_eye}
		KEY_TAB, KEY_V: pass
		_:
			# A brush number puts the camera down and picks that brush up.
			if code >= KEY_1 and code <= KEY_9 and not event.alt_pressed:
				var index: int = code-KEY_1
				if index < scene.brush_ids.size():
					_before.looking = false
					leave()
					scene.select_brush(scene.brush_ids[index])
				return true
			return false
	return true

func _wake() -> void:
	_idle = 0.0

func _drag_by(relative: Vector2, _shift: bool) -> void:
	var height := maxf(scene.get_viewport().get_visible_rect().size.y,1.0)
	if _drag == "turn":
		if ground:
			_goal.yaw += TAU*LOOK_TURN*relative.x/height
			_goal.polar = clampf(_goal.polar+TAU*LOOK_TURN*relative.y/height,GROUND_POLAR.x,GROUND_POLAR.y)
		else:
			_goal.yaw -= TAU*TURN*relative.x/height
			_goal.polar = clampf(_goal.polar-TAU*TURN*relative.y/height,ORBIT_POLAR.x,ORBIT_POLAR.y)
	elif ground:
		_walk(Vector2(-relative.x,-relative.y)/height*WALK_DRAG)
	else:
		_pan(relative)

## Grab-the-world pan in the orbit: the ground follows the pointer.
func _pan(relative: Vector2) -> void:
	var height := maxf(scene.get_viewport().get_visible_rect().size.y,1.0)
	var reach := 2.0*_distance*tan(deg_to_rad(_fov)*0.5)/height
	var basis := camera.global_basis
	var pivot: Vector3 = _goal.pivot+(-basis.x*relative.x+basis.y*relative.y)*reach
	var local := editor.terrain.to_local(pivot)
	local.x = clampf(local.x,-PLATE_REACH*1.4,PLATE_REACH*1.4)
	local.z = clampf(local.z,-PLATE_REACH*1.4,PLATE_REACH*1.4)
	_goal.pivot = editor.terrain.to_global(local)

## Ground eye: x strafes, y walks (negative is forward), in metres.
func _walk(move: Vector2) -> void:
	var forward := -_offset(_goal.yaw,PI*0.5)
	var right := forward.cross(Vector3.UP)
	_goal.eye = _grounded(_goal.eye+right*move.x-forward*move.y)

func _dolly(amount: float) -> void:
	if ground:
		_walk(Vector2(0.0,amount*WALK_STEP))
	else:
		_goal.distance = clampf(_goal.distance*pow(1.12,amount),DISTANCE.x,DISTANCE.y)

# --- Inspect ------------------------------------------------------------------------

## A click: focus there when depth of field is on, and name what was clicked.
func click(point: Vector2) -> void:
	var found := inspect(point)
	var hit: Variant = found.get("point",_ground_hit(point))
	if focus_on and hit != null: _focus_goal = camera.global_position.distance_to(hit)
	if found.is_empty():
		_label_box.hide()
		return
	label.text = str(found.title)+("  ·  "+str(found.detail) if not str(found.get("detail","")).is_empty() else "")
	_label_at = found.point
	_label_time = 0.0
	_label_box.modulate.a = 0.0
	_label_box.show()
	fit()

## What is under a screen point: {title, detail, point, kind, ...} or {}
## (scripts/scene_inspector.gd, shared with the camera).
func inspect(point: Vector2) -> Dictionary:
	return inspector.inspect(point)

# --- Capture ----------------------------------------------------------------------

## "ZenScape - Open plain - Day 2 dawn - 2026-09-26 14.03.22.png"
func file_name(now := Time.get_datetime_dict_from_system()) -> String:
	var place := "ZenScape"
	var places: Node = scene.get("places")
	if places != null and places.has_method("_label"): place = str(places.call("_label",scene))
	var clock: WorldClock = scene.get("world_clock")
	var when := "Day %d %s" % [clock.day+1,part_of_day(clock.hour)] if clock != null else ""
	var stamp := "%04d-%02d-%02d %02d.%02d.%02d" % [now.year,now.month,now.day,now.hour,now.minute,now.second]
	var parts: Array[String] = ["ZenScape"]
	for part in [place,when,stamp]:
		var clean_part := str(part).replace("·","-")
		for bad in ["/","\\",":","*","?","\"","<",">","|","\n"]: clean_part = clean_part.replace(bad," ")
		clean_part = clean_part.strip_edges()
		while "  " in clean_part: clean_part = clean_part.replace("  "," ")
		if not clean_part.is_empty() and clean_part != "ZenScape": parts.append(clean_part)
	return " - ".join(parts)+".png"

## Take the photo: one frame drawn without chrome, read back, then written as
## a PNG on a worker. Only the readback is on the main thread.
func capture() -> void:
	if not active or capturing: return
	capturing = true
	var started := Time.get_ticks_usec()
	# Anything that showed itself since entering hides too.
	_hide_chrome()
	layer.visible = false
	timings.hide = Time.get_ticks_usec()-started
	await RenderingServer.frame_post_draw
	var read := Time.get_ticks_usec()
	var image := scene.get_viewport().get_texture().get_image()
	timings.readback = Time.get_ticks_usec()-read
	# Main-thread work only: hiding, the readback and handing off to the worker.
	var after := Time.get_ticks_usec()
	layer.visible = true
	capturing = false
	if image == null or image.is_empty():
		_toast("Could not take the photo",false)
		saved.emit("")
		return
	var directory := folder()
	var path := directory.path_join(file_name())
	var n := 2
	while FileAccess.file_exists(path):
		path = directory.path_join(file_name().trim_suffix(".png")+" (%d).png" % n)
		n += 1
	_saving += 1
	_flash.color.a = 0.28
	_toast("Saving…",false)
	_tasks.append(WorkerThreadPool.add_task(_write.bind(image,path),false,"Photo"))
	timings.capture = timings.hide+timings.readback+Time.get_ticks_usec()-after

## Worker: flatten to 8-bit RGB and write the PNG.
func _write(image: Image, path: String) -> void:
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error == OK:
		if image.get_format() != Image.FORMAT_RGB8: image.convert(Image.FORMAT_RGB8)
		error = image.save_png(path)
	_written.call_deferred(path if error == OK else "")

func _written(path: String) -> void:
	_saving -= 1
	# Collect finished tasks so the pool can let them go; never wait on one.
	for id in _tasks.duplicate():
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_tasks.erase(id)
	if path.is_empty():
		_toast("Could not save the photo",false)
	else:
		last_path = path
		var folder_path := path.get_base_dir()
		_toast("Saved to "+folder_path.get_base_dir().get_file().path_join(folder_path.get_file()),true)
	saved.emit(path)

func _toast(text: String, reveal: bool) -> void:
	toast_label.text = text
	reveal_button.visible = reveal
	_toast_time = 0.0
	toast.show()
	fit()

## True while a photo is still being written.
func busy() -> bool:
	return capturing or _saving > 0
