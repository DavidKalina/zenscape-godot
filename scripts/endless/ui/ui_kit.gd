extends RefCounted
## The flight UI's kit: the colours, fonts, scale rule and draw helpers the
## menus, the flight HUD and the chain HUD share (docs/design/ui/spec-flight-ui.md).
## Every number here is read off the mock-ups' <style> blocks and markup
## (docs/design/ui/mock/Main.dc.html, Hud.dc.html).
##
##     const Kit = preload("res://scripts/endless/ui/ui_kit.gd")
##     func _draw() -> void:
##         var k := Kit.scale_of(size)
##         var slip := Rect2(72.0*k, 238.0*k, 228.0*k, 250.0*k)
##         Kit.slip(self, slip, k)
##         Kit.head(self, slip, slip.position.y+8.0*k, k, "Paused")
##         Kit.row(self, slip, slip.position.y+38.0*k, k, "Resume", Kit.ON, 30.0, 16.0, "Esc")
##         Kit.row(self, slip, slip.position.y+68.0*k, k, "Logbook", Kit.OFF, 30.0, 16.0, "J")
##         Kit.prompts(self, [["Up Down","select"],["Enter","choose"]], size-Vector2(28.0,50.0)*k, k)
##
## The contract every helper keeps:
## - It is a static function that draws on the CanvasItem it is handed, so
##   call it from that item's `_draw` (or a `draw` signal).
## - **Positions and rects are screen px. Every other measure is the
##   mock-up's px** (a row height, a font size, a padding) and is multiplied
##   by `k` inside. `k` is `scale_of(size)`: the one scale rule.
## - `a` is an alpha multiplier for fades. A helper draws nothing it was not
##   asked to: no state is kept between calls but the font cache.
## - Text is placed by its left edge (or `align`) and its **middle** line.
## - Labels are upper-cased by the row helpers; `text`, `run` and `chip`
##   draw the string as given.
## - Selection is a time: `sel_t >= 0` is selected, that many seconds ago;
##   `sel_t < 0` is not selected, that many seconds ago. `ON` and `OFF` are
##   the two at rest. The band, the tick and the lean run off it.

const Pad = preload("res://scripts/pad.gd")

# --- The scale rule ----------------------------------------------------------------------

## The mock-ups' frame. One mock px is `scale_of(size)` screen px.
const FRAME := Vector2(1280.0,800.0)

## The scale of every piece of the new UI in a viewport of `size`: the
## mock-up's 1280x800 frame fitted inside it (1.125 at 1440x900, 1.35 at
## 1920x1080). Anchor to the viewport's corners with it: a chip the mock-up
## puts at `left:28px;top:26px` is at `Vector2(28,26)*k`, one at
## `right:28px;bottom:26px` ends at `size-Vector2(28,26)*k`.
static func scale_of(size: Vector2) -> float:
	return minf(size.x/FRAME.x,size.y/FRAME.y)

# --- Colours -----------------------------------------------------------------------------

## The slip's cream paper.
const PAPER := Color("f4eedc")
## The paper's faint grain (vertical bands 92 px apart), at alpha GRAIN_A.
const GRAIN := Color("3c280a")
const GRAIN_A := 0.035
## Ink: the spine, a selected label, the chosen option, numerals on paper.
const INK := Color("1b1d22")
## A label at rest on paper.
const LAND := Color("3a3a36")
## Quiet words on paper: key hints, the options not chosen, a credit's second line.
const DIM := Color("5d5b55")
## The selection tick, and a selected slider's mark.
const TICK := Color("c2501c")
## A section heading on paper.
const HEAD := Color("8c2a16")
## Ink at the alphas the paper's furniture uses.
const BAND := Color("1b1d221a")
const RULE := Color("1b1d2238")
const RULE_SOFT := Color("1b1d222e")
const TRACK := Color("1b1d2247")
## The dark chip.
const PLATE := Color("16181ddb")
## On a dark chip: words, quieter words, gilt numerals, a toast's words.
const CREAM := Color("f6f3ea")
const PALE := Color("d9d5c8")
const GOLD := Color("ffd36b")
const TOAST := Color("f7dc8a")
## A lit charge cell, and the cream an unlit cell or a chip's divider is drawn
## in (at CELL_OFF_A).
const CELL := Color("f2c14e")
const CELL_OFF_A := 0.3
## The shadow under paper and the wash a menu lays over the flight.
const NIGHT := Color("0e1013")
const WASH_A := 0.2

# --- Measures (mock px) ------------------------------------------------------------------

## The lean of every slanted mark: tan(14 degrees), top to the right.
const SKEW := 0.2493
## How far the slip's right edge runs in from top to bottom, and a chip's.
const SLIP_CUT := 18.0
const PLATE_CUT := 9.0
const SPINE := 3.0
## A row's label starts here from the slip's left, and leans LEAN further when selected.
const LABEL_X := 30.0
const LEAN := 8.0
## A value row's control ends this far from the slip's right.
const VALUE_PAD := 38.0
const SLIDER := Vector2(132.0,22.0)

## Timings (seconds) and the two rest states of `sel_t`.
const T_SLIP := 0.18
const T_BAND := 0.12
const T_TICK := 0.16
const T_LEAN := 0.1
const ON := 1000.0
const OFF := -1000.0

# --- Fonts -------------------------------------------------------------------------------

## The faces: MED is Barlow Semi Condensed 500 upright (labels, words); NUM
## is 600 italic with tabular figures (numerals, key names, anything
## selected); SERIF is Newsreader 500 (the game's name).
enum {MED, NUM, SERIF}

const FONT_DIR := "res://assets/fonts/"
## The design's files, then the ones the repo has. The loader takes the
## first that exists, so the build runs before the lighter files are added.
const FILES := {
	MED: ["barlow-semi-condensed-500-latin.woff2","barlow-semi-condensed-800-latin.woff2"],
	NUM: ["barlow-semi-condensed-600-italic-latin.woff2","barlow-semi-condensed-800-italic-latin.woff2"],
	SERIF: ["newsreader-latin.woff2"],
}
## How much the 800 fallback is thinned towards the design's weight
## (FontVariation.variation_embolden; 0 leaves it at 800).
const FALLBACK_THIN := {MED: -0.7, NUM: -0.45}

static var _base := {}
static var _fell := {}
static var _faces := {}
static var _skip_design := false
static var _shadow: StyleBoxFlat

## Forgets the loaded fonts, so the next draw loads them again. With
## `fallback` the design's files are passed over as if they were missing: a
## look at the build without them.
static func reset_fonts(fallback := false) -> void:
	_base.clear()
	_fell.clear()
	_faces.clear()
	_skip_design = fallback

## The font file behind a face: the design's when it is in assets/fonts, else
## the fallback. Loaded once.
static func base(which: int) -> Font:
	if _base.has(which): return _base[which]
	var files: Array = FILES[which]
	var font: Font = null
	for i in files.size():
		var path := FONT_DIR+str(files[i])
		if _skip_design and i == 0 and files.size() > 1: continue
		if not ResourceLoader.exists(path): continue
		font = load(path)
		if font != null:
			_fell[which] = i > 0
			break
	if font == null:
		push_warning("ui_kit: no font file for face %d, using the engine's" % which)
		font = ThemeDB.fallback_font
		_fell[which] = true
	_base[which] = font
	return font

## True when a face is drawn with its fallback file (the 800 weight).
static func fell_back(which: int) -> bool:
	base(which)
	return bool(_fell.get(which,false))

## A face at `px` screen px, tracked `track` em (CSS letter-spacing). Cached.
static func face(which: int, px: float, track := 0.0) -> FontVariation:
	var gap := roundi(px*track)
	var key := which*4096+gap+512
	if _faces.has(key): return _faces[key]
	var f := FontVariation.new()
	f.base_font = base(which)
	f.spacing_glyph = gap
	var ts := TextServerManager.get_primary_interface()
	if which == NUM: f.opentype_features = {ts.name_to_tag("tnum"):1}
	if which == SERIF: f.variation_opentype = {ts.name_to_tag("wght"):500}
	elif fell_back(which): f.variation_embolden = float(FALLBACK_THIN.get(which,0.0))
	_faces[key] = f
	return f

## The width `s` takes in a face at `px` mock px.
static func text_w(which: int, s: String, px: float, k: float, track := 0.0) -> float:
	if s.is_empty(): return 0.0
	var ipx := maxi(roundi(px*k),4)
	return face(which,ipx,track).get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx).x

## `s` in a face at `px` mock px, tracked `track` em, its middle line at
## at.y and its left edge at at.x (`align` 0.5 centres it, 1 ends it there).
## Returns its width. No keyline or shadow: the new UI's text sits on paper
## or a chip.
static func text(ci: CanvasItem, which: int, s: String, at: Vector2, px: float, k: float, track: float, col: Color, align := 0.0, a := 1.0) -> float:
	if s.is_empty(): return 0.0
	var ipx := maxi(roundi(px*k),4)
	var f := face(which,ipx,track)
	var w := f.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx).x
	if col.a*a <= 0.003: return w
	var base_y := at.y+(f.get_ascent(ipx)-f.get_descent(ipx))*0.5
	ci.draw_string(f,Vector2(roundf(at.x-w*align),roundf(base_y)),s,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,Color(col,col.a*a))
	return w

# --- Easing ------------------------------------------------------------------------------

## CSS cubic-bezier(x1,y1,x2,y2) at `x` in 0..1.
static func bez(x: float, x1: float, y1: float, x2: float, y2: float) -> float:
	if x <= 0.0: return 0.0
	if x >= 1.0: return 1.0
	var lo := 0.0
	var hi := 1.0
	var t := x
	for i in 24:
		var cx := _cubic(t,x1,x2)
		if absf(cx-x) < 0.0005: break
		if cx < x: lo = t
		else: hi = t
		t = (lo+hi)*0.5
	return _cubic(t,y1,y2)

static func _cubic(t: float, p1: float, p2: float) -> float:
	var u := 1.0-t
	return 3.0*u*u*t*p1+3.0*u*t*t*p2+t*t*t

## CSS ease-out.
static func ease_out(x: float) -> float:
	return bez(x,0.0,0.0,0.58,1.0)

## A slip arriving, `t` seconds after it opened: x is how far left of its
## place it still is (mock px, 18 to 0), y its alpha. Shift the slip's rect
## by `-x*k` and pass `y` as `a`.
static func slip_in(t: float) -> Vector2:
	var e := bez(t/T_SLIP,0.2,0.8,0.3,1.0)
	return Vector2(SLIP_CUT*(1.0-e),e)

# --- Shapes ------------------------------------------------------------------------------

## A filled convex polygon whose slanted edges are feathered one px (the
## project has no 2D MSAA; straight edges stay crisp).
static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var n := pts.size()
	if n < 3 or col.a <= 0.003: return
	ci.draw_colored_polygon(pts,col)
	var area := 0.0
	for i in n: area += pts[i].cross(pts[(i+1)%n])
	var out_sign := 1.0 if area > 0.0 else -1.0
	var clear := Color(col,0.0)
	for i in n:
		var p := pts[i]
		var q := pts[(i+1)%n]
		var d := q-p
		if absf(d.x) < 0.01 or absf(d.y) < 0.01: continue
		var out := Vector2(d.y,-d.x).normalized()*out_sign
		ci.draw_polygon(PackedVector2Array([p,q,q+out,p+out]),PackedColorArray([col,col,clear,clear]))

## A bar leaning 14 degrees (CSS skewX(-14deg) about its middle): the tick,
## an underline, a slider's mark, a charge cell, a chip's divider. `r` is
## the upright bar in screen px; one thinner than 1.6 px is drawn as a line.
static func slant(ci: CanvasItem, r: Rect2, col: Color) -> void:
	if col.a <= 0.003: return
	var dx := SKEW*r.size.y*0.5
	if r.size.x < 1.6:
		var cx := r.position.x+r.size.x*0.5
		ci.draw_line(Vector2(cx+dx,r.position.y),Vector2(cx-dx,r.end.y),col,maxf(r.size.x,1.0),true)
		return
	poly(ci,PackedVector2Array([Vector2(r.position.x+dx,r.position.y),Vector2(r.end.x+dx,r.position.y),
		Vector2(r.end.x-dx,r.end.y),Vector2(r.position.x-dx,r.end.y)]),col)

## A level hairline from `from` to x `to_x`, `thick` mock px, on whole pixels.
static func hair(ci: CanvasItem, from: Vector2, to_x: float, k: float, col: Color, thick := 1.0) -> void:
	if to_x <= from.x or col.a <= 0.003: return
	var t := maxf(roundf(thick*k),1.0)
	ci.draw_rect(Rect2(roundf(from.x),roundf(from.y-t*0.5),roundf(to_x-from.x),t),col)

# --- The slip ----------------------------------------------------------------------------

## The slip's outline in rect `r`: square but for the right edge, which runs
## SLIP_CUT in from top to bottom.
static func slip_pts(r: Rect2, k: float) -> PackedVector2Array:
	return PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),
		Vector2(r.end.x-SLIP_CUT*k,r.end.y),Vector2(r.position.x,r.end.y)])

## The x of the slip's slanted edge at screen height `y`.
static func slip_edge(r: Rect2, k: float, y: float) -> float:
	return r.end.x-SLIP_CUT*k*clampf((y-r.position.y)/maxf(r.size.y,1.0),0.0,1.0)

## The cream slip in `r`: its two shadows (a hard one 3 px under its foot, a
## soft one around it), the paper with its grain, the ink spine down the left. The
## caller sizes `r` to its rows first (the mock-up's slips: title 204 wide
## with 12 above and below the rows, the others 8 above and 12 below; pause
## 228, settings 452, controls 500, credits 440). `grain` is the grain's
## alpha (the chain's pennant uses 0.06).
static func slip(ci: CanvasItem, r: Rect2, k: float, a := 1.0, grain := GRAIN_A) -> void:
	if a <= 0.003: return
	if _shadow == null:
		_shadow = StyleBoxFlat.new()
		_shadow.bg_color = Color(0,0,0,0)
		_shadow.anti_aliasing = false
	var soft := roundi(30.0*k)
	_shadow.shadow_size = soft
	_shadow.shadow_color = Color(NIGHT,0.3*a*a)
	_shadow.shadow_offset = Vector2(0.0,12.0*k)
	_shadow.set_corner_radius_all(roundi(10.0*k))
	ci.draw_style_box(_shadow,r.grow(-12.0*k))
	var pts := slip_pts(r,k)
	ci.draw_rect(Rect2(r.position.x,r.end.y,r.size.x-SLIP_CUT*k,3.0*k),Color(NIGHT,0.4*a))
	poly(ci,pts,Color(PAPER,a))
	if grain > 0.0:
		var half := 46.0*k
		var x := r.position.x
		var i := 0
		while x < r.end.x:
			var x1 := minf(x+half,r.end.x)
			var c0 := Color(GRAIN,grain*a*float(i%2))
			var c1 := Color(GRAIN,grain*a*(1.0-float(i%2))*(x1-x)/half+c0.a*(1.0-(x1-x)/half))
			var band := PackedVector2Array([Vector2(x,r.position.y),Vector2(x1,r.position.y),Vector2(x1,r.end.y),Vector2(x,r.end.y)])
			if x1 <= r.end.x-SLIP_CUT*k:
				ci.draw_polygon(band,PackedColorArray([c0,c1,c1,c0]))
			else:
				for piece: PackedVector2Array in Geometry2D.intersect_polygons(band,pts):
					var cols := PackedColorArray()
					for p in piece: cols.append(c0.lerp(c1,clampf((p.x-x)/maxf(x1-x,0.001),0.0,1.0)))
					ci.draw_polygon(piece,cols)
			x += half
			i += 1
	ci.draw_rect(Rect2(r.position,Vector2(maxf(roundf(SPINE*k),1.0),r.size.y)),Color(INK,a))

## A section heading on a slip: the word in HEAD red, tracked wide, and a
## hairline from it to `pad_r` short of the slip's right. `y` is the top of
## its box, `h` the box's height and `pad_top` the padding inside it (the
## mock-up: 30 and 0 over a menu, 30 and 6 between settings groups, 34 and 8
## on the credits page; `pad_r` 34 on the pause slip, 38 elsewhere).
static func head(ci: CanvasItem, r: Rect2, y: float, k: float, label: String, h := 30.0, pad_top := 0.0, pad_r := 34.0, a := 1.0) -> void:
	var cy := y+(pad_top+(h-pad_top)*0.5)*k
	var x := r.position.x+LABEL_X*k
	var w := text(ci,MED,label.to_upper(),Vector2(x,cy),10.5,k,0.26,HEAD,0.0,a)
	hair(ci,Vector2(x+w+10.0*k,cy),r.end.x-pad_r*k,k,Color(RULE,RULE.a*a))

# --- Rows --------------------------------------------------------------------------------

## The rect of a row on slip `r` whose top is at screen `y` and which is `h`
## mock px tall: what the mouse hits, and what `row` returns.
static func row_rect(r: Rect2, y: float, k: float, h := 30.0) -> Rect2:
	return Rect2(r.position.x,y,r.size.x,h*k)

## The selection's furniture and the label, shared by every row. Returns
## the row's middle y.
static func _row_base(ci: CanvasItem, r: Rect2, y: float, k: float, label: String, sel_t: float, h: float, px: float, a: float) -> float:
	var cy := y+h*k*0.5
	var sel := sel_t >= 0.0
	var lean := ease_out(sel_t/T_LEAN) if sel else 1.0-ease_out(-sel_t/T_LEAN)
	if sel:
		var e := ease_out(sel_t/T_BAND)
		var left := r.position.x+SPINE*k
		var right := left+(r.end.x-left)*(0.55+0.45*e)
		var band := PackedVector2Array([Vector2(left,y+2.0*k),Vector2(right,y+2.0*k),Vector2(right,y+(h-2.0)*k),Vector2(left,y+(h-2.0)*k)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(band,slip_pts(r,k)):
			poly(ci,piece,Color(BAND,BAND.a*e*a))
		var te := bez(sel_t/T_TICK,0.2,0.9,0.3,1.4)
		slant(ci,Rect2(r.position.x+(17.0-9.0*(1.0-te))*k,cy-7.5*k,4.0*k,15.0*k),Color(TICK,clampf(te,0.0,1.0)*a))
	var at := Vector2(r.position.x+(LABEL_X+LEAN*lean)*k,cy)
	if sel: text(ci,NUM,label.to_upper(),at,px,k,0.085,INK,0.0,a)
	else: text(ci,MED,label.to_upper(),at,px,k,0.1,LAND,0.0,a)
	return cy

## A menu row on slip `r`, its top at screen `y`: the label (upper-cased;
## at rest upright in LAND, selected italic in INK and leaning 8 px right),
## and when selected the band behind it and the tick before it, both run
## in by `sel_t`. `key` is a quiet hint ended `key_pad` from the slip's
## right ("Esc", "J"; the mock-up pads it 36 on the pause slip, 42 on a
## Back row). `h` is 32 on the title slip, 30 on pause and Back, with `px`
## 16 on a menu and 15 on the settings, controls and credits pages. A gap
## before a row (8 before Quit) is the caller's: add it to `y`.
## Returns the row's rect for the mouse.
static func row(ci: CanvasItem, r: Rect2, y: float, k: float, label: String, sel_t := OFF, h := 30.0, px := 16.0, key := "", key_pad := 36.0, a := 1.0) -> Rect2:
	var cy := _row_base(ci,r,y,k,label,sel_t,h,px,a)
	if not key.is_empty():
		text(ci,MED,key.to_upper(),Vector2(r.end.x-key_pad*k,cy),10.5,k,0.14,DIM,1.0,a)
	return row_rect(r,y,k,h)

## Where a value row's options sit: one rect per option, right to left from
## VALUE_PAD short of the slip's right, 16 apart, each as tall as the row.
## `on` is the chosen one (its italic is a little wider).
static func seg_rects(r: Rect2, y: float, k: float, opts: PackedStringArray, on: int, h := 28.0) -> Array[Rect2]:
	var out: Array[Rect2] = []
	out.resize(opts.size())
	var x := r.end.x-VALUE_PAD*k
	for i in range(opts.size()-1,-1,-1):
		var w := text_w(NUM,opts[i].to_upper(),13.5,k,0.07) if i == on else text_w(MED,opts[i].to_upper(),13.5,k,0.08)
		out[i] = Rect2(x-w,y,w,h*k)
		x -= w+16.0*k
	return out

## A value row that picks one of `opts`: the row's label as `row` draws it,
## and the options at its right, the chosen one (`on`) italic in INK over a
## slanted underline, the others upright in DIM. `on_t` is the seconds since
## the choice changed (the underline runs in over T_BAND). Left and Right
## change `on` in the mock-up, Enter cycles it, a click picks.
## Returns the options' rects for the mouse.
static func seg_row(ci: CanvasItem, r: Rect2, y: float, k: float, label: String, opts: PackedStringArray, on: int, sel_t := OFF, on_t := ON, h := 28.0, px := 15.0, a := 1.0) -> Array[Rect2]:
	var cy := _row_base(ci,r,y,k,label,sel_t,h,px,a)
	var rects := seg_rects(r,y,k,opts,on,h)
	for i in opts.size():
		var o := rects[i]
		if i != on:
			text(ci,MED,opts[i].to_upper(),Vector2(o.position.x,cy),13.5,k,0.08,DIM,0.0,a)
			continue
		text(ci,NUM,opts[i].to_upper(),Vector2(o.position.x,cy),13.5,k,0.07,INK,0.0,a)
		var e := ease_out(on_t/T_BAND)
		var w := (o.size.x-1.0*k)*(0.55+0.45*e)
		slant(ci,Rect2(o.position.x,cy+9.1*k,w,2.0*k),Color(INK,e*a))
	return rects

## Where a slider row's track sits: the 132 x 22 box the mouse drags in.
static func slider_rect(r: Rect2, y: float, k: float, h := 28.0) -> Rect2:
	return Rect2(r.end.x-(VALUE_PAD+26.0+12.0+SLIDER.x)*k,y+(h-SLIDER.y)*k*0.5,SLIDER.x*k,SLIDER.y*k)

## The slider's value, 0..1, for a click or drag at screen x `x` on `track`.
static func slider_frac(track: Rect2, x: float) -> float:
	return clampf((x-track.position.x)/maxf(track.size.x,1.0),0.0,1.0)

## A value row with a slider: the row's label, a hairline track filled in
## ink up to `frac` (0..1) with a slanted mark on it (TICK red while the row
## is selected, ink at rest), and `value` as a numeral at the right (the
## mock-up shows 0 to 100 in steps of 5, and the sensitivity as 0.2 to 2.0).
## Returns the track's rect for the mouse.
static func slider_row(ci: CanvasItem, r: Rect2, y: float, k: float, label: String, frac: float, value: String, sel_t := OFF, h := 28.0, px := 15.0, a := 1.0) -> Rect2:
	var cy := _row_base(ci,r,y,k,label,sel_t,h,px,a)
	var track := slider_rect(r,y,k,h)
	var f := clampf(frac,0.0,1.0)
	var line_y := track.position.y+11.0*k
	hair(ci,Vector2(track.position.x,line_y),track.end.x,k,Color(TRACK,TRACK.a*a),2.0)
	hair(ci,Vector2(track.position.x,line_y),track.position.x+track.size.x*f,k,Color(INK,a),2.0)
	slant(ci,Rect2(track.position.x+track.size.x*f-2.0*k,track.position.y+4.0*k,4.0*k,14.0*k),Color(TICK if sel_t >= 0.0 else INK,a))
	text(ci,NUM,value,Vector2(r.end.x-VALUE_PAD*k,cy),14.5,k,0.0,INK,1.0,a)
	return track

# --- The controls page -------------------------------------------------------------------

## One line of the controls page, 25 tall: what it does (upper-cased, LAND),
## then its keys and its pad buttons in the italic face, in columns 160
## apart. A pad cell with no binding is an en dash. `y` is the row's top.
static func ctrl_row(ci: CanvasItem, r: Rect2, y: float, k: float, action: String, keys: String, pad: String, a := 1.0) -> void:
	var cy := y+12.5*k
	var x := r.position.x+LABEL_X*k
	text(ci,MED,action.to_upper(),Vector2(x,cy),14.0,k,0.09,LAND,0.0,a)
	text(ci,NUM,keys,Vector2(x+160.0*k,cy),14.0,k,0.05,INK,0.0,a)
	text(ci,NUM,pad if not pad.is_empty() else "–",Vector2(x+320.0*k,cy),14.0,k,0.05,INK,0.0,a)

## The controls page's column names, 22 tall, over the keys and the pad.
static func ctrl_cols(ci: CanvasItem, r: Rect2, y: float, k: float, keys := "Keyboard and mouse", pad := "Gamepad", a := 1.0) -> void:
	var x := r.position.x+LABEL_X*k
	text(ci,MED,keys.to_upper(),Vector2(x+160.0*k,y+11.0*k),10.5,k,0.14,DIM,0.0,a)
	text(ci,MED,pad.to_upper(),Vector2(x+320.0*k,y+11.0*k),10.5,k,0.14,DIM,0.0,a)

## The hairline between groups of controls. It takes 12 of height: 7 down to
## the line, 5 under it.
static func ctrl_rule(ci: CanvasItem, r: Rect2, y: float, k: float, a := 1.0) -> void:
	hair(ci,Vector2(r.position.x+LABEL_X*k,y+7.0*k),r.end.x-VALUE_PAD*k,k,Color(RULE_SOFT,RULE_SOFT.a*a))

# --- Chips -------------------------------------------------------------------------------

## The dark chip's plate in `r`: square but for one edge cut PLATE_CUT in.
## A chip on the left of the screen is cut on its right, from the top corner
## in to the bottom; with `right` (a chip on the right of the screen) it is
## cut on its left, from the bottom corner in to the top.
static func plate(ci: CanvasItem, r: Rect2, k: float, right := false, a := 1.0, col := PLATE) -> void:
	var cut := PLATE_CUT*k
	var pts := PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),Vector2(r.end.x-cut,r.end.y),Vector2(r.position.x,r.end.y)])
	if right: pts = PackedVector2Array([Vector2(r.position.x+cut,r.position.y),Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
	poly(ci,pts,Color(col,col.a*a))

## One piece of a run of text on a chip: `s` in a face at `px` mock px,
## tracked `track` em, `gap` mock px after the piece before it, `dy` mock px
## below the run's middle line.
static func part(s: String, which: int, px: float, track: float, col: Color, gap := 0.0, dy := 0.0) -> Dictionary:
	return {"s":s,"f":which,"px":px,"tr":track,"col":col,"gap":gap,"dy":dy}

## A blank piece `w` mock px wide (`gap` before it): room for a glyph, a
## divider or the charge cells, which the caller draws at the place `run_x`
## gives.
static func room(w: float, gap := 0.0) -> Dictionary:
	return {"w":w,"gap":gap}

## The width of a run, in screen px.
static func run_w(parts: Array, k: float) -> float:
	return run_x(parts,k,parts.size())

## How far from the run's left piece `i` starts, in screen px.
static func run_x(parts: Array, k: float, i: int) -> float:
	var x := 0.0
	for j in parts.size():
		var p: Dictionary = parts[j]
		x += float(p.get("gap",0.0))*k
		if j == i: return x
		if p.has("w"): x += float(p["w"])*k
		else: x += text_w(int(p["f"]),str(p["s"]),float(p["px"]),k,float(p["tr"]))
	return x

## Draws a run of `part`s left to right from `at` (its left edge and middle
## line). Returns its width.
static func run(ci: CanvasItem, parts: Array, at: Vector2, k: float, a := 1.0) -> float:
	var x := 0.0
	for p: Dictionary in parts:
		x += float(p.get("gap",0.0))*k
		if p.has("w"): x += float(p["w"])*k
		else:
			var col: Color = p["col"]
			x += text(ci,int(p["f"]),str(p["s"]),at+Vector2(x,float(p["dy"])*k),float(p["px"]),k,float(p["tr"]),col,0.0,a)
	return x

## A dark chip sized to a run of `part`s and the run on it. `at` is the
## chip's top-left corner, or with `right` its top-right corner (the chip
## then grows leftward and is cut on its left). `h` is its height, `pad`
## the padding on its square side and `pad_cut` on its cut side (the
## mock-up: finds chip 28 / 10 / 20, money 28 / 9 / 20, region tag
## 24 / 14 / 20, toast 24 / 12 / 20, the speed and charge plate
## 26 / 12 / 20 from the right). Returns the chip's rect: the run starts
## `pad*k` in from its left when cut on the right, `pad_cut*k` in with
## `right`; add `run_x` for a `room`.
static func chip(ci: CanvasItem, parts: Array, at: Vector2, k: float, h := 24.0, pad := 12.0, pad_cut := 20.0, right := false, a := 1.0, col := PLATE) -> Rect2:
	var w := run_w(parts,k)+(pad+pad_cut)*k
	var r := Rect2(at.x-(w if right else 0.0),at.y,w,h*k)
	plate(ci,r,k,right,a,col)
	run(ci,parts,Vector2(r.position.x+(pad_cut if right else pad)*k,r.position.y+h*k*0.5),k,a)
	return r

# --- Prompts and key plates --------------------------------------------------------------

## Picks the device's label out of prompt triples `[keys, pad, word]`:
## returns `[label, word]` pairs for `prompts`, dropping a prompt the device
## has no binding for (an empty label). `pad` defaults to the device last
## used (scripts/pad.gd); listen on `Pad.hub.device_changed` to redraw.
static func pick(triples: Array, pad := Pad.using_pad()) -> Array:
	var out := []
	for t: Array in triples:
		var label := str(t[1] if pad else t[0])
		if not label.is_empty(): out.append([label,str(t[2])])
	return out

## A strip of prompts on one dark chip: each `[label, word]` pair is the
## key or button in the italic face and what it does beside it, 18 between
## pairs. The menus' footer is the default: words upper-cased, the chip 24
## tall, cut on its left, `at` its top-right corner (the mock-up ends it at
## right 28, bottom 26). With `hint` it is the flight's hint: words as
## given, a little larger, and with `right` false the chip is cut on its
## right and `at` is its top-left corner (the mock-up starts it at left 28,
## bottom 26). Returns the chip's rect.
static func prompts(ci: CanvasItem, pairs: Array, at: Vector2, k: float, right := true, hint := false, a := 1.0) -> Rect2:
	var parts := []
	for i in pairs.size():
		var pair: Array = pairs[i]
		var word := str(pair[1])
		if hint:
			parts.append(part(str(pair[0]),NUM,12.5,0.06,CREAM,18.0 if i > 0 else 0.0))
			parts.append(part(word,MED,12.0,0.08,PALE,6.0))
		else:
			parts.append(part(str(pair[0]),NUM,12.0,0.08,CREAM,18.0 if i > 0 else 0.0))
			parts.append(part(word.to_upper(),MED,11.5,0.1,PALE,6.0))
	return chip(ci,parts,at,k,24.0,12.0,20.0,right,a)

## A key plate: one key and its verb on a small chip cut on its left, `at`
## its top-right corner (the mock-up: right 28, bottom 60, above the charge
## plate). At rest the key is gilt and the word cream on the dark plate;
## `held` turns the plate gold and both to ink. Returns the plate's rect.
static func key_plate(ci: CanvasItem, key: String, word: String, at: Vector2, k: float, held := false, a := 1.0) -> Rect2:
	var parts := [part(key,NUM,13.0,0.0,INK if held else GOLD),part(word.to_upper(),MED,10.5,0.2,INK if held else CREAM,7.0)]
	return chip(ci,parts,at,k,22.0,11.0,18.0,true,a,GOLD if held else PLATE)
