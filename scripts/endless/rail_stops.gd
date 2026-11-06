extends Node3D
## The railroad's four stops (spec-railroad.md, lane line), in greybox
## blocks: at each station (RailLine's rail/start-station, farm-town,
## mine-town, cattle-town pieces) a platform outside each track, a station
## house and a water tower, and a town of false-fronted blocks along a main
## street beside the line, with one landmark each (the farm's grain
## elevator, the cattle pens, the mine's headframe up the hill). Nobody
## about.
##
## The towns stand where the stations are (tools/rail_line.py put each
## station on the nearest 160 m of plain bed to its map place): each street
## is placed by hand in the station's frame (STOPS: `head` along s and
## across, `turn` off the line), on the flattest dry ground beside it. Mine
## town's street runs along the bench of the hill over its station, 10 m
## above the line, the headframe higher up behind it: the valley under the
## mine trestle is a sea inlet (the map's place, (-4500, 700), 560 m off, is
## in the water), so the town is on the shore's hill, in sight ahead from
## the trestle.
## Each street has its handle (`rail/<stop>-street`, AGENTS.md Handles): a
## layout's move wins over the coded spot. The station's parts follow the
## line (its piece's s).
##
## Every part is a level box (a centre, its axes, a foot and a top). Built
## at setup (one mesh and one static body of boxes per stop, seen out to
## VISIBLE). The flight meets them as stone, as the spans
## (rail_span.gd): `ground` raises the land to a roof, or gives
## Vector2(top, underside) under the water tank; `inside` keeps the camera
## out; `land_y` puts the wheels on a roof or a platform. Trees keep off
## each town and station (`tree_keepouts`, read by tree_plan.gd).
##
## Seed 1's wilderness with the bed (RailTrack.wanted); `--no-railroad`
## leaves it out.

const RailLine = preload("res://scripts/endless/rail_line.gd")
const RailBed = preload("res://scripts/endless/rail_bed.gd")
const RailTrack = preload("res://scripts/endless/rail_track.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")

const LAYER := 1
const VISIBLE := 6000.0
## The platforms: s either side of the station (the tool's PLATFORM, the
## plain bed it found), their top over the bed (a car's floor is 1.4), the
## room left to a car's side, how far out they reach, the boxes' length.
const PLATFORM_HALF := 80.0
const PLATFORM_TOP := 1.1
const PLATFORM_ROOM := 0.4
const PLATFORM_OUT := 16.0
const PLATFORM_STEP := 4.0
## The station house beside the town side's platform: along, across, tall.
const HOUSE := Vector3(36.0,14.0,11.0)
const HOUSE_ROOF := 3.0
## The water tower on the far side: its legs a bay apart (toy width
## TOY_LEGS: 8 m between the legs at the defaults), the tank's underside
## and size over the bed.
const TOY_LEGS := 4.0
const LEG := 1.2
const TANK_UNDER := 14.0
const TANK := Vector2(12.0,9.0)
const TOWER_AT := 56.0   # m of s from the station
## The main street: its width an opening (toy width TOY_STREET, 24 m at
## the defaults); lots along it, now and then an alley to thread (toy width
## TOY_ALLEY, the game's usual 7 m); a block's frontage, depth and height
## ranges; a false front FRONT tall over it and FRONT_DEEP thick.
const TOY_STREET := 12.0
const TOY_ALLEY := 3.5
const LOT_WIDE := Vector2(13.0,20.0)
const LOT_DEEP := Vector2(18.0,28.0)
const LOT_TALL := Vector2(8.0,17.0)
const FRONT := 3.5
const FRONT_DEEP := 0.8
const TIGHT := 0.4    # the gap between two blocks with no alley
## The street's first lot starts this far along it from its head.
const STREET_IN := 6.0
## Feet sink this far under the lowest ground of their corners; a stone
## plinth to PLINTH over the block's base.
const SINK := 2.0
const PLINTH := 0.5
## Trees keep this far round a stop's parts (and tree_plan's own margin).
const TREE_PAD := 6.0
## Colours over the ruins' stone (its vertex colour).
const PLATFORM_C := Color(0.62,0.58,0.52)
const STONE_C := Color(0.80,0.74,0.65)
const TIMBER_C := Color(0.55,0.42,0.30)
const ROOF_C := Color(0.38,0.30,0.26)
const TANK_C := Color(0.50,0.38,0.28)
const FRONTS := [Color(0.72,0.40,0.30),Color(0.80,0.66,0.42),Color(0.55,0.60,0.62),Color(0.85,0.80,0.70),Color(0.60,0.46,0.34),Color(0.50,0.56,0.44)]
## The shelter (vertex alpha) of an underside, so it reads in shade.
const UNDER_SHELTER := 0.35

## The stops, by the line's piece: the town's side of the line (+1 the
## right of +s), the street's head (m along s from the station, m out from
## the centre line on that side), its turn off straight-out (degrees,
## toward +s), how many lots a side, the landmark.
const STOPS := [
	{"piece":"rail/start-station","street":"rail/start-station-street","side":1.0,"head":Vector2(-6.0,40.0),"turn":0.0,"lots":2,"mark":"shed"},
	{"piece":"rail/farm-town","street":"rail/farm-town-street","side":1.0,"head":Vector2(-18.0,40.0),"turn":0.0,"lots":5,"mark":"elevator"},
	{"piece":"rail/mine-town","street":"rail/mine-town-street","side":-1.0,"head":Vector2(-150.0,80.0),"turn":90.0,"lots":6,"mark":"headframe"},
	{"piece":"rail/cattle-town","street":"rail/cattle-town-street","side":-1.0,"head":Vector2(10.0,40.0),"turn":0.0,"lots":5,"mark":"pens"},
]

## Part kinds: where its base is and how its foot is laid.
## BED: its base the bed's at s; GROUND: the ground's at its centre.
const BED := 0
const GROUND := 1

## The plan (XZ only, no heights: tree_plan's workers read it), built once.
static var _lock := Mutex.new()
static var _plan_done := false
static var _plan: Array = []

var line: RefCounted
var field: RefCounted
var _stone: Material
## The boxes: B floats each (cx, cz, ux, uz, hx, hz, y0, y1), the axes level
## (u along local x, its left-turn along local z), and a grid of CELL m
## squares listing the boxes that reach each.
const B := 8
const CELL := 32.0
var _b := PackedFloat32Array()
var _cells := {}
var _grow := 0.0
var tris := 0
var build_ms := 0.0
var stops := 0

func setup(land_field: RefCounted) -> void:
	var t0 := Time.get_ticks_usec()
	field = land_field
	line = RailLine.shared()
	_stone = RuinKit.materials().stone
	_grow = WorldScale.span*0.5+1.0
	for stop: Dictionary in plan():
		_build_stop(stop)
		stops += 1
	build_ms = (Time.get_ticks_usec()-t0)/1000.0

# --- The plan (XZ) -------------------------------------------------------------

## Every stop's parts: [{name, parts: [part]}], each part {c (XZ), u (its
## local x axis, unit, level), hx, hz (half sizes along u and across), base
## (BED or GROUND), s (the bed's s for BED), lo (its bottom over the base,
## or -INF from the ground's foot), hi (its top over the base), col,
## under (draw its underside), plinth (a stone foot under it)}.
static func plan() -> Array:
	_lock.lock()
	if not _plan_done:
		_plan = _make_plan()
		_plan_done = true
	_lock.unlock()
	return _plan

static func _make_plan() -> Array:
	var out: Array = []
	var ln: RefCounted = RailLine.shared()
	if not ln.ok: return out
	for spec: Dictionary in STOPS:
		var piece: Dictionary = ln.piece(str(spec.piece))
		if piece.is_empty(): continue
		var s := float(piece.s0)
		var side := float(spec.side)
		var station: Array = []
		_station(ln,s,side,station)
		var street: Array = []
		var marks: Array = []
		_town(ln,s,spec,street,marks)
		var right: Vector2 = _frame(ln,s)[2]
		var su: Vector2 = street[0].u if not street.is_empty() else right
		# Each group's frame for the trees' keep-out: its x across, its z
		# (tree_plan's approach) along the line or the street.
		var groups := [[station,right],[street,Vector2(-su.y,su.x)],[marks,right]]
		var parts: Array = station+street+marks
		out.append({"name":str(spec.piece),"s":s,"parts":parts,"groups":groups})
	return out

## The station's frame at s: centre XZ, along (level, +s), right (level).
static func _frame(ln: RefCounted, s: float) -> Array:
	var c: Vector3 = ln.centre(s)
	var f: Vector3 = ln.tangent(s)
	var along := Vector2(f.x,f.z).normalized()
	var right := Vector2(-along.y,along.x)
	return [Vector2(c.x,c.z),along,right]

static func _part(c: Vector2, u: Vector2, hx: float, hz: float, base: int, s: float, lo: float, hi: float, col: Color, under := false, plinth := false) -> Dictionary:
	return {"c":c,"u":u,"hx":hx,"hz":hz,"base":base,"s":s,"lo":lo,"hi":hi,"col":col,"under":under,"plinth":plinth}

## The platforms (either side, along the curve in PLATFORM_STEP boxes), the
## house on the town side, the water tower on the other.
static func _station(ln: RefCounted, s: float, side: float, parts: Array) -> void:
	var inner := float(ln.track_gap())*0.5+RailLine.CAR_WIDTH*0.5+PLATFORM_ROOM
	var n := ceili(PLATFORM_HALF*2.0/PLATFORM_STEP)
	for k in n:
		var sm := s-PLATFORM_HALF+(k+0.5)*PLATFORM_STEP
		var fr := _frame(ln,sm)
		# On a curve the outer edge runs longer than s: each box reaches its
		# neighbours there (the inner side overlaps a little).
		var bend := absf(_frame(ln,sm-PLATFORM_STEP*0.5)[1].angle_to(_frame(ln,sm+PLATFORM_STEP*0.5)[1]))
		var along := PLATFORM_STEP*0.5+PLATFORM_OUT*bend*0.5+0.05
		for sd: float in [-1.0,1.0]:
			var c: Vector2 = fr[0]+fr[2]*sd*(inner+PLATFORM_OUT)*0.5
			parts.append(_part(c,fr[2],(PLATFORM_OUT-inner)*0.5,along,BED,sm,-INF,PLATFORM_TOP,PLATFORM_C))
	var fr := _frame(ln,s)
	var right: Vector2 = fr[2]*side
	var house: Vector2 = fr[0]+right*(PLATFORM_OUT+HOUSE.y*0.5)
	parts.append(_part(house,fr[2],HOUSE.y*0.5,HOUSE.x*0.5,BED,s,-INF,HOUSE.z,TIMBER_C,false,true))
	parts.append(_part(house,fr[2],HOUSE.y*0.5+1.2,HOUSE.x*0.5+1.2,BED,s,HOUSE.z,HOUSE.z+HOUSE_ROOF,ROOF_C,true))
	# The water tower past the platform's far end on the other side.
	var ts := s+TOWER_AT*side
	var tf := _frame(ln,ts)
	var off := WorldScale.opening(TOY_LEGS)*0.5+LEG*0.5
	var tc: Vector2 = tf[0]-tf[2]*side*(PLATFORM_OUT+off+LEG+2.0)
	for e: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		var lc: Vector2 = tc+tf[2]*e.x*off+tf[1]*e.y*off
		parts.append(_part(lc,tf[2],LEG*0.5,LEG*0.5,BED,ts,-INF,TANK_UNDER,TIMBER_C.darkened(0.15)))
	parts.append(_part(tc,tf[2],TANK.x*0.5,TANK.x*0.5,BED,ts,TANK_UNDER,TANK_UNDER+TANK.y,TANK_C,true))
	parts.append(_part(tc,tf[2],TANK.x*0.5-1.5,TANK.x*0.5-1.5,BED,ts,TANK_UNDER+TANK.y,TANK_UNDER+TANK.y+2.0,ROOF_C))

## A town: its main street from the head (the handle's spot), lots both
## sides, its landmark.
static func _town(ln: RefCounted, s: float, spec: Dictionary, parts: Array, marks: Array) -> void:
	var fr := _frame(ln,s)
	var side := float(spec.side)
	var head: Vector2 = spec.head
	var away: Vector2 = fr[2]*side
	var turn := deg_to_rad(float(spec.turn))
	var u0: Vector2 = (away*cos(turn)+fr[1]*sin(turn)).normalized()
	var at: Vector2 = fr[0]+fr[1]*head.x+away*head.y
	var coded := Transform3D(Basis.looking_at(Vector3(u0.x,0.0,u0.y),Vector3.UP),Vector3(at.x,ln.bed(s),at.y))
	var xf := LayoutOverrides.xform(str(spec.street),coded)
	if LayoutOverrides.deleted(str(spec.street)): return
	var o := Vector2(xf.origin.x,xf.origin.z)
	var fz := -xf.basis.z
	var u := Vector2(fz.x,fz.z).normalized()
	var v := Vector2(-u.y,u.x)
	var half := WorldScale.opening(TOY_STREET)*0.5
	var rng := _Hash.new(str(spec.piece))
	var reach := 0.0
	for sd: float in [-1.0,1.0]:
		var x := STREET_IN
		for k in int(spec.lots):
			var wide := rng.range(LOT_WIDE)
			var deep := rng.range(LOT_DEEP)
			var tall := rng.range(LOT_TALL)
			var col: Color = FRONTS[rng.pick(FRONTS.size())]
			var mid := o+u*(x+wide*0.5)+v*sd*(half+deep*0.5)
			# The block, its roof (a shade darker) and its false front on the
			# street, taller than the block.
			parts.append(_part(mid,u,wide*0.5,deep*0.5,GROUND,0.0,-INF,tall,TIMBER_C.lerp(col,0.25),false,true))
			var front := o+u*(x+wide*0.5)+v*sd*(half+FRONT_DEEP*0.5)
			parts.append(_part(front,u,wide*0.5,FRONT_DEEP*0.5,GROUND,0.0,0.0,tall+FRONT,col))
			x += wide+(WorldScale.opening(TOY_ALLEY) if k%2 == 1 else TIGHT)
		reach = maxf(reach,x)
	var mark := str(spec.mark)
	if mark == "elevator": _elevator(ln,s,fr,side,marks)
	elif mark == "pens": _pens(ln,s,fr,side,marks)
	elif mark == "headframe": _headframe(fr,side,marks)
	elif mark == "shed": _shed(ln,s,fr,side,marks)

## The farm's grain elevator beside the line past the house: a tall bin
## house, its head on top, a low annex.
static func _elevator(ln: RefCounted, s: float, fr: Array, side: float, parts: Array) -> void:
	var a := HOUSE.x*0.5+22.0
	var sf := _frame(ln,s+a)
	var away: Vector2 = sf[2]*side
	var c: Vector2 = sf[0]+away*(PLATFORM_OUT+11.0)
	parts.append(_part(c,sf[2],9.0,8.0,BED,s+a,-INF,34.0,Color(0.70,0.62,0.50),false,true))
	parts.append(_part(c,sf[2],4.0,4.0,BED,s+a,34.0,42.0,Color(0.66,0.56,0.44)))
	var b: Vector2 = c+sf[1]*14.0
	parts.append(_part(b,sf[2],7.0,6.0,BED,s+a,-INF,12.0,TIMBER_C,false,true))

## The cattle pens along the line short of the platform's start on the town
## side (past its end a creek crosses): a grid of low rail fences.
static func _pens(ln: RefCounted, s: float, fr: Array, side: float, parts: Array) -> void:
	const PEN := 20.0
	const ROWS := 2
	const COLS := 4
	const RAIL := 0.5
	const HIGH := 2.2
	var s0 := s-PLATFORM_HALF-12.0-PEN*COLS
	var sf := _frame(ln,s0+PEN*COLS*0.5)
	var along: Vector2 = sf[1]
	var away: Vector2 = sf[2]*side
	var o: Vector2 = sf[0]+away*(PLATFORM_OUT+4.0)-along*PEN*COLS*0.5
	for r in ROWS+1:
		var c := o+away*r*PEN+along*PEN*COLS*0.5
		parts.append(_part(c,sf[2],RAIL*0.5,PEN*COLS*0.5,GROUND,0.0,-INF,HIGH,TIMBER_C))
	for k in COLS+1:
		var c := o+along*k*PEN+away*PEN*ROWS*0.5
		parts.append(_part(c,sf[2],PEN*ROWS*0.5,RAIL*0.5,GROUND,0.0,-INF,HIGH,TIMBER_C))
	# The loading chute up to a car's floor by the platform's start.
	var cs := s-PLATFORM_HALF-4.0
	var cf := _frame(ln,cs)
	var ch: Vector2 = cf[0]+cf[2]*side*(PLATFORM_OUT-1.0)
	parts.append(_part(ch,cf[2],3.0,3.0,BED,cs,-INF,PLATFORM_TOP+0.3,TIMBER_C.darkened(0.1)))

## The mine's headframe up the hill behind the town: four legs a bay
## apart, a cap and the sheave house on top.
static func _headframe(fr: Array, side: float, parts: Array) -> void:
	const TALL := 30.0
	var off := WorldScale.opening(TOY_LEGS)*0.5+LEG*0.5
	var c: Vector2 = fr[0]-fr[1]*60.0+fr[2]*side*150.0
	for e: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		parts.append(_part(c+fr[2]*e.x*off+fr[1]*e.y*off,fr[2],LEG*0.5,LEG*0.5,GROUND,0.0,-INF,TALL,TIMBER_C.darkened(0.2)))
	parts.append(_part(c,fr[2],off+LEG,off+LEG,GROUND,0.0,TALL,TALL+2.0,TIMBER_C.darkened(0.1),true))
	parts.append(_part(c,fr[2],3.5,5.0,GROUND,0.0,TALL+2.0,TALL+7.0,ROOF_C))
	# The engine house at its foot, downhill toward the line.
	var h: Vector2 = c-fr[2]*side*(off+14.0)
	parts.append(_part(h,fr[2],8.0,11.0,GROUND,0.0,-INF,10.0,STONE_C.darkened(0.15),false,true))

## The start's freight shed along the platform's far end on the town side.
static func _shed(ln: RefCounted, s: float, fr: Array, side: float, parts: Array) -> void:
	var a := -(HOUSE.x*0.5+26.0)
	var sf := _frame(ln,s+a)
	var c: Vector2 = sf[0]+sf[2]*side*(PLATFORM_OUT+9.0)
	parts.append(_part(c,sf[2],9.0,16.0,BED,s+a,-INF,9.0,TIMBER_C.darkened(0.05),false,true))
	parts.append(_part(c,sf[2],10.0,17.0,BED,s+a,9.0,10.0,ROOF_C,true))

## Trees keep off each stop: [pos XZ, cos, sin, half x, half z] as
## tree_plan's arches (its margin and the approach along local z on top):
## a rectangle round the station, one round the town's street (its
## approach along the street), one round the landmark. The caller asks
## only with the railroad on (RailTrack.wanted).
static func tree_keepouts(x0: float, z0: float, x1: float, z1: float) -> Array:
	var out: Array = []
	for stop: Dictionary in plan():
		for group: Array in stop.groups:
			var parts: Array = group[0]
			if parts.is_empty(): continue
			var a: Vector2 = group[1]
			var b := Vector2(-a.y,a.x)
			var c0: Vector2 = parts[0].c
			var lo := Vector2(INF,INF)
			var hi := Vector2(-INF,-INF)
			for p: Dictionary in parts:
				var pc: Vector2 = p.c
				var pu: Vector2 = p.u
				var pv := Vector2(-pu.y,pu.x)
				for e: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
					var q: Vector2 = pc+pu*e.x*float(p.hx)+pv*e.y*float(p.hz)-c0
					var l := Vector2(q.dot(a),q.dot(b))
					lo = lo.min(l)
					hi = hi.max(l)
			var mid := (lo+hi)*0.5
			var c: Vector2 = c0+a*mid.x+b*mid.y
			var h := (hi-lo)*0.5+Vector2.ONE*TREE_PAD
			var r := h.length()
			if c.x+r < x0-400.0 or c.x-r > x1+400.0 or c.y+r < z0-400.0 or c.y-r > z1+400.0: continue
			# tree_plan: lx = |ox cos - oz sin| along (cos, -sin) = a, lz
			# along (sin, cos) = b (up to its sign).
			out.append([c,a.x,-a.y,h.x,h.y])
	return out

# --- Building ---------------------------------------------------------------------

func _build_stop(stop: Dictionary) -> void:
	var m := RailTrack._Mesh.new()
	var body := StaticBody3D.new()
	body.name = str(stop.name).replace("rail/","")
	body.collision_layer = LAYER
	body.collision_mask = 0
	for p: Dictionary in stop.parts:
		_box_of(p,m,body)
	if m.verts.is_empty(): return
	var mi := m.instance(_stone)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.visibility_range_end = VISIBLE
	add_child(mi)
	add_child(body)
	tris += m.verts.size()/3

## A part's box with its heights from the land: its mesh, collider and
## flight record; a stone plinth under it when it asks.
func _box_of(p: Dictionary, m: RefCounted, body: StaticBody3D) -> void:
	var c: Vector2 = p.c
	var u: Vector2 = p.u
	var v := Vector2(-u.y,u.x)
	var hx := float(p.hx)
	var hz := float(p.hz)
	var foot := INF
	var top_g := -INF
	for e: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1),Vector2.ZERO]:
		var q := c+u*e.x*hx+v*e.y*hz
		var g := float(field.height(q.x,q.y))
		foot = minf(foot,g)
		top_g = maxf(top_g,g)
	var base := float(line.bed(float(p.s))) if int(p.base) == BED else float(field.height(c.x,c.y))
	foot -= SINK
	var lo := float(p.lo)
	var y0 := foot if lo == -INF else base+lo
	var y1 := base+float(p.hi)
	if y1 <= y0+0.05: return
	if bool(p.plinth) and base+PLINTH > foot:
		_add(c,u,hx+0.3,hz+0.3,foot,base+PLINTH,STONE_C,false,m,body)
		y0 = maxf(y0,base)
	_add(c,u,hx,hz,y0,y1,p.col,bool(p.under),m,body)

func _add(c: Vector2, u: Vector2, hx: float, hz: float, y0: float, y1: float, col: Color, under: bool, m: RefCounted, body: StaticBody3D) -> void:
	var x := Vector3(u.x,0.0,u.y)*hx
	var z := Vector3(-u.y,0.0,u.x)*hz
	var y := Vector3(0.0,(y1-y0)*0.5,0.0)
	var mid := Vector3(c.x,(y0+y1)*0.5,c.y)
	m.box(mid,x,z,y,col)
	if under:
		var bot := mid-y
		m.quad(bot-x-z,bot+x-z,bot+x+z,bot-x+z,-y,Color(col,UNDER_SHELTER))
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(hx*2.0,y1-y0,hz*2.0)
	cs.shape = shape
	cs.transform = Transform3D(Basis(Vector3(u.x,0.0,u.y),Vector3.UP,Vector3(-u.y,0.0,u.x)),mid)
	body.add_child(cs)
	var i := _b.size()/B
	_b.append_array([c.x,c.y,u.x,u.y,hx,hz,y0,y1])
	var r := Vector2(hx,hz).length()+_grow
	for cz in range(floori((c.y-r)/CELL),floori((c.y+r)/CELL)+1):
		for cx in range(floori((c.x-r)/CELL),floori((c.x+r)/CELL)+1):
			var key := Vector2i(cx,cz)
			var l: PackedInt32Array = _cells.get(key,PackedInt32Array())
			l.append(i)
			_cells[key] = l

# --- The flight -------------------------------------------------------------------

## The stretches of stone at `p` grown by `pad` (no more than the plane's
## half span), as Vector2(bottom, top), sorted and joined.
func _stretches(p: Vector3, pad: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cell: Variant = _cells.get(Vector2i(floori(p.x/CELL),floori(p.z/CELL)))
	if cell == null: return out
	pad = minf(pad,_grow)
	for i: int in cell:
		var at := i*B
		var ox := p.x-_b[at]
		var oz := p.z-_b[at+1]
		var lx := ox*_b[at+2]+oz*_b[at+3]
		var lz := -ox*_b[at+3]+oz*_b[at+2]
		if absf(lx) > _b[at+4]+pad or absf(lz) > _b[at+5]+pad: continue
		out.append(Vector2(_b[at+6]-pad,_b[at+7]+pad))
	if out.size() < 2: return out
	out.sort()
	var joined: Array[Vector2] = [out[0]]
	for i in range(1,out.size()):
		var last := joined[joined.size()-1]
		if out[i].x <= last.y+0.05: joined[joined.size()-1] = Vector2(last.x,maxf(last.y,out[i].y))
		else: joined.append(out[i])
	return joined

## SkyGlide's `ground` at `p` over `h` (as LandArches `ground`): a float
## (the land raised by a block, a roof's top) or Vector2(top, underside)
## under the water tank. `h` passed back as it is if it isn't a height.
func ground(p: Vector3, h: Variant, pad := 0.0) -> Variant:
	if not h is float or _b.is_empty(): return h
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

## In a block (the camera keeps out, the rolling plane is blocked).
func inside(p: Vector3) -> bool:
	if _b.is_empty(): return false
	for st: Vector2 in _stretches(p,0.0):
		if p.y >= st.x and p.y <= st.y: return true
	return false

## The top under `p` over the land's `h` (the wheels' and the eye's floor):
## a roof, a platform, the tank's top when over its middle height.
func land_y(p: Vector3, h: float) -> float:
	if _b.is_empty(): return h
	for st: Vector2 in _stretches(p,0.0):
		if p.y >= (st.x+st.y)*0.5 and st.y > h: h = st.y
	return h

## A line for a driver: what was built.
func note() -> String:
	return "%d stops, %d boxes, %d tris, built in %.1f ms" % [stops,_b.size()/B,tris,build_ms]

## A stable pick from a name: the same town on every machine.
class _Hash:
	var _h := 0
	func _init(key: String) -> void:
		_h = hash(key) & 0x7fffffff
	func next() -> float:
		_h = (_h*1103515245+12345) & 0x7fffffff
		return float(_h)/float(0x7fffffff)
	func range(r: Vector2) -> float:
		return lerpf(r.x,r.y,next())
	func pick(n: int) -> int:
		return mini(int(next()*n),n-1)
