extends Control
## The money in flight, kept quiet: the balance small in the top right corner
## (the landing summary's numerals and inks), a "+N" under it fading as money
## comes in. And, until a shop has been found, a pointer to the first one
## (ShopSites `first_shop`: the start's square's, else the nearest round it): an arrow
## turned toward it off the view's heading, its distance, and what a shop is
## for. Hidden under the title, an overlay (the shop, the logbook) and while
## the game has no book.
##
## The game (studies/endless_flight.gd) adds one to its HUD layer:
## `layer.add_child(MoneyHud.new(self))`; it reads `game` each frame.

const Card = preload("res://scripts/endless/landing_summary.gd")
const Money = preload("res://scripts/endless/money.gd")

## How long a "+N" shows (s), and how long the balance stays bright after.
const GAIN_HOLD := 2.6
## The corner's margin and the numerals' size at 900 px tall.
const MARGIN := Vector2(36.0, 30.0)
const PX := 30.0
## The pointer's place (fraction of the screen down) and its words.
const POINT_Y := 0.075
const POINT_WORDS := "a shop"
const POINT_SUB := "land on its strip to spend your money"

var game: Node
var _shown := -1
var _gain := 0
var _gain_t := 0.0
var _a := 0.0
## The first shop's site ({} while none is known).
var _site: Dictionary = {}

func _init(host: Node = null) -> void:
	game = host
	name = "MoneyHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	var screen := get_viewport_rect().size
	if size != screen:
		position = Vector2.ZERO
		size = screen
	var book: RefCounted = game.get("book") if game != null else null
	var up := book != null and game.get("stage") == null and game.get("overlay") == null
	_a = clampf(_a+delta/(0.3 if up else -0.15),0.0,1.0)
	visible = _a > 0.0
	if book == null: return
	var m := int(book.money)
	if _shown < 0: _shown = m
	if m > _shown:
		_gain = (_gain if _gain_t > 0.0 else 0)+(m-_shown)
		_gain_t = GAIN_HOLD
	_shown = m
	_gain_t = maxf(_gain_t-delta,0.0)
	queue_redraw()

## Whether the pointer to the first shop shows: no shop found yet, and one
## known (ShopSites `first_shop`, looked for a little each frame).
func pointing() -> bool:
	var book: RefCounted = game.get("book") if game != null else null
	if book == null or game.get("shops") == null: return false
	for k: String in (book.found as Dictionary):
		if k.begins_with("shop/"): return false
	_site = game.shops.first_shop()
	return not _site.is_empty()

## The first shop's centre (null for none yet).
func target() -> Variant:
	return _site.get("centre") if pointing() else null

func _draw() -> void:
	var book: RefCounted = game.get("book") if game != null else null
	if book == null: return
	var s := size.y/900.0
	var a := _a
	var right := size.x-MARGIN.x*s
	var y := MARGIN.y*s+PX*s
	# The balance: dim at rest, bright while money comes in.
	var lit := clampf(_gain_t/0.6,0.0,1.0)
	var col := Color(Card.GOLD,a*lerpf(0.72,1.0,lit))
	var text := Money.money(int(book.money))
	Card.ink(self,Card.nums(true),text,Vector2(right,y),PX*s,col,6.0*s,1.0)
	var w := Card.nums(true).get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(PX*s)).x
	Card.ink(self,Card.words(14.0*s,0.08),"money",Vector2(right-w-12.0*s,y-2.0*s),14.0*s,Color(Card.GREY,a*0.85),4.0*s,1.0)
	if _gain_t > 0.0:
		var ga := a*clampf(_gain_t/0.8,0.0,1.0)
		var rise := (1.0-_gain_t/GAIN_HOLD)*10.0*s
		Card.ink(self,Card.nums(true),"+"+Money.money(_gain),Vector2(right,y+26.0*s-rise),20.0*s,Color(Card.GOLD,ga),5.0*s,1.0)
	if pointing(): _draw_pointer(s,a)

func _draw_pointer(s: float, a: float) -> void:
	var plane: RefCounted = game.get("plane")
	var cam := get_viewport().get_camera_3d()
	if plane == null or cam == null: return
	var to: Vector3 = (_site.centre as Vector3)-(plane.position as Vector3)
	to.y = 0.0
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if to.length() < 1.0 or fwd.length() < 0.01: return
	var turn := fwd.normalized().signed_angle_to(to.normalized(),Vector3.UP)
	var d := to.length()
	var dist := ("%d m" % int(round(d/10.0)*10.0)) if d < 1000.0 else ("%.1f km" % (d/1000.0))
	var mid := Vector2(size.x*0.5,size.y*POINT_Y)
	var label := "%s  ·  %s" % [POINT_WORDS,dist]
	var lw := Card.words(20.0*s,0.06).get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(20.0*s)).x
	# The arrow, left of the words: up is straight ahead, turned as the shop lies.
	var at := mid+Vector2(-lw*0.5-22.0*s,-7.0*s)
	var r := 11.0*s
	var rot := -turn
	var pts := PackedVector2Array([Vector2(0,-r),Vector2(r*0.72,r*0.7),Vector2(0,r*0.3),Vector2(-r*0.72,r*0.7)])
	for i in pts.size(): pts[i] = at+pts[i].rotated(rot)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline,Color(Card.KEY,0.7*a),4.0*s,true)
	draw_colored_polygon(pts,Color(Card.GOLD,a))
	Card.ink(self,Card.words(20.0*s,0.06),label,mid+Vector2(-lw*0.5,0.0),20.0*s,Color(Card.CREAM,a),5.0*s,0.0)
	Card.ink(self,Card.words(14.0*s,0.04),POINT_SUB,mid+Vector2(0.0,22.0*s),14.0*s,Color(Card.GREY,a*0.9),4.0*s,0.5)
