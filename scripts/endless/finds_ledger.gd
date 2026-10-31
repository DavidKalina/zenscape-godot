extends RefCounted
## The logbook's Wilderness page (lane `finds`): each area with its count, what
## was found by name, a blank for the rest, the hint where a row has one. Drawn
## on the logbook view through LandingSummary's helpers.

const Card = preload("res://scripts/endless/landing_summary.gd")

const WIDTH := 1060.0
const MARGIN := 48.0
const ROW := 27.0
const HEAD := 40.0
const COLUMNS := 3
const BLANK := "- - - - -"

## The blocks split over columns, at most COLUMNS, keeping an area whole:
## [[block, ...], ...].
static func flow(blocks: Array) -> Array:
	var total := 0
	for b: Dictionary in blocks: total += 1+(b.rows as Array).size()
	var each := ceili(float(total)/COLUMNS)
	var cols: Array = [[]]
	var n := 0
	for b: Dictionary in blocks:
		var h := 1+(b.rows as Array).size()
		if n > 0 and n+h > each and cols.size() < COLUMNS:
			cols.append([])
			n = 0
		(cols[cols.size()-1] as Array).append(b)
		n += h
	return cols

## The page as text lines (for drivers and checks).
static func lines(blocks: Array) -> Array:
	var out := ["[wilderness]"]
	for b: Dictionary in blocks:
		out.append("  %s | %d / %d" % [b.title,int(b.got),int(b.of)])
		for r: Dictionary in b.rows:
			var left := str(r.text) if str(r.text) != "" else BLANK
			out.append("    %s%s%s" % ["* " if r.found else "",left," | "+str(r.value) if str(r.value) != "" else ""])
	return out

static func draw(view: Control, finds: Node, a: float) -> void:
	var blocks: Array = finds.ledger()
	var cols := flow(blocks)
	var tallest := 0.0
	for col: Array in cols:
		var h := 0.0
		for b: Dictionary in col: h += HEAD+(b.rows as Array).size()*ROW+14.0
		tallest = maxf(tallest,h)
	var size := view.size
	var extra := 120.0+70.0
	var s := minf(size.y/900.0,(size.y-MARGIN)/(tallest+extra))
	var h := (tallest+extra)*s
	var w := minf(WIDTH*s,size.x-MARGIN*2.0)
	var r := Rect2((size.x-w)*0.5,(size.y-h)*0.5,w,h)
	Card.plate(view,r,s,a)
	var left := r.position.x+32.0*s
	var right := r.end.x-32.0*s
	var y := r.position.y+48.0*s
	Card.ink(view,Card.words(30.0*s,0.22),"WILDERNESS",Vector2(left,y),30.0*s,Color(Card.CREAM,a),7.0*s,0.0)
	var got := 0
	var of := 0
	for b: Dictionary in blocks:
		got += int(b.got)
		of += int(b.of)
	Card.ink(view,Card.nums(true),"%d / %d" % [got,of],Vector2(right,y-2.0*s),44.0*s,Color(Card.GOLD,a),9.0*s,1.0,Color(Card.GOLD,0.5*a),6.0*s)
	var top := r.position.y+112.0*s
	var col_w := (w-64.0*s)/float(COLUMNS)
	for i in cols.size():
		var cx := left+i*col_w
		var cr := cx+col_w-22.0*s
		var cy := top
		for b: Dictionary in cols[i]:
			Card.draw_row(view,{"kind":"head","label":str(b.title)},cx,cr,cy,s,a)
			Card.ink(view,Card.nums(),"%d / %d" % [int(b.got),int(b.of)],Vector2(cr,cy),17.0*s,Color(Card.GOLD,a),4.0*s,1.0)
			cy += 34.0*s
			for row: Dictionary in b.rows:
				_row(view,row,cx,cr,cy,s,a)
				cy += ROW*s
			cy += 20.0*s
	Card.ink(view,Card.words(14.0*s,0.08),"Tab for the logbook.  J or Esc to close",Vector2(r.position.x+r.size.x*0.5,r.end.y-26.0*s),14.0*s,Color(Card.GREY,a),4.0*s,0.5)

static func _row(view: Control, row: Dictionary, cx: float, cr: float, cy: float, s: float, a: float) -> void:
	var value := str(row.value)
	if bool(row.found):
		var d := 5.0*s
		var c := Vector2(cx+d,cy)
		view.draw_colored_polygon(PackedVector2Array([c+Vector2(0,-d),c+Vector2(d,0),c+Vector2(0,d),c+Vector2(-d,0)]),Color(Card.GOLD,a))
		Card.ink(view,Card.words(15.0*s,0.02),str(row.text),Vector2(cx+16.0*s,cy),15.0*s,Color(Card.CREAM,0.9*a),4.0*s,0.0)
		if value != "": Card.ink(view,Card.nums(),value,Vector2(cr,cy),17.0*s,Color(Card.GOLD,a),4.0*s,1.0)
		return
	var text := str(row.text)
	if text != "": Card.ink(view,Card.words(14.0*s,0.01),text,Vector2(cx+16.0*s,cy),14.0*s,Color(Card.GREY,0.95*a),3.0*s,0.0)
	else: Card.ink(view,Card.words(14.0*s,0.12),BLANK,Vector2(cx+16.0*s,cy),14.0*s,Color(Card.GREY,0.7*a),3.0*s,0.0)
