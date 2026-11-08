extends CanvasLayer
## The shell's menus over endless flight (studies/endless_flight.gd): Pause
## in flight, and Settings, Controls and Credits from Pause or the title
## (scripts/endless/main_menu.gd). One stack of pages (shell_page.gd); Back
## goes down it, and off the bottom resumes the flight or hands the title
## its picks again.
##
## Pause is one more overlay (`game.overlay`, as the logbook): Esc or the
## pad's Menu opens it only while no overlay is up and the title is gone;
## the tree is paused, the sound ducked, the mouse freed; Resume takes the
## mouse again. Quit to Title opens the scene again on its title (a clean
## reload: the land, the plane and the menu stage are all built in `_ready`).

const S = preload("res://scripts/endless/shell/shell_settings.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const GraphicsPreset = preload("res://scripts/graphics_preset.gd")
const Pad = preload("res://scripts/pad.gd")
const PAGES := {
	"pause":preload("res://scripts/endless/shell/pause_page.gd"),
	"settings":preload("res://scripts/endless/shell/settings_page.gd"),
	"controls":preload("res://scripts/endless/shell/controls_page.gd"),
	"credits":preload("res://scripts/endless/shell/credits_page.gd"),
}

var game: Node
var pages := {}
var stack: Array = []
## Opened from the title (not over a paused flight).
var from_title := false
## The preset kept differs from the run's: the flight starts again on close.
var preset_changed := false
var _was_paused := false
## The game's own canvas layers (the HUD, the hints) hidden while a page is
## up, and whether each was shown.
var _hidden := {}

func _init() -> void:
	name = "Shell"
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS

## Hooked to `game`; the kept window mode and vsync applied.
func setup(host: Node) -> void:
	game = host
	S.apply_boot()

func is_open() -> bool:
	return not stack.is_empty()

func paused() -> bool:
	return game != null and game.overlay == self

## Esc or the pad's Menu in flight: Pause, if nothing else holds the keys.
## True if it took the event.
func wants(event: InputEvent) -> bool:
	var esc: bool = event is InputEventKey and event.pressed and not event.is_echo() and (event as InputEventKey).keycode == KEY_ESCAPE
	if not esc and not Pad.pressed(event,&"menu"): return false
	return pause()

func pause() -> bool:
	if game == null or game.overlay != null or is_open(): return false
	if game.stage != null: return false
	game.overlay = self
	from_title = false
	_was_paused = get_tree().paused
	get_tree().paused = true
	S.duck(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	open_page("pause")
	return true

func resume() -> void:
	if not paused(): return
	_close_all()
	game.overlay = null
	get_tree().paused = _was_paused
	S.duck(false)
	if preset_changed:
		_restart()
		return
	if get_tree().current_scene == game and DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## A title pick this owns ("settings", "controls", "credits"): opened over
## the meadow, the title's picks held until it is closed. True if taken.
func title_pick(what: String) -> bool:
	if not what in ["settings","controls","credits"] or is_open(): return false
	from_title = true
	if game.menu != null: game.menu.hold(true)
	open_page(what)
	return true

func open_page(what: String) -> void:
	if not pages.has(what):
		var page: Control = PAGES[what].new(self)
		page.name = what.capitalize()
		page.back.connect(back)
		page.menu.connect(_menu_button)
		add_child(page)
		pages[what] = page
	if not stack.is_empty(): (stack.back() as Control).close()
	else: _hide_layers(true)
	stack.append(pages[what])
	(pages[what] as Control).open()

## The page on top, or null.
func top() -> Control:
	return null if stack.is_empty() else stack.back()

func back() -> void:
	if stack.is_empty(): return
	(stack.pop_back() as Control).close()
	if not stack.is_empty():
		(stack.back() as Control).open()
		return
	_hide_layers(false)
	if paused():
		resume()
		return
	from_title = false
	if preset_changed:
		_restart()
		return
	if game.menu != null: game.menu.hold(false)

func _menu_button() -> void:
	if paused(): resume()

func _close_all() -> void:
	while not stack.is_empty(): (stack.pop_back() as Control).close()
	_hide_layers(false)

func _hide_layers(on: bool) -> void:
	if on:
		for c: Node in game.get_children():
			if c is CanvasLayer and c != self and (c as CanvasLayer).visible:
				_hidden[c] = true
				(c as CanvasLayer).visible = false
		return
	for c: Object in _hidden:
		if is_instance_valid(c): (c as CanvasLayer).visible = true
	_hidden.clear()

func note_preset() -> void:
	preset_changed = S.preset_index() != GraphicsPreset.NAMES.find(GraphicsPreset.current)

func quit_to_title() -> void:
	_leave()
	LaunchArgs.open_scene(get_tree(),game.scene_file_path,_args(LaunchArgs.title_args(LaunchArgs.own_args())),true)

func quit() -> void:
	_leave()
	get_tree().quit()

func _leave() -> void:
	_close_all()
	if paused(): game.overlay = null
	get_tree().paused = false
	S.duck(false)

## The flight again on the kept preset, as F3 does: straight into the air
## from Pause, on the title from the title.
func _restart() -> void:
	var title := from_title or game.stage != null
	_leave()
	if title: LaunchArgs.open_scene(get_tree(),game.scene_file_path,_args(LaunchArgs.title_args(LaunchArgs.own_args())),true)
	else: GraphicsPreset.restart(get_tree(),game.scene_file_path)

func _args(from: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for a: String in from:
		if not a.begins_with("--preset="): out.append(a)
	return out
