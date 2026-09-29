extends Node
## A first test for a human who roams the chunk: a small figure stands on the
## land and the camera can step into its eyes. V with the pointer on the land
## sets the figure down there (or picks it up and moves it) and looks out
## through it; V with the pointer off the land steps into it where it stands.
## In its eyes the mouse is captured: move to look, WASD or the arrows walk,
## Shift runs. V or Esc steps back out, and the camera glides back to where it
## was; the figure stays where you walked it.
##
## Like photo mode (scripts/photo_mode.gd) this runs before the scene each
## frame (process_priority) and writes the pose into the scene's own orbit
## (target, yaw, polar, distance), so the fog, reflections and look pass read
## the same camera they always do. The figure is not saved with the place.

## The figure's height and the eye's height above the ground, in metres. The
## diorama is toy-scaled: trees stand about 3 to 5 m and photo mode's ground
## eye sits at 0.85 m.
const FIGURE_HEIGHT := 0.95
const EYE_HEIGHT := 0.85
## Walking and running speed, in metres a second, and how fast the pace eases.
const WALK := 1.6
const RUN := 4.0
const EASE_PACE := 0.12
## The eye rides over bumps rather than snapping to every step.
const EASE_HEIGHT := 0.08
## Radians of look per pixel of captured mouse movement.
const LOOK := 0.0025
## The polar range of the look: near straight down to well above the horizon.
const POLAR := Vector2(0.25,2.8)
## The walk stays on the plate.
const PLATE_REACH := 13.5
## Seconds the glide back to the orbit takes.
const RETURN := 0.7
const HINT := "Mouse to look  ·  WASD or arrows to walk  ·  Shift to run  ·  V or Esc to step out"

signal entered
signal left

var scene: Node3D
var editor: NativeChunkEditor
var camera: Camera3D
## True while the camera looks through the figure.
var active := false
## The figure, parented to the terrain so it turns with the world.
var figure: Node3D
## Terrain-local position of the figure's feet.
var _feet := Vector3.ZERO
var _eye_y := 0.0
var _yaw := 0.0
var _polar := PI*0.5
var _pace := Vector2.ZERO
var _before := {}
var _returning := 0.0
var _hint_time := 0.0
var _layer: CanvasLayer
var _hint: Label
var _dot: Control

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	camera = scene.camera
	name = "WandererEye"
	# Before the scene's own _process (and with photo mode), so the scene
	# reads this frame's pose.
	process_priority = -10
	set_process(false)
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.visible = false
	add_child(_layer)
	_hint = Label.new()
	_hint.text = HINT
	_hint.add_theme_font_size_override("font_size",15)
	_hint.add_theme_color_override("font_color",Color("fbf6ea"))
	_hint.add_theme_color_override("font_shadow_color",Color(0,0,0,0.55))
	_hint.add_theme_constant_override("shadow_offset_y",1)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -56.0
	_hint.offset_bottom = -30.0
	_hint.offset_left = -400.0
	_hint.offset_right = 400.0
	_layer.add_child(_hint)
	# A faint dot where the eye looks.
	_dot = Control.new()
	_dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.draw.connect(func() -> void:
		_dot.draw_circle(_dot.size*0.5,2.5,Color(1,1,1,0.55),true,-1.0,true))
	_layer.add_child(_dot)

# --- The figure -------------------------------------------------------------------

## A plain little person: a capsule body, a head and a pale face side so its
## heading reads from the orbit.
func _build_figure() -> void:
	figure = Node3D.new()
	figure.name = "Wanderer"
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("c8643b")
	cloth.roughness = 0.85
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color("e8c39e")
	skin.roughness = 0.7
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.14
	capsule.height = FIGURE_HEIGHT*0.78
	capsule.radial_segments = 12
	capsule.rings = 4
	body.mesh = capsule
	body.material_override = cloth
	body.position.y = capsule.height*0.5
	figure.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	sphere.radial_segments = 12
	sphere.rings = 6
	head.mesh = sphere
	head.material_override = skin
	head.position.y = FIGURE_HEIGHT-0.1
	figure.add_child(head)
	# A nose, so which way it faces reads from above.
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04,0.04,0.06)
	nose.mesh = box
	nose.material_override = skin
	nose.position = Vector3(0.0,FIGURE_HEIGHT-0.1,-0.11)
	figure.add_child(nose)
	editor.terrain.add_child(figure)

func has_figure() -> bool:
	return figure != null and is_instance_valid(figure)

## Terrain height under a local point, or the point's own height off the map.
func _ground(local: Vector3) -> float:
	var h: Variant = editor.data.ground_height(Vector2(local.x,local.z))
	return float(h) if h != null else local.y

func _clamped(local: Vector3) -> Vector3:
	local.x = clampf(local.x,-PLATE_REACH,PLATE_REACH)
	local.z = clampf(local.z,-PLATE_REACH,PLATE_REACH)
	local.y = _ground(local)
	return local

## Set the figure down at a terrain-local point, facing the way the camera
## looks.
func place(local: Vector3) -> void:
	if not has_figure(): _build_figure()
	_feet = _clamped(local)
	_yaw = scene.yaw
	_sync_figure()

## The terrain's own turn; the world turn (scripts/world_turn.gd) turns the
## camera, so this is normally 0.
func _turn() -> float:
	return editor.terrain.global_basis.get_euler().y

## The scene's yaw points from the look target to the camera; the figure
## faces the other way, down its local -Z, in the terrain's frame.
func _sync_figure() -> void:
	if not has_figure(): return
	figure.position = _feet
	figure.rotation = Vector3(0.0,_yaw-_turn(),0.0)

# --- Stepping in and out ------------------------------------------------------------

func can_enter() -> bool:
	if active or scene == null or not scene.get("shell_ready") or not scene._has_world: return false
	if scene._menu.visible or scene.crafting or editor.forming: return false
	var photo: Node = scene.get("photo")
	if photo != null and photo.active: return false
	var places: Node = scene.get("places")
	return places == null or not places.busy

## V from the world: set the figure down under the pointer (if the land is
## there) and look through it.
func summon(pointer: Vector2) -> void:
	if not can_enter(): return
	var hit: Variant = editor.pick(pointer)
	if hit != null: place(hit)
	elif not has_figure(): place(editor.terrain.to_local(scene.target))
	enter()

func enter() -> void:
	if not can_enter() or not has_figure(): return
	_before = {"looking":scene.looking,"target":scene.target,"yaw":scene.yaw,"polar":scene.polar,"distance":scene.distance,"auto":scene._auto_orbit}
	if not scene.looking:
		scene._set_looking_state(true)
		editor.set_active(false)
		scene._sync_creation_ui()
	active = true
	_returning = 0.0
	_pace = Vector2.ZERO
	_yaw = figure.rotation.y+_turn()
	_polar = PI*0.5
	_feet = _clamped(_feet)
	_eye_y = _feet.y+EYE_HEIGHT
	scene._orbiting = false
	scene._panning = false
	scene._auto_orbit = false
	figure.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_layer.visible = true
	_hint.modulate.a = 1.0
	_hint_time = 0.0
	set_process(true)
	entered.emit()

func leave() -> void:
	if not active: return
	active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_layer.visible = false
	figure.visible = true
	_sync_figure()
	if not bool(_before.looking): scene.select_brush(scene.brush)
	scene._auto_orbit = bool(_before.auto)
	# Re-express the eye as an orbit around a point ahead of it, then glide home.
	var reach := 6.0
	var eye := _eye_global()
	scene.target = eye-_offset(scene.yaw,scene.polar)*reach
	scene.distance = reach
	_returning = RETURN
	left.emit()

static func _offset(yaw: float, polar: float) -> Vector3:
	return Vector3(sin(polar)*sin(yaw),cos(polar),sin(polar)*cos(yaw))

func _eye_global() -> Vector3:
	return editor.terrain.to_global(Vector3(_feet.x,_eye_y,_feet.z))

# --- Each frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if active: _advance_eye(delta)
	elif _returning > 0.0: _advance_return(delta)
	else: set_process(false)

func _ease(rate: float, delta: float) -> float:
	return 1.0-exp(-delta/rate)

func _advance_eye(delta: float) -> void:
	if not has_figure() or scene._menu.visible:
		leave()
		return
	var want := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if want.length() > 1.0: want = want.normalized()
	want *= RUN if Input.is_physical_key_pressed(KEY_SHIFT) else WALK
	_pace = _pace.lerp(want,_ease(EASE_PACE,delta))
	# Walk in the terrain's frame: the scene's yaw is in world space, and the
	# world may be turned under the camera.
	var heading := _yaw-_turn()
	var forward := -Vector3(sin(heading),0.0,cos(heading))
	var right := forward.cross(Vector3.UP)
	_feet = _clamped(_feet+(right*_pace.x-forward*_pace.y)*delta)
	_eye_y = lerpf(_eye_y,_feet.y+EYE_HEIGHT,_ease(EASE_HEIGHT,delta))
	# Never below the ground right under the eye.
	_eye_y = maxf(_eye_y,_feet.y+EYE_HEIGHT*0.6)
	var reach := 6.0
	scene.yaw = _yaw
	scene.polar = _polar
	scene.target = _eye_global()-_offset(_yaw,_polar)*reach
	scene.distance = reach
	scene._auto_orbit = false
	scene._orbit_delta = Vector2.ZERO
	scene._pan_delta = Vector2.ZERO
	# The figure keeps the eye's heading and place for when you step out.
	_sync_figure()
	_hint_time += delta
	_hint.modulate.a = clampf(1.0-(_hint_time-4.0)/1.5,0.0,1.0)

func _advance_return(delta: float) -> void:
	_returning = maxf(0.0,_returning-delta)
	if scene._orbiting or scene._panning:
		_returning = 0.0
		return
	var k := _ease(0.18,delta) if _returning > 0.0 else 1.0
	scene.target = scene.target.lerp(_before.target,k)
	scene.yaw = lerp_angle(scene.yaw,_before.yaw,k)
	scene.polar = lerpf(scene.polar,_before.polar,k)
	scene.distance = lerpf(scene.distance,_before.distance,k)

# --- Input ------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if handle(event): get_viewport().set_input_as_handled()

## The eye's input. Returns true when the event was used. V from the world
## is taken here too, so the hand scheme's key filter never sees it.
func handle(event: InputEvent) -> bool:
	if not active:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V \
				and not (event.ctrl_pressed or event.meta_pressed or event.alt_pressed) and can_enter():
			summon(scene.get_viewport().get_mouse_position())
			return true
		return false
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_yaw -= event.relative.x*LOOK
			_polar = clampf(_polar+event.relative.y*LOOK,POLAR.x,POLAR.y)
		return true
	if event is InputEventMouseButton:
		# A click takes the mouse back if the window let it go.
		if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return true
	if event is InputEventMagnifyGesture or event is InputEventPanGesture:
		return true
	if event is InputEventKey:
		if event.ctrl_pressed or event.meta_pressed: return false
		if event.pressed and not event.echo and event.keycode in [KEY_V,KEY_ESCAPE]:
			leave()
		# Walking keys are read each frame; every plain key stays here.
		return true
	return false

func _notification(what: int) -> void:
	# Stepping out of the window lets the mouse go.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
