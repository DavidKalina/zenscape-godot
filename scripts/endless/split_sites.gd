extends RefCounted
## Split mountains (docs/design/endless-flight/split-mountain-handoff.md): a
## narrow slot canyon cut through a range from foot to foot, rock walls
## standing close on both sides, its floor flown in at one end and out at
## the other. A layer over the land field, as the ponds and the slot halls'
## cuts are: LandField (land_field.gd) cuts the slot in after the native or
## GDScript field has worked, so both fields read the same slots and
## nothing native changes.
##
## At most one per CELL m square, from the seed and the square alone. A
## square rolls (CHANCE times the density), then scans its middle for a
## range's crest (`mountain` at least CREST_MIN) and tries the best spots,
## as hall_sites.gd does: up onto the crest, the crest's way read off a
## ring, the crest checked straight either side, then the range walked
## across to its feet (each at least TALL_MIN m under the crest). The slot
## runs foot to foot (LENGTH m), its path bending gently (an S of BEND_MOST
## m at most, no tighter than TURN_MIN m), its floor falling from the higher
## foot to the lower at GRADE_MOST at the most. The whole cut stays inside
## the square, so a point asks only its own square.
##
## Kept: no river's water within RIVER_OFF m of its floor or mouths, no pond
## by it, the sea off it, and a flat to land on (FLAT_RUN m of land within
## FLAT_RISE m) within FLAT_REACH m out of each mouth (AGENTS.md, meadows).
##
## The cut: the floor is WorldScale.opening(TOY_SLOT) wide at its narrowest;
## each wall stands back from it by its own flutes (ROUGH, a groove and a
## buttress in turn, so the rock reads carved) and the slot swells wider in
## places (WIDEN). From the floor each wall rises in two sheer tiers with a
## bench between (TIER, BENCH, TIER_UP), then leans back at LEAN (run over
## rise) to the land, so the cut reads as a deep notch in the ridgeline from
## afar. Toward each mouth the slot flares open (FLARE*). Past each end the
## floor climbs at GRADE till it meets the land; the cut's edges ease back
## into the land (EASE).
##
## A site is a PackedFloat32Array laid out as hall_sites.gd's where they
## share (tunnel_sites.gd `blocks_hall`, tree_plan.gd's keep-outs read
## [0], [1], [2], [3], [7], [8]): [centre x, centre z, way x, way z (unit,
## along the slot), half length (foot to foot), the floor's half width at
## its narrowest, the floor's height at the middle, reach (half length of
## the whole cut), the cut's half width round its centre line (its widest
## plus the bend), the bend (m, the S's swing), the floor's slope along the
## way (rise per m), the cut's half width off the path (its top), the
## flutes' salt, the crest's height].
##
## In a world of regions (the field a LandBlend) a split stands only where
## its whole cut, and SITE_CLEAR m round it, lies in one region that grows
## splits (LandBlend `site_ok`, the profile's `splits` layer): wilderness.
##
## Each is named `<world>/split/<cx>_<cz>` and placed through
## scripts/layout_overrides.gd: a move in the layout file moves the cut (its
## yaw and place; the floor's middle at the frame's origin), a deletion
## drops it.

const SEA_Y := -40.0
const WorldScale = preload("res://scripts/world_scale.gd")
const Ponds = preload("res://scripts/endless/land_ponds.gd")
const Sites = preload("res://scripts/endless/hall_sites.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The square (m) and how far in from its edges the scan looks (m).
const CELL := 1536.0
const MARGIN := 300.0
## How often: the share of squares that roll a split (times the density,
## the world's `splits` layer or --splits=X, up to CHANCE_MOST). Of the
## squares that roll, only those with a range's crest fit for a slot get
## one: at 0.9 the wilderness of seeds 1 to 4 has one every 4.6 to 9.6 km²
## (docs/design/endless-flight/split-mountain-handoff.md).
const CHANCE := 0.9
const CHANCE_MOST := 0.97
## The scan of a square's middle (spots a side) and the best spots tried.
const SCAN := 9
const TRIES := 12
## The crest: its `mountain` at the least, the ring its way is read off
## (m), how far either side it is looked for (m), how far along it is
## checked straight (m) and how far off the line its middle may stand (m).
const CREST_MIN := 0.5
const RING := 30.0
const SNAP := 70.0
const ALONG := 60.0
const STRAIGHT := 40.0
## The walk out to the feet: step (m), how far (m), the flank's slope
## (rise over run, over FOOT_RUN m) the foot eases under; the crest at least
## TALL_MIN m over each foot, and a foot taken wherever the flank stands
## FOOT_DEEP m under the crest (the slot then opens high on the flank); the
## slot's length foot to foot (m).
const WALK := 4.0
const WALK_MOST := 520.0
const FOOT_SLOPE := 0.14
const FOOT_RUN := 16.0
const TALL_MIN := 75.0
const FOOT_DEEP := 110.0
const LENGTH := Vector2(180.0,860.0)
## The floor's toy-era width at its narrowest (WorldScale.opening: 18 m at
## the knobs, 7.6 m past each wingtip; --split-slot=X another toy width),
## its slope along the slot at the most (rise over run), how far under the
## lower foot it is sunk (m).
const TOY_SLOT := 9.0
static var HALF: float = WorldScale.opening(_toy_slot())*0.5
const GRADE_MOST := 0.07
const SINK := 0.3

static func _toy_slot() -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--split-slot="): return maxf(0.0,float(a.get_slice("=",1)))
	return TOY_SLOT

## The walls: their flutes (each wall's own setback from the floor's edge,
## m: Vector2(scale along the slot, depth)), two sizes; the swell (the
## floor wider in places, up to WIDEN of its half width each side, over
## WIDEN_SCALE m along).
const ROUGH := [Vector2(22.0,4.5),Vector2(7.0,1.8)]
const WIDEN := 0.2
const WIDEN_SCALE := 140.0
## Each wall stands in two sheer tiers with a bench between, each its own
## along the slot: the lower tier's rise (m, least..most, wandering over
## TIER_SCALE m), the bench (m across, least..most; it climbs BENCH_RISE
## over its width), the upper tier's rise; a tier rises within EDGE m
## across. Over the upper tier the wall leans back at LEAN (run over rise)
## to the land.
const TIER := Vector2(18.0,36.0)
const TIER_SCALE := 70.0
const BENCH := Vector2(1.5,6.0)
const BENCH_RISE := 0.3
const TIER_UP := Vector2(14.0,30.0)
const EDGE := 2.5
const LEAN := 0.24
## The mouths: over the last FLARE m of each end (FLARE_SHARE of the half
## length at the most) the slot opens out, its floor up to 1+FLARE_WIDEN
## times as wide, its tiers down to FLARE_LOW of their rise, softened to
## FLARE_SOFT times their width across (slopes, not steps, where the land
## is low) and its lean out to FLARE_LEAN, so the range opens round the
## way in rather than a trench ending in a wall.
const FLARE := 80.0
const FLARE_SHARE := 0.35
const FLARE_WIDEN := 0.8
const FLARE_LOW := 0.2
const FLARE_SOFT := 8.0
const FLARE_LEAN := 1.1
## The cut eases back into the land over its last EASE m across and along,
## so no seam stands where its walls would not reach over the land.
const EASE := 12.0
## Past the ends the floor climbs at GRADE to meet the land, RAMP_MOST m at
## the most.
const GRADE := 0.25
const RAMP_MOST := 120.0
## The bend: the S's swing at the most (m) and its tightest turn (m).
const BEND_MOST := 30.0
const TURN_MIN := 220.0
## The cut's half width off the path at the most (m), and how far over the
## land round it the top of the walls is kept (m).
const WIDE_MOST := 230.0
const TOP_OVER := 6.0
## Water: a river's water kept this far from the floor and the mouths (m).
const RIVER_OFF := 40.0
## The way on out of each mouth: OPEN m along it (and rays OPEN_FAN rad
## either side) under the mouth's floor plus OPEN_RISE m and OPEN_CLIMB
## (rise over run) of the way.
const OPEN := 400.0
const OPEN_FAN := 0.2
const OPEN_RISE := 12.0
const OPEN_CLIMB := 0.15
## A flat within FLAT_REACH m out of each mouth: FLAT_RUN m of dry land
## within FLAT_RISE m, read every FLAT_STEP m along FLAT_FAN rays.
const FLAT_REACH := 1100.0
const FLAT_RUN := 160.0
const FLAT_RISE := 4.0
const FLAT_STEP := 16.0
const FLAT_FAN := [-0.7,-0.35,0.0,0.35,0.7]
## --split-near-start: the start this far out of the lower mouth, on the
## slot's way in, ALT m over the land; the squares searched round the start.
const START_BACK := 520.0
const START_ALT := 28.0
const START_RINGS := 5

static var _cache := {}
static var _lock := Mutex.new()

## The splits' density: the world's `splits` layer (0: none), then
## `--splits=X` or `--no-splits`.
static func wanted(default := 0.0) -> float:
	var out := default
	for a: String in LaunchArgs.user_args():
		if a == "--no-splits": out = 0.0
		elif a.begins_with("--splits="): out = maxf(0.0,float(a.get_slice("=",1)))
	return out

## Whether `--split-near-start` asks for the start at a split's mouth.
static func near_start_wanted() -> bool:
	return "--split-near-start" in LaunchArgs.user_args()

static func _hash01(seed: int, i: int, j: int, salt: int) -> float:
	return float(hash([seed,i,j,salt,7717]) & 0xffffff)/16777216.0

## The square key holding (x, z).
static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/CELL),floori(z/CELL))

## The site of square `key`, or an empty array. `impl` is the field doing
## the work (its last sample is overwritten when the square is first looked
## at, read at full detail); `local` is the asking LandField's own cache;
## `ponds` the field's pond density.
static func cell_site(impl: Object, seed: int, density: float, ponds: float, key: Vector2i, local: Dictionary) -> PackedFloat32Array:
	var got: Variant = local.get(key)
	if got != null: return got
	var k4 := Vector4i(key.x,key.y,seed,int(density*1000.0))
	_lock.lock()
	got = _cache.get(k4)
	_lock.unlock()
	if got == null:
		var was: float = impl.detail
		impl.detail = 0.0
		got = _make(impl,seed,density,ponds,key.x,key.y)
		impl.detail = was
		_lock.lock()
		if _cache.has(k4): got = _cache[k4]
		else: _cache[k4] = got
		_lock.unlock()
	local[key] = got
	return got

## (x, z) in site `s`'s frame: Vector2(along the slot from its middle, across).
static func local(s: PackedFloat32Array, x: float, z: float) -> Vector2:
	var dx := x-s[0]
	var dz := z-s[1]
	return Vector2(dx*s[2]+dz*s[3],-dx*s[3]+dz*s[2])

## The path's centre line across at `u` along (clamped to the slot's ends)
## and its slope there: Vector2(offset, d offset / d u).
static func path(s: PackedFloat32Array, u: float) -> Vector2:
	var hl := s[4]
	if absf(u) >= hl: return Vector2.ZERO
	var k := PI/hl
	return Vector2(s[9]*sin(u*k),s[9]*k*cos(u*k))

## The floor's height at `u` along (world y), the climb past the ends in.
static func floor_at(s: PackedFloat32Array, u: float) -> float:
	var hl := s[4]
	var y := s[6]+clampf(u,-hl,hl)*s[10]
	var past := absf(u)-hl
	if past > 0.0: y += past*GRADE
	return y

## The world point on the floor's centre line at `u` along.
static func point(s: PackedFloat32Array, u: float) -> Vector3:
	var c := path(s,u).x
	var way := Vector2(s[2],s[3])
	var p := Vector2(s[0],s[1])+way*u+Vector2(-way.y,way.x)*c
	return Vector3(p.x,floor_at(s,u),p.y)

## True where (x, z) is on the cut, or within `margin` m of it (and
## `along` m more past its ends: the way in and out).
static func on_cut(s: PackedFloat32Array, x: float, z: float, margin := 0.0, along := 0.0) -> bool:
	var q := local(s,x,z)
	if absf(q.x) > s[7]+margin+along or absf(q.y) > s[8]+margin: return false
	var c := path(s,q.x)
	return absf(q.y-c.x)/sqrt(1.0+c.y*c.y) <= s[11]+margin

## The trees' keep-outs for site `s` (tree_plan.gd `_arches_near`'s
## [centre, cos, sin, half across, half along]): the cut in stretches of at
## most KEEP_STRETCH m (a keep-out is read within 400 m of its centre), each
## its whole width, its ends' way in and out kept by the trees' approach.
const KEEP_STRETCH := 240.0
const LANE := 140.0
static func tree_keepouts(s: PackedFloat32Array) -> Array:
	var out: Array = []
	var turned := atan2(-s[3],s[2])+PI*0.5
	var n := maxi(1,ceili(s[7]*2.0/KEEP_STRETCH))
	var half := s[7]/n
	var way := Vector2(s[2],s[3])
	for k in n:
		var u := -s[7]+half*(2*k+1)
		out.append([Vector2(s[0],s[1])+way*u,cos(turned),sin(turned),s[8],half])
	# A lane on through the woods out of each mouth, LANE m on, as wide as
	# the mouth.
	for end: float in [-1.0,1.0]:
		out.append([Vector2(s[0],s[1])+way*end*(s[7]+LANE*0.5),cos(turned),sin(turned),s[5]*(1.0+FLARE_WIDEN)+10.0,LANE*0.5])
	return out

# --- The cut --------------------------------------------------------------------------

static func _r(i: int, salt: int) -> float:
	var h := (i*374761393+salt*668265263) & 0xffffffff
	h = ((h ^ (h >> 13))*1274126177) & 0xffffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff)/65535.0

## Value noise along a line (0..1), smooth between whole `t`.
static func _vn(t: float, salt: int) -> float:
	var i := floori(t)
	var f := t-i
	f = f*f*(3.0-2.0*f)
	return lerpf(_r(i,salt),_r(i+1,salt),f)

## The most a wall stands back from the floor's narrowest edge (m).
static func setback_most() -> float:
	var out := HALF*WIDEN
	for r: Vector2 in ROUGH: out += r.y
	return out

## How far into a mouth's flare `u` along lies (0 inside, 1 at the mouth
## and past it).
static func _flare(s: PackedFloat32Array, u: float) -> float:
	var reach := minf(FLARE,s[4]*FLARE_SHARE)
	return smoothstep(s[4]-reach,s[4],absf(u))

## The floor's half width at `u` along before the walls' own setbacks: the
## narrowest, the mouths' flare in.
static func _half(s: PackedFloat32Array, u: float) -> float:
	return s[5]*(1.0+FLARE_WIDEN*_flare(s,u))

## Wall `side` (0 or 1)'s setback from the floor's edge at `u` along:
## Vector2(m, the flutes' share of their most, 0..1).
static func _back(s: PackedFloat32Array, u: float, side: int) -> Vector2:
	var salt := int(s[12])
	var flute := 0.0
	var most := 0.0
	for k in ROUGH.size():
		var r: Vector2 = ROUGH[k]
		flute += r.y*_vn(u/r.x,salt+side*17+k*5)
		most += r.y
	return Vector2(flute+s[5]*WIDEN*_vn(u/WIDEN_SCALE,salt+3),flute/most)

## Wall `side`'s height over the floor `e` m past the floor's edge (its
## setback in) at `u` along: the lower tier, the bench, the upper tier, the
## lean; the mouths' flare in.
static func _rise(s: PackedFloat32Array, u: float, side: int, e: float) -> float:
	if e <= 0.0: return 0.0
	var salt := int(s[12])+side*31
	var f := _flare(s,u)
	var low := lerpf(1.0,FLARE_LOW,f)
	var edge := EDGE*lerpf(1.0,FLARE_SOFT,f)
	var t1 := lerpf(TIER.x,TIER.y,_vn(u/TIER_SCALE,salt+7))*low
	if e <= edge: return t1*e/edge
	e -= edge
	var b := lerpf(BENCH.x,BENCH.y,_vn(u/(TIER_SCALE*0.6),salt+9))
	if e <= b: return t1+e*BENCH_RISE
	e -= b
	var y := t1+b*BENCH_RISE
	var t2 := lerpf(TIER_UP.x,TIER_UP.y,_vn(u/TIER_SCALE,salt+13))*low
	if e <= edge: return y+t2*e/edge
	return y+t2+(e-edge)/lerpf(LEAN,FLARE_LEAN,f)

## Vector3(the land's height `base` with site `s`'s slot cut in at (x, z),
## the groove 0..1, the buttress 0..1 (the carve's marks for the rock), or
## a negative groove where the cut leaves the land be; a negative buttress
## on the floor).
static func cut(s: PackedFloat32Array, base: float, x: float, z: float) -> Vector3:
	var q := local(s,x,z)
	var au := absf(q.x)
	if au > s[7] or absf(q.y) > s[8]: return Vector3(base,-1.0,0.0)
	var c := path(s,q.x)
	var off := q.y-c.x
	var d := absf(off)/sqrt(1.0+c.y*c.y)
	if d > s[11]: return Vector3(base,-1.0,0.0)
	var lid := floor_at(s,q.x)
	if base <= lid: return Vector3(base,-1.0,0.0)
	var side := 1 if off > 0.0 else 0
	var back := _back(s,q.x,side)
	var e := d-_half(s,q.x)-back.x
	var y := lid+_rise(s,q.x,side,e)
	# Eased back into the land at the cut's edge and its ends.
	var t := maxf(smoothstep(s[11]-EASE,s[11],d),smoothstep(s[7]-EASE,s[7],au))
	y = lerpf(y,base,t)
	if y >= base-0.0005: return Vector3(base,-1.0,0.0)
	if e <= 0.0: return Vector3(y,0.0,-1.0)
	return Vector3(y,smoothstep(0.45,0.9,back.y),smoothstep(0.55,0.1,back.y))

## The land's height `base` with site `s`'s slot cut in at (x, z).
static func carve(s: PackedFloat32Array, base: float, x: float, z: float) -> float:
	return cut(s,base,x,z).x

# --- Finding a site ------------------------------------------------------------------

static func _h(impl: Object, x: float, z: float) -> float:
	return (impl.sample(x,z) as Vector2).x

static func _make(impl: Object, seed: int, density: float, ponds: float, ci: int, cj: int) -> PackedFloat32Array:
	var none := PackedFloat32Array()
	if density <= 0.0: return none
	if _hash01(seed,ci,cj,1) >= minf(CHANCE*density,CHANCE_MOST): return none
	var x0 := ci*CELL+MARGIN
	var z0 := cj*CELL+MARGIN
	var span := CELL-MARGIN*2.0
	var spots: Array = []
	var gated := impl.has_method("site_ok")
	for gj in SCAN:
		for gi in SCAN:
			var x := x0+(gi+0.5)/SCAN*span
			var z := z0+(gj+0.5)/SCAN*span
			if gated and not impl.site_spot(&"splits",x,z): continue
			impl.sample(x,z)
			var m: float = impl.last_mountain
			if m >= CREST_MIN: spots.append([m,x,z])
	if spots.is_empty(): return none
	spots.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for t in mini(TRIES,spots.size()):
		var got := _fit(impl,seed,ponds,ci,cj,float(spots[t][1]),float(spots[t][2]))
		if not got.is_empty(): return got
	return none

## The crest nearest `p` across way `d`: the highest point along it.
static func _snap(impl: Object, p: Vector2, d: Vector2, reach: float, step: float) -> Vector2:
	var best := p
	var top := -INF
	var t := -reach
	while t <= reach:
		var q := p+d*t
		var h := _h(impl,q.x,q.y)
		if h > top:
			top = h
			best = q
		t += step
	return best

## Walks from `c` (the crest, `top` high) along `d` to the range's foot,
## where the flank eases (or, FOOT_DEEP m under the crest, wherever it is:
## the slot then opens high on the flank): Vector3(distance, height there,
## 1 if fit, 0 by a river's water or on the sea, -1 none within WALK_MOST).
static func _foot(impl: Object, c: Vector2, d: Vector2, top: float) -> Vector3:
	var back := int(FOOT_RUN/WALK)
	var hs: Array = [top]
	var t := WALK
	while t <= WALK_MOST:
		var q := c+d*t
		var h: float = (impl.sample(q.x,q.y) as Vector2).x
		if h < SEA_Y+3.0 or float(impl.last_river) < RIVER_OFF:
			# A river's valley under the flank: the mouth stands back from it.
			var b := hs.size()-1-int(RIVER_OFF/WALK)
			if b > 0 and top-float(hs[b]) > TALL_MIN: return Vector3(b*WALK,float(hs[b]),1.0)
			return Vector3(t,h,0.0)
		hs.append(h)
		if hs.size() > back and top-h > TALL_MIN and ((float(hs[-1-back])-h)/FOOT_RUN < FOOT_SLOPE or top-h > FOOT_DEEP): return Vector3(t,h,1.0)
		t += WALK
	return Vector3(t,0.0,-1.0)

static func _fit(impl: Object, seed: int, ponds: float, ci: int, cj: int, x: float, z: float) -> PackedFloat32Array:
	var none := PackedFloat32Array()
	# Up the slope onto the crest, its way off a ring, straight either side.
	var e := 6.0
	var g := Vector2(_h(impl,x+e,z)-_h(impl,x-e,z),_h(impl,x,z+e)-_h(impl,x,z-e))
	var c := Vector2(x,z)
	if g.length() > 0.01: c = _snap(impl,c,g.normalized(),SNAP,3.0)
	var best_a := 0.0
	var best_h := -INF
	for k in 16:
		var a := PI*k/16.0
		var w := Vector2(cos(a),sin(a))*RING
		var h := _h(impl,c.x+w.x,c.y+w.y)+_h(impl,c.x-w.x,c.y-w.y)
		if h > best_h:
			best_h = h
			best_a = a
	var along := Vector2(cos(best_a),sin(best_a))
	var across := Vector2(-along.y,along.x)
	c = _snap(impl,c,across,SNAP*0.5,2.0)
	var c1 := _snap(impl,c-along*ALONG,across,SNAP*0.7,3.0)
	var c2 := _snap(impl,c+along*ALONG,across,SNAP*0.7,3.0)
	var line := (c2-c1).normalized()
	if absf((c-c1).dot(Vector2(-line.y,line.x))) > STRAIGHT: return none
	across = Vector2(-line.y,line.x)
	# Across the range to its feet.
	var hc := _h(impl,c.x,c.y)
	var fa := _foot(impl,c,-across,hc)
	var fb := _foot(impl,c,across,hc)
	if fa.z < 1.0 or fb.z < 1.0: return none
	var crossing := fa.x+fb.x
	if crossing < LENGTH.x or crossing > LENGTH.y: return none
	var mid := c+across*((fb.x-fa.x)*0.5)
	var hl := crossing*0.5
	# The way along the slot (from foot a to foot b), from the seed.
	var way := across
	var ya := fa.y
	var yb := fb.y
	if _hash01(seed,ci,cj,2) < 0.5:
		way = -way
		ya = fb.y
		yb = fa.y
	# The floor: from the lower foot, the other end within GRADE_MOST of it
	# (its foot's land climbed by the ramp past the end).
	var lo := minf(ya,yb)
	if lo < SEA_Y+4.0: return none
	var ea := minf(ya,lo+GRADE_MOST*crossing)
	var eb := minf(yb,lo+GRADE_MOST*crossing)
	var slope := (eb-ea)/crossing
	var floor_mid := (ea+eb)*0.5-SINK
	if hc-maxf(ea,eb) < TALL_MIN: return none
	var rise := maxf(ya-ea,yb-eb)
	var reach := hl+minf(rise/GRADE+16.0,RAMP_MOST)
	# The bend: an S no tighter than TURN_MIN.
	var bend := minf(BEND_MOST,hl*hl/(PI*PI*TURN_MIN))*(_hash01(seed,ci,cj,3)*2.0-1.0)
	var salt := int(hash([seed,ci,cj,"split"]) & 0xffff)
	# The cut's top: the land round the path read along its edge, the walls
	# widened till they stand over it.
	var name := "%s/split/%d_%d" % [_world_id(),ci,cj]
	if LayoutOverrides.deleted(name): return none
	var yaw := atan2(-way.y,way.x)
	var coded := Transform3D(Basis(Vector3.UP,yaw),Vector3(mid.x,floor_mid,mid.y))
	var top := hc+TOP_OVER
	var site := _site(coded,hl,reach,slope,bend,top,salt,hc)
	for _round in 3:
		var over := -INF
		var u := -reach
		while u <= reach:
			for sgn: float in [-1.0,1.0]:
				var q := _edge(site,u,sgn*site[11]*0.97)
				over = maxf(over,_h(impl,q.x,q.y)-_wall(site,u,site[11]*0.97))
			u += 12.0
		if over <= 0.0: break
		top += over+TOP_OVER
		site = _site(coded,hl,reach,slope,bend,top,salt,hc)
		if site[11] > WIDE_MOST: return none
	if site[11] > WIDE_MOST: return none
	# The whole cut inside the square.
	var sq := Rect2(ci*CELL,cj*CELL,CELL,CELL).grow(-8.0)
	var w2 := Vector2(site[2],site[3])
	var n2 := Vector2(-w2.y,w2.x)
	for su: float in [-1.0,1.0]:
		for sv: float in [-1.0,1.0]:
			if not sq.has_point(mid+w2*su*site[7]+n2*sv*site[8]): return none
	# In a world of regions, wholly inside one that grows splits.
	if impl.has_method("site_ok"):
		var ex := absf(w2.x)*site[7]+absf(w2.y)*site[8]
		var ez := absf(w2.y)*site[7]+absf(w2.x)*site[8]
		if not impl.site_ok(&"splits",mid.x-ex,mid.y-ez,mid.x+ex,mid.y+ez): return none
	# The ends climb out to the land within the reach (no trench left at the
	# cut's end; its sides ease into the land, EASE), no river's water along
	# the floor or at the mouths, no sea.
	for end: float in [-1.0,1.0]:
		var q := _edge(site,end*site[7],0.0)
		if _h(impl,q.x,q.y) > floor_at(site,end*site[7])+1.0: return none
	var u2 := -site[7]
	while u2 <= site[7]:
		var p := point(site,u2)
		var h := _h(impl,p.x,p.z)
		# Along the floor a river's water no nearer than (about) RIVER_OFF;
		# past the ends, none where the ramp cuts.
		var keep := RIVER_OFF*0.75 if absf(u2) <= site[4] else (10.0 if h > floor_at(site,u2) else -INF)
		if (absf(u2) <= site[4] and h < SEA_Y+3.0) or float(impl.last_river) < keep: return none
		u2 += 8.0
	if ponds > 0.0:
		for pond: PackedFloat32Array in Ponds.ponds_in(impl,seed,ponds,mid.x-site[7]-site[8],mid.y-site[7]-site[8],mid.x+site[7]+site[8],mid.y+site[7]+site[8],{}):
			var q := local(site,pond[0],pond[1])
			if absf(q.x) < site[7]+pond[11]+Ponds.REACH and absf(q.y) < site[8]+pond[11]+Ponds.REACH: return none
	# A way on out of each mouth (no hill straight ahead) and a flat to land
	# on out of each.
	for end: float in [-1.0,1.0]:
		if not _open(impl,site,end) or not _flat_near(impl,site,end): return none
	# A move in the layout file wins (its yaw and place).
	var xf := LayoutOverrides.xform(name,coded)
	var frame := Transform3D(Basis(Vector3.UP,atan2(-xf.basis.x.z,xf.basis.x.x)),xf.origin)
	if frame != coded: site = _site(frame,hl,reach,slope,bend,top,salt,hc)
	return site

## The world XZ `v` m across the path at `u` along (site `s`).
static func _edge(s: PackedFloat32Array, u: float, v: float) -> Vector2:
	var c := path(s,u)
	var way := Vector2(s[2],s[3])
	var n := Vector2(-way.y,way.x)
	var t := (way+n*c.y).normalized()
	var nn := Vector2(-t.y,t.x)
	return Vector2(s[0],s[1])+way*u+n*c.x+nn*v

## The wall's lowest height `d` m off the path at `u` along (the flutes
## and swell standing back their most).
static func _wall(s: PackedFloat32Array, u: float, d: float) -> float:
	var e := d-_half(s,u)-setback_most()
	return floor_at(s,u)+minf(_rise(s,u,0,e),_rise(s,u,1,e))

## A site's array for the frame `frame` (the floor's middle at its origin,
## the slot along its +X).
static func _site(frame: Transform3D, hl: float, reach: float, slope: float, bend: float, top: float, salt: int, crest: float) -> PackedFloat32Array:
	var way := Vector2(frame.basis.x.x,frame.basis.x.z).normalized()
	var lid_lo := frame.origin.y-absf(slope)*hl
	var wide := HALF*(1.0+FLARE_WIDEN)+setback_most()+EDGE*2.0+BENCH.y+maxf(top-lid_lo-TIER.x-TIER_UP.x,0.0)*LEAN+EASE
	return PackedFloat32Array([frame.origin.x,frame.origin.z,way.x,way.y,hl,HALF,frame.origin.y,reach,wide+absf(bend),bend,slope,wide,float(salt),crest])

## Whether the way out of the mouth at `end` (-1 or 1) runs on open for
## OPEN m: the land along it, and OPEN_FAN either side, stays under the
## floor at the mouth plus OPEN_RISE m and OPEN_CLIMB of the way, so the
## slot never sends the plane at a hill it cannot climb.
static func _open(impl: Object, s: PackedFloat32Array, end: float) -> bool:
	var m := point(s,end*s[4])
	var at := Vector2(m.x,m.z)
	var o := Vector2(s[2],s[3])*end
	for turn: float in [-OPEN_FAN,0.0,OPEN_FAN]:
		var d := o.rotated(turn)
		var a := 16.0
		while a <= OPEN:
			var p := at+d*a
			if _h(impl,p.x,p.y) > m.y+OPEN_RISE+a*OPEN_CLIMB: return false
			a += 16.0
	return true

## Whether a flat lies within FLAT_REACH m out of the mouth at `end` (-1 or
## 1): FLAT_RUN m of dry land within FLAT_RISE m on one of the rays.
static func _flat_near(impl: Object, s: PackedFloat32Array, end: float) -> bool:
	var m := point(s,end*s[4])
	var at := Vector2(m.x,m.z)
	var o := Vector2(s[2],s[3])*end
	var need := ceili(FLAT_RUN/FLAT_STEP)+1
	for turn: float in FLAT_FAN:
		var d := o.rotated(turn)
		var run := PackedFloat32Array()
		var a := FLAT_STEP*2.0
		while a < FLAT_REACH:
			var p := at+d*a
			var h := _h(impl,p.x,p.y)
			if h < SEA_Y+3.0 or float(impl.last_river) < 20.0: run.clear()
			else:
				run.append(h)
				while run.size() > 1:
					var lo := INF
					var hi := -INF
					for v: float in run:
						lo = minf(lo,v)
						hi = maxf(hi,v)
					if hi-lo <= FLAT_RISE: break
					run.remove_at(0)
				if run.size() >= need: return true
			a += FLAT_STEP
	return false

static func _world_id() -> String:
	return String(preload("res://scripts/endless/world/world_profile.gd").current().id)

## --split-near-start: the start for site `s`, START_BACK m out of its lower
## mouth on the way in: {at (Vector2), heading (degrees clockwise from -z),
## mouth (Vector3), exit (Vector3)}.
static func approach(s: PackedFloat32Array) -> Dictionary:
	var end := -1.0 if s[10] >= 0.0 else 1.0
	var mouth := point(s,end*s[4])
	var other := point(s,-end*s[4])
	var inward := Vector2(s[2],s[3])*-end
	var at := Vector2(mouth.x,mouth.z)-inward*START_BACK
	return {"at":at,"heading":rad_to_deg(atan2(inward.x,-inward.y)),"mouth":mouth,"exit":other}

# --- The cut over a chunk's and a grid's arrays ------------------------------------

## The split pass over a chunk's arrays (LandField.build_chunk; its args),
## after the ponds', the tunnels' and the halls'. `field` is the LandField
## (its `height` has the splits in).
static func apply_chunk(field: Object, impl: Object, made: Dictionary, ss: Array, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	var n := cells+1
	var heights: PackedFloat32Array = made.heights
	var verts: PackedVector3Array = made.verts
	var moved := PackedByteArray()
	moved.resize(n*n)
	var marks := PackedByteArray()
	marks.resize(n*n*2)
	var keep := PackedByteArray()
	keep.resize(n*n)
	var any_moved := false
	for s: PackedFloat32Array in ss:
		var r := s[7]+s[8]
		var i0 := clampi(floori((s[0]-r-x0)/step),0,cells)
		var i1 := clampi(ceili((s[0]+r-x0)/step),0,cells)
		var j0 := clampi(floori((s[1]-r-z0)/step),0,cells)
		var j1 := clampi(ceili((s[1]+r-z0)/step),0,cells)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var v := j*n+i
				var got := cut(s,heights[v],x0+i*step,z0+j*step)
				if got.y < 0.0 or absf(got.x-heights[v]) <= 0.0005: continue
				heights[v] = got.x
				verts[v] = Vector3(verts[v].x,got.x,verts[v].z)
				moved[v] = 1
				marks[v*2] = int(got.y*255.0)
				marks[v*2+1] = int(maxf(got.z,0.0)*255.0)
				# The floor keeps its meadow (the land's turf runs on in).
				if got.z < 0.0: keep[v] = 1
				any_moved = true
	if not any_moved: return
	made.heights = heights
	made.verts = verts
	Sites.refresh(field,impl,made,moved,x0,z0,step,cells,skirt_drop,marks,keep)

## The split pass over LandField.grid's arrays (the grass's): the cut's
## heights, and its walls read as a river's water (`river` -1), so no tuft
## or flower grows on the rock; the floor keeps its grass.
static func apply_grid(got: Dictionary, ss: Array, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var hs: PackedFloat32Array = got.heights
	var rs: PackedFloat32Array = got.river
	for s: PackedFloat32Array in ss:
		var r := s[7]+s[8]
		var i0 := clampi(floori((s[0]-r-x0)/step)+pad,0,nx-1)
		var i1 := clampi(ceili((s[0]+r-x0)/step)+pad,0,nx-1)
		var j0 := clampi(floori((s[1]-r-z0)/step)+pad,0,nz-1)
		var j1 := clampi(ceili((s[1]+r-z0)/step)+pad,0,nz-1)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var k := j*nx+i
				var c := cut(s,hs[k],x0+(i-pad)*step,z0+(j-pad)*step)
				if c.y < 0.0: continue
				hs[k] = c.x
				if c.z >= 0.0: rs[k] = minf(rs[k],-1.0)
	got.heights = hs
	got.river = rs
