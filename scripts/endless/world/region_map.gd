extends RefCounted
## The region map of the patchwork world (scripts/endless/world/profiles/
## regions.gd): irregular cells over the endless XZ plane, each holding one
## registered region, with a soft band at every border where two regions
## meet.
##
## The cells are a warped Voronoi: one site per square of `size` (jittered
## inside it), the point domain-warped by two octaves of value noise before
## the nearest site is found, so the borders wander. Each cell's region comes
## from a low-discrepancy walk over the cells (the R2 sequence, offset by the
## seed and nudged per cell), so the shares hold over any wide stretch and a
## line of cells changes region every two or three cells instead of running
## on.
##
## The weights are smooth everywhere: for each cell near the point, the
## product over every other cell of smoothstep(-blend/2, blend/2, e), with e
## the signed distance to the two cells' bisector (positive on this cell's
## side). Deep in a cell that is 1 for it and 0 for the rest; on a border it
## is one half each, easing across `blend` metres. Cells of one region add, so
## a border between two cells of the same region has no band at all.
##
## Pure maths on immutable numbers: thread-safe, deterministic, and the same
## on every worker (the land's workers read it per sample).

## The jitter of a site inside its square (a share of `size`). Under 1 so a
## 4 x 4 window of squares always holds every cell within `blend` of the
## nearest (see `_window`).
const JITTER := 0.75
## The R2 sequence's steps (1/rho, 1/rho^2 with rho the plastic number).
const R2 := Vector2(0.7548776662,0.5698402910)
## How far each cell's place on the walk is nudged (a share of the walk).
const NUDGE := 0.04
## The warp: two octaves (amplitude, scale), both shares of `size`.
const WARP := [Vector2(0.20,1.1),Vector2(0.07,0.37)]

var size := 6000.0
var blend := 1500.0
var seed := 1
## The regions' cumulative shares (the last is 1).
var _cum := PackedFloat32Array()
var _walk_off := 0.0

func _init(region_size: float, band: float, layout_seed: int, shares: PackedFloat32Array) -> void:
	size = maxf(region_size,500.0)
	blend = clampf(band,1.0,size*0.38)
	seed = layout_seed
	var total := 0.0
	for s in shares: total += maxf(s,0.0)
	var run := 0.0
	for s in shares:
		run += maxf(s,0.0)/maxf(total,1e-6)
		_cum.append(run)
	if not _cum.is_empty(): _cum[_cum.size()-1] = 1.0
	_walk_off = _unit(_hash(0,0,seed*7+5))

## How many regions the map deals out.
func count() -> int:
	return _cum.size()

# --- Hash and noise --------------------------------------------------------------------

## A 32-bit hash of a lattice point and a salt.
static func _hash(i: int, j: int, salt: int) -> int:
	var h := (i*73856093+j*19349663+(salt & 0xffffff)*83492791) & 0xffffffff
	h = ((h ^ (h >> 13))*668265261) & 0xffffffff
	h = ((h ^ (h >> 16))*374761393) & 0xffffffff
	return h ^ (h >> 15)

static func _unit(h: int) -> float:
	return float(h & 0xffffff)/16777216.0

## Value noise in [-1, 1] at (x, y) (lattice units), quintic eased.
static func _noise(x: float, y: float, salt: int) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x-ix
	var fy := y-iy
	var ux := fx*fx*fx*(fx*(fx*6.0-15.0)+10.0)
	var uy := fy*fy*fy*(fy*(fy*6.0-15.0)+10.0)
	var a := _unit(_hash(ix,iy,salt))
	var b := _unit(_hash(ix+1,iy,salt))
	var c := _unit(_hash(ix,iy+1,salt))
	var d := _unit(_hash(ix+1,iy+1,salt))
	return lerpf(lerpf(a,b,ux),lerpf(c,d,ux),uy)*2.0-1.0

# --- The cells --------------------------------------------------------------------------

## World XZ (x, z) moved into the warped plane the sites stand in.
func warp(x: float, z: float) -> Vector2:
	var out := Vector2(x,z)
	var o := 0
	for w: Vector2 in WARP:
		var sc := size*w.y
		var salt := seed*31+o*2
		out += Vector2(_noise(x/sc,z/sc,salt+101),_noise(x/sc+17.3,z/sc-9.1,salt+102))*size*w.x
		o += 1
	return out

## The site of cell (i, j) in the warped plane.
func site(i: int, j: int) -> Vector2:
	var hx := _unit(_hash(i,j,seed*13+1))
	var hz := _unit(_hash(i,j,seed*13+2))
	return Vector2((i+0.5+(hx-0.5)*JITTER)*size,(j+0.5+(hz-0.5)*JITTER)*size)

## The region index cell (i, j) holds.
func region_of(i: int, j: int) -> int:
	var u := fposmod(i*R2.x+j*R2.y+_walk_off+(_unit(_hash(i,j,seed*13+3))-0.5)*NUDGE,1.0)
	for k in _cum.size():
		if u < _cum[k]: return k
	return _cum.size()-1

## The 4 x 4 squares round warped point q: every site within the nearest's
## distance plus `blend` is in it (a site outside is over 1.6 size away, the
## nearest under 1.24 size, and blend is at most 0.38 size).
func _window(q: Vector2) -> Vector2i:
	return Vector2i(floori(q.x/size-0.5)-1,floori(q.y/size-0.5)-1)

## The cell (i, j) nearest world XZ (x, z).
func cell_at(x: float, z: float) -> Vector2i:
	var q := warp(x,z)
	var b := _window(q)
	var best := INF
	var got := Vector2i.ZERO
	for dj in 4:
		for di in 4:
			var d := q.distance_squared_to(site(b.x+di,b.y+dj))
			if d < best:
				best = d
				got = Vector2i(b.x+di,b.y+dj)
	return got

## The regions' weights at world XZ (x, z), one per region index, summing
## to 1.
func weights(x: float, z: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(_cum.size())
	var q := warp(x,z)
	var b := _window(q)
	var sites: Array[Vector2] = []
	var d2 := PackedFloat32Array()
	var regs := PackedInt32Array()
	var near := INF
	for dj in 4:
		for di in 4:
			var s := site(b.x+di,b.y+dj)
			var d := q.distance_squared_to(s)
			sites.append(s)
			d2.append(d)
			regs.append(region_of(b.x+di,b.y+dj))
			near = minf(near,d)
	var reach := sqrt(near)+blend
	reach *= reach
	var half := blend*0.5
	var total := 0.0
	for i in 16:
		if d2[i] > reach: continue
		var w := 1.0
		for k in 16:
			if k == i: continue
			var e := (d2[k]-d2[i])/(2.0*sites[i].distance_to(sites[k]))
			if e >= half: continue
			w *= smoothstep(-half,half,e)
			if w <= 0.0: break
		if w <= 0.0: continue
		out[regs[i]] += w
		total += w
	for r in out.size(): out[r] /= total
	return out

## The region index with the most weight at (x, z).
func dominant(x: float, z: float) -> int:
	var w := weights(x,z)
	var best := 0
	for r in w.size():
		if w[r] > w[best]: best = r
	return best
