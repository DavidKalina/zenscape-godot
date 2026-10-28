extends RefCounted
## The ruin kit's great road bridge (scripts/ruin_kit.gd: its Build, its
## weathered stone and growth), the second form a land bridge takes
## (scripts/endless/bridge_plan.gd picks per chain between it and the
## aqueduct arcade, scripts/ruin_kit_aqueduct.gd): an old stone road across a
## gorge, rim to rim, read from a kilometre off as one heavy structure.
##
## - `road_bridge`: a wide flat deck (a road WIDTH across) paved in big
##   slabs, a parapet wall along both edges standing on a cornice, worn down
##   and torn open in places; carried on a few massive arches, round or
##   segmental by the drop, on thick tapered piers that step down into the
##   gorge on stepped footings, a cutwater on both faces capped with a sloped
##   hood; a tall drop grows taller piers, never a second tier. A gate over
##   the deck at each end (a great round arch in a wall across the road
##   between two towers) and, on a long whole span, one midway over a pier,
##   so a line flown along the road threads them. Broken: one arch gone from
##   the middle, the deck snapped off both sides over it (paving, parapet
##   and cornice ragged, the haunch fill stepping down to the arch's stub),
##   rubble on the ground under the gap.
## - Overgrown thick (scripts/ruin_growth.gd's strands and curtains, laid as
##   scripts/sundered_growth.gd lays them, through its Probe): curtains from
##   the arch soffits, fringes from under the cornice down the spandrels,
##   ivy down the piers and the gates, mats on the parapets and gate heads,
##   long trails off the snapped ends. Every flown opening keeps a clear
##   core (Build `clear`); thin strands at its edges are parted by the
##   plane, never collided. The growth's leaves are tinted toward a muted
##   olive that sits in the amber palette (`GROWTH_TINT`).
##
## The frame: the run's, as the aqueduct run's (arch_build.gd places it):
## X along the bridge from 0 to `length`, Z across (the deck middle z 0), the
## road's top y 0. `ground` (Callable(x, z) -> y, the run's frame) is the
## land under it. `plan` gives every size and place without building it,
## and `openings` the flown openings from the plan (name, kind, frame, size,
## head, lane: as ruin_kit_gothic.gd's), so a flyability check reads them.
## Openings are sized from toy widths named here through
## WorldScale.opening.

const RuinKit = preload("res://scripts/ruin_kit.gd")
const RuinGrowth = preload("res://scripts/ruin_growth.gd")
const SunderedGrowth = preload("res://scripts/sundered_growth.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Build = RuinKit.Build

## The piece built here (ids stable: break_kinds.gd KIND_OF names it).
const PIECES := ["road_bridge"]

# --- The openings' toy widths (WorldScale.opening: x plane x ratio) ----------

## A gate's arch over the road, and the road's lane flown through the gates:
## toy 5.0 (10 m at the defaults).
const TOY_GATE := 5.0
## The least clear under a big arch, pier face to pier face: toy 14 (28 m).
const TOY_ARCH := 14.0
## The broken gap between the snapped ends, at the deck: toy 10 (20 m).
const TOY_BREAK := 10.0

# --- Sizes (m) -----------------------------------------------------------------

## The deck across (outer faces of the parapets); at least the gate's clear
## plus the parapets and a margin.
const WIDTH := Vector2(12.0,16.0)
## The paving slabs' depth; the parapet's half thickness and height.
const PAVE := 0.55
const PARAPET := Vector2(0.5,1.6)
## The cornice under the parapets: how far proud of the spandrels, deep.
const CORNICE := Vector2(0.85,0.9)
## The spandrels' set-back from the deck's outer face (the rings stand
## proud of them).
const SPANDREL_IN := 0.35
## The ring's backing reaches this far past the voussoirs' backs (m).
const BACKING := 1.6
## Pier middle to pier middle: the span sought from the drop
## (SPAN_BASE + drop x SPAN_DROP), between SPAN.x and SPAN.y.
const SPAN := Vector2(40.0,74.0)
const SPAN_BASE := 30.0
const SPAN_DROP := 0.5
## The pier's width along the bridge at its springing: the span's share,
## between PIER.x and PIER.y; its batter (each side, m a metre down); how
## proud of the deck faces it stands.
const PIER_SHARE := 0.17
const PIER := Vector2(6.0,11.0)
const BATTER := 0.03
const PIER_PROUD := 0.3
## The cutwater: how far it reaches out off the pier's face (its share of
## the pier's width), and how far up the pier it climbs (share of the pier).
const CUTWATER := 0.6
const CUTWATER_UP := 0.72
## The arch ring's depth (share of the clear, clamped).
const RING_SHARE := 0.06
const RING := Vector2(1.7,3.2)
## Over the crown: spandrel fill between the ring and the paving.
const CROWN_FILL := 1.0
## The arches' rise: the drop's share, held between a flat segment's and a
## half round's.
const RISE_SHARE := 0.5
const RISE_LEAST := 0.25
## How deep a footing sinks under the ground, and its steps.
const FOOT := 3.0
const STEPS := 3
const STEP_OUT := 1.1
## Courses: the piers', the spandrels', the gates'.
const PIER_COURSE := 4.0
const SPANDREL_COURSE := 3.6
const GATE_COURSE := 2.8
## A gate: its thickness along the road, how far its wall reaches past the
## deck's sides, its springing over the road, its ring, its wall's top over
## the road, its towers' (across, along: half sizes) and their top.
const GATE_T := 6.0
const GATE_OUT := 1.4
const GATE_SPRING := 10.0
const GATE_RING := 1.5
const GATE_TOP := 23.0
const TOWER := Vector2(2.2,4.2)
const TOWER_TOP := 29.0
## Where the end gates stand: back from the rim's edge onto the rim (m).
const GATE_BACK := 9.0
## The run past each rim's edge (m): the approach the end gate stands on.
const APPROACH := 26.0
## Onto a rim higher than the deck the road climbs outside the end gates, at
## most RAMP (m up a metre along), its top RAMP_CLEAR over the land under it
## across the deck; where the land climbs faster the road ends in it (a
## cutting), built no further. The profile is sampled every ROAD_STEP.
const RAMP := 0.2
const RAMP_CLEAR := 0.4
const ROAD_STEP := 1.0
const COARSE_STEP := 4.0
## A whole span this long (rim edge to edge) with at least MID_ARCHES
## arches gets a gate midway, over its middle pier.
const MID_GAP := 200.0
const MID_ARCHES := 3
## A broken bridge: the deck stub's reach out over the lost arch from each
## pier face (m), and how steeply the haunch fill's torn face falls (m down a
## metre out).
const STUB := Vector2(2.0,6.0)
const TORN_FALL := 1.3
## The broken gap's flown box: from under the deck to over it.
const GAP_Y := Vector2(-2.0,10.0)
## An under-arch lane: from this over the floor to this share of the rise
## over the springing; shorter than LANE_LEAST, not a flown opening.
const LANE_FLOOR := 4.0
const LANE_TOP := 0.6
const LANE_LEAST := 12.0
## The growth's leaves pulled this far toward `GROWTH_TINT` (sRGB): a muted
## olive for the amber land.
const GROWTH_TINT := Color("5a5a33")
const GROWTH_PULL := 0.45
## The bridge's own strands this much coarser than SunderedGrowth's.
const COARSE_GROWTH := 2.4
## The kit's own growth (ivy, fringes, cushions on the open tops) as a share
## of a ruin's.
const KIT_GROWTH := 0.4
## The kit takes the ground as y 0 where a piece gives none (its faces under
## it culled, native and GDScript alike), and a terrain would cost the
## native finish: so the bridge is built LIFT up (every block through
## `Stone.solid`, every strand's start through `_up`) and its Mesh and Body
## set back down.
const LIFT := 600.0

# --- Plan ------------------------------------------------------------------------

## Everything about a bridge but its stones. `length`: the run (x 0 to it);
## `gap`: rim edge to rim edge (middled in the run); `drop`: the deck over
## the floor's lowest; `broken`; `ground` as the file's head.
## `coarse`: the land under the road read every COARSE_STEP along and a
## quarter of the deck across, each metre taking the higher of the reads
## either side (a placer's quick look; the build reads it all).
static func plan(seed_value: int, weathered: float, length: float, gap: float, drop: float, broken: bool, ground: Callable = Callable(), coarse := false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"road bridge plan"])
	var gate_w := WorldScale.opening(TOY_GATE)
	var width := maxf(rng.randf_range(WIDTH.x,WIDTH.y),gate_w+PARAPET.x*4.0+1.6)
	var xa := (length-gap)*0.5
	var xb := xa+gap
	var want := clampf(SPAN_BASE+drop*SPAN_DROP,SPAN.x,SPAN.y)
	# An odd count, so an arch (not a pier) stands over the gorge's middle.
	var n := maxi(1,2*int(round((gap/want-1.0)*0.5))+1)
	var least := WorldScale.opening(TOY_ARCH)
	var pw := 0.0
	var span := 0.0
	while true:
		span = gap/n
		pw = clampf(span*PIER_SHARE,PIER.x,PIER.y)
		if span-pw >= least or n == 1: break
		n = maxi(1,n-2)
	var clear := span-pw
	var ring := clampf(clear*RING_SHARE,RING.x,RING.y)
	var deck_depth := PAVE+ring+CROWN_FILL
	var rise := clampf((drop-deck_depth)*RISE_SHARE,clear*RISE_LEAST,clear*0.5)
	var spring := -(deck_depth+rise)
	var radius := (clear*clear*0.25+rise*rise)/(2.0*rise)
	var p := {"seed":seed_value,"weathered":weathered,"length":length,"gap":gap,"drop":drop,"broken":broken,
		"width":width,"half":width*0.5,"xa":xa,"xb":xb,"n":n,"span":span,"pier_w":pw,"clear":clear,
		"ring":ring,"deck_depth":deck_depth,"rise":rise,"spring":spring,"radius":radius,
		"centre_y":spring+rise-radius,"gate_w":gate_w,"cutwater":pw*CUTWATER}
	# The piers: where they stand, their feet.
	var piers: Array = []
	var zh := width*0.5+PIER_PROUD
	for i in range(n+1):
		var x := xa+span*i
		var lo := INF
		var hi := -INF
		var reach := pw*0.5+BATTER*maxf(drop,10.0)+STEP_OUT*STEPS
		for sx: float in [-1.0,0.0,1.0]:
			for sz: float in [-1.0,-0.5,0.0,0.5,1.0]:
				var g := _ground(ground,x+sx*reach,sz*(zh+pw*CUTWATER))
				lo = minf(lo,g)
				hi = maxf(hi,g)
		piers.append({"x":x,"low":lo,"high":hi,"stands":hi+1.5 < spring-2.0})
	p["piers"] = piers
	# The lost arch of a broken bridge: the middle one; the stubs.
	var lost := -1
	if broken:
		lost = n/2 if n > 1 else 0
		if n > 1 and n%2 == 0 and rng.randf() < 0.5: lost = n/2-1
		var room := clear-WorldScale.opening(TOY_BREAK)-2.0*(PAVE-GAP_Y.x)/TORN_FALL-1.2
		var most := clampf(room*0.5,0.5,STUB.y)
		p["stub_a"] = rng.randf_range(minf(STUB.x,most),most)
		p["stub_b"] = rng.randf_range(minf(STUB.x,most),most)
	p["lost"] = lost
	# The land under the road, across the deck (its highest, plus the clear).
	var count := int(ceil(length/ROAD_STEP))+1
	var raw := PackedFloat32Array()
	raw.resize(count)
	var every := int(COARSE_STEP/ROAD_STEP) if coarse else 1
	var reads := PackedFloat32Array()
	reads.resize(int(ceil(float(count)/every))+1)
	for k in range(reads.size()):
		var hi := -1.0e4
		if ground.is_valid():
			var z := -width*0.5
			while z <= width*0.5+0.01:
				hi = maxf(hi,_ground(ground,minf(k*every*ROAD_STEP,length),z))
				z += width/(4.0 if coarse else 8.0)
		reads[k] = hi+RAMP_CLEAR
	for i in range(count):
		var k := i/every
		raw[i] = reads[k] if i%every == 0 else maxf(reads[k],reads[mini(k+1,reads.size()-1)])
	# The gates: one each end on the rim, one midway on a long whole span.
	var cap := maxf(pw*0.5-GATE_T*0.5,0.0)
	# An end gate the rim's land would bury moves out over the first pier
	# (never past the lost arch, nor the other end's).
	var most_a := (lost if lost >= 0 else n/2)
	var most_b := (n-1-lost if lost >= 0 else (n-1)/2)
	var ga := _gate_x(raw,xa,1.0,cap,span,mini(1,most_a))
	var gb := _gate_x(raw,xb,-1.0,cap,span,mini(1,most_b))
	# One the land would bury wherever it stood is left out: the road's flat
	# then starts where the land first stands under it.
	var gates: Array = []
	if not ga.has("buried"): gates.append(ga.merged({"name":"gate_a","end":true}))
	var mid := xa+span*(n/2)
	if not broken and gap >= MID_GAP and n >= MID_ARCHES and mid-float(ga.x) > span*0.6 and float(gb.x)-mid > span*0.6:
		gates.append({"name":"gate_mid","x":mid,"end":false,"pier":n/2})
	if not gb.has("buried"): gates.append(gb.merged({"name":"gate_b","end":true}))
	var fa := float(ga.x)-GATE_T*0.5-1.0 if not ga.has("buried") else _clear_from(raw,float(ga.x),1.0,xb)
	var fb := float(gb.x)+GATE_T*0.5+1.0 if not gb.has("buried") else _clear_from(raw,float(gb.x),-1.0,xa)
	p["lane"] = Vector2(float(ga.x) if not ga.has("buried") else fa+1.0,float(gb.x) if not gb.has("buried") else fb-1.0)
	_road_profile(p,raw,fa,fb)
	for g: Dictionary in gates:
		var lo := INF
		for sx: float in [-1.0,1.0]:
			for sz: float in [-1.0,0.0,1.0]:
				lo = minf(lo,_ground(ground,float(g.x)+sx*(GATE_T*0.5+1.0),sz*(width*0.5+GATE_OUT+TOWER.x*2.0)))
		g["low"] = lo
	p["gates"] = gates
	return p

## An end gate's x: GATE_BACK onto the rim from its edge `edge`, or nearer
## the gorge (`way` +1 the gorge's side) until the land (`raw`, the road
## profile's) under its road and a metre each side stands under the road;
## at most `cap` past the edge (over the abutment's pier, never an arch).
## Failing that, over the first `piers` piers out from the edge (the first
## whose road clears; the last if none): {x, pier (if over one)}.
static func _gate_x(raw: PackedFloat32Array, edge: float, way: float, cap: float, span: float, piers: int) -> Dictionary:
	var x := edge-way*GATE_BACK
	while true:
		if _gate_clear(raw,x): return {"x":x}
		if way*(x-edge) >= cap-0.01: break
		x = edge+way*minf(way*(x-edge)+1.0,cap)
	for k in range(1,piers+1):
		var got := {"x":edge+way*span*k,"pier":k}
		if _gate_clear(raw,float(got.x)): return got
	return {"x":x,"buried":true}

## The first x from `x` along `way` (short of `stop`) where the land under
## the road stands under it.
static func _clear_from(raw: PackedFloat32Array, x: float, way: float, stop: float) -> float:
	while way*(stop-x) > 0.0:
		var i := clampi(int(round(x/ROAD_STEP)),0,raw.size()-1)
		if raw[i] <= 0.0: return x
		x += way*ROAD_STEP
	return x

## The land under a gate at x and a metre each side stands under the road.
static func _gate_clear(raw: PackedFloat32Array, x: float) -> bool:
	var a := int(floor((x-GATE_T*0.5-1.0)/ROAD_STEP))
	var b := int(ceil((x+GATE_T*0.5+1.0)/ROAD_STEP))
	for i in range(maxi(a,0),mini(b,raw.size()-1)+1):
		if raw[i] > 0.0: return false
	return true

## The road's profile (p.road_y, p.cut_a, p.cut_b) from the land under it:
## flat (0) from fa to fb (the end gates and a metre past them); outside,
## the least climb that keeps its top over `raw` (the one-sided upper
## envelope at RAMP, held to RAMP from the flat), never under 0; where the
## land still stands over it the road is cut (cut_a, cut_b: its built ends).
static func _road_profile(p: Dictionary, raw: PackedFloat32Array, fa: float, fb: float) -> void:
	var count := raw.size()
	var ys := PackedFloat32Array()
	ys.resize(count)
	var env := PackedFloat32Array()
	env.resize(count)
	# Side a: the envelope from x 0 inward.
	var e := -1.0e4
	for i in range(count):
		e = maxf(raw[i],e-RAMP*ROAD_STEP)
		env[i] = e
	for i in range(count):
		var x := i*ROAD_STEP
		if x < fa: ys[i] = maxf(0.0,minf(env[i],RAMP*(fa-x)))
	# Side b: from the far end back.
	e = -1.0e4
	for i in range(count-1,-1,-1):
		e = maxf(raw[i],e-RAMP*ROAD_STEP)
		var x := i*ROAD_STEP
		if x > fb: ys[i] = maxf(0.0,minf(e,RAMP*(x-fb)))
	var cut_a := 0.0
	var i := int(floor(fa/ROAD_STEP))
	while i >= 0:
		if ys[i] < raw[i]-RAMP_CLEAR:
			cut_a = (i+1)*ROAD_STEP
			break
		i -= 1
	var cut_b := float(p.length)
	i = int(ceil(fb/ROAD_STEP))
	while i < count:
		if ys[i] < raw[i]-RAMP_CLEAR:
			cut_b = (i-1)*ROAD_STEP
			break
		i += 1
	p["road_y"] = ys
	p["raw"] = raw
	p["cut_a"] = minf(cut_a,fa)
	p["cut_b"] = maxf(cut_b,fb)

## The most the land stands over the built road's top (m; under 0: clear
## all along). A placer leaves out a bridge the land breaks through.
static func through(p: Dictionary) -> float:
	var raw: PackedFloat32Array = p.raw
	var ys: PackedFloat32Array = p.road_y
	var most := -INF
	for i in range(int(ceil(float(p.cut_a)/ROAD_STEP)),mini(int(floor(float(p.cut_b)/ROAD_STEP)),raw.size()-1)+1):
		most = maxf(most,raw[i]-RAMP_CLEAR-ys[i])
	return most

## The road's top at x (the run's frame): 0 between the end gates, climbing
## onto a rim higher than the deck (the plan's `road_y`, every ROAD_STEP).
static func road_y(p: Dictionary, x: float) -> float:
	var ys: PackedFloat32Array = p.get("road_y",PackedFloat32Array())
	if ys.is_empty(): return 0.0
	var f := clampf(x/ROAD_STEP,0.0,ys.size()-1.0)
	var i := mini(int(f),ys.size()-2)
	return lerpf(ys[i],ys[i+1],f-i)

static func _ground(ground: Callable, x: float, z: float) -> float:
	return float(ground.call(x,z)) if ground.is_valid() else -1.0e4

## The arch's soffit at x (inside arch i's clear), and its half clear at y.
static func soffit(p: Dictionary, i: int, x: float) -> float:
	var mid := float(p.xa)+float(p.span)*(i+0.5)
	var r := float(p.radius)
	var dx := clampf(x-mid,-r,r)
	return float(p.centre_y)+sqrt(r*r-dx*dx)

static func half_clear(p: Dictionary, y: float) -> float:
	var spring := float(p.spring)
	if y <= spring: return float(p.clear)*0.5-BATTER*(spring-y)
	var r := float(p.radius)
	var dy := y-float(p.centre_y)
	if dy >= r: return 0.0
	return sqrt(r*r-dy*dy)

# --- Openings ------------------------------------------------------------------

## The flown openings, from `plan` (the run's frame): {name, kind, frame
## (its middle; +Z the way flown), size (across, up, along the way: the
## rectangle flown, under any head), head (a round head's rise over it),
## knife, round, lane (a lane flown its length, not a hole passed)}.
## Kinds: "arch" (under a big arch, across the bridge), "gate" (a gate's
## arch, along the road), "deck" (the road's lane through the gates),
## "gap" (a broken bridge's gap, across).
static func openings(p: Dictionary) -> Array:
	var out: Array = []
	var half := float(p.half)
	var gw := float(p.gate_w)
	var cw := float(p.cutwater)
	var lost := int(p.lost)
	for i in range(int(p.n)):
		if i == lost: continue
		var mid := float(p.xa)+float(p.span)*(i+0.5)
		var lane := _arch_lane(p,i)
		if lane == Vector3.ZERO: continue
		out.append(_opening("arch_%d" % i,"arch",Vector3(mid,(lane.x+lane.y)*0.5,0.0),Vector3.BACK,Vector3(lane.z,lane.y-lane.x,(half+PIER_PROUD+cw)*2.0+2.0)))
	var gates: Array = p.gates
	for g: Dictionary in gates:
		out.append(_opening(str(g.name),"gate",Vector3(float(g.x),(1.0+GATE_SPRING)*0.5,0.0),Vector3.RIGHT,Vector3(gw,GATE_SPRING-1.0,GATE_T),gw*0.5,true))
	var y := (1.0+GATE_SPRING)*0.5
	var lane_x: Vector2 = p.lane
	var x0 := lane_x.x
	var x1 := lane_x.y
	if lost < 0:
		out.append(_opening("deck","deck",Vector3((x0+x1)*0.5,y,0.0),Vector3.RIGHT,Vector3(gw,GATE_SPRING-1.0,x1-x0),0.0,false,true))
	else:
		var ends := gap_ends(p)
		out.append(_opening("deck_a","deck",Vector3((x0+ends.x)*0.5,y,0.0),Vector3.RIGHT,Vector3(gw,GATE_SPRING-1.0,ends.x-x0),0.0,false,true))
		out.append(_opening("deck_b","deck",Vector3((ends.y+x1)*0.5,y,0.0),Vector3.RIGHT,Vector3(gw,GATE_SPRING-1.0,x1-ends.y),0.0,false,true))
		var w := ends.y-ends.x-2.0*(PAVE-GAP_Y.x)/TORN_FALL-1.2
		out.append(_opening("gap","gap",Vector3((ends.x+ends.y)*0.5,(GAP_Y.x+GAP_Y.y)*0.5,0.0),Vector3.BACK,Vector3(w,GAP_Y.y-GAP_Y.x,(half+2.0)*2.0)))
	return out

static func _opening(name: String, kind: String, centre: Vector3, way: Vector3, size: Vector3, head := 0.0, round := false, lane := false) -> Dictionary:
	var z := way.normalized()
	var x := Vector3.UP.cross(z).normalized()
	return {"name":name,"kind":kind,"frame":Transform3D(Basis(x,Vector3.UP,z),centre),"size":size,"head":head,"knife":false,"round":round,"lane":lane}

## The snapped deck ends of a broken bridge (x of each stub's tip).
static func gap_ends(p: Dictionary) -> Vector2:
	var lost := int(p.lost)
	var face_a := float(p.xa)+float(p.span)*lost+float(p.pier_w)*0.5
	var face_b := float(p.xa)+float(p.span)*(lost+1)-float(p.pier_w)*0.5
	return Vector2(face_a+float(p.stub_a),face_b-float(p.stub_b))

## Arch i's flown lane: Vector3(floor y, top y, width), or zero if the
## ground stands too high under it.
static func _arch_lane(p: Dictionary, i: int) -> Vector3:
	var piers: Array = p.piers
	var a: Dictionary = piers[i]
	var b: Dictionary = piers[i+1]
	var floors: Dictionary = p.get("floors",{})
	var floor_y := float(floors.get(i,maxf(float(a.low),float(b.low))))
	var lo := floor_y+LANE_FLOOR
	var hi := float(p.spring)+float(p.rise)*LANE_TOP
	if hi-lo < LANE_LEAST: return Vector3.ZERO
	# The narrowest: at the top under the arch, or low between the battered
	# piers or over a footing.
	var w := minf(half_clear(p,hi),half_clear(p,lo))*2.0
	var step_top := maxf(float(a.high),float(b.high))+1.5
	if lo < step_top: w = minf(w,float(p.clear)-2.0*(BATTER*(float(p.spring)-lo)+STEP_OUT*STEPS))
	return Vector3(lo,hi,w-1.0)

## The ground's height under each arch's middle (its highest), for `_arch_lane`.
static func _floors(p: Dictionary, ground: Callable) -> void:
	var floors := {}
	for i in range(int(p.n)):
		var mid := float(p.xa)+float(p.span)*(i+0.5)
		var hi := -INF
		for sx: float in [-0.35,-0.15,0.0,0.15,0.35]:
			for sz: float in [-1.0,0.0,1.0]:
				hi = maxf(hi,_ground(ground,mid+sx*float(p.clear),sz*(float(p.half)+4.0)))
		floors[i] = hi
	p["floors"] = floors

## The plan with its arches' floors read (what `piece` and a check use).
static func full_plan(seed_value: int, weathered: float, length: float, gap: float, drop: float, broken: bool, ground: Callable) -> Dictionary:
	var p := plan(seed_value,weathered,length,gap,drop,broken,ground)
	_floors(p,ground)
	return p

# --- Build -----------------------------------------------------------------------

## The bridge's stone: the kit's Build, its growth's leaves tinted.
class Stone extends Build:
	## Blocks raised LIFT while the stone is laid (off for the growth's leaves,
	## whose places are raised already).
	var lifting := true
	func solid(planes: Array[Plane], pose: Transform3D, colour: Color, collide := true, wear := true, extra: Array[Plane] = [], open := -1, rough := 1.0, growable := true) -> PackedVector3Array:
		if lifting: pose = Transform3D(pose.basis,pose.origin+Vector3(0.0,LIFT,0.0))
		return super.solid(planes,pose,colour,collide,wear,extra,open,rough,growable)

	func growth_face(corners: PackedVector3Array, normal: Vector3, colour: Color) -> void:
		var tint := GROWTH_TINT.srgb_to_linear()
		var c := colour.lerp(tint,GROWTH_PULL)
		c.a = colour.a
		super.growth_face(corners,normal,c)

## A probe over the bridge's blocks (SunderedGrowth's grid) whose floor is
## the land's, so strands under the deck reach down to the gorge.
class Probe extends SunderedGrowth.Probe:
	var land := Callable()
	func floor_at(x: float, z: float) -> float:
		return (float(land.call(x,z)) if land.is_valid() else -500.0)+LIFT

## The whole bridge: a Node3D in the run's frame, "Mesh" and "Body" (each
## block's hull), meta "openings", "bounds", "road" (the plan).
static func piece(seed_value: int, weathered: float, length: float, gap: float, drop: float, broken: bool, ground: Callable) -> Node3D:
	var p := full_plan(seed_value,weathered,length,gap,drop,broken,ground)
	var b := Stone.new(seed_value,weathered,"RoadBridge")
	b.lean = true
	b.cull = true
	b.settle = 0.35
	# The kit's own ivy, fringes and cushions thinner than a ruin's: the
	# bridge's own strands carry its growth.
	b.level *= KIT_GROWTH
	var ctx := {"tops":[]}
	var n := int(p.n)
	var lost := int(p.lost)
	var piers: Array = p.piers
	# The piers.
	for i in range(n+1):
		var pr: Dictionary = piers[i]
		if bool(pr.stands): _pier(b,p,pr)
	# The arches and the spandrels over them.
	for i in range(n):
		_arch(b,p,i,i == lost)
	# The approaches: solid fill from the ground to the deck past each rim.
	_approach(b,p,float(p.cut_a),float(p.xa),ground)
	_approach(b,p,float(p.xb),float(p.cut_b),ground)
	# The deck: paving, cornice, parapets, broken where the lost arch was.
	var gates: Array = p.gates
	var spans := _deck_spans(p)
	for s: Vector2 in spans:
		_paving(b,p,s.x,s.y)
		for side: float in [-1.0,1.0]:
			_cornice(b,p,s.x,s.y,side)
	for side: float in [-1.0,1.0]:
		for s: Vector2 in _parapet_runs(p,spans):
			_parapet(b,p,s.x,s.y,side,ctx)
	for g: Dictionary in gates:
		_gate(b,p,g,ctx)
	if lost >= 0: _rubble(b,p,ground)
	# The flown cores, kept clear of growth.
	for o: Dictionary in openings(p):
		var f: Transform3D = o.frame
		var size: Vector3 = o.size
		var core := Vector3(maxf(size.x-3.0,0.5),maxf(size.y-2.0,0.5),size.z+4.0)*0.5
		var box := AABB(f*(-core),Vector3.ZERO)
		for k in range(8):
			box = box.expand(f*Vector3(core.x*(1 if k&1 else -1),core.y*(1 if k&2 else -1),core.z*(1 if k&4 else -1)))
		b.clear.append(AABB(box.position+Vector3(0.0,LIFT,0.0),box.size))
	b.lifting = false
	_growth(b,p,ground,ctx)
	var node := b.finish()
	for child in node.get_children():
		if child is Node3D: (child as Node3D).position.y -= LIFT
	node.set_meta("road",p)
	node.set_meta("openings",openings(p))
	var mesh := node.get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		var box := mesh.get_aabb()
		node.set_meta("bounds",AABB(box.position-Vector3(0.0,LIFT,0.0),box.size))
	return node

## A place in the run's frame raised to the stone's (LIFT up).
static func _up(v: Vector3) -> Vector3:
	return v+Vector3(0.0,LIFT,0.0)

## A pose on the deck (y 0 the road's top) set onto the road's profile:
## raised to it and tipped to its climb.
static func _on_road(p: Dictionary, pose: Transform3D) -> Transform3D:
	var x := pose.origin.x
	var y := road_y(p,x)
	if y <= 0.0 and road_y(p,x-2.0) <= 0.0 and road_y(p,x+2.0) <= 0.0: return pose
	var slope := (road_y(p,x+1.0)-road_y(p,x-1.0))*0.5
	return Transform3D(Basis(Vector3.BACK,atan(slope))*pose.basis,pose.origin+Vector3(0.0,y,0.0))

## The deck's standing stretches (x0, x1): the whole run, or the two halves
## either side of a broken bridge's gap.
static func _deck_spans(p: Dictionary) -> Array:
	var a := float(p.get("cut_a",0.0))
	var z := float(p.get("cut_b",float(p.length)))
	if int(p.lost) < 0: return [Vector2(a,z)]
	var e := gap_ends(p)
	return [Vector2(a,e.x),Vector2(e.y,z)]

## A pier: stepped footing, coursed tapered body, a cutwater each face.
static func _pier(b: Build, p: Dictionary, pr: Dictionary) -> void:
	var x := float(pr.x)
	var spring := float(p.spring)
	var bottom := float(pr.low)-FOOT
	var foot_top := minf(float(pr.high)+1.5,spring-2.0)
	var hw := float(p.pier_w)*0.5
	var zh := float(p.half)+PIER_PROUD
	var cw := float(p.cutwater)
	var cut_top := lerpf(foot_top,spring,CUTWATER_UP)
	# The footing: STEPS slabs, each in from the last.
	var sh := (foot_top-bottom)/STEPS
	for k in range(STEPS):
		var out := STEP_OUT*(STEPS-k)
		var ya := bottom+sh*k
		var bx := hw+BATTER*(spring-ya)+out
		var bz := zh+cw*0.7+out
		for part in range(3):
			var z0 := -bz+bz*2.0*part/3.0
			var z1 := -bz+bz*2.0*(part+1)/3.0
			var half := Vector3(bx,sh*0.5-0.02,(z1-z0)*0.5-0.02)
			b.solid(RuinKit._box(b,half),RuinKit._settle(b,Vector3(x,ya+sh*0.5,(z0+z1)*0.5),0.1),RuinKit._stone(b,0.9))
	# The body: courses, battered.
	var y := foot_top
	var k := 0
	while y < spring-0.05:
		var h := minf(PIER_COURSE*b.rng.randf_range(0.85,1.15),spring-y)
		if spring-(y+h) < 1.0: h = spring-y
		var bx := hw+BATTER*(spring-(y+h*0.5))
		var shift := 0.8 if k%2 == 0 else -0.8
		var splits := [-zh,-zh/3.0+shift,zh/3.0+shift,zh]
		var xs := [-bx,bx] if bx < 3.2 else [-bx,b.rng.randf_range(-0.8,0.8)+shift*0.75,bx]
		for xi in range(xs.size()-1):
			for zi in range(3):
				var x0: float = xs[xi]
				var x1: float = xs[xi+1]
				var z0: float = splits[zi]
				var z1: float = splits[zi+1]
				var half := Vector3((x1-x0)*0.5-0.02,h*0.5-0.02,(z1-z0)*0.5-0.02)
				b.solid(RuinKit._box(b,half),RuinKit._settle(b,Vector3(x+(x0+x1)*0.5,y+h*0.5,(z0+z1)*0.5),0.12),RuinKit._stone(b,0.95+0.05*(k%2)))
		# The cutwaters, each face, in the same course.
		if y < cut_top-0.3:
			var yb := minf(y+h,cut_top)
			for s: float in [-1.0,1.0]:
				var pts := PackedVector3Array()
				for yy: float in [y+0.02,yb-0.02]:
					pts.append(Vector3(x-bx,yy,s*(zh-0.4)))
					pts.append(Vector3(x+bx,yy,s*(zh-0.4)))
					pts.append(Vector3(x,yy,s*(zh+cw*(bx/hw))))
				b.solid(RuinKit._planes_round(pts),RuinKit._jiggle(b,Transform3D.IDENTITY,0.1),RuinKit._stone(b,0.98))
		y += h
		k += 1
	# The cutwaters' hoods: a sloped cap off the face.
	var cx := hw+BATTER*(spring-cut_top)
	for s: float in [-1.0,1.0]:
		var pts := PackedVector3Array()
		pts.append(Vector3(x-cx,cut_top,s*(zh-0.4)))
		pts.append(Vector3(x+cx,cut_top,s*(zh-0.4)))
		pts.append(Vector3(x,cut_top,s*(zh+cw*(cx/hw))))
		pts.append(Vector3(x-cx*0.9,cut_top+cw*0.9,s*(zh-0.4)))
		pts.append(Vector3(x+cx*0.9,cut_top+cw*0.9,s*(zh-0.4)))
		b.solid(RuinKit._planes_round(pts),Transform3D.IDENTITY,RuinKit._stone(b,1.04))

## Arch i: its ring of voussoirs (a barrel the deck's width) and the
## spandrel fill over it to the paving; `lost`: fallen but for the stubs
## at its haunches, the fill's torn face stepping down to them.
static func _arch(b: Build, p: Dictionary, i: int, lost: bool) -> void:
	var span := float(p.span)
	var x0 := float(p.xa)+span*i
	var x1 := x0+span
	var mid := (x0+x1)*0.5
	var r := float(p.radius)
	var t := float(p.ring)
	var yc := float(p.centre_y)
	var spring := float(p.spring)
	var half := float(p.half)
	var clear := float(p.clear)
	var face_a := x0+float(p.pier_w)*0.5
	var face_b := x1-float(p.pier_w)*0.5
	var top := func(x: float) -> float: return road_y(p,x)-PAVE
	if lost:
		var stub_a := float(p.stub_a)
		var stub_b := float(p.stub_b)
		var noise := b.rng.randf()*TAU
		top = func(x: float) -> float:
			var da := x-(face_a+stub_a)
			var db := (face_b-stub_b)-x
			if da <= 0.0 or db <= 0.0: return -PAVE
			return -PAVE-minf(da,db)*TORN_FALL-0.5-0.5*sin(x*1.7+noise)
	var ro := r+t
	# The fill's hole a little inside the ring's back, so the coursed fill
	# laps onto the ring (no wedge of sky between them).
	var rh := ro-0.35
	var hole := func(y: float) -> Vector2:
		var dy := y-yc
		if dy >= rh: return Vector2(mid,-1.0)
		return Vector2(mid,sqrt(rh*rh-dy*dy))
	RuinKit._courses(b,Transform3D.IDENTITY,x0,x1,spring,top,half-SPANDREL_IN,hole,SPANDREL_COURSE)
	# The ring: from the right springing (theta s) round to the left.
	var ts := atan2(spring-yc,clear*0.5)
	var arc := (PI-2.0*ts)*(r+t*0.5)
	var count := maxi(9,int(arc/2.4))
	var foot_x := sqrt(maxf(ro*ro-(spring-yc)*(spring-yc),0.0))
	for j in range(count):
		var a0 := ts+(PI-2.0*ts)*j/count
		var a1 := ts+(PI-2.0*ts)*(j+1)/count
		if lost:
			# Kept while the fill over it stands (or nearly).
			var am := (a0+a1)*0.5
			var ox := mid+cos(am)*ro
			var oy := yc+sin(am)*ro
			if oy > float(top.call(ox))+t*0.6: continue
		var pts := PackedVector3Array()
		for z: float in [-half+0.02,half-0.02]:
			for a: float in [a0,a1]:
				pts.append(Vector3(mid+cos(a)*r,yc+sin(a)*r,z))
				pts.append(Vector3(mid+cos(a)*ro,yc+sin(a)*ro,z))
			if j == 0: pts.append(Vector3(mid+foot_x,spring,z))
			if j == count-1: pts.append(Vector3(mid-foot_x,spring,z))
		b.solid(RuinKit._planes_round(pts),RuinKit._jiggle(b,Transform3D.IDENTITY,0.03),RuinKit._stone(b,1.0+b.rng.randf_range(-0.03,0.03)))
	# The backing: a ring of rough stone behind the voussoirs' backs, at the
	# fill's face, from a little inside the ring's back to BACKING past it
	# (under the road): the coursed fill's straight cuts never leave a dark
	# notch between the ring and the spandrel over it.
	var backs := maxi(5,count/2)
	var fill := half-SPANDREL_IN-0.05
	for j in range(backs):
		var a0 := ts+(PI-2.0*ts)*j/backs
		var a1 := ts+(PI-2.0*ts)*(j+1)/backs
		var pts := PackedVector3Array()
		var ok := true
		for a: float in [a0,(a0+a1)*0.5,a1]:
			var c := Vector2(cos(a),sin(a))
			var inner := Vector3(mid+c.x*(ro-0.4),yc+c.y*(ro-0.4),0.0)
			if inner.y > float(top.call(inner.x))-0.1:
				ok = false
				break
			# The outer edge held under the road (or the torn fill's face).
			var out := ro+BACKING
			for k in range(6):
				var q := Vector2(mid+c.x*out,yc+c.y*out)
				if q.y <= float(top.call(q.x))-0.1: break
				out = lerpf(ro-0.3,out,0.6)
			for z: float in [-fill,fill]:
				pts.append(Vector3(inner.x,inner.y,z))
				pts.append(Vector3(mid+c.x*out,yc+c.y*out,z))
		if not ok: continue
		b.solid(RuinKit._planes_round(pts),Transform3D.IDENTITY,RuinKit._stone(b,0.97),true,true,[],-1,1.0,false)

## An approach: the deck's fill on the rim from x0 to x1, down to the ground.
static func _approach(b: Build, p: Dictionary, x0: float, x1: float, ground: Callable) -> void:
	if x1-x0 < 0.5: return
	var lo := INF
	var x := x0
	while x <= x1+0.01:
		for z: float in [-float(p.half),0.0,float(p.half)]: lo = minf(lo,_ground(ground,x,z))
		x += 4.0
	var y0 := maxf(lo-1.5,float(p.spring))
	if y0 > maxf(road_y(p,x0),road_y(p,x1))-PAVE-0.3: return
	var top := func(x: float) -> float: return road_y(p,x)-PAVE
	RuinKit._courses(b,Transform3D.IDENTITY,x0,x1,y0,top,float(p.half)-SPANDREL_IN,Callable(),SPANDREL_COURSE)

## The paving from x0 to x1: slabs in rows across the road, some sunk or
## lost; a ragged end over a broken gap.
static func _paving(b: Build, p: Dictionary, x0: float, x1: float) -> void:
	var half := float(p.half)-PARAPET.x*2.0
	var rows := 3
	var w := float(p.weathered)
	var ragged_a := x0 > float(p.xa)
	var ragged_b := x1 < float(p.xb)
	for row in range(rows):
		var z0 := -half+half*2.0*row/rows
		var z1 := -half+half*2.0*(row+1)/rows
		var xa := x0+(b.rng.randf_range(0.0,2.5) if ragged_a else 0.0)
		var xb := x1-(b.rng.randf_range(0.0,2.5) if ragged_b else 0.0)
		var x := xa+(b.rng.randf_range(0.0,1.5) if row%2 == 1 else 0.0)
		while x < xb-0.3:
			var l := minf(b.rng.randf_range(2.6,4.4),xb-x)
			if xb-(x+l) < 0.8: l = xb-x
			if b.rng.randf() > 0.06+0.12*w:
				var sink := b.rng.randf_range(0.0,0.12)*w
				var half_v := Vector3(l*0.5-0.03,PAVE*0.5,(z1-z0)*0.5-0.03)
				# The road grows no moss of the kit's (its mats are laid on
				# the parapets instead): the deck's whole top would double
				# the growth.
				b.solid(RuinKit._box(b,half_v),_on_road(p,RuinKit._settle(b,Vector3(x+l*0.5,-PAVE*0.5-sink,(z0+z1)*0.5),0.06)),RuinKit._stone(b,1.06),true,true,[],-1,1.0,false)
			x += l

## The cornice under one side's parapet, from x0 to x1 (lost in places).
static func _cornice(b: Build, p: Dictionary, x0: float, x1: float, side: float) -> void:
	var zo := float(p.half)-SPANDREL_IN+CORNICE.x
	var zi := float(p.half)-PARAPET.x*2.0
	var x := x0+(b.rng.randf_range(0.0,2.0) if x0 > float(p.xa) else 0.0)
	var end := x1-(b.rng.randf_range(0.0,2.0) if x1 < float(p.xb) else 0.0)
	while x < end-0.3:
		var l := minf(b.rng.randf_range(3.0,4.6),end-x)
		if b.rng.randf() > 0.08*float(p.weathered):
			var half_v := Vector3(l*0.5-0.03,CORNICE.y*0.5,(zo-zi)*0.5)
			b.solid(RuinKit._box(b,half_v),_on_road(p,RuinKit._settle(b,Vector3(x+l*0.5,-PAVE-CORNICE.y*0.5,side*(zo+zi)*0.5),0.08)),RuinKit._stone(b,1.08))
		x += l

## The parapet's runs: the deck's stretches less the gates' feet.
static func _parapet_runs(p: Dictionary, spans: Array) -> Array:
	var cuts: Array = []
	for g: Dictionary in p.gates:
		cuts.append(Vector2(float(g.x)-GATE_T*0.5,float(g.x)+GATE_T*0.5))
	var out: Array = []
	for s: Vector2 in spans:
		var pieces: Array = [s]
		for c: Vector2 in cuts:
			var next: Array = []
			for q: Vector2 in pieces:
				if c.y <= q.x or c.x >= q.y:
					next.append(q)
					continue
				if c.x > q.x+0.5: next.append(Vector2(q.x,c.x))
				if c.y < q.y-0.5: next.append(Vector2(c.y,q.y))
			pieces = next
		out.append_array(pieces)
	return out

## One side's parapet from x0 to x1: two courses, its head ragged, a breach
## now and then.
static func _parapet(b: Build, p: Dictionary, x0: float, x1: float, side: float, ctx: Dictionary) -> void:
	var w := float(p.weathered)
	var z := side*(float(p.half)-PARAPET.x)
	var pose := Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,z))
	var ragged_a := x0 > float(p.xa) and not _at_gate(p,x0)
	var ragged_b := x1 < float(p.xb) and not _at_gate(p,x1)
	var a := x0+(b.rng.randf_range(0.5,4.0) if ragged_a else 0.0)
	var e := x1-(b.rng.randf_range(0.5,4.0) if ragged_b else 0.0)
	var x := a
	while x < e-1.0:
		var run := minf(b.rng.randf_range(18.0,46.0),e-x)
		if e-(x+run) < 4.0: run = e-x
		var line: Callable = RuinKit._ruin_line(b,x,x+run,PARAPET.y*lerpf(0.75,0.35,w),PARAPET.y,w*0.6)
		var top := func(t: float) -> float: return float(line.call(t))+road_y(p,t)
		RuinKit._courses(b,pose,x,x+run,-PAVE,top,PARAPET.x-0.02,Callable(),(PARAPET.y+PAVE)*0.5)
		var m := x+run*b.rng.randf_range(0.2,0.8)
		(ctx.tops as Array).append(Vector3(m,float(top.call(m)),z))
		x += run
		# A breach.
		if b.rng.randf() < 0.25+0.4*w: x += b.rng.randf_range(2.5,7.0)

static func _at_gate(p: Dictionary, x: float) -> bool:
	for g: Dictionary in p.gates:
		if absf(absf(x-float(g.x))-GATE_T*0.5) < 0.6: return true
	return false

## A gate over the road at g.x: a wall across the deck with a great round
## arch, a tower each side; an end gate stands from the rim's ground.
static func _gate(b: Build, p: Dictionary, g: Dictionary, ctx: Dictionary) -> void:
	var x := float(g.x)
	var half := float(p.half)
	var gz := half+GATE_OUT
	var gw := float(p.gate_w)
	var r := gw*0.5
	var deck := float(p.deck_depth)
	var y0 := -deck-2.0
	if bool(g.end) and not g.has("pier"): y0 = clampf(float(g.low)-1.5,float(p.spring),-deck)
	var w := float(p.weathered)
	# The wall: its X along the bridge's -Z, its thickness along X.
	var pose := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(x,0.0,0.0))
	var ro := r+GATE_RING
	var hole := func(y: float) -> Vector2:
		if y < -PAVE-0.05: return Vector2(0.0,-1.0)
		if y < GATE_SPRING: return Vector2(0.0,r)
		var dy := y-GATE_SPRING
		if dy >= ro: return Vector2(0.0,-1.0)
		return Vector2(0.0,sqrt(ro*ro-dy*dy))
	var top: Callable = RuinKit._ruin_line(b,-gz,gz,lerpf(GATE_TOP,GATE_SPRING+ro+2.5,w*0.7),GATE_TOP,w*0.5)
	RuinKit._courses(b,pose,-gz,gz,y0,top,GATE_T*0.5,hole,GATE_COURSE)
	# The ring: a round head, two orders (the outer proud).
	var n := 15
	for order in range(2):
		var r0 := r+GATE_RING*0.5*order
		var r1 := r0+GATE_RING*0.5
		var d := GATE_T*0.5+(0.3 if order == 1 else 0.05)
		for j in range(n):
			var a0 := PI*j/n
			var a1 := PI*(j+1)/n
			var pts := PackedVector3Array()
			for zz: float in [-d,d]:
				for a: float in [a0,a1]:
					pts.append(Vector3(cos(a)*r0,GATE_SPRING+sin(a)*r0,zz))
					pts.append(Vector3(cos(a)*r1,GATE_SPRING+sin(a)*r1,zz))
			b.solid(RuinKit._planes_round(pts),pose*RuinKit._jiggle(b,Transform3D.IDENTITY,0.06),RuinKit._stone(b,1.05 if order == 0 else 1.0))
	(ctx.tops as Array).append(Vector3(x,float(top.call(0.0)),0.0))
	# The towers, each side past the wall's ends.
	for s: float in [-1.0,1.0]:
		var tz := s*(gz+TOWER.x-0.3)
		var tpose := Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,tz))
		var ttop: Callable = RuinKit._ruin_line(b,x-TOWER.y,x+TOWER.y,lerpf(TOWER_TOP,GATE_TOP+1.0,w),TOWER_TOP,w*0.7)
		RuinKit._courses(b,tpose,x-TOWER.y,x+TOWER.y,y0,ttop,TOWER.x,Callable(),GATE_COURSE*1.1)
		(ctx.tops as Array).append(Vector3(x+TOWER.y*0.5,float(ttop.call(x+TOWER.y*0.5)),tz))

## The fallen arch's stones on the ground under the gap.
static func _rubble(b: Build, p: Dictionary, ground: Callable) -> void:
	var e := gap_ends(p)
	var mid := (e.x+e.y)*0.5
	var reach := (e.y-e.x)*0.5+6.0
	var count := int((16+20*float(p.weathered))*(0.5+0.5*b.level))
	for i in range(count):
		var s := Vector3(b.rng.randf_range(0.9,2.6),b.rng.randf_range(0.6,1.5),b.rng.randf_range(0.9,3.4))
		var at := Vector3(mid+b.rng.randf_range(-1.0,1.0)*reach,0.0,b.rng.randf_range(-1.0,1.0)*(float(p.half)+6.0))
		at.y = _ground(ground,at.x,at.z)+s.y*0.4
		var pose := Transform3D(Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.5,0.5))*Basis(Vector3.BACK,b.rng.randf_range(-0.4,0.4)),at)
		b.solid(RuinKit._box(b,s),pose,RuinKit._stone(b,0.92),true,true,[],-1,2.0)

# --- Growth ----------------------------------------------------------------------

## Laid on thick (SunderedGrowth.amount scales it, --overgrowth=): see the
## file's head.
static func _growth(b: Build, p: Dictionary, ground: Callable, ctx: Dictionary) -> void:
	var d := SunderedGrowth.amount
	var probe := Probe.new(b)
	probe.land = ground
	probe.label = "road bridge"
	# The kit's own moss and ivy grow from tops in the open only: a course's
	# top under the next one's stone is let go (what grew there was buried).
	var open_tops: Array = []
	for t: Array in b.tops:
		var poly: PackedVector3Array = t[0]
		var c := Vector3.ZERO
		for q: Vector3 in poly: c += q
		c /= poly.size()
		if not probe._inside(c+Vector3(0.0,0.3,0.0)): open_tops.append(t)
	b.tops = open_tops
	if d <= 0.0: return
	var keep_rng := b.rng
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(p.seed),"road bridge growth"])
	b.rng = rng
	probe.rng = rng
	var w := float(p.weathered)
	var half := float(p.half)
	var lost := int(p.lost)
	var piers: Array = p.piers
	var span := float(p.span)
	var spring := float(p.spring)
	# The bridge's own strands coarser than the kit's (fewer, bigger leaves:
	# a bridge is seen from tens of metres off).
	var coarse := SunderedGrowth.COARSE_OUT*COARSE_GROWTH
	# Curtains under the arch soffits, rows across the barrel.
	probe.label = "curtains"
	for i in range(int(p.n)):
		var x0 := float(p.xa)+span*i+float(p.pier_w)*0.5
		var x1 := x0+float(p.clear)
		var x := x0+rng.randf_range(1.0,4.0)
		while x < x1-1.0:
			for z: float in [-half*0.6,half*0.6]:
				if rng.randf() > 0.5*d: continue
				var at := Vector3(x,0.0,z+rng.randf_range(-1.5,1.5))
				var from := soffit(p,i,at.x)
				if from > -PAVE-0.5: continue
				at.y = from-0.3
				var hang := from-maxf(_ground(ground,at.x,at.z),-1.0e3)
				RuinGrowth.curtain(probe,_up(at),minf(rng.randf_range(3.0,8.0)*(0.6+w),hang*0.4),from+LIFT,6,14.0,false,COARSE_GROWTH)
			x += rng.randf_range(8.0,13.0)/maxf(d,0.3)
	# Fringes from under the cornice down the spandrels.
	probe.label = "fringes"
	for side: float in [-1.0,1.0]:
		var zf := side*(half-SPANDREL_IN+0.1)
		for s: Vector2 in _deck_spans(p):
			var x := s.x+rng.randf_range(2.0,8.0)
			while x < s.y-2.0:
				var count := rng.randi_range(4,6)
				var longest := rng.randf_range(4.0,16.0)*(0.6+w)
				for j in range(count):
					var fx := x+(j-count*0.5)*0.5
					var start := _up(Vector3(fx,road_y(p,fx)-PAVE-CORNICE.y-0.08,zf))
					for nudge in range(10):
						if not probe._inside(start): break
						start.z += side*0.12
					if probe._inside(start): continue
					var l := longest*(0.45+0.55*sin(PI*(j+0.5)/count))*rng.randf_range(0.75,1.1)
					RuinGrowth.strand(probe,start,l,Vector3(0.0,0.0,side),false,coarse,true)
				x += rng.randf_range(18.0,34.0)/maxf(d,0.3)
	# Ivy down the piers: into the arches, and down their faces under the
	probe.label = "piers"
	# cornice.
	for pr: Dictionary in piers:
		if not bool(pr.stands): continue
		var px := float(pr.x)
		var tall := spring-float(pr.high)
		for s: float in [-1.0,1.0]:
			var face := float(p.pier_w)*0.5+BATTER*2.0+0.15
			for j in range(int(rng.randi_range(2,3)*d)):
				var start := _up(Vector3(px+s*face,spring-rng.randf_range(0.5,4.0),rng.randf_range(-half,half)))
				if probe._inside(start): continue
				RuinGrowth.strand(probe,start,minf(rng.randf_range(0.3,0.75)*tall,24.0),Vector3(s,0.0,0.0),false,coarse*1.3,true)
		for s: float in [-1.0,1.0]:
			for j in range(int(rng.randi_range(2,3)*d)):
				var start := _up(Vector3(px+rng.randf_range(-1.0,1.0)*float(p.pier_w)*0.4,-PAVE-CORNICE.y-0.1,s*(half+PIER_PROUD+0.12)))
				if probe._inside(start): continue
				RuinGrowth.strand(probe,start,minf(rng.randf_range(0.3,0.75)*(tall-spring),28.0),Vector3(0.0,0.0,s),false,coarse*1.3,true)
	# Mats on the parapets' and gates' heads.
	probe.label = "mats"
	for t: Vector3 in ctx.tops:
		SunderedGrowth._mat(probe,_up(t+Vector3(0.0,0.01,0.0)),Vector3.UP,rng.randi_range(3,6),1.2)
	# The gates: ivy down their faces and towers.
	probe.label = "gates"
	for g: Dictionary in p.gates:
		var gx := float(g.x)
		for s: float in [-1.0,1.0]:
			for j in range(int(rng.randi_range(3,6)*d)):
				var start := _up(Vector3(gx+s*(GATE_T*0.5+0.35),rng.randf_range(GATE_SPRING,GATE_TOP-2.0),rng.randf_range(-1.0,1.0)*(half+GATE_OUT+TOWER.x*1.5)))
				if probe._inside(start) or b.kept_clear(start): continue
				RuinGrowth.strand(probe,start,rng.randf_range(4.0,14.0),Vector3(s,0.0,0.0),false,coarse,true)
	# Long trails off the snapped ends.
	probe.label = "trails"
	if lost >= 0:
		var e := gap_ends(p)
		for end: Array in [[e.x,1.0],[e.y,-1.0]]:
			var ex: float = end[0]
			var out: float = end[1]
			var z := -half+rng.randf_range(0.3,1.5)
			while z < half:
				var count := rng.randi_range(2,5)
				var longest := rng.randf_range(10.0,22.0)
				for j in range(count):
					var zz := z+(j-count*0.5)*0.4
					# The lip: the outermost stone a little under the deck.
					var lip := -INF
					var t := -4.0
					while t < 6.0:
						if probe._inside(_up(Vector3(ex+out*t,-PAVE-0.6,zz))): lip = t
						t += 0.2
					if lip == -INF: continue
					var start := _up(Vector3(ex+out*(lip+0.2),-PAVE-0.3,zz))
					if probe._inside(start): continue
					RuinGrowth.strand(probe,start,longest*(0.45+0.55*sin(PI*(j+0.5)/count))*rng.randf_range(0.75,1.1),Vector3(out,0.0,0.0),false,coarse,true)
				z += rng.randf_range(1.8,3.6)/maxf(d,0.3)
	b.rng = keep_rng
	b.grow = PackedFloat32Array()
