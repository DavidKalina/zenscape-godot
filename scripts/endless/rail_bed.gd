extends RefCounted
## The railroad's bed in the land (spec-railroad.md, lane line): the line
## (rail_line.gd) cut and banked into the heightfield, a stamp over either
## field like the Peak's massif and the coast's isles, so the ground, its
## paint, collision, the grass and the landing all come with it. LandField
## calls it last.
##
## Across the line, `d` m from its centre: a flat top at the bed's height out
## to HALF (both tracks and their shoulders), then the ground held between a
## cut's wall rising at CUT_SLOPE and a bank falling at FILL_SLOPE, so the
## land is only moved where it stood above or below the bed; faded out by
## REACH, where a sidehill too steep for the wall to meet is left as it was.
## Along it, the flat top ends where the line runs onto a span (trestles
## and bridges end to end, RailLine.spans(); rail_span.gd stands them), and
## the bank falls on into it as a spill cone (SPILL_SLOPE along, FILL_SLOPE
## across) round the abutment, out to SPAN_REACH m in; past that the stamp
## is off (rivers keep their channels under the bridges). In a tunnel it turns to a cover: the
## land raised where it lies under the bore's crown and COVER m over it
## (rail_bore_shape.gd), never lowered, so the bore (rail_bore.gd) is
## always in the rock; at each mouth the cut runs wider than the bed, to
## the portal block's face, and the land under the block is holed
## (`hole_mask`, land_stream.gd) for the bore to open through.
##
## The GDScript is the only copy: the C++ kernels never see the bed
## (LandField `native_impl_in` is null where it meets a box, as for the
## Peak). A point finds its nearest s through a grid of CELL m squares, each
## listing the runs of the line's 4 m segments within REACH of it, and a
## short walk along the run from the square's own nearest one.
##
## Seed 1's wilderness only (the line was laid on it); `--no-railroad` takes
## it off, and the land is main's exactly.

const RailLine = preload("res://scripts/endless/rail_line.gd")
const BoreShape = preload("res://scripts/endless/rail_bore_shape.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const STOPS_PATH := "res://scripts/endless/rail_stops.gd"

## LandField.SEA_Y (land_field.gd preloads this file).
const SEA_Y := -40.0
## The bed's flat top runs a car's half-width and this shoulder past each
## track's centre: HALF, half the top, is 12.5 m with the tracks 13 m apart
## (RailLine.track_gap(); tools/rail_line.py's EDGE), more with a wider
## `--track-gap-toy=`.
const SHOULDER := 3.0
static var HALF := 12.5
## A cut's walls (rise per m out) and a bank's fall (drop per m out).
const CUT_SLOPE := 1.2
const FILL_SLOPE := 0.7
## How far out the stamp reaches (m from the centre), and the band it fades
## over at the end.
const REACH := 60.0
const REACH_FADE := 20.0
## A span's end: the bank's fall along the line into it (drop per m), and
## how far in the stamp reaches (eased off over the last SPAN_FADE m).
## The walls' and banks' feet rounded over FOOT m (`_foot`); their rims
## where they meet the land rounded over RIM m, RIM_GROW m a m out from
## the flat (`_held`).
const FOOT := 3.0
const RIM := 6.0
const RIM_GROW := 0.6
## Round a portal block the hill is cut back under a face rising at
## PORTAL_SLOPE (rise per m) from the cover's top behind and beside the
## block, eased off by PORTAL_REACH m from it (`_cover`).
const PORTAL_SLOPE := 2.2
const PORTAL_REACH := 45.0
const SPILL_SLOPE := 1.0
const SPAN_REACH := 40.0
const SPAN_FADE := 10.0
## The station yards: at each station (RailLine's station and town
## pieces) the flat runs out to YARD_HALF m (the platforms, RailStops
## PLATFORM_OUT 16 m out, and the station house and water tower past them,
## 14 m deep) over YARD_ALONG m either side of its s (RailStops
## PLATFORM_HALF 80 m, and 2), and out to YARD_PLATFORM m along the rest of
## its platforms (RailStops `platform`) and YARD_PAST m past their ends,
## eased back over YARD_EASE m; never on a span.
const YARD_HALF := 31.0
const YARD_ALONG := 82.0
const YARD_PLATFORM := 18.0
const YARD_PAST := 2.0
const YARD_EASE := 12.0
## The grid's squares (m).
const CELL := 32.0
## Trees keep this far off the centre line (m), and off any ground it moved.
const TREE_CLEAR := 36.0
## The bed's ballast, over the field's paint on its flat top.
const BALLAST := Color(0.40,0.37,0.33)

static var _lock := Mutex.new()
static var _built := false
static var _ok := false
static var _n := 0
static var _step := 4.0
static var _x := PackedFloat64Array()
static var _z := PackedFloat64Array()
static var _y := PackedFloat64Array()
## Each sample's stamp weight along the line (0 on spans).
static var _w := PackedFloat32Array()
## Each sample's metres into a span from its nearer end (0 off the spans).
static var _sin := PackedFloat32Array()
## Each sample's distance into a tunnel from its nearer mouth (m; negative
## outside one: how far to the nearest mouth, down to -INTO_FAR), and the
## bed's flat half width there (wider before a mouth).
static var _into := PackedFloat32Array()
static var _hw := PackedFloat32Array()
## The tunnels: [s0, s1] each, along s.
static var _tunnels: Array = []
const INTO_FAR := 400.0
## The bore's sizes (rail_bore_shape.gd), read once.
static var _bore_half := 16.5
static var _face_half := 24.5
## Each segment's (x, z) run to the next sample and 1/its length squared.
static var _dx := PackedFloat64Array()
static var _dz := PackedFloat64Array()
static var _inv := PackedFloat64Array()
## The grid: origin, width and height in squares; per square its first run
## in `_runs` and how many; runs as (first segment, count, walk start), the
## segments unwrapped (index n.. is 0.. again).
static var _gx := 0.0
static var _gz := 0.0
static var _gw := 0
static var _gh := 0
static var _cell_at := PackedInt32Array()
static var _cell_n := PackedInt32Array()
static var _runs := PackedInt32Array()

## How the stamp is weighted for the pass at hand (a coarse chunk: less).
var level := 1.0
## What the last `apply` found and did: the distance from the centre line,
## the s there, the bed's height, the rise it made (negative: a cut), and
## whether trees keep off.
var last_d := INF
var last_s := 0.0
var last_bed := 0.0
var last_lift := 0.0
var last_clear := false
## How far into a tunnel the last point's s is (see `_into`).
var last_into := -INF
var _i := 0
var _t := 0.0

## The bed for this land, or null: seed 1's wilderness, no `--no-railroad`.
static func make(land_seed: int, world_id: String) -> RefCounted:
	if land_seed != 1 or not world_id in ["wilderness","doors"]: return null
	if "--no-railroad" in LaunchArgs.user_args(): return null
	_ensure()
	return new() if _ok else null

## The line's samples and the grid, built once for every field (they are
## read-only after, so the workers' fields share them).
static func _ensure() -> void:
	_lock.lock()
	if not _built:
		_build()
		_built = true
	_lock.unlock()

static func _build() -> void:
	var line: RefCounted = RailLine.new()
	if not bool(line.ok): return
	_step = float(line.step)
	HALF = float(line.track_gap())*0.5+RailLine.CAR_WIDTH*0.5+SHOULDER
	_x = line._x
	_z = line._z
	_y = line._y
	_n = _x.size()
	_dx.resize(_n)
	_dz.resize(_n)
	_inv.resize(_n)
	for i in _n:
		var j := (i+1)%_n
		_dx[i] = _x[j]-_x[i]
		_dz[i] = _z[j]-_z[i]
		_inv[i] = 1.0/maxf(_dx[i]*_dx[i]+_dz[i]*_dz[i],1e-6)
	# The weight along the line: 1 on the bed and in tunnels, and into each
	# span (its spill cones) out to SPAN_REACH, eased to 0 past that.
	_w.resize(_n)
	_w.fill(1.0)
	_sin.resize(_n)
	_sin.fill(0.0)
	for st: Array in line.spans():
		var s0 := float(st[0])
		var s1 := float(st[1])
		for i in range(ceili(s0/_step),floori(s1/_step)+1):
			var into := minf(i*_step-s0,s1-i*_step)
			var k := posmod(i,_n)
			_sin[k] = maxf(into,0.0)
			_w[k] = minf(_w[k],1.0-smoothstep(SPAN_REACH-SPAN_FADE,SPAN_REACH,into))
	# Into the tunnels, and the cut widened before each mouth.
	_bore_half = BoreShape.half()
	_face_half = BoreShape.face_half()
	_tunnels = line.stretches("tunnel")
	_into.resize(_n)
	_into.fill(-INTO_FAR)
	_hw.resize(_n)
	_hw.fill(HALF)
	var mouth_half := maxf(_bore_half+BoreShape.MOUTH_PAST,HALF)
	var len := _n*_step
	for st: Array in _tunnels:
		var s0 := float(st[0])
		var s1 := float(st[1])
		var reach := BoreShape.MOUTH_FLAT+BoreShape.MOUTH_EASE
		for i in range(floori((s0-INTO_FAR)/_step),ceili((s1+INTO_FAR)/_step)+1):
			var s := i*_step
			var k := posmod(i,_n)
			var into := minf(s-s0,s1-s)
			if into < 0.0 and _into[k] >= 0.0: continue
			if into >= 0.0 or into > _into[k]: _into[k] = maxf(into,-INTO_FAR)
			if into < BoreShape.COVER_FROM and -into < reach:
				var widen := 1.0-smoothstep(BoreShape.MOUTH_FLAT,reach,-into)
				_hw[k] = maxf(_hw[k],lerpf(HALF,mouth_half,widen))
		if s1 > len: push_warning("rail bed: a tunnel over the lap's end")
	# The station yards: wide enough that the land never stands through a
	# platform, nor up the house's or the tower's back.
	var yard := maxf(YARD_HALF,HALF)
	var stops: GDScript = load(STOPS_PATH)
	for piece: Dictionary in line.pieces():
		if not str(piece.kind) in ["station","town"]: continue
		var sc := float(piece.s0)
		var pl: Vector2 = stops.platform(line,sc)
		for zone: Vector3 in [Vector3(sc-YARD_ALONG,sc+YARD_ALONG,yard),Vector3(pl.x-YARD_PAST,pl.y+YARD_PAST,maxf(YARD_PLATFORM,HALF))]:
			for i in range(floori((zone.x-YARD_EASE)/_step),ceili((zone.y+YARD_EASE)/_step)+1):
				var k := posmod(i,_n)
				# Not on a span, nor before a tunnel's mouth (its own widening).
				if _sin[k] > 0.0 or _into[k] >= -(BoreShape.MOUTH_FLAT+BoreShape.MOUTH_EASE): continue
				var widen := 1.0-smoothstep(0.0,YARD_EASE,maxf(zone.x-i*_step,i*_step-zone.y))
				_hw[k] = maxf(_hw[k],lerpf(HALF,zone.z,widen))
	# The grid over the line's box and REACH round it.
	var x0 := INF
	var z0 := INF
	var x1 := -INF
	var z1 := -INF
	for i in _n:
		x0 = minf(x0,_x[i])
		z0 = minf(z0,_z[i])
		x1 = maxf(x1,_x[i])
		z1 = maxf(z1,_z[i])
	_gx = x0-REACH-CELL
	_gz = z0-REACH-CELL
	_gw = int(ceil((x1-x0+2.0*(REACH+CELL))/CELL))+1
	_gh = int(ceil((z1-z0+2.0*(REACH+CELL))/CELL))+1
	var lists := {}
	for i in _n:
		var j := (i+1)%_n
		var c0 := Vector2i(floori((minf(_x[i],_x[j])-REACH-_gx)/CELL),floori((minf(_z[i],_z[j])-REACH-_gz)/CELL))
		var c1 := Vector2i(floori((maxf(_x[i],_x[j])+REACH-_gx)/CELL),floori((maxf(_z[i],_z[j])+REACH-_gz)/CELL))
		for cj in range(c0.y,c1.y+1):
			for ci in range(c0.x,c1.x+1):
				# Only squares the segment's reach truly meets.
				var cx := _gx+(ci+0.5)*CELL
				var cz := _gz+(cj+0.5)*CELL
				if _seg_d2(i,cx,cz) > (REACH+CELL*0.75)*(REACH+CELL*0.75): continue
				var k := cj*_gw+ci
				if not lists.has(k): lists[k] = PackedInt32Array()
				var l: PackedInt32Array = lists[k]
				l.append(i)
				lists[k] = l
	_cell_at.resize(_gw*_gh)
	_cell_n.resize(_gw*_gh)
	_cell_n.fill(0)
	for k: int in lists:
		var l: PackedInt32Array = lists[k]
		# Runs of consecutive segments; one through the lap's end joined.
		var starts := PackedInt32Array([l[0]])
		var counts := PackedInt32Array([1])
		for q in range(1,l.size()):
			if l[q] == l[q-1]+1: counts[counts.size()-1] += 1
			else:
				starts.append(l[q])
				counts.append(1)
		if starts.size() > 1 and starts[0] == 0 and starts[-1]+counts[-1] == _n:
			counts[-1] += counts[0]
			starts.remove_at(0)
			counts.remove_at(0)
		var cx := _gx+(k%_gw+0.5)*CELL
		var cz := _gz+(k/_gw+0.5)*CELL
		_cell_at[k] = _runs.size()/3
		_cell_n[k] = starts.size()
		for r in starts.size():
			var best := INF
			var at := starts[r]
			for q in counts[r]:
				var d2 := _seg_d2((starts[r]+q)%_n,cx,cz)
				if d2 < best:
					best = d2
					at = starts[r]+q
			_runs.append_array([starts[r],counts[r],at])
	_ok = true

## The squared distance from (x, z) to segment i.
static func _seg_d2(i: int, x: float, z: float) -> float:
	var t := clampf(((x-_x[i])*_dx[i]+(z-_z[i])*_dz[i])*_inv[i],0.0,1.0)
	var ox := x-_x[i]-_dx[i]*t
	var oz := z-_z[i]-_dz[i]*t
	return ox*ox+oz*oz

## Whether the grid's square at (x, z) lists any of the line.
func reaches(x: float, z: float) -> bool:
	var ci := floori((x-_gx)/CELL)
	var cj := floori((z-_gz)/CELL)
	if ci < 0 or cj < 0 or ci >= _gw or cj >= _gh: return false
	return _cell_n[cj*_gw+ci] > 0

## Whether the box (x0, z0)..(x1, z1) meets a square that lists the line.
func meets(x0: float, z0: float, x1: float, z1: float) -> bool:
	var c0 := Vector2i(maxi(floori((x0-_gx)/CELL),0),maxi(floori((z0-_gz)/CELL),0))
	var c1 := Vector2i(mini(floori((x1-_gx)/CELL),_gw-1),mini(floori((z1-_gz)/CELL),_gh-1))
	for cj in range(c0.y,c1.y+1):
		for ci in range(c0.x,c1.x+1):
			if _cell_n[cj*_gw+ci] > 0: return true
	return false

## The nearest point of the line to (x, z) through its square's runs:
## `last_d`, `last_s`, `_i`, `_t`; false off the grid's listed squares.
func _near(x: float, z: float) -> bool:
	var ci := floori((x-_gx)/CELL)
	var cj := floori((z-_gz)/CELL)
	if ci < 0 or cj < 0 or ci >= _gw or cj >= _gh: return false
	var c := cj*_gw+ci
	var runs := _cell_n[c]
	if runs == 0: return false
	var best := INF
	for r in runs:
		var q := (_cell_at[c]+r)*3
		var a := _runs[q]
		var b := a+_runs[q+1]-1
		var i := _runs[q+2]
		var t := 0.0
		var j := 0
		for _k in 64:
			j = i if i < _n else i-_n
			t = ((x-_x[j])*_dx[j]+(z-_z[j])*_dz[j])*_inv[j]
			if t < 0.0 and i > a: i -= 1
			elif t > 1.0 and i < b: i += 1
			else: break
		t = clampf(t,0.0,1.0)
		var ox := x-_x[j]-_dx[j]*t
		var oz := z-_z[j]-_dz[j]*t
		var d2 := ox*ox+oz*oz
		if d2 < best:
			best = d2
			_i = j
			_t = t
	last_d = sqrt(best)
	last_s = (_i+_t)*_step
	return true

## Where (x, z) sits across the line: Vector3(s, the signed distance from the
## centre line (+ on the right of +s, track 0's side), the bed's top there),
## or a NAN s off the grid's listed squares (more than REACH or so away).
func across(x: float, z: float) -> Vector3:
	if not _near(x,z): return Vector3(NAN,NAN,NAN)
	var j := _i+1 if _i+1 < _n else 0
	var side := (x-_x[_i])*(-_dz[_i])+(z-_z[_i])*_dx[_i]
	return Vector3(last_s,last_d if side >= 0.0 else -last_d,lerpf(_y[_i],_y[j],_t))

## Vector2(world height, meadow) `got` with the bed on it at (x, z).
func apply(got: Vector2, x: float, z: float) -> Vector2:
	last_lift = 0.0
	last_clear = false
	last_d = INF
	if not _near(x,z) or last_d >= REACH: return got
	var j := _i+1 if _i+1 < _n else 0
	var bed := lerpf(_y[_i],_y[j],_t)
	last_bed = bed
	last_into = lerpf(_into[_i],_into[j],_t)
	var fade := (1.0-smoothstep(REACH-REACH_FADE,REACH,last_d))*level
	if last_into >= BoreShape.COVER_FROM or (last_into >= -BoreShape.FACE_OUT and last_d >= _face_half): return _cover(got,bed,fade)
	var w := lerpf(_w[_i],_w[j],_t)*fade
	last_clear = (last_d < TREE_CLEAR and w > 0.0) or in_block()
	if w <= 0.0: return got
	var half := lerpf(_hw[_i],_hw[j],_t)
	var out := last_d-half
	var span_in := lerpf(_sin[_i],_sin[j],_t)
	var to := bed if out <= 0.0 else _held(got.x,bed+_foot(out)*CUT_SLOPE,bed-_foot(out)*FILL_SLOPE,out)
	if span_in > 0.0:
		# On a span: the bank's spill cone round its end, no flat top.
		var o := maxf(out,0.0)
		var f := _foot(o)
		to = _held(got.x,bed+Vector2(f,span_in).length()*CUT_SLOPE,bed-Vector2(f*FILL_SLOPE,span_in*SPILL_SLOPE).length(),o)
	var y := lerpf(got.x,to,w)
	last_lift = y-got.x
	if absf(last_lift) > 0.5: last_clear = true
	# The bed isn't turf, nor a bank the line moved.
	var m := got.y*(1.0-w*(1.0-smoothstep(half-2.0,half+4.0,last_d)))
	m *= 1.0-w*clampf(absf(last_lift)/3.0,0.0,1.0)
	return Vector2(y,m)

## How far out a wall or bank stands at `out` m past the flat: its foot
## rounded over FOOT m each side of the edge (the line of the flat's edge
## falls between the land's vertices, so a sharp one reads as a saw-tooth),
## the wall then FOOT/2 m out from where a sharp one would be.
static func _foot(out: float) -> float:
	if out <= 0.0: return 0.0
	return out*out/(FOOT*2.0) if out < FOOT else out-FOOT*0.5

## The land `h` held under the cut's wall `hi` and over the bank `lo`, the
## rim where either meets the land rounded over up to RIM m (a smooth min
## and max), less near the flat's edge (`out` m past it).
static func _held(h: float, hi: float, lo: float, out: float) -> float:
	var k := minf(out*RIM_GROW,RIM)
	return _smax(_smin(h,hi,k),lo,k)

static func _smin(a: float, b: float, k: float) -> float:
	if k <= 0.0: return minf(a,b)
	var h := maxf(k-absf(a-b),0.0)/k
	return minf(a,b)-h*h*k*0.25

static func _smax(a: float, b: float, k: float) -> float:
	return -_smin(-a,-b,k)

## In a tunnel: the land raised to the bore's cover where it lies under it
## (BoreShape `cover_over`), never lowered, but on a portal block's
## footprint, where it is the cover exactly, under the block's top: the
## hill's face rises behind the block, and the hole under the block drops
## nothing that stands over it.
func _cover(got: Vector2, bed: float, fade: float) -> Vector2:
	var to := bed+BoreShape.cover_over(last_d)
	var cap := last_into <= BoreShape.BLOCK_IN and last_d < _face_half
	var y := got.x if to <= got.x and not cap else lerpf(got.x,to,fade)
	if not cap and to < got.x:
		# Round the block the hill is cut back: under a face rising at
		# PORTAL_SLOPE from the cover's top at the block's back and sides
		# (BoreShape.block_top less the parapet), never under the cover.
		var px := maxf(last_into-BoreShape.BLOCK_IN,0.0)
		var pd := maxf(last_d-_face_half,0.0)
		var past := Vector2(px,pd).length()
		if past < PORTAL_REACH:
			var face := bed+BoreShape.cover_over(0.0)+past*PORTAL_SLOPE
			var k := minf(past*RIM_GROW,RIM)
			var held := maxf(_smin(got.x,face,k),to)
			y = lerpf(got.x,lerpf(held,got.x,smoothstep(PORTAL_REACH*0.6,PORTAL_REACH,past)),fade)
	last_lift = y-got.x
	last_clear = last_lift > 0.5 or in_block()
	var m := got.y*(1.0-fade*clampf(last_lift/3.0,0.0,1.0))
	return Vector2(y,m)

## Whether the last point is on a portal block's footprint (no trees, no
## grass: rail_bore.gd stands the block there).
func in_block() -> bool:
	return last_into >= -BoreShape.FACE_OUT and last_into <= BoreShape.BLOCK_IN and last_d < _face_half

## Whether the last point is on a portal's hole: the land there is dropped.
func in_hole() -> bool:
	return last_into >= BoreShape.HOLE_FROM and last_into <= BoreShape.HOLE_IN and last_d < _bore_half+BoreShape.HOLE_PAST

## How much of the ballast's paint shows at the last `apply`'s point.
func ballast() -> float:
	if last_d >= REACH or last_into >= -BoreShape.FACE_OUT: return 0.0
	var j := _i+1 if _i+1 < _n else 0
	return lerpf(_w[_i],_w[j],_t)*level*(1.0-smoothstep(HALF-3.0,HALF+1.0,last_d))*(1.0-clampf(lerpf(_sin[_i],_sin[j],_t),0.0,1.0))

# --- The land's arrays ------------------------------------------------------------

## The weight of a pass at `step` m a sample: full to 8 m, none past 32 (a
## coarse chunk would catch the 25 m bed as dents).
static func level_of(step: float) -> float:
	return 1.0-smoothstep(8.0,32.0,step)

## The bed's pass over a chunk's arrays (LandField.build_chunk's): heights,
## then the normals and colours round what moved, the skirt's copies. `under`
## gives the land's height without the bed (for the rim outside the chunk).
func apply_chunk(field: Object, under: Callable, made: Dictionary, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	level = level_of(step)
	if level <= 0.0:
		level = 1.0
		return
	var n := cells+1
	var w := n+2
	var heights: PackedFloat32Array = made.heights
	var colours: PackedColorArray = made.colours
	var hs := PackedFloat32Array()
	var ms := PackedFloat32Array()
	var bs := PackedFloat32Array()
	var ds := PackedFloat32Array()
	var mv := PackedByteArray()
	hs.resize(w*w)
	ms.resize(w*w)
	bs.resize(w*w)
	ds.resize(w*w)
	mv.resize(w*w)
	var any := false
	for j in w:
		for i in w:
			var x := x0+(i-1)*step
			var z := z0+(j-1)*step
			var k := j*w+i
			var inner := i >= 1 and i <= n and j >= 1 and j <= n
			if not reaches(x,z):
				hs[k] = heights[(j-1)*n+i-1] if inner else float(under.call(x,z))
				continue
			var base := heights[(j-1)*n+i-1] if inner else float(under.call(x,z))
			var meadow := colours[(j-1)*n+i-1].a if inner else 0.0
			var got := apply(Vector2(base,meadow),x,z)
			hs[k] = got.x
			ms[k] = got.y
			bs[k] = ballast()
			ds[k] = last_d
			if absf(last_lift) > 0.001 or bs[k] > 0.0 or got.y != meadow:
				mv[k] = 1
				any = any or inner
	level = 1.0
	if not any: return
	var verts: PackedVector3Array = made.verts
	var normals: PackedVector3Array = made.normals
	var carved: PackedByteArray = made.carved
	var river: PackedFloat32Array = made.river
	var xs := PackedFloat64Array()
	var zs := PackedFloat64Array()
	var ys := PackedFloat32Array()
	var ups := PackedFloat32Array()
	var mds := PackedFloat32Array()
	var ids := PackedInt32Array()
	var bal := PackedFloat32Array()
	var dist := PackedFloat32Array()
	for j in n:
		for i in n:
			var k := (j+1)*w+i+1
			if mv[k]+mv[k-1]+mv[k+1]+mv[k-w]+mv[k+w] == 0: continue
			var v := j*n+i
			var y := hs[k]
			var nrm := Vector3(hs[k-1]-hs[k+1],2.0*step,hs[k-w]-hs[k+w]).normalized()
			normals[v] = nrm
			xs.append(x0+i*step)
			zs.append(z0+j*step)
			ys.append(y)
			ups.append(nrm.y)
			mds.append(ms[k] if mv[k] == 1 else colours[v].a)
			ids.append(v)
			bal.append(bs[k])
			dist.append(ds[k])
			if mv[k] == 0: continue
			heights[v] = y
			verts[v] = Vector3(i*step,y,j*step)
			# No river on the bed or the banks; no rock's groove on them.
			river[v*3] = 1000.0
			river[v*3+1] = 0.0
			river[v*3+2] = SEA_Y-100.0
			carved[v*4] = 0
			carved[v*4+1] = 0
	if not ids.is_empty():
		var cs: PackedColorArray = field.colours(xs,zs,ys,ups,mds)
		for q in ids.size():
			var c := cs[q].lerp(_ballast_at(xs[q],zs[q],dist[q],cs[q]),bal[q])
			c.a = mds[q]
			colours[ids[q]] = c
	for e in 4:
		for t in n:
			var from: int = t if e == 0 else (t*n+cells if e == 1 else (cells*n+t if e == 2 else t*n))
			var k := ((from/n)+1)*w+(from%n)+1
			if mv[k]+mv[k-1]+mv[k+1]+mv[k-w]+mv[k+w] == 0: continue
			var sv := n*n+e*n+t
			verts[sv] = verts[from]-Vector3(0.0,skirt_drop,0.0)
			normals[sv] = normals[from]
			colours[sv] = colours[from]
			for q in 4: carved[sv*4+q] = carved[from*4+q]
			river[sv*3] = river[from*3]
			river[sv*3+1] = -river[from*3+1]
			river[sv*3+2] = river[from*3+2]
	made.heights = heights
	made.verts = verts
	made.normals = normals
	made.colours = colours
	made.carved = carved
	made.river = river

## The bed's ballast paint at a vertex (x, z), `d` m from the centre line and
## over land colour `land`: dark and oily by each track's middle, paler and
## dustier toward the shoulders, going to the land's own colour at the foot,
## with a mottle of its own (a vertex's, and a wider one) so the band is not
## one flat tan. The 3D strips and sleepers (rail_track.gd) sit on it.
func _ballast_at(x: float, z: float, d: float, land: Color) -> Color:
	var at := absf(d)-(HALF-RailLine.CAR_WIDTH*0.5-SHOULDER)
	var dt := absf(at)
	var mottle := _vnoise(x*0.13,z*0.13)*0.6+_vnoise(x*0.41+7.0,z*0.41)*0.4
	var oil := 1.0-smoothstep(0.6,3.2,dt)
	var c := BALLAST.lerp(Color(0.24,0.225,0.21),oil*(0.4+0.6*mottle))
	# Shoulders between and outside the tracks: pale dust, then the land's own.
	c = c.lerp(Color(0.5,0.46,0.4),smoothstep(3.4,5.6,dt)*0.55)
	c = c.lerp(land*0.8,smoothstep(5.0,HALF,dt)*0.5*mottle)
	return c*(0.88+0.24*mottle)

## Smooth value noise in [0, 1].
static func _vnoise(x: float, z: float) -> float:
	var ix := floorf(x)
	var iz := floorf(z)
	var fx := x-ix
	var fz := z-iz
	fx = fx*fx*(3.0-2.0*fx)
	fz = fz*fz*(3.0-2.0*fz)
	var a := _h2(ix,iz)
	var b := _h2(ix+1.0,iz)
	var c := _h2(ix,iz+1.0)
	var e := _h2(ix+1.0,iz+1.0)
	return lerpf(lerpf(a,b,fx),lerpf(c,e,fx),fz)

static func _h2(x: float, z: float) -> float:
	return fposmod(sin(x*127.1+z*311.7)*43758.5453,1.0)

## No grass on the bed's top (EndlessGrass `grow_cell`, both its paths): the
## grid's river channel (LandField.grid's `river`, how far outside a river's
## water a node is) set under the water where the bed is laid, d < HALF, so
## the grass keeps off the track as off a river's bed.
## None on the stops either (rail_stops.gd `on_stop`: the platforms, the
## towns' streets and lots, the landmarks), loaded here, not preloaded (it
## preloads this file through RailTrack).
func clear_grass(got: Dictionary, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var rs: PackedFloat32Array = got.get("river",PackedFloat32Array())
	if rs.is_empty(): return
	var bx0 := x0-pad*step
	var bz0 := z0-pad*step
	var bx1 := x0+(nx-pad)*step
	var bz1 := z0+(nz-pad)*step
	var stops: GDScript = load(STOPS_PATH)
	var near: Array = stops.grass_near(bx0,bz0,bx1,bz1)
	if not near.is_empty():
		for j in nz:
			for i in nx:
				if stops.on_stop(near,x0+(i-pad)*step,z0+(j-pad)*step): rs[j*nx+i] = -1.0
	if not meets(bx0,bz0,bx1,bz1):
		got.river = rs
		return
	for j in nz:
		for i in nx:
			var x := x0+(i-pad)*step
			var z := z0+(j-pad)*step
			if not _near(x,z) or last_d >= maxf(_face_half,YARD_HALF): continue
			var k := _i+1 if _i+1 < _n else 0
			last_into = lerpf(_into[_i],_into[k],_t)
			var w := lerpf(_w[_i],_w[k],_t)*(1.0 if lerpf(_sin[_i],_sin[k],_t) < 0.5 else 0.0)
			if in_block() or (last_into < BoreShape.COVER_FROM and w > 0.5 and last_d < lerpf(_hw[_i],_hw[k],_t)): rs[j*nx+i] = -1.0
	got.river = rs

## The land holed at each portal (land_stream.gd `_portal_holes`): a
## chunk's vertices (cells + 1 a side, `step` m apart from (x0, z0)) on a
## hole set to 1; empty where the chunk meets none.
func hole_mask(x0: float, z0: float, step: float, cells: int) -> PackedByteArray:
	var out := PackedByteArray()
	if _tunnels.is_empty(): return out
	var r := _face_half+step
	var x1 := x0+cells*step
	var z1 := z0+cells*step
	var near_any := false
	for st: Array in _tunnels:
		for s: float in [float(st[0]),float(st[1])]:
			var i := clampi(int(round(s/_step)),0,_n-1)
			if _x[i] > x0-r-BoreShape.BLOCK_IN and _x[i] < x1+r+BoreShape.BLOCK_IN and _z[i] > z0-r-BoreShape.BLOCK_IN and _z[i] < z1+r+BoreShape.BLOCK_IN:
				near_any = true
	if not near_any: return out
	var n := cells+1
	var any := false
	for j in n:
		for i in n:
			if not _near(x0+i*step,z0+j*step): continue
			var k := _i+1 if _i+1 < _n else 0
			last_into = lerpf(_into[_i],_into[k],_t)
			if not in_hole(): continue
			if not any:
				out.resize(n*n)
				any = true
			out[j*n+i] = 1
	return out

## The bed's pass over LandField.grid's arrays (the grass's).
func apply_grid(got: Dictionary, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var hs: PackedFloat32Array = got.heights
	var ms: PackedFloat32Array = got.get("meadows",PackedFloat32Array())
	var rs: PackedFloat32Array = got.get("river",PackedFloat32Array())
	level = level_of(step)
	for j in nz:
		for i in nx:
			var x := x0+(i-pad)*step
			var z := z0+(j-pad)*step
			if not reaches(x,z): continue
			var k := j*nx+i
			var y := apply(Vector2(hs[k],ms[k] if not ms.is_empty() else 0.0),x,z)
			if absf(last_lift) <= 0.001 and (ms.is_empty() or y.y == ms[k]): continue
			hs[k] = y.x
			if not ms.is_empty(): ms[k] = y.y
			if not rs.is_empty() and absf(last_lift) > 0.25: rs[k] = 1000.0
	level = 1.0
	got.heights = hs
	if not ms.is_empty(): got.meadows = ms
	if not rs.is_empty(): got.river = rs
