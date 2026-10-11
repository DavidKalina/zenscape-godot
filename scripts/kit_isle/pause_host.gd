extends Node
## The game's pause (studies/zenscape.gd; docs/design/consolidation-audit.md,
## round 2). Esc or the pad's Menu, in the game once Begin is pressed,
## pauses the tree and puts the pause sheet (scripts/kit_isle/pause_menu.gd)
## over the isle; Esc, pad B or Menu again, or Resume, gives it back as it
## was (the mouse captured again if it was). From the sheet: Back to the
## plane (the scene's `back_to_plane`: beside the parked plane, as a hop
## out of it lands; nothing summons the plane, docs/design/manual-landing.md),
## Settings (scripts/kit_isle/settings_menu.gd, back to the pause on Back),
## Scenes (the scene picker, scripts/scene_picker.gd; a pick opens it, Back
## comes back), Back to the title (the game's main scene again, on the
## command line's flags less the ones that skip its title: the isle comes up
## afresh under the veil) and Quit.
##
## It also tells scripts/pad.gd which device is in hand (`note`, from the
## root window's every event, as the old game's scripts/pad_input.gd does),
## so the sheets' keys and the isle's prompts follow the device.
##
## It processes while paused, as does all it holds. Not while the title is
## up (the front door has the keys then), the isle is still coming up, or the
## study's recording-name panel is open (its Esc drops the recording).

const PauseMenu = preload("res://scripts/kit_isle/pause_menu.gd")
const SettingsMenu = preload("res://scripts/kit_isle/settings_menu.gd")
const Picker = preload("res://scripts/scene_picker.gd")
const Catalog = preload("res://scripts/scene_catalog.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const FrontDoor = preload("res://scripts/kit_isle/front_door.gd")
const Pad = preload("res://scripts/pad.gd")

var isle: Node3D
var layer: CanvasLayer
var menu: Control
var settings: Control
var picker: Control
## True from the pause until it's given back.
var is_open := false
## Where the way back to the title goes: the main scene. Tests point it
## elsewhere.
var title_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
var _mouse := Input.MOUSE_MODE_VISIBLE

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	Pad.ensure()
	get_tree().root.window_input.connect(Pad.note)

func _exit_tree() -> void:
	if get_tree().root.window_input.is_connected(Pad.note): get_tree().root.window_input.disconnect(Pad.note)

## Hosts the pause over `scene`.
func setup(scene: Node3D) -> void:
	isle = scene
	layer = CanvasLayer.new()
	layer.name = "PauseLayer"
	layer.layer = 60
	add_child(layer)
	menu = PauseMenu.new()
	menu.name = "PauseMenu"
	layer.add_child(menu)
	menu.resumed.connect(resume)
	menu.plane_requested.connect(back_to_plane)
	menu.settings_requested.connect(open_settings)
	menu.scenes_requested.connect(open_scenes)
	menu.title_requested.connect(back_to_title)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	settings = SettingsMenu.new()
	settings.name = "Settings"
	settings.isle = scene
	layer.add_child(settings)
	settings.closed.connect(func() -> void: if is_open: menu.open(menu.settings_row))

## Whether the pause may open now.
func can_pause() -> bool:
	if is_open or isle == null or not isle.walk_ready: return false
	var door: Node = isle.get("front_door")
	if door != null and door.titled: return false
	var naming: Control = isle.get("_name_panel")
	return naming == null or not naming.visible

## Whether Back to the plane is offered: on foot or off the edge, with
## the plane parked (in the plane it's the plane).
func can_return() -> bool:
	return not isle.flying and isle.parked and isle.lode_state != "inspecting"

## Pauses the tree and shows the sheet, Resume in reach.
func open() -> void:
	if not can_pause(): return
	is_open = true
	_mouse = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.present(isle.isle_name(),can_return(),Catalog.enabled())

## Everything closed, the tree given back, the mouse as it was.
func resume() -> void:
	if not is_open: return
	is_open = false
	menu.close()
	settings.close()
	if picker != null: picker.hide()
	get_tree().paused = false
	if get_tree().current_scene == isle: Input.mouse_mode = _mouse

func back_to_plane() -> void:
	resume()
	isle.back_to_plane()

func open_settings() -> void:
	menu.close()
	settings.present()

func open_scenes() -> void:
	if picker == null:
		picker = Picker.new()
		picker.name = "ScenePicker"
		layer.add_child(picker)
		picker.closed.connect(func() -> void: if is_open: menu.open(menu.scenes_row))
		picker.picked.connect(func(entry: Dictionary) -> void:
			_leave()
			Catalog.open(get_tree(),entry))
	menu.close()
	picker.present()

## The game's title again, afresh (the isle saves nothing yet).
func back_to_title() -> void:
	_leave()
	LaunchArgs.set_override(FrontDoor.title_args())
	get_tree().change_scene_to_file(title_scene)

func _leave() -> void:
	is_open = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## The pad's Menu while paused gives the isle back, whatever sheet is up.
func _input(event: InputEvent) -> void:
	if is_open and Pad.pressed(event,&"menu"):
		get_viewport().set_input_as_handled()
		resume()

## Esc or the pad's Menu in the game pauses it.
func _unhandled_input(event: InputEvent) -> void:
	if is_open: return
	var esc: bool = event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE
	if (esc or Pad.pressed(event,&"menu")) and can_pause():
		get_viewport().set_input_as_handled()
		open()
