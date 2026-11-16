extends "res://scripts/endless/ui/menu_base.gd"
## The pause menu (docs/design/ui/mock/Main.dc.html, its pause screen): Esc
## or the pad's Start (`menu`, scripts/pad.gd) in flight opens a slip down
## the left with Resume, Logbook, Map, Photo mode, Hangar, Controls, Settings, Quit to
## title and Quit, over the flight held still.
##
## It is the game's overlay while up, as the logbook is (scripts/endless/
## logbook_view.gd): `game.overlay` is this, the tree is paused (this runs
## through it), the mouse is let go; Resume, Esc, B or Start give all three
## back. It opens only in flight with no other overlay up (the shop, the
## logbook and photo mode keep Esc), and not while the title holds the plane.
##
## Logbook and Map open the game's logbook or map over the held flight and
## come back here when they close. Photo mode resumes into the game's photo mode (it
## runs in the game's own tick, so the tree cannot stay held under it).
## Quit to title loads the scene again with the title up: nothing in the
## game parks a flown plane back on the title's meadow.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const ControlsPage = preload("res://scripts/endless/ui/controls_page.gd")

const WASH_IN := 0.2

## The tree held before the flight's first tick ends the run in an access
## violation when it quits (found by the settings page's --open-settings): the
## menu opens only after the flight has run this many frames and physics ticks.
const FIRST_TICKS := 3

## The flight HUD's top chips stay up under the pause slip (FlightHud reads
## this off the game's overlay): the money shows while paused. Not under a
## page (controls, settings), which has the screen to itself.
var keeps_flight_hud := true
var _frames := 0
var _ticks := 0
var _open := false
## The logbook is up over the held flight; back here when it closes.
var _away := false
var _was_paused := false
var _wash := 0.0

func _init(game: Node = null) -> void:
	super()
	host = game
	name = "PauseMenu"
	rows = [{"id":"resume","label":"Resume","key":"Esc","pad":"Start"},
		{"id":"logbook","label":"Logbook","key":"J"},
		{"id":"map","label":"Map","key":"M","pad":"View"},
		{"id":"photo","label":"Photo mode","key":"O","pad":"L3"},
		{"id":"hangar","label":"Hangar"},
		{"id":"controls","label":"Controls"},
		{"id":"settings","label":"Settings"},
		{"id":"title","label":"Quit to title","gap":8.0},
		{"id":"quit","label":"Quit"}]
	visible = false
	active = false

func setup(game: Node) -> void:
	host = game

func is_open() -> bool:
	return _open

## True when Esc or Start would open it now.
func can_open() -> bool:
	if _open or host == null or not host.walk_ready or host.overlay != null: return false
	if _frames < FIRST_TICKS or _ticks < FIRST_TICKS: return false
	return host.stage == null or not host.stage.holding()

func open_menu() -> void:
	if not can_open(): return
	_open = true
	_away = false
	host.overlay = self
	host.key_line_under(true)
	_was_paused = get_tree().paused
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_wash = 0.0
	visible = true
	active = true
	arrive(0)

## Back to the flight: the overlay, the tree and the mouse given back.
func resume() -> void:
	if not _open: return
	_open = false
	_away = false
	active = false
	visible = false
	if page != null:
		page.queue_free()
		page = null
	if host.overlay == self: host.overlay = null
	host.key_line_under(false)
	get_tree().paused = _was_paused
	if get_tree().current_scene == host and DisplayServer.get_name() != "headless": Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _exit_tree() -> void:
	super()
	# Never leave the tree held behind it.
	if _open: resume()

func _unhandled_input(event: InputEvent) -> void:
	if _open or not _wants(event) or not can_open(): return
	open_menu()
	_taken()

## Esc or the pad's Start, pressed.
func _wants(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key != null: return key.pressed and not key.echo and key.keycode == KEY_ESCAPE
	return Pad.pressed(event,&"menu")

func other_input(event: InputEvent) -> bool:
	if not Pad.pressed(event,&"menu"): return false
	resume()
	return true

func back() -> void:
	resume()

func pick(i: int) -> void:
	match str(rows[i].id):
		"resume": resume()
		"logbook": _hand_over(host.logbook,&"open_book")
		"map": _hand_over(host.get("map_page"),&"open_map")
		"photo":
			resume()
			if host.photo != null and host.overlay == null: host.photo.enter()
		"hangar": open_hangar()
		"controls": open_page(ControlsPage.new())
		"settings": open_settings()
		"title": quit_to_title()
		"quit": get_tree().quit()

## The game's logbook or map over the held flight (`open` its opener);
## `_process` takes the overlay back when it closes.
func _hand_over(book: Control, open: StringName) -> void:
	if book == null: return
	host.overlay = null
	book.call(open)
	if host.overlay != book:
		host.overlay = self
		return
	_away = true
	active = false
	visible = false

## Back to the title: the scene loaded again on the launch's flags without
## the ones that skip the title.
func quit_to_title() -> void:
	var tree := get_tree()
	if tree.current_scene != host:
		resume()
		return
	resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	LaunchArgs.set_override(LaunchArgs.title_args(LaunchArgs.own_args()))
	tree.reload_current_scene()

func _physics_process(_delta: float) -> void:
	if _ticks < FIRST_TICKS and host != null and host.walk_ready: _ticks += 1

func _process(delta: float) -> void:
	if _frames < FIRST_TICKS and host != null and host.walk_ready: _frames += 1
	keeps_flight_hud = page == null
	# A page's slip would lie half over the chain HUD by the plane: that goes too.
	var chain: CanvasItem = host.get("_near_hud") if host != null else null
	if chain != null: chain.modulate.a = move_toward(chain.modulate.a,0.0 if _open and page != null else 1.0,delta/0.15)
	if _away and host.overlay == null:
		# The logbook closed: the menu again, on the row it left from.
		_away = false
		host.overlay = self
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		visible = true
		active = true
		_closed_frame = Engine.get_process_frames()
		arrive(sel)
	super(delta)

func tick(delta: float) -> void:
	if _wash < 1.0:
		_wash = minf(1.0,_wash+delta/WASH_IN)
		queue_redraw()

func _draw() -> void:
	var s := k()
	# No wash under a page that shows the scene (the hangar: the plane's colours).
	if page == null or page.get("shows_scene") != true: draw_rect(Rect2(Vector2.ZERO,size),Color(Kit.NIGHT,Kit.WASH_A*_wash))
	if page == null:
		var arrival := Kit.slip_in(age)
		var slip := Rect2(72.0*s-arrival.x*s,238.0*s,228.0*s,(8.0+30.0+rows_height(30.0)+12.0)*s)
		Kit.slip(self,slip,s,arrival.y)
		Kit.head(self,slip,slip.position.y+8.0*s,s,"Paused",30.0,0.0,34.0,arrival.y)
		draw_rows(slip,slip.position.y+38.0*s,s,30.0,16.0,36.0,arrival.y)
		draw_footer([P_SELECT,P_CHOOSE,["Esc","B","resume"]],s)
	draw_toast(s)
