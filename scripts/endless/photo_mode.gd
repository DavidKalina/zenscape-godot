extends RefCounted
## Photo mode (endless flight; docs/design/endless-flight/spec-wild-loop.md,
## lane `photo`). O (the pad's `photo`, L3) holds the flight: the game skips
## its `tick` while `active` (no plane step, no land, no day clock, no
## wind or water time) and the physics server is stopped, so the flight
## carries on exactly where it was when O or Esc (the pad's B or L3) lets go.
## The HUD's layers are hidden and a free camera orbits a pivot that starts
## at the plane and flies from it:
##   orbit      mouse (captured, or dragged) / right stick
##   fly        WASD or the arrows / left stick, Shift faster
##   down, up   Q, E / LB, RB
##   near, far  wheel / d-pad up, down
##   lens       Z wider, X narrower / LT, RT
##   save       Space or Enter / A: a PNG to `dir` named by the date
## The game holds one (`game.photo`), hands it its events before its own
## match (`handle`) and calls `step` instead of `tick` while it is active.
## It is `game.overlay` while up. The book counts the photos saved.

const Pad = preload("res://scripts/pad.gd")

const DIR := "user://photos"
## How far the pivot may fly from the plane (the land streams round the
## plane's last eye, held while the photo is up).
const REACH := 160.0
const NEAR := 2.5
const FAR := 90.0
## Pivot speed, m/s; Shift times FAST.
const FLY := 12.0
const FAST := 4.0
const TURN_MOUSE := 0.004
const TURN_STICK := 2.2
const PITCH := 1.45
const FOV_MIN := 12.0
const FOV_MAX := 100.0
const FOV_RATE := 35.0
## The eye keeps this far over the land or the water.
const CLEAR := 0.8
const FLASH := 1.6

var game: Node
var active := false
var pivot := Vector3.ZERO
var yaw := 0.0
var pitch := 0.0
var dist := 12.0
var fov := 70.0
## Where the stills go (`--photo-dir=` for another).
var dir := DIR
var saved := 0
var last_path := ""
## Why the last save did not happen ("" when it did).
var last_error := ""
var _hidden_layers: Array[CanvasLayer] = []
var _was_eye := Transform3D.IDENTITY
var _was_fov := 70.0
var _layer: CanvasLayer
var _hint: Label
var _flash: Label
var _flash_t := 0.0
var _saving := false

func _init(owner_game: Node) -> void:
	game = owner_game
	for arg: String in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--photo-dir="): dir = arg.substr(12)

## Takes `event` when photo mode wants it: everything while up, and O or
## L3 to open it while no other overlay is. True when taken.
func handle(event: InputEvent) -> bool:
	if not active:
		if game.overlay != null: return false
		if _is_toggle(event):
			enter()
			return true
		return false
	if _is_toggle(event) or _is_key(event,[KEY_ESCAPE]) \
			or (event is InputEventJoypadButton and event.is_action_pressed(&"ui_cancel")):
		leave()
		return true
	if _is_key(event,[KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		shoot()
		return true
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or event.button_mask != 0:
			_turn(Vector2(event.relative.x,event.relative.y)*TURN_MOUSE)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: dist = maxf(dist/1.12,NEAR)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: dist = minf(dist*1.12,FAR)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_UP: dist = maxf(dist/1.25,NEAR)
		elif event.button_index == JOY_BUTTON_DPAD_DOWN: dist = minf(dist*1.25,FAR)
	return true

func _is_key(event: InputEvent, keys: Array) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode in keys

func _is_toggle(event: InputEvent) -> bool:
	if event is InputEventKey: return _is_key(event,[KEY_O])
	return event is InputEventJoypadButton and event.is_action_pressed(&"photo")

## The plane where it is drawn (on its wheels, lifted by the ground scale).
func _plane_at() -> Vector3:
	return game.plane.position+game.ground_scale.lift()

func enter() -> void:
	if active: return
	active = true
	game.overlay = self
	var camera: Camera3D = game.camera
	_was_eye = camera.global_transform
	_was_fov = camera.fov
	fov = camera.fov
	pivot = _plane_at()
	var off: Vector3 = camera.global_position-pivot
	dist = clampf(off.length(),NEAR,FAR)
	if off.length() < 0.01: off = Vector3(0.0,0.3,1.0)
	off = off.normalized()
	yaw = atan2(off.x,off.z)
	pitch = clampf(asin(clampf(off.y,-1.0,1.0)),-PITCH,PITCH)
	# The HUD: every layer the game shows, hidden until it lets go (and given
	# back just as it was).
	_hidden_layers.clear()
	for node: Node in game.find_children("*","CanvasLayer",true,false):
		var layer := node as CanvasLayer
		if layer != _layer and layer.visible:
			layer.visible = false
			_hidden_layers.append(layer)
	PhysicsServer3D.set_active(false)
	_build()
	_layer.visible = true
	_hint.visible = true
	_flash.visible = false
	_place()

func leave() -> void:
	if not active: return
	active = false
	if game.overlay == self: game.overlay = null
	for layer: CanvasLayer in _hidden_layers:
		if is_instance_valid(layer): layer.visible = true
	_hidden_layers.clear()
	PhysicsServer3D.set_active(true)
	var camera: Camera3D = game.camera
	camera.global_transform = _was_eye
	camera.fov = _was_fov
	if _layer != null: _layer.visible = false

## One frame while up, in the game's tick's place.
func step(delta: float) -> void:
	var look := Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down")
	if look != Vector2.ZERO: _turn(look*TURN_STICK*delta)
	var move := Pad.stick(&"move_left",&"move_right",&"move_forward",&"move_back")
	var lift := 0.0
	if Input.is_physical_key_pressed(KEY_E) or Input.is_action_pressed(&"fly_lean_right"): lift += 1.0
	if Input.is_physical_key_pressed(KEY_Q) or Input.is_action_pressed(&"fly_lean_left"): lift -= 1.0
	var speed := FLY*(FAST if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	# Flown along the view, kept level: forward is where the eye looks.
	var ahead := Vector3(-sin(yaw),0.0,-cos(yaw))
	var side := Vector3(cos(yaw),0.0,-sin(yaw))
	pivot += (side*move.x-ahead*move.y+Vector3.UP*lift)*speed*delta
	var from: Vector3 = _plane_at()
	var off := pivot-from
	if off.length() > REACH: pivot = from+off.normalized()*REACH
	pivot.y = maxf(pivot.y,float(game.eye_floor(pivot))+CLEAR)
	var lens := 0.0
	if Input.is_physical_key_pressed(KEY_Z): lens += 1.0
	if Input.is_physical_key_pressed(KEY_X): lens -= 1.0
	lens += Pad.trigger(&"zoom_out")-Pad.trigger(&"zoom_in")
	fov = clampf(fov+lens*FOV_RATE*delta,FOV_MIN,FOV_MAX)
	_place()
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0: _flash.visible = false

func _turn(by: Vector2) -> void:
	yaw -= by.x
	pitch = clampf(pitch+by.y,-PITCH,PITCH)

## The eye on its orbit round the pivot, kept over the land and the water.
func _place() -> void:
	var off := Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*dist
	var eye := pivot+off
	eye.y = maxf(eye.y,float(game.eye_floor(eye))+CLEAR)
	var camera: Camera3D = game.camera
	camera.global_position = eye
	var way := pivot-eye
	if way.length() > 0.01:
		var up := Vector3.UP if absf(way.normalized().y) < 0.995 else Vector3.FORWARD
		camera.look_at(pivot,up)
	camera.fov = fov

## Saves the view as drawn, with its own words hidden, to `dir`. Headless
## nothing is drawn: `last_error` says so and nothing is written.
func shoot() -> void:
	if _saving or not active: return
	_saving = true
	last_error = ""
	_hint.visible = false
	_flash.visible = false
	# Two frames, so the one read was drawn without the words.
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	var image: Image = null
	if DisplayServer.get_name() != "headless":
		var texture := game.get_viewport().get_texture()
		if texture != null: image = texture.get_image()
	if image == null or image.is_empty():
		last_error = "nothing drawn (headless)"
	else:
		var path := _path()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var err := image.save_png(path)
		if err == OK:
			saved += 1
			last_path = path
			if game.book != null: game.book.count("photos")
		else:
			last_error = "save_png %s: %s" % [path,error_string(err)]
	_saving = false
	if active:
		_hint.visible = true
		_flash.text = ("saved  ·  "+last_path.get_file()) if last_error == "" else ("not saved: "+last_error)
		_flash.visible = true
		_flash_t = FLASH

## A name by the date and time, with a number when two fall in one second.
func _path() -> String:
	var stamp := Time.get_datetime_string_from_system(false,true).replace(":","-").replace(" ","_")
	var path := "%s/%s.png" % [dir,stamp]
	var n := 2
	while FileAccess.file_exists(path):
		path = "%s/%s_%d.png" % [dir,stamp,n]
		n += 1
	return path

func _build() -> void:
	if _layer != null: return
	_layer = CanvasLayer.new()
	_layer.layer = 20
	game.add_child(_layer)
	_hint = _label(-34.0,16)
	_hint.text = "photo  ·  mouse / RS orbit  ·  WASD fly  ·  Q E down up  ·  wheel near far  ·  Z X lens  ·  Space save  ·  O leave"
	_hint.modulate = Color(1,1,1,0.75)
	_flash = _label(-62.0,18)

func _label(y: float, size: int) -> Label:
	var label := Label.new()
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_top = y
	label.offset_bottom = y+24.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_outline_color",Color(0,0,0,0.8))
	label.add_theme_constant_override("outline_size",4)
	_layer.add_child(label)
	return label
