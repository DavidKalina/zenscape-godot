extends "res://scripts/endless/ui/menu_base.gd"
## The controls page (docs/design/ui/mock/Main.dc.html, its controls
## screen): what each control does, its keys and its pad buttons, on one
## slip, with Back. A page (menu_base.gd `open_page`): `setup(host)`, then
## `closed` when Back, Esc or the pad's B leaves it.
##
## The bindings are read, not written here: an action's keys and buttons
## come from the InputMap (scripts/pad.gd ACTIONS fills it, a remap changes
## it), and the few keys the game reads straight off the keyboard
## (studies/endless_flight.gd `_unhandled_input`, `_fly_input`) are named in
## LINES as `keys`. A line with no pad binding shows a dash.

signal closed

## The page's lines, in the mock-up's order; {} is the rule between groups.
## `actions`: the InputMap actions whose bindings it shows. `keys`: the keys
## column as given (a key read directly). `join`: between two bindings.
## `note`: after both columns' bindings; `key_note`: after the keys only.
const LINES := [
	{"label":"Bank","actions":["move_left","move_right"]},
	{"label":"Pitch","actions":["move_forward","move_back"]},
	{"label":"Steer","keys":"Mouse"},
	{"label":"Boost","actions":["fly_boost"]},
	{"label":"Brake","actions":["fly_brake"]},
	{},
	{"label":"Roll","actions":["fly_roll"]},
	{"label":"Surge","actions":["fly_surge"],"note":"hold"},
	{"label":"Surge roll","actions":["fly_roll","fly_surge"],"join":" or ","key_note":"at full charge"},
	{"label":"Knife edge","keys":"Q E","actions":["fly_lean_left","fly_lean_right"],"note":"hold"},
	{"label":"Flaps, land","keys":"F","actions":["fly_land"]},
	{},
	{"label":"Race a plane","actions":["fly_challenge"],"note":"hold"},
	{"label":"Photo mode","keys":"O","actions":["photo"]},
	{"label":"Logbook","keys":"J"},
	{"label":"Up again","keys":"R"},
	{"label":"Menu","keys":"Esc","actions":["menu"]},
]
## The pad's buttons and axes by name, as the page words them.
const BUTTONS := {JOY_BUTTON_A:"A",JOY_BUTTON_B:"B",JOY_BUTTON_X:"X",JOY_BUTTON_Y:"Y",
	JOY_BUTTON_LEFT_SHOULDER:"LB",JOY_BUTTON_RIGHT_SHOULDER:"RB",JOY_BUTTON_LEFT_STICK:"L3",JOY_BUTTON_RIGHT_STICK:"R3",
	JOY_BUTTON_BACK:"View",JOY_BUTTON_START:"Start",JOY_BUTTON_DPAD_UP:"D-pad up",JOY_BUTTON_DPAD_DOWN:"D-pad down",
	JOY_BUTTON_DPAD_LEFT:"D-pad left",JOY_BUTTON_DPAD_RIGHT:"D-pad right"}
const AXES := {JOY_AXIS_LEFT_X:"Left stick",JOY_AXIS_LEFT_Y:"Left stick",JOY_AXIS_RIGHT_X:"Right stick",JOY_AXIS_RIGHT_Y:"Right stick",
	JOY_AXIS_TRIGGER_LEFT:"LT",JOY_AXIS_TRIGGER_RIGHT:"RT"}
const KEY_WORDS := {"Escape":"Esc","Control":"Ctrl","PageUp":"PgUp","PageDown":"PgDn"}

var _table: Array = []

func _init() -> void:
	super()
	name = "ControlsPage"
	rows = [{"id":"back","label":"Back","key":"Esc","pad":"B","gap":10.0}]

func setup(game: Node) -> void:
	host = game
	Pad.ensure()
	_table = table()
	arrive(0)

func pick(_i: int) -> void:
	closed.emit()

func back() -> void:
	closed.emit()

## The page as [label, keys, pad] lines ([] for a rule): what `_draw` shows.
static func table() -> Array:
	var out := []
	for line: Dictionary in LINES:
		if line.is_empty():
			out.append([])
			continue
		var actions: Array = line.get("actions",[])
		var join := str(line.get("join"," "))
		var keys := str(line.get("keys",""))
		if keys.is_empty(): keys = join.join(bound(actions,false))
		var pad := join.join(bound(actions,true))
		var note := str(line.get("note",""))
		if not note.is_empty():
			keys += " "+note
			if not pad.is_empty(): pad += " "+note
		if line.has("key_note"): keys += " "+str(line.key_note)
		out.append([str(line.label),keys,pad])
	return out

## The first key (or with `pad` the first pad button or axis) each of
## `actions` is bound to, by name, a name given once.
static func bound(actions: Array, pad: bool) -> PackedStringArray:
	var out := PackedStringArray()
	for action: String in actions:
		var word := ""
		for event: InputEvent in _events(action):
			word = _word(event,pad)
			if not word.is_empty(): break
		if not word.is_empty() and not word in out: out.append(word)
	return out

## An action's events: the InputMap's, else scripts/pad.gd's own table.
static func _events(action: String) -> Array:
	if InputMap.has_action(action): return InputMap.action_get_events(action)
	var out := []
	for spec: Array in Pad.ACTIONS.get(action,[]): out.append(Pad._event(spec))
	return out

static func _word(event: InputEvent, pad: bool) -> String:
	if pad:
		if event is InputEventJoypadButton: return str(BUTTONS.get((event as InputEventJoypadButton).button_index,""))
		if event is InputEventJoypadMotion: return str(AXES.get((event as InputEventJoypadMotion).axis,""))
		return ""
	var key := event as InputEventKey
	if key == null: return ""
	var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	var word := OS.get_keycode_string(code)
	return str(KEY_WORDS.get(word,word))

func _draw() -> void:
	var s := k()
	var arrival := Kit.slip_in(age)
	var a := arrival.y
	var body := 0.0
	for line: Array in _table: body += 12.0 if line.is_empty() else 25.0
	var slip := Rect2(72.0*s-arrival.x*s,112.0*s,500.0*s,(8.0+30.0+22.0+body+rows_height(30.0)+12.0)*s)
	Kit.slip(self,slip,s,a)
	var y := slip.position.y+8.0*s
	Kit.head(self,slip,y,s,"Controls",30.0,0.0,38.0,a)
	y += 30.0*s
	Kit.ctrl_cols(self,slip,y,s,"Keyboard and mouse","Gamepad",a)
	y += 22.0*s
	for line: Array in _table:
		if line.is_empty():
			Kit.ctrl_rule(self,slip,y,s,a)
			y += 12.0*s
		else:
			Kit.ctrl_row(self,slip,y,s,str(line[0]),str(line[1]),str(line[2]),a)
			y += 25.0*s
	draw_rows(slip,y,s,30.0,15.0,42.0,a)
	draw_footer([P_BACK],s)
