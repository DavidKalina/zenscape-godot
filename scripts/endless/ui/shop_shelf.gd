extends Control
## The shop's shelf (shop_view.gd owns it): a low band along the screen's
## foot with the stock as cards in a row, the chosen one centred, lifted and
## larger, the plane above it wearing the choice. Over the shelf, the chosen
## item's name and what Enter does; in its head, the sections and the money.
## Everything is drawn here; the view holds the choice and the keys.
##
## `view.rows` is [{id, slot, s (selection 0..1), pulse, ...}], `view.chosen`
## the index in it.

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
const FlightHud = preload("res://scripts/endless/ui/flight_hud.gd")
const ShopStock = preload("res://scripts/endless/shop_stock.gd")
const Pad = preload("res://scripts/pad.gd")

const LOST := Color("ff8a6b")
const DIM := Color(0.96,0.95,0.92,0.55)
const CARD := Color("1d2026")

## Sizes in the kit's mock px (1280x800), times `k`.
const BAND := 256.0
const CARD_W := 132.0
const CARD_H := 168.0
const PITCH := 148.0
const HEAD_Y := 28.0
const CARD_Y := 140.0
const HINT_Y := 242.0
const SEL_SCALE := 1.1
const REST_SCALE := 0.9

var view: Control
var _k := 1.0
var _band_top := 0.0
## Eased: how far the band has risen, the sideways scroll (in cards), the
## money shown.
var _rise := 0.0
var _scroll := 0.0
var _slot_shown := ""
var _money_shown := -1.0
var _t := 0.0
## Hit areas from the last draw, for the mouse: [{rect, index}] and [{rect, slot}].
var _hits: Array = []
var _tab_hits: Array = []
var shake := 0.0
var _plane_pts := {}

func _ready() -> void:
	name = "ShopShelf"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The cards in `slot`, as indices into view.rows.
func _in_slot(slot: String) -> Array:
	var out: Array = []
	for k in view.rows.size():
		if view.rows[k].slot == slot: out.append(k)
	return out

func _process(delta: float) -> void:
	if view == null or view.rows.is_empty(): return
	_t += delta
	var screen := get_viewport_rect().size
	if size != screen:
		position = Vector2.ZERO
		size = screen
	var ease_by := 1.0-exp(-13.0*delta)
	_rise = minf(1.0,_rise+delta/0.42)
	var cur: Dictionary = view.rows[view.chosen]
	var mine := _in_slot(cur.slot)
	var at := float(mine.find(view.chosen))
	if _slot_shown != cur.slot:
		_slot_shown = cur.slot
		_scroll = at
	_scroll += (at-_scroll)*(1.0-exp(-10.0*delta))
	for k in view.rows.size():
		var r: Dictionary = view.rows[k]
		r.s += ((1.0 if k == view.chosen else 0.0)-r.s)*ease_by
		r.pulse = maxf(0.0,r.pulse-delta*1.7)
	var money := float(view.book.money)
	if _money_shown < 0.0: _money_shown = money
	_money_shown += (money-_money_shown)*(1.0-exp(-9.0*delta))
	if absf(money-_money_shown) < 0.6: _money_shown = money
	shake = maxf(0.0,shake-delta*3.2)
	queue_redraw()

func _draw() -> void:
	if view == null or view.rows.is_empty(): return
	var screen := size
	_k = Kit.scale_of(screen)
	var k := _k
	var rise := Kit.ease_out(_rise)
	var band_h := BAND*k
	_band_top = screen.y-band_h*rise
	_hits.clear()
	_tab_hits.clear()
	var cur: Dictionary = view.rows[view.chosen]
	var item := ShopStock.item(cur.id)

	# A scrim so the caption reads on any sky, then the band.
	var scrim_h := 190.0*k
	var clear := Color(0,0,0,0)
	var dark := Color(0.03,0.035,0.05,0.5*rise)
	draw_polygon(PackedVector2Array([Vector2(0,_band_top-scrim_h),Vector2(screen.x,_band_top-scrim_h),
		Vector2(screen.x,_band_top+2),Vector2(0,_band_top+2)]),PackedColorArray([clear,clear,dark,dark]))
	draw_rect(Rect2(0,_band_top,screen.x,band_h+2),Kit.PLATE)
	draw_rect(Rect2(0,_band_top,screen.x,2.0*k),Color(Kit.GOLD,0.5))

	_draw_head(screen,k)
	_draw_caption(screen,k,cur,item)
	# The cards: the current section's, the chosen one drawn last (on top).
	var mine := _in_slot(cur.slot)
	var cx := screen.x*0.5
	var cy := _band_top+CARD_Y*k
	var order: Array = []
	for n in mine.size(): order.append(n)
	order.sort_custom(func(a: int, b: int) -> bool:
		return absf(float(a)-_scroll) > absf(float(b)-_scroll))
	for n: int in order:
		var off := (float(n)-_scroll)*PITCH*k
		if absf(off) > screen.x*0.5+CARD_W*k: continue
		_draw_card(view.rows[mine[n]],mine[n],Vector2(cx+off,cy),k,absf(float(n)-_scroll))
	# Edges fade into the band.
	var fade := 120.0*k
	var c0 := Color(Kit.PLATE,0.95)
	var c1 := Color(Kit.PLATE,0.0)
	var fy0 := _band_top+46.0*k
	var fy1 := _band_top+(HINT_Y-10.0)*k
	draw_polygon(PackedVector2Array([Vector2(0,fy0),Vector2(fade,fy0),Vector2(fade,fy1),Vector2(0,fy1)]),PackedColorArray([c0,c1,c1,c0]))
	draw_polygon(PackedVector2Array([Vector2(screen.x-fade,fy0),Vector2(screen.x,fy0),Vector2(screen.x,fy1),Vector2(screen.x-fade,fy1)]),PackedColorArray([c1,c0,c0,c1]))
	# The place in the section.
	var arrow_y := cy
	if mine.size() > 1:
		var at := mine.find(view.chosen)
		var tint := Color(Kit.GOLD,0.6)
		if at > 0: Kit.text(self,Kit.NUM,"<",Vector2(28.0*k,arrow_y),30.0,k,0.0,tint,0.5)
		if at < mine.size()-1: Kit.text(self,Kit.NUM,">",Vector2(screen.x-28.0*k,arrow_y),30.0,k,0.0,tint,0.5)
	var hint := Pad.pick("A D choose   ·   Q E section   ·   Enter buy or wear   ·   Esc leave   ·   Space take off",
		"Stick choose   ·   LB RB section   ·   X buy or wear   ·   B leave   ·   A take off")
	Kit.text(self,Kit.MED,hint,Vector2(screen.x*0.5,_band_top+HINT_Y*k),12.5,k,0.04,DIM,0.5)

## The sections (with how many each holds) and the money.
func _draw_head(screen: Vector2, k: float) -> void:
	var cur_slot: String = view.rows[view.chosen].slot
	var x := 44.0*k
	var y := _band_top+HEAD_Y*k
	for slot: String in ShopStock.SLOTS:
		var label := String(ShopStock.SLOT_NAMES.get(slot,slot)).to_upper()
		var held := 0
		var all := 0
		for r: Dictionary in view.rows:
			if r.slot != slot: continue
			all += 1
			if ShopStock.has(view.book,r.id): held += 1
		var on := slot == cur_slot
		var col := Kit.CREAM if on else DIM
		var w := Kit.text(self,Kit.MED,label,Vector2(x,y),17.0,k,0.14,col)
		var w2 := Kit.text(self,Kit.NUM,"%d/%d" % [held,all],Vector2(x+w+9.0*k,y),13.0,k,0.04,Color(Kit.GOLD,0.9 if on else 0.4))
		var full := w+9.0*k+w2
		if on: draw_rect(Rect2(x,y+13.0*k,full,2.5*k),Kit.GOLD)
		_tab_hits.append({"rect":Rect2(x-6.0*k,y-16.0*k,full+12.0*k,38.0*k),"slot":slot})
		x += full+34.0*k
	# Money: the coin and the figure, to the right.
	var coin_d := 26.0*k
	var txt := "%d" % roundi(_money_shown)
	var px := 28.0
	var tw := Kit.text_w(Kit.NUM,txt,px,k,0.02)
	var rx := screen.x-44.0*k
	var plate := Rect2(rx-tw-coin_d-34.0*k,y-19.0*k,tw+coin_d+44.0*k,38.0*k)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1,1,1,0.07)
	sb.set_corner_radius_all(int(19.0*k))
	sb.border_color = Color(Kit.GOLD,0.4)
	sb.set_border_width_all(maxi(1,int(1.5*k)))
	draw_style_box(sb,plate)
	FlightHud.draw_coin(self,Vector2(plate.position.x+22.0*k,y),coin_d)
	Kit.text(self,Kit.NUM,txt,Vector2(rx,y),px,k,0.02,Kit.GOLD,1.0)

## Over the band: the chosen item's name, its rarity, and what the key does.
func _draw_caption(screen: Vector2, k: float, cur: Dictionary, item: Dictionary) -> void:
	var rare := ShopStock.rarity(item)
	var rc: Color = ShopStock.RARITY_COLOURS.get(rare,Kit.CREAM)
	# To the left, so the plane stays clear above the cards.
	var cx := 44.0*k
	var y := _band_top-92.0*k
	Kit.text(self,Kit.SERIF,String(item.get("name","")),Vector2(cx,y),46.0,k,0.01,Kit.CREAM,0.0)
	var kind := "PAINT" if cur.slot == "paint" else String(ShopStock.SLOT_NAMES.get(cur.slot,cur.slot)).trim_suffix("s").to_upper()
	Kit.text(self,Kit.MED,"%s %s" % [rare.to_upper(),kind],Vector2(cx,y+36.0*k),15.0,k,0.2,rc,0.0)
	var had: bool = ShopStock.has(view.book,cur.id)
	var worn: bool = ShopStock.worn(view.book,cur.slot) == cur.id
	var price := int(item.get("price",0))
	var money := int(view.book.money)
	var yy := y+66.0*k
	var key := Pad.pick("ENTER","X")
	if worn:
		Kit.text(self,Kit.MED,"ON YOUR PLANE",Vector2(cx,yy),15.0,k,0.2,Kit.GOLD,0.0)
	elif had:
		var parts := [Kit.part(key,Kit.NUM,15.0,0.06,Kit.GOLD,10.0),Kit.part("WEAR IT",Kit.MED,15.0,0.2,Kit.CREAM)]
		Kit.run(self,parts,Vector2(cx,yy),k)
	elif price <= money:
		var parts := [Kit.part(key,Kit.NUM,15.0,0.06,Kit.GOLD,10.0),Kit.part("BUY FOR",Kit.MED,15.0,0.2,Kit.CREAM,10.0),
			Kit.part("%d" % price,Kit.NUM,19.0,0.02,Kit.GOLD,8.0),Kit.room(18.0)]
		var w := Kit.run_w(parts,k)
		Kit.run(self,parts,Vector2(cx,yy),k)
		FlightHud.draw_coin(self,Vector2(cx+w-9.0*k,yy),18.0*k)
	else:
		var sx := sin(_t*60.0)*6.0*k*shake
		Kit.text(self,Kit.MED,"%d MORE TO BUY" % (price-money),Vector2(cx+sx,yy),15.0,k,0.2,LOST,0.0)

func _draw_card(r: Dictionary, index: int, c: Vector2, k: float, away: float) -> void:
	var item := ShopStock.item(r.id)
	var s: float = r.s
	var pop: float = r.pulse
	var scale := lerpf(REST_SCALE,SEL_SCALE,s)*(1.0+0.08*sin(pop*PI)*pop)
	var kc := k*scale
	var chosen: bool = index == view.chosen
	var had: bool = ShopStock.has(view.book,r.id)
	var worn: bool = ShopStock.worn(view.book,r.slot) == r.id
	var price := int(item.get("price",0))
	var can := had or price <= int(view.book.money)
	var rare := ShopStock.rarity(item)
	var rc: Color = ShopStock.RARITY_COLOURS.get(rare,Kit.PALE)
	var fade := clampf(1.3-away*0.2,0.35,1.0)
	var dim := 1.0 if can else 0.8
	var a := fade*(1.0 if chosen else 0.78)
	var lift := -10.0*k*s
	var sh := sin(_t*60.0)*7.0*k*shake*s
	var ctr := c+Vector2(sh,lift)
	var rect := Rect2(ctr-Vector2(CARD_W,CARD_H)*0.5*kc,Vector2(CARD_W,CARD_H)*kc)
	_hits.append({"rect":rect,"index":index})
	var rad := int(9.0*kc)

	# Glow behind the better ones and the chosen one.
	var glow := 0.0
	if rare == "legendary": glow = 0.28
	elif rare == "rare": glow = 0.14
	glow = maxf(glow*a,0.0)+0.18*s
	if glow > 0.01:
		var gc := rc if not chosen else Kit.GOLD.lerp(rc,0.4)
		for i in 4:
			var g := rect.grow((4.0+i*4.0)*kc)
			var sbg := StyleBoxFlat.new()
			sbg.bg_color = Color(gc,glow*0.22*(4-i)/4.0)
			sbg.set_corner_radius_all(int((12.0+i*4.0)*kc))
			draw_style_box(sbg,g)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CARD,0.96*a)
	sb.set_corner_radius_all(rad)
	var edge := (3.0 if chosen else 1.5)*kc
	sb.set_border_width_all(maxi(1,int(edge)))
	var line: Color = Kit.CREAM if chosen else rc.darkened(0.15)
	if chosen and rare != "common": line = Kit.CREAM.lerp(rc,0.45)
	sb.border_color = Color(line,a*(1.0 if chosen else 0.8))
	draw_style_box(sb,rect)

	# The preview, on a plate tinted by the item's own colour.
	var pv := Rect2(rect.position+Vector2(6,6)*kc,Vector2((CARD_W-12.0)*kc,104.0*kc))
	var cols := _colours(item)
	var tint := Color(0.2,0.23,0.27)
	if not cols.is_empty(): tint = tint.lerp(cols[0],0.2)
	var pb := StyleBoxFlat.new()
	pb.bg_color = Color(tint,a)
	pb.set_corner_radius_all(int(6.0*kc))
	draw_style_box(pb,pv)
	if r.slot == "paint": _draw_plane(pv,item,a*dim,kc)
	else: _draw_ribbon(pv,cols,a*dim,kc)
	# A rarity bar along the plate's foot.
	var bar := Rect2(pv.position.x,pv.end.y-4.0*kc,pv.size.x,4.0*kc)
	draw_rect(bar,Color(rc,a*(0.9 if rare != "common" else 0.45)))
	if not can: draw_rect(pv,Color(0.05,0.05,0.07,0.35*a))

	# Name and the state.
	var nx := rect.position.x+rect.size.x*0.5
	Kit.text(self,Kit.MED,String(item.get("name","")).to_upper(),Vector2(nx,rect.position.y+127.0*kc),14.0,kc,0.08,
		Color(Kit.CREAM,a*(1.0 if can else 0.8)),0.5)
	var by := rect.position.y+148.0*kc
	if worn:
		_badge(Vector2(nx,by),"WORN",Kit.GOLD,Color("2a1f08"),kc,a,true)
	elif had:
		_badge(Vector2(nx,by),"OWNED",Color(Kit.PALE,0.9),Color(Kit.PALE,0.0),kc,a,false)
	else:
		var txt := "%d" % price
		var tw := Kit.text_w(Kit.NUM,txt,16.0,kc,0.02)
		var d := 15.0*kc
		var total := d+6.0*kc+tw
		var x0 := nx-total*0.5
		FlightHud.draw_coin(self,Vector2(x0+d*0.5,by),d,a*dim)
		Kit.text(self,Kit.NUM,txt,Vector2(x0+d+6.0*kc,by),16.0,kc,0.02,Color(Kit.GOLD if can else LOST,a),0.0)
	# A buy: the ring that leaves the card.
	if pop > 0.0:
		var e := 1.0-pop
		var ring := rect.grow((6.0+46.0*e)*kc)
		var pr := StyleBoxFlat.new()
		pr.bg_color = Color(0,0,0,0)
		pr.set_border_width_all(maxi(1,int(3.0*kc)))
		pr.border_color = Color(Kit.GOLD,pop*0.9)
		pr.set_corner_radius_all(int((14.0+30.0*e)*kc))
		draw_style_box(pr,ring)
		draw_rect(rect,Color(1,0.92,0.6,0.35*pop*pop),true)

## A small pill: filled (worn) or outlined (owned).
func _badge(at: Vector2, word: String, col: Color, ink: Color, kc: float, a: float, filled: bool) -> void:
	var w := Kit.text_w(Kit.MED,word,12.5,kc,0.16)+22.0*kc
	var h := 20.0*kc
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(h*0.5))
	if filled:
		sb.bg_color = Color(col,a)
	else:
		sb.bg_color = Color(0,0,0,0)
		sb.border_color = Color(col,a*0.7)
		sb.set_border_width_all(maxi(1,int(1.2*kc)))
	draw_style_box(sb,Rect2(at-Vector2(w,h)*0.5,Vector2(w,h)))
	Kit.text(self,Kit.MED,word,at,12.5,kc,0.16,Color(ink if filled else col,a),0.5)

func _colours(i: Dictionary) -> Array:
	if i.has("livery"):
		var l: Dictionary = i.livery
		return [l.get("body",Color.WHITE),l.get("trim",Color.WHITE),l.get("wing",Color.WHITE),l.get("dark",Color.BLACK)]
	return i.get("colours",[])

## The plane from above in the paint's colours.
func _draw_plane(pv: Rect2, item: Dictionary, a: float, kc: float) -> void:
	var cols := _colours(item)
	var body: Color = cols[0]
	var trim: Color = cols[1]
	var wing: Color = cols[2]
	var dark: Color = cols[3]
	var c := pv.get_center()+Vector2(0,-2.0*kc)
	var u := minf(pv.size.x*0.46,pv.size.y*0.52)
	var o := func(pts: Array) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p: Vector2 in pts: out.append(c+p*u)
		return out
	var wings: PackedVector2Array = o.call([Vector2(-1,-0.1),Vector2(-0.95,0.12),Vector2(-0.15,0.2),Vector2(0.15,0.2),
		Vector2(0.95,0.12),Vector2(1,-0.1),Vector2(0.15,-0.28),Vector2(-0.15,-0.28)])
	var tail: PackedVector2Array = o.call([Vector2(-0.38,0.82),Vector2(-0.36,0.95),Vector2(0.36,0.95),Vector2(0.38,0.82),
		Vector2(0.12,0.7),Vector2(-0.12,0.7)])
	var fus: PackedVector2Array = o.call([Vector2(0,-0.9),Vector2(0.1,-0.8),Vector2(0.15,-0.5),Vector2(0.14,-0.1),
		Vector2(0.1,0.4),Vector2(0.045,0.95),Vector2(-0.045,0.95),Vector2(-0.1,0.4),Vector2(-0.14,-0.1),
		Vector2(-0.15,-0.5),Vector2(-0.1,-0.8)])
	var shadow := Vector2(2.5,3.5)*kc
	for poly: PackedVector2Array in [wings,tail,fus]:
		var sp := PackedVector2Array()
		for p: Vector2 in poly: sp.append(p+shadow)
		draw_colored_polygon(sp,Color(0,0,0,0.3*a))
	var edge := Color(0.95,0.95,1.0,0.32*a)
	draw_colored_polygon(wings,Color(wing,a))
	draw_colored_polygon(tail,Color(wing,a))
	for sgn in [-1.0,1.0]:
		var tip: PackedVector2Array = o.call([Vector2(sgn,-0.1),Vector2(sgn*0.95,0.12),Vector2(sgn*0.78,0.15),Vector2(sgn*0.8,-0.16)])
		draw_colored_polygon(tip,Color(trim,a))
	for poly: PackedVector2Array in [wings,tail]:
		var closed := poly.duplicate()
		closed.append(poly[0])
		draw_polyline(closed,edge,maxf(1.0,1.0*kc),true)
	draw_colored_polygon(fus,Color(body,a))
	var closed := fus.duplicate()
	closed.append(fus[0])
	draw_polyline(closed,edge,maxf(1.0,1.0*kc),true)
	draw_colored_polygon(o.call([Vector2(-0.015,-0.78),Vector2(0.015,-0.78),Vector2(0.02,0.9),Vector2(-0.02,0.9)]),Color(trim,a))
	draw_colored_polygon(o.call([Vector2(-0.075,-0.42),Vector2(0.075,-0.42),Vector2(0.085,-0.14),Vector2(-0.085,-0.14)]),Color(dark,a))
	draw_circle(c+Vector2(0,-0.9)*u,u*0.07,Color(dark,a),true,-1.0,true)

## A ribbon in the paint's two colours, rippling across the plate.
func _draw_ribbon(pv: Rect2, cols: Array, a: float, kc: float) -> void:
	var c := pv.get_center()
	if cols.is_empty():
		var rr := minf(pv.size.x,pv.size.y)*0.26
		draw_arc(c,rr,0.0,TAU,40,Color(1,1,1,0.35*a),2.0*kc,true)
		draw_line(c+Vector2(-0.7,0.7)*rr,c+Vector2(0.7,-0.7)*rr,Color(1,1,1,0.35*a),2.0*kc,true)
		return
	var main: Color = cols[0]
	var alt: Color = cols[1] if cols.size() > 1 else main
	var n := 14
	var x0 := pv.position.x+10.0*kc
	var x1 := pv.end.x-10.0*kc
	var half := 11.0*kc
	var top_pts := PackedVector2Array()
	var low_pts := PackedVector2Array()
	for i in n+1:
		var f := float(i)/n
		var x := lerpf(x0,x1,f)
		var y := c.y+sin(f*TAU*1.15+0.6+_t*2.2)*13.0*kc*(0.35+f*0.65)
		var slope := cos(f*TAU*1.15+0.6+_t*2.2)*0.6
		top_pts.append(Vector2(x,y-half))
		low_pts.append(Vector2(x+slope*2.0,y+half))
	for i in n:
		var quad := PackedVector2Array([top_pts[i],top_pts[i+1],low_pts[i+1],low_pts[i]])
		var col := main if i % 5 != 2 else alt
		draw_colored_polygon(quad,Color(col.darkened(0.12 if i % 2 == 0 else 0.0),a))
	for i in n:
		var m0 := top_pts[i].lerp(low_pts[i],0.5)
		var m1 := top_pts[i+1].lerp(low_pts[i+1],0.5)
		draw_line(m0,m1,Color(alt,a),maxf(1.5,3.0*kc),true)

# --- The mouse -----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var b := event as InputEventMouseButton
	if b == null or not b.pressed: return
	if b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_LEFT:
		view.choose(-1)
	elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN or b.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
		view.choose(1)
	elif b.button_index == MOUSE_BUTTON_LEFT:
		for h: Dictionary in _tab_hits:
			if (h.rect as Rect2).has_point(b.position):
				view.choose_slot(h.slot)
				return
		for h: Dictionary in _hits:
			if (h.rect as Rect2).has_point(b.position):
				if int(h.index) == view.chosen: view.act()
				else: view.choose_to(int(h.index))
				return
