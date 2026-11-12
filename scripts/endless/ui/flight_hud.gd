extends Control
## The flight HUD's corner pieces (docs/design/ui/spec-flight-ui.md, lane hud),
## built from docs/design/ui/mock/Hud.dc.html and the flight tab of
## Main.dc.html with the kit (ui_kit.gd). One full-rect Control on the HUD's
## canvas layer, drawn each frame it shows:
##
## - top left: the finds chip (mark, found / total), the money chip beside it
##   (coin, total, "+N", and behind a switch what the flight earned), the
##   region tag under them when a region is entered, a find's name under that;
## - lower right: the charge and the speed in one plate (chevrons, five cells,
##   roll mark; km/h before them), and over it the key plates ("B SURGE",
##   "Z ROLL") when each first becomes available and while it is held;
## - lower left: the short hint from takeoff, and the landing's stop cue.
##
## `studies/endless_flight.gd` makes one with `make(game, layer)` unless
## `--hud=old`. It then takes today's pieces off the screen (the key line, the
## stop cue's label, the centred region caption, the finds counter) and
## reads the game's own state for its own: nothing is fed to it.
##
## For the trunk:
## - `OPTS` / `opt` / `set_opt`: the switches (launch flags for now).
## - `set_hints(on)`: the settings' "HUD hints".
## - `draws_charge`: true while a FlightHud draws the charge, so the chain
##   HUDs leave their own corner bar out.
## - `money_anchor()`, `pending()`, `land_coin(n)`, `coin_flight`: the coin
##   flight's hooks.
## - `draw_coin`, `draw_roll`, `draw_surge`, `draw_finds_mark`: the marks,
##   one function each, for the glyph set to take over.

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
const Pad = preload("res://scripts/pad.gd")
const Glyphs = preload("res://scripts/endless/near_glyphs.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

# --- The switches ------------------------------------------------------------------------

## Every switch: its launch flag, its values (the first is the default).
## `--hud-money=always`, `--hud-speed=always|off`, `--hud-earned`,
## `--hud-hints=off`. The settings page drives the same table with `set_opt`.
const OPTS := {
	"money": {"flag":"--hud-money","values":["bank","always"]},
	"speed": {"flag":"--hud-speed","values":["when","always","off"]},
	"earned": {"flag":"--hud-earned","values":["off","on"]},
	"hints": {"flag":"--hud-hints","values":["on","off"]},
}
static var _opts := {}
## True while a FlightHud is up and draws the charge: the chain HUDs skip
## their own bar in the lower right (near_miss_hud_handoff.gd, _glyph.gd).
static var draws_charge := false

## False with `--hud=old`: today's counter, caption, bar and key line stay.
static func wanted() -> bool:
	return not ("--hud=old" in LaunchArgs.user_args())

## A switch's value now ("bank", "when", "off", ...).
static func opt(name: String) -> String:
	if _opts.is_empty(): read_flags(LaunchArgs.user_args())
	return str(_opts.get(name,""))

## Sets a switch; a value it does not have is ignored.
static func set_opt(name: String, value: String) -> void:
	if _opts.is_empty(): read_flags(LaunchArgs.user_args())
	if OPTS.has(name) and value in (OPTS[name] as Dictionary)["values"]: _opts[name] = value

## The switches from launch flags: `--flag=value`, or the bare flag for the
## second value.
static func read_flags(args: PackedStringArray) -> void:
	for name: String in OPTS:
		var o: Dictionary = OPTS[name]
		var values: Array = o["values"]
		_opts[name] = str(values[0])
		for arg in args:
			if arg == str(o["flag"]): _opts[name] = str(values[1])
			elif arg.begins_with(str(o["flag"])+"="):
				var v := arg.get_slice("=",1)
				if v in values: _opts[name] = v

## The settings' "HUD hints": the hint line, the stop cue and the key plates.
static func set_hints(on: bool) -> void:
	set_opt("hints","on" if on else "off")

static func hints_on() -> bool:
	return opt("hints") == "on"

## A FlightHud for `game`, on `layer`.
static func make(game: Node, layer: Node) -> Control:
	var hud: Control = load("res://scripts/endless/ui/flight_hud.gd").new()
	hud.set("game",game)
	hud.name = "FlightHud"
	layer.add_child(hud)
	return hud

# --- The mock-up's numbers ---------------------------------------------------------------

const KICK := Color("fff8df")
const HOT := Color("fff3c9")
const SURGING := Color("ffe7a3")
const MARK_OFF_A := 0.32
## The hint stays this long from takeoff, and every fade of a corner piece.
const HINT_HOLD := 6.5
const FADE := 0.6
## A key plate shows this long when its key first has something to spend.
const KEY_HOLD := 2.2
## The money's beat, seconds after the pay (Hud.dc.html): the chip comes up,
## the coins land one by one, the "+N" shows and goes, the chip goes.
const CHIP_IN := Vector2(1.3,1.6)
const CHIP_OUT := Vector2(4.8,5.2)
const LAND_AT := 2.45
const LAND_GAP := 0.09
const COINS_MOST := 6
const PLUS_FOR := Vector2(1.45,1.85)
## The speed counts as changing fast over this many km/h a second.
const SPEED_FAST := 12.0
const SPEED_HOLD := 0.6
## Gold this far over the plane's boost speed (the mock-up: 210 over 208).
const SPEED_TOP := 2.0

# --- State -------------------------------------------------------------------------------

var game: Node
## Set by the coin flight: the total then waits for `land_coin` instead of
## ticking by itself.
var coin_flight := false

var _a := 0.0
var _top_a := 1.0
var _clock := 0.0
var _taken := false
var _finds_hud: Node
var _was_flying := false
var _was_stage := true

var _money_known := false
var _shown := 0
var _pending := 0
var _plus := 0
var _lands: Array = []
var _bank_age := 99.0
var _plus_age := 99.0
var _kick_age := 99.0
var _stay_a := 0.0
var _money_a := 0.0

var _meter := 0.0
var _prev_meter := 0.0
var _prev_ready := false
var _hot := false
var _was_hot := false
var _surge := false
var _rise := 0.0
var _b_age := 99.0
var _z_age := 99.0
var _b_held := 0.0
var _roll_age := 99.0
var _charge_on := false

var _kmh := 0.0
var _prev_kmh := -1.0
var _accel := 0.0
var _top := false
var _spd_hold := 0.0
var _spd_a := 0.0

var _hint_age := 99.0
var _hint_a := 0.0
var _stop_a := 0.0
var _stop_text := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	draws_charge = true

func _exit_tree() -> void:
	draws_charge = false

# --- The coin flight's hooks -------------------------------------------------------------

## Where a coin should land: the middle of the money chip's coin, screen px.
## True whether or not the chip is up yet.
func money_anchor() -> Vector2:
	var k := Kit.scale_of(size)
	return Vector2(_money_x(k)+19.0*k,40.0*k)

## Money the book holds that the total does not show yet: a bank's pay, until
## its coins land. The HUD finds the pay itself (the book's money against
## what it shows), in the frame of the bank.
func pending() -> int:
	return _pending

## One coin landed: `n` of the pending money joins the total, which kicks.
func land_coin(n := 1) -> void:
	var take := mini(n,_pending)
	if take <= 0: return
	_pending -= take
	_shown += take
	_kick_age = 0.0
	if _plus_age > PLUS_FOR.y: _plus_age = 0.0

## Seconds since the pay the chip is showing (99 at rest): the beat's clock.
func bank_age() -> float:
	return _bank_age

func _gain(d: int) -> void:
	if _pending <= 0 and _plus_age > PLUS_FOR.y: _plus = 0
	_plus += d
	_pending += d
	if _bank_age > CHIP_OUT.y: _bank_age = CHIP_IN.y if _money_a >= 0.99 else 0.0
	elif _bank_age > CHIP_IN.y: _bank_age = CHIP_IN.y
	if coin_flight: return
	var n := mini(d,COINS_MOST)
	for i in n:
		@warning_ignore("integer_division")
		var amount := d/n+(1 if i < d%n else 0)
		_lands.append([LAND_AT+LAND_GAP*i,amount])

# --- Each frame --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if game == null: return
	var dt := minf(delta,0.1)
	_clock += dt
	if not _taken: _take_over()
	var overlay: Object = game.get("overlay")
	var open := game.get("stage") == null and (overlay == null or bool(overlay.get("keeps_flight_hud")))
	_a = move_toward(_a,1.0 if open else 0.0,dt/0.25)
	var numbers: Control = game.get("_hud")
	_top_a = move_toward(_top_a,0.0 if numbers != null and numbers.visible else 1.0,dt/0.2)
	var landing: Object = game.get("hand_landing")
	var flying := landing == null or bool(landing.call("flying"))
	var paused := get_tree().paused
	if not paused:
		_money_step(dt,not flying)
		_charge_step(dt)
		_speed_step(dt,flying)
		_hint_step(dt,flying)
	else:
		_stay_a = move_toward(_stay_a,1.0,dt/0.3)
		_money_a = maxf(_money_a,_stay_a)
	if visible != (_a > 0.003): visible = _a > 0.003
	if visible: queue_redraw()

## Today's pieces off the screen, once: the key line and the stop cue's label
## keep their `visible` (the game reads it) and lose their ink; the centred
## region caption goes (its text and timing are read here); the finds
## counter stops drawing its tally.
func _take_over() -> void:
	for n in ["_hint","_stop_cue"]:
		var label: Control = game.get(n)
		if label != null: label.self_modulate.a = 0.0
	var caption: Control = game.get("_region_caption")
	if caption != null: caption.visible = false
	var finds: Node = game.get("finds")
	if finds != null and finds.get("hud") != null:
		_finds_hud = finds.get("hud")
		_finds_hud.set("counter",false)
	_taken = true

func _money_step(dt: float, landed: bool) -> void:
	var book: Object = game.get("book")
	if book == null: return
	var now := int(book.get("money"))
	if not _money_known:
		_money_known = true
		_shown = now
	var gap := now-(_shown+_pending)
	if gap > 0: _gain(gap)
	elif gap < 0:
		var take := mini(_pending,-gap)
		_pending -= take
		_shown += gap+take
		_kick_age = 0.0
	_bank_age += dt
	_plus_age += dt
	_kick_age += dt
	while not _lands.is_empty() and float((_lands[0] as Array)[0]) <= _bank_age:
		var land: Array = _lands.pop_front()
		land_coin(int(land[1]))
	# The flight's coins never came (or came short): the total is made right.
	if _pending > 0 and _lands.is_empty() and _bank_age > CHIP_OUT.x-0.4: land_coin(_pending)
	_stay_a = move_toward(_stay_a,1.0 if landed or opt("money") == "always" else 0.0,dt/0.3)
	var beat := smoothstep(CHIP_IN.x,CHIP_IN.y,_bank_age)*(1.0-smoothstep(CHIP_OUT.x,CHIP_OUT.y,_bank_age))
	_money_a = maxf(beat,_stay_a)

func _charge_step(dt: float) -> void:
	var near: Object = game.get("near")
	var plane: Object = game.get("plane")
	_charge_on = near != null and plane != null and bool(plane.get("weighted"))
	if not _charge_on: return
	_meter = clampf(float(near.get("meter")),0.0,1.0)
	var smash: Object = game.get("smash")
	_hot = smash != null and bool(smash.get("hot")) and _meter > 0.0
	_surge = not _hot and _meter > 0.0 and float(near.get("surge")) > 0.02
	var ready := _meter >= 0.999 and not _hot
	if _meter > _prev_meter+0.0005: _rise = 0.2
	_rise = maxf(_rise-dt,0.0)
	_b_age += dt
	_z_age += dt
	_roll_age += dt
	if _prev_meter <= 0.002 and _meter > 0.002: _b_age = 0.0
	if ready and not _prev_ready: _z_age = 0.0
	if _hot and not _was_hot: _roll_age = 0.0
	_b_held = move_toward(_b_held,1.0 if _surge else 0.0,dt/(0.05 if _surge else 0.25))
	_prev_meter = _meter
	_prev_ready = ready
	_was_hot = _hot

func _speed_step(dt: float, flying: bool) -> void:
	var plane: Object = game.get("plane")
	if plane == null: return
	_kmh = float(plane.get("speed"))*3.6
	if _prev_kmh < 0.0: _prev_kmh = _kmh
	_accel = lerpf(_accel,(_kmh-_prev_kmh)/maxf(dt,0.001),1.0-exp(-dt*5.0))
	_prev_kmh = _kmh
	_top = _kmh > float(plane.call("boost_speed"))*3.6+SPEED_TOP
	var mode := opt("speed")
	var matters := _top or (absf(_accel) > SPEED_FAST and (flying or _kmh > 20.0))
	_spd_hold = SPEED_HOLD if matters else maxf(_spd_hold-dt,0.0)
	var want := 1.0 if mode == "always" else (0.0 if mode == "off" else (1.0 if _spd_hold > 0.0 else 0.0))
	_spd_a = move_toward(_spd_a,want,dt/(0.2 if want > _spd_a else 0.7))

func _hint_step(dt: float, flying: bool) -> void:
	var staged := game.get("stage") != null
	# From takeoff: the title gone, or the wheels off the ground again.
	if (_was_stage and not staged) or (flying and not _was_flying and not staged): _hint_age = 0.0
	_was_stage = staged
	_was_flying = flying
	_hint_age += dt
	var on := hints_on()
	_hint_a = move_toward(_hint_a,1.0 if on and not staged and _hint_age < HINT_HOLD else 0.0,dt/FADE)
	var cue: Label = game.get("_stop_cue")
	var cued := on and cue != null and cue.visible and not cue.text.is_empty()
	if cued: _stop_text = cue.text
	_stop_a = move_toward(_stop_a,1.0 if cued else 0.0,dt/0.25)

# --- Drawing -----------------------------------------------------------------------------

func _draw() -> void:
	if game == null or _a <= 0.003: return
	var k := Kit.scale_of(size)
	_draw_top(k)
	_draw_hint(k)
	_draw_charge(k)

static func group(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = ","+s.right(3)+out
		s = s.left(s.length()-3)
	return ("-" if n < 0 else "")+s+out

func _finds() -> Vector2i:
	if _finds_hud == null: return Vector2i.ZERO
	return Vector2i(int(_finds_hud.get("_got")),int(_finds_hud.get("_of")))

## The finds chip's width, 0 with no finds.
func _finds_w(k: float) -> float:
	var f := _finds()
	if f.y <= 0: return 0.0
	return (10.0+19.0+7.0+5.0+20.0)*k+Kit.text_w(Kit.NUM,str(f.x),19.0,k)+Kit.text_w(Kit.NUM,"/ %d" % f.y,12.5,k)

## The money chip's left edge at rest: beside the finds chip (8 apart).
func _money_x(k: float) -> float:
	var fw := _finds_w(k)
	return 28.0*k+(fw+8.0*k if fw > 0.0 else 0.0)

func _draw_top(k: float) -> void:
	var a := _a*_top_a
	if a <= 0.003: return
	var cy := 40.0*k
	var f := _finds()
	if f.y > 0:
		var x := 28.0*k
		var r := Rect2(x,26.0*k,_finds_w(k),28.0*k)
		var pop := float(_finds_hud.get("_pop"))
		var kick := 1.0-smoothstep(0.0,0.3,pop)
		Kit.plate(self,r,k,false,a)
		draw_finds_mark(self,Vector2(x+19.5*k,cy),19.0*k,a,1.0-smoothstep(0.0,0.6,pop))
		var wn := Kit.text_w(Kit.NUM,str(f.x),19.0,k)
		Kit.text(self,Kit.NUM,str(f.x),Vector2(x+36.0*k,cy),19.0*(1.0+0.16*kick),k,0.0,Kit.GOLD.lerp(KICK,kick),0.0,a)
		Kit.text(self,Kit.NUM,"/ %d" % f.y,Vector2(x+41.0*k+wn,cy),12.5,k,0.0,Kit.PALE,0.0,a)
	_draw_money(k,a)
	# Under the chips: the region entered, then a find's name.
	var y := 62.0*k
	var caption: Label = game.get("_region_caption")
	if caption != null and caption.modulate.a > 0.003 and not caption.text.is_empty():
		var ra := smoothstep(0.0,1.0,caption.modulate.a)*a
		Kit.chip(self,[Kit.part(caption.text.to_upper(),Kit.MED,11.5,0.24,Kit.CREAM)],Vector2(28.0*k-6.0*k*(1.0-ra),y),k,24.0,14.0,20.0,false,ra)
		y += 30.0*k
	if _finds_hud != null:
		var title := str(_finds_hud.get("_name"))
		var age := float(_finds_hud.get("_pop"))
		var fa := smoothstep(0.0,0.15,age)*(1.0-smoothstep(3.4,4.1,age))*a
		if not title.is_empty() and fa > 0.003:
			Kit.chip(self,[Kit.part(title,Kit.MED,12.0,0.08,Kit.TOAST)],Vector2(28.0*k,y),k,24.0,12.0,20.0,false,fa)

func _draw_money(k: float, top_a: float) -> void:
	var a := _money_a*top_a
	if a <= 0.003: return
	var x := _money_x(k)-10.0*k*(1.0-_money_a)
	var cy := 40.0*k
	var total := group(_shown)
	var kick := 1.0-smoothstep(0.0,0.2,_kick_age)
	var flash := 1.0-smoothstep(0.0,0.3,_kick_age)
	var plus_a := smoothstep(0.0,0.1,_plus_age)*(1.0-smoothstep(PLUS_FOR.x,PLUS_FOR.y,_plus_age)) if _plus > 0 else 0.0
	var plus := "+"+group(_plus)
	var wt := Kit.text_w(Kit.NUM,total,19.0,k)
	var wp := (7.0*k+Kit.text_w(Kit.NUM,plus,13.0,k))*plus_a
	var earned := opt("earned") == "on"
	var earn := ""
	var we := 0.0
	if earned:
		var book: Object = game.get("book")
		var flight: Dictionary = book.get("flight")
		earn = "+"+group(maxi(int(flight.get("earned",0))-_pending,0))
		we = (6.0+4.0+1.0+9.0+5.0)*k+Kit.text_w(Kit.MED,"FLIGHT",9.5,k,0.18)+Kit.text_w(Kit.NUM,earn,13.0,k)
	Kit.plate(self,Rect2(x,26.0*k,(9.0+20.0+6.0+20.0)*k+wt+wp+we,28.0*k),k,false,a)
	draw_coin(self,Vector2(x+19.0*k,cy),20.0*k,a,flash)
	var tx := x+35.0*k
	Kit.text(self,Kit.NUM,total,Vector2(tx,cy),19.0*(1.0+0.16*kick),k,0.0,Kit.GOLD.lerp(KICK,kick),0.0,a)
	tx += wt
	if plus_a > 0.003: Kit.text(self,Kit.NUM,plus,Vector2(tx+7.0*k*plus_a,cy),13.0,k,0.0,Kit.CREAM,0.0,a*smoothstep(0.5,1.0,plus_a))
	tx += wp
	if earned:
		Kit.slant(self,Rect2(tx+10.0*k,cy-6.0*k,1.0*k,12.0*k),Color(Kit.CREAM,Kit.CELL_OFF_A*a))
		var wf := Kit.text(self,Kit.MED,"FLIGHT",Vector2(tx+20.0*k,cy),9.5,k,0.18,Kit.PALE,0.0,a)
		Kit.text(self,Kit.NUM,earn,Vector2(tx+25.0*k+wf,cy),13.0,k,0.0,Kit.CREAM,0.0,a)

## The hint's words for the device last used: [keys, pad, word].
const HINTS := [["A D","","bank"],["W S","","pitch"],["","L stick","steer"],["Space","RT","boost"],["Shift","LT","brake"],["Esc","Start","menu"]]
## The stop cue (the game's `_stop_note` words it): its word, then prompts.
const STOPPED := [["Space","RT","boost to roll"],["Shift","LT","again to back up"]]
const BACKING := [["Shift","LT","let go to stop"]]

func _draw_hint(k: float) -> void:
	var at := Vector2(28.0*k,size.y-50.0*k)
	if _hint_a > 0.003: Kit.prompts(self,Kit.pick(HINTS),at,k,false,true,_hint_a*_a)
	var a := _stop_a*_a
	if a <= 0.003: return
	# Over the hint while it shows, in its place once it has gone.
	at.y -= 30.0*k*smoothstep(0.0,1.0,_hint_a)
	var word := "STOPPED"
	var pairs := Kit.pick(STOPPED)
	if _stop_text.begins_with("backing"):
		word = "BACKING UP"
		pairs = Kit.pick(BACKING)
	elif not _stop_text.begins_with("stopped"):
		word = _stop_text.to_upper()
		pairs = []
	var parts := [Kit.part(word,Kit.MED,11.5,0.2,Kit.TOAST)]
	for pair: Array in pairs:
		parts.append(Kit.part(str(pair[0]),Kit.NUM,12.5,0.06,Kit.CREAM,18.0))
		parts.append(Kit.part(str(pair[1]),Kit.MED,12.0,0.08,Kit.PALE,6.0))
	Kit.chip(self,parts,at,k,24.0,12.0,20.0,false,a)

func _draw_charge(k: float) -> void:
	var a := _a
	var speed_a := _spd_a
	if not _charge_on and speed_a <= 0.003: return
	# Right to left from the plate's right pad: roll mark, cells, chevrons, then the speed.
	var bottom := size.y-26.0*k
	var cy := bottom-13.0*k
	var right := size.x-28.0*k
	var charge_w := (14.0+6.0+93.0+7.0+15.0)*k if _charge_on else 0.0
	var kmh_w := Kit.text_w(Kit.MED,"KM/H",9.5,k,0.18)
	var speed_w := (30.0+4.0+(23.0 if _charge_on else 0.0))*k+kmh_w
	var open := smoothstep(0.0,1.0,speed_a)
	var w := (20.0+12.0)*k+charge_w+speed_w*open
	Kit.plate(self,Rect2(right-w,bottom-26.0*k,w,26.0*k),k,true,a)
	var x := right-12.0*k-charge_w
	var ink := a*smoothstep(0.75,1.0,speed_a)
	if ink > 0.003:
		var sx := x-speed_w
		Kit.text(self,Kit.NUM,str(roundi(_kmh)),Vector2(sx+30.0*k,cy),17.0,k,0.0,Kit.GOLD if _top else Kit.CREAM,1.0,ink)
		Kit.text(self,Kit.MED,"KM/H",Vector2(sx+34.0*k,cy+1.0*k),9.5,k,0.18,Kit.PALE,0.0,ink)
		if _charge_on: Kit.slant(self,Rect2(x-12.0*k,cy-6.0*k,1.0*k,12.0*k),Color(Kit.CREAM,Kit.CELL_OFF_A*ink))
	if not _charge_on: return
	var ready := _meter >= 0.999 and not _hot
	var pulse := 0.5+0.5*sin(_clock*25.0)
	# The chevrons: lit while there is any charge to hold a surge on.
	var s_col := Color(Kit.CREAM,MARK_OFF_A) if _meter <= 0.002 else (HOT if _surge or _hot else Kit.GOLD)
	draw_surge(self,Vector2(x+7.0*k,cy),14.0*k*(1.08+0.1*pulse if _surge else 1.0),Color(s_col,s_col.a*a))
	# The cells: half a second of surge each, drained from the right.
	var cells := Rect2(x+20.0*k,cy-2.5*k,93.0*k,5.0*k)
	var cell_col := HOT if _hot else (SURGING if _surge else (Kit.GOLD if ready else Kit.CELL))
	if _hot: _glow(cells,Color(1.0,0.59,0.24,0.9*a),(7.0+4.0*pulse)*k)
	elif _surge: _glow(cells,Color(1.0,0.84,0.42,0.7*a),7.0*k)
	elif ready: _glow(cells,Color(1.0,0.84,0.42,0.75*a),8.0*k)
	elif _rise > 0.0: _glow(cells,Color(1.0,0.84,0.42,0.55*a*minf(_rise/0.1,1.0)),7.0*k)
	for i in 5:
		var cell := Rect2(cells.position.x+19.0*k*i,cells.position.y,17.0*k,cells.size.y)
		Kit.slant(self,cell,Color(Kit.CREAM,Kit.CELL_OFF_A*a))
		var fill := clampf(_meter*5.0-i,0.0,1.0)
		if fill > 0.0: Kit.slant(self,Rect2(cell.position,Vector2(cell.size.x*fill,cell.size.y)),Color(cell_col,a))
	# The roll mark: lit only on a full meter, spun and spent by the surge roll.
	var r_col := HOT if _hot else (Kit.GOLD if ready else Color(Kit.CREAM,MARK_OFF_A))
	var spin := TAU*2.0*(1.0-pow(1.0-clampf(_roll_age/0.62,0.0,1.0),2.0)) if _hot else 0.0
	var breath := 1.0+0.08*(0.5+0.5*sin(_clock*3.4)) if ready else 1.0
	draw_roll(self,Vector2(right-12.0*k-7.5*k,cy),15.0*k*breath,Color(r_col,r_col.a*a),spin,ready or _hot)
	if not hints_on(): return
	# The key plates over the plate: a key's first chance, and while it is held.
	var pad := Pad.using_pad()
	var at := Vector2(right,bottom-34.0*k-22.0*k)
	var z_held := _hot and _roll_age < 0.5
	var z_a := maxf(_shown_for(_z_age),smoothstep(0.0,0.05,_roll_age)*(1.0-smoothstep(0.5,0.75,_roll_age)))*a
	var b_a := maxf(_shown_for(_b_age),_b_held)*a
	if z_a > 0.003:
		Kit.key_plate(self,"A" if pad else "Z","ROLL",at,k,z_held,z_a)
		at.y -= 28.0*k*smoothstep(0.0,1.0,z_a/maxf(a,0.001))
	if b_a > 0.003: Kit.key_plate(self,"X" if pad else "B","SURGE",at,k,_surge,b_a)

func _shown_for(age: float) -> float:
	return smoothstep(0.0,0.15,age)*(1.0-smoothstep(KEY_HOLD,KEY_HOLD+0.4,age))

## A soft light round `r` (CSS box-shadow 0 0 blur): a few faint grown boxes.
func _glow(r: Rect2, col: Color, blur: float) -> void:
	if col.a <= 0.003: return
	for i in 4:
		var g := blur*(i+1)/4.0
		draw_rect(Rect2(r.position-Vector2(g,g*0.7),r.size+Vector2(g,g*0.7)*2.0),Color(col,col.a*0.11))

# --- The marks: one function each, for the glyph set to take over -------------------------

## The money's coin, `d` across at `c`: a gold disc with a rim (the glyph
## set's `coin` goes here). `flash` 0..1 lights it as a coin lands.
static func draw_coin(ci: CanvasItem, c: Vector2, d: float, a := 1.0, flash := 0.0) -> void:
	var r := d*0.5
	if flash > 0.003:
		for i in 3: ci.draw_circle(c,r+d*0.1*(i+1),Color(1.0,0.84,0.42,0.22*flash*a),true,-1.0,true)
	ci.draw_circle(c+Vector2(0.0,d*0.05),r*0.92,Color(Kit.NIGHT,0.5*a),true,-1.0,true)
	ci.draw_circle(c,r*0.9,Color(Color("b9812a").lerp(Kit.GOLD,flash*0.5),a),true,-1.0,true)
	ci.draw_circle(c,r*0.68,Color(Kit.GOLD.lerp(KICK,flash),a),true,-1.0,true)
	ci.draw_arc(c,r*0.5,PI*1.05,PI*1.6,8,Color(KICK,0.8*a),maxf(d*0.07,1.0),true)

## The finds' mark, `d` across at `c`: today's `relic` glyph. `gleam` 0..1
## lights it as a find is made.
static func draw_finds_mark(ci: CanvasItem, c: Vector2, d: float, a := 1.0, gleam := 0.0) -> void:
	var px := maxf(roundf(d/2.0)*2.0,8.0)
	var side := px*Glyphs.BOX/24.0
	var r := Rect2(c-Vector2.ONE*side*0.5,Vector2.ONE*side)
	var tex := Glyphs.texture("relic","icon",px)
	if tex != null: ci.draw_texture_rect(tex,r,false,Color(1,1,1,a))
	if gleam > 0.003:
		var lit := Glyphs.texture("relic","lit",px)
		if lit != null: ci.draw_texture_rect(lit,r,false,Color(1,1,1,a*gleam))

## A stroked path on the mock-up's 16-unit box, `d` across about `c`, round
## at its ends and corners.
static func _stroke(ci: CanvasItem, pts: PackedVector2Array, c: Vector2, d: float, col: Color, width := 1.9) -> void:
	var u := d/16.0
	var w := maxf(width*u,1.0)
	var at := PackedVector2Array()
	for p in pts: at.append(c+(p-Vector2(8.0,8.0))*u)
	ci.draw_polyline(at,col,w,true)
	for p in at: ci.draw_circle(p,w*0.5,col,true,-1.0,true)

## The surge's chevrons, `d` across at `c` (the glyph set's `surge` swirl
## goes here).
static func draw_surge(ci: CanvasItem, c: Vector2, d: float, col: Color) -> void:
	if col.a <= 0.003: return
	_stroke(ci,PackedVector2Array([Vector2(3,3),Vector2(8,8),Vector2(3,13)]),c,d,col)
	_stroke(ci,PackedVector2Array([Vector2(8,3),Vector2(13,8),Vector2(8,13)]),c,d,col)

## The roll mark, `d` across at `c`, turned `spin` radians: the mock-up's
## own drawing (an open ring with an arrow head; the glyph set's `roll` goes
## here). `lit` puts a little light under it.
static func draw_roll(ci: CanvasItem, c: Vector2, d: float, col: Color, spin := 0.0, lit := false) -> void:
	if col.a <= 0.003: return
	var u := d/16.0
	var w := maxf(1.9*u,1.0)
	ci.draw_set_transform(c,spin,Vector2.ONE)
	if lit: ci.draw_arc(Vector2.ZERO,5.0*u,deg_to_rad(-30.2),deg_to_rad(-360.0),24,Color(1.0,0.84,0.42,0.3*col.a),w*2.6,true)
	ci.draw_arc(Vector2.ZERO,5.0*u,deg_to_rad(-30.2),deg_to_rad(-360.0),24,col,w,true)
	ci.draw_circle(Vector2(5.0*u,0.0),w*0.5,col,true,-1.0,true)
	_stroke(ci,PackedVector2Array([Vector2(12.9,2.1),Vector2(12.6,5.8),Vector2(9.0,5.3)]),Vector2.ZERO,d,col)
	ci.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
