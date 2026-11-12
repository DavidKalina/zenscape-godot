extends "res://scripts/endless/ui/menu_base.gd"
## The title (docs/design/ui/mock/Main.dc.html, its title screen): the
## game's name top left over a hairline with its gilt flag, and a small slip
## lower left with Start, Settings, Credits and Quit. It stands in for
## scripts/endless/main_menu.gd over the parked plane (studies/
## endless_flight.gd `_park_for_menu`; `--menus=old` keeps that one), and
## keeps its contract with the stage (scripts/endless/menu_stage.gd):
## `present` shows it under a lifting veil, `leave` fades it and stops its
## input, `picked` says "start" or "quit".

signal picked(what: String)

const CreditsPage = preload("res://scripts/endless/ui/credits_page.gd")

## The dark veil the game opens under, lifting over VEIL s (the old title's).
const VEIL := 1.4
const VEIL_COL := Color("0b0e12")
const LEAVE := 0.35

var _veil := 0.0
var _fade := 1.0
var _leaving := false

func _init(game: Node = null) -> void:
	super()
	host = game
	name = "TitleMenu"
	rows = [{"id":"start","label":"Start"},{"id":"settings","label":"Settings"},
		{"id":"credits","label":"Credits"},{"id":"quit","label":"Quit","gap":8.0}]
	active = false

## Comes in: the veil lifting, the slip arriving.
func present() -> void:
	show()
	active = true
	_leaving = false
	_fade = 1.0
	_veil = 1.0
	arrive(0)

## Goes: faded over LEAVE s, then hidden; no input from now.
func leave() -> void:
	active = false
	_leaving = true

## The row picked now (0 is Start), as the old title answered.
func selected() -> int:
	return sel

func tick(delta: float) -> void:
	if _veil > 0.0:
		_veil = maxf(0.0,_veil-delta/VEIL)
		queue_redraw()
	if _leaving:
		_fade = maxf(0.0,_fade-delta/LEAVE)
		queue_redraw()
		if _fade <= 0.0:
			_leaving = false
			hide()

func pick(i: int) -> void:
	match str(rows[i].id):
		"start": picked.emit("start")
		"settings": open_settings()
		"credits": open_page(CreditsPage.new())
		"quit": picked.emit("quit")

func _draw() -> void:
	var s := k()
	# A page stands where the name does (the mock-up's pages show no name).
	if page == null:
		_draw_name(s,_fade)
		var arrival := Kit.slip_in(age)
		var a := arrival.y*_fade
		var h := (24.0+rows_height(32.0))*s
		var slip := Rect2(72.0*s-arrival.x*s,size.y-78.0*s-h,204.0*s,h)
		Kit.slip(self,slip,s,a)
		draw_rows(slip,slip.position.y+12.0*s,s,32.0,16.0,36.0,a)
		draw_footer([P_SELECT,P_CHOOSE],s,_fade)
	draw_toast(s)
	if _veil > 0.0: draw_rect(Rect2(Vector2.ZERO,size),Color(VEIL_COL,_veil))

## The name, 46 px Newsreader tracked wide, over a 2 px hairline that stops
## short of its end, where the gilt flag stands.
func _draw_name(s: float, a: float) -> void:
	var at := Vector2(72.0,86.0)*s
	var w := Kit.text_w(Kit.SERIF,GAME_NAME,46.0,s,0.2)-roundf(46.0*s*0.2)
	# The name's two shadows: a close one, and a wide soft one (CSS 0 4px 24px).
	for i in 8:
		var off := Vector2.from_angle(TAU*float(i)/8.0)*7.0*s+Vector2(0.0,4.0*s)
		Kit.text(self,Kit.SERIF,GAME_NAME,at+off,46.0,s,0.2,Color(Kit.NIGHT,0.05),0.0,a)
	Kit.text(self,Kit.SERIF,GAME_NAME,at+Vector2(0.0,maxf(1.0,roundf(s))),46.0,s,0.2,Color(Kit.NIGHT,0.6),0.0,a)
	Kit.text(self,Kit.SERIF,GAME_NAME,at,46.0,s,0.2,Kit.CREAM,0.0,a)
	var line_y := 121.0*s
	draw_rect(Rect2(74.0*s,roundf(line_y-s),w-20.0*s,maxf(roundf(2.0*s),1.0)).grow(1.0),Color(Kit.NIGHT,0.18*a))
	Kit.hair(self,Vector2(74.0*s,line_y),72.0*s+w-18.0*s,s,Color(Kit.CREAM,a),2.0)
	Kit.slant(self,Rect2(72.0*s+w-11.0*s,115.0*s,5.0*s,11.0*s),Color(Kit.GOLD,a))
