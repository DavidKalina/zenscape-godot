extends Node
## The game's front door over a kit isle (studies/zenscape.gd, the project's
## main scene; docs/design/consolidation-audit.md, round 1): the loading
## veil (scripts/title_loading.gd) while the isle comes up, then the
## original minimal centred title (scripts/title_screen.gd: the ZENSCAPE
## wordmark, its tagline and the small linen card) over the isle, the camera
## orbiting it slowly as the old title orbited its showcase world. The card:
## Begin (on foot by the parked plane), and along its foot the quiet Scenes
## (the scene picker, scripts/scene_picker.gd, where the old game waits as
## "Builder (old game)") and Quit. Begin fades the card, gives the pilot
## back and eases the camera from the orbit down behind him.
##
## It sits as the scene's first child, so its `_process` runs after the
## scene's each frame: the orbit and the ease have the camera last. While
## the title is up the scene is `scripted` (the pilot stands, the mouse is
## free) and its own HUD layers are hidden; the isle's look, sky and life
## go on behind the card.
##
## The title shows when the scene is the current one (the game launched, or
## the way back from a picked scene: scripts/scene_return.gd), unless
## `--no-title`, `--capture=`, `--fly`, `--near-ring` or `--place=` is
## given, or the scene has the "no_title" meta; the "title" meta forces it
## (tests). The veil goes up with the title, and on a played start with no
## title (the scene current, no capture).

signal begun

const Title = preload("res://scripts/title_screen.gd")
const Loading = preload("res://scripts/title_loading.gd")
const Picker = preload("res://scripts/scene_picker.gd")
const Catalog = preload("res://scripts/scene_catalog.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
## Flags that start straight in, as `--no-title` does.
const STRAIGHT_IN := ["--no-title","--fly","--near-ring"]
const STRAIGHT_IN_PREFIX := ["--capture=","--place="]
## The orbit, as the old title's (studies/diorama.gd `_frame_title`): the
## eye POLAR rad down from straight above the isle's middle, raised LIFT m
## over its datum, at DISTANCE times its half-span (at least NEAR m), turning
## SPEED rad/s.
const POLAR := 1.10
const LIFT := 6.0
const DISTANCE := 1.35
const NEAR := 70.0
const SPEED := TAU/60.0*0.22
## The card fading out on Begin (s), and the camera's ease down behind the
## pilot.
const FADE := 0.6
const EASE := 1.8
const VEIL_TEXT := "The isle is rising out of the clouds"

var isle: Node3D
## The title wanted for this start, and up now.
var title_wanted := false
var titled := false
var veil: CanvasLayer
var layer: CanvasLayer
var title: Control
var picker: Control
var begin_button: Button
var scenes_button: Button
var quit_button: Button
## The orbit's middle (world), its reach (m) and its yaw now.
var orbit_middle := Vector3.ZERO
var orbit_distance := NEAR
var orbit_yaw := 0.0
var _hidden: Array[CanvasLayer] = []
var _ease_left := 0.0
var _ease_from := Transform3D.IDENTITY

## Whether `scene` opens on the title (see the doc above).
static func title_for(scene: Node) -> bool:
	if scene.has_meta("title"): return bool(scene.get_meta("title"))
	if scene.has_meta("no_title") or not scene.is_inside_tree(): return false
	if scene.get_tree().current_scene != scene: return false
	for arg: String in LaunchArgs.user_args():
		if arg in STRAIGHT_IN: return false
		for prefix: String in STRAIGHT_IN_PREFIX:
			if arg.begins_with(prefix): return false
	return true

## Whether a start puts the veil up: the title's, or a played start straight in.
static func veil_for(scene: Node) -> bool:
	if title_for(scene): return true
	if scene.has_meta("no_title") or not scene.is_inside_tree() or scene.get_tree().current_scene != scene: return false
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--capture="): return false
	return true

## Before the isle builds: decides the title, puts the veil up, and waits
## for the isle's `isle_ready`.
func open(scene: Node3D) -> void:
	isle = scene
	title_wanted = title_for(scene)
	if veil_for(scene):
		veil = Loading.new()
		veil.name = "Veil"
		add_child(veil)
		veil.stage(VEIL_TEXT)
	scene.isle_ready.connect(_lift,CONNECT_ONE_SHOT)

## The isle is up: the title over it, or the veil away and straight in.
func _lift() -> void:
	if not title_wanted:
		if veil != null: veil.fade_out()
		veil = null
		begun.emit()
		return
	_build_title()
	_frame_orbit()
	for child in isle.get_children():
		if child is CanvasLayer and child.visible and child != layer:
			_hidden.append(child)
			child.visible = false
	titled = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_orbit(0.0)
	# The title's own cover takes over from the veil (as the old title's).
	if veil != null: veil.queue_free()
	veil = null
	title.present(true)

func _build_title() -> void:
	layer = CanvasLayer.new()
	layer.name = "TitleLayer"
	layer.layer = 50
	add_child(layer)
	title = Title.new()
	title.name = "Title"
	layer.add_child(title)
	begin_button = title.add_action("Begin","On foot by your plane",begin)
	if Catalog.enabled(): scenes_button = title.add_action("Scenes","",open_scenes,true)
	quit_button = title.add_action("Quit","",func() -> void: get_tree().quit(),true)

## The orbit round the isle's art: its middle and reach from what it draws.
func _frame_orbit() -> void:
	var bounds := AABB()
	var first := true
	var art: Node = isle.get("art")
	if art != null:
		for mesh: MeshInstance3D in art.find_children("*","MeshInstance3D",true,false):
			if mesh.mesh == null: continue
			var box: AABB = mesh.global_transform*mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
	var top: float = isle.isle_top()
	if first:
		orbit_middle = Vector3(isle.start.x,top,isle.start.z)
	else:
		var centre := bounds.get_center()
		orbit_middle = Vector3(centre.x,top,centre.z)
		orbit_distance = maxf(NEAR,maxf(bounds.size.x,bounds.size.z)*0.5*DISTANCE)
	# From the start's side, so the pilot by his plane is in view first.
	var start: Vector3 = isle.start
	orbit_yaw = atan2(start.x-orbit_middle.x,start.z-orbit_middle.z)

func _orbit(delta: float) -> void:
	orbit_yaw = wrapf(orbit_yaw+SPEED*delta,-PI,PI)
	var at := orbit_middle+Vector3.UP*LIFT
	var eye := at+Vector3(sin(POLAR)*sin(orbit_yaw),cos(POLAR),sin(POLAR)*cos(orbit_yaw))*orbit_distance
	var camera: Camera3D = isle.camera
	camera.look_at_from_position(eye,at)

func _process(delta: float) -> void:
	if isle == null: return
	if titled:
		_orbit(delta)
		return
	if _ease_left <= 0.0: return
	_ease_left = maxf(_ease_left-delta,0.0)
	var camera: Camera3D = isle.camera
	var t := 1.0-_ease_left/EASE
	camera.global_transform = _ease_from.interpolate_with(camera.global_transform,smoothstep(0.0,1.0,t))

## Begin: the card fades, the HUD comes back, the pilot is given back by his
## plane and the camera eases from the orbit down behind him.
func begin() -> void:
	if not titled: return
	if picker != null and picker.visible: return
	titled = false
	isle.scripted = false
	for child in _hidden:
		if is_instance_valid(child): child.visible = true
	_hidden.clear()
	_ease_from = isle.camera.global_transform
	_ease_left = EASE
	if get_tree().current_scene == isle: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	title.release_focus()
	for button in title.buttons: button.focus_mode = Control.FOCUS_NONE
	var tween := create_tween()
	tween.tween_property(title,"modulate:a",0.0,FADE)
	tween.tween_callback(layer.hide)
	begun.emit()

## The scene picker over the card, which fades under it; Back brings the
## card again with Scenes in reach.
func open_scenes() -> void:
	if not titled: return
	if picker == null:
		picker = Picker.new()
		picker.name = "ScenePicker"
		layer.add_child(picker)
		picker.closed.connect(_close_scenes)
		picker.picked.connect(func(entry: Dictionary) -> void: Catalog.open(get_tree(),entry))
	title.modulate.a = 0.0
	picker.present()

func _close_scenes() -> void:
	create_tween().tween_property(title,"modulate:a",1.0,0.25)
	if scenes_button != null and scenes_button.is_visible_in_tree(): scenes_button.grab_focus()
