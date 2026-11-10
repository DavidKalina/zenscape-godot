extends RefCounted
## The railroad tunnels' layout (rail_bore.gd builds it and answers for it):
## what each stretch of each bore is lined with, its cross-section, and the
## solids stood in it, laid by rule from the line (rail_line.gd), the land
## over it (the field's height) and the trains' timetable, so a re-laid line
## gets its own. Nothing here is tuned to one tunnel. Read by the builder
## (meshes, colliders, lamps) and by the flight's answers alike, so what is
## drawn is what is asked.
##
## Coordinates: s along the line, d across it (+ on the right of +s, track
## 0's side), y over the bed's top. A tunnel runs s0..s1; `into` is m in
## from its nearer face.
##
## The rules, per tunnel of length L:
## - ASHLAR: dressed stone the first PORTAL_LINED m in from each face, and
##   the whole of a tunnel shorter than SHORT. Arch rings every 6 m.
## - BRICK: a masonry lining wherever the rock is near the surface or the
##   face (into under LINED_IN, or the cover over the crown under
##   ROCK_COVER). Ribs every 12 m, refuges in the walls.
## - ROCK: unlined rough rock deeper in, the lamps sparser; rock spurs off
##   the walls every SPUR_EVERY m or so, a side at a time.
## - TIMBER: where a lining meets bare rock the ground is bad: TIMBER_LEN m
##   of close timber sets on the rock's side, and a rock fall heaped against
##   the wall in their middle, the uphill side first, then the sides taking
##   turns; and the same every ROCK_RUN m of a long run of bare rock.
## - CAVERN: in a tunnel with enough bare rock, the CAVERN_LEN m of it
##   under the deepest cover (at least CAVERN_COVER) opens wide and high,
##   rock pillars standing in its width either side of the tracks.
## - The arcade: a row of piers between the tracks with arches to switch
##   sides through, along the lined middle of a tunnel at least ARCADE_MIN
##   long, where the timetable never has two trains side by side (within a
##   train's length and MEET_PAST of a meeting's point): the gap between
##   passing trains stays open.
##
## The trains' room is kept clear of everything: cars TRAIN_HALF m either
## side of each track to TRAIN_TALL m up, and over them a riding plane's
## room; members stand only past CLEAR_D m off the centre line (or under the
## vault's own line over the cars), the arcade only inside the gap.

const RailLine = preload("res://scripts/endless/rail_line.gd")
const BoreShape = preload("res://scripts/endless/rail_bore_shape.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const RailTrains = preload("res://scripts/endless/rail_trains.gd")
const RailTrain = preload("res://scripts/endless/rail_train.gd")

enum { ASHLAR, BRICK, TIMBER, ROCK, CAVERN }
const KIND_NAMES := ["ashlar","brick","timber","rock","cavern"]
## Member kinds: a box in (s, d, y); a heap (a rock fall); the arcade.
enum { M_BOX, M_PILE, M_ARCADE }
## Member looks (the builder's): rock, timber, iron, dressed stone.
enum { L_ROCK, L_TIMBER, L_IRON, L_STONE, L_BRICK }

## The lining's stretches (m).
const PORTAL_LINED := 36.0
const SHORT := 180.0
const LINED_IN := 150.0
const ROCK_COVER := 45.0
const TIMBER_LEN := 42.0
## A bare-rock run this long or more gets timber sets in it too.
const ROCK_RUN := 300.0
## The cavern: its length, its least cover over the standard crown, the
## bare rock it needs either side, its ease in and out (m); its section.
const CAVERN_LEN := 168.0
const CAVERN_COVER := 70.0
const CAVERN_FLARE := 26.0
const CAVERN_HALF := 31.0
const CAVERN_SPRING := 9.0
const CAVERN_CROWN := 31.0
## The ribs per lining: [every, width along s, depth in] (m); 0: none.
const RIBS := {ASHLAR: Vector3(6.0,1.2,0.45), BRICK: Vector3(12.0,1.0,0.4), TIMBER: Vector3(3.0,0.5,0.6)}
## Lamps on brackets: every m per lining (alternating walls), at the
## spring plus LAMP_UP, reaching LAMP_OUT m off the wall.
const LAMP_EVERY := {ASHLAR: 30.0, BRICK: 30.0, TIMBER: 21.0, ROCK: 48.0, CAVERN: 0.0}
const LAMP_UP := 0.8
const LAMP_OUT := 1.3
## Refuges in a lined wall: every REFUGE_BAYS-th bay between ribs, sides
## alternating; their size (m).
const REFUGE_BAYS := 2
const REFUGE_W := 2.4
const REFUGE_H := 3.6
const REFUGE_DEEP := 1.4
## The drains along each wall's foot (m wide), drawn only.
const DRAIN := 1.1
## The train's room: half a car's width past each track, its height, and
## over a car a riding plane (its height and an opening over it).
const TRAIN_TALL := 9.0
const RIDE_ROOM := 1.6
## Members keep CLEAR_D m off the centre line at least (the car's outer
## side and an opening for the plane between: TOY_LANE).
const TOY_LANE := 3.5
## Rock spurs: about every SPUR_EVERY m of bare rock, SPUR_LONG along s,
## out to the lane's edge, SPUR_TALL high.
const SPUR_EVERY := 64.0
const SPUR_LONG := 4.5
const SPUR_TALL := 5.0
## The rock fall: along s, how far it eases at its ends, the ramp across
## from its inner foot; over its crest an opening of TOY_OVER under the
## vault.
const PILE_LONG := 26.0
const PILE_EASE := 9.0
const PILE_RAMP := 3.0
const TOY_OVER := 3.5
const PILE_JIT := 0.3
## The cavern's pillars: their size (along s, across), every PILLAR_EVERY m
## a side, the sides staggered by half that: the gap between two on a side
## is long enough to cross the pillars' row in at cruise, a lane either side
## of them (inner: past the cars' side, TOY_LANE's opening; outer: to the
## wall).
const PILLAR_LONG := 5.0
const PILLAR_WIDE := 4.0
const PILLAR_EVERY := 40.0
## The arcade: needs a lined middle this long; piers ARC_PIER along s,
## ARC_HALF either side of the centre line, every ARC_EVERY; the arches
## spring at ARC_SPRING and rise ARC_RISE.
const ARCADE_MIN := 150.0
const ARC_PIER := 2.6
const ARC_HALF := 0.9
const ARC_EVERY := 20.0
const ARC_SPRING := 8.0
const ARC_RISE := 4.5
## A meeting's reach past a train's length (m).
const MEET_PAST := 60.0
## The portal kinds: rock-cut where the hill stands high over the crown
## FACE_PROBE m in (ROCK_FACE m or more), else a masonry facade.
const FACE_PROBE := 30.0
const ROCK_FACE := 25.0
enum { P_FACADE, P_ROCKCUT }
const PORTAL_NAMES := ["facade","rock-cut"]
## The cover's samples along a tunnel (m).
const SAMPLE := 8.0
## Member buckets along s (m).
const BUCKET := 8.0

static var _shared: RefCounted

## Per tunnel: {s0, s1, spans: [[kind, s0, s1]], portals: [kind at s0,
## kind at s1], arcade: Vector2 (s range, or empty), cavern: Vector2,
## uphill: +1/-1 per pile}.
var tunnels: Array[Dictionary] = []
## The members: kind, look, tunnel, box (s0, s1, d0, d1, y0, y1) and a
## parameter (the pile's crest).
var mk := PackedInt32Array()
var ml := PackedInt32Array()
var mt := PackedInt32Array()
var ms0 := PackedFloat32Array()
var ms1 := PackedFloat32Array()
var md0 := PackedFloat32Array()
var md1 := PackedFloat32Array()
var my0 := PackedFloat32Array()
var my1 := PackedFloat32Array()
var _bucket := {}
## Lamps: s, d (the head), y; and refuges: s centre, side.
var lamp_s := PackedFloat32Array()
var lamp_d := PackedFloat32Array()
var lamp_y := PackedFloat32Array()
var refuge_s := PackedFloat32Array()
var refuge_side := PackedFloat32Array()
var line: RefCounted
var _std := Vector3.ZERO

## The plan for the shared line over `field`, made once.
static func shared(field: RefCounted = null) -> RefCounted:
	if _shared == null and field != null:
		_shared = load("res://scripts/endless/rail_bore_plan.gd").new()
		_shared.make(RailLine.shared(),field)
	return _shared

func make(rail_line: RefCounted, field: RefCounted) -> void:
	line = rail_line
	_std = Vector3(BoreShape.half(),BoreShape.SPRING,BoreShape.rise())
	var meets := _meetings()
	var ti := 0
	for st: Array in line.stretches("tunnel"):
		_plan(ti,float(st[0]),float(st[1]),field,meets)
		ti += 1

## The s ranges where two trains can stand side by side: a train's length
## and MEET_PAST either side of each point their noses meet.
func _meetings() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var reach := RailTrain.length_of()+MEET_PAST
	for s: float in [RailTrains.LINE_TUNNEL,RailTrains.LINE_BRIDGE]:
		out.append(Vector2(s-reach,s+reach))
	return out

func _plan(ti: int, s0: float, s1: float, field: RefCounted, meets: Array[Vector2]) -> void:
	var L := s1-s0
	var t := {"s0":s0,"s1":s1,"spans":[],"portals":[P_FACADE,P_FACADE],"arcade":Vector2.ZERO,"cavern":Vector2.ZERO}
	# The cover over the standard crown along it.
	var n := maxi(2,ceili(L/SAMPLE)+1)
	var cover := PackedFloat32Array()
	for k in n:
		var s := lerpf(s0,s1,float(k)/(n-1))
		var c: Vector3 = line.centre(s)
		cover.append(float(field.height(c.x,c.z))-c.y-BoreShape.crown())
	var cover_at := func(s: float) -> float:
		var u := clampf((s-s0)/L,0.0,1.0)*(n-1)
		var i := mini(int(u),n-2)
		return lerpf(cover[i],cover[i+1],u-i)
	# The portals: rock-cut where the hill is high over the crown in from the face.
	for e in 2:
		var probe := s0+FACE_PROBE if e == 0 else s1-FACE_PROBE
		if L > FACE_PROBE*2.0 and float(cover_at.call(probe)) >= ROCK_FACE: t.portals[e] = P_ROCKCUT
	# Lined or bare along it, by each SAMPLE m step's middle; the portals'
	# dressed stone exactly PORTAL_LINED m in.
	var spans: Array = []
	for k in n-1:
		var a := lerpf(s0,s1,float(k)/(n-1))
		var b := lerpf(s0,s1,float(k+1)/(n-1))
		var s := (a+b)*0.5
		var kd := ROCK
		if L < SHORT or into_of(s,s0,s1) < PORTAL_LINED: kd = ASHLAR
		elif into_of(s,s0,s1) < LINED_IN or float(cover_at.call(s)) < ROCK_COVER: kd = BRICK
		if not spans.is_empty() and int(spans[-1][0]) == kd: spans[-1][2] = b
		else: spans.append([kd,a,b])
	if L >= SHORT:
		spans = _cut(spans,s0,s0+PORTAL_LINED,ASHLAR)
		spans = _cut(spans,s1-PORTAL_LINED,s1,ASHLAR)
		spans = _cut(spans,s0+PORTAL_LINED,s0+PORTAL_LINED+SAMPLE,BRICK) if int(_kind_in(spans,s0+PORTAL_LINED+1.0)) == ASHLAR else spans
		spans = _cut(spans,s1-PORTAL_LINED-SAMPLE,s1-PORTAL_LINED,BRICK) if int(_kind_in(spans,s1-PORTAL_LINED-1.0)) == ASHLAR else spans
	# Bare rock runs shorter than two timber stretches stay lined.
	for sp: Array in spans:
		if int(sp[0]) == ROCK and float(sp[2])-float(sp[1]) < TIMBER_LEN*2.0+20.0: sp[0] = BRICK
	spans = _merge(spans)
	# The cavern: the deepest stretch of bare rock long enough.
	var best := -INF
	var at := NAN
	for sp: Array in spans:
		if int(sp[0]) != ROCK: continue
		var a := float(sp[1])+TIMBER_LEN+40.0
		var b := float(sp[2])-TIMBER_LEN-40.0-CAVERN_LEN
		var s := a
		while s <= b:
			var least := INF
			var q := s
			while q <= s+CAVERN_LEN:
				least = minf(least,float(cover_at.call(q)))
				q += SAMPLE
			if least > best:
				best = least
				at = s
			s += SAMPLE
	if not is_nan(at) and best >= CAVERN_COVER:
		t.cavern = Vector2(at,at+CAVERN_LEN)
		spans = _cut(spans,at,at+CAVERN_LEN,CAVERN)
	# Timber sets on the rock's side of each lining's end.
	var timbers: Array[Vector2] = []
	for i in spans.size():
		var sp: Array = spans[i]
		if int(sp[0]) != ROCK: continue
		if i > 0 and int(spans[i-1][0]) in [ASHLAR,BRICK]: timbers.append(Vector2(float(sp[1]),float(sp[1])+TIMBER_LEN))
		if i < spans.size()-1 and int(spans[i+1][0]) in [ASHLAR,BRICK]: timbers.append(Vector2(float(sp[2])-TIMBER_LEN,float(sp[2])))
	# A long run of bare rock has bad ground in it too: timber sets every
	# ROCK_RUN m or so.
	for sp: Array in spans:
		var len := float(sp[2])-float(sp[1])
		if int(sp[0]) != ROCK or len < ROCK_RUN: continue
		var count := floori(len/ROCK_RUN)
		for j in range(1,count+1):
			var mid := float(sp[1])+len*j/(count+1)
			timbers.append(Vector2(mid-TIMBER_LEN*0.5,mid+TIMBER_LEN*0.5))
	for tb: Vector2 in timbers: spans = _cut(spans,tb.x,tb.y,TIMBER)
	t.spans = spans
	tunnels.append(t)
	# The arcade: the lined middle, if no meeting reaches it.
	if L >= ARCADE_MIN:
		var a := s0+PORTAL_LINED+4.0
		var b := s1-PORTAL_LINED-4.0
		var clear := true
		for m: Vector2 in meets:
			if _overlaps(a,b,m.x,m.y,line.length()): clear = false
		for sp: Array in spans:
			if int(sp[0]) in [ROCK,TIMBER,CAVERN] and float(sp[1]) < b and float(sp[2]) > a: clear = false
		if clear and b-a >= ARC_EVERY*2.0: t.arcade = Vector2(a,b)
	_members(ti,t,field)

static func _kind_in(spans: Array, s: float) -> int:
	for sp: Array in spans:
		if s >= float(sp[1]) and s <= float(sp[2]): return int(sp[0])
	return -1

static func into_of(s: float, s0: float, s1: float) -> float:
	return minf(s-s0,s1-s)

static func _merge(spans: Array) -> Array:
	var out: Array = []
	for sp: Array in spans:
		if not out.is_empty() and int(out[-1][0]) == int(sp[0]): out[-1][2] = sp[2]
		else: out.append(sp.duplicate())
	return out

## `spans` with a..b made `kind`.
static func _cut(spans: Array, a: float, b: float, kind: int) -> Array:
	var out: Array = []
	for sp: Array in spans:
		var p := float(sp[1])
		var q := float(sp[2])
		if q <= a or p >= b:
			out.append(sp)
			continue
		if p < a: out.append([sp[0],p,a])
		out.append([kind,maxf(p,a),minf(q,b)])
		if q > b: out.append([sp[0],b,q])
	return _merge(out)

static func _overlaps(a: float, b: float, c: float, d: float, n: float) -> bool:
	for k: float in [-n,0.0,n]:
		if b > c+k and a < d+k: return true
	return false

# --- Members -------------------------------------------------------------------------

func _add(kind: int, look: int, ti: int, s0: float, s1: float, d0: float, d1: float, y0: float, y1: float) -> void:
	var i := mk.size()
	mk.append(kind)
	ml.append(look)
	mt.append(ti)
	ms0.append(s0)
	ms1.append(s1)
	md0.append(minf(d0,d1))
	md1.append(maxf(d0,d1))
	my0.append(y0)
	my1.append(y1)
	for b in range(floori(s0/BUCKET),floori(s1/BUCKET)+1):
		var got: PackedInt32Array = _bucket.get(b,PackedInt32Array())
		got.append(i)
		_bucket[b] = got

## The d off the centre line no member comes inside (the trains' side and
## a lane past it).
static func clear_d() -> float:
	var line: RefCounted = RailLine.shared()
	return float(line.track_gap())*0.5+RailLine.CAR_WIDTH*0.5+WorldScale.opening(TOY_LANE)*0.25

func _members(ti: int, t: Dictionary, field: RefCounted) -> void:
	var car_out := float(line.track_gap())*0.5+RailLine.CAR_WIDTH*0.5
	var lane := WorldScale.opening(TOY_LANE)
	var hash := ti*7919
	var falls := 0
	for sp: Array in t.spans:
		var kind := int(sp[0])
		var a := float(sp[1])
		var b := float(sp[2])
		# The lamps, alternating walls.
		var every := float(LAMP_EVERY.get(kind,0.0))
		if every > 0.0:
			var k := ceili((a+every*0.25)/every)
			var s := k*every-every*0.5
			while s < b:
				if s > a+2.0:
					var side := 1.0 if (k%2) == 0 else -1.0
					_lamp(ti,s,side)
				s += every
				k += 1
		# Refuges in a lined wall, mid bay.
		if kind in [ASHLAR,BRICK]:
			var r: Vector3 = RIBS[kind]
			var bay := ceili(a/r.x)
			while (bay+0.5)*r.x < b:
				var s := (bay+0.5)*r.x
				if bay%REFUGE_BAYS == 0 and s-a > r.x and b-s > r.x and not _near_lamp(s,REFUGE_W+1.0):
					refuge_s.append(s)
					refuge_side.append(1.0 if (bay/REFUGE_BAYS)%2 == 0 else -1.0)
				bay += 1
		# Spurs off the walls of bare rock.
		if kind == ROCK:
			var s := a+SPUR_EVERY*0.6
			var side := 1.0 if (ti%2) == 0 else -1.0
			while s < b-SPUR_EVERY*0.4:
				var j := float(posmod(hash*31+int(s),97))/97.0
				var c := s+(j-0.5)*SPUR_EVERY*0.4
				_add(M_BOX,L_ROCK,ti,c-SPUR_LONG*0.5,c+SPUR_LONG*0.5,side*(car_out+lane*0.6),side*(_std.x+0.5),-0.5,SPUR_TALL)
				side = -side
				s += SPUR_EVERY
		# The rock fall in timber sets, against the uphill wall.
		if kind == TIMBER:
			var c := (a+b)*0.5
			var p: Vector3 = line.centre(c)
			var tg: Vector3 = line.tangent(c)
			var r := Vector3(-tg.z,0.0,tg.x).normalized()
			var hi := float(field.height(p.x+r.x*60.0,p.z+r.z*60.0))
			var lo := float(field.height(p.x-r.x*60.0,p.z-r.z*60.0))
			var side := (1.0 if hi >= lo else -1.0)*(1.0 if falls%2 == 0 else -1.0)
			falls += 1
			var inner := car_out+lane*0.25
			var crest := inner+PILE_RAMP
			var top := BoreShape.roof_over(crest)-float(RIBS[TIMBER].z)-WorldScale.opening(TOY_OVER)
			_add(M_PILE,L_ROCK,ti,c-PILE_LONG*0.5,c+PILE_LONG*0.5,side*inner,side*(_std.x+0.2),0.0,top)
		# The cavern's pillars, staggered.
		if kind == CAVERN:
			var lo := a+CAVERN_FLARE+PILLAR_LONG
			var hi := b-CAVERN_FLARE-PILLAR_LONG
			var d_in := car_out+lane
			for side: float in [1.0,-1.0]:
				var s := lo+(0.0 if side > 0.0 else PILLAR_EVERY*0.5)
				while s <= hi:
					_add(M_BOX,L_ROCK,ti,s-PILLAR_LONG*0.5,s+PILLAR_LONG*0.5,side*d_in,side*(d_in+PILLAR_WIDE),-0.5,CAVERN_CROWN+2.0)
					# A lamp on its face to the tracks.
					lamp_s.append(s)
					lamp_d.append(side*(d_in-0.35))
					lamp_y.append(7.0)
					s += PILLAR_EVERY
	# The arcade.
	var arc: Vector2 = t.arcade
	if arc != Vector2.ZERO:
		var n := floori((arc.y-arc.x-ARC_PIER)/ARC_EVERY)
		var a := (arc.x+arc.y)*0.5-(n*ARC_EVERY+ARC_PIER)*0.5
		t.arcade = Vector2(a,a+n*ARC_EVERY+ARC_PIER)
		_add(M_ARCADE,L_STONE,ti,t.arcade.x,t.arcade.y,-ARC_HALF,ARC_HALF,0.0,BoreShape.crown())

func _lamp(ti: int, s: float, side: float) -> void:
	var half := section(s).x
	lamp_s.append(s)
	lamp_d.append(side*(half-LAMP_OUT))
	lamp_y.append(section(s).y+LAMP_UP)
	# Its bracket, a member: from the wall out to the head.
	_add(M_BOX,L_IRON,ti,s-0.3,s+0.3,side*(half-LAMP_OUT-0.3),side*(half+0.3),section(s).y+LAMP_UP-0.35,section(s).y+LAMP_UP+0.45)

func _near_lamp(s: float, r: float) -> bool:
	for i in lamp_s.size():
		if absf(lamp_s[i]-s) < r: return true
	return false

# --- Lookups --------------------------------------------------------------------------

## The tunnel `s` is in (index), or -1; `pad` m past its faces counts.
func tunnel_at(s: float, pad := 0.0) -> int:
	for i in tunnels.size():
		var t: Dictionary = tunnels[i]
		if s >= float(t.s0)-pad and s <= float(t.s1)+pad: return i
	return -1

## The lining at s (ASHLAR outside any tunnel).
func lining(s: float) -> int:
	var ti := tunnel_at(s)
	if ti < 0: return ASHLAR
	for sp: Array in tunnels[ti].spans:
		if s >= float(sp[1]) and s <= float(sp[2]): return int(sp[0])
	return ASHLAR

## How rough the walls are at s, 0..1, eased over 6 m into bare rock.
func rough(s: float) -> float:
	var ti := tunnel_at(s)
	if ti < 0: return 0.0
	var best := 0.0
	for sp: Array in tunnels[ti].spans:
		if not int(sp[0]) in [ROCK,TIMBER,CAVERN]: continue
		var into := minf(s-float(sp[1]),float(sp[2])-s)
		best = maxf(best,clampf(into/6.0+0.5,0.0,1.0))
	return best

## The cross-section at s: Vector3(half width, spring, rise).
func section(s: float) -> Vector3:
	var ti := tunnel_at(s)
	if ti < 0: return _std
	var cv: Vector2 = tunnels[ti].cavern
	if cv == Vector2.ZERO or s <= cv.x or s >= cv.y: return _std
	var w := smoothstep(0.0,1.0,minf(s-cv.x,cv.y-s)/CAVERN_FLARE)
	var wide := Vector3(CAVERN_HALF,CAVERN_SPRING,CAVERN_CROWN-CAVERN_SPRING)
	return _std.lerp(wide,w)

## The rib's depth at s (0 between ribs), and its lining.
func inset(s: float) -> float:
	var kd := lining(s)
	if not RIBS.has(kd): return 0.0
	var r: Vector3 = RIBS[kd]
	return r.z if fposmod(s,r.x) < r.y else 0.0

## The breaks along s0..s1 the rings must fall on (rib edges, lining and
## refuge edges, the cavern's flare).
func breaks(s0: float, s1: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var ti := tunnel_at((s0+s1)*0.5,BoreShape.FACE_OUT+1.0)
	if ti < 0: return out
	var t: Dictionary = tunnels[ti]
	for sp: Array in t.spans:
		for e: float in [float(sp[1]),float(sp[2])]:
			if e > s0 and e < s1: out.append(e)
		var kd := int(sp[0])
		if not RIBS.has(kd): continue
		var r: Vector3 = RIBS[kd]
		var k := floori(maxf(s0,float(sp[1]))/r.x)
		while k*r.x < minf(s1,float(sp[2])):
			for e: float in [k*r.x,k*r.x+r.y]:
				if e > s0 and e < s1 and e > float(sp[1]) and e < float(sp[2]): out.append(e)
			k += 1
	for i in refuge_s.size():
		for e: float in [refuge_s[i]-REFUGE_W*0.5,refuge_s[i]+REFUGE_W*0.5]:
			if e > s0 and e < s1: out.append(e)
	var cv: Vector2 = t.cavern
	if cv != Vector2.ZERO:
		var q := cv.x
		while q <= cv.y:
			if q > s0 and q < s1: out.append(q)
			q += 4.0 if (q < cv.x+CAVERN_FLARE or q > cv.y-CAVERN_FLARE) else 1000.0
	out.sort()
	return out

## The refuge on side `side` covering s, or -1.
func refuge_at(s: float, side: float) -> int:
	for i in refuge_s.size():
		if refuge_side[i] == side and absf(s-refuge_s[i]) < REFUGE_W*0.5-0.01: return i
	return -1

## The members whose s range comes within `pad` of s.
func members_near(s: float, pad := 0.0) -> PackedInt32Array:
	var b0 := floori((s-pad)/BUCKET)
	var b1 := floori((s+pad)/BUCKET)
	if b0 == b1:
		var got: Variant = _bucket.get(b0)
		return got if got != null else PackedInt32Array()
	var out := PackedInt32Array()
	for b in range(b0,b1+1):
		var got: Variant = _bucket.get(b)
		if got == null: continue
		for i: int in got:
			if not i in out: out.append(i)
	return out

## The solid stretches (Vector2(y0, y1) over the bed) of the members at
## (s, d), grown `pad` m.
func stretches(s: float, d: float, pad := 0.0) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in members_near(s,pad):
		if s < ms0[i]-pad or s > ms1[i]+pad or d < md0[i]-pad or d > md1[i]+pad: continue
		match mk[i]:
			M_BOX:
				out.append(Vector2(my0[i],my1[i]))
			M_PILE:
				var top := pile_top(i,s,d,pad)
				if top > 0.05: out.append(Vector2(-0.5,top))
			M_ARCADE:
				var under := arch_under(i,s,pad)
				var roof := roof_over(s,maxf(absf(d)-pad,0.0))
				if under <= 0.0: out.append(Vector2(-0.5,roof+2.0))
				elif under < roof: out.append(Vector2(under,roof+2.0))
	return out

## A rock fall's top at (s, d), `pad` m toward its crest (with its stones'
## jitter on top).
func pile_top(i: int, s: float, d: float, pad := 0.0) -> float:
	var c := (ms0[i]+ms1[i])*0.5
	var half := (ms1[i]-ms0[i])*0.5
	var along := smoothstep(0.0,1.0,(half-maxf(absf(s-c)-pad,0.0))/PILE_EASE)
	var inner := md0[i] if absf(md0[i]) < absf(md1[i]) else md1[i]
	var out := absf(d)-absf(inner)+pad
	var across := smoothstep(0.0,1.0,out/PILE_RAMP)
	return my1[i]*along*across+(PILE_JIT if along*across > 0.0 else 0.0)

## Under an arcade's arch at s: the soffit's height, 0 on a pier.
func arch_under(i: int, s: float, pad := 0.0) -> float:
	var u := fposmod(s-ms0[i],ARC_EVERY)
	if s-ms0[i] < ARC_PIER+pad or ms1[i]-s < ARC_PIER+pad: return 0.0
	var open := ARC_EVERY-ARC_PIER
	var x := u-ARC_PIER
	if x < pad or x > open-pad: return 0.0
	var k := (x-open*0.5)/(open*0.5-pad)
	return ARC_SPRING+ARC_RISE*sqrt(maxf(1.0-k*k,0.0))-pad

## The roof over the floor at d off the centre at s (NAN past the walls),
## less a rib.
func roof_over(s: float, d: float) -> float:
	var sc := section(s)
	var ins := inset(s)
	var h := sc.x-ins
	var a := absf(d)
	if a >= h: return NAN
	return sc.y+(sc.z-ins)*sqrt(1.0-(a/h)*(a/h))

## The wall's half width y m over the floor at s, less a rib.
func half_at(s: float, y: float) -> float:
	var sc := section(s)
	var ins := inset(s)
	var h := sc.x-ins
	if y <= sc.y: return h
	var r := sc.z-ins
	if y >= sc.y+r: return 0.0
	var t := (y-sc.y)/r
	return h*sqrt(1.0-t*t)

func note() -> String:
	var parts: Array[String] = []
	for t: Dictionary in tunnels:
		var sp: Array[String] = []
		for x: Array in t.spans: sp.append("%s %.0f-%.0f" % [KIND_NAMES[int(x[0])],float(x[1]),float(x[2])])
		parts.append("[%.0f-%.0f portals %s/%s arcade %s cavern %s: %s]" % [float(t.s0),float(t.s1),PORTAL_NAMES[int(t.portals[0])],PORTAL_NAMES[int(t.portals[1])],str(t.arcade),str(t.cavern),", ".join(sp)])
	return "bore plan: %d members, %d lamps, %d refuges %s" % [mk.size(),lamp_s.size(),refuge_s.size()," ".join(parts)]
