extends RefCounted
## Genome version 7 terrain detail: ridged, domain-warped noise on the slopes,
## then stream-power erosion down a drainage tree with sediment settling where
## the flow slackens. The result is a height delta on a 41x41 grid (0.7 m cells,
## about the terrain mesh spacing)
## added to the analytic genome height before water is carved.
##
## The native kernel (`ZenScapeTerrainKernels.erode`) does the work when built.
## `erode_reference` is the exact GDScript mirror, operation for operation, so
## unbuilt checkouts grow the same world. Both use only + - * / sqrt floor on
## doubles and 64-bit integer hashing, so no platform's libm can change a seed.
const Genome = preload("res://scripts/inland_genome.gd")
const SIZE := 41
const CELL := 0.7
const ORIGIN := -14.0
const CACHE_LIMIT := 8
static var _cache := {}
static var _order: Array = []
static var _mutex := Mutex.new()

## Per-family strengths. Families left out keep their exact analytic shape:
## dunes are wind-built, marsh pools and salt pans sit on precise levels.
const FAMILIES := {
	"mountain":{"detail":0.6,"k":0.010,"max_cut":1.0,"deposit":0.45},
	"massif":{"detail":0.65,"k":0.010,"max_cut":1.1,"deposit":0.45},
	"valley":{"detail":0.35,"k":0.008,"max_cut":0.9,"deposit":0.55},
	"basin":{"detail":0.4,"k":0.008,"max_cut":0.8,"deposit":0.5},
	"plateau":{"detail":0.2,"k":0.007,"max_cut":0.7,"deposit":0.5},
	"foothills":{"detail":0.3,"k":0.007,"max_cut":0.6,"deposit":0.5},
	"meadow":{"detail":0.1,"k":0.004,"max_cut":0.3,"deposit":0.5},
	"chasm":{"detail":0.12,"k":0.005,"max_cut":0.4,"deposit":0.4},
	"desert":{"detail":0.15,"k":0.007,"max_cut":0.45,"deposit":0.5},
	"desert-mountains":{"detail":0.55,"k":0.010,"max_cut":1.0,"deposit":0.45},
	"tablelands":{"detail":0.12,"k":0.006,"max_cut":0.5,"deposit":0.65},
	"buttes":{"detail":0.12,"k":0.006,"max_cut":0.5,"deposit":0.65},
	"monuments":{"detail":0.12,"k":0.006,"max_cut":0.5,"deposit":0.65},
}

static func params(genome: Dictionary) -> Dictionary:
	if int(genome.version)<7 or not FAMILIES.has(genome.composition): return {}
	var family: Dictionary = FAMILIES[genome.composition]
	var relief := float(genome.relief)
	return {"size":SIZE,"cell":CELL,"origin":ORIGIN,"seed":int(genome.noise_seed)&0xffffffff,
		"detail":float(family.detail)*relief,"frequency":0.16/float(genome.breadth),"warp":1.3,"slope_ref":1.2,
		"iterations":20,"k":float(family.k),"channel_area":4.0,"jitter":0.6,"max_cut":float(family.max_cut)*relief,"deposit":float(family.deposit),
		"deposit_slope":0.35,"deposit_cap":0.06,"edge_inner":10.8,"edge_outer":12.6}

## Delta grid for a genome, or an empty array when the family is not eroded.
## Parallel recipe workers build the same world at once; the first computes,
## the rest wait on the mutex and share the result.
static func delta(genome: Dictionary,noise: FastNoiseLite) -> PackedFloat64Array:
	var settings := params(genome)
	if settings.is_empty(): return PackedFloat64Array()
	var key := var_to_str([genome.version,genome.seed,genome.composition,genome.archetype,genome.landform,genome.relief,genome.breadth])
	_mutex.lock()
	if _cache.has(key):
		var hit: PackedFloat64Array = _cache[key]
		_mutex.unlock()
		return hit
	var base := PackedFloat64Array()
	var fixed := PackedByteArray()
	base.resize(SIZE*SIZE)
	fixed.resize(SIZE*SIZE)
	for j in range(SIZE):
		for i in range(SIZE):
			var p := Vector2(ORIGIN+i*CELL,ORIGIN+j*CELL)
			base[j*SIZE+i] = Genome.height(genome,p,noise)
			fixed[j*SIZE+i] = 0 if Genome.has_ground(genome,p) else 1
	var result := erode(base,fixed,settings)
	_cache[key] = result
	_order.append(key)
	if _order.size()>CACHE_LIMIT: _cache.erase(_order.pop_front())
	_mutex.unlock()
	return result

static func erode(base: PackedFloat64Array,fixed: PackedByteArray,settings: Dictionary) -> PackedFloat64Array:
	var kernel: RefCounted = preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	if kernel != null and kernel.has_method("erode"): return kernel.erode(base,fixed,settings)
	return erode_reference(base,fixed,settings)

## Catmull-Rom read of the delta grid, so the 0.7 m cells leave no creases
## in the surface. Zero for an empty grid; clamped at the plate edge.
static func sample(grid: PackedFloat64Array,x: float,z: float) -> float:
	if grid.is_empty(): return 0.0
	var fi := clampf((x-ORIGIN)/CELL,0.0,SIZE-1.0)
	var fj := clampf((z-ORIGIN)/CELL,0.0,SIZE-1.0)
	var i := mini(SIZE-2,int(fi))
	var j := mini(SIZE-2,int(fj))
	var u := fi-i
	var v := fj-j
	var i0 := maxi(i-1,0)
	var i3 := mini(i+2,SIZE-1)
	var r0 := maxi(j-1,0)*SIZE
	var r1 := j*SIZE
	var r2 := r1+SIZE
	var r3 := mini(j+2,SIZE-1)*SIZE
	return _spline(_spline(grid[r0+i0],grid[r0+i],grid[r0+i+1],grid[r0+i3],u),
		_spline(grid[r1+i0],grid[r1+i],grid[r1+i+1],grid[r1+i3],u),
		_spline(grid[r2+i0],grid[r2+i],grid[r2+i+1],grid[r2+i3],u),
		_spline(grid[r3+i0],grid[r3+i],grid[r3+i+1],grid[r3+i3],u),v)

static func _spline(a: float,b: float,c: float,d: float,t: float) -> float:
	return b+0.5*t*(c-a+t*(2.0*a-5.0*b+4.0*c-d+t*(3.0*(b-c)+d-a)))

static func _hash(x: int,z: int,seed_value: int) -> int:
	var h := ((x*73856093)^(z*19349663)^seed_value)&0xffffffff
	h = ((h^(h>>16))*0x45d9f3b)&0xffffffff
	h = ((h^(h>>16))*0x45d9f3b)&0xffffffff
	return h^(h>>16)

const _GX := [1.0,-1.0,0.0,0.0,0.7071067811865476,-0.7071067811865476,0.7071067811865476,-0.7071067811865476]
const _GZ := [0.0,0.0,1.0,-1.0,0.7071067811865476,0.7071067811865476,-0.7071067811865476,-0.7071067811865476]
static func _corner(ix: int,iz: int,dx: float,dz: float,seed_value: int) -> float:
	var g := _hash(ix,iz,seed_value)&7
	return float(_GX[g])*dx+float(_GZ[g])*dz

static func _gradient(x: float,z: float,seed_value: int) -> float:
	var fx := floorf(x)
	var fz := floorf(z)
	var ix := int(fx)
	var iz := int(fz)
	var tx := x-fx
	var tz := z-fz
	var u := tx*tx*tx*(tx*(tx*6.0-15.0)+10.0)
	var v := tz*tz*tz*(tz*(tz*6.0-15.0)+10.0)
	var a := _corner(ix,iz,tx,tz,seed_value)
	var b := _corner(ix+1,iz,tx-1.0,tz,seed_value)
	var c := _corner(ix,iz+1,tx,tz-1.0,seed_value)
	var d := _corner(ix+1,iz+1,tx-1.0,tz-1.0,seed_value)
	var top := a+(b-a)*u
	var bottom := c+(d-c)*u
	return top+(bottom-top)*v

static func _ridged(x: float,z: float,seed_value: int) -> float:
	var sum := 0.0
	var amp := 0.5
	var weight := 1.0
	var f := 1.0
	for o in range(3):
		var r := 1.0-absf(_gradient(x*f,z*f,(seed_value+o*1013)&0xffffffff))*1.35
		if r<0.0: r = 0.0
		r = r*r*weight
		weight = r*2.0
		if weight>1.0: weight = 1.0
		sum += r*amp
		amp *= 0.5
		f *= 2.03
	return sum/0.875

static func _ramp(value: float,low: float,high: float) -> float:
	var t := (value-low)/(high-low)
	if t<0.0: t = 0.0
	if t>1.0: t = 1.0
	return t*t*(3.0-2.0*t)

## Exact mirror of the native kernel. Keep the two in step line by line.
static func erode_reference(b: PackedFloat64Array,locked: PackedByteArray,p: Dictionary) -> PackedFloat64Array:
	var n := int(p.size)
	var seed_value := int(p.seed)&0xffffffff
	var iterations := int(p.iterations)
	var cell := float(p.cell)
	var origin := float(p.origin)
	var detail := float(p.detail)
	var frequency := float(p.frequency)
	var warp := float(p.warp)
	var slope_ref := float(p.slope_ref)
	var k := float(p.k)
	var channel_area := float(p.channel_area)
	var jitter_amp := float(p.jitter)
	var max_cut := float(p.max_cut)
	var deposit := float(p.deposit)
	var deposit_slope := float(p.deposit_slope)
	var deposit_cap := float(p.deposit_cap)
	var edge_inner := float(p.edge_inner)
	var edge_outer := float(p.edge_outer)
	var count := n*n
	var out := PackedFloat64Array()
	if n<3 or b.size()!=count or locked.size()!=count: return out
	var h := PackedFloat64Array()
	var top := PackedFloat64Array()
	var weight := PackedFloat64Array()
	var before := PackedFloat64Array()
	var eroded := PackedFloat64Array()
	var area := PackedFloat64Array()
	var sediment := PackedFloat64Array()
	var distance := PackedFloat64Array()
	var lowest := PackedFloat64Array()
	var change := PackedFloat64Array()
	var jitter := PackedFloat64Array()
	lowest.resize(count); change.resize(count); jitter.resize(count*8)
	h.resize(count); top.resize(count); weight.resize(count); before.resize(count)
	eroded.resize(count); area.resize(count); sediment.resize(count); distance.resize(count)
	var receiver := PackedInt64Array()
	var donors := PackedInt64Array()
	var donor := PackedInt64Array()
	var stack := PackedInt64Array()
	var todo := PackedInt64Array()
	receiver.resize(count); donors.resize(count); donor.resize(count*8); stack.resize(count); todo.resize(count)
	for j in range(n):
		for i in range(n):
			var c := j*n+i
			var x := origin+float(i)*cell
			var z := origin+float(j)*cell
			var reach := maxf(absf(x),absf(z))
			var w := 1.0-_ramp(reach,edge_inner,edge_outer)
			if locked[c]!=0: w = 0.0
			weight[c] = w
			var l := c-1 if i>0 else c
			var r := c+1 if i<n-1 else c
			var u := c-n if j>0 else c
			var d := c+n if j<n-1 else c
			var sx := (b[r]-b[l])/(float(r-l)*cell)
			var sz := (b[d]-b[u])/(float((d-u)/n)*cell)
			var s := sqrt(sx*sx+sz*sz)/slope_ref
			if s>1.0: s = 1.0
			var fx := x*frequency
			var fz := z*frequency
			var qx := fx+warp*_gradient(fx*0.5+3.1,fz*0.5+7.7,(seed_value+17)&0xffffffff)
			var qz := fz+warp*_gradient(fx*0.5+11.3,fz*0.5+5.9,(seed_value+29)&0xffffffff)
			h[c] = b[c]+detail*w*s*((_ridged(qx,qz,seed_value)-0.575)*2.0)
			# Fixed random weights per direction let flow wander off the eight
			# grid axes and merge into branching gullies.
			for m in range(8): jitter[c*8+m] = 1.0+(float(_hash(i*8+m,j,(seed_value+41)&0xffffffff)&65535)/65535.0-0.5)*jitter_amp
			top[c] = h[c]
	var ox := [-1,0,1,-1,1,-1,0,1]
	var oz := [-1,-1,-1,0,0,1,1,1]
	var diagonal := cell*1.4142135623730951
	for t in range(iterations):
		for c in range(count):
			receiver[c] = c
			distance[c] = cell
			donors[c] = 0
			lowest[c] = h[c]
			var i := c%n
			var j := c/n
			if locked[c]!=0 or i==0 or j==0 or i==n-1 or j==n-1: continue
			var best := 0.0
			lowest[c] = 1e30
			for m in range(8):
				var other: int = (j+oz[m])*n+i+ox[m]
				var d := diagonal if (ox[m]!=0 and oz[m]!=0) else cell
				var s := (h[c]-h[other])/d*jitter[c*8+m]
				if h[other]<lowest[c]: lowest[c] = h[other]
				if s>best:
					best = s
					receiver[c] = other
					distance[c] = d
		for c in range(count):
			var r := receiver[c]
			if r!=c:
				donor[r*8+donors[r]] = c
				donors[r] += 1
		var size := 0
		for c in range(count):
			if receiver[c]!=c: continue
			var pending := 0
			todo[pending] = c
			pending += 1
			while pending>0:
				pending -= 1
				var node := todo[pending]
				stack[size] = node
				size += 1
				for m in range(donors[node]):
					todo[pending] = donor[node*8+m]
					pending += 1
		for c in range(count):
			area[c] = 1.0
			before[c] = h[c]
			sediment[c] = 0.0
		for s in range(count-1,-1,-1):
			var node := stack[s]
			var r := receiver[node]
			if r!=node: area[r] += area[node]
		for s in range(count):
			var node := stack[s]
			var r := receiver[node]
			if r==node: continue
			var drained := area[node]-channel_area
			if drained<0.0: drained = 0.0
			var f := k*weight[node]*drained/distance[node]
			var next := (h[node]+f*h[r])/(1.0+f)
			var bed := top[node]-max_cut
			if next<bed: next = bed
			if next<h[node]: h[node] = next
		for c in range(count): eroded[c] = before[c]-h[c]
		for s in range(count-1,-1,-1):
			var node := stack[s]
			var r := receiver[node]
			var load := sediment[node]+eroded[node]
			var slack := 1.0
			if r!=node:
				slack = 1.0-((h[node]-h[r])/distance[node])/deposit_slope
				if slack<0.0: slack = 0.0
			var keep := load*deposit*slack*weight[node]
			if keep>deposit_cap: keep = deposit_cap
			var limit := lowest[node] if r==node else 1e30
			for m in range(donors[node]): limit = minf(limit,h[donor[node*8+m]])
			var room := limit-h[node]
			if room<0.0: room = 0.0
			if keep>room: keep = room
			h[node] += keep
			if r!=node: sediment[r] += load-keep
	out.resize(count)
	for c in range(count): change[c] = h[c]-top[c]
	for c in range(count):
		var i := c%n
		out[c] = (change[c-1 if i>0 else c]+change[c]*2.0+change[c+1 if i<n-1 else c])*0.25
	for c in range(count): change[c] = out[c]
	for c in range(count):
		var j := c/n
		out[c] = (top[c]-b[c])+(change[c-n if j>0 else c]+change[c]*2.0+change[c+n if j<n-1 else c])*0.25
	return out
