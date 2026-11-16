extends Control
## The shop's panel (shop_view.gd owns it): a card on the screen's right edge,
## vertically centred, its height what the content needs up to a share of the
## screen. A head (title, sections with their counts, the money), a list of
## rows that scrolls smoothly (preview, name, rarity, price or OWNED / WORN),
## and a foot (what Enter does, the keys). The plane stands clear to its left
## wearing the choice. Everything is drawn here; the view holds the choice and
## the keys.
##
## `view.rows` is [{id, slot, s (selection 0..1), pulse, ...}], `view.chosen`
## the index in it. A row's slot is its section (ShopStock SECTIONS): the
## head's tabs, drawn as small as they must be to fit the panel, the count
## only on the one shown. A part's row (a look's pattern, finish or decal)
## shows the little plane in the part's `thumb` colours.

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
const FlightHud = preload("res://scripts/endless/ui/flight_hud.gd")
const ShopStock = preload("res://scripts/endless/shop_stock.gd")
const Pad = preload("res://scripts/pad.gd")

const LOST := Color("ff8a6b")
const DIM := Color(0.96,0.95,0.92,0.55)
const CARD := Color("23272e")

## Sizes in the kit's mock px (1280x800), times `k`.
const PANEL_W := 400.0
const MARGIN := 26.0
const HEAD_H := 100.0
const FOOT_H := 92.0
const ROW_H := 62.0
const THUMB_W := 88.0
const WANT_ROWS := 5.6
## The most of the screen's height the panel takes.
const MAX_SHARE := 0.64

var view: Control
var _k := 1.0
var _panel := Rect2()
## Eased: how far the panel has slid in, the list's scroll (px), the money shown.
var _rise := 0.0
var _scroll := 0.0
var _slot_shown := ""
var _money_shown := -1.0
var _t := 0.0
## Hit areas from the last draw, for the mouse: [{rect, index}] and [{rect, slot}].
var _hits: Array = []
var _tab_hits: Array = []
var shake := 0.0

func _ready() -> void:
	name = "ShopPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## The rows in `slot`, as indices into view.rows.
func _in_slot(slot: String) -> Array:
	var out: Array = []
	for k in view.rows.size():
		if view.rows[k].slot == slot: out.append(k)
	return out

## The panel's size in mock px for this screen: the content, capped.
func _panel_mock(screen: Vector2, k: float, count: int) -> Vector2:
	var want := HEAD_H+FOOT_H+minf(float(count),WANT_ROWS)*ROW_H+8.0
	return Vector2(PANEL_W,minf(want,MAX_SHARE*screen.y/k))

func _list_h(h: float) -> float:
	return h-HEAD_H-FOOT_H

func _scroll_target(at: int, count: int, list_h: float) -> float:
	var total := count*ROW_H+8.0
	return clampf(at*ROW_H+ROW_H*0.5-list_h*0.5,0.0,maxf(0.0,total-list_h))

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
	var k := Kit.scale_of(screen)
	var pm := _panel_mock(screen,k,mine.size())
	var goal := _scroll_target(mine.find(view.chosen),mine.size(),_list_h(pm.y))*k
	if _slot_shown != cur.slot:
		_slot_shown = cur.slot
		_scroll = goal
	_scroll += (goal-_scroll)*(1.0-exp(-11.0*delta))
	for r: Dictionary in view.rows:
		var want := 1.0 if r == cur else 0.0
		r.s += (want-r.s)*ease_by
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
	var cur: Dictionary = view.rows[view.chosen]
	var mine := _in_slot(cur.slot)
	var pm := _panel_mock(screen,k,mine.size())
	var pw := pm.x*k
	var ph := pm.y*k
	var slide := (1.0-rise)*(pw+MARGIN*k*2.0)
	_panel = Rect2(screen.x-pw-MARGIN*k+slide,(screen.y-ph)*0.5,pw,ph)
	_hits.clear()
	_tab_hits.clear()
	var item := ShopStock.item(cur.id)

	# A soft shadow, then the plate.
	for i in 5:
		var sbs := StyleBoxFlat.new()
		sbs.bg_color = Color(0,0,0,0.06*rise)
		sbs.set_corner_radius_all(int((16.0+i*5.0)*k))
		draw_style_box(sbs,_panel.grow((3.0+i*5.0)*k))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Kit.PLATE,1.0)
	sb.set_corner_radius_all(int(16.0*k))
	sb.border_color = Color(Kit.GOLD,0.45)
	sb.set_border_width_all(maxi(1,int(1.5*k)))
	draw_style_box(sb,_panel)

	# The list, then the head and foot over its overflow.
	var top := _panel.position.y+HEAD_H*k
	var bot := _panel.end.y-FOOT_H*k
	var total := mine.size()*ROW_H*k+8.0*k
	for n in mine.size():
		var y := top+4.0*k+n*ROW_H*k-_scroll
		if y+ROW_H*k < top-2.0*k or y > bot+2.0*k: continue
		_draw_row(view.rows[mine[n]],mine[n],Rect2(_panel.position.x+14.0*k,y,pw-28.0*k,(ROW_H-6.0)*k),k,top,bot)
	var body := Color(Kit.PLATE,1.0)
	var inner := Rect2(_panel.position.x+1.5*k,0,pw-3.0*k,0)
	draw_rect(Rect2(inner.position.x,_panel.position.y+8.0*k,inner.size.x,top-_panel.position.y-8.0*k),body)
	draw_rect(Rect2(inner.position.x,bot,inner.size.x,_panel.end.y-bot-8.0*k),body)
	# Fades where more lie beyond.
	var fh := 26.0*k
	var more_up := clampf(_scroll/(ROW_H*k*0.6),0.0,1.0)
	var more_dn := clampf((total-_list_h(pm.y)*k-_scroll)/(ROW_H*k*0.6),0.0,1.0)
	var c0 := Color(Kit.PLATE,1.0)
	var c1 := Color(Kit.PLATE,0.0)
	var x0 := inner.position.x
	var x1 := inner.end.x
	draw_polygon(PackedVector2Array([Vector2(x0,top),Vector2(x1,top),Vector2(x1,top+fh),Vector2(x0,top+fh)]),
		PackedColorArray([c0,c0,c1,c1]))
	draw_polygon(PackedVector2Array([Vector2(x0,bot-fh),Vector2(x1,bot-fh),Vector2(x1,bot),Vector2(x0,bot)]),
		PackedColorArray([c1,c1,c0,c0]))
	# Little arrows over the fades.
	var tint := Color(Kit.GOLD,0.7)
	if more_up > 0.05: Kit.text(self,Kit.NUM,"^",Vector2(_panel.get_center().x,top+9.0*k),13.0,k,0.0,Color(tint,tint.a*more_up),0.5)
	if more_dn > 0.05: Kit.text(self,Kit.NUM,"v",Vector2(_panel.get_center().x,bot-9.0*k),13.0,k,0.0,Color(tint,tint.a*more_dn),0.5)

	_draw_head(k,mine.size())
	_draw_foot(k,cur,item)

## The title, the sections (with how many each holds) and the money.
func _draw_head(k: float, _count: int) -> void:
	var cur_slot: String = view.rows[view.chosen].slot
	var px := _panel.position.x+22.0*k
	var y := _panel.position.y+30.0*k
	Kit.text(self,Kit.SERIF,"The Shop",Vector2(px,y),27.0,k,0.01,Kit.CREAM,0.0)
	# Money: the coin and the figure, to the right.
	var coin_d := 20.0*k
	var txt := "%d" % roundi(_money_shown)
	var fs := 21.0
	var tw := Kit.text_w(Kit.NUM,txt,fs,k,0.02)
	var rx := _panel.end.x-22.0*k
	var plate := Rect2(rx-tw-coin_d-26.0*k,y-15.0*k,tw+coin_d+34.0*k,30.0*k)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1,1,1,0.07)
	sb.set_corner_radius_all(int(15.0*k))
	sb.border_color = Color(Kit.GOLD,0.4)
	sb.set_border_width_all(maxi(1,int(1.5*k)))
	draw_style_box(sb,plate)
	FlightHud.draw_coin(self,Vector2(plate.position.x+17.0*k,y),coin_d)
	Kit.text(self,Kit.NUM,txt,Vector2(rx,y),fs,k,0.02,Kit.GOLD,1.0)
	# The sections: every name, the one shown with how many of it are had;
	# as large as fits the panel's width.
	var x := px
	var ty := _panel.position.y+72.0*k
	var held := 0
	var all := 0
	for r: Dictionary in view.rows:
		if r.slot != cur_slot: continue
		all += 1
		if ShopStock.has(view.book,r.id): held += 1
	var count := "%d/%d" % [held,all]
	var fs_tab := 15.0
	var gap := 30.0
	var room := _panel.end.x-22.0*k-px
	while fs_tab > 9.0:
		var need := Kit.text_w(Kit.NUM,count,fs_tab-3.0,k,0.04)+6.0*k-gap*k
		for slot: String in ShopStock.SECTIONS: need += Kit.text_w(Kit.MED,String(ShopStock.SLOT_NAMES.get(slot,slot)).to_upper(),fs_tab,k,0.1)+gap*k
		if need <= room: break
		fs_tab -= 0.5
		gap = maxf(gap-2.0,11.0)
	for slot: String in ShopStock.SECTIONS:
		var label := String(ShopStock.SLOT_NAMES.get(slot,slot)).to_upper()
		var on := slot == cur_slot
		var col := Kit.CREAM if on else DIM
		var full := Kit.text(self,Kit.MED,label,Vector2(x,ty),fs_tab,k,0.1,col)
		if on:
			full += 6.0*k+Kit.text(self,Kit.NUM,count,Vector2(x+full+6.0*k,ty),fs_tab-3.0,k,0.04,Color(Kit.GOLD,0.9))
			draw_rect(Rect2(x,ty+12.0*k,full,2.5*k),Kit.GOLD)
		_tab_hits.append({"rect":Rect2(x-gap*0.5*k,ty-15.0*k,full+gap*k,36.0*k),"slot":slot})
		x += full+gap*k
	Kit.hair(self,Vector2(px,_panel.position.y+(HEAD_H-4.0)*k),_panel.end.x-22.0*k,k,Color(Kit.GOLD,0.25))

## The foot: what the key does for the chosen item, and the keys.
func _draw_foot(k: float, cur: Dictionary, _item: Dictionary) -> void:
	var item := ShopStock.item(cur.id)
	var x := _panel.position.x+22.0*k
	var top := _panel.end.y-FOOT_H*k
	Kit.hair(self,Vector2(x,top+2.0*k),_panel.end.x-22.0*k,k,Color(Kit.GOLD,0.25))
	var had: bool = ShopStock.has(view.book,cur.id)
	var worn: bool = ShopStock.wearing(view.book,cur.id)
	var price := int(item.get("price",0))
	var money := int(view.book.money)
	var yy := top+27.0*k
	var key := Pad.pick("ENTER","X")
	if worn:
		Kit.text(self,Kit.MED,"ON YOUR PLANE",Vector2(x,yy),15.0,k,0.2,Kit.GOLD,0.0)
	elif had:
		var parts := [Kit.part(key,Kit.NUM,15.0,0.06,Kit.GOLD,10.0),Kit.part("WEAR IT",Kit.MED,15.0,0.2,Kit.CREAM)]
		Kit.run(self,parts,Vector2(x,yy),k)
	elif price <= money:
		var parts := [Kit.part(key,Kit.NUM,15.0,0.06,Kit.GOLD,10.0),Kit.part("BUY FOR",Kit.MED,15.0,0.2,Kit.CREAM,10.0),
			Kit.part("%d" % price,Kit.NUM,19.0,0.02,Kit.GOLD,8.0),Kit.room(24.0)]
		var w := Kit.run_w(parts,k)
		Kit.run(self,parts,Vector2(x,yy),k)
		FlightHud.draw_coin(self,Vector2(x+w-12.0*k,yy),18.0*k)
	else:
		var sx := sin(_t*60.0)*6.0*k*shake
		Kit.text(self,Kit.MED,"%d MORE TO BUY" % (price-money),Vector2(x+sx,yy),15.0,k,0.2,LOST,0.0)
	var h1 := Pad.pick("W S choose  ·  Q E section  ·  Esc leave","Stick choose  ·  LB RB section  ·  B leave")
	var h2 := Pad.pick("Space take off","A take off")
	Kit.text(self,Kit.MED,h1,Vector2(x,top+53.0*k),11.5,k,0.04,DIM,0.0)
	Kit.text(self,Kit.MED,h2,Vector2(x,top+71.0*k),11.5,k,0.04,DIM,0.0)

func _draw_row(r: Dictionary, index: int, rect0: Rect2, k: float, top: float, bot: float) -> void:
	var item := ShopStock.item(r.id)
	var s: float = r.s
	var pop: float = r.pulse
	var chosen: bool = index == view.chosen
	var had: bool = ShopStock.has(view.book,r.id)
	var worn: bool = ShopStock.wearing(view.book,r.id)
	var price := int(item.get("price",0))
	var can := had or price <= int(view.book.money)
	var rare := ShopStock.rarity(item)
	var rc: Color = ShopStock.RARITY_COLOURS.get(rare,Kit.PALE)
	var a := 0.82+0.18*s
	var dim := 1.0 if can else 0.8
	# The chosen row slides out a little and grows.
	var grow := (3.0*s+4.0*sin(pop*PI)*pop)*k
	var sh := sin(_t*60.0)*7.0*k*shake*s
	var rect := Rect2(rect0.position+Vector2(-9.0*k*s+sh,0),rect0.size).grow_individual(grow*0.5,grow,grow*0.5+9.0*k*s,grow)
	var kc := k
	_hits.append({"rect":Rect2(rect.position.x,maxf(rect.position.y,top),rect.size.x,minf(rect.end.y,bot)-maxf(rect.position.y,top)),"index":index})

	# Glow behind the chosen row and the better ones.
	var glow := 0.0
	if rare == "legendary": glow = 0.16
	elif rare == "rare": glow = 0.07
	glow += 0.2*s
	if glow > 0.01:
		var gc := rc.lerp(Kit.GOLD,0.35) if chosen else rc
		for i in 3:
			var sbg := StyleBoxFlat.new()
			sbg.bg_color = Color(gc,glow*0.22*(3-i)/3.0)
			sbg.set_corner_radius_all(int((11.0+i*3.0)*kc))
			draw_style_box(sbg,rect.grow((2.0+i*3.0)*kc))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CARD,1.0).lerp(Color("3a414d"),s)
	sb.set_corner_radius_all(int(9.0*kc))
	sb.border_color = Color(rc.lerp(Kit.CREAM,0.35) if chosen else rc.darkened(0.25),0.95 if chosen else (0.55 if rare != "common" else 0.25))
	sb.set_border_width_all(maxi(1,int((1.0+2.0*s)*kc)))
	draw_style_box(sb,rect)

	# The preview, on a plate tinted by the item's own colour.
	var pv := Rect2(rect.position+Vector2(5,5)*kc,Vector2(THUMB_W*kc,rect.size.y-10.0*kc))
	var cols := _colours(item)
	var tint := Color(0.17,0.2,0.24)
	if not cols.is_empty(): tint = tint.lerp(cols[0],0.2)
	var pb := StyleBoxFlat.new()
	pb.bg_color = tint
	pb.set_corner_radius_all(int(6.0*kc))
	draw_style_box(pb,pv)
	if r.slot == "paint" or item.has("thumb"): _draw_plane(pv,item,dim,kc)
	else: _draw_ribbon(pv,cols,dim,kc)
	draw_rect(Rect2(pv.position.x+3.0*kc,pv.end.y-3.0*kc,pv.size.x-6.0*kc,2.5*kc),Color(rc,0.9 if rare != "common" else 0.4))
	if not can: draw_rect(pv,Color(0.05,0.05,0.07,0.18),true)

	# The state or price, right.
	var rx := rect.end.x-12.0*kc
	var cy := rect.position.y+rect.size.y*0.5
	var right_w := 0.0
	if worn:
		right_w = _badge(Vector2(rx,cy),"WORN",Kit.GOLD,Color("2a1f08"),kc,a,true)
	elif had:
		right_w = _badge(Vector2(rx,cy),"OWNED",Color(Kit.PALE,0.9),Color(Kit.PALE,0.0),kc,a,false)
	else:
		var txt := "%d" % price
		var tw := Kit.text_w(Kit.NUM,txt,17.0,kc,0.02)
		var d := 15.0*kc
		Kit.text(self,Kit.NUM,txt,Vector2(rx,cy),17.0,kc,0.02,Color(Kit.GOLD if can else LOST,a),1.0)
		FlightHud.draw_coin(self,Vector2(rx-tw-d*0.5-5.0*kc,cy),d,dim)
		right_w = tw+d+5.0*kc

	# Name and rarity.
	var nx := pv.end.x+13.0*kc
	var room := (rx-right_w-10.0*kc)-nx
	var nm := String(item.get("name",""))
	var px := 16.0
	while px > 11.0 and Kit.text_w(Kit.MED,nm,px,kc,0.02) > room: px -= 0.5
	Kit.text(self,Kit.MED,nm,Vector2(nx,cy-9.5*kc),px,kc,0.02,Color(Kit.CREAM,(1.0 if can else 0.75)),0.0)
	var dia := PackedVector2Array([Vector2(0,-4),Vector2(4,0),Vector2(0,4),Vector2(-4,0)])
	var dc := Vector2(nx+4.0*kc,cy+11.0*kc)
	var pts := PackedVector2Array()
	for p: Vector2 in dia: pts.append(dc+p*kc)
	draw_colored_polygon(pts,rc)
	Kit.text(self,Kit.MED,rare.to_upper(),Vector2(nx+13.0*kc,cy+11.0*kc),11.5,kc,0.16,Color(rc,0.95),0.0)
	# A buy: the ring that leaves the row.
	if pop > 0.0:
		var e := 1.0-pop
		var ring := rect.grow((4.0+26.0*e)*kc)
		var pr := StyleBoxFlat.new()
		pr.bg_color = Color(0,0,0,0)
		pr.set_border_width_all(maxi(1,int(3.0*kc)))
		pr.border_color = Color(Kit.GOLD,pop*0.9)
		pr.set_corner_radius_all(int((12.0+20.0*e)*kc))
		draw_style_box(pr,ring)
		draw_rect(rect,Color(1,0.92,0.6,0.3*pop*pop),true)

## A small pill ending at `right` (its middle height): filled (worn) or outlined
## (owned). Returns its width.
func _badge(right: Vector2, word: String, col: Color, ink: Color, kc: float, a: float, filled: bool) -> float:
	var w := Kit.text_w(Kit.MED,word,12.5,kc,0.16)+22.0*kc
	var h := 20.0*kc
	var at := right-Vector2(w*0.5,0)
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
	return w

func _colours(i: Dictionary) -> Array:
	if i.has("thumb"): return i.thumb
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
