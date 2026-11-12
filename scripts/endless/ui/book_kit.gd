extends RefCounted
## The slots the logbook and the landing slip share: a square tile on the
## cream paper, dark with its glyph in colour once the thing is had, an empty
## recess with the kind's faint outline until then. Drawn with the flight
## UI's kit (ui_kit.gd) and its glyphs (near_glyphs.gd).
##
##     const Book = preload("res://scripts/endless/ui/book_kit.gd")
##     Book.slot(self, Rect2(at, Vector2(44, 44)*k), k, "arch", true)        # had
##     Book.slot(self, r, k, "relic", false)                                  # not yet
##     Book.slot(self, r, k, id, found, a, sel_t, fresh)                      # the cursor on it, new this flight
##
## Positions and rects are screen px, every other measure the mock-up's px
## times `k` (ui_kit.gd's contract). `sel_t` is the kit's selection time.

const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
const Glyphs = preload("res://scripts/endless/near_glyphs.gd")

## A had slot's tile, opaque (the HUD chips' plate without its see-through).
const TILE := Color("1b1d22")
## An empty slot's recess and its outline, ink at these alphas, and how much
## of its kind's outline shows.
const RECESS_A := 0.055
const EDGE_A := 0.2
const GHOST_A := 0.16
## The corner cut off a slot, lower right (the slip's slanted edge, small).
const CUT := 0.16
## How far a slot under the cursor lifts.
const LIFT := 3.0

## What each kind of find is, in a word, and how it is had.
const KINDS := {
	"relic":["Ring","Fly through it"],
	"landing":["Landing","Come to rest there"],
	"line":["Line","Fly its gates to the last"],
	"event":["Moment","It happens when it happens"],
}

## A find's glyph once found, by where it stands: the table's own `glyph` if
## a row names one, else its anchor, else its kind's.
const BY_ANCHOR := [["ice-arch","arch"],["/arch/","arch"],["/stacks/","stack"],["peak/summit","peak"],["peak/tower","peak"],
	["tunnel","tunnel"],["chamber/","door"],["doors/","door"],["peak/hole","gap"],["peak/tarn","water"],["peak/crevasse","canyon"]]
const BY_ID := {"burrower-catch":"burrower","the-wall":"door","inlet-skim":"water","bay-ring":"water","sound-ring":"water",
	"strait-ring":"water","horn-mouth":"water","gap-ring":"gap","saddle-ring":"climb"}

static func find_glyph(e: Dictionary) -> String:
	var own := str(e.get("glyph",""))
	if own != "" and Glyphs.resolve(own) != "": return own
	var kind := str(e.get("kind","relic"))
	if kind == "line": return "race"
	if BY_ID.has(str(e.get("id",""))): return str(BY_ID[str(e.id)])
	if kind == "relic":
		var anchor := str(e.get("anchor",""))
		for pair: Array in BY_ANCHOR:
			if anchor.contains(str(pair[0])): return str(pair[1])
	return kind_glyph(kind)

## The glyph an unfound slot hints with: its kind's only.
static func kind_glyph(kind: String) -> String:
	return kind if kind in ["relic","landing","line","event"] else "relic"

static func kind_word(kind: String) -> String:
	return str((KINDS.get(kind,KINDS.relic) as Array)[0])

static func kind_how(kind: String) -> String:
	return str((KINDS.get(kind,KINDS.relic) as Array)[1])

## The glyph for a record or a tally, or "".
const STAT_GLYPHS := {"best_line":"line","best_mult":"bank","longest_line":"carve","tightest_gap":"gap","top_speed":"surge",
	"highest":"peak","longest_flight":"plane","trees":"tree","grass_m":"ground","skims":"skip","scrapes":"scrape",
	"crashes":"crash","landings":"landing","lines":"line","metres":"plane"}

static func stat_glyph(key: String) -> String:
	return str(STAT_GLYPHS.get(key,""))

# --- Drawing -----------------------------------------------------------------------------

## A glyph `d` screen px across its 24-unit box, centred on `c`. False if
## the set has none by that id.
static func glyph(ci: CanvasItem, id: String, variant: String, c: Vector2, d: float, mod := Color.WHITE) -> bool:
	var tex := Glyphs.texture(id,variant,maxf(roundf(d),6.0))
	if tex == null: return false
	if mod.a <= 0.003: return true
	var sz := Vector2(tex.get_size())
	ci.draw_texture_rect(tex,Rect2((c-sz*0.5).round(),sz),false,mod)
	return true

## The slot's outline in `r`: square, its lower right corner cut.
static func slot_pts(r: Rect2) -> PackedVector2Array:
	var cut := r.size.x*CUT
	return PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),Vector2(r.end.x,r.end.y-cut),
		Vector2(r.end.x-cut,r.end.y),Vector2(r.position.x,r.end.y)])

## One slot in `r` (screen px, square). `id` is its glyph; `found` the dark
## tile with the glyph in colour, else the recess with the outline of
## `ghost` (default `id`). With `sel_t >= 0` the cursor is on it: it lifts,
## takes an ink frame and the slanted tick under it. `fresh` marks one had
## this flight with a dot at its corner.
static func slot(ci: CanvasItem, r: Rect2, k: float, id: String, found: bool, a := 1.0, sel_t := Kit.OFF, fresh := false, ghost := "") -> void:
	if a <= 0.003: return
	var sel := sel_t >= 0.0
	var e := Kit.ease_out(sel_t/Kit.T_BAND) if sel else 1.0-Kit.ease_out(-sel_t/Kit.T_BAND)
	var at := Rect2(r.position-Vector2(0.0,roundf(LIFT*k*e)),r.size)
	var pts := slot_pts(at)
	if e > 0.003:
		# What it lifted off: the tick, as under a chosen option.
		Kit.slant(ci,Rect2(r.position.x+r.size.x*0.18,r.end.y+2.0*k,r.size.x*(0.34+0.3*e),maxf(2.5*k,2.0)),Color(Kit.TICK,e*a))
	if found:
		ci.draw_colored_polygon(slot_pts(Rect2(at.position+Vector2(0.0,2.0*k),at.size)),Color(Kit.NIGHT,0.28*a))
		Kit.poly(ci,pts,Color(TILE,a))
		glyph(ci,id,"icon",at.get_center(),at.size.x*0.66,Color(1,1,1,a))
	else:
		Kit.poly(ci,pts,Color(Kit.INK,RECESS_A*a))
		var line := pts.duplicate()
		line.append(pts[0])
		ci.draw_polyline(line,Color(Kit.INK,EDGE_A*a),maxf(roundf(k),1.0),true)
		glyph(ci,ghost if ghost != "" else id,"shadow",at.get_center(),at.size.x*0.58,Color(Kit.INK,GHOST_A*a))
	if e > 0.003:
		var frame := slot_pts(at.grow(2.5*k))
		frame.append(frame[0])
		ci.draw_polyline(frame,Color(Kit.INK,e*a),maxf(roundf(1.6*k),1.0),true)
	if fresh:
		ci.draw_circle(Vector2(at.end.x-1.0*k,at.position.y+1.0*k),3.6*k,Color(Kit.PAPER,a),true,-1.0,true)
		ci.draw_circle(Vector2(at.end.x-1.0*k,at.position.y+1.0*k),2.4*k,Color(Kit.TICK,a),true,-1.0,true)

## A small label over a numeral, the slip's stat cell: `label` upper-cased
## and quiet, `value` in the italic numerals under it. `at` is the cell's top
## left; it is 34 tall.
static func stat(ci: CanvasItem, at: Vector2, k: float, label: String, value: String, a := 1.0, col := Kit.INK) -> void:
	Kit.text(ci,Kit.MED,label.to_upper(),at+Vector2(0.0,7.0*k),9.5,k,0.2,Kit.DIM,0.0,a)
	Kit.text(ci,Kit.NUM,value,at+Vector2(0.0,24.0*k),17.0,k,0.0,col,0.0,a)
