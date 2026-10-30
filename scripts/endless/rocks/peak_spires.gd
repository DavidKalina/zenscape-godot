extends "res://scripts/endless/rocks/rock_kind.gd"
## The Peak's spires (a rock kind, scripts/endless/rocks/rock_plan.gd): a
## granite tower on each of the crest's tower bases (PeakMassif
## `tower_bases`), some with a lesser spire or two beside it, so the crest
## round the horseshoe stands as towers on a knife ridge.
##
## Planned only on the cells that hold a tower base (`cells`); every other
## cell pays one look at the eight bases. A group a base: its main tower on
## the base's flat top, each its own height and girth (MAIN_UP, MAIN_R, in
## turn, so the crest is no row of even teeth), its satellites (SATS, in
## turn) set along the crest or out over the outer face, each gap between
## two rocks' surfaces at their widest an opening (WorldScale.opening from
## TOY_SAT) the plane threads. Between the bases the crest's cols stay open
## (the bases stand about 165 m apart round the ring).
##
## Kept off the couloir's lift tube (PeakRoutes LIFT_R round its path, plus
## an opening) and off the plateau's landing flat (PLATEAU_BLEND round its
## centre): a pillar that would stand in either is left out.
##
## A tower: buried foot, beds stepping in and out up a squared, tapering
## body, a lean, a blunt top. Bare stone (no turf on the top).

const WorldScale = preload("res://scripts/world_scale.gd")
const PeakMassif = preload("res://scripts/endless/peak_massif.gd")
const PeakRoutes = preload("res://scripts/endless/peak_routes.gd")

## Each base's main tower, in turn (+v side from the head out, then -v;
## PeakMassif lists the -v side's bases first, `_turn` maps them):
## its height over the base's top (m) and its radius (m). The top is kept
## under TOP_MOST over the sea, so the head stands over every tower.
const MAIN_UP := [55.0,72.0,40.0,92.0,46.0,82.0,34.0,64.0]
const MAIN_R := [12.0,9.0,15.0,10.0,13.0,8.5,14.0,11.0]
const TOP_MOST := 1135.0
## Each base's satellites, in turn, and which way the first stands: 1 along
## the crest away from the head, -1 toward it, 0 out over the outer face.
const SATS := [1,2,0,1,2,1,0,2]
const SAT_WAY := [1,-1,0,0,1,-1,0,1]
## A satellite's radius, its height over its own ground, and the gap to the
## tower (toy widths: WorldScale.opening).
const SAT_R := Vector2(4.5,7.5)
const SAT_UP := Vector2(26.0,48.0)
const TOY_SAT := Vector2(9.0,14.0)
## The widest a section stands past its radius (tiers) and the weathering's
## push (sea_stacks.gd's rule): gaps are kept between radius x SHAPE_MOST x
## (1 + NOISE) either side.
const SHAPE_MOST := 1.06
const NOISE := 0.3
## The most a section is drawn out one way (its radii r x sqrt(aspect) and
## r / sqrt(aspect)), and the foot's skirt past the radius.
const ASPECT_MOST := 1.45
const SKIRT := 1.1
## A main tower's foot flares out over its base's flat top (PeakMassif
## TOWER_R, past it by FLARE.x m) and narrows to the body over FLARE.y m,
## so the base's top reads as the tower's own foot, not a plinth.
const FLARE := Vector2(2.0,16.0)
## The weathering (rock_build.gd): granite, jointed, beds and rills.
const LUMPS := 0.09
const GRAIN := 0.035
const LEDGES := 0.045
const FLUTES := 0.14
## --rock-start=spires: this far back along the crest from the outermost
## tower of a side, this high over the ground, flying toward the head.
const START_BACK := 450.0
const START_ALT := 60.0

## The cells (RockPlan.CELL) that hold a tower base of `peak`: {Vector2i: true}.
static func cells(peak: RefCounted) -> Dictionary:
	var out := {}
	if peak == null: return out
	var cell: float = preload("res://scripts/endless/rocks/rock_plan.gd").CELL
	for b: Vector3 in peak.tower_bases(): out[Vector2i(floori(b.x/cell),floori(b.z/cell))] = true
	return out

static func plan_cell(field: RefCounted, cx: int, cz: int, _density: float, _rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	if not field.has_method("peak"): return out
	var peak: RefCounted = field.peak()
	if peak == null: return out
	var cell: float = preload("res://scripts/endless/rocks/rock_plan.gd").CELL
	var bases: Array[Vector3] = peak.tower_bases()
	var lift: Array = []
	for k in bases.size():
		var b := bases[k]
		if Vector2i(floori(b.x/cell),floori(b.z/cell)) != Vector2i(cx,cz): continue
		if lift.is_empty(): lift = PeakRoutes.couloir(peak,Callable(field,"height")).points
		var spec := _group(field,peak,k,b,lift)
		if not spec.is_empty(): out.append(spec)
	return out

static func _widest(r: float, flare := 0.0) -> float:
	return maxf(r*maxf(SHAPE_MOST,SKIRT),flare)*sqrt(ASPECT_MOST)*(1.0+NOISE)

## A main tower's flared foot's radius (m).
static func _flare() -> float:
	return PeakMassif.TOWER_R+FLARE.x

## Base `k`'s side (1 the +v side) and its turn in the tables (the +v side's
## from the head out first): PeakMassif lists the -v side's bases first.
static func _side(k: int) -> float:
	return -1.0 if k < PeakMassif.TOWER_NEG.size() else 1.0

static func _turn(k: int) -> int:
	var n := PeakMassif.TOWER_NEG.size()
	return k-n if k >= n else k+PeakMassif.TOWER_POS.size()

## Base `k`'s way along the crest (unit XZ, away from the head) and out over
## its outer face (unit XZ, away from the horseshoe's middle).
static func _ways(peak: RefCounted, k: int) -> Array:
	var s := _side(k)
	var n := PeakMassif.TOWER_NEG.size()
	var th := deg_to_rad(float(PeakMassif.TOWER_POS[k-n] if s > 0.0 else PeakMassif.TOWER_NEG[k]))
	var R := PeakMassif.RING_R
	# Round the ring (a, v) = (O_ALONG - R cos th, s R sin th).
	var along_l := Vector2(R*sin(th),s*R*cos(th)).normalized()
	var out_l := Vector2(-cos(th),s*sin(th))
	var f: Vector2 = peak.facing
	var sd: Vector2 = peak.side
	return [(f*along_l.x+sd*along_l.y).normalized(),(f*out_l.x+sd*out_l.y).normalized()]

## Whether a pillar of widest reach `w` at world XZ `q` keeps off the lift
## tube and the plateau's flat.
static func _clear(peak: RefCounted, q: Vector2, w: float, lift: Array) -> bool:
	if q.distance_to(peak.centre) < PeakMassif.PLATEAU_BLEND+w: return false
	var keep := PeakRoutes.LIFT_R+w+WorldScale.opening(6.0)
	for i in range(lift.size()-1):
		var a: Vector3 = lift[i]
		var b: Vector3 = lift[i+1]
		var p := Geometry2D.get_closest_point_to_segment(q,Vector2(a.x,a.z),Vector2(b.x,b.z))
		if p.distance_to(q) < keep: return false
	return true

## Base `k`'s pillars: [[XZ, radius, top (world y), flare]...], its main
## tower first (when it stands). Its own seed (the land's and the base's),
## so any cell can place any base's: with `cross` the satellites keep off
## the neighbouring bases' pillars (placed without it: a superset of what
## stands there, so either side's keep-off holds).
static func _placed(field: RefCounted, peak: RefCounted, k: int, lift: Array, cross: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),k,"peak spire"])
	var b: Vector3 = peak.tower_bases()[k]
	var ways := _ways(peak,k)
	var along: Vector2 = ways[0]
	var outward: Vector2 = ways[1]
	var c := Vector2(b.x,b.z)
	var i := _turn(k)
	var r := float(MAIN_R[i%MAIN_R.size()])*rng.randf_range(0.92,1.08)
	var top := minf(b.y+float(MAIN_UP[i%MAIN_UP.size()])*rng.randf_range(0.9,1.1),TOP_MOST+PeakMassif.SEA_Y)
	var placed: Array = []
	# Flared when that keeps off the lift and the plateau, else the body alone.
	var flare := _flare()
	if not _clear(peak,c,_widest(r,flare),lift): flare = 0.0
	var wr := _widest(r,flare)
	if _clear(peak,c,wr,lift): placed.append([c,r,top,flare])
	var others: Array = []
	if cross:
		for nb: int in [k-1,k+1]:
			if nb >= 0 and nb < peak.tower_bases().size() and _side(nb) == _side(k): others.append_array(_placed(field,peak,nb,lift,false))
	var n := int(SATS[i%SATS.size()])
	var way := int(SAT_WAY[i%SAT_WAY.size()])
	for j in range(n):
		var sr := rng.randf_range(SAT_R.x,SAT_R.y)
		var w := way if j == 0 else (-way if way != 0 else (1 if rng.randf() < 0.5 else -1))
		var dir := outward if w == 0 else along*float(w)
		# A touch off the line, so a pair does not stand square.
		dir = dir.rotated(rng.randf_range(-0.35,0.35))
		var q := c+dir*(wr+WorldScale.opening(rng.randf_range(TOY_SAT.x,TOY_SAT.y))+_widest(sr))
		var up := rng.randf_range(SAT_UP.x,SAT_UP.y)
		if not _clear(peak,q,_widest(sr),lift): continue
		var ok := true
		for o: Array in placed+others:
			if (o[0] as Vector2).distance_to(q) < _widest(sr)+_widest(float(o[1]),float(o[3]))+WorldScale.opening(TOY_SAT.x): ok = false
		if not ok: continue
		placed.append([q,sr,minf(float(field.height(q.x,q.y))+up,top-12.0),0.0])
	return placed

## Base `k`'s group: its tower and satellites, anchored on the base's top.
static func _group(field: RefCounted, peak: RefCounted, k: int, b: Vector3, lift: Array) -> Dictionary:
	var ways := _ways(peak,k)
	var along: Vector2 = ways[0]
	var c := Vector2(b.x,b.z)
	var pos := Vector3(b.x,b.y,b.z)
	var placed := _placed(field,peak,k,lift,true)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),k,"peak spire shape"])
	if placed.is_empty(): return {}
	var pillars: Array = []
	var reach := 0.0
	for o: Array in placed:
		var q: Vector2 = o[0]
		pillars.append(_tower(field,pos,q,float(o[1]),float(o[2]),float(o[3]),rng))
		reach = maxf(reach,q.distance_to(c)+_widest(float(o[1]),float(o[3]))*1.3)
	# --rock-start: back along the crest from the side's outermost base,
	# flying in toward the head.
	var head: Vector3 = peak.summit()
	var start := c+along*START_BACK
	var to := Vector2(head.x,head.z)-start
	return {"pos":pos,"reach":reach,"pillars":pillars,"foot":[],"by_arches":false,"bare":true,"on_peak":true,
		"approach":{"at":start,"heading":rad_to_deg(atan2(to.x,-to.y)),"alt":START_ALT},"form":"spires","base":k}

## One tower at world XZ `q`, radius `r`, its top at world y `top`, its
## foot flared out to `flare` m (0 none).
static func _tower(field: RefCounted, pos: Vector3, q: Vector2, r: float, top: float, flare: float, rng: RandomNumberGenerator) -> Dictionary:
	# Its foot: the lowest ground under it, buried past that.
	var low := INF
	var high := -INF
	for k in range(9):
		var d := Vector2.ZERO if k == 0 else Vector2.from_angle(TAU*k/8.0)*r*1.3
		var g := float(field.height(q.x+d.x,q.y+d.y))
		low = minf(low,g)
		high = maxf(high,g)
	var ground := float(field.height(q.x,q.y))
	var tall := maxf(top-ground,maxf(high-ground,0.0)+18.0)
	var aspect := rng.randf_range(1.0,ASPECT_MOST)
	var ax := sqrt(aspect)
	var taper := rng.randf_range(0.28,0.45)
	var profile: Array = []
	# A ring `k` x r round (drawn out by the aspect, `round` 0..1 less so).
	var ring := func(y: float, k: float, round := 0.0) -> void:
		if not profile.is_empty() and y < float(profile.back()[0])+0.4: return
		var a := lerpf(ax,1.0,round)
		profile.append([y,r*k*a,r*k/a,0.0,0.0])
	# Buried down the slope under it, a skirt of fallen blocks at the foot.
	var y_foot := low-ground-4.0
	var y := maxf(high-ground,0.0)+1.0
	if flare > r*SKIRT:
		# Out over the base's flat top, then in to the body.
		# Round inside the base's flat top at its edge, so no lip stands out
		# over its fall; wider under the fall.
		ring.call(y_foot,flare*1.08/r,1.0)
		ring.call(0.6,(PeakMassif.TOWER_R-1.0)/r,1.0)
		ring.call(FLARE.y*0.35,lerpf((PeakMassif.TOWER_R-1.0)/r,SKIRT,0.6),0.5)
		ring.call(FLARE.y,SKIRT)
		y = FLARE.y+1.0
	else:
		ring.call(y_foot,1.3)
		ring.call(maxf(high-ground,0.0)-1.0,SKIRT)
	# Beds stepping in and out up the body, narrowing toward the top.
	var tier := 1.06
	while y < tall-6.0:
		var u := y/tall
		ring.call(y,(1.0-taper*u)*tier)
		var step := rng.randf_range(6.0,16.0)
		var next := minf(y+step,tall-6.0)
		ring.call(next-0.8,(1.0-taper*next/tall)*tier)
		tier = rng.randf_range(0.9,SHAPE_MOST)
		y = next
	# A blunt top: the last bed steps in twice.
	var k_top := (1.0-taper)*tier
	ring.call(tall-6.0,k_top)
	ring.call(tall-4.5,k_top*0.82)
	ring.call(tall-1.0,k_top*0.7)
	ring.call(tall,k_top*0.52)
	# A lean, most at the top.
	var lean := Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.02,0.07)*tall
	for c: Array in profile:
		var u := clampf(float(c[0])/tall,0.0,1.0)
		c[3] = lean.x*u*u
		c[4] = lean.y*u*u
	return {"at":Vector3(q.x-pos.x,ground-pos.y,q.y-pos.z),"profile":profile,"yaw":rng.randf()*TAU,"dome":rng.randf_range(0.8,2.5),
		"square":rng.randf_range(0.5,0.68),"lump":clampf(r*0.8,3.5,12.0),"lumps":LUMPS,"grain":GRAIN,"ledges":LEDGES,"flutes":FLUTES,
		"bed":rng.randf_range(6.0,11.0),"ring_every":2.0,"segments":24 if r > 10.0 else 20,"seed":rng.randi()}
