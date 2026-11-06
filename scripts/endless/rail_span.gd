extends Node3D
## The railroad's trestles and bridges (spec-railroad.md, lane line), in
## greybox: each span (trestles and bridges end to end, RailLine.spans())
## a deck along the line that the track lies on, held up by supports every
## so often and ending on a stone abutment at each end, where the bed's
## bank spills round it (rail_bed.gd's cone).
##
## - The deck: a girder slab DECK_DEPTH deep under the sleepers' foot
##   (RailTrack.SLEEPER_BASE over the bed's height), wide enough for both
##   tracks' sleepers and the bents' posts.
## - Over land (a trestle stretch) a bent every BENT_STEP m: three posts,
##   the bays between them an opening by WorldScale (TOY_BAY), a cap under
##   the deck and girts across every GIRT_EVERY m down, so a tall bent is a
##   ladder of windows to thread.
## - Over water (a bridge stretch) a pier every PIER_STEP m: two stone
##   columns with a slot between them (TOY_SLOT) up to a cap under the deck.
##
## Everything is built at setup (a few hundred boxes; far pieces culled by
## VISIBLE), its colliders (physics layer 1, as the arches) within COLLIDE
## of the plane. The flight meets it as any stone (LandArches `ground`):
## `ground` gives the deck's top over it and Vector2(top, underside) under
## it, the posts and piers raise the land; `inside` keeps the camera and
## the rolling plane out; `land_y` puts the wheels and the eye on the deck.
## So a pass over the deck scores as a graze over stone, under it as a
## passage, and the wing rays read the posts as stone (NearMiss `_what`).
##
## Seed 1's wilderness, with the bed (RailTrack.wanted); `--no-railroad`
## leaves it out.

const RailLine = preload("res://scripts/endless/rail_line.gd")
const RailBed = preload("res://scripts/endless/rail_bed.gd")
const RailTrack = preload("res://scripts/endless/rail_track.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

const LAYER := 1
## The deck's frames (m of s) and its pieces (m of s): one mesh and one
## collider each.
const FRAME := 4.0
const PIECE := 64.0
## Seen out to VISIBLE m; colliders within COLLIDE of the plane, freed past
## FREE_AT x that.
const VISIBLE := 6000.0
const COLLIDE := 120.0
const FREE_AT := 1.25
## The deck: its girders' depth under the sleepers' foot, and how far it
## runs past the outer sleepers' ends.
const DECK_DEPTH := 1.8
const DECK_PAST := 0.9
## The trestle's bents: about this far apart along the line; the bays
## between the posts an opening (toy width TOY_BAY: 8 m at the defaults);
## a post's side; the cap under the deck; girts every GIRT_EVERY m down.
const BENT_STEP := 24.0
const TOY_BAY := 4.0
const POST := 1.2
const CAP_DEEP := 1.2
const CAP_ALONG := 1.6
const GIRT_EVERY := 14.0
const GIRT_DEEP := 0.8
## The bridge's piers: about this far apart; two columns (along, across)
## with a slot between (toy width TOY_SLOT: the game's usual thread); the
## pier's cap.
const PIER_STEP := 64.0
const TOY_SLOT := 3.5
const COLUMN := Vector2(3.0,3.6)
const PIER_CAP_DEEP := 2.4
const PIER_CAP_ALONG := 4.0
## A support is left out where the deck is nearer its ground than this.
const SUPPORT_MIN := 1.5
## The abutments: from ABUT_BACK m before a span's end (under the bed) to
## ABUT_IN m into it, ABUT_PAST m wider than the bed's flat each side.
const ABUT_BACK := 3.0
const ABUT_IN := 5.0
const ABUT_PAST := 1.0
## Feet sink this far under the ground.
const SINK := 2.0
## Colours over the ruins' stone (its vertex colour).
const DECK_C := Color(0.42,0.36,0.31)
const DECK_TOP_C := Color(0.34,0.31,0.28)
const TIMBER_C := Color(0.55,0.42,0.30)
const STONE_C := Color(0.80,0.74,0.65)
const CAP_C := Color(0.70,0.64,0.56)
## The shelter (the vertex colour's alpha, the ruins' stone's bounce under a
## roof: 1 open air, 0 deep under it) of the deck's underside and of the
## caps and girts, so they read in the deck's shade instead of going black.
const UNDER_SHELTER := 0.3
const CAP_SHELTER := 0.55

var line: RefCounted
var field: RefCounted
var _bed: RefCounted
## Half the deck's width, the bed's flat half (RailBed.HALF).
var _deck_half := 10.2
var _half := 12.5
var _top_up := RailTrack.SLEEPER_BASE
## The spans: s0, s1 each, and a coarse grid of CELL m squares listing the
## spans whose reach meets them.
const CELL := 64.0
var _s0 := PackedFloat32Array()
var _s1 := PackedFloat32Array()
var _cells := {}
## Per span: its supports' s (sorted) and their parts, each part PART
## floats (d, half across, half along, y0, y1, what: COL, CAP or GIRT);
## its abutments' feet (start, end).
const PART := 6
const COL := 0.0
const CAP := 1.0
const GIRT := 2.0
var _sup_s: Array[PackedFloat32Array] = []
var _sup_parts: Array = []
var _abut_foot := PackedVector2Array()
## The pieces: centre, radius, faces, body.
var _pc := PackedVector3Array()
var _pr := PackedFloat32Array()
var _faces: Array = []
var _body: Array = []
var _stone: Material
## What was built (a driver's count).
var supports := 0
var tris := 0
var build_ms := 0.0

func setup(land_field: RefCounted) -> void:
	var t0 := Time.get_ticks_usec()
	field = land_field
	line = RailLine.shared()
	_bed = RailBed.new()
	_half = RailBed.HALF
	var gap: float = line.track_gap()
	var outer := WorldScale.opening(TOY_BAY)+POST
	_deck_half = maxf(gap*0.5+RailTrack.SLEEPER_HALF+DECK_PAST,outer+POST*0.5+0.3)
	_stone = RuinKit.materials().stone
	for sp: Array in line.spans():
		_s0.append(float(sp[0]))
		_s1.append(float(sp[1]))
	for k in _s0.size():
		_plan(k)
		_grid(k)
		var a := _s0[k]-ABUT_BACK
		var b := _s1[k]+ABUT_BACK
		var n := maxi(ceili((b-a)/PIECE),1)
		for q in n:
			_build_piece(k,lerpf(a,b,float(q)/n),lerpf(a,b,float(q+1)/n),q == 0,q == n-1)
	build_ms = (Time.get_ticks_usec()-t0)/1000.0

## Each frame: colliders near the plane, freed far from it.
func step(_eye: Vector3, plane_at: Vector3) -> void:
	for i in _pc.size():
		var d := plane_at.distance_to(_pc[i])-_pr[i]
		if _body[i] == null:
			if d < COLLIDE: _collide(i)
		elif d > COLLIDE*FREE_AT:
			_body[i].queue_free()
			_body[i] = null

# --- The plan ---------------------------------------------------------------------

## Span k's supports: walked from its start a bent's or a pier's step at a
## time (by the kind under it), stretched to end on the span's end; each
## one's parts with their feet on the ground.
func _plan(k: int) -> void:
	var s0 := _s0[k]
	var s1 := _s1[k]
	var at := PackedFloat32Array()
	var s := s0
	var last := s0
	while true:
		var st := _step_at(s)
		if s+st > s1-st*0.5:
			last = s+st
			break
		s += st
		at.append(s)
	var stretch := (s1-s0)/maxf(last-s0,0.001) if not at.is_empty() else 1.0
	var ss := PackedFloat32Array()
	var parts: Array = []
	for q in at.size():
		var sq := s0+(at[q]-s0)*stretch
		var got := _support(sq)
		if got.is_empty(): continue
		ss.append(sq)
		parts.append(got)
		supports += 1
	_sup_s.append(ss)
	_sup_parts.append(parts)
	_abut_foot.append(Vector2(_abut_bottom(s0),_abut_bottom(s1)))

func _step_at(s: float) -> float:
	return PIER_STEP if line.kind(s+1.0) == "bridge" else BENT_STEP

## The deck's underside at s.
func _deck_under(s: float) -> float:
	return line.bed(s)+_top_up-DECK_DEPTH

## A support's parts at s: a bent over land, a pier over water.
func _support(s: float) -> PackedFloat32Array:
	var top := _deck_under(s)
	var c: Vector3 = line.centre(s)
	var fwd: Vector3 = line.tangent(s)
	var right := fwd.cross(Vector3.UP).normalized()
	var out := PackedFloat32Array()
	var pier: bool = line.kind(s) == "bridge"
	var cols: Array[Vector3] = []   # d, half across, half along
	var cap_deep := PIER_CAP_DEEP if pier else CAP_DEEP
	var cap_along := PIER_CAP_ALONG if pier else CAP_ALONG
	if pier:
		var off := WorldScale.opening(TOY_SLOT)*0.5+COLUMN.y*0.5
		for side: float in [-1.0,1.0]: cols.append(Vector3(side*off,COLUMN.y*0.5,COLUMN.x*0.5))
	else:
		var off := WorldScale.opening(TOY_BAY)+POST
		for d: float in [-off,0.0,off]: cols.append(Vector3(d,POST*0.5,POST*0.5))
	var under := top-cap_deep
	var feet := PackedFloat32Array()
	for col: Vector3 in cols:
		# The ground's lowest under the column's corners.
		var foot := INF
		for e: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var p := c+right*(col.x+e.x*col.y)+fwd*(e.y*col.z)
			foot = minf(foot,float(field.height(p.x,p.z)))
		feet.append(foot)
		if under-foot < SUPPORT_MIN: continue
		out.append_array([col.x,col.y,col.z,foot-SINK,under,COL])
	if out.is_empty(): return out
	# The cap, the deck's width (a pier's a little less).
	var cap_half := _deck_half-(0.4 if pier else 0.0)
	out.append_array([0.0,cap_half,cap_along*0.5,under,top,CAP])
	if pier: return out
	# Girts between neighbouring posts, every GIRT_EVERY m down from the cap,
	# where both posts stand under them.
	for q in cols.size()-1:
		var a: Vector3 = cols[q]
		var b: Vector3 = cols[q+1]
		var y := under-GIRT_EVERY
		while y-GIRT_DEEP > maxf(feet[q],feet[q+1])+2.0:
			var d0 := a.x+a.y
			var d1 := b.x-b.y
			out.append_array([(d0+d1)*0.5,(d1-d0)*0.5,POST*0.5*0.8,y-GIRT_DEEP,y,GIRT])
			y -= GIRT_EVERY
	return out

## An abutment's foot at a span's end: under the bed's spill cone at its
## front and corners (rail_bed.gd).
func _abut_bottom(s: float) -> float:
	return line.bed(s)-Vector2(ABUT_PAST*RailBed.FILL_SLOPE,ABUT_IN*RailBed.SPILL_SLOPE).length()-SINK

func _grid(k: int) -> void:
	var lo := Vector2(INF,INF)
	var hi := Vector2(-INF,-INF)
	var s := _s0[k]-ABUT_BACK
	while true:
		var c: Vector3 = line.centre(s)
		lo = lo.min(Vector2(c.x,c.z))
		hi = hi.max(Vector2(c.x,c.z))
		if s >= _s1[k]+ABUT_BACK: break
		s = minf(s+FRAME*4.0,_s1[k]+ABUT_BACK)
	var grow := _half+ABUT_PAST+COLUMN.y+8.0
	for cz in range(floori((lo.y-grow)/CELL),floori((hi.y+grow)/CELL)+1):
		for cx in range(floori((lo.x-grow)/CELL),floori((hi.x+grow)/CELL)+1):
			var key := Vector2i(cx,cz)
			var l: PackedInt32Array = _cells.get(key,PackedInt32Array())
			l.append(k)
			_cells[key] = l

# --- Building -----------------------------------------------------------------------

## Span k's stretch a..b of s: the deck's frames in it, its supports, an
## abutment at the span's start or end if it holds one.
func _build_piece(k: int, a: float, b: float, first: bool, last: bool) -> void:
	var m := RailTrack._Mesh.new()
	# The deck, from the span's start to its end.
	var d0 := maxf(a,_s0[k])
	var d1 := minf(b,_s1[k])
	if d1 > d0:
		var steps := maxi(ceili((d1-d0)/FRAME),1)
		var prev := {}
		for q in steps+1:
			var f := _frame(lerpf(d0,d1,float(q)/steps))
			if not prev.is_empty(): _deck(m,prev,f)
			prev = f
	# The supports.
	var ss: PackedFloat32Array = _sup_s[k]
	for q in ss.size():
		if ss[q] < a or ss[q] >= b: continue
		_support_mesh(m,ss[q],_sup_parts[k][q])
	if first: _abutment(m,_s0[k],1.0,_abut_foot[k].x)
	if last: _abutment(m,_s1[k],-1.0,_abut_foot[k].y)
	if m.verts.is_empty(): return
	var mi := m.instance(_stone)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.visibility_range_end = VISIBLE
	add_child(mi)
	tris += m.verts.size()/3
	# Its bounds, for the collider's distance.
	var box := AABB(m.verts[0],Vector3.ZERO)
	for v: Vector3 in m.verts: box = box.expand(v)
	_pc.append(box.get_center())
	_pr.append(box.size.length()*0.5)
	_faces.append(m.verts)
	_body.append(null)

## The line's frame at s: the centre, its right (level), up and along.
func _frame(s: float) -> Dictionary:
	var fwd: Vector3 = line.tangent(s)
	var up := (Vector3.UP-fwd*fwd.y).normalized()
	return {"c":line.centre(s),"r":fwd.cross(up).normalized(),"u":up,"f":fwd}

## The deck between two frames: its top (the sleepers' foot), sides and
## underside.
func _deck(m: RefCounted, f0: Dictionary, f1: Dictionary) -> void:
	var h := _deck_half
	var a: Vector3 = f0.c+f0.u*_top_up
	var b: Vector3 = f1.c+f1.u*_top_up
	var ra: Vector3 = f0.r*h
	var rb: Vector3 = f1.r*h
	var da: Vector3 = -f0.u*DECK_DEPTH
	var db: Vector3 = -f1.u*DECK_DEPTH
	m.quad(a-ra,b-rb,b+rb,a+ra,f0.u,DECK_TOP_C)
	m.quad(a+ra,b+rb,b+rb+db,a+ra+da,f0.r,DECK_C)
	m.quad(a-ra,b-rb,b-rb+db,a-ra+da,-f0.r,DECK_C)
	m.quad(a-ra+da,b-rb+db,b+rb+db,a+ra+da,-f0.u,Color(DECK_C,UNDER_SHELTER))

## A support's parts as boxes, level, along the line at s.
func _support_mesh(m: RefCounted, s: float, parts: PackedFloat32Array) -> void:
	var c: Vector3 = line.centre(s)
	var fwd: Vector3 = line.tangent(s)
	var along := Vector3(fwd.x,0.0,fwd.z).normalized()
	var right := along.cross(Vector3.UP).normalized()
	var pier: bool = line.kind(s) == "bridge"
	for q in parts.size()/PART:
		var at := q*PART
		var y0 := parts[at+3]
		var y1 := parts[at+4]
		var col_part := parts[at+5] == COL
		var col := (STONE_C if pier else TIMBER_C) if col_part else Color(CAP_C if pier else TIMBER_C.darkened(0.12),CAP_SHELTER)
		var mid := c+right*parts[at]
		mid.y = (y0+y1)*0.5
		_box(m,mid,right*parts[at+1],along*parts[at+2],Vector3.UP*((y1-y0)*0.5),col,not col_part)

## The abutment at a span's end s (`into` +1 at its start, -1 at its end):
## a block from ABUT_BACK under the bed to ABUT_IN into the span, its top at
## the bed's, its foot under the bank's spill.
func _abutment(m: RefCounted, s: float, into: float, foot: float) -> void:
	var f := _frame(s)
	var along: Vector3 = f.f*into
	var mid_s := s+into*(ABUT_IN-ABUT_BACK)*0.5
	var top: float = line.bed(s)-0.02
	var c: Vector3 = line.centre(mid_s)
	c.y = (top+foot)*0.5
	var flat := Vector3(along.x,0.0,along.z).normalized()
	var right := flat.cross(Vector3.UP).normalized()
	_box(m,c,right*(_half+ABUT_PAST),flat*((ABUT_IN+ABUT_BACK)*0.5),Vector3.UP*((top-foot)*0.5),STONE_C,false)

## A box at `c` with half axes x, z (level) and y (up); its floor too when
## `under` (seen from under: caps, girts).
func _box(m: RefCounted, c: Vector3, x: Vector3, z: Vector3, y: Vector3, col: Color, under: bool) -> void:
	m.box(c,x,z,y,col)
	if under:
		var bot := c-y
		m.quad(bot-x-z,bot+x-z,bot+x+z,bot-x+z,-y,col)

func _collide(i: int) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_faces[i])
	var body := StaticBody3D.new()
	body.collision_layer = LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	_body[i] = body

# --- The flight -------------------------------------------------------------------

## The stretches of stone at `p` grown by `pad`, as Vector2(bottom, top),
## sorted and joined. The deck's and the abutments' tops grow by the pad
## only past their sides (`_up`; at their ends the bed carries on at their
## height): over them the plane rides them as land, so its wheels can touch
## down on the deck (wings level, the pad is the plane's reach sideways,
## not down).
func _stretches(p: Vector3, pad: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cell: Variant = _cells.get(Vector2i(floori(p.x/CELL),floori(p.z/CELL)))
	if cell == null: return out
	var q: Vector3 = _bed.across(p.x,p.z)
	if is_nan(q.x): return out
	var s := q.x
	var d := q.y
	var bed := q.z
	var ad := absf(d)
	for k: int in cell:
		if s < _s0[k]-ABUT_BACK-pad or s > _s1[k]+ABUT_BACK+pad: continue
		# The deck.
		if s >= _s0[k]-pad and s <= _s1[k]+pad and ad <= _deck_half+pad:
			out.append(Vector2(bed+_top_up-DECK_DEPTH-pad,bed+_top_up+_up(ad-_deck_half,pad)))
		# The abutments.
		var ah := _half+ABUT_PAST+pad
		if ad <= ah:
			var side := ad-_half-ABUT_PAST
			if s >= _s0[k]-ABUT_BACK-pad and s <= _s0[k]+ABUT_IN+pad: out.append(Vector2(_abut_foot[k].x,bed+_up(side,pad)))
			if s >= _s1[k]-ABUT_IN-pad and s <= _s1[k]+ABUT_BACK+pad: out.append(Vector2(_abut_foot[k].y,bed+_up(side,pad)))
		# The supports within reach along s.
		var ss: PackedFloat32Array = _sup_s[k]
		if ss.is_empty(): continue
		var reach := PIER_CAP_ALONG*0.5+pad
		var i0 := ss.bsearch(s-reach)
		for i in range(i0,ss.size()):
			var ds := absf(s-ss[i])
			if ss[i] > s+reach: break
			var parts: PackedFloat32Array = _sup_parts[k][i]
			for t in parts.size()/PART:
				var at := t*PART
				if ds > parts[at+2]+pad or absf(d-parts[at]) > parts[at+1]+pad: continue
				out.append(Vector2(parts[at+3]-pad,parts[at+4]+pad))
	if out.size() < 2: return out
	out.sort()
	var joined: Array[Vector2] = [out[0]]
	for i in range(1,out.size()):
		var last := joined[joined.size()-1]
		if out[i].x <= last.y+0.05: joined[joined.size()-1] = Vector2(last.x,maxf(last.y,out[i].y))
		else: joined.append(out[i])
	return joined

## A top's growth `past` m beyond its edge (<= 0 over it): none over it,
## the pad's share past it.
static func _up(past: float, pad: float) -> float:
	return clampf(past,0.0,pad)

## SkyGlide's `ground` at `p` over `h` (as LandArches `ground`): a float
## (the land, raised by a support or an abutment, or the deck's top over
## it) or Vector2(top, underside) under the deck. `h` passed back as it is
## if it isn't a height.
func ground(p: Vector3, h: Variant, pad := 0.0) -> Variant:
	if not h is float or _s0.is_empty(): return h
	var list := _stretches(p,maxf(pad,0.0))
	if list.is_empty(): return h
	var top: float = h
	var under := -INF
	for st: Vector2 in list:
		if st.x <= top+0.6:
			top = maxf(top,st.y)
			continue
		if p.y >= st.y:
			top = st.y
			under = st.x
			continue
		if p.y >= (top+st.x)*0.5: return Vector2(st.y,st.x)
		break
	return top if under == -INF else Vector2(top,under)

## In the stone (the camera keeps out, the rolling plane is blocked).
func inside(p: Vector3) -> bool:
	if _s0.is_empty(): return false
	for st: Vector2 in _stretches(p,0.0):
		if p.y >= st.x and p.y <= st.y: return true
	return false

## The solid's top under `p` over the land's `h` (the wheels' and the eye's
## floor): the deck's top when over its middle height, an abutment's top.
func land_y(p: Vector3, h: float) -> float:
	if _s0.is_empty(): return h
	for st: Vector2 in _stretches(p,0.0):
		if p.y >= (st.x+st.y)*0.5 and st.y > h: h = st.y
	return h

## A line for a driver: what was built.
func note() -> String:
	return "%d spans, %d supports, %d pieces, %d tris, built in %.1f ms" % [_s0.size(),supports,_pc.size(),tris,build_ms]
