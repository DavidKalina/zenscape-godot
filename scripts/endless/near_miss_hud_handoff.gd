extends Control
## The near misses on screen as the design handoff draws them ("Near-Miss
## Feedback", 2026-10-25); the same calls as scripts/endless/near_miss_hud.gd,
## plus `plane_at` (the plane's place in the world, set each frame). Sizes are
## the handoff's, at 2560 x 1440 (D below), scaled by min(w/2560, h/1440).
## - placement, the player's setting (`set_tag`, kept in SETTINGS_PATH; the
##   tag until they choose): the tag hangs the chain cluster (total and
##   multiplier, the 3 s drain, the feed), TAG its size and tilted ANGLE, off
##   the plane's upper left, the surge meter in the lower right corner; the
##   top puts the cluster, meter and all, at the top centre over the sky, as
##   the handoff drew it. --near-hud=handoff-tag or --near-hud=handoff picks
##   one for a run without keeping it. (The handoff's hitmarker, a ring of
##   ticks round the plane, was left out on 2026-10-25; its razor hitch stays.)
## - a razor pass drops the world to quarter speed for 50 ms.
## - the feed: a line a pass (its badge, scripts/endless/near_badges.gd, the
##   rim its tier; its kind in Newsreader; its points in Barlow), landing at
##   the foot and pushing older lines up and dimmer, three at most; each line's
##   points fly up into the total.
## - the total ticks over 0.35 s and jolts; the multiplier, italic, heats
##   white, gold, orange, burning as it climbs, growing, breathing, rocking,
##   then burning with embers at the cap.
## - the bank: total and multiplier slide together and slam into one gold
##   number sized to the run (a nod, big, huge), counting up, then pouring
##   into the meter; under it the line reads back (READ_TIME s from the
##   bank, cut short by the next move): its moves' badges in order, the land
##   it crossed, its name if it earned one and the money paid; a scrape
##   freezes 60 ms, cracks the total in coral,
##   splits it and lets it fall, the loss in a coral line.
## - the gap: at the cluster's foot, the closest the plane has come this
##   pass (NearMiss `gap`), counting down live as it closes, heating from
##   mist through cream and gold to burning as it shrinks; a scored pass
##   locks it on the moment's least with a pop and holds it GAP_HOLD s. Each
##   feed line carries its least too, between the kind and the points.

const NearMiss = preload("res://scripts/endless/near_miss.gd")
const Glyphs = preload("res://scripts/endless/near_glyphs.gd")
const Badges = preload("res://scripts/endless/near_badges.gd")
const WORDS = preload("res://assets/fonts/newsreader-latin.woff2")
const NUMS = preload("res://assets/fonts/barlow-semi-condensed-800-latin.woff2")
const WorldScale = preload("res://scripts/world_scale.gd")
const NUMS_ITALIC = preload("res://assets/fonts/barlow-semi-condensed-800-italic-latin.woff2")
## The player's kept layout: [near] layout = "tag" or "top".
const SETTINGS_PATH := "user://hud.cfg"

## The tag's size against the handoff's, its tilt, and where its lower right
## corner hangs off the plane on screen (D).
const TAG := 0.42
const ANGLE := -0.12
const TAG_OFFSET := Vector2(-115.0,-83.0)
const FOLLOW := 10.0
## The cluster (D, from the total row's top): the meter over it, the total's
## middle, the drain, and the feed's rows by slot (newest first): middle y,
## badge, kind and points sizes, opacity.
const METER_Y := -32.0
const METER := Vector2(440.0,20.0)
const TOTAL_Y := 60.0
const TOTAL_PX := 120.0
const DRAIN_Y := 144.0
const DRAIN := Vector2(560.0,8.0)
const ROWS := [[380.0,108.0,62.0,81.0,1.0],[267.0,76.0,46.0,57.0,0.7],[180.0,65.0,40.0,49.0,0.35],[121.0,59.0,38.0,46.0,0.0]]
const CLUSTER_FOOT := 590.0
## The gap (D): its middle, its number's size from the reach to touching,
## the hold of a locked pass and its fade (s).
const GAP_Y := 502.0
const GAP_PX := Vector2(104.0,150.0)
const GAP_HOLD := 1.0
const GAP_FADE := 0.3
## After a pass the gap shows again once closing this fast (m/s).
const GAP_CLOSING := 0.6
## The tag's meter: in from the lower right corner (D) and its size.
const TAG_METER_AT := Vector2(72.0,90.0)
const TAG_METER := Vector2(300.0,14.0)
## The multiplier's size (D) and colour from x1 to the cap (NearMiss.CHAIN_TOP)
## in four even steps, and its glow there.
const MULT_PX := [88.0,96.0,108.0,120.0,136.0]
const HEAT := [Color("f6f3ea"),Color("f7dc8a"),Color("f2c14e"),Color("f7922e"),Color("ff6a2b")]
const GLOW := [Color(0,0,0,0),Color(0.969,0.863,0.541,0.55),Color(0.949,0.757,0.306,0.7),Color(0.969,0.573,0.180,0.8),Color(1.0,0.353,0.118,0.9)]
const GLOW_PX := [0.0,10.0,14.0,18.0,22.0]
## The bank by size: under 2,000 a nod, to 10,000 big, past it huge: the
## number's size, the word's, the count's time (s), the shake (D).
const BANK_TIERS := [[2000.0,68.0,30.0,0.4,0.0],[10000.0,112.0,36.0,0.8,3.0],[INF,152.0,40.0,1.2,8.0]]
## The read-back (D): from READ_IN s after the bank to READ_TIME, its last
## READ_FADE fading; the badges' row (their middle y, size, at most
## READ_MOST), the land's and the name's rows (middle y, size).
const READ_IN := 0.35
const READ_TIME := 2.6
const READ_FADE := 0.35
const READ_BADGES := [262.0,64.0]
const READ_MOST := 9
const READ_LAND := [336.0,34.0]
const READ_NAME := [404.0,46.0]

const CREAM := Color("f6f3ea")
const NEAR_C := Color("b9c6d2")
const GOLD := Color("ffd36b")
const SPARK := Color("ffe7a3")
const LOST := Color("ff8a6b")
const BANKED := Color("f4f0e6")
const KEY := Color("0e1013")
const GREY := Color("8a93a0")

var key_name := "B"
## The plane's place in the world; the tag hangs off it.
var plane_at: Variant = null
var tag := false

var _nums := FontVariation.new()
var _nums_i := FontVariation.new()
var _words := {}
var _block := Node2D.new()
var _halves: Array[Node2D] = []
var _anchor := Vector2.ZERO
var _anchored := false
var _feed: Array = []
var _total_from := 0.0
var _total_to := 0.0
var _total_t := 1.0
var _shown := 0.0
var _jolt := INF
var _heat := 0.0
var _mult_kick := INF
var _last_mult := 1.0
var _prev_chain := 0.0
var _prev_mult := 1.0
var _bank := {}
var _loss := {}
var _flare := 0.0
var _hold_until := 0
var _hold_scale := 1.0
var _clock := 0.0
var _near: NearMiss
## The gap: the closest this pass (INF none), the last frame's and its
## closing rate (m/s, smoothed), waiting for it to close again after a pass,
## the locked moment's least and its age, and the readout's value and
## opacity.
var _gap_min := INF
var _gap_prev := INF
var _gap_rate := 0.0
var _gap_rising := false
var _gap_lock := INF
var _gap_lock_t := INF
var _gap_value := INF
var _gap_alpha := 0.0

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var args := preload("res://scripts/launch_args.gd").user_args()
	if "--near-hud=handoff-tag" in args: tag = true
	elif "--near-hud=handoff" in args: tag = false
	else: tag = load_layout() == "tag"
	_nums.base_font = NUMS
	_nums.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"):1}
	_nums_i.base_font = NUMS_ITALIC
	_nums_i.opentype_features = _nums.opentype_features
	_block.draw.connect(_draw_block)
	add_child(_block)
	# The scrape's two halves: each a mask (its share of the total) over the
	# total's text, tipped and dropped on their own.
	for i in 2:
		var half := Node2D.new()
		half.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		half.visible = false
		var ink := Node2D.new()
		half.add_child(ink)
		half.draw.connect(_draw_half_mask.bind(half,i))
		ink.draw.connect(_draw_half_ink.bind(ink))
		_block.add_child(half)
		_halves.append(half)

## The tag (true) or the top; `keep` saves it as the player's choice.
func set_tag(on: bool, keep := true) -> void:
	tag = on
	_anchored = false
	if keep: save_layout("tag" if on else "top")
	queue_redraw()
	_block.queue_redraw()

## The player's kept layout, the tag until they choose.
static func load_layout(path := SETTINGS_PATH) -> String:
	var file := ConfigFile.new()
	if file.load(path) != OK: return "tag"
	var layout := str(file.get_value("near","layout","tag"))
	return layout if layout in ["tag","top"] else "tag"

static func save_layout(layout: String, path := SETTINGS_PATH) -> void:
	var file := ConfigFile.new()
	file.load(path)
	file.set_value("near","layout",layout)
	file.save(path)

## Newsreader 700 at `px`, tracked `track` em.
func _word_font(px: float, track: float) -> FontVariation:
	var key := "%d/%d" % [roundi(px),roundi(track*100.0)]
	if _words.has(key): return _words[key]
	var f := FontVariation.new()
	f.base_font = WORDS
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):700}
	f.spacing_glyph = roundi(px*track)
	_words[key] = f
	return f

## One frame, as NearMissHud's: `near` the NearMiss, `on` whether it runs,
## `events` the frame's.
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
		# A new move cuts the last line's read-back short.
		if not _bank.is_empty(): _bank.cut = true
		_feed.push_front({"id":Glyphs.for_moment(m),"kind":str(m.kind).to_upper(),"band":band,
			"points":float(m.points),"clear":float(m.clear),"age":0.0,"slot":0.0,"landed":false,"fade":-1.0})
		_gap_lock = maxf(float(m.clear),0.0)
		_gap_lock_t = 0.0
		_gap_min = INF
		_gap_rising = true
		if not _loss.is_empty(): _loss.age = maxf(float(_loss.age),0.6)
	if events.has("banked"):
		var pts := float(events.banked.points)
		var tier: Array = BANK_TIERS[0]
		for t: Array in BANK_TIERS:
			if pts < float(t[0]):
				tier = t
				break
		var line: Dictionary = events.banked.get("line",{})
		_bank = {"age":0.0,"points":pts,"chain":_prev_chain,"mult":float(line.get("mult",_prev_mult)),"tier":tier,"line":line,"cut":false}
		_end_feed()
	var crash := events.has("crash")
	if crash or events.has("scrape"):
		var lost := float((events.get("lost",{}) as Dictionary).get("points",0.0))
		_loss = {"age":0.0,"chain":_prev_chain,"mult":_prev_mult,"lost":lost,"crash":crash,"pace":1.4 if crash else 1.0}
		if _prev_chain >= 1.0: _hold(0.0,60)
		_end_feed()
	# The feed: age the lines, land their points, slide them up a slot each.
	var pending := 0.0
	for i in _feed.size():
		var f: Dictionary = _feed[i]
		f.age += delta
		f.slot = lerpf(float(f.slot),float(i),minf(1.0,delta*14.0))
		if f.fade >= 0.0: f.fade += delta
		if not f.landed and f.age >= 0.37:
			f.landed = true
			_jolt = 0.0
		if not f.landed and f.fade < 0.0: pending += f.points
	# A fourth line has slid to slot 3, where it is gone.
	_feed = _feed.filter(func(f: Dictionary) -> bool: return f.fade < 0.3 and float(f.slot) < 2.95)
	if _feed.size() > 4: _feed.resize(4)
	# The total ticks over 0.35 s, ease-out, to the chain less what is flying in.
	var target := maxf(near.chain_points-pending,0.0)
	if near.chain_points <= 0.0:
		target = 0.0
		_total_from = 0.0
		_total_to = 0.0
		_total_t = 1.0
	if absf(target-_total_to) > 0.5:
		_total_from = _shown
		_total_to = target
		_total_t = 0.0
	_total_t = minf(_total_t+delta/0.35,1.0)
	_shown = lerpf(_total_from,_total_to,1.0-pow(1.0-_total_t,3.0))
	_jolt += delta
	# The multiplier: punch on each step, heat easing over 0.3 s.
	var mult := near.multiplier()
	if mult > _last_mult+0.01: _mult_kick = 0.0
	_last_mult = mult
	_mult_kick += delta
	var heat := _mult_heat(mult)
	# (The bank's slide keeps the heat it banked.)
	if _bank.is_empty() or float(_bank.age) > 0.15: _heat = lerpf(_heat,heat,minf(1.0,delta*10.0))
	if not _bank.is_empty():
		_bank.age += delta
		if _bank.age >= _bank_time(): _bank = {}
	if not _loss.is_empty():
		_loss.age += delta*float(_loss.pace)
		if _loss.age >= 1.4: _loss = {}
	_flare = maxf(_flare-delta,0.0)
	_step_gap(delta,near,crash or events.has("scrape"))
	_place_block()
	_place_halves()
	_prev_chain = near.chain_points
	_prev_mult = mult
	queue_redraw()
	_block.queue_redraw()
	for h: Node2D in _halves:
		h.queue_redraw()
		(h.get_child(0) as Node2D).queue_redraw()

## The gap's pass: the closest so far while it closes; once the plane
## pulls away (a scored pass, a turn as NearMiss's, a scrape) it fades and
## waits for the plane to close in again at GAP_CLOSING m/s.
func _step_gap(delta: float, near: NearMiss, hit: bool) -> void:
	var g := near.gap
	_gap_lock_t += delta
	if g < INF and _gap_prev < INF and delta > 0.0:
		_gap_rate = lerpf(_gap_rate,(_gap_prev-g)/delta,1.0-exp(-delta/0.1))
	else:
		_gap_rate = 0.0
	_gap_prev = g
	if hit:
		_gap_lock_t = INF
		_gap_min = INF
		_gap_rising = true
	if g == INF:
		_gap_min = INF
		_gap_rising = false
	elif _gap_rising:
		if _gap_rate > GAP_CLOSING:
			_gap_rising = false
			_gap_min = g
	elif _gap_min == INF:
		_gap_min = g
	else:
		_gap_min = minf(_gap_min,g)
		var back := maxf(NearMiss.HYST*WorldScale.span,NearMiss.HYST_SHARE*_gap_min)
		if g > _gap_min+back:
			_gap_min = INF
			_gap_rising = true
	var locked := _gap_lock_t < GAP_HOLD and _gap_lock <= _gap_min
	var want := 0.0
	if locked:
		_gap_value = _gap_lock
		want = 1.0
	elif _gap_min < INF:
		_gap_value = _gap_min
		want = 1.0
	_gap_alpha = move_toward(_gap_alpha,want,delta/(0.12 if want > _gap_alpha else GAP_FADE))

## A clearance as the readout writes it: two places under a metre, one to
## ten, none past.
static func _metres(v: float) -> String:
	if v < 1.0: return "%.2f" % maxf(v,0.0)
	if v < 10.0: return "%.1f" % v
	return "%d" % roundi(v)

## The gap's heat (0 to 1): none from the close band out, 1 touching.
static func _gap_heat(v: float) -> float:
	return clampf(1.0-v/(NearMiss.CLOSE*WorldScale.span),0.0,1.0)

## The gap's colour: mist out at the reach, cream at the close band, then up
## the multiplier's heat to burning.
func _gap_col(v: float) -> Color:
	var close := NearMiss.CLOSE*WorldScale.span
	if v >= close: return NEAR_C.lerp(CREAM,clampf((NearMiss.REACH*WorldScale.span-v)/(NearMiss.REACH*WorldScale.span-close),0.0,1.0))
	return _ramp(HEAT,_gap_heat(v))

func _end_feed() -> void:
	for f: Dictionary in _feed:
		if f.fade < 0.0: f.fade = 0.0
		f.landed = true

## The world at `scale` for `ms` real milliseconds (only ever slower).
func _hold(scale: float, ms: int) -> void:
	if Engine.time_scale < scale and Time.get_ticks_msec() >= _hold_until: return
	Engine.time_scale = scale
	_hold_scale = scale
	_hold_until = Time.get_ticks_msec()+ms

func _release_hold() -> void:
	if _hold_until > 0 and Time.get_ticks_msec() >= _hold_until:
		if is_equal_approx(Engine.time_scale,_hold_scale): Engine.time_scale = 1.0
		_hold_until = 0

func _exit_tree() -> void:
	if _hold_until > 0 and is_equal_approx(Engine.time_scale,_hold_scale): Engine.time_scale = 1.0

func _k() -> float:
	return minf(size.x/2560.0,size.y/1440.0)

## The cluster's scale: D to screen px.
func _s() -> float:
	return _k()*(TAG if tag else 1.0)

## The rows' alignment: centred at the top, set to the tag's corner.
func _row_left(w: float) -> float:
	return -w if tag else -w*0.5

func _plane_screen() -> Vector2:
	var fallback := Vector2(size.x*0.5,size.y*0.62)
	var cam := get_viewport().get_camera_3d()
	if cam == null or not (plane_at is Vector3) or cam.is_position_behind(plane_at): return fallback
	return cam.unproject_position(plane_at)

func _place_block() -> void:
	var s := _s()
	if not tag:
		_block.position = Vector2(size.x*0.5,68.0*_k())
		_block.rotation = 0.0
		return
	var to := _plane_screen()+TAG_OFFSET*_k()
	var foot := Vector2(0.0,CLUSTER_FOOT*s).rotated(ANGLE)
	to = Vector2(clampf(to.x,420.0*_k(),size.x-40.0*_k()),clampf(to.y,CLUSTER_FOOT*s+40.0*_k(),size.y-100.0*_k()))
	_anchor = to if not _anchored else _anchor.lerp(to,minf(1.0,get_process_delta_time()*FOLLOW))
	_anchored = true
	_block.position = _anchor-foot
	_block.rotation = ANGLE

func _bank_time() -> float:
	var tier: Array = _bank.tier
	var slam := 0.15+float(tier[3])+0.25+0.3
	if bool(_bank.get("cut",false)) or (_bank.get("line",{}).get("moves",[]) as Array).is_empty(): return slam
	return maxf(slam,READ_TIME)

# --- Text --------------------------------------------------------------------

## `text` centred on `at` (its middle at at.y), scaled `grow` and turned
## `rot` about it: a #0E1013 keyline `stroke` px, a drop shadow, and a glow.
func _txt(ci: CanvasItem, font: Font, text: String, at: Vector2, px: float, col: Color, stroke: float, grow := 1.0, rot := 0.0, glow := Color(0,0,0,0), glow_px := 0.0, align := 0.5) -> void:
	if text.is_empty() or col.a <= 0.003: return
	var ipx := maxi(roundi(px),4)
	var w := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx).x
	ci.draw_set_transform(at,rot,Vector2.ONE*grow)
	var p := Vector2(-w*align,ipx*0.35)
	var st := maxi(roundi(stroke),1)
	if glow.a > 0.0 and glow_px > 0.0:
		ci.draw_string_outline(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,roundi(st+glow_px*1.6),Color(glow,glow.a*0.22*col.a))
		ci.draw_string_outline(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,roundi(st+glow_px*0.8),Color(glow,glow.a*0.35*col.a))
	var drop := Vector2(0.0,maxf(stroke*0.5,1.0))
	ci.draw_string_outline(font,p+drop,text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,st,Color(KEY,0.45*col.a))
	ci.draw_string_outline(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,st,Color(KEY,col.a))
	ci.draw_string(font,p,text,HORIZONTAL_ALIGNMENT_LEFT,-1,ipx,col)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

func _width(font: Font, text: String, px: float) -> float:
	return font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(roundi(px),4)).x

# --- The block: meter, total and multiplier, drain, feed, bank, scrape ---------

func _draw_block() -> void:
	if _near == null: return
	var s := _s()
	if not tag: _draw_meter(_block,Vector2(0.0,METER_Y*s+METER.y*s*0.5),METER*s,s)
	var total_c := Vector2.ZERO
	var mult_c := Vector2.ZERO
	var live := _shown >= 1.0
	var mult := _near.multiplier()
	var mult_px := _mult_px(mult)*s
	var total_px := TOTAL_PX*s
	var text := _grouped(_shown)
	var mtext := "×%s" % String.num(mult,1)
	var tw := _width(_nums,text,total_px)
	var mw := _width(_nums_i,mtext,mult_px)
	var gap := 28.0*s
	var left := _row_left(tw+gap+mw)
	total_c = Vector2(left+tw*0.5,TOTAL_Y*s)
	mult_c = Vector2(left+tw+gap+mw*0.5,TOTAL_Y*s+4.0*s)
	if not _bank.is_empty(): _draw_bank(s)
	elif not _loss.is_empty(): _draw_loss(s)
	elif live:
		# The total: warm white, jolting 1.14x and 8 D up as a line lands.
		var j := 1.0-smoothstep(0.0,0.14,_jolt)
		_txt(_block,_nums,text,total_c-Vector2(0.0,8.0*s*j),total_px,CREAM,12.0*s,1.0+0.14*j)
		_draw_mult(mtext,mult_c,mult_px,s,1.0)
		# The drain to the bank.
		if _near.bank_left > 0.0:
			var share := clampf(_near.bank_left/NearMiss.BANK_AFTER,0.0,1.0)
			var dw := DRAIN.x*s
			var dl := _row_left(dw)
			_bar(_block,Rect2(dl,DRAIN_Y*s,dw,DRAIN.y*s),share,3.0*s,[CREAM,CREAM],tag)
	for i in range(_feed.size()-1,-1,-1): _draw_line(_feed[i],total_c,s)
	_draw_gap(s)

## The gap at the cluster's foot: a chevron down to the land and the
## closest this pass in metres, swelling and heating as it shrinks; locked,
## one white frame and a pop.
func _draw_gap(s: float) -> void:
	if _gap_alpha <= 0.01 or _gap_value == INF: return
	var v := _gap_value
	var h := _gap_heat(v)
	var col := _gap_col(v)
	var glow: Color = _ramp(GLOW,h)
	var glow_px := float(_ramp(GLOW_PX,h))*s
	var px := lerpf(GAP_PX.x,GAP_PX.y,h*h)*s
	var unit_px := px*0.6
	var grow := 1.0
	var locked := _gap_lock_t < GAP_HOLD and is_equal_approx(v,_gap_lock)
	if locked:
		grow = 1.0+0.3*(1.0-smoothstep(0.0,0.18,_gap_lock_t))
		if _gap_lock_t < 0.034: col = Color.WHITE
	# Under the razor band it throbs.
	if v < NearMiss.RAZOR*WorldScale.span and not locked: grow *= 1.0+0.05*sin(_clock*TAU*4.0)
	var text := _metres(v)
	var unit := _word_font(unit_px,0.04)
	var tw := _width(_nums,text,px)
	var uw := _width(unit,"m",unit_px)
	var chev := px*0.5
	var gap := 12.0*s
	var whole := chev+gap+tw+gap*0.5+uw
	var left := _row_left(whole)
	var y := GAP_Y*s
	var mid := left+whole*0.5
	var a := _gap_alpha
	# The chevron, pointing down.
	var c := (Vector2(left+chev*0.5,y)-Vector2(mid,y))*grow+Vector2(mid,y)
	var r := chev*0.5*grow
	var tri := PackedVector2Array([c+Vector2(-r,-r*0.55),c+Vector2(r,-r*0.55),c+Vector2(0.0,r*0.75)])
	var key := PackedVector2Array([tri[0]+Vector2(-3.0,-2.0)*s,tri[1]+Vector2(3.0,-2.0)*s,tri[2]+Vector2(0.0,4.0)*s])
	# (Too small to triangulate, as in a window of no size, it is left out.)
	if r >= 0.5:
		_block.draw_colored_polygon(key,Color(KEY,a))
		_block.draw_colored_polygon(tri,Color(col,a))
	_txt(_block,_nums,text,(Vector2(left+chev+gap+tw*0.5,y)-Vector2(mid,y))*grow+Vector2(mid,y),px,Color(col,a),14.0*s,grow,0.0,Color(glow,glow.a*a),glow_px)
	_txt(_block,unit,"m",(Vector2(left+whole-uw*0.5,y+px*0.12)-Vector2(mid,y))*grow+Vector2(mid,y),unit_px,Color(col,a),8.0*s,grow)

## The multiplier's heat, 0 at x1 to 1 at NearMiss.CHAIN_TOP.
static func _mult_heat(mult: float) -> float:
	return clampf((mult-1.0)/(NearMiss.CHAIN_TOP-1.0),0.0,1.0)

## The multiplier's size: MULT_PX spread from x1 to the cap.
func _mult_px(mult: float) -> float:
	var x := _mult_heat(mult)*4.0
	var i := mini(int(x),3)
	return lerpf(MULT_PX[i],MULT_PX[i+1],x-i)

func _ramp(table: Array, h: float) -> Variant:
	var x := clampf(h,0.0,1.0)*4.0
	var i := mini(int(x),3)
	var a: Variant = table[i]
	var b: Variant = table[i+1]
	if a is Color: return (a as Color).lerp(b,x-i)
	return lerpf(float(a),float(b),x-i)

## The multiplier at its heat: italic, punching on a step (one white frame),
## breathing from x3, rocking from x4, burning at x5 with embers.
func _draw_mult(text: String, at: Vector2, px: float, s: float, alpha: float) -> void:
	var m := 1.0+_heat*4.0
	var col: Color = _ramp(HEAT,_heat)
	var glow: Color = _ramp(GLOW,_heat)
	var glow_px := float(_ramp(GLOW_PX,_heat))*s
	var grow := 1.0+0.35*(1.0-smoothstep(0.0,0.2,_mult_kick))
	if _mult_kick < 0.034: col = Color.WHITE
	var rot := deg_to_rad(-4.0)*smoothstep(2.0,3.5,m)
	var off := Vector2.ZERO
	if m >= 3.0 and m < 4.0: grow *= 1.0+0.04*sin(_clock*TAU/1.6)
	if m >= 4.0 and m < 4.95: rot = deg_to_rad(-1.5+2.5*sin(_clock*TAU/0.8))
	if m >= 4.95:
		var t := _clock/0.36
		rot = deg_to_rad(-4.5+1.5*sin(t*TAU*1.7))
		off = Vector2(sin(t*TAU*2.3),cos(t*TAU*1.9))*1.5*s
		grow *= 1.05+0.03*sin(t*TAU*3.1)
		glow.a *= 0.85+0.15*sin(_clock*TAU*2.0)
		glow_px *= 1.0+0.25*sin(_clock*TAU*2.0)
		_embers(at,px,s,alpha)
	_txt(_block,_nums_i,text,at+off,px,Color(col,alpha),12.0*s,grow,rot,Color(glow,glow.a*alpha),glow_px)

func _embers(at: Vector2, px: float, s: float, alpha: float) -> void:
	for i in 4:
		var t := fmod(_clock/1.1+i*0.27,1.0)
		var a := (smoothstep(0.0,0.15,t))*(1.0-t)*alpha
		var p := at+Vector2((-0.35+0.25*i)*px,px*0.55-112.0*s*t)
		var c := Color("ffd27a") if i != 3 else Color("ff9a4a")
		_block.draw_rect(Rect2(p-Vector2.ONE*4.0*s,Vector2.ONE*8.0*s),Color(c,a))

## A feed line at its slot: badge, kind, points; its points flying up into
## the total from 0.12 s to 0.37 s.
func _draw_line(f: Dictionary, total_c: Vector2, s: float) -> void:
	var slot := clampf(float(f.slot),0.0,3.0)
	var i := mini(int(slot),2)
	var a: Array = ROWS[i]
	var b: Array = ROWS[i+1]
	var k := slot-i
	var y := lerpf(a[0],b[0],k)*s
	var badge := lerpf(a[1],b[1],k)*s
	var kind_px := lerpf(a[2],b[2],k)*s
	var pts_px := lerpf(a[3],b[3],k)*s
	var alpha := lerpf(a[4],b[4],k)
	var age := float(f.age)
	if float(f.fade) >= 0.0:
		var d := clampf(float(f.fade)/0.3,0.0,1.0)
		alpha *= 1.0-d
		y += 40.0*s*d
	alpha *= smoothstep(0.0,0.12,age)
	if alpha <= 0.01: return
	var band := str(f.band)
	var col := GOLD if band == "razor" else (CREAM if band == "close" else NEAR_C)
	var kind := str(f.kind)
	var pts := "+%s" % _grouped(float(f.points))
	var font := _word_font(kind_px,0.12)
	var kw := _width(font,kind,kind_px)
	var pw := _width(_nums,pts,pts_px)
	var clear := "%s m" % _metres(float(f.clear))
	var clear_px := pts_px*0.8
	var cw := _width(_nums,clear,clear_px)
	var gap := lerpf(20.0,16.0,clampf(slot,0.0,1.0))*s
	var whole := badge+gap+kw+gap+cw+gap+pw
	var left := _row_left(whole)
	var pop := lerpf(0.7,1.0,1.0-pow(1.0-clampf(age/0.12,0.0,1.0),3.0))
	var stroke := (12.0 if slot < 0.5 else 8.0)*s
	var row_mid := left+whole*0.5
	_txt(_block,font,kind,Vector2(left+badge+gap+kw*0.5-row_mid,0.0)*pop+Vector2(row_mid,y),kind_px,Color(col,alpha),stroke,pop)
	_txt(_block,_nums,clear,Vector2(left+badge+gap+kw+gap+cw*0.5-row_mid,0.0)*pop+Vector2(row_mid,y),clear_px,Color(_gap_col(float(f.clear)),alpha),stroke*0.8,pop)
	var pts_at := Vector2(left+whole-pw*0.5-row_mid,0.0)*pop+Vector2(row_mid,y)
	_txt(_block,_nums,pts,pts_at,pts_px,Color(col,alpha),stroke,pop)
	# The badge: 0.6x to 1.18x to 1x over 0.3 s, one gleam (none on near).
	var bp: float
	if age < 0.14: bp = lerpf(0.6,1.18,age/0.14)
	else: bp = lerpf(1.18,1.0,clampf((age-0.14)/0.17,0.0,1.0))
	var bc := Vector2(left+badge*0.5,y)
	var tex := Badges.texture(str(f.id),band,badge*bp)
	if tex != null:
		var sz := badge*bp
		_block.draw_texture_rect(tex,Rect2(bc-Vector2.ONE*sz*0.5,Vector2.ONE*sz),false,Color(1,1,1,alpha*clampf(age/0.07,0.0,1.0)))
		if band != "near" and age > 0.08 and age < 0.43:
			_gleam(bc,sz*0.5*28.0/32.0,(age-0.08)/0.35,0.4 if band == "razor" else 0.3,alpha)
	# The points flying up into the total.
	if float(f.fade) < 0.0 and age > 0.12 and age < 0.37:
		var t := (age-0.12)/0.25
		var e := t*t*(3.0-2.0*t)
		var p := pts_at.lerp(total_c,e)
		_txt(_block,_nums,pts,p,pts_px*lerpf(1.0,0.75,e),Color(col,0.9*(1.0-e*0.5)),stroke)

## A white bar at 25 degrees sweeping across a badge's face (radius r).
func _gleam(c: Vector2, r: float, t: float, a: float, alpha: float) -> void:
	var circle := PackedVector2Array()
	for i in 28: circle.append(c+Vector2.from_angle(i*TAU/28.0)*r)
	var n := Vector2.from_angle(deg_to_rad(25.0))
	var x := lerpf(-1.3,1.3,1.0-pow(1.0-clampf(t,0.0,1.0),2.0))*r
	var half := r*10.0/56.0
	var poly := _clip(_clip(circle,n,n.dot(c)+x+half),-n,-(n.dot(c)+x-half))
	# (A sliver at the circle's edge can be too thin to triangulate.)
	if poly.size() >= 3 and not Geometry2D.triangulate_polygon(poly).is_empty():
		_block.draw_colored_polygon(poly,Color(1,1,1,a*alpha))

## `poly` clipped to the side of the line n.p = d where n.p <= d.
static func _clip(poly: PackedVector2Array, n: Vector2, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i+1)%poly.size()]
		var pin := n.dot(p) <= d
		var qin := n.dot(q) <= d
		if pin: out.append(p)
		if pin != qin:
			var t := (d-n.dot(p))/(n.dot(q)-n.dot(p))
			out.append(p.lerp(q,t))
	return out

## A bar `share` full in `r`: a dark, keylined track, the fill toward the
## far end (`from_right`: shrinking toward the right end) in `cols` (2 or 3 stops).
func _bar(ci: CanvasItem, r: Rect2, share: float, key: float, cols: Array, from_right := false, glow := 0.0) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(KEY,0.6)
	box.border_color = KEY
	box.set_border_width_all(maxi(roundi(key),1))
	box.set_corner_radius_all(roundi(r.size.y*0.5))
	box.expand_margin_left = key
	box.expand_margin_right = key
	box.expand_margin_top = key
	box.expand_margin_bottom = key
	if glow > 0.0:
		box.shadow_color = Color(1.0,0.84,0.42,0.8*glow)
		box.shadow_size = roundi(14.0*_k()*glow)
	ci.draw_style_box(box,r)
	var w := r.size.x*share
	if w < 0.5: return
	var x0 := r.position.x+(r.size.x-w if from_right else 0.0)
	var y0 := r.position.y
	var h := r.size.y
	var stops: Array = [[0.0,cols[0]],[1.0,cols[1]]] if cols.size() == 2 else [[0.0,cols[0]],[0.7,cols[1]],[1.0,cols[2]]]
	for i in stops.size()-1:
		var a: Array = stops[i]
		var b: Array = stops[i+1]
		var xa := x0+w*float(a[0])
		var xb := x0+w*float(b[0])
		var ca: Color = a[1]
		var cb: Color = b[1]
		ci.draw_polygon(PackedVector2Array([Vector2(xa,y0),Vector2(xb,y0),Vector2(xb,y0+h),Vector2(xa,y0+h)]),PackedColorArray([ca,cb,cb,ca]))

func _draw_meter(ci: CanvasItem, mid: Vector2, sz: Vector2, s: float) -> void:
	var fill := clampf(_near.meter,0.0,1.0)
	var glow := maxf(_flare/0.4,1.0 if fill >= 0.999 else 0.0)
	if _near.surge > 0.0: glow = 0.6+0.4*sin(_clock*TAU*4.0)
	_bar(ci,Rect2(mid-sz*0.5,sz),fill,4.0*s,[Color("a06c1c"),Color("f2c14e"),Color("ffe7a3")],false,glow)

# --- The bank ----------------------------------------------------------------

func _draw_bank(s: float) -> void:
	var a := float(_bank.age)
	var tier: Array = _bank.tier
	var count_t := float(tier[3])
	var chain := float(_bank.chain)
	var mult := float(_bank.mult)
	var pts := float(_bank.points)
	var total_px := TOTAL_PX*s
	var ctext := _grouped(chain)
	var mtext := "×%s" % String.num(mult,1)
	var tw := _width(_nums,ctext,total_px)
	var mult_px := _mult_px(mult)*s
	var mw := _width(_nums_i,mtext,mult_px)
	var gap := 28.0*s
	var left := _row_left(tw+gap+mw)
	var mid := Vector2(_row_left(0.0) if tag else 0.0,TOTAL_Y*s)
	if a < 0.15:
		# They slide together.
		var k := smoothstep(0.0,0.15,a)
		var tc := Vector2(left+tw*0.5,TOTAL_Y*s)
		var mc := Vector2(left+tw+gap+mw*0.5,TOTAL_Y*s)
		if tag: mid.x = -(tw*0.5)
		_txt(_block,_nums,ctext,tc.lerp(mid,k*0.5),total_px,CREAM,12.0*s)
		_draw_mult(mtext,mc.lerp(mid,k),mult_px,s,1.0-k)
		return
	var slam := a-0.15
	var px := float(tier[1])*s
	var word_px := float(tier[2])*s
	var c := clampf(slam/count_t,0.0,1.0)
	var text := "+"+_grouped(lerpf(chain,pts,1.0-pow(1.0-c,3.0)))
	var w := _width(_nums,"+"+_grouped(pts),px)
	var at := Vector2(-w*0.5 if tag else 0.0,TOTAL_Y*s)
	var grow := 1.0+0.25*(1.0-smoothstep(0.0,0.12,slam))
	var alpha := 1.0
	var pour := slam-count_t-0.25
	var meter_at := _meter_mid_in_block()
	if pour > 0.0:
		var k := clampf(pour/0.3,0.0,1.0)
		at = at.lerp(meter_at,k*k)
		grow *= lerpf(1.0,0.3,k)
		alpha = 1.0-k*k
		if k >= 1.0: _flare = 0.4
	_draw_readback(s)
	if alpha <= 0.0: return
	var shake := float(tier[4])*s
	var rot := 0.0
	if shake > 0.0 and pour <= 0.0:
		at += Vector2(randf_range(-1.0,1.0),randf_range(-1.0,1.0))*shake
		if float(tier[4]) >= 8.0: rot = deg_to_rad(randf_range(-1.5,1.5))
	var glow := Color(1.0,0.75,0.27,0.0 if float(tier[4]) <= 0.0 else (0.7 if float(tier[4]) < 8.0 else 0.95))
	_txt(_block,_nums,text,at,px,Color(GOLD,alpha),12.0*s,grow,rot,glow,(18.0 if float(tier[4]) < 8.0 else 30.0)*s)
	# The gold coin badge to its left, and BANKED under it.
	var badge := px*0.8
	var tex := Badges.texture("bank","razor",badge)
	if tex != null:
		var bc := at-Vector2(w*0.5*grow+badge*0.6+14.0*s,0.0)
		_block.draw_texture_rect(tex,Rect2(bc-Vector2.ONE*badge*0.5,Vector2.ONE*badge),false,Color(1,1,1,alpha))
	_txt(_block,_word_font(word_px,0.3),"BANKED",at+Vector2(0.0,px*0.5+word_px*0.9),word_px,Color(BANKED,alpha*smoothstep(0.0,0.1,slam)),8.0*s)
	# Huge: sparks burst off both sides.
	if float(tier[4]) >= 8.0 and slam < 0.45:
		var k := slam/0.45
		for side: float in [-1.0,1.0]:
			for j in 3:
				var d := Vector2(side,(j-1)*0.65).normalized()
				var r0 := w*0.5+lerpf(20.0,90.0,k)*s
				var p0 := at+Vector2(d.x*r0,d.y*r0*0.6)
				_block.draw_line(p0,p0+d*lerpf(48.0,16.0,k)*s,Color(SPARK,0.8*(1.0-k)),6.0*s,true)

## The banked line read back under the bank: its moves' badges in order
## (each popping in, a "+n" past READ_MOST), the land it crossed, and its
## name (if any) with the money paid.
func _draw_readback(s: float) -> void:
	var line: Dictionary = _bank.get("line",{})
	var kinds: Array = line.get("moves",[])
	if kinds.is_empty(): return
	var a := float(_bank.age)-READ_IN
	if a <= 0.0: return
	var end := _bank_time()-READ_IN
	var alpha := smoothstep(0.0,0.15,a)*(1.0-smoothstep(end-READ_FADE,end,a))
	if alpha <= 0.01: return
	# The badges.
	var glyphs: Array = line.get("glyphs",[])
	var bands: Array = line.get("bands",[])
	var n := mini(glyphs.size(),READ_MOST)
	var bpx := float(READ_BADGES[1])*s
	var step := bpx*1.08
	var more := "+%d" % (glyphs.size()-n) if glyphs.size() > n else ""
	var more_px := bpx*0.55
	var mw := _width(_nums,more,more_px)+(10.0*s if more != "" else 0.0)
	var whole := step*(n-1)+bpx+mw
	var left := _row_left(whole)
	var y := float(READ_BADGES[0])*s
	for i in n:
		var t := clampf((a-0.06*i)/0.18,0.0,1.0)
		if t <= 0.0: continue
		var pop := lerpf(0.6,1.0,1.0-pow(1.0-t,3.0))
		var band := str(bands[i]) if i < bands.size() else "close"
		var tex := Badges.texture(str(glyphs[i]),band,bpx*pop)
		if tex == null: continue
		var c := Vector2(left+bpx*0.5+step*i,y)
		_block.draw_texture_rect(tex,Rect2(c-Vector2.ONE*bpx*pop*0.5,Vector2.ONE*bpx*pop),false,Color(1,1,1,alpha*t))
	if more != "": _txt(_block,_nums,more,Vector2(left+whole-mw*0.5+5.0*s,y),more_px,Color(CREAM,alpha),6.0*s)
	# The land crossed.
	var land: Array = line.get("terrain",[])
	if not land.is_empty():
		var words := PackedStringArray()
		for w: Variant in land: words.append(str(w).to_upper())
		var ltext := "  ·  ".join(words)
		var lpx := float(READ_LAND[1])*s
		var lf := _word_font(lpx,0.14)
		var lw := _width(lf,ltext,lpx)
		_txt(_block,lf,ltext,Vector2(_row_left(lw)+lw*0.5,float(READ_LAND[0])*s),lpx,Color(NEAR_C,alpha*smoothstep(0.1,0.3,a)),6.0*s)
	# The name and the money.
	var title := str(line.get("name","")).to_upper()
	var money := "+%d" % int(line.get("money",0))
	var npx := float(READ_NAME[1])*s
	var nf := _word_font(npx,0.18)
	var nw := _width(nf,title,npx) if title != "" else 0.0
	var gap := 22.0*s if title != "" else 0.0
	var cw := _width(_nums,money,npx*1.05)
	var coin := npx*0.9
	var row := nw+gap+coin+8.0*s+cw
	var rl := _row_left(row)
	var ny := float(READ_NAME[0])*s
	var na := alpha*smoothstep(0.2,0.4,a)
	if title != "": _txt(_block,nf,title,Vector2(rl+nw*0.5,ny),npx,Color(GOLD,na),8.0*s,1.0,0.0,Color(1.0,0.75,0.27,0.6),12.0*s)
	var tex := Badges.texture("bank","razor",coin)
	if tex != null: _block.draw_texture_rect(tex,Rect2(Vector2(rl+nw+gap,ny-coin*0.5),Vector2.ONE*coin),false,Color(1,1,1,na))
	_txt(_block,_nums,money,Vector2(rl+row-cw*0.5,ny),npx*1.05,Color(GOLD,na),8.0*s)

func _meter_mid_in_block() -> Vector2:
	if not tag: return Vector2(0.0,METER_Y*_s()+METER.y*_s()*0.5)
	var k := _k()
	var screen := Vector2(size.x-TAG_METER_AT.x*k-TAG_METER.x*k*0.5,size.y-TAG_METER_AT.y*k)
	return _block.get_global_transform().affine_inverse()*screen

# --- The scrape ----------------------------------------------------------------

## The crack's path across the total's text (fractions of its width and height).
const CRACK := [Vector2(0.50,-0.1),Vector2(0.60,0.32),Vector2(0.52,0.52),Vector2(0.64,0.80),Vector2(0.58,1.1)]
## Each half's share of the text (fractions), the left one's then the right one's.
const HALF_POLY := [[Vector2(0,0),Vector2(0.52,0),Vector2(0.60,0.45),Vector2(0.50,0.60),Vector2(0.58,1),Vector2(0,1)],
	[Vector2(0.52,0),Vector2(1,0),Vector2(1,1),Vector2(0.58,1),Vector2(0.50,0.60),Vector2(0.60,0.45)]]

## The lost chain's row: {text, px, tw, tc (the total's middle), mtext,
## mult_px, mc (the multiplier's)}.
func _loss_row(s: float) -> Dictionary:
	var text := _grouped(float(_loss.chain)) if float(_loss.chain) >= 1.0 else ""
	var total_px := TOTAL_PX*s
	var tw := _width(_nums,text,total_px)
	var mtext := "×%s" % String.num(float(_loss.mult),1)
	var mult_px := _mult_px(float(_loss.mult))*s
	var mw := _width(_nums_i,mtext,mult_px)
	var gap := 28.0*s
	var left := _row_left(tw+gap+mw)
	return {"text":text,"px":total_px,"tw":tw,"tc":Vector2(left+tw*0.5,TOTAL_Y*s),
		"mtext":mtext,"mult_px":mult_px,"mc":Vector2(left+tw+gap+mw*0.5,TOTAL_Y*s+4.0*s)}

## The halves of a cracked total: split by 0.12 s, fallen by 0.6 s.
func _place_halves() -> void:
	var split := not _loss.is_empty() and float(_loss.chain) >= 1.0 and float(_loss.age) >= 0.06
	for h: Node2D in _halves: h.visible = split
	if not split: return
	var s := _s()
	var row := _loss_row(s)
	var a := float(_loss.age)
	var k1 := smoothstep(0.06,0.12,a)
	var k2 := smoothstep(0.12,0.6,a)
	var fade := 1.0-0.7*k2-0.3*smoothstep(0.5,0.7,a)
	var tc: Vector2 = row.tc
	var turns := [[-7.0,-18.0,Vector2(-12.0,12.0),Vector2(-20.0,140.0)],[6.0,16.0,Vector2(20.0,24.0),Vector2(40.0,148.0)]]
	for i in 2:
		var t: Array = turns[i]
		var h := _halves[i]
		h.set_meta("text",row.text)
		h.set_meta("px",row.px)
		h.set_meta("w",row.tw)
		h.position = tc+(t[2] as Vector2).lerp(t[3],k2)*k1*s
		h.rotation = deg_to_rad(lerpf(t[0],t[1],k2))*k1
		h.modulate.a = fade

func _draw_loss(s: float) -> void:
	var a := float(_loss.age)
	var row := _loss_row(s)
	var text := str(row.text)
	if not text.is_empty():
		# Whole, with the crack through it, until it splits (the halves draw it then).
		if a < 0.06:
			_txt(_block,_nums,text,row.tc,row.px,CREAM,12.0*s)
			_draw_crack(row.tc,row.tw,row.px,s)
		var mult := float(_loss.mult)
		var mtext := str(row.mtext)
		var mult_px := float(row.mult_px)
		var mc: Vector2 = row.mc
		# The multiplier drains to grey and goes.
		var grey := smoothstep(0.06,0.12,a)
		var m_alpha := 1.0-smoothstep(0.3,0.6,a)
		if m_alpha > 0.0:
			var col := (_ramp(HEAT,clampf((mult-1.0)/4.0,0.0,1.0)) as Color).lerp(GREY,grey)
			_txt(_block,_nums_i,mtext,mc,mult_px,Color(col,m_alpha),12.0*s,1.0,deg_to_rad(-4.0)*smoothstep(2.0,3.5,mult))
	# The coral line: what it would have banked, held 1.2 s.
	var line_alpha := smoothstep(0.1,0.14,a)*(1.0-smoothstep(1.2,1.4,a)) if not text.is_empty() else (1.0-smoothstep(1.2,1.4,a))
	var word := "CRASHED" if bool(_loss.crash) else "SCRAPE"
	var lost := float(_loss.lost)
	var num := ("−"+_grouped(lost)) if lost >= 1.0 else ""
	var wpx := 34.0*s
	var npx := 40.0*s
	var font := _word_font(wpx,0.12)
	var ww := _width(font,word,wpx)
	var nw := _width(_nums,num,npx)
	var g := 16.0*s if not num.is_empty() else 0.0
	var lw := ww+g+nw
	var ll := _row_left(lw)
	var ly := lerpf(TOTAL_Y+110.0,TOTAL_Y,smoothstep(0.12,0.6,a))*s if not text.is_empty() else TOTAL_Y*s
	_txt(_block,font,word,Vector2(ll+ww*0.5,ly),wpx,Color(LOST,line_alpha),8.0*s)
	_txt(_block,_nums,num,Vector2(ll+ww+g+nw*0.5,ly),npx,Color(LOST,line_alpha),8.0*s)

func _draw_crack(c: Vector2, w: float, px: float, s: float) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in CRACK: pts.append(c+Vector2((p.x-0.5)*w,(p.y-0.5)*px))
	_block.draw_polyline(pts,KEY,16.0*s,true)
	_block.draw_polyline(pts,LOST,7.0*s,true)

func _draw_half_mask(half: Node2D, i: int) -> void:
	if not half.has_meta("text"): return
	var w := float(half.get_meta("w"))
	var px := float(half.get_meta("px"))
	var h := px*1.3
	var poly := PackedVector2Array()
	for p: Vector2 in HALF_POLY[i]: poly.append(Vector2((p.x-0.5)*(w+px*0.3),(p.y-0.5)*h))
	half.draw_colored_polygon(poly,Color.WHITE)

func _draw_half_ink(ink: Node2D) -> void:
	var half := ink.get_parent() as Node2D
	if not half.has_meta("text"): return
	_txt(ink,_nums,str(half.get_meta("text")),Vector2.ZERO,float(half.get_meta("px")),CREAM,12.0*_s())

# --- On the screen: the tag's meter ------------------------------------------

func _draw() -> void:
	if _near == null or not tag: return
	var k := _k()
	var mid := Vector2(size.x-TAG_METER_AT.x*k-TAG_METER.x*k*0.5,size.y-TAG_METER_AT.y*k)
	_draw_meter(self,mid,TAG_METER*k,k)

## 12345 as "12,345".
static func _grouped(v: float) -> String:
	var n := str(roundi(v))
	var out := ""
	while n.length() > 3:
		out = ","+n.substr(n.length()-3)+out
		n = n.substr(0,n.length()-3)
	return n+out
