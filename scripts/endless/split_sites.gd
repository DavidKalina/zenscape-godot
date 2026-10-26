extends RefCounted
## Split mountains (docs/design/endless-flight/split-mountain-handoff.md,
## split-types-handoff.md): a canyon cut through a range from foot to foot,
## rock walls standing on both sides, its floor flown in at one end and out
## at the other. A layer over the land field, as the ponds and the slot
## halls' cuts are: LandField (land_field.gd) cuts the canyon in after the
## native or GDScript field has worked, so both fields read the same
## canyons and nothing native changes.
##
## At most one per CELL m square, from the seed and the square alone. A
## square rolls (CHANCE times the density), then scans its middle for a
## range's crest (`mountain` at least CREST_MIN) and tries the best spots,
## as hall_sites.gd does: up onto the crest, the crest's way read off a
## ring, the crest checked straight either side, then the range walked
## across to its feet (each at least TALL_MIN m under the crest). The
## canyon runs foot to foot, its floor falling from the higher foot to the
## lower at GRADE_MOST at the most. The whole cut stays inside the square,
## so a point asks only its own square.
##
## Kinds (TYPES): each canyon is one of slot, winding, gorge or grand,
## picked from the seed and the square among the kinds its crossing fits
## (each kind's length and depth), weighed by the world's mix (the
## profile's `split_kinds` layer, MIX by default) and by the land: a sharp
## crest leans to slot and winding, a broad high crossing (a tableland) to
## gorge and grand (`_fill`). Each kind rolls its own numbers within its
## ranges: the floor's width (WorldScale.opening of the kind's toy width),
## the bends, the tiers and benches, the lean, the wander, the buttresses,
## the strata, the mouths. `--split-kind=K` forces one.
##
## Kept: no river's water within RIVER_OFF m of its floor or mouths, no pond
## by it, the sea off it, and a flat to land on (FLAT_RUN m of land within
## FLAT_RISE m) within FLAT_REACH m out of each mouth (AGENTS.md, meadows).
##
## The cut: the floor is the kind's opening wide at its narrowest; each wall
## stands back from it by its own wander (so the walls are never parallel),
## its buttresses and alcoves (ribs standing out, bays set in, each the
## whole wall's height) and small flutes. From the floor each wall rises in
## the kind's tiers with benches between, each bench pinching out and
## widening along the canyon, so each tier's line wanders on its own. Over
## the top tier it leans back to the land in strata: level ledges at the
## same heights on both walls. Toward each mouth the canyon flares open
## (the kind's flare). Past each end the floor climbs at GRADE till it
## meets the land; the cut's edges ease back into the land (EASE).
##
## A site is a PackedFloat32Array laid out as hall_sites.gd's where they
## share (tunnel_sites.gd `blocks_hall`, tree_plan.gd's keep-outs read
## [0], [1], [2], [3], [7], [8]): [centre x, centre z, way x, way z (unit,
## along the canyon), half length (foot to foot), the floor's half width at
## its narrowest, the floor's height at the middle, reach (half length of
## the whole cut), the cut's half width round its centre line (its widest
## plus the bend), the bend (m, the swing's amplitude), the floor's slope
## along the way (rise per m), the cut's half width off the path (its top),
## the walls' salt, the crest's height], then the kind's rolled numbers at
## K_* (the kind's index, the bend's half waves, the tiers, a tier's rise
## least and most, a bench's width least and most, a tier's riser across,
## the lean, the wander and its scale, the buttresses' depth and scale, the
## flare's length and widening, the strata's step and tread share, the
## walls' setback at the most).
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
## squares that roll, only those with a range's crest fit for a canyon get
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
## FOOT_DEEP m under the crest (the canyon then opens high on the flank);
## the crossing's length foot to foot (m) any kind takes.
const WALK := 4.0
const WALK_MOST := 520.0
const FOOT_SLOPE := 0.14
const FOOT_RUN := 16.0
const TALL_MIN := 70.0
const FOOT_DEEP := 110.0
const LENGTH := Vector2(160.0,860.0)
## The floor's slope along the canyon at the most (rise over run), how far
## under the lower foot it is sunk (m).
const GRADE_MOST := 0.07
const SINK := 0.3

## The kinds, by index (a site's K_KIND).
const KINDS := ["slot","winding","gorge","grand"]
## Each kind's floor at its narrowest, a toy-era width (WorldScale.opening:
## 12, 18, 36 and 76 m at the knobs; --split-slot=X the slot's).
const TOY_SLOT := 6.0
const TOY_WINDING := 9.0
const TOY_GORGE := 18.0
const TOY_GRAND := 38.0
## The mix of kinds when the world names none (its `split_kinds` layer).
const MIX := {"slot":1.0,"winding":1.0,"gorge":1.0,"grand":1.0}
## Each kind's numbers; a Vector2 is a range a site rolls within:
##   toy        the floor's toy width at its narrowest (above)
##   wide       the floor's width over that, a share (1 the narrowest)
##   length     the crossing it takes, foot to foot (m)
##   tall       the crest over the floor at the least (m)
##   land       the land it leans to: -1 a sharp crest, 1 a broad one
##   half_wave  the bend's half wave along the canyon (m); `waves` the
##              count of them at the least and most (a Vector2i)
##   turn       the bend's tightest turn (m); `bend` its swing at the most
##   tiers      the walls' tiers (a Vector2i, up to TIERS_MOST); `tier` each
##              one's rise (m). Each tier stands to its own level, the same
##              world height along the canyon and on both walls (strata).
##   bench      the bench between two tiers (m across; pinching out)
##   edge       a tier's riser across (m: the smaller, the sheerer)
##   lean       over the top tier, run over rise up to the land
##   talus      the scree apron at the walls' foot: (rise, across) m
##   blocks     the joints: blocks (m along) each tier's line steps by
##              (up to m), each tier its own
##   wander     each wall's own setback's swing (m) and its scale along
##   buttress   the ribs' and alcoves' depth (m) and their scale along
##   flare      the mouths' flare (m along) and the floor's widening there
##   strata     the ledges' step over the lean (m; 0 none) and the treads'
##              share of it
##   wide_most  the cut's half width at the most (m)
const TYPES := {
	"slot":{"toy":TOY_SLOT,"wide":Vector2(1.0,1.1),"length":Vector2(160.0,400.0),"tall":70.0,"land":-1.0,
		"half_wave":320.0,"waves":Vector2i(1,2),"turn":240.0,"bend":9.0,
		"tiers":Vector2i(2,3),"tier":Vector2(22.0,38.0),"bench":Vector2(0.0,2.5),"edge":2.2,"lean":Vector2(0.07,0.11),
		"talus":Vector2(0.0,0.0),"blocks":Vector2(4.0,1.6),
		"wander":Vector2(1.0,2.5),"wander_scale":55.0,"buttress":Vector2(3.5,6.0),"buttress_scale":Vector2(12.0,18.0),
		"flare":Vector2(80.0,100.0),"flare_widen":Vector2(2.2,2.8),"strata":Vector2(0.0,0.0),"tread":Vector2(0.5,0.6),"wide_most":200.0},
	"winding":{"toy":TOY_WINDING,"wide":Vector2(1.0,1.15),"length":Vector2(240.0,700.0),"tall":70.0,"land":-0.6,
		"half_wave":150.0,"waves":Vector2i(2,5),"turn":120.0,"bend":30.0,
		"tiers":Vector2i(2,3),"tier":Vector2(18.0,32.0),"bench":Vector2(0.5,5.0),"edge":3.0,"lean":Vector2(0.14,0.22),
		"talus":Vector2(2.0,3.0),"blocks":Vector2(7.0,1.6),
		"wander":Vector2(2.5,4.5),"wander_scale":60.0,"buttress":Vector2(4.0,7.0),"buttress_scale":Vector2(20.0,30.0),
		"flare":Vector2(70.0,90.0),"flare_widen":Vector2(1.3,1.7),"strata":Vector2(7.0,10.0),"tread":Vector2(0.45,0.6),"wide_most":240.0},
	"gorge":{"toy":TOY_GORGE,"wide":Vector2(1.0,1.2),"length":Vector2(180.0,640.0),"tall":95.0,"land":0.6,
		"half_wave":260.0,"waves":Vector2i(1,2),"turn":300.0,"bend":28.0,
		"tiers":Vector2i(3,4),"tier":Vector2(18.0,32.0),"bench":Vector2(3.0,12.0),"edge":4.5,"lean":Vector2(0.28,0.42),
		"talus":Vector2(4.0,7.0),"blocks":Vector2(10.0,2.6),
		"wander":Vector2(6.0,11.0),"wander_scale":90.0,"buttress":Vector2(10.0,16.0),"buttress_scale":Vector2(36.0,55.0),
		"flare":Vector2(90.0,110.0),"flare_widen":Vector2(0.8,1.1),"strata":Vector2(8.0,12.0),"tread":Vector2(0.5,0.65),"wide_most":300.0},
	"grand":{"toy":TOY_GRAND,"wide":Vector2(1.0,1.3),"length":Vector2(400.0,860.0),"tall":85.0,"land":1.0,
		"half_wave":280.0,"waves":Vector2i(2,3),"turn":320.0,"bend":40.0,
		"tiers":Vector2i(3,5),"tier":Vector2(14.0,26.0),"bench":Vector2(6.0,22.0),"edge":5.5,"lean":Vector2(0.45,0.7),
		"talus":Vector2(6.0,12.0),"blocks":Vector2(14.0,3.5),
		"wander":Vector2(12.0,20.0),"wander_scale":140.0,"buttress":Vector2(16.0,26.0),"buttress_scale":Vector2(50.0,80.0),
		"flare":Vector2(100.0,130.0),"flare_widen":Vector2(0.5,0.8),"strata":Vector2(6.0,9.0),"tread":Vector2(0.5,0.65),"wide_most":370.0},
}
## The land's fill under the crossing (`_fill`: the mean of the land over
## the line between the feet, as a share of the crest over it): under
## FILL_SHARP a sharp crest, over FILL_BROAD a broad one (a tableland). A
## kind's lean to the land it does not lean to keeps LAND_KEEP of its
## weight.
const FILL_SHARP := 0.44
const FILL_BROAD := 0.62
const LAND_KEEP := 0.25

## A site's slots past the shared ones (above): K_LEVEL holds TIERS_MOST
## tiers' levels (m over the floor's middle), the pairs their least and
## most, or a size and depth.
const TIERS_MOST := 5
const K_KIND := 14
const K_WAVES := 15
const K_TIERS := 16
const K_LEVEL := 17
const K_BENCH := 22
const K_EDGE := 24
const K_LEAN := 25
const K_WANDER := 26
const K_BUTTRESS := 28
const K_FLARE := 30
const K_STRATA := 32
const K_TALUS := 34
const K_BLOCK := 36
const K_BACK := 38

## The walls' small flutes (m: Vector2(scale along, depth)); a bench's
## width wanders over BENCH_SCALE m along and it climbs BENCH_RISE over its
## width. The buttresses' edges: their noise stepped over RIB_EDGE (the
## nearer, the squarer the ribs). A joint's step takes BLOCK_EDGE of its
## block.
const FLUTE := Vector2(6.0,1.0)
const BENCH_SCALE := 45.0
const BENCH_RISE := 0.25
const RIB_EDGE := Vector2(0.4,0.6)
const BLOCK_EDGE := 0.15
## Down in the canyon the walls shade as a deep groove (the carve's groove
## mark): from DEEP_SHADE.x to DEEP_SHADE.y times the canyon's width under
## the old ground (none at the rim, all of it that deep and more).
const DEEP_SHADE := Vector2(0.15,1.6)
## The mouths: over the last of the kind's flare (FLARE_SHARE of the half
## length at the most) the canyon opens out, its floor widened by the
## kind's flare widening, its tiers down to FLARE_LOW of their rise,
## softened to FLARE_SOFT times their width across (slopes, not steps,
## where the land is low) and its lean out to FLARE_LEAN, so the range
## opens round the way in rather than a trench ending in a wall.
const FLARE_SHARE := 0.35
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
## How far over the land round it the top of the walls is kept (m).
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
## canyon's way in, ALT m over the land; the squares searched round the start.
const START_BACK := 520.0
const START_ALT := 28.0
const START_RINGS := 5

static var _cache := {}
static var _lock := Mutex.new()
static var _forced: int = _kind_forced()
static var _toy_slot_arg: float = _toy_slot()

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

## `--split-kind=K`'s kind index, or -1.
static func _kind_forced() -> int:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--split-kind="):
			var k := KINDS.find(a.get_slice("=",1))
			if k < 0: push_warning("--split-kind: one of %s" % str(KINDS))
			return k
	return -1

static func _toy_slot() -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--split-slot="): return maxf(0.0,float(a.get_slice("=",1)))
	return TOY_SLOT

## Site `s`'s kind's name.
static func kind_name(s: PackedFloat32Array) -> String:
	return KINDS[int(s[K_KIND])]

static func _hash01(seed: int, i: int, j: int, salt: int) -> float:
	return float(hash([seed,i,j,salt,7717]) & 0xffffff)/16777216.0

## The square key holding (x, z).
static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/CELL),floori(z/CELL))

## The site of square `key`, or an empty array. `impl` is the field doing
## the work (its last sample is overwritten when the square is first looked
## at, read at full detail); `local` is the asking LandField's own cache;
## `ponds` the field's pond density; `mix` the world's mix of kinds
## (`split_kinds`; empty: MIX).
static func cell_site(impl: Object, seed: int, density: float, ponds: float, key: Vector2i, local: Dictionary, mix: Dictionary = {}) -> PackedFloat32Array:
	var got: Variant = local.get(key)
	if got != null: return got
	var k4 := [key.x,key.y,seed,int(density*1000.0),hash(mix)]
	_lock.lock()
	got = _cache.get(k4)
	_lock.unlock()
	if got == null:
		var was: float = impl.detail
		impl.detail = 0.0
		got = _make(impl,seed,density,ponds,key.x,key.y,mix if not mix.is_empty() else MIX)
		impl.detail = was
		_lock.lock()
		if _cache.has(k4): got = _cache[k4]
		else: _cache[k4] = got
		_lock.unlock()
	local[key] = got
	return got

## (x, z) in site `s`'s frame: Vector2(along the canyon from its middle, across).
static func local(s: PackedFloat32Array, x: float, z: float) -> Vector2:
	var dx := x-s[0]
	var dz := z-s[1]
	return Vector2(dx*s[2]+dz*s[3],-dx*s[3]+dz*s[2])

## The path's centre line across at `u` along (held at its ends' past
## them) and its slope there: Vector2(offset, d offset / d u). It swings
## the bend's amplitude in K_WAVES half waves, straight along the way at
## both mouths.
static func path(s: PackedFloat32Array, u: float) -> Vector2:
	var hl := s[4]
	var k := PI*s[K_WAVES]/(2.0*hl)
	if absf(u) >= hl: return Vector2(s[9]*cos(k*(signf(u)*hl+hl)),0.0)
	var a := k*(u+hl)
	return Vector2(s[9]*cos(a),-s[9]*k*sin(a))

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
	var across := Vector2(-way.y,way.x)
	for k in n:
		var u := -s[7]+half*(2*k+1)
		out.append([Vector2(s[0],s[1])+way*u,cos(turned),sin(turned),s[8],half])
	# A lane on through the woods out of each mouth, LANE m on, as wide as
	# the mouth, on the path's line there.
	for end: float in [-1.0,1.0]:
		out.append([Vector2(s[0],s[1])+way*end*(s[7]+LANE*0.5)+across*path(s,end*s[4]).x,cos(turned),sin(turned),s[5]*(1.0+s[K_FLARE+1])+10.0,LANE*0.5])
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

## How far into a mouth's flare `u` along lies (0 inside, 1 at the mouth
## and past it).
static func _flare(s: PackedFloat32Array, u: float) -> float:
	var reach := minf(s[K_FLARE],s[4]*FLARE_SHARE)
	return smoothstep(s[4]-reach,s[4],absf(u))

## The floor's half width at `u` along before the walls' own setbacks: the
## narrowest, the mouths' flare in.
static func _half(s: PackedFloat32Array, u: float) -> float:
	return s[5]*(1.0+s[K_FLARE+1]*_flare(s,u))

## Wall `side` (0 or 1)'s setback from the floor's edge at `u` along:
## Vector2(m, the alcove's share 0..1: 0 a buttress standing out, 1 an
## alcove set in). Each wall wanders on its own, so the two never run
## parallel; its foot steps in blocks (the joints).
static func _back(s: PackedFloat32Array, u: float, side: int) -> Vector2:
	var salt := int(s[12])+side*17
	var wander := s[K_WANDER]*_vn(u/s[K_WANDER+1],salt+3)
	var bay := smoothstep(RIB_EDGE.x,RIB_EDGE.y,_vn(u/s[K_BUTTRESS+1],salt+5))
	var flute := FLUTE.y*_vn(u/FLUTE.x,salt+7)
	return Vector2(wander+s[K_BUTTRESS]*bay+flute+_blocks(s,u,salt+19),bay)

## The joints: a step of up to the kind's block depth, the same along each
## block (the kind's block size along), changing over BLOCK_EDGE of it.
static func _blocks(s: PackedFloat32Array, u: float, salt: int) -> float:
	var t := u/s[K_BLOCK]
	var i := floori(t)
	return s[K_BLOCK+1]*lerpf(_r(i-1,salt),_r(i,salt),smoothstep(0.0,BLOCK_EDGE,t-i))

## Bench `k` of wall `side`'s width at `u` along: pinching out to the
## kind's least in places (the tiers then one face), widening to its most
## (a ledge) in others, stepped by its own joints. `lowest`: the widest.
static func _bench(s: PackedFloat32Array, u: float, salt: int, k: int, lowest: bool) -> float:
	if lowest: return s[K_BENCH+1]+s[K_BLOCK+1]
	return lerpf(s[K_BENCH],s[K_BENCH+1],smoothstep(0.2,0.8,_vn(u/BENCH_SCALE+k*3.7,salt+9+k*13)))+_blocks(s,u,salt+23+k*7)

## Wall `side`'s height over the floor `e` m past the floor's edge (its
## setback in) at `u` along, the floor there at world height `lid`: the
## talus, the tiers each to its level with their benches between, then the
## lean in its strata; the mouths' flare in. `lowest` reads the lowest the
## wall can stand there (the widest benches, no strata), for the cut's
## extent.
static func _rise(s: PackedFloat32Array, u: float, side: int, e: float, lid: float, lowest := false) -> float:
	if e <= 0.0: return 0.0
	var salt := int(s[12])+side*31
	var f := _flare(s,u)
	var low := lerpf(1.0,FLARE_LOW,f)
	var edge := s[K_EDGE]*lerpf(1.0,FLARE_SOFT,f)
	var y := 0.0
	# The talus: a scree apron at the foot, steepening to the rock.
	var tw := s[K_TALUS+1]
	if tw > 0.0:
		var th := s[K_TALUS]*low
		if e <= tw:
			var a := e/tw
			return th*a*a
		e -= tw
		y = th
	# The tiers, each up to its level over the floor's middle (so a tier
	# under the floor where it climbs is gone), each riser rounded at its
	# foot and lip.
	var under := s[6]-lid
	var n := int(s[K_TIERS])
	for k in n:
		var t := (s[K_LEVEL+k]+under)*low-y
		if t <= 0.5: continue
		if e <= edge:
			var a := e/edge
			return y+t*a*a*(3.0-2.0*a)
		e -= edge
		y += t
		if k < n-1:
			var b := _bench(s,u,salt,k,lowest)
			if e <= b: return y+e*BENCH_RISE
			e -= b
			y += b*BENCH_RISE
	var h := e/lerpf(s[K_LEAN],FLARE_LEAN,f)
	if lowest: return y+h
	return y+_strata(s,lid+y,h,f)

## The strata over the lean: the rise `h` over the lean's foot (at world
## height `y0`) stepped in level ledges, the treads at the same world
## heights on both walls (a step of K_STRATA m, its tread K_STRATA+1 of
## it), fading out toward the mouths (`f`).
static func _strata(s: PackedFloat32Array, y0: float, h: float, f: float) -> float:
	var step := s[K_STRATA]
	if step <= 0.0 or h <= 0.0: return h
	var tread := s[K_STRATA+1]
	var a := _terrace(y0/step,tread)
	var b := _terrace((y0+h)/step,tread)
	return lerpf((b-a)*step,h,f)

static func _terrace(t: float, tread: float) -> float:
	var i := floorf(t)
	return i+smoothstep(tread,1.0,t-i)

## Vector3(the land's height `base` with site `s`'s canyon cut in at (x, z),
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
	var y := lid+_rise(s,q.x,side,e,lid)
	# Eased back into the land at the cut's edge and its ends.
	var t := maxf(smoothstep(s[11]-EASE,s[11],d),smoothstep(s[7]-EASE,s[7],au))
	y = lerpf(y,base,t)
	if y >= base-0.0005: return Vector3(base,-1.0,0.0)
	if e <= 0.0: return Vector3(y,0.0,-1.0)
	# The groove: an alcove's, or the canyon's depth here (how far under the
	# old ground, over the canyon's width), so the rock down in a canyon
	# shades as the deep groove it is (endless_rock.gdshaderinc: darker,
	# cooler, its painted light leaning to shade) rather than as an open
	# face in the sun.
	var wide := 2.0*(_half(s,q.x)+back.x)
	var deep := smoothstep(DEEP_SHADE.x,DEEP_SHADE.y,(base-y)/wide)*(1.0-t)
	return Vector3(y,maxf(smoothstep(0.55,1.0,back.y)*0.8,deep),smoothstep(0.45,0.0,back.y)*0.7*(1.0-deep))

## The land's height `base` with site `s`'s canyon cut in at (x, z).
static func carve(s: PackedFloat32Array, base: float, x: float, z: float) -> float:
	return cut(s,base,x,z).x

# --- Finding a site ------------------------------------------------------------------

static func _h(impl: Object, x: float, z: float) -> float:
	return (impl.sample(x,z) as Vector2).x

static func _make(impl: Object, seed: int, density: float, ponds: float, ci: int, cj: int, mix: Dictionary) -> PackedFloat32Array:
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
	# The square's kinds in an order drawn from the world's mix (or the
	# forced one alone), each tried at every spot whose crossing fits it:
	# first only where the land takes it (a kind's land lean as a chance,
	# _likes), then anywhere it fits.
	var order: Array = [_forced] if _forced >= 0 else _draws(seed,ci,cj,mix)
	var tries := mini(TRIES,spots.size())
	var crossings: Array = []
	crossings.resize(tries)
	for gate: bool in ([false] if _forced >= 0 else [true,false]):
		for kind: int in order:
			for t in tries:
				if crossings[t] == null: crossings[t] = _cross(impl,seed,ci,cj,float(spots[t][1]),float(spots[t][2]))
				var x: Dictionary = crossings[t]
				if x.is_empty() or not _fits(kind,x): continue
				var take := lerpf(LAND_KEEP,1.0,_likes(kind,float(x.fill)))
				if gate == (_hash01(seed,ci,cj,70+t*5+kind) >= take): continue
				var got := _kind_site(impl,seed,ponds,ci,cj,kind,x)
				if not got.is_empty(): return got
	return none

## The kinds in an order drawn from `mix` ({name: weight}) for square
## (ci, cj), each from what is left; those the mix weighs nothing left out.
static func _draws(seed: int, ci: int, cj: int, mix: Dictionary) -> Array:
	var w := PackedFloat32Array()
	for k in KINDS.size(): w.append(maxf(float(mix.get(KINDS[k],0.0)),0.0))
	var out: Array = []
	for draw in KINDS.size():
		var k := _draw(_hash01(seed,ci,cj,6+draw*7),w)
		if k < 0: break
		out.append(k)
		w[k] = 0.0
	return out

## A kind drawn by its weight in `w` (a weight a kind) at `roll` (0..1),
## or -1 where nothing weighs.
static func _draw(roll: float, w: PackedFloat32Array) -> int:
	var sum := 0.0
	for v: float in w: sum += v
	if sum <= 0.0: return -1
	roll *= sum
	var got := -1
	for k in w.size():
		if w[k] <= 0.0: continue
		got = k
		roll -= w[k]
		if roll < 0.0: break
	return got

## Whether kind `k` fits crossing `x` (_cross): its length and depth.
static func _fits(k: int, x: Dictionary) -> bool:
	var t: Dictionary = TYPES[KINDS[k]]
	var r: Vector2 = t.length
	var crossing := float(x.hl)*2.0
	return crossing >= r.x and crossing <= r.y and float(x.deep) >= float(t.tall)

## How well kind `k` likes land of fill `fill` (_fill), 0..1: a sharp
## crest suits the kinds whose `land` is -1, a broad one those at 1.
static func _likes(k: int, fill: float) -> float:
	var broad := smoothstep(FILL_SHARP,FILL_BROAD,fill)
	var lean: float = TYPES[KINDS[k]].land
	return lerpf(1.0-broad,broad,lean*0.5+0.5)

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
## the canyon then opens high on the flank): Vector3(distance, height
## there, 1 if fit, 0 by a river's water or on the sea, -1 none within
## WALK_MOST).
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

## The land's fill under the crossing from `a` (`ya` high) to `b` (`yb`)
## over crest height `top`: the mean, over the line, of the land's height
## over the line between the feet as a share of the crest's (0.5 a straight
## sided ridge, toward 1 a tableland, under it a peak with concave flanks).
static func _fill(impl: Object, a: Vector2, ya: float, b: Vector2, yb: float, top: float) -> float:
	var n := maxi(8,int(a.distance_to(b)/12.0))
	var sum := 0.0
	for k in n:
		var t := (k+0.5)/n
		var p := a.lerp(b,t)
		var base := lerpf(ya,yb,t)
		sum += clampf((_h(impl,p.x,p.y)-base)/maxf(top-base,1.0),0.0,1.2)
	return sum/n

## Kind `k`'s number `key` rolled within its range for square (ci, cj).
static func _roll(seed: int, ci: int, cj: int, k: int, key: String, salt: int) -> float:
	var r: Vector2 = TYPES[KINDS[k]][key]
	return lerpf(r.x,r.y,_hash01(seed,ci,cj,40+salt))

## The crossing of the range from the crest nearest (x, z) to its feet:
## {name, coded (the floor's middle, the way along +X), hl, reach, slope,
## crest, deep (the crest over the floor's higher end), fill (_fill)}, or
## an empty one where no crossing fits.
static func _cross(impl: Object, seed: int, ci: int, cj: int, x: float, z: float) -> Dictionary:
	var none := {}
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
	# The way along the canyon (from foot a to foot b), from the seed.
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
	var deep := hc-maxf(ea,eb)
	if deep < TALL_MIN: return none
	# The land under it, for the kinds (_likes).
	var fill := _fill(impl,c-across*fa.x,fa.y,c+across*fb.x,fb.y,hc)
	var name := "%s/split/%d_%d" % [_world_id(),ci,cj]
	if LayoutOverrides.deleted(name): return none
	var yaw := atan2(-way.y,way.x)
	var coded := Transform3D(Basis(Vector3.UP,yaw),Vector3(mid.x,floor_mid,mid.y))
	var rise := maxf(ya-ea,yb-eb)
	var reach := hl+minf(rise/GRADE+16.0,RAMP_MOST)
	return {"name":name,"coded":coded,"hl":hl,"reach":reach,"slope":slope,"crest":hc,"deep":deep,"fill":fill}

## The site of kind `kind` on crossing `x` (_cross), or an empty array
## where its cut does not fit the land round it (too wide, out of its square or its region,
## by water, no way on or no flat out of a mouth).
static func _kind_site(impl: Object, seed: int, ponds: float, ci: int, cj: int, kind: int, x: Dictionary) -> PackedFloat32Array:
	var none := PackedFloat32Array()
	var name: String = x.name
	var coded: Transform3D = x.coded
	var hl: float = x.hl
	var reach: float = x.reach
	var slope: float = x.slope
	var hc: float = x.crest
	var salt := int(hash([seed,ci,cj,"split"]) & 0xffff)
	var mid := Vector2(coded.origin.x,coded.origin.z)
	var kn := _numbers(seed,ci,cj,kind,hl)
	# The bend: the kind's swing in its half waves, no tighter than its turn.
	var tk: Dictionary = TYPES[KINDS[kind]]
	var kk := PI*kn[K_WAVES-13]/(hl*2.0)
	var bend := minf(float(tk.bend),1.0/(float(tk.turn)*kk*kk))*lerpf(0.65,1.0,_hash01(seed,ci,cj,3))*(1.0 if _hash01(seed,ci,cj,5) < 0.5 else -1.0)
	# The cut's top: the land round the path read along its edge, the walls
	# widened till they stand over it.
	var top := hc+TOP_OVER
	var wide_most: float = tk.wide_most
	var site := _site(coded,hl,reach,slope,bend,top,salt,hc,kn)
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
		site = _site(coded,hl,reach,slope,bend,top,salt,hc,kn)
		if site[11] > wide_most: return none
	if site[11] > wide_most: return none
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
	if frame != coded: site = _site(frame,hl,reach,slope,bend,top,salt,hc,kn)
	return site

## Kind `kind`'s numbers rolled for square (ci, cj), a crossing `hl` m
## half long: the site's slots from K_KIND on, up to K_BACK (the floor's
## half width first, at [0], kept out by _site).
static func _numbers(seed: int, ci: int, cj: int, kind: int, hl: float) -> PackedFloat32Array:
	var t: Dictionary = TYPES[KINDS[kind]]
	var toy: float = _toy_slot_arg if kind == 0 else float(t.toy)
	var waves: Vector2i = t.waves
	var tiers: Vector2i = t.tiers
	var hw: float = t.half_wave
	var n_waves := clampi(roundi(hl*2.0/hw),waves.x,waves.y)
	var n_tiers := mini(tiers.x+int(_hash01(seed,ci,cj,60)*(tiers.y-tiers.x+1)*0.9999),TIERS_MOST)
	var tier: Vector2 = t.tier
	var bench: Vector2 = t.bench
	var bs: Vector2 = t.buttress_scale
	var talus: Vector2 = t.talus
	var blocks: Vector2 = t.blocks
	var out := PackedFloat32Array([WorldScale.opening(toy)*0.5*_roll(seed,ci,cj,kind,"wide",1),float(kind),float(n_waves),float(n_tiers)])
	# Each tier's level: the rises rolled one by one, summed.
	var level := 0.0
	for k in TIERS_MOST:
		level += lerpf(tier.x,tier.y,_hash01(seed,ci,cj,61+k))
		out.append(level if k < n_tiers else 0.0)
	out.append_array([bench.x,bench.y,float(t.edge),
		_roll(seed,ci,cj,kind,"lean",2),_roll(seed,ci,cj,kind,"wander",3),float(t.wander_scale),
		_roll(seed,ci,cj,kind,"buttress",4),lerpf(bs.x,bs.y,_hash01(seed,ci,cj,45)),
		_roll(seed,ci,cj,kind,"flare",6),_roll(seed,ci,cj,kind,"flare_widen",7),
		_roll(seed,ci,cj,kind,"strata",8),_roll(seed,ci,cj,kind,"tread",9),
		talus.x,talus.y,blocks.x,blocks.y])
	return out

## The world XZ `v` m across the path at `u` along (site `s`).
static func _edge(s: PackedFloat32Array, u: float, v: float) -> Vector2:
	var c := path(s,u)
	var way := Vector2(s[2],s[3])
	var n := Vector2(-way.y,way.x)
	var t := (way+n*c.y).normalized()
	var nn := Vector2(-t.y,t.x)
	return Vector2(s[0],s[1])+way*u+n*c.x+nn*v

## The wall's lowest height `d` m off the path at `u` along (the wander,
## the alcoves, the joints and the flutes standing back their most, the
## strata's step under the lean).
static func _wall(s: PackedFloat32Array, u: float, d: float) -> float:
	var e := d-_half(s,u)-s[K_BACK]
	var lid := floor_at(s,u)
	return lid+minf(_rise(s,u,0,e,lid,true),_rise(s,u,1,e,lid,true))-s[K_STRATA]

## A site's array for the frame `frame` (the floor's middle at its origin,
## the canyon along its +X); `kn` the kind's numbers (_numbers).
static func _site(frame: Transform3D, hl: float, reach: float, slope: float, bend: float, top: float, salt: int, crest: float, kn: PackedFloat32Array) -> PackedFloat32Array:
	var way := Vector2(frame.basis.x.x,frame.basis.x.z).normalized()
	var lid_lo := frame.origin.y-absf(slope)*hl
	var half := kn[0]
	var tiers := kn[K_TIERS-13]
	var back_most := kn[K_WANDER-13]+kn[K_BUTTRESS-13]+FLUTE.y+kn[K_BLOCK-13+1]
	var steps := kn[K_TALUS-13+1]+kn[K_EDGE-13]*tiers+(kn[K_BENCH-13+1]+kn[K_BLOCK-13+1])*(tiers-1)
	var lean := kn[K_LEAN-13]
	var wide := half*(1.0+kn[K_FLARE-13+1])+back_most+steps+maxf(top-lid_lo-kn[K_LEVEL-13+int(tiers)-1],0.0)*lean+EASE
	var out := PackedFloat32Array([frame.origin.x,frame.origin.z,way.x,way.y,hl,half,frame.origin.y,reach,wide+absf(bend),bend,slope,wide,float(salt),crest])
	out.append_array(kn.slice(1))
	out.append(back_most)
	return out

## Whether the way out of the mouth at `end` (-1 or 1) runs on open for
## OPEN m: the land along it, and OPEN_FAN either side, stays under the
## floor at the mouth plus OPEN_RISE m and OPEN_CLIMB of the way, so the
## canyon never sends the plane at a hill it cannot climb.
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
## mouth (Vector3), exit (Vector3), alt (m over the ground at `at`:
## START_ALT, or more so the way in stands START_CLEAR m over the land of
## `field` all the way to the mouth, and over the mouth's floor)}.
const START_CLEAR := 18.0
static func approach(s: PackedFloat32Array, field: Object = null) -> Dictionary:
	var end := -1.0 if s[10] >= 0.0 else 1.0
	var mouth := point(s,end*s[4])
	var other := point(s,-end*s[4])
	var inward := Vector2(s[2],s[3])*-end
	var at := Vector2(mouth.x,mouth.z)-inward*START_BACK
	var alt := START_ALT
	if field != null:
		var ground: float = field.height(at.x,at.y)
		# Over the mouth's floor too: a mouth high on the flank stands over
		# the land before it, and the way in glides down into it.
		alt = maxf(alt,mouth.y+START_CLEAR-ground)
		var a := 16.0
		while a < START_BACK:
			var p := at+inward*a
			alt = maxf(alt,float(field.height(p.x,p.y))+START_CLEAR-ground)
			a += 16.0
	return {"at":at,"heading":rad_to_deg(atan2(inward.x,-inward.y)),"mouth":mouth,"exit":other,"alt":alt}

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
