extends "res://scripts/endless/near_miss_hud_handoff.gd"
## The near misses as the "Line HUD Redesign" canvas's C2 draws them
## ("Minimal ring + glyphs & sheen", 2026-10-28): the ring is the medallion.
## Hung off the plane's upper left, tilted ANGLE_C; sizes are the canvas's
## mock px (M), scaled by min(w/2560, h/1440) x SCALE. The surge meter stays
## in the lower right corner (the handoff tag's). Uses the handoff HUD's text,
## gleam, bar and time-hold helpers; the same calls.
## - the ring: a dark disc, its arc the bank timer (NearMiss `bank_left`) in
##   the multiplier's heat, growing RING_PX and glowing as it heats. Each pass
##   pops its faceted glyph into the ring at 135% (scripts/endless/near_glyphs.gd),
##   a sheen crosses it, then the move's name, then a bright dash orbits the arc.
## - beside it: the total with the italic multiplier; under them the feed, the
##   line's runs newest on top (LineScore's: TREES ×7 +1,480), each a row that
##   counts up as it grows, a flourish's marked in gold, the multiplier's step
##   flying into the multiplier as it's earned. The newest row carries the
##   pass's biggest factor when it was close (not FAST: flat out it's on
##   everything). A filler moment (a near pull-out) only ticks the total. Under
##   the ring, how close the last pass came (any pass), in its band's colour.
## - the bank: the arc closes gold, the coin lands in the ring, the trail
##   flies into it and the paid number slams and counts up; then the ring
##   shrinks and a cream banner hangs under it on a pole. A scored line's recap:
##   its runs in order, the sum and the money, its closest pass, average speed
##   and time, and its name if any. A prize, or
##   a line under --line-score=old: the moves' medallions stamped on it as seals,
##   the land crossed, the name and the money. A broad sheen sweeps the cloth.
## - a scrape or crash: the ring shatters in coral round the cracked glyph of
##   what was hit, LINE LOST and the loss, the trail falling away greyed.

const SCALE := 1.25
const ANGLE_C := -0.105
## The ring's top left off the plane on screen (M).
const RING_AT := Vector2(-450.0,-170.0)
## The ring across (M) cool and at the cap; the glyph inside as a share of it.
const RING_PX := Vector2(72.0,84.0)
const GLYPH_SHARE := 44.0/72.0
const COL_GAP := 14.0
const TOTAL_M := 44.0
const MULT_M := Vector2(26.0,34.0)
const MOVE_M := 20.0
## The feed's rows, newest first: text size (M) and opacity; the tag's size.
const FEED_ROWS := [[22.0,1.0],[18.0,0.85],[16.0,0.7]]
const TAG_M := 15.0
## How close the last pass came, under the ring (M).
const CLEAR_M := 24.0
## A multiplier step: its size (M) for a switch and a flourish, how long it
## shows, and when it starts flying into the multiplier (s).
const STEP_M := Vector2(24.0,38.0)
const STEP_TIME := 0.7
const STEP_FLY := 0.4
## The bank's recap: its most runs in the shape.
const SHAPE_MOST := 5
## The trail: medallion sizes and opacities, newest first.
const TRAIL := [[20.0,1.0],[18.0,0.85],[16.0,0.7],[14.0,0.55]]
## The bank: the slam's number by tier (M), the read-back's ring and number,
## and how long the banner hangs (s, from the read-back's start).
const SLAM_M := [52.0,60.0,72.0]
const READ_RING := 52.0
const READ_NUM := 46.0
const BANNER_TIME := 2.8
const LOSS_TIME := 1.4

const CLOTH := Color("f4eedc")
const INK := Color("1b1d22")
const LAND_INK := Color("3a3a36")
const NAME_INK := Color("8c2a16")
const DISC := Color("16181d")
const GLINT := Color("fff8df")
const GLINT_TEXT := Color("fff3c9")
const CLOSE_C := Color("f7dc8a")

var _moves: Array = []
## The feed: each run's row age (s, by its index in the line), the newest pass's
## tag {run, text, razor}, and the multiplier's steps in flight {text, age, big}.
var _row_age := {}
var _tag := {}
var _steps: Array = []
## The last pass's clearance {m, band, age}, a filler's too.
var _clear := {}
var _barlow := {}
## The surge roll's ready mark (`_draw_ready`): where (block px), how big, its
## word's size and how long it shows (s).
const READY_AT := Vector2(-44.0,6.0)
const READY_PX := 38.0
const READY_TEXT := 15.0
const READY_WORD := 2.0
var _ready_age := 0.0

func _ready() -> void:
	tag = true

## Always by the plane: H has no top layout to switch to.
func set_tag(_on: bool, _keep := true) -> void:
	tag = true

func _s() -> float:
	return _k()*SCALE

## Barlow 800 at `px`, tracked `track` em.
func _bw(px: float, track: float) -> FontVariation:
	var key := "%d/%d" % [roundi(px),roundi(track*100.0)]
	if _barlow.has(key): return _barlow[key]
	var f := FontVariation.new()
	f.base_font = NUMS
	f.spacing_glyph = roundi(px*track)
	_barlow[key] = f
	return f

func show_state(delta: float, near: NearMiss, on: bool, events: Dictionary) -> void:
	visible = on
	_near = near
	_release_hold()
	if not on:
		_prev_chain = near.chain_points
		_prev_mult = near.multiplier()
		_anchored = false
		return
	_clock += delta
	if events.has("near"):
		var m: Dictionary = events.near
		var band := str(m.band)
		if band == "razor": _hold(0.25,50)
		if not _bank.is_empty() and not _bank.has("cut"): _bank.cut = float(_bank.age)
		if not _loss.is_empty(): _loss.age = maxf(float(_loss.age),LOSS_TIME-0.2)
		if is_finite(float(m.clear)): _clear = {"m":float(m.clear),"band":band,"age":0.0}
		var filler := bool(m.get("filler",false))
		# A filler moment takes no pop; the ring needs a glyph only if it's the line's first.
		if not filler or _moves.is_empty():
			_moves.push_front({"id":Glyphs.for_moment(m),"kind":str(m.kind).to_upper(),"band":band,
				"points":float(m.points),"clear":float(m.clear),"age":1.0 if filler else 0.0})
			if _moves.size() > 64: _moves.resize(64)
		if not filler:
			_jolt = 0.0
			_row_note(m,near.line_new)
	if events.has("banked"):
		var pts := float(events.banked.points)
		var tier := 0 if pts < 2000.0 else (1 if pts < 10000.0 else 2)
		var line: Dictionary = events.banked.get("line",{})
		_bank = {"age":0.0,"points":pts,"chain":_prev_chain,"mult":float(line.get("mult",_prev_mult)),
			"tier":tier,"line":line,"trail":_moves.slice(0,TRAIL.size()+1),"heat":_heat}
		_moves = []
		_feed_clear()
	var crash := events.has("crash")
	if crash or events.has("scrape"):
		var hit: Dictionary = events.get("crash",events.get("scrape",{}))
		var lost := float((events.get("lost",{}) as Dictionary).get("points",0.0))
		_loss = {"age":0.0,"chain":_prev_chain,"lost":lost,"crash":crash,"what":str(hit.get("what","land")),
			"trail":_moves.slice(0,TRAIL.size()),"heat":_heat,"seed":randi()}
		_bank = {}
		_moves = []
		_feed_clear()
		if _prev_chain >= 1.0: _hold(0.0,60)
	for m: Dictionary in _moves: m.age += delta
	for run: int in _row_age: _row_age[run] = float(_row_age[run])+delta
	for st: Dictionary in _steps: st.age += delta
	if not _clear.is_empty(): _clear.age = float(_clear.age)+delta
	_steps = _steps.filter(func(st: Dictionary) -> bool: return float(st.age) < STEP_TIME)
	# The total ticks over 0.35 s, ease-out.
	var target := maxf(near.chain_points,0.0)
	if target <= 0.0:
		_total_from = 0.0
		_total_to = 0.0
		_total_t = 1.0
	elif absf(target-_total_to) > 0.5:
		_total_from = _shown
		_total_to = target
		_total_t = 0.0
	_total_t = minf(_total_t+delta/0.35,1.0)
	_shown = lerpf(_total_from,_total_to,1.0-pow(1.0-_total_t,3.0))
	_jolt += delta
	var mult := near.multiplier()
	if mult > _last_mult+0.01: _mult_kick = 0.0
	_last_mult = mult
	_mult_kick += delta
	_heat = lerpf(_heat,_mult_heat(mult),minf(1.0,delta*10.0))
	if near.chain_points <= 0.0 and _bank.is_empty() and _loss.is_empty():
		_moves = []
		_feed_clear()
	if not _bank.is_empty():
		_bank.age += delta
		if float(_bank.age) >= _bank_end(): _bank = {}
	if not _loss.is_empty():
		_loss.age += delta*(1.4 if bool(_loss.crash) else 1.0)
		if float(_loss.age) >= LOSS_TIME: _loss = {}
	_flare = maxf(_flare-delta,0.0)
	_meter_rise(near)
	_place_ring()
	_prev_chain = near.chain_points
	_prev_mult = mult
	queue_redraw()
	_block.queue_redraw()

## The newest pass `m` into the feed: its row's age, its tag, its multiplier step.
func _row_note(m: Dictionary, stepped: bool) -> void:
	var run := int(m.get("run",-1))
	_row_age[run] = 0.0
	_tag = {}
	var band := str(m.band)
	if band == "razor": _tag = {"run":run,"text":"RAZOR","razor":true}
	elif band == "close":
		for word: String in m.get("tags",[]):
			if word != "FAST":
				_tag = {"run":run,"text":word,"razor":false}
				break
	var step := float(m.get("line_step",0.0))
	if stepped and step > 0.0: _steps.append({"text":"+%s" % String.num(step,1),"age":0.0,"big":bool(m.get("flourish",false))})

func _feed_clear() -> void:
	_row_age = {}
	_tag = {}
	_steps = []
	_clear = {}

func _place_ring() -> void:
	var s := _s()
	var to := _plane_screen()+RING_AT*s
	to = Vector2(clampf(to.x,40.0*_k(),size.x-420.0*s),clampf(to.y,60.0*_k(),size.y-320.0*s))
	_anchor = to if not _anchored else _anchor.lerp(to,minf(1.0,get_process_delta_time()*FOLLOW))
	_anchored = true
	_block.position = _anchor
	_block.rotation = ANGLE_C

# --- The bank's times ------------------------------------------------------------

func _slam_end() -> float:
	return 0.15+float([0.4,0.8,1.2][int(_bank.tier)])+0.25

## When the read-back (the small ring and the banner) starts.
func _read_at() -> float:
	return _slam_end()

func _bank_end() -> float:
	var end := _slam_end()+0.3
	if not (_bank.line.get("moves",[]) as Array).is_empty(): end = _read_at()+BANNER_TIME
	if _bank.has("cut"): end = minf(end,float(_bank.cut)+0.2)
	return end

## The bank's fade: out over its last 0.3 s (0.2 when cut).
func _bank_alpha() -> float:
	var end := _bank_end()
	var fade := 0.2 if _bank.has("cut") else 0.3
	return 1.0-smoothstep(end-fade,end,float(_bank.age))

# --- Drawing ---------------------------------------------------------------------

func _draw_block() -> void:
	if _near == null: return
	var s := _s()
	if not _bank.is_empty(): _draw_bank_c(s)
	elif not _loss.is_empty(): _draw_loss_c(s)
	elif _near.chain_points >= 1.0 and not _moves.is_empty(): _draw_live(s)
	_draw_ready(s)

## The surge roll ready (a full meter, not being spent): a small gilt sunburst
## breathing by the tag, its word only for READY_WORD s after it fills. No disc
## behind it: on the land a dark disc is all that reads.
func _draw_ready(s: float) -> void:
	if _near.meter < 0.999 or _near.surge > 0.0:
		_ready_age = 0.0
		return
	_ready_age += get_process_delta_time()
	var breath := 0.5+0.5*sin(_clock*TAU*0.55)
	var c := READY_AT*s
	var px := roundf(READY_PX*s/2.0)*2.0
	var sz := px*Glyphs.BOX/24.0
	var r := Rect2(c-Vector2.ONE*sz*0.5,Vector2.ONE*sz)
	var shadow := Glyphs.texture("surge","shadow",px)
	if shadow != null: _block.draw_texture_rect(shadow,Rect2(r.position+Vector2(0.0,2.0)*s,r.size),false,Color(0.08,0.05,0.03,0.6))
	_block.draw_texture_rect(Glyphs.texture("surge","icon",px),r,false,Color.WHITE)
	var lit := Glyphs.texture("surge","lit",px)
	if lit != null: _block.draw_texture_rect(lit,r,false,Color(1,1,1,0.05+0.35*breath))
	var a := 1.0-smoothstep(READY_WORD-0.5,READY_WORD,_ready_age)
	if a > 0.0: _txt(_block,_bw(READY_TEXT,0.14),"ROLL",c+Vector2(0.0,READY_PX*0.82)*s,READY_TEXT*s,Color(GLINT_TEXT,a),6.0*s)

## The ring centred `c`, `px` across (screen px): a disc, its track, the arc
## `share` full from the top clockwise in `col`, glowing `glow`.
func _ring(c: Vector2, px: float, share: float, col: Color, track: Color, glow: Color, glow_px: float, alpha: float) -> void:
	var r := px*31.0/72.0
	var w := px*4.0/72.0
	if glow.a > 0.0 and glow_px > 0.0:
		for i in 4:
			_block.draw_circle(c,r+w*0.5+glow_px*(4-i)/4.0,Color(glow,glow.a*0.16*alpha))
	_block.draw_circle(c,r+w*0.5+1.5*_k(),Color(KEY,alpha))
	_block.draw_circle(c,r,Color(DISC,alpha))
	_block.draw_arc(c,r,0.0,TAU,64,Color(track,track.a*alpha),w,true)
	if share > 0.002:
		var a0 := -PI*0.5
		var a1 := a0+TAU*clampf(share,0.0,1.0)
		_block.draw_arc(c,r,a0,a1,maxi(8,roundi(64*share)),Color(col,alpha),w,true)
		_block.draw_circle(c+Vector2.from_angle(a0)*r,w*0.5,Color(col,alpha))
		_block.draw_circle(c+Vector2.from_angle(a1)*r,w*0.5,Color(col,alpha))

## The bright dash orbiting the ring once, `t` 0 to 1.
func _orbit(c: Vector2, px: float, t: float, alpha: float) -> void:
	if t <= 0.0 or t >= 1.0: return
	var r := px*31.0/72.0
	var w := px*4.0/72.0
	var e := 1.0-pow(1.0-t,2.0)
	var head := -PI*0.5+TAU*e
	var a := alpha*smoothstep(0.0,0.08,t)*(1.0-smoothstep(0.85,1.0,t))
	_block.draw_arc(c,r,head-0.45,head,10,Color(GLINT,a),w,true)
	_block.draw_circle(c+Vector2.from_angle(head)*r,w*0.5,Color(GLINT,a))

## A faceted glyph `px` across its 24-unit box, centred `c`, scaled `grow`.
func _glyph(id: String, c: Vector2, px: float, grow: float, alpha: float) -> void:
	var tex := Glyphs.texture(id,"icon",px*grow)
	if tex == null: return
	var sz := px*grow*Glyphs.BOX/24.0
	_block.draw_texture_rect(tex,Rect2(c-Vector2.ONE*sz*0.5,Vector2.ONE*sz),false,Color(1,1,1,alpha))

## The pop into the ring: 135% to 94% to 100% over 0.22 s.
static func _pop(age: float) -> float:
	if age < 0.1: return lerpf(1.35,0.94,smoothstep(0.0,0.1,age))
	return lerpf(0.94,1.0,smoothstep(0.1,0.22,age))

## A medallion (near_badges.gd) `px` across centred `c` (in `base`'s frame),
## turned `rot`; the transform is left at `base`.
func _medal(id: String, band: String, c: Vector2, px: float, alpha: float, rot := 0.0, base := Transform2D.IDENTITY) -> void:
	if px < 2.0 or alpha <= 0.01: return
	var tex := Badges.texture(id,band,px)
	if tex == null: return
	_block.draw_set_transform_matrix(base*Transform2D(rot,c))
	_block.draw_texture_rect(tex,Rect2(-Vector2.ONE*px*0.5,Vector2.ONE*px),false,Color(1,1,1,alpha))
	_block.draw_set_transform_matrix(base)

## `text` left-aligned at `at` (its middle at at.y), keylined, a light band
## crossing it at `t` (0 to 1; none outside).
func _glint_word(font: Font, text: String, at: Vector2, px: float, col: Color, stroke: float, t: float, shine := GLINT_TEXT) -> void:
	_txt(_block,font,text,at,px,col,stroke,1.0,0.0,Color(0,0,0,0),0.0,0.0)
	if t <= 0.0 or t >= 1.0 or col.a <= 0.01: return
	var ipx := maxi(roundi(px),4)
	var w := _width(font,text,px)
	var band := lerpf(-0.25,1.25,t)*w
	var reach := maxf(w*0.18,px*0.6)
	for i in text.length():
		var pre := font.get_string_size(text.substr(0,i),HORIZONTAL_ALIGNMENT_LEFT,-1,ipx).x
		var cw := font.get_string_size(text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,ipx).x
		var k := 1.0-absf(pre+cw*0.5-band)/reach
		if k <= 0.0: continue
		var c := shine if k < 0.75 else GOLD.lerp(shine,0.4)
		_block.draw_string(font,at+Vector2(pre,ipx*0.35),text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,Color(c,k*col.a))

func _band_col(band: String) -> Color:
	return GOLD if band == "razor" else (CLOSE_C if band == "close" else NEAR_C)

## The ring's size at the heat.
func _ring_px(heat: float, s: float) -> float:
	return lerpf(RING_PX.x,RING_PX.y,smoothstep(0.0,0.6,heat))*s

# --- Flying: the ring, the total, the newest pass, the trail ---------------------

func _draw_live(s: float) -> void:
	var m: Dictionary = _moves[0]
	var age := float(m.age)
	var heat := _heat
	var px := _ring_px(heat,s)
	var c := Vector2.ONE*px*0.5
	var col: Color = _ramp(HEAT,maxf(heat,0.25))
	var glow: Color = _ramp(GLOW,heat)
	var share := clampf(_near.bank_left/_near.bank_after(),0.0,1.0)
	_ring(c,px,share,col,Color(CREAM,0.25),glow,float(_ramp(GLOW_PX,heat))*s,1.0)
	_orbit(c,px,(age-0.12)/0.33,1.0)
	# The newest glyph, popping in, and its sheen.
	var gpx := px*GLYPH_SHARE
	_glyph(str(m.id),c,gpx,_pop(age),smoothstep(0.0,0.04,age))
	if age > 0.04 and age < 0.5: _gleam(c,gpx*0.5,(age-0.04)/0.42,0.55,1.0)
	# The column beside it.
	var x := px+COL_GAP*s
	var tpx := TOTAL_M*s
	var y := tpx*0.5
	var text := _grouped(_shown)
	var j := 1.0-smoothstep(0.0,0.14,_jolt)
	_txt(_block,_nums,text,Vector2(x,y-3.0*s*j),tpx,CREAM,4.0*s,1.0+0.08*j,0.0,Color(0,0,0,0),0.0,0.0)
	var tw := _width(_nums,text,tpx)*(1.0+0.08*j)
	var mult_at := Vector2(x+tw+10.0*s,y+3.0*s)
	_mult_c(_near.multiplier(),mult_at,s,1.0)
	_draw_feed(Vector2(x,tpx+8.0*s),s)
	_draw_steps(mult_at,s)
	# How close the last pass came, under the ring, in its band's colour.
	if not _clear.is_empty():
		var near_px := CLEAR_M*s
		var near_at := Vector2(c.x,px+near_px*0.5+4.0*s)
		_txt(_block,_nums,"%s m" % _metres(float(_clear.m)),near_at,near_px,_band_col(str(_clear.band)),3.0*s,_pop(float(_clear.age)))

## The feed from `at` (its top left): the line's last runs, newest on top. Each
## row's name, its points, the step its first moment earned and, on the newest,
## the pass's tag.
func _draw_feed(at: Vector2, s: float) -> void:
	var runs: Array[Dictionary] = _near.score_line.runs
	var ppu := float(LineScore.tune().points_per_unit)
	var y := at.y
	for i in mini(runs.size(),FEED_ROWS.size()):
		var index := runs.size()-1-i
		var run: Dictionary = runs[index]
		var px := float(FEED_ROWS[i][0])*s
		var age := float(_row_age.get(index,1.0))
		var a := float(FEED_ROWS[i][1])*smoothstep(0.0,0.08,age)
		y += px*0.5
		var cx := at.x
		var name_f := _bw(px,0.06)
		var name_text := LineScore.Line.label(run)
		var flourish := bool(run.flourish)
		if flourish:
			_txt(_block,name_f,"FLOURISH",Vector2(cx,y),px,Color(GOLD,a),3.0*s,1.0,0.0,Color(0,0,0,0),0.0,0.0)
			cx += _width(name_f,"FLOURISH",px)+8.0*s
		_glint_word(name_f,name_text,Vector2(cx,y),px,Color(CREAM,a),3.0*s,(age-0.12)/0.3)
		cx += _width(name_f,name_text,px)+8.0*s
		var pts := "+"+_grouped(LineScore.Line.paid(run)*ppu)
		_txt(_block,_nums,pts,Vector2(cx,y),px,Color(CREAM,a),3.0*s,1.0,0.0,Color(0,0,0,0),0.0,0.0)
		cx += _width(_nums,pts,px)+8.0*s
		if float(run.step) > 0.0:
			var step := "+%s" % String.num(float(run.step),1)
			_txt(_block,_nums_i,step,Vector2(cx,y),px,Color(GOLD if flourish else CLOSE_C,a),3.0*s,1.0,0.0,Color(0,0,0,0),0.0,0.0)
			cx += _width(_nums_i,step,px)+8.0*s
		if i == 0 and int(_tag.get("run",-1)) == index:
			var tag_f := _bw(TAG_M*s,0.14)
			_txt(_block,tag_f,str(_tag.text),Vector2(cx,y+1.0*s),TAG_M*s,Color(GOLD if bool(_tag.razor) else CLOSE_C,a),3.0*s,1.0,0.0,Color(0,0,0,0),0.0,0.0)
		y += px*0.5+5.0*s

## The multiplier's steps: each pops out beside the multiplier at `to`, holds,
## then flies into it. A flourish's is bigger and glows.
func _draw_steps(to: Vector2, s: float) -> void:
	var width := _width(_nums_i,"×%s" % String.num(_near.multiplier(),1),lerpf(MULT_M.x,MULT_M.y,_heat)*s)
	var from := to+Vector2(width+14.0*s,0.0)
	for st: Dictionary in _steps:
		var age := float(st.age)
		var big := bool(st.big)
		var fly := smoothstep(STEP_FLY,STEP_TIME,age)
		var a := smoothstep(0.0,0.05,age)*(1.0-smoothstep(0.75,1.0,age/STEP_TIME))
		var px := (STEP_M.y if big else STEP_M.x)*s*lerpf(1.0,0.6,fly)
		var col: Color = GOLD if big else CLOSE_C
		var glow := Color(1.0,0.75,0.27,0.7*a) if big else Color(0,0,0,0)
		_txt(_block,_nums_i,str(st.text),from.lerp(to,fly),px,Color(col,a),4.0*s,_pop(age),0.0,glow,14.0*s if big else 0.0,0.0)

## The multiplier, italic, left-aligned at `at`: heat colour, a punch on a
## step, a glow when hot.
func _mult_c(mult: float, at: Vector2, s: float, alpha: float) -> void:
	var col: Color = _ramp(HEAT,_heat)
	var glow: Color = _ramp(GLOW,_heat)
	var px := lerpf(MULT_M.x,MULT_M.y,_heat)*s
	var grow := 1.0+0.3*(1.0-smoothstep(0.0,0.2,_mult_kick))
	if _mult_kick < 0.034: col = Color.WHITE
	_txt(_block,_nums_i,"×%s" % String.num(mult,1),at,px,Color(col,alpha),4.0*s,grow,0.0,Color(glow,glow.a*alpha),float(_ramp(GLOW_PX,_heat))*s*0.6,0.0)

# --- The bank ----------------------------------------------------------------------

func _draw_bank_c(s: float) -> void:
	var a := float(_bank.age)
	var alpha := _bank_alpha()
	if alpha <= 0.01: return
	var read := _read_at()
	var k := smoothstep(read,read+0.25,a)
	var big := RING_PX.y*s
	var px := lerpf(big,READ_RING*s,k)
	var c := Vector2.ONE*big*0.5
	# The slam: a full gold ring, then the read-back's timer running down.
	var share := 1.0
	var has_line := not (_bank.line.get("moves",[]) as Array).is_empty()
	if k > 0.0 and has_line: share = lerpf(1.0,1.0-clampf((a-read)/BANNER_TIME,0.0,1.0),k)
	var cool := smoothstep(read,read+0.3,a)
	var track := Color(GOLD,1.0).lerp(Color(CREAM,0.25),cool)
	var glow := Color(1.0,0.83,0.42,0.8*(1.0-cool))
	_ring(c,px,share,GOLD,track,glow,14.0*s,alpha)
	if a < 0.45: _orbit(c,px,(a-0.05)/0.4,alpha)
	var coin := px*(56.0/84.0 if k <= 0.0 else lerpf(56.0/84.0,32.0/52.0,k))
	_glyph("bank",c,coin,_pop(a),alpha)
	if a < 0.4: _gleam(c,coin*0.5,a/0.4,0.6,alpha)
	# The trail flies into the coin.
	var trail: Array = _bank.trail
	if a < 0.35:
		var t := smoothstep(0.0,0.3,a)
		var tx := big+COL_GAP*s
		for i in mini(trail.size(),TRAIL.size()):
			var e: Dictionary = trail[i]
			var mp := float(TRAIL[i][0])*s
			var from := Vector2(tx+mp*0.5,(TOTAL_M+6.0+MOVE_M+14.0)*s)
			_medal(str(e.id),str(e.band),from.lerp(c,t),mp*lerpf(1.0,0.4,t),alpha*(1.0-t))
			tx += mp+5.0*s
	# The number: slammed in big and counting up, then settling to the
	# read-back's size beside the small ring.
	var tier := int(_bank.tier)
	var slam := a
	var cnt := clampf(slam/float([0.4,0.8,1.2][tier]),0.0,1.0)
	var pts := float(_bank.points)
	var text := "+"+_grouped(lerpf(float(_bank.chain),pts,1.0-pow(1.0-cnt,3.0)))
	var npx := lerpf(float(SLAM_M[tier])*s,READ_NUM*s,k)
	var grow := 1.0+0.25*(1.0-smoothstep(0.0,0.12,slam))
	var x := lerpf(big,c.x+px*0.5,k)+COL_GAP*s*lerpf(1.0,0.85,k)
	var at := Vector2(x,c.y)
	if tier > 0 and a < read:
		at += Vector2(randf_range(-1.0,1.0),randf_range(-1.0,1.0))*float([0.0,2.0,4.0][tier])*s
	var gl := Color(1.0,0.75,0.27,lerpf(0.75,0.35,k))
	_txt(_block,_nums,text,at,npx,Color(GOLD,alpha),4.0*s,grow,0.0,Color(gl,gl.a*alpha),18.0*s,0.0)
	if k > 0.0:
		var nw := _width(_nums,text,npx)
		var mpx := 20.0*s
		_txt(_block,_nums_i,"×%s" % String.num(float(_bank.mult),1),Vector2(at.x+nw+10.0*s,c.y+3.0*s),mpx,Color(CREAM,alpha*k),3.0*s,1.0,0.0,Color(0,0,0,0),0.0,0.0)
	if has_line and k > 0.0:
		if _bank.line.has("shape"): _draw_recap(s,c,px,a-read,alpha)
		else: _draw_banner(s,c,px,a-read,alpha)

## The recap on the banner, `t` s into the read-back: the line's runs in order,
## stamped one by one (a flourish's in red), then the sum and the money, and the
## line's name if any.
func _draw_recap(s: float, c: Vector2, ring_px: float, t: float, alpha: float) -> void:
	var line: Dictionary = _bank.line
	var shape: Array = line.shape
	var n := mini(shape.size(),SHAPE_MOST)
	var more := shape.size()-n
	var spx := 18.0*s
	var shape_f := _bw(spx,0.06)
	var gap := 20.0*s
	var row1 := maxf(n-1,0)*gap
	for i in n: row1 += _width(shape_f,str(shape[i].name),spx)
	var more_text := "+%d" % more
	if more > 0: row1 += 10.0*s+_width(_nums,more_text,spx)
	var points := float(line.points)
	var mult := float(line.mult)
	var sum_px := 24.0*s
	var sum_text := _grouped(points)
	if mult > 1.001: sum_text = "%s × %s = %s" % [_grouped(float(line.raw)),String.num(mult,1),sum_text]
	var money := "+%s" % _grouped(float(line.get("money",0)))
	var coin := 22.0*s
	var row2 := _width(_nums,sum_text,sum_px)+16.0*s+coin+4.0*s+_width(_nums,money,sum_px)
	var stat_px := 15.0*s
	var stat_f := _bw(stat_px,0.08)
	var stats := PackedStringArray()
	if is_finite(float(line.closest)): stats.append("CLOSEST %s M" % _metres(float(line.closest)))
	stats.append("AVG %d KM/H" % roundi(float(line.speed)*3.6))
	if float(line.t) >= 0.1: stats.append("%s S" % String.num(float(line.t),1))
	var stat_text := "   ".join(stats)
	var title := str(line.get("name","")).to_upper()
	var name_px := 28.0*s
	var row3 := _width(_nums_i,title,name_px) if title != "" else 0.0
	var pad := Vector4(14.0,10.0,44.0,12.0)*s
	var inner_h := spx+8.0*s+sum_px+6.0*s+stat_px+(8.0*s+name_px if title != "" else 0.0)
	var w := maxf(maxf(maxf(row1,row2),row3),_width(stat_f,stat_text,stat_px))+pad.x+pad.z
	var h := inner_h+pad.y+pad.w
	_cloth(s,c,ring_px,t,w,h,alpha)
	# The runs, 90 ms apart.
	var y := pad.y+spx*0.5
	var x := pad.x
	for i in n:
		var word := str(shape[i].name)
		var st := t-0.12-0.09*i
		var ia := alpha*smoothstep(0.0,0.1,st)
		_ink(shape_f,word,Vector2(x,y),spx,Color(NAME_INK if bool(shape[i].flourish) else INK,ia))
		x += _width(shape_f,word,spx)
		if i < n-1:
			var mid := Vector2(x+gap*0.5,y)
			var r := 5.0*s
			_block.draw_colored_polygon(PackedVector2Array([mid+Vector2(-r*0.7,-r),mid+Vector2(r*0.7,0.0),mid+Vector2(-r*0.7,r)]),Color(LAND_INK,ia*0.7))
			x += gap
	if more > 0: _ink(_nums,more_text,Vector2(x+10.0*s,y),spx,Color(LAND_INK,alpha*smoothstep(0.3,0.45,t)))
	# The sum and the money.
	var sa := alpha*smoothstep(0.2+0.09*n,0.35+0.09*n,t)
	y = pad.y+spx+8.0*s+sum_px*0.5
	_ink(_nums,sum_text,Vector2(pad.x,y),sum_px,Color(INK,sa))
	x = pad.x+_width(_nums,sum_text,sum_px)+16.0*s
	_glyph("bank",Vector2(x+coin*0.5,y),coin,1.0,sa)
	_ink(_nums,money,Vector2(x+coin+4.0*s,y),sum_px,Color(LAND_INK,sa))
	# How it was flown.
	y += sum_px*0.5+6.0*s+stat_px*0.5
	_ink(stat_f,stat_text,Vector2(pad.x,y),stat_px,Color(LAND_INK,sa))
	if title != "":
		var ny := y+stat_px*0.5+8.0*s+name_px*0.5
		var na := alpha*smoothstep(0.35,0.5,t)
		_ink(_nums_i,title,Vector2(pad.x,ny),name_px,Color(NAME_INK,na))
		_glint_ink(_nums_i,title,Vector2(pad.x,ny),name_px,na,(t-0.55)/0.5)
	_cloth_sheen(s,t,w,h,alpha)

## The banner's pole and cloth, `w` by `h`, unfurling to the right; returns the
## cloth's transform, left set for what's drawn on it.
func _cloth(s: float, c: Vector2, ring_px: float, t: float, w: float, h: float, alpha: float) -> Transform2D:
	# The pole from the ring's foot.
	var pole_top := Vector2(c.x,c.y+ring_px*0.5)
	var pole_len := 14.0*s
	var unf := smoothstep(0.0,0.25,t)
	_block.draw_rect(Rect2(pole_top+Vector2(-2.0*s,0.0),Vector2(4.0*s,pole_len)),Color(CREAM,0.5*alpha))
	_block.draw_rect(Rect2(pole_top+Vector2(-1.0*s,0.0),Vector2(2.0*s,pole_len)),Color(INK,alpha))
	var o := Vector2(c.x-11.0*s,pole_top.y+pole_len)
	# The cloth, skewed 2 degrees, unfurling to the right.
	var xf := Transform2D(Vector2(1.0,tan(deg_to_rad(2.0))),Vector2(0.0,1.0),o)
	_block.draw_set_transform_matrix(xf)
	var cw := w*unf
	var notch := 20.0*s*unf
	var cloth := PackedVector2Array([Vector2(0,0),Vector2(cw,0),Vector2(cw-notch,h*0.5),Vector2(cw,h),Vector2(0,h)])
	if cw > 2.0:
		var drop := PackedVector2Array()
		for p: Vector2 in cloth: drop.append(p+Vector2(0.0,4.0*s))
		_block.draw_colored_polygon(drop,Color(0,0,0,0.35*alpha))
		_block.draw_colored_polygon(cloth,Color(CLOTH,alpha))
		# The weave: soft darker stripes.
		var sx := 0.0
		while sx+92.0*s <= cw-notch:
			var mid := sx+46.0*s
			_block.draw_polygon(PackedVector2Array([Vector2(sx,0),Vector2(mid,0),Vector2(mid,h),Vector2(sx,h)]),
				PackedColorArray([Color(0.235,0.157,0.04,0.0),Color(0.235,0.157,0.04,0.07*alpha),Color(0.235,0.157,0.04,0.07*alpha),Color(0.235,0.157,0.04,0.0)]))
			_block.draw_polygon(PackedVector2Array([Vector2(mid,0),Vector2(sx+92.0*s,0),Vector2(sx+92.0*s,h),Vector2(mid,h)]),
				PackedColorArray([Color(0.235,0.157,0.04,0.07*alpha),Color(0.235,0.157,0.04,0.0),Color(0.235,0.157,0.04,0.0),Color(0.235,0.157,0.04,0.07*alpha)]))
			sx += 92.0*s
		_block.draw_rect(Rect2(0,0,4.0*s,h),Color(INK,alpha))
	return xf

## The sheen across the cloth; the transform back to the block's.
func _cloth_sheen(s: float, t: float, w: float, h: float, alpha: float) -> void:
	var unf := smoothstep(0.0,0.25,t)
	var cw := w*unf
	var notch := 20.0*s*unf
	var sh := (t-0.3)/0.85
	if sh > 0.0 and sh < 1.0 and cw > 2.0:
		var bw := w*0.45
		var x0 := lerpf(-bw,w*1.1,1.0-pow(1.0-sh,2.0))
		_sheen_quad(x0,x0+bw*0.5,0.0,0.75,h,cw-notch,alpha)
		_sheen_quad(x0+bw*0.5,x0+bw,0.75,0.0,h,cw-notch,alpha)
	_block.draw_set_transform_matrix(Transform2D.IDENTITY)

## The towed banner under the small ring, `t` s into the read-back: a pole,
## then the cloth unfurling with the seals stamped on it, the land, the name
## and the money, a sheen sweeping it.
func _draw_banner(s: float, c: Vector2, ring_px: float, t: float, alpha: float) -> void:
	var line: Dictionary = _bank.line
	var glyphs: Array = line.get("glyphs",[])
	var bands: Array = line.get("bands",[])
	var land_words := PackedStringArray()
	for w: Variant in line.get("terrain",[]): land_words.append(str(w).to_upper())
	var title := str(line.get("name","")).to_upper()
	var money := "+%s" % _grouped(float(line.get("money",0)))
	var seal := 26.0*s
	var n := mini(glyphs.size(),READ_MOST)
	var more := glyphs.size()-n
	var lpx := 14.0*s
	var land_f := _bw(lpx,0.1)
	var land := " · ".join(land_words)
	var name_f := _nums_i
	var name_px := 30.0*s
	var money_px := 22.0*s
	# The rows measured.
	var seals_w := n*seal+maxf(n-1,0)*5.0*s
	if more > 0: seals_w += 6.0*s+_width(_nums,"+%d" % more,lpx*1.1)
	var row1 := seals_w+(8.0*s+_width(land_f,land,lpx) if land != "" else 0.0)
	var row2 := 0.0
	if title != "": row2 = _width(name_f,title,name_px)+14.0*s+_width(_nums,money,money_px)
	else: row1 += 10.0*s+_width(_nums,money,money_px*0.86)
	var pad := Vector4(14.0,10.0,44.0,12.0)*s
	var inner_h := seal+(8.0*s+name_px if title != "" else 0.0)
	var w := maxf(row1,row2)+pad.x+pad.z
	var h := inner_h+pad.y+pad.w
	var xf := _cloth(s,c,ring_px,t,w,h,alpha)
	var ca := alpha*smoothstep(0.15,0.3,t)
	# The seals, stamped 60 ms apart.
	var sy := pad.y+seal*0.5
	var x := pad.x
	for i in n:
		var st := t-0.12-0.06*i
		if st > 0.0:
			var g := 1.0+0.35*(1.0-smoothstep(0.0,0.1,st))
			var band := str(bands[i]) if i < bands.size() else "close"
			_block.draw_circle(Vector2(x+seal*0.5,sy),seal*0.5*lerpf(1.25,1.0,smoothstep(0.0,0.2,st)),Color(INK,0.12*ca*(1.0-smoothstep(0.0,0.3,st))))
			_medal(str(glyphs[i]),band,Vector2(x+seal*0.5,sy),seal*g,ca,0.0,xf)
		x += seal+5.0*s
	if more > 0:
		_ink(_nums,"+%d" % more,Vector2(x+1.0*s,sy),lpx*1.1,Color(LAND_INK,ca))
		x += 6.0*s+_width(_nums,"+%d" % more,lpx*1.1)
	else:
		x -= 5.0*s
	if land != "":
		x += 8.0*s
		_ink(land_f,land,Vector2(x,sy),lpx,Color(LAND_INK,ca*smoothstep(0.3,0.45,t)))
		x += _width(land_f,land,lpx)
	if title != "":
		var ny := pad.y+seal+8.0*s+name_px*0.5
		var na := alpha*smoothstep(0.35,0.5,t)
		_ink(name_f,title,Vector2(pad.x,ny),name_px,Color(NAME_INK,na))
		_glint_ink(name_f,title,Vector2(pad.x,ny),name_px,na,(t-0.55)/0.5)
		_ink(_nums,money,Vector2(pad.x+_width(name_f,title,name_px)+14.0*s,ny+2.0*s),money_px,Color(INK,na))
	else:
		_ink(_nums,money,Vector2(x+10.0*s,sy),money_px*0.86,Color(INK,ca*smoothstep(0.35,0.5,t)))
	_cloth_sheen(s,t,w,h,alpha)

## One half of the cloth's sheen: white from `a0` at xa to `a1` at xb,
## cut to [0, right].
func _sheen_quad(xa: float, xb: float, a0: float, a1: float, h: float, right: float, alpha: float) -> void:
	var l := clampf(xa,0.0,right)
	var r := clampf(xb,0.0,right)
	if r-l < 0.5: return
	var al := lerpf(a0,a1,(l-xa)/(xb-xa))*alpha
	var ar := lerpf(a0,a1,(r-xa)/(xb-xa))*alpha
	_block.draw_polygon(PackedVector2Array([Vector2(l,0),Vector2(r,0),Vector2(r,h),Vector2(l,h)]),
		PackedColorArray([Color(1,1,1,al),Color(1,1,1,ar),Color(1,1,1,ar),Color(1,1,1,al)]))

## Ink on the cloth: plain text, left-aligned, its middle at at.y (no keyline;
## the cloth's transform stays set).
func _ink(font: Font, text: String, at: Vector2, px: float, col: Color) -> void:
	if text.is_empty() or col.a <= 0.003: return
	var ipx := maxi(roundi(px),4)
	_block.draw_string(font,at+Vector2(0.0,ipx*0.35),text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,col)

## The name's glint on the cloth: a gold band crossing it at `t`.
func _glint_ink(font: Font, text: String, at: Vector2, px: float, alpha: float, t: float) -> void:
	if t <= 0.0 or t >= 1.0 or alpha <= 0.01: return
	var ipx := maxi(roundi(px),4)
	var w := _width(font,text,px)
	var band := lerpf(-0.25,1.25,t)*w
	var reach := maxf(w*0.16,px*0.6)
	for i in text.length():
		var pre := font.get_string_size(text.substr(0,i),HORIZONTAL_ALIGNMENT_LEFT,-1,ipx).x
		var cw := font.get_string_size(text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,ipx).x
		var k := 1.0-absf(pre+cw*0.5-band)/reach
		if k <= 0.0: continue
		_block.draw_string(font,at+Vector2(pre,ipx*0.35),text[i],HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,Color(GOLD.lerp(GLINT_TEXT,k),k*alpha))

# --- The scrape ----------------------------------------------------------------------

func _draw_loss_c(s: float) -> void:
	var a := float(_loss.age)
	var alpha := 1.0-smoothstep(LOSS_TIME-0.25,LOSS_TIME,a)
	var px := RING_PX.x*s
	var c := Vector2.ONE*px*0.5
	var r := px*31.0/72.0
	var w := px*4.0/72.0
	var had := float(_loss.chain) >= 1.0
	# The ring in three shards, flying out and tipping.
	if had:
		var k := smoothstep(0.0,0.5,a)
		var shards := [[-1.45,0.85,Vector2(6.0,-6.0),12.0],[0.3,2.35,Vector2(8.0,12.0),-10.0],[2.75,4.5,Vector2(-8.0,10.0),16.0]]
		for sh: Array in shards:
			var off: Vector2 = (sh[2] as Vector2)*s*(0.4+k*2.2)+Vector2(0.0,40.0*s*k*k)
			var rot := deg_to_rad(float(sh[3]))*k
			_block.draw_set_transform(c+off,rot)
			_block.draw_arc(Vector2.ZERO,r,float(sh[0]),float(sh[1]),16,Color(KEY,alpha),w+3.0*_k(),true)
			_block.draw_arc(Vector2.ZERO,r,float(sh[0]),float(sh[1]),16,Color(LOST,alpha*(1.0-0.5*k)),w,true)
			_block.draw_set_transform_matrix(Transform2D.IDENTITY)
	# The glyph of what was hit, on its disc, cracked in coral.
	var what := str(_loss.what)
	var id := "rock" if what == "stone" else (what if what in ["tree","water"] else "ground")
	var gpx := 40.0*s
	_block.draw_circle(c,gpx*0.5,Color(DISC,alpha))
	var shake := Vector2(randf_range(-1.0,1.0),randf_range(-1.0,1.0))*2.0*s*(1.0-smoothstep(0.0,0.2,a))
	_glyph(id,c+shake,gpx,1.0,alpha)
	var crack := PackedVector2Array()
	for p: Vector2 in [Vector2(8,5),Vector2(11,11),Vector2(9.5,13),Vector2(13,19)]: crack.append(c+shake+(p-Vector2(12,12))*gpx/24.0)
	var ck := smoothstep(0.0,0.08,a)
	if ck > 0.0:
		_block.draw_polyline(crack,Color(KEY,alpha*ck),3.2*s,true)
		_block.draw_polyline(crack,Color(LOST,alpha*ck),1.6*s,true)
	# LINE LOST and the loss; what was hit under it.
	var x := px+COL_GAP*s
	var y := 20.0*s
	var head := ("CRASHED" if bool(_loss.crash) else "LINE LOST") if had else ("CRASHED" if bool(_loss.crash) else "SCRAPE")
	var hf := _bw(16.0*s,0.22)
	_txt(_block,hf,head,Vector2(x,y+4.0*s),16.0*s,Color(LOST,alpha),3.0*s,1.0,0.0,Color(0,0,0,0),0.0,0.0)
	var lost := float(_loss.lost)
	if lost >= 1.0:
		var hw := _width(hf,head,16.0*s)
		_txt(_block,_nums,"−"+_grouped(lost),Vector2(x+hw+10.0*s,y),40.0*s,Color(LOST,alpha),4.0*s,1.0+0.15*(1.0-smoothstep(0.0,0.12,a)),0.0,Color(0,0,0,0),0.0,0.0)
	var word := {"stone":"ROCK","tree":"TREE","water":"WATER"}.get(what,"GROUND") as String
	var verb := "HIT " if bool(_loss.crash) else "SCRAPED "
	_txt(_block,_bw(17.0*s,0.08),verb+word,Vector2(x,y+20.0*s+12.0*s),17.0*s,Color(CREAM,0.85*alpha),3.0*s,1.0,0.0,Color(0,0,0,0),0.0,0.0)
	# The trail falls away greyed.
	var trail: Array = _loss.trail
	var tx := x
	var ty := y+20.0*s+12.0*s+22.0*s
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_loss.seed)
	for i in mini(trail.size(),TRAIL.size()):
		var e: Dictionary = trail[i]
		var mp := float(TRAIL[i][0])*s
		var fall := a*a*260.0*s+a*30.0*s*rng.randf()
		var drift := (rng.randf()*2.0-1.0)*30.0*s*a
		var rot := (rng.randf()*2.0-1.0)*2.4*a
		_medal(str(e.id),"near",Vector2(tx+mp*0.5+drift,ty+fall),mp,0.55*alpha*(1.0-smoothstep(0.4,1.0,a)),rot)
		tx += mp+8.0*s
