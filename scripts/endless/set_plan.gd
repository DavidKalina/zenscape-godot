extends RefCounted
## The amberlands' standalone set pieces (docs/design/endless-flight/
## spec-amber-r2.md, trunk 1): the gothic nave, the belfry tower and the
## rose gate (scripts/ruin_kit_gothic.gd) stood on the land. A pure function
## of the seed and a set cell (CELL m, its own grid), read from the land's
## heights alone.
##
## A set cell takes at most one piece, its middle at least MARGIN inside the
## cell, so two pieces stand at least 2*MARGIN apart and a region is never
## crowded. Of TRIES spots in the cell, a piece stands where:
##   - the ground under its footprint is flat within its SPREAD (a terrace's
##     tread, a shelf, a massif's foot);
##   - the ground beside it rises at least RISE within BACK one way (a
##     massif's flank, a mesa's wall or a terrace's riser behind it), so it
##     stands against the high ground and reads from it;
##   - its long way (the piece's z: the nave's length, the belfry's and the
##     gate's way through) runs along that rise, the way the land flows
##     along a shelf, and the ground stays within CLIMB of its foot LANE m
##     out either way, so its openings are flown into with the land's flow;
##   - it keeps KEEP m clear of the slot halls, split mountains, tunnels'
##     mouths (and TUNNEL_WAY out of them) and the bridges
##     (scripts/endless/bridge_plan.gd). The arch planner's arches near it
##     give way (`with_arches`), as they do to the bridges.
## Of the spots that pass, the one with the tallest backdrop for its
## flatness.
##
## On only where a profile's layers set `sets` (the chance a set cell takes
## a piece, x --sets=; --no-sets none): amberlands. Wilderness and the
## overgrown have none and plan as before.
##
## Each piece is a spec built by arch_build.gd and streamed by
## land_arches.gd in the arch cell holding its middle, as the bridges are:
## {kind (the piece id), set: true, pos (its foot), yaw (its z along the
## rise), seed, weathered, grow 1, foot, reach}, named
## `<region>/<piece id>_<sx>_<sz>` (scripts/layout_overrides.gd).

const ArchPlan = preload("res://scripts/endless/arch_plan.gd")
const Bridges = preload("res://scripts/endless/bridge_plan.gd")
const Field = preload("res://scripts/endless/land_field.gd")

## The set cell (m), how far inside it a piece's middle keeps (m), the
## chance a cell takes one at layer 1, the spots tried.
const CELL := 1000.0
const MARGIN := 200.0
const TAKE := 0.8
const TRIES := 56
## The pieces: their chance, footprint (half across x, half along z: m,
## the built bounds and their drifts) and the most the ground under it may
## vary (m).
const PIECES := {
	"gothic_nave":{"w":0.5,"half":Vector2(30.5,60.0),"spread":6.0},
	"belfry_tower":{"w":0.3,"half":Vector2(17.0,15.0),"spread":4.0},
	"rose_gate":{"w":0.2,"half":Vector2(17.0,8.0),"spread":3.5},
}
## The colosseum (scripts/ruin_kit_colosseum.gd), rarer, apart from the
## pieces' roll: its chance a set cell (its own draw, so a cell it skips
## plans as before), footprint (the podium's steps and the rubble past the
## broken side) and spread. It wants a broad flat terrace, no rise: its foot
## at the highest ground under its core (its footings reach FOUND 16 m down),
## the ground within SPREAD under it, and a STRIP m landable run kept past
## its footprint (the land's flats rule, land_ponds.gd `_strip`). Flat
## terraces that broad are rare, so every set cell tries for one and the
## ground may fall the footings' full depth under it: some 14 stand within
## 12 km of the start in the regions world, seed 1 (0.22 and 12 m stood none).
const COLOSSEUM := {"w":1.0,"half":Vector2(236.0,208.0),"spread":16.0}
const STRIP := 208.0
## The backdrop: the rise beside the spot (m) and the distances it is read
## at (m), out of DIRS ways.
const RISE := 22.0
const BACK := [80.0,130.0,190.0]
const DIRS := 16
## The lane along its z, either way: the distances read (m, past the
## footprint's end) and how much the ground may climb over its foot (m, and
## CLIMB_OUT a metre further out: a dive in from rising ground).
## The side away from the rise stays open: OPEN m out, within CLIMB*2.
const LANE := [30.0,90.0,160.0,240.0]
const CLIMB := 7.0
const CLIMB_OUT := 0.04
const OPEN := 120.0
## Clearances (m).
const KEEP := 60.0
const TUNNEL_WAY := 300.0
## The least foot over the sea (m).
const DRY := 6.0

static var stats := {}
static var _cache := {}
static var _lock := Mutex.new()

## The flags: --sets=X (x the layer), --no-sets.
## --sets=colosseum: every set cell that can tries the colosseum first.
static var _flag := -1.0
static var _force := ""
static func flag() -> float:
	if _flag < 0.0:
		var k := 1.0
		for a: String in preload("res://scripts/launch_args.gd").user_args():
			if a == "--no-sets": k = 0.0
			elif a.begins_with("--sets="):
				var v := a.get_slice("=",1)
				if v.is_valid_float(): k = maxf(0.0,float(v))
				else: _force = v
		_flag = k
	return _flag

## The colosseum's chance a set cell and its spread (COLOSSEUM.w, .spread),
## --colosseum-chance=P and --colosseum-spread=M over them.
static var _col := Vector2(-1.0,-1.0)
static func _col_knobs() -> Vector2:
	if _col.x < 0.0:
		_col = Vector2(float(COLOSSEUM.w),float(COLOSSEUM.spread))
		for a: String in preload("res://scripts/launch_args.gd").user_args():
			if a.begins_with("--colosseum-chance="): _col.x = maxf(0.0,a.get_slice("=",1).to_float())
			elif a.begins_with("--colosseum-spread="): _col.y = maxf(0.0,a.get_slice("=",1).to_float())
	return _col

static func _info(id: String) -> Dictionary:
	return COLOSSEUM if id == "colosseum" else PIECES[id]

static func cell_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/CELL),floori(z/CELL))

## Whether `field`'s world may take set pieces (a uniform world: its layer).
static func on(field: RefCounted) -> bool:
	if flag() <= 0.0: return false
	var world: Variant = field.get("world")
	if world == null: return false
	if bool(world.uniform): return float(world.layers.get("sets",0.0)) > 0.0
	return true

static func _layer(field: RefCounted, x: float, z: float) -> float:
	var world: Variant = field.get("world")
	if world == null: return 0.0
	return float(world.at(x,z).layers.get("sets",0.0))*flag()

static func _region_id(field: RefCounted, x: float, z: float) -> String:
	var world: Variant = field.get("world")
	return String(world.at(x,z).id) if world != null else "endless"

## Arch cell (cx, cz)'s specs `specs` (its arches and bridges) less the
## arches whose feet come within KEEP of a set piece, and the pieces whose
## middle stands in it. A world with no sets gets `specs` back as they are.
static func with_arches(field: RefCounted, cx: int, cz: int, specs: Array, density := 1.0, rock := 1.0, ruin := 1.0) -> Array:
	if not on(field): return specs
	var x0 := cx*ArchPlan.CELL
	var z0 := cz*ArchPlan.CELL
	var near := pieces_in(field,x0-KEEP*3.0-ArchPlan.CELL,z0-KEEP*3.0-ArchPlan.CELL,
		x0+ArchPlan.CELL*2.0+KEEP*3.0,z0+ArchPlan.CELL*2.0+KEEP*3.0,density,rock,ruin)
	if near.is_empty(): return specs
	var out: Array = []
	for a: Dictionary in specs:
		if a.has("bridge") or _off_pieces(a,near): out.append(a)
	for p: Dictionary in near:
		var at: Vector3 = p.pos
		if ArchPlan.cell_of(at.x,at.z) == Vector2i(cx,cz): out.append(p)
	return out

## The pieces whose middle stands within the box (x0, z0)-(x1, z1).
static func pieces_in(field: RefCounted, x0: float, z0: float, x1: float, z1: float, density := 1.0, rock := 1.0, ruin := 1.0) -> Array:
	var out: Array = []
	if not on(field): return out
	var lo := cell_of(x0,z0)
	var hi := cell_of(x1,z1)
	for sz in range(lo.y,hi.y+1):
		for sx in range(lo.x,hi.x+1):
			for p: Dictionary in plan(field,sx,sz,density,rock,ruin):
				var at: Vector3 = p.pos
				if at.x >= x0 and at.x <= x1 and at.z >= z0 and at.z <= z1: out.append(p)
	return out

## Whether an arch's feet keep KEEP clear of every piece in `pieces`.
static func _off_pieces(arch: Dictionary, pieces: Array) -> bool:
	for p: Dictionary in pieces:
		var at: Vector3 = p.pos
		var c := Vector2(at.x,at.z)
		var r := float(p.reach)+KEEP
		var apos: Vector3 = arch.pos
		if c.distance_to(Vector2(apos.x,apos.z)) < r+float(arch.get("w",20.0))*0.5: return false
		for foot: Array in arch.get("foot",[]):
			var fc: Vector2 = foot[0]
			var fe: Vector2 = foot[1]
			var fd := Vector2(cos(float(foot[2])),-sin(float(foot[2])))
			if Bridges._seg_point(fc-fd*fe.x,fc+fd*fe.x,c) < r+fe.y: return false
	return true

## Set cell (sx, sz)'s pieces (none or one), cached (a pure function of the
## seed and the cell).
static func plan(field: RefCounted, sx: int, sz: int, density := 1.0, rock := 1.0, ruin := 1.0) -> Array:
	var world: Variant = field.get("world")
	var key := "%d|%d|%d|%s|%.3f|%.3f|%.3f|%.3f|%s" % [int(field.seed),sx,sz,String(world.id) if world != null else "",density,rock,ruin,flag(),_force]
	_lock.lock()
	var got: Variant = _cache.get(key)
	_lock.unlock()
	if got != null: return got
	var t0 := Time.get_ticks_usec()
	var made := _plan(field,sx,sz,density,rock,ruin)
	_count("plan_us",Time.get_ticks_usec()-t0)
	_lock.lock()
	if _cache.size() > 600: _cache.clear()
	_cache[key] = made
	_lock.unlock()
	return made

static func _plan(field: RefCounted, sx: int, sz: int, density: float, rock: float, ruin: float) -> Array:
	var out: Array = []
	var x0 := sx*CELL
	var z0 := sz*CELL
	var most := 0.0
	for q: Vector2 in [Vector2(0.5,0.5),Vector2(0.2,0.2),Vector2(0.8,0.2),Vector2(0.2,0.8),Vector2(0.8,0.8)]:
		most = maxf(most,_layer(field,x0+q.x*CELL,z0+q.y*CELL))
	if most <= 0.0: return out
	# The colosseum first, on its own draw.
	var crng := RandomNumberGenerator.new()
	crng.seed = hash([int(field.seed),sx,sz,"endless colosseum"])
	if crng.randf() < _col_knobs().x*minf(most,1.0) or _force == "colosseum":
		var got := _colosseum(field,x0,z0,crng,density,rock,ruin)
		if not got.is_empty():
			out.append(_spec(field,"colosseum",got,sx,sz,crng))
			_count("placed_colosseum")
			return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(field.seed),sx,sz,"endless set pieces"])
	if rng.randf() >= TAKE*minf(most,1.0): return out
	_count("cells")
	# The piece the cell tries first; the others after it, if it finds no spot.
	var order: Array = []
	var roll := rng.randf()
	for id: String in PIECES:
		roll -= float(PIECES[id].w)
		if roll < 0.0 and order.is_empty(): order.append(id)
	if order.is_empty(): order.append(PIECES.keys()[0])
	for id: String in PIECES:
		if not id in order: order.append(id)
	var spots: Array = []
	for t in TRIES:
		spots.append(Vector2(x0+rng.randf_range(MARGIN,CELL-MARGIN),z0+rng.randf_range(MARGIN,CELL-MARGIN)))
	var start := rng.randf()*TAU
	for id: String in order:
		var best: Array = []
		for a: Vector2 in spots:
			var got := _spot(field,id,a,start)
			if not got.is_empty(): best.append(got)
		if best.is_empty():
			_count("no_spot_"+id)
			continue
		best.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.score) > float(q.score))
		for s: Dictionary in best.slice(0,6):
			var c0 := Time.get_ticks_usec()
			var clear := _clear(field,id,s,density,rock,ruin)
			_count("clear_us",Time.get_ticks_usec()-c0)
			if not clear: continue
			if not _flats_kept(field,id,s):
				_count("flat_taken_"+id)
				continue
			out.append(_spec(field,id,s,sx,sz,rng))
			_count("placed_"+id)
			return out
	return out

## A spot for piece `id` at `a`: {c, z (its long way, XZ), lo (its
## footprint's lowest ground), spread, rise, score}, or {}.
static func _spot(field: RefCounted, id: String, a: Vector2, start: float) -> Dictionary:
	var info: Dictionary = _info(id)
	var half: Vector2 = info.half
	var h0 := float(field.height(a.x,a.y))
	if h0 < Field.SEA_Y+DRY: return _none("wet")
	if _layer(field,a.x,a.y) <= 0.0: return _none("region")
	# The rise beside it: the way the ground climbs most within BACK.
	var rise := -INF
	var up := Vector2.ZERO
	for k in DIRS:
		var d := Vector2.from_angle(start+TAU*k/DIRS)
		var r := -INF
		for b: float in BACK: r = maxf(r,float(field.height(a.x+d.x*(b+half.x),a.y+d.y*(b+half.x)))-h0)
		if r > rise:
			rise = r
			up = d
	if rise < RISE: return _none("no_rise")
	# Away from the rise, open.
	var away := a-up*(OPEN+half.x)
	if float(field.height(away.x,away.y))-h0 > CLIMB*2.0: return _none("closed")
	# Its long way along the rise, and the lane either way along it open.
	var z := Vector2(-up.y,up.x)
	for sgn: float in [1.0,-1.0]:
		for l: float in LANE:
			var q := a+z*sgn*(half.y+l)
			if float(field.height(q.x,q.y))-h0 > CLIMB+l*CLIMB_OUT: return _none("lane")
	# The footprint flat.
	var x := Vector2(z.y,-z.x)
	var lo := INF
	var hi := -INF
	var nx := 4
	var nz := maxi(4,int(half.y/12.0))
	for j in range(-nz,nz+1):
		for i in range(-nx,nx+1):
			var q := a+x*(half.x*i/nx)+z*(half.y*j/nz)
			var h := float(field.height(q.x,q.y))
			lo = minf(lo,h)
			hi = maxf(hi,h)
			if hi-lo > float(info.spread): return _none("not_flat")
	if lo < Field.SEA_Y+DRY: return _none("wet")
	return {"c":a,"z":z,"lo":lo,"spread":hi-lo,"rise":rise,"score":minf(rise,90.0)-(hi-lo)*6.0}

## Whether a piece at spot `s` keeps clear of the halls, splits, tunnels
## and bridges.
static func _clear(field: RefCounted, id: String, s: Dictionary, density: float, rock: float, ruin: float) -> bool:
	var c: Vector2 = s.c
	var r := (_info(id).half as Vector2).length()+KEEP
	if field.has_method("hall_at") and not (field.hall_at(c.x,c.y,r) as PackedFloat32Array).is_empty(): return _no("by_hall")
	if field.has_method("split_at") and not (field.split_at(c.x,c.y,r,0.0) as PackedFloat32Array).is_empty(): return _no("by_split")
	if field.has_method("tunnels_in"):
		var w := r+TUNNEL_WAY
		for t: RefCounted in field.tunnels_in(c.x-w,c.y-w,c.x+w,c.y+w):
			for m: Array in [[t.get("origin"),-(t.get("way") as Vector2)],[t.get("mouth_b"),t.get("out_b")]]:
				var at: Vector2 = m[0]
				var way: Vector2 = m[1]
				if Bridges._seg_point(at-way*KEEP,at+way*TUNNEL_WAY,c) < r: return _no("by_tunnel")
	if Bridges.on(field):
		var reach := Bridges.CHAIN_REACH+Bridges.GAP.y+r
		var lo := Bridges.cell_of(c.x-reach,c.y-reach)
		var hi := Bridges.cell_of(c.x+reach,c.y+reach)
		for bz in range(lo.y,hi.y+1):
			for bx in range(lo.x,hi.x+1):
				# Every link the bridge cell plans (`raw`, of which `kept` keeps
				# some): its neighbours' raw plans are mostly made already by the
				# arch cells' own bridges, where `kept` would plan a wider ring.
				for chain: Dictionary in Bridges.raw(field,bx,bz,density,rock,ruin):
					for l: Dictionary in chain.links:
						var e := Bridges._ends(l)
						var half := float(((l.foot[0] as Array)[1] as Vector2).y)
						if Bridges._seg_point(e[0],e[1],c) < r+half: return _no("by_bridge")
	return true

static func _spec(field: RefCounted, id: String, s: Dictionary, sx: int, sz: int, rng: RandomNumberGenerator) -> Dictionary:
	var c: Vector2 = s.c
	var z: Vector2 = s.z
	var half: Vector2 = _info(id).half
	# Basis(UP, yaw) takes the piece's z to (sin yaw, cos yaw).
	var yaw := atan2(z.x,z.y)
	# Its foot a little over the lowest ground (its footings reach 2 m down).
	var y := float(s.lo)+minf(float(s.spread)*0.4,1.6)
	if id == "colosseum": y = float(s.top)
	return {"kind":id,"set":true,"form":id,"pos":Vector3(c.x,y,c.y),"yaw":yaw,"grow":1.0,
		"seed":rng.randi() & 0xffffff,"weathered":rng.randf_range(0.45,0.8),
		"reach":half.length(),"w":half.x*2.0,"depth":half.y*2.0,
		"foot":[[c,Vector2(half.y,half.x),yaw-PI*0.5]],"rise":float(s.rise),
		"name":"%s/%s_%d_%d" % [_region_id(field,c.x,c.y),id,sx,sz]}

## The colosseum's spot in the set cell at (x0, z0): of TRIES spots and 4
## ways each, the flattest that is dry, in the region, has a STRIP run kept
## past its footprint and keeps clear (`_clear`); {} if none.
static func _colosseum(field: RefCounted, x0: float, z0: float, rng: RandomNumberGenerator, density: float, rock: float, ruin: float) -> Dictionary:
	var half: Vector2 = COLOSSEUM.half
	var spread := _col_knobs().y
	var margin := maxf(MARGIN,half.length())
	var start := rng.randf()*TAU
	var best: Array = []
	for t in TRIES:
		var a := Vector2(x0+rng.randf_range(margin,CELL-margin),z0+rng.randf_range(margin,CELL-margin))
		if _layer(field,a.x,a.y) <= 0.0:
			_count("col_region")
			continue
		for k in 4:
			var z := Vector2.from_angle(start+PI*0.5*k)
			var x := Vector2(z.y,-z.x)
			var lo := INF
			var hi := -INF
			var top := -INF
			var ok := true
			for j in range(-6,7):
				for i in range(-6,7):
					var q := a+x*(half.x*i/6.0)+z*(half.y*j/6.0)
					var h := float(field.height(q.x,q.y))
					lo = minf(lo,h)
					hi = maxf(hi,h)
					if absi(i) <= 4 and absi(j) <= 4: top = maxf(top,h)
					if hi-lo > spread:
						ok = false
						break
				if not ok: break
			if not ok:
				_count("col_not_flat")
				continue
			if lo < Field.SEA_Y+DRY:
				_count("col_wet")
				continue
			best.append({"c":a,"z":z,"lo":lo,"top":top,"spread":hi-lo,"rise":0.0,"score":-(hi-lo)})
	best.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.score) > float(q.score))
	for s: Dictionary in best.slice(0,8):
		if not _strip_by(field,s):
			_count("col_no_strip")
			continue
		if not _clear(field,"colosseum",s,density,rock,ruin): continue
		return s
	if best.is_empty(): _count("no_spot_colosseum")
	return {}

## Whether piece `id` at spot `s` leaves the flats round it: no STRIP m
## level run passes through its footprint (on any of 4 headings, by its
## middle or 0.7 of its half width to a side), or one still lies along a
## side of it (`_strip_by`), as land_ponds.gd keeps a strip by a pond.
static func _flats_kept(field: RefCounted, id: String, s: Dictionary) -> bool:
	var c: Vector2 = s.c
	var half: Vector2 = _info(id).half
	var side := minf(half.x,half.y)*0.7
	var through := false
	for k in 4:
		var d := Vector2.from_angle(PI*0.25*k)
		var across := Vector2(-d.y,d.x)
		for off: float in [0.0,side,-side]:
			if _level(field,c+across*off,d):
				through = true
				break
		if through: break
	return not through or _strip_by(field,s,id)

## Whether a STRIP m landable run lies past piece `id`'s footprint at
## spot `s`: along either of its axes, clear of it, on one of its 4 sides.
static func _strip_by(field: RefCounted, s: Dictionary, id := "colosseum") -> bool:
	var c: Vector2 = s.c
	var z: Vector2 = s.z
	var x := Vector2(z.y,-z.x)
	var half: Vector2 = _info(id).half
	for side: Array in [[x,half.x],[-x,half.x],[z,half.y],[-z,half.y]]:
		var out: Vector2 = side[0]
		var along := Vector2(-out.y,out.x)
		for off: float in [40.0,90.0,150.0]:
			if _level(field,c+out*(float(side[1])+off),along): return true
	return false

## The flats check's level run, as strict as the check counts one
## (scratch flats.gd, the earlier rounds'): dry, no rise over 1.92 m between
## points 16 m apart nor 3.84 m across 64 m, along it or across it (0.06,
## the check's flat cell), and its heights within STRIP_SPREAD m of each other.
## (land_ponds.gd `_strip` has the first two only, which pass a run
## rising some 12 m over its length.)
const STRIP_SPREAD := 3.0
static func _level(field: RefCounted, c: Vector2, d: Vector2) -> bool:
	var n := int(STRIP/16.0)
	var prev := PackedFloat32Array()
	var across := Vector2(-d.y,d.x)*32.0
	var lo := INF
	var hi := -INF
	for t in n+1:
		var p := c+d*(t*16.0-STRIP*0.5)
		var h := float(field.height(p.x,p.y))
		if h-Field.SEA_Y < 2.0: return false
		if t > 0 and absf(h-prev[t-1]) > 1.92: return false
		if t > 3 and absf(h-prev[t-4]) > 3.84: return false
		lo = minf(lo,h)
		hi = maxf(hi,h)
		if hi-lo > STRIP_SPREAD: return false
		var a := p+across
		var b := p-across
		if absf(float(field.height(a.x,a.y))-float(field.height(b.x,b.y))) > 3.84: return false
		prev.append(h)
	return true

static func _none(why: String) -> Dictionary:
	_count(why)
	return {}

static func _no(why: String) -> bool:
	_count(why)
	return false

static func _count(what: String, n := 1) -> void:
	_lock.lock()
	stats[what] = int(stats.get(what,0))+n
	_lock.unlock()
