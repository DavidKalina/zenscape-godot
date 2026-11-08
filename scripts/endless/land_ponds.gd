extends RefCounted
## Ponds: still water in hollows on the meadows and wide valley floors
## (docs/design/endless-flight/ponds-handoff.md). A layer over the land
## field: LandField (land_field.gd) applies it after the native or GDScript
## field has worked, so both fields read the same ponds and nothing native
## changes.
##
## At most one pond per CELL m square, its centre kept MARGIN m inside the
## square so all it touches stays in it (a point only asks its own square).
## A square rolls for one (CHANCE times --ponds=X), then keeps it only on
## open, near-flat meadow away from rivers, the coast and the ranges.
##
## Downstream a pond reads as a river with no flow, so everything that keeps
## off a river's water and bank keeps off it, the ground shader paints it
## with the river's water and banks, and the plane and the walker meet it as
## a river: `last_river` the distance outside its edge, `last_river_r` the
## distance from its centre, `last_river_w` its radius that way,
## `last_river_y` its level.
##
## A pond is a PackedFloat32Array: [centre x, centre z, radius, level,
## depth, lobe 2, phase 2, lobe 3, phase 3, lobe 5, phase 5, widest].

## The sea's level (LandField.SEA_Y; not preloaded, LandField preloads this).
const SEA_Y := -40.0

const CELL := 400.0
const MARGIN := 80.0
## The share of squares that roll a pond (times --ponds=X, up to CHANCE_MAX).
const CHANCE := 0.75
const CHANCE_MAX := 0.95
## Spots a square tries before it gives up.
const TRIES := 6
## Radius (m), before its lobes.
const RADIUS := Vector2(11.0,25.0)
## The outline's lobes, as shares of the radius: 2 (long or round), 3, 5.
const LOBES := [Vector2(0.08,0.24),Vector2(0.05,0.12),Vector2(0.02,0.06)]
## Depth in the middle (m); the ground shader lifts its grid at most 3 m.
const DEPTH := Vector2(1.5,2.4)
## The bed's fall: none at the edge, all of the depth by this share in.
const BOWL := 0.3
## Past its edge the bank runs down to the water at BANK_RISE (rise over
## run), so the turf dips gently into it; LIP raises a low hole by the edge.
const BANK_RISE := 0.14
const LIP := Vector2(5.0,9.0)
## How far past its edge a pond's reads carry (m; `last_river`).
const REACH := 40.0
## Where one may lie: meadow at least this, this high over the sea (m) at the
## least, mountain at most this, a river's water at least this far past
## its edge (m), and the ground round it this level (the rise over run
## across it, end to end).
const MEADOW_MIN := 0.0
const OVER_SEA := 4.0
const MOUNTAIN_MAX := 0.25
const RIVER_OFF := 45.0
const LEVEL_SLOPE := 0.06
## A valley floor narrower than this half-width (m) takes none: it is the
## valley's one landing strip.
const FLOOR_HALF := 55.0
## The water stands this far under the lowest of the ground round it (m).
const BRIM := 0.25
## A landing strip's length (m), and how far past a pond's edge one is
## looked for when the pond sits on one ("Meadows and flats", AGENTS.md).
const STRIP := 208.0
const STRIP_OFF := 30.0

static var _cache := {}
static var _lock := Mutex.new()
## A world's say over each square before it rolls (the tutorial's stages,
## profiles/tutorial.gd `pond_gate`): Callable(seed, ci, cj, impl) -> null
## (roll as ever), false (none for now, not kept) or the square's pond (kept).
## A pond of 14 numbers is a straight reach: [12] half its length, [13] its
## angle; its radius [2] is the half width round that line (`at`).
static var gate := Callable()
## Bumped by `forget`: every asking field's own cache (`local`) is dropped
## when it sees a new one.
static var epoch := 0

## The `--ponds=X` density (1; 0 none).
static func wanted(default := 1.0) -> float:
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--ponds="): return maxf(0.0,float(a.get_slice("=",1)))
	return default

static func _hash01(seed: int, i: int, j: int, salt: int) -> float:
	return float(hash([seed,i,j,salt,7717]) & 0xffffff)/16777216.0

## The pond of the CELL square holding (x, z), or an empty array. `impl` is
## the field doing the work (its last sample is overwritten when the square
## is first looked at); `local` is the asking LandField's own cache.
static func cell_pond(impl: Object, seed: int, density: float, x: float, z: float, local: Dictionary) -> PackedFloat32Array:
	var key := Vector2i(floori(x/CELL),floori(z/CELL))
	if int(local.get(&"epoch",0)) != epoch:
		local.clear()
		local[&"epoch"] = epoch
	var got: Variant = local.get(key)
	if got != null: return got
	var k4 := Vector4i(key.x,key.y,seed,int(density*1000.0))
	_lock.lock()
	got = _cache.get(k4)
	_lock.unlock()
	if got == null and gate.is_valid():
		var said: Variant = gate.call(seed,key.x,key.y,impl)
		if said is bool: return PackedFloat32Array()
		got = said
	if got == null:
		got = _make(impl,seed,density,key.x,key.y)
		_lock.lock()
		_cache[k4] = got
		_lock.unlock()
	local[key] = got
	return got

## Square `key`'s pond forgotten (a world's `gate` now says otherwise, e.g.
## the tutorial's lake at PARRY): out of the shared cache, and every field's
## own cache dropped (`epoch`). The land standing over it must be built again.
static func forget(key: Vector2i) -> void:
	_lock.lock()
	for k4: Vector4i in _cache.keys():
		if k4.x == key.x and k4.y == key.y: _cache.erase(k4)
	epoch += 1
	_lock.unlock()

## Every pond whose reach meets the box (x0, z0)..(x1, z1).
static func ponds_in(impl: Object, seed: int, density: float, x0: float, z0: float, x1: float, z1: float, local: Dictionary) -> Array:
	var out: Array = []
	for cj in range(floori(z0/CELL),floori(z1/CELL)+1):
		for ci in range(floori(x0/CELL),floori(x1/CELL)+1):
			var p := cell_pond(impl,seed,density,(ci+0.5)*CELL,(cj+0.5)*CELL,local)
			if p.is_empty(): continue
			var r := p[11]+REACH
			if p[0]+r < x0 or p[0]-r > x1 or p[1]+r < z0 or p[1]-r > z1: continue
			out.append(p)
	return out

## Where (x, z) lies by pond `p`: Vector3(distance outside its edge, from its
## centre, its radius that way), or x INF past its reach.
static func at(p: PackedFloat32Array, x: float, z: float) -> Vector3:
	var dx := x-p[0]
	var dz := z-p[1]
	var far := p[11]+REACH
	if absf(dx) > far or absf(dz) > far: return Vector3(INF,0.0,0.0)
	if p.size() >= 14:
		var along := clampf(dx*cos(p[13])+dz*sin(p[13]),-p[12],p[12])
		var off := Vector2(dx-cos(p[13])*along,dz-sin(p[13])*along).length()
		return Vector3(off-p[2],off,p[2]) if off < p[2]+REACH else Vector3(INF,0.0,0.0)
	var r := sqrt(dx*dx+dz*dz)
	if r > far: return Vector3(INF,0.0,0.0)
	var edge := edge_at(p,atan2(dz,dx))
	return Vector3(r-edge,r,edge)

## The pond's radius toward angle `a`.
static func edge_at(p: PackedFloat32Array, a: float) -> float:
	return p[2]*(1.0+p[5]*sin(2.0*a+p[6])+p[7]*sin(3.0*a+p[8])+p[9]*sin(5.0*a+p[10]))

## The land's height `base` with pond `p` cut in, at `e` (`at`).
static func carve(p: PackedFloat32Array, base: float, e: Vector3) -> float:
	var level := p[3]
	if e.x < 0.0:
		var s := e.y/maxf(e.z,0.01)
		return minf(base,level-p[4]*(1.0-smoothstep(BOWL,1.0,s)))
	if e.x > LIP.y and base < level+BANK_RISE*e.x: return base
	var h := minf(base,level+BANK_RISE*e.x)
	var lip := 1.0-smoothstep(LIP.x,LIP.y,e.x)
	if lip > 0.0: h = maxf(h,lerpf(h,level+0.06+0.08*e.x,lip))
	return h

## Square (ci, cj)'s pond, or an empty array (see the top).
static func _make(impl: Object, seed: int, density: float, ci: int, cj: int) -> PackedFloat32Array:
	if density <= 0.0 or _hash01(seed,ci,cj,0) > minf(CHANCE*density,CHANCE_MAX): return PackedFloat32Array()
	for t in TRIES:
		var p := _try(impl,seed,ci,cj,t)
		if not p.is_empty(): return p
	return PackedFloat32Array()

## Square (ci, cj)'s `t`th spot tried.
static func _try(impl: Object, seed: int, ci: int, cj: int, t: int) -> PackedFloat32Array:
	var none := PackedFloat32Array()
	var salt := t*16
	var x := ci*CELL+MARGIN+_hash01(seed,ci,cj,salt+1)*(CELL-2.0*MARGIN)
	var z := cj*CELL+MARGIN+_hash01(seed,ci,cj,salt+2)*(CELL-2.0*MARGIN)
	var radius := lerpf(RADIUS.x,RADIUS.y,pow(_hash01(seed,ci,cj,salt+3),1.3))
	var s: Dictionary = impl.shape(x,z)
	var h0 := float(s.height)
	if h0-SEA_Y < OVER_SEA: return none
	if float(s.meadow) < MEADOW_MIN or float(s.mountain) > MOUNTAIN_MAX: return none
	var widest := radius*(1.0+LOBES[0].y+LOBES[1].y+LOBES[2].y)
	if float(s.river) < widest+RIVER_OFF: return none
	var v := float(s.valley)
	if v < INF and v < float(s.half)+widest and float(s.half) < FLOOR_HALF: return none
	# The ground round it: level enough, dry, off any river.
	var low := h0
	var lo := h0
	var hi := h0
	var outer := widest+14.0
	for k in 12:
		var a := TAU*k/12.0
		for rr: float in [widest,outer]:
			var g: Vector2 = impl.sample(x+cos(a)*rr,z+sin(a)*rr)
			if float(impl.last_river) < RIVER_OFF*0.5: return none
			lo = minf(lo,g.x)
			hi = maxf(hi,g.x)
			if rr == widest: low = minf(low,g.x)
			if hi-lo > LEVEL_SLOPE*outer*2.0: return none
	var level := low-BRIM
	if level-SEA_Y < OVER_SEA-1.0: return none
	if not _strip_kept(impl,x,z,widest): return none
	var p := PackedFloat32Array()
	p.resize(12)
	p[0] = x
	p[1] = z
	p[2] = radius
	p[3] = level
	p[4] = lerpf(DEPTH.x,DEPTH.y,_hash01(seed,ci,cj,salt+4))
	for l in 3:
		var range_l: Vector2 = LOBES[l]
		p[5+l*2] = lerpf(range_l.x,range_l.y,_hash01(seed,ci,cj,salt+5+l))
		p[6+l*2] = _hash01(seed,ci,cj,salt+9+l)*TAU
	p[11] = widest
	return p

## Whether a landing strip (STRIP m of level ground in a row) still lies by
## a pond at (x, z) as wide as `widest`: none runs through its spot, or one
## runs past it, STRIP_OFF m clear of its edge, along any of 8 headings.
static func _strip_kept(impl: Object, x: float, z: float, widest: float) -> bool:
	var through := false
	for k in 4:
		var a := PI*k/4.0
		var d := Vector2(cos(a),sin(a))
		for off: float in [0.0,widest*0.7,-widest*0.7]:
			if _strip(impl,Vector2(x,z)+Vector2(-d.y,d.x)*off,d):
				through = true
				break
		if through: break
	if not through: return true
	for k in 8:
		var a := TAU*k/8.0
		var out := Vector2(cos(a),sin(a))
		var c := Vector2(x,z)+out*(widest+STRIP_OFF)
		if _strip(impl,c,Vector2(-out.y,out.x)): return true
	return false

## Whether the STRIP m line centred on `c` along `d` is level, as the flats
## check has it: dry, no rise over 0.12 between points 16 m apart, nor over
## 0.06 across 64 m.
static func _strip(impl: Object, c: Vector2, d: Vector2) -> bool:
	var n := int(STRIP/16.0)
	var hs := PackedFloat32Array()
	hs.resize(n+1)
	for t in n+1:
		var p := c+d*(t*16.0-STRIP*0.5)
		var h: float = impl.sample(p.x,p.y).x
		if h-SEA_Y < 2.0 or float(impl.last_river) < 2.0: return false
		if t > 0 and absf(h-hs[t-1]) > 1.92: return false
		if t > 3 and absf(h-hs[t-4]) > 3.84: return false
		hs[t] = h
	return true

## The pond pass over a chunk's arrays (LandField.build_chunk; its args).
## `field` is the LandField (its `height` has the ponds in).
static func apply_chunk(field: Object, impl: Object, made: Dictionary, ps: Array, x0: float, z0: float, step: float, cells: int, skirt_drop: float) -> void:
	var n := cells+1
	var heights: PackedFloat32Array = made.heights
	var verts: PackedVector3Array = made.verts
	var normals: PackedVector3Array = made.normals
	var colours: PackedColorArray = made.colours
	var carved: PackedByteArray = made.carved
	var river: PackedFloat32Array = made.river
	var moved := PackedByteArray()
	moved.resize(n*n)
	var touched := PackedByteArray()
	touched.resize(n*n)
	var any_moved := false
	for p: PackedFloat32Array in ps:
		var far := p[11]+REACH
		var i0 := clampi(floori((p[0]-far-x0)/step),0,cells)
		var i1 := clampi(ceili((p[0]+far-x0)/step),0,cells)
		var j0 := clampi(floori((p[1]-far-z0)/step),0,cells)
		var j1 := clampi(ceili((p[1]+far-z0)/step),0,cells)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var x := x0+i*step
				var z := z0+j*step
				var e := at(p,x,z)
				if e.x >= REACH: continue
				var v := j*n+i
				var out_now := absf(river[v*3])-river[v*3+1]
				if e.x < out_now:
					river[v*3] = e.y
					river[v*3+1] = e.z
					river[v*3+2] = p[3]
					carved[v*4+2] = 127
					carved[v*4+3] = 127
					touched[v] = 1
				if e.x < LIP.y:
					var y := carve(p,heights[v],e)
					if absf(y-heights[v]) > 0.0005:
						heights[v] = y
						verts[v] = Vector3(verts[v].x,y,verts[v].z)
						moved[v] = 1
						touched[v] = 1
						any_moved = true
	if any_moved:
		# Normals round what moved (central differences, as the field's).
		var redo := PackedByteArray()
		redo.resize(n*n)
		for j in n:
			for i in n:
				if moved[j*n+i] == 0: continue
				for d: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var ii := i+d.x
					var jj := j+d.y
					if ii >= 0 and ii < n and jj >= 0 and jj < n: redo[jj*n+ii] = 1
		for j in n:
			for i in n:
				var v := j*n+i
				if redo[v] == 0: continue
				var x := x0+i*step
				var z := z0+j*step
				var hl: float = heights[v-1] if i > 0 else field.height(x-step,z)
				var hr: float = heights[v+1] if i < cells else field.height(x+step,z)
				var hd: float = heights[v-n] if j > 0 else field.height(x,z-step)
				var hu: float = heights[v+n] if j < cells else field.height(x,z+step)
				var normal := Vector3(hl-hr,2.0*step,hd-hu).normalized()
				normals[v] = normal
				var meadow := colours[v].a
				var c: Color = impl.colour(x,z,heights[v],normal.y,meadow)
				c.a = meadow
				colours[v] = c
				touched[v] = 1
	# The skirt's copies of the edges.
	var edges := [[],[],[],[]]
	for t in n:
		edges[0].append(t)
		edges[1].append(t*n+cells)
		edges[2].append(cells*n+t)
		edges[3].append(t*n)
	for e in 4:
		for t in n:
			var from: int = edges[e][t]
			if touched[from] == 0: continue
			var v := n*n+e*n+t
			verts[v] = verts[from]-Vector3(0.0,skirt_drop,0.0)
			normals[v] = normals[from]
			colours[v] = colours[from]
			for q in 4: carved[v*4+q] = carved[from*4+q]
			river[v*3] = river[from*3]
			river[v*3+1] = -river[from*3+1]
			river[v*3+2] = river[from*3+2]
	made.heights = heights
	made.verts = verts
	made.normals = normals
	made.colours = colours
	made.carved = carved
	made.river = river

## The pond pass over LandField.grid's arrays.
static func apply_grid(got: Dictionary, ps: Array, x0: float, z0: float, step: float, nx: int, nz: int, pad: int) -> void:
	var hs: PackedFloat32Array = got.heights
	var rs: PackedFloat32Array = got.river
	for p: PackedFloat32Array in ps:
		var far := p[11]+REACH
		var i0 := clampi(floori((p[0]-far-x0)/step)+pad,0,nx-1)
		var i1 := clampi(ceili((p[0]+far-x0)/step)+pad,0,nx-1)
		var j0 := clampi(floori((p[1]-far-z0)/step)+pad,0,nz-1)
		var j1 := clampi(ceili((p[1]+far-z0)/step)+pad,0,nz-1)
		for j in range(j0,j1+1):
			for i in range(i0,i1+1):
				var e := at(p,x0+(i-pad)*step,z0+(j-pad)*step)
				if e.x >= REACH: continue
				var k := j*nx+i
				if e.x < rs[k]: rs[k] = e.x
				if e.x < LIP.y: hs[k] = carve(p,hs[k],e)
	got.heights = hs
	got.river = rs
