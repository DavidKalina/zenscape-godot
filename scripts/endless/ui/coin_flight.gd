extends Control
## A bank's coins on their way from the chain HUD's pennant to the corner
## HUD's money chip (docs/design/ui/mock/Hud.dc.html: "Coins fly", "Total
## ticks"; spec-flight-ui.md). It joins the two HUDs and draws only the coins
## in the air:
##
## - the chain plate (near_miss_hud_plate.gd) says `banked(money, points)` as
##   its pennant's money row shows. The coins `claim` that pay from the corner
##   HUD (flight_hud.gd), so its total waits for them;
## - COINS_AFTER s later (the plate's: the mock-up's 1.9 s after the bank) they
##   leave the row's seal GAP s apart, one a unit of money up to MOST (a larger
##   pay is shared among MOST coins), out to the left edge of the view and up
##   it to the chip's coin, FLIES s each;
## - each one landing is the HUD's `land_coin`: the total ticks by that
##   coin's share, kicks, and the "+N" shows beside it.
##
## A bank cut short before its money row shows (a new pass, a lost line, a
## landing) sends no coins: the corner HUD ticks that pay by itself, as it does
## with no coin flight. The coins stand still while the tree is paused and
## show as much as the corner HUD's top chips do (nothing under a page).
##
## `studies/endless_flight.gd` makes one with `make(layer, plate, hud)` when
## the new chain HUD and the new corner HUD are both up.

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
const FlightHud = preload("res://scripts/endless/ui/flight_hud.gd")
const Plate = preload("res://scripts/endless/near_miss_hud_plate.gd")

## The most coins a bank sends, the time between two leaving and how long one
## flies (s): Hud.dc.html's 6, 0.09 and 0.55.
const MOST := FlightHud.COINS_MOST
const GAP := FlightHud.LAND_GAP
const FLIES := 0.55
## A coin's width (M, the mock-up's px in its 1280 x 800 frame).
const SIZE := 22.0
## The path's bend: this far right of the chip's coin (M) and this much of the
## way up from the pennant to the chip, so a coin goes out to the left first
## and then climbs (the mock-up's curve from 404,466 by 170,356 to 157,40).
const BEND_X := 13.0
const BEND_UP := 0.258
const GLOW := Color(1.0,0.784,0.353)

var plate: Control
var hud: Control
## The coins sent and not yet landed: {wait (s until it leaves), u (0..1 of
## its flight), amount (the money it carries), from (the seal, screen px)}.
var _coins: Array = []

## A coin flight between `plate` and `hud`, on `layer` over both.
static func make(layer: Node, plate_hud: Control, flight_hud: Control) -> Control:
	var flight: Control = load("res://scripts/endless/ui/coin_flight.gd").new()
	flight.set("plate",plate_hud)
	flight.set("hud",flight_hud)
	flight.name = "CoinFlight"
	layer.add_child(flight)
	return flight

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if plate == null or hud == null: return
	hud.set("coin_flight",true)
	plate.connect("banked",send)

func _exit_tree() -> void:
	if hud != null and is_instance_valid(hud): hud.set("coin_flight",false)

## How many coins are waiting or in the air.
func count() -> int:
	return _coins.size()

## Each coin in the air: {u, at (screen px), amount}.
func flying() -> Array:
	var out: Array = []
	for coin: Dictionary in _coins:
		if float(coin.wait) <= 0.0: out.append({"u":float(coin.u),"at":_at(coin),"amount":int(coin.amount)})
	return out

## A bank's pay of `money` to the chip: the plate's `banked`. Returns how many
## coins it sent (0 when the bank's money row never showed, or when the corner
## HUD has none of that pay left to tick).
func send(money: int, _points := 0) -> int:
	if money <= 0 or plate == null or hud == null: return 0
	if float(plate.call("bank_age")) < Plate.PAY_AT: return 0
	var took: int = hud.call("claim",money)
	if took <= 0: return 0
	var n := mini(took,MOST)
	var from: Vector2 = plate.call("pennant_money_anchor")
	for i in n:
		@warning_ignore("integer_division")
		var amount := took/n+(1 if i < took%n else 0)
		_coins.append({"wait":Plate.COINS_AFTER+GAP*i,"u":0.0,"amount":amount,"from":from})
	return n

func _process(delta: float) -> void:
	if _coins.is_empty() or hud == null or not is_instance_valid(hud):
		if visible: visible = false
		return
	if not get_tree().paused: _step(minf(delta,0.1))
	var on := not _coins.is_empty() and float(hud.call("coin_alpha")) > 0.003
	if visible != on: visible = on
	if visible: queue_redraw()

func _step(dt: float) -> void:
	# The seal moves with the plane: a coin starts from where it is now, for
	# as long as the pennant is up.
	var seal := Vector2.INF
	if is_instance_valid(plate) and plate.visible and float(plate.call("bank_age")) >= 0.0: seal = plate.call("pennant_money_anchor")
	var i := 0
	while i < _coins.size():
		var coin: Dictionary = _coins[i]
		if seal != Vector2.INF: coin.from = seal
		var left := dt
		if float(coin.wait) > 0.0:
			left = dt-float(coin.wait)
			coin.wait = maxf(float(coin.wait)-dt,0.0)
		if left > 0.0: coin.u = float(coin.u)+left/FLIES
		if float(coin.u) >= 1.0:
			_coins.remove_at(i)
			hud.call("land_coin",int(coin.amount))
		else: i += 1

## Where `coin` is on its path.
func _at(coin: Dictionary) -> Vector2:
	var k := Kit.scale_of(size)
	var from: Vector2 = coin.from
	var to: Vector2 = hud.call("money_anchor")
	var via := Vector2(minf(to.x+BEND_X*k,from.x),lerpf(from.y,to.y,BEND_UP))
	var e := smoothstep(0.0,1.0,float(coin.u))
	return from*(1.0-e)*(1.0-e)+via*2.0*e*(1.0-e)+to*e*e

func _draw() -> void:
	if hud == null or not is_instance_valid(hud): return
	var top := float(hud.call("coin_alpha"))
	if top <= 0.003: return
	var k := Kit.scale_of(size)
	for coin: Dictionary in _coins:
		var u := float(coin.u)
		if float(coin.wait) > 0.0 or u <= 0.0: continue
		var a := smoothstep(0.0,0.12,u)*(1.0-smoothstep(0.9,1.0,u))*top
		if a <= 0.003: continue
		var d := SIZE*k*(0.9+0.35*sin(PI*u))
		var at := _at(coin)
		# Its light (the mock-up's 5 px gold shadow), then the chip's own coin
		# (the `coin` glyph, one texture at the coin's size at rest).
		for g in 3: draw_circle(at,d*0.5+5.0*k*(g+1)/3.0,Color(GLOW,0.24*a),true,-1.0,true)
		FlightHud.draw_coin(self,at,d,a,0.0,SIZE*k)
