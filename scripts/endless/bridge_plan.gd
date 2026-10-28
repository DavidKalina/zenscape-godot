extends RefCounted
## Bridges and aqueducts that join the high ground (docs/design/endless-
## flight/spec-amber-r2.md, lane 2): from a plateau's top, a massif's
## shoulder or a terrace's shelf to another at a matched height, whatever
## lies between. A pure function of the seed and a bridge cell (CELL m, its
## own grid: a span crosses the arches' 480 m cells), read from the land's
## heights alone (`field.height` / `grid`), so the native and the GDScript
## fields both serve it and the land field needs no change.
##
## In a bridge cell, flat high points with a drop beside them are the rims
## tried. From one, a walk out each of DIRS ways crosses its top to the edge
## (the ground falling EDGE under it), then the gap, to where the ground
## climbs back to within MATCH of the rim: the far rim, if the ground fell at
## least DROP between and the far top holds near that height. The deck is
## level with the lower rim; the run reaches INTO a span past where each
## rim's ground meets it, so both ends are buried in rims.
##
## Forms (each a RuinKit aqueduct run, grown so its arches open to a toy
## width, WorldScale.opening; scripts/endless/bridge_build.gd lays it):
##   bridge          whole, a single arcade on piers grown down to the floor.
##   bridge_tier     whole, a two-tier arcade (the kit's `two_tier`), where
##                   the deck stands more than TIER_DROP over the floor.
##   bridge_broken   single, broken in the middle: each half a run out from
##                   its rim ending snapped off, the spans between fallen, a
##                   gap of at least TOY_BREAK's opening to fly through.
## Some are chained: from the far rim the line goes on across that chunk's
## top to the next rim at the same deck height, up to CHAIN_LINKS spans, a
## line flown along them.
##
## On only where a profile's layers set `bridges` (the chance a bridge cell
## tries, x --bridges=; --no-bridges none): amberlands. Wilderness and the
## overgrown have none and their arches plan as before (arch_plan.gd is
## untouched). Bridges keep KEEP m clear of the arch planner's arches, slot
## halls, split mountains and tunnels, and APART m from each other.
##
## Each link is a spec as arch_plan.gd's aqueducts (kind "aqueduct", built by
## arch_build.gd and streamed by land_arches.gd in the arch cell holding its
## middle, `for_cell`), named `<region>/bridge_<bx>_<bz>_<chain>_<link>`
## (scripts/layout_overrides.gd), with `bridge`: {tier, cut, miss, wet}.

const WorldScale = preload("res://scripts/world_scale.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const ArchPlan = preload("res://scripts/endless/arch_plan.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const Road = preload("res://scripts/ruin_kit_bridge.gd")
const BridgeBuild = preload("res://scripts/endless/bridge_build.gd")

## The bridge cell (m), the rim search's grid (m), the rims tried a cell (x
## the layer), the most bridges (a chain counts once) a cell.
const CELL := 960.0
const GRID := 40.0
const TRIES := 14
const MOST := 2
## A rim: its four GRID neighbours within FLAT m of it, and the ground
## falling at least DROP*RIM_FALL within two GRID steps of it.
const FLAT := 4.0
const RIM_FALL := 0.7
## The walk: ways tried, its step (m), how far across a top to its edge (m),
## the fall that makes the edge (m).
const DIRS := 16
const STEP := 8.0
const TOP_MOST := 220.0
const EDGE := 3.0
## The gap: the least and most the ground falls under the deck (m), how near the far
## rim's top stands to the near one's (m), the gap's least and most (m,
## edge to edge).
const DROP := 25.0
const DROP_MOST := 100.0
const MATCH := 6.0
const GAP := Vector2(70.0,460.0)
## Past this drop (deck over the floor's lowest, m) a whole bridge is
## two-tier.
const TIER_DROP := 40.0
## Toy widths of the openings under the arcades: the single arcade's and
## the two-tier's lower one (the kit's CLEAR is 4.7). The deck's share of
## the drop the arches grow to (as arch_plan's spans), and the most they
## grow.
const TOY_ARCADE := [5.5,6.5,8.0]
const TOY_TIER := [4.7,5.5,6.5]
const DECK_SHARE := 0.62
const GROW_MOST := 3.6
## How far the run reaches past where each rim's ground meets the deck (in
## spans), and how far under the deck the ground counts as met (m).
const INTO := 0.6
const MEET := 1.0
## The chance a bridge is broken in the middle (single-tier: the kit has no
## snapped two-tier span), the most drop it is tried on (m: its piers grow
## down past TIER_DROP), and the toy width of the gap left between the
## snapped ends.
const BROKEN := 0.5
const BROKEN_DROP := 66.0
const TOY_BREAK := 10.0
## Chains: the chance a bridge goes on to the next rim, the most links, the
## most the line turns at a rim (rad), how far it crosses a chunk's top
## between links (m) and the most the whole line reaches from its first rim.
const CHAIN := 0.6
const CHAIN_LINKS := 4
const CHAIN_TURN := 0.5
const CHAIN_TOP := 420.0
const CHAIN_REACH := 1700.0
## A chain's runs end within this past CHAIN_REACH of its first rim (each
## far rim's top is within CHAIN_REACH; a run reaches at most its approach,
## INTO a grown span and the rounding to whole spans past it, under 70 m).
const REACH_PAD := 100.0
## Clearances (m): from arches' feet, halls, splits and tunnels; between
## bridges.
const KEEP := 50.0
const APART := 160.0
## How far out of a tunnel's mouth its way is kept clear (m).
const TUNNEL_WAY := 300.0
## The chance a bridge cell tries at all, at layer 1.
const TAKE := 0.85
## The road form (scripts/ruin_kit_bridge.gd), the second a chain may take
## (picked per chain on its own stream, so the aqueduct chains are as they
## were): its share of the chains (x --bridge-road=, 0 none, 1 all), the
## chance one is broken, and its weathering.
const ROAD := 0.5
const ROAD_BROKEN := 0.45
const ROAD_WEATHERED := Vector2(0.4,0.8)

## What the planner tried and turned down (for a census; not thread-exact).
static var stats := {}
static var _cache := {}
static var _kept := {}
static var _lock := Mutex.new()
## Bridge cells being planned now, by key: each a Mutex its planner holds,
## so a second thread asking for the same cell waits for it rather than
## planning it again (_plan reads no other cell's plan: no cycle).
static var _pending := {}
## The caches hold this many cells; past it the oldest half goes.
const CACHE_MOST := 4000
## A chain matters to an arch cell when its links' box comes within this of
## the cell (its arches' feet reach out of it; KEEP and a deck's half).
const NEAR_CELL := 400.0

## The flags: --bridges=X (x the layer), --no-bridges.
static var _flag := -1.0
static func flag() -> float:
	if _flag < 0.0:
		var k := 1.0
		for a: String in preload("res://scripts/launch_args.gd").user_args():
			if a == "--no-bridges": k = 0.0
			elif a.begins_with("--bridges="): k = maxf(0.0,float(a.get_slice("=",1)))
		_flag = k
	return _flag

## The road form's share: --bridge-road=X (0..1), else ROAD.
static var _road := -1.0
static func road_share() -> float:
	if _road < 0.0:
		var k := ROAD
		for a: String in preload("res://scripts/launch_args.gd").user_args():
			if a.begins_with("--bridge-road="): k = clampf(float(a.get_slice("=",1)),0.0,1.0)
		_road = k
	return _road

static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/CELL),floori(z/CELL))

## Arch cell (cx, cz)'s arches `arches` (ArchPlan.plan) less those a
## bridge passes within KEEP of (the bridges win: they are planned from the
## land alone), and the bridge links whose middle stands in it. A world with
## no bridges gets `arches` back as they are.
static func with_arches(field: RefCounted, cx: int, cz: int, arches: Array, density := 1.0, rock := 1.0, ruin := 1.0) -> Array:
	if not on(field): return arches
	var near: Array = []
	var x0 := cx*ArchPlan.CELL
	var z0 := cz*ArchPlan.CELL
	var r := CHAIN_REACH+REACH_PAD
	var lo := cell_of(x0-r,z0-r)
	var hi := cell_of(x0+ArchPlan.CELL+r,z0+ArchPlan.CELL+r)
	var box := Rect2(x0-NEAR_CELL,z0-NEAR_CELL,ArchPlan.CELL+NEAR_CELL*2.0,ArchPlan.CELL+NEAR_CELL*2.0)
	# Cells another thread is planning now are left for a second pass, so
	# threads streaming neighbouring arch cells plan different cells at once
	# rather than queueing on the same one.
	var cells: Array = []
	for bz in range(lo.y,hi.y+1):
		for bx in range(lo.x,hi.x+1): cells.append(Vector2i(bx,bz))
	var got := {}
	for wait: bool in [false,true]:
		for c: Vector2i in cells:
			if got.has(c): continue
			var mine: Variant = raw(field,c.x,c.y,density,rock,ruin,wait)
			if mine == null: continue
			# Only a cell with a chain near this one pays for `kept` (which
			# reads the cells round it): the rest cannot touch it.
			var links: Array = []
			for chain: Dictionary in mine:
				if not _chain_in(chain,box): continue
				for k: Dictionary in kept(field,c.x,c.y,density,rock,ruin):
					if _chain_in(k,box): links.append_array(k.links)
				break
			got[c] = links
	for c: Vector2i in cells: near.append_array(got[c])
	var out: Array = []
	for a: Dictionary in arches:
		if not _off_bridges(a,near): continue
		out.append(a)
	for spec: Dictionary in near:
		var p: Vector3 = spec.pos
		if ArchPlan.cell_of(p.x,p.z) == Vector2i(cx,cz): out.append(spec)
	return out

## The bridge links whose middle stands in arch cell (cx, cz).
static func for_cell(field: RefCounted, cx: int, cz: int, density := 1.0, rock := 1.0, ruin := 1.0) -> Array:
	var out: Array = []
	for s: Dictionary in with_arches(field,cx,cz,[],density,rock,ruin):
		if s.has("bridge"): out.append(s)
	return out

## Whether a chain's segments' box overlaps `box`.
static func _chain_in(chain: Dictionary, box: Rect2) -> bool:
	for sg: Array in chain.segs:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		if Rect2(a.min(b),(a-b).abs()).grow(1.0).intersects(box): return true
	return false

## Whether an arch's feet keep KEEP clear of every bridge in `links`.
static func _off_bridges(arch: Dictionary, links: Array) -> bool:
	for l: Dictionary in links:
		var e := _ends(l)
		var half := float(((l.foot[0] as Array)[1] as Vector2).y)
		for foot: Array in arch.get("foot",[]):
			var fc: Vector2 = foot[0]
			var fe: Vector2 = foot[1]
			var fd := Vector2(cos(float(foot[2])),-sin(float(foot[2])))
			if _seg_seg(e[0],e[1],fc-fd*fe.x,fc+fd*fe.x) < KEEP+half+fe.y: return false
	return true

## Whether `field`'s world may take bridges (a uniform world: its layer).
static func on(field: RefCounted) -> bool:
	if flag() <= 0.0: return false
	var world: Variant = field.get("world")
	if world == null: return false
	if bool(world.uniform): return float(world.layers.get("bridges",0.0)) > 0.0
	return true

static func _layer(field: RefCounted, x: float, z: float) -> float:
	var world: Variant = field.get("world")
	if world == null: return 0.0
	return float(world.at(x,z).layers.get("bridges",0.0))*flag()

static func _region_id(field: RefCounted, x: float, z: float) -> String:
	var world: Variant = field.get("world")
	return String(world.at(x,z).id) if world != null else "endless"

## The chains bridge cell (bx, bz) keeps: its own, less those that come
## within APART of a better-ranked chain of a cell round it.
static func kept(field: RefCounted, bx: int, bz: int, density := 1.0, rock := 1.0, ruin := 1.0) -> Array:
	var mine: Array = raw(field,bx,bz,density,rock,ruin)
	if mine.is_empty(): return mine
	var key := _key(field,bx,bz,density,rock,ruin)
	_lock.lock()
	var got: Variant = _kept.get(key)
	_lock.unlock()
	if got != null: return got
	var out := _kept_of(field,bx,bz,mine,density,rock,ruin)
	_lock.lock()
	_store(_kept,key,out)
	_lock.unlock()
	return out

static func _kept_of(field: RefCounted, bx: int, bz: int, mine: Array, density: float, rock: float, ruin: float) -> Array:
	var reach := int(ceil((CHAIN_REACH+REACH_PAD+APART)*2.0/CELL))
	var out: Array = []
	for chain: Dictionary in mine:
		var links: Array = chain.links
		var ok: Array = []
		ok.resize(links.size())
		ok.fill(true)
		for dz in range(-reach,reach+1):
			for dx in range(-reach,reach+1):
				if dx == 0 and dz == 0: continue
				if not _boxes_near(chain,bx+dx,bz+dz): continue
				for other: Dictionary in raw(field,bx+dx,bz+dz,density,rock,ruin):
					if int(other.rank) <= int(chain.rank): continue
					for i in range(links.size()):
						if ok[i] and _near_segs(chain.segs[i],other.segs,APART): ok[i] = false
		# The longest unbroken run of its links that stand clear.
		var run := _longest(links,ok)
		if run.is_empty(): continue
		out.append({"rank":chain.rank,"links":run,"segs":run.map(func(l: Dictionary) -> Array: return _ends(l))})
	return out

## The longest run of `items` whose `ok` are all true (the first of equals).
static func _longest(items: Array, ok: Array) -> Array:
	var best: Array = []
	var now: Array = []
	for i in range(items.size()):
		if ok[i]: now.append(items[i])
		else: now = []
		if now.size() > best.size(): best = now.duplicate()
	return best

static func _near_segs(s: Array, segs: Array, d: float) -> bool:
	for t: Array in segs:
		if _seg_seg(s[0],s[1],t[0],t[1]) < d: return true
	return false

## Whether a chain could reach any chain of bridge cell (bx, bz) (whose own
## reach out of its cell is at most CHAIN_REACH+REACH_PAD).
static func _boxes_near(chain: Dictionary, bx: int, bz: int) -> bool:
	var r := CHAIN_REACH+REACH_PAD+APART
	var lo := Vector2(bx*CELL-r,bz*CELL-r)
	var hi := Vector2((bx+1)*CELL+r,(bz+1)*CELL+r)
	for s: Array in chain.segs:
		for p: Vector2 in s:
			if p.x > lo.x and p.y > lo.y and p.x < hi.x and p.y < hi.y: return true
	return false

static func _chains_near(a: Dictionary, b: Dictionary, d: float) -> bool:
	for s: Array in a.segs:
		for t: Array in b.segs:
			if _seg_seg(s[0],s[1],t[0],t[1]) < d: return true
	return false

## Bridge cell (bx, bz)'s chains, each {rank, segs: [[a, b] XZ], links:
## [spec...]}, cached (a pure function of the seed and the cell).
## `wait` false: null at once if another thread is planning it now.
static func raw(field: RefCounted, bx: int, bz: int, density := 1.0, rock := 1.0, ruin := 1.0, wait := true) -> Variant:
	var key := _key(field,bx,bz,density,rock,ruin)
	_lock.lock()
	var got: Variant = _cache.get(key)
	if got != null:
		_lock.unlock()
		return got
	var busy: Mutex = _pending.get(key)
	if busy != null:
		_lock.unlock()
		if not wait: return null
		# Another thread plans it: wait for it, then read its plan.
		busy.lock()
		busy.unlock()
		_lock.lock()
		got = _cache.get(key)
		_lock.unlock()
		if got != null: return got
		return raw(field,bx,bz,density,rock,ruin)
	var mine := Mutex.new()
	mine.lock()
	_pending[key] = mine
	_lock.unlock()
	var t0 := Time.get_ticks_usec()
	var made := _plan(field,bx,bz)
	var ms := (Time.get_ticks_usec()-t0)/1000.0
	_lock.lock()
	_count("raw_cells")
	stats["raw_ms"] = float(stats.get("raw_ms",0.0))+ms
	stats["raw_worst"] = maxf(float(stats.get("raw_worst",0.0)),ms)
	_store(_cache,key,made)
	_pending.erase(key)
	_lock.unlock()
	mine.unlock()
	return made

static func _key(field: RefCounted, bx: int, bz: int, density: float, rock: float, ruin: float) -> String:
	var world: Variant = field.get("world")
	return "%d|%d|%d|%s|%.3f|%.3f|%.3f|%.3f" % [int(field.seed),bx,bz,String(world.id) if world != null else "",density,rock,ruin,flag()]

## Into a cache (under `_lock`), the oldest half let go past CACHE_MOST.
static func _store(cache: Dictionary, key: String, value: Variant) -> void:
	if cache.size() >= CACHE_MOST:
		var keys := cache.keys()
		for i in range(keys.size()/2): cache.erase(keys[i])
	cache[key] = value

static func _plan(field: RefCounted, bx: int, bz: int) -> Array:
	var out: Array = []
	var x0 := bx*CELL
	var z0 := bz*CELL
	# The cell's take: its corners' and middle's layer (a region's border
	# may run through it; each rim reads its own after).
	var most := 0.0
	for q: Vector2 in [Vector2(0.5,0.5),Vector2(0.05,0.05),Vector2(0.95,0.05),Vector2(0.05,0.95),Vector2(0.95,0.95)]:
		most = maxf(most,_layer(field,x0+q.x*CELL,z0+q.y*CELL))
	if most <= 0.0: return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),bx,bz,"endless bridges"])
	if rng.randf() >= TAKE*minf(most,1.0): return out
	var n := int(CELL/GRID)
	var pad := 2
	var w := n+pad*2
	var g: Dictionary = field.grid(x0+GRID*0.5,z0+GRID*0.5,GRID,w,w,pad)
	var hs: PackedFloat32Array = g.heights
	var rims: Array = []
	for j in n:
		for i in n:
			var k := (j+pad)*w+i+pad
			var h := hs[k]
			if h < Field.SEA_Y+10.0: continue
			if absf(hs[k-1]-h) > FLAT or absf(hs[k+1]-h) > FLAT or absf(hs[k-w]-h) > FLAT or absf(hs[k+w]-h) > FLAT: continue
			var low := h
			for dj in range(-2,3):
				for di in range(-2,3): low = minf(low,hs[k+dj*w+di])
			if h-low < DROP*RIM_FALL: continue
			rims.append(Vector3(x0+GRID*(i+0.5),h,z0+GRID*(j+0.5)))
	_count("cells")
	_count("rims",rims.size())
	if rims.is_empty(): return out
	# Shuffled by the cell's rng (a pure function of the seed).
	for i in range(rims.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var t: Vector3 = rims[i]
		rims[i] = rims[j]
		rims[j] = t
	var tries := int(round(TRIES*minf(most,1.5)))
	for t in range(mini(tries,rims.size())):
		if out.size() >= MOST: break
		var rim: Vector3 = rims[t]
		var a := Vector2(rim.x,rim.z)
		if _layer(field,a.x,a.y) <= 0.0: continue
		var near := false
		for c: Dictionary in out:
			for s: Array in c.segs:
				if _seg_point(s[0],s[1],a) < APART: near = true
		if near: continue
		var start := rng.randf()*TAU
		var dirs: Array = []
		for k in DIRS: dirs.append(Vector2.from_angle(start+TAU*k/DIRS))
		_count("tried")
		var cands := _links(field,a,rim.y,dirs,false)
		if cands.is_empty(): continue
		_count("links")
		var sub := RandomNumberGenerator.new()
		sub.seed = rng.randi()
		var chain := {"rank":hash([int(field.seed),bx,bz,t,"bridge rank"]),"segs":[],"links":[]}
		var links: Array = [cands[0]]
		# A chain: of the best few ways across, the one that goes on the
		# furthest, rim to rim, both ways along its line.
		if sub.randf() < CHAIN:
			for c: Dictionary in cands.slice(0,4):
				var line := _chain(field,a,rim.y,c)
				if line.size() > links.size(): links = line
		var specs: Array = []
		var ok: Array = []
		# The chain's form, on its own stream (the aqueduct's draws untouched).
		var style := RandomNumberGenerator.new()
		style.seed = hash([int(field.seed),bx,bz,t,"bridge style"])
		var road := style.randf() < road_share()
		for li in range(links.size()):
			var l: Dictionary = links[li]
			var spec := _road_spec(l,style) if road else _spec(field,l,sub)
			var stands := not spec.is_empty()
			if not stands: _count("too_long")
			# The far rim is in a region that takes bridges too.
			elif _layer(field,(l.far_top as Vector2).x,(l.far_top as Vector2).y) <= 0.0: stands = false
			elif not _clear(field,spec,out):
				_count("not_clear")
				stands = false
			elif road and BridgeBuild.road_through(spec,field):
				_count("road_through")
				stands = false
			if stands:
				spec["name"] = "%s/bridge_%d_%d_%d_%d" % [_region_id(field,a.x,a.y),bx,bz,out.size(),li]
				spec["chain"] = "%d_%d_%d" % [bx,bz,out.size()]
				spec["link"] = li
			specs.append(spec)
			ok.append(stands)
		# The chain keeps its longest unbroken run of links that stand.
		specs = _longest(specs,ok)
		if specs.is_empty(): continue
		chain["links"] = specs
		# A longer chain outranks a shorter (a line is rarer than a span).
		chain["rank"] = specs.size()*(1 << 32)+int(chain.rank)
		chain["segs"] = specs.map(func(l: Dictionary) -> Array: return _ends(l))
		out.append(chain)
	return out

static func _count(k: String, by := 1) -> void:
	stats[k] = int(stats.get(k,0))+by

## A gap from the rim at `a` (height `y`) out one of `dirs` to a far rim:
## {a, dir, edge, far, ta, tb (where each rim's ground meets the deck, m
## from a), deck, low (the floor's lowest), far_top (a point on the far
## rim's top), score}; every way that crosses one, best first. `level`: a chain's next
## link, crossing up to CHAIN_TOP of its chunk's top, the nearer `dirs[0]`
## (the line's way) the better.
## The line through link `first` (out of the rim at `a`, height `y`): on
## from its far rim, and back from `a` the other way, a link at a time
## within CHAIN_TURN of the line's way, up to CHAIN_LINKS in all and
## CHAIN_REACH from `a`; in order along it.
static func _chain(field: RefCounted, a: Vector2, y: float, first: Dictionary) -> Array:
	var ahead: Array = [first]
	var behind: Array = []
	for back: bool in [false,true]:
		var dir: Vector2 = -(first.dir as Vector2) if back else first.dir
		var from: Vector2 = a if back else first.far_top
		var from_y := y if back else float(field.height(from.x,from.y))
		while ahead.size()+behind.size() < CHAIN_LINKS:
			if from.distance_to(a) > CHAIN_REACH: break
			var ways: Array = []
			for k: float in [0.0,-0.5,0.5,-1.0,1.0]: ways.append(dir.rotated(k*CHAIN_TURN))
			_count("chain_tries")
			var got := _links(field,from,from_y,ways,true)
			if got.is_empty(): break
			var next: Dictionary = got[0]
			var to: Vector2 = next.far_top
			if to.distance_to(a) > CHAIN_REACH or _layer(field,to.x,to.y) <= 0.0: break
			_count("chain_links")
			if back: behind.push_front(next)
			else: ahead.append(next)
			dir = next.dir
			from = to
			from_y = float(field.height(from.x,from.y))
	return behind+ahead

## A way's walk out of the rim at `a` (height `y`) along `dir`, as one read
## every STEP would: across the top (up to `top_most`) to its edge (the first
## read under y-EDGE), then on to where the ground climbs back to y-MATCH,
## reading the floor's lowest. Read every second STEP, the step before a
## change read too, and the floor's skipped reads filled in once a far rim
## is met (only a spike or notch under 2 STEP wide reads otherwise).
## Early outs: a floor under the sea's margin, or deeper than any deck (at
## least y-MATCH-2) could take. Vector3(edge, far, low); edge -1 no edge,
## far -1 no far rim.
static func _walk(field: RefCounted, a: Vector2, dir: Vector2, y: float, top_most: float) -> Vector3:
	var h := func(d: float) -> float: return float(field.height(a.x+dir.x*d,a.y+dir.y*d))
	var edge := -1.0
	var d := STEP*2.0
	while d <= top_most:
		if float(h.call(d)) < y-EDGE:
			edge = d-STEP if float(h.call(d-STEP)) < y-EDGE else d
			break
		d += STEP*2.0
	if edge < 0.0 and d-STEP <= top_most and float(h.call(d-STEP)) < y-EDGE: edge = d-STEP
	if edge < 0.0: return Vector3(-1.0,-1.0,INF)
	var low := INF
	var deepest := y-MATCH-2.0-DROP_MOST
	var stop := -1.0
	d = edge
	var last := edge+GAP.y
	while d <= last:
		var hd := float(h.call(d))
		if hd >= y-MATCH:
			stop = d
			if d > edge:
				var hb := float(h.call(d-STEP))
				if hb >= y-MATCH: stop = d-STEP
				else: low = minf(low,hb)
			if stop == d: low = minf(low,hd)
			break
		low = minf(low,hd)
		if low < Field.SEA_Y+2.0 or low < deepest: return Vector3(edge,-1.0,low)
		var next := d+STEP*2.0
		if next > last and d+STEP <= last:
			# The tail read the fine walk would make.
			var ht := float(h.call(d+STEP))
			if ht >= y-MATCH:
				stop = d+STEP
				low = minf(low,ht)
				break
			low = minf(low,ht)
		d = next
	if stop < 0.0: return Vector3(edge,-1.0,low)
	# The floor's reads skipped (odd STEPs short of the one before the stop).
	var k := edge+STEP
	while k < stop-STEP-0.01:
		low = minf(low,float(h.call(k)))
		k += STEP*2.0
	if stop == edge: low = minf(low,float(h.call(edge)))
	return Vector3(edge,stop if y-low >= DROP else -1.0,low)

## The best of `_links`, or {}.
static func _link(field: RefCounted, a: Vector2, y: float, dirs: Array, level: bool) -> Dictionary:
	var all := _links(field,a,y,dirs,level)
	return all[0] if not all.is_empty() else {}

static func _links(field: RefCounted, a: Vector2, y: float, dirs: Array, level: bool) -> Array:
	var found: Array = []
	var top_most := CHAIN_TOP if level else TOP_MOST
	for dir: Vector2 in dirs:
		# Across the top to its edge, then the gap: `_walk`, every STEP read
		# at half the cost.
		var got := _walk(field,a,dir,y,top_most)
		if got.x < 0.0: continue
		var edge := got.x
		var far := got.y
		var low := got.z
		if far < 0.0 or far-edge < GAP.x: continue
		if low < Field.SEA_Y+2.0: continue
		# The far rim's top: near the rim's height, not a wall or a fin.
		var f1 := a+dir*(far+16.0)
		var f2 := a+dir*(far+40.0)
		var h1 := float(field.height(f1.x,f1.y))
		var h2 := float(field.height(f2.x,f2.y))
		if h1 < y-MATCH or h2 < y-MATCH-2.0 or h1 > y+MATCH*2.5: continue
		var top := maxf(float(field.height(a.x+dir.x*far,a.y+dir.y*far)),minf(h1,h2))
		var deck := minf(y,top)
		# Where each rim's ground meets the deck.
		var ta := maxf(edge-STEP,0.0)
		while ta < far and float(field.height(a.x+dir.x*(ta+3.0),a.y+dir.y*(ta+3.0))) >= deck-MEET: ta += 3.0
		var tb := far
		while tb > ta and float(field.height(a.x+dir.x*(tb-3.0),a.y+dir.y*(tb-3.0))) >= deck-MEET: tb -= 3.0
		if tb-ta < GAP.x*0.8: continue
		var drop := deck-low
		if drop < DROP or drop > DROP_MOST: continue
		# The longer and deeper the better; a chain keeps nearest its way.
		var score := minf(tb-ta,320.0)+drop*1.5-(absf(dir.angle_to(dirs[0]))*60.0 if level else 0.0)
		found.append({"a":a,"dir":dir,"edge":edge,"far":far,"ta":ta,"tb":tb,"deck":deck,"low":low,"far_top":a+dir*(far+16.0),"score":score})
	found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.score) > float(q.score))
	return found

## The run that spans link `l`: its form, the grow its openings take, its
## spans and its place.
static func _spec(_field: RefCounted, l: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var deck := float(l.deck)
	var drop := deck-float(l.low)
	var broken := drop < BROKEN_DROP and rng.randf() < BROKEN
	var tier := drop > TIER_DROP and not broken
	var toy: float = (TOY_TIER if tier else TOY_ARCADE)[rng.randi()%3]
	var deck_h: float = Aqueduct.DECK_HIGH if tier else Aqueduct.DECK
	var least := WorldScale.opening(toy)/Aqueduct.CLEAR
	var grow := clampf(maxf(least,drop*DECK_SHARE/deck_h),1.0,maxf(GROW_MOST,least))
	var span: float = Aqueduct.SPAN*grow
	var gap := float(l.tb)-float(l.ta)
	var count := maxi(ceili(gap/span+INTO*2.0),3)
	var a: Vector2 = l.a
	var dir: Vector2 = l.dir
	var mid := (float(l.ta)+float(l.tb))*0.5
	var c := a+dir*mid
	var cut := -1
	var miss := 0
	if broken:
		# Its middle fallen: the A half `cut` spans (its last snapped), `miss`
		# spans gone, the B half the rest (its last snapped). The gap between
		# the snapped ends is about (miss+2) spans less their stubs.
		var want := WorldScale.opening(TOY_BREAK)
		while (miss+2)*span-3.2*grow < want: miss += 1
		if count < miss+4: count = miss+4
		cut = (count-miss)/2
	var length := span*count
	# The half length stays inside an arch cell's reach (land_arches looks
	# one cell round).
	if length*0.5 > ArchPlan.CELL*0.9: return {}
	var spec := {"kind":"aqueduct","form":"bridge_tier" if tier else ("bridge_broken" if broken else "bridge"),
		"grow":grow,"count":count,"head":false,"break_at":-1,"weathered":rng.randf_range(0.3,0.7),
		"yaw":ArchPlan._yaw(dir),"length":length,"deck":deck,"drop":drop,"toy":toy,
		"bridge":{"tier":tier,"cut":cut,"miss":miss,"wet":rng.randf() < 0.35}}
	spec["pos"] = Vector3(c.x,deck-deck_h*grow-0.4,c.y)
	spec["foot"] = [[c,Vector2(length*0.5+6.0*grow,3.0*grow+4.0),float(spec.yaw)]]
	spec["seed"] = rng.randi()
	return spec

## A road bridge's run (scripts/ruin_kit_bridge.gd) spanning link `l`:
## built at grow 1 (its own sizes, metres), its road's top at the deck, the
## run reaching Road.APPROACH onto each rim past where the ground meets the
## deck, in whole Aqueduct.SPAN modules (arch_build.gd middles a run by its
## count). `bridge`: {style "road", gap, broken; tier, cut, miss, wet as the
## aqueduct's, unused}.
static func _road_spec(l: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var deck := float(l.deck)
	var drop := deck-float(l.low)
	var broken := rng.randf() < ROAD_BROKEN
	var gap := float(l.tb)-float(l.ta)
	var span: float = Aqueduct.SPAN
	var count := ceili((gap+Road.APPROACH*2.0)/span)
	var length := span*count
	if length*0.5 > ArchPlan.CELL*0.9: return {}
	var dir: Vector2 = l.dir
	var c: Vector2 = (l.a as Vector2)+dir*(float(l.ta)+float(l.tb))*0.5
	var spec := {"kind":"aqueduct","form":"bridge_broken" if broken else "bridge","style":"road",
		"grow":1.0,"count":count,"head":false,"break_at":-1,"weathered":rng.randf_range(ROAD_WEATHERED.x,ROAD_WEATHERED.y),
		"yaw":ArchPlan._yaw(dir),"length":length,"deck":deck,"drop":drop,"toy":Road.TOY_ARCH,
		"bridge":{"style":"road","gap":gap,"broken":broken,"tier":false,"cut":0 if broken else -1,"miss":0,"wet":false}}
	spec["pos"] = Vector3(c.x,deck,c.y)
	spec["foot"] = [[c,Vector2(length*0.5+6.0,Road.WIDTH.y*0.5+12.0),float(spec.yaw)]]
	spec["seed"] = rng.randi()
	return spec

## A run's two ends (XZ).
static func _ends(spec: Dictionary) -> Array:
	var p: Vector3 = spec.pos
	var d := Vector2(cos(float(spec.yaw)),-sin(float(spec.yaw)))
	var c := Vector2(p.x,p.z)
	return [c-d*float(spec.length)*0.5,c+d*float(spec.length)*0.5]

## Whether a run keeps clear of the halls, splits and tunnels, and of this
## cell's other bridges (`chains`). (The arches keep clear of it:
## `with_arches`.)
static func _clear(field: RefCounted, spec: Dictionary, chains: Array) -> bool:
	var e := _ends(spec)
	var p0: Vector2 = e[0]
	var p1: Vector2 = e[1]
	for c: Dictionary in chains:
		for s: Array in c.segs:
			if _seg_seg(p0,p1,s[0],s[1]) < APART: return _no("by_bridge")
	var lo := p0.min(p1)-Vector2.ONE*KEEP
	var hi := p0.max(p1)+Vector2.ONE*KEEP
	# A tunnel's mouths and the ways out of them (its massif and the bore
	# under it may stand under a bridge).
	var half := float(((spec.foot[0] as Array)[1] as Vector2).y)
	if field.has_method("tunnels_in"):
		for t: RefCounted in field.tunnels_in(lo.x-TUNNEL_WAY,lo.y-TUNNEL_WAY,hi.x+TUNNEL_WAY,hi.y+TUNNEL_WAY):
			for m: Array in [[t.get("origin"),-(t.get("way") as Vector2)],[t.get("mouth_b"),t.get("out_b")]]:
				var at: Vector2 = m[0]
				var out: Vector2 = m[1]
				if _seg_seg(p0,p1,at-out*KEEP,at+out*TUNNEL_WAY) < KEEP+half: return _no("by_tunnel")
	var n := maxi(2,int(p0.distance_to(p1)/24.0))
	for i in range(n+1):
		var q := p0.lerp(p1,float(i)/n)
		if field.has_method("hall_at") and not (field.hall_at(q.x,q.y,KEEP) as PackedFloat32Array).is_empty(): return _no("by_hall")
		if field.has_method("split_at") and not (field.split_at(q.x,q.y,KEEP,0.0) as PackedFloat32Array).is_empty(): return _no("by_split")
	return true

static func _no(why: String) -> bool:
	_count(why)
	return false

static func _seg_point(a: Vector2, b: Vector2, p: Vector2) -> float:
	var ab := b-a
	var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
	return p.distance_to(a+ab*t)

static func _seg_seg(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	var r := b-a
	var s := d-c
	var den := r.cross(s)
	if absf(den) > 0.0001:
		var t := (c-a).cross(s)/den
		var u := (c-a).cross(r)/den
		if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0: return 0.0
	return minf(minf(_seg_point(a,b,c),_seg_point(a,b,d)),minf(_seg_point(c,d,a),_seg_point(c,d,b)))
